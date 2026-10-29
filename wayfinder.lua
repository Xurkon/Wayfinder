local function DebugPrint(message)
  local text = "[Wayfinder] " .. tostring(message)
  if aaprint ~= nil then
    pcall(function() aaprint(text) end)
  elseif X2Chat ~= nil then
    pcall(function() X2Chat:DispatchChatMessage(CMF_SYSTEM, text) end)
  end
end

local function Initialize()
if API_TYPE == nil then
  ADDON:ImportAPI(8)
  X2Chat:DispatchChatMessage(CMF_SYSTEM, "Wayfinder requires the shared globals folder.")
  return
end

ADDON:ImportObject(OBJECT_TYPE.TEXT_STYLE)
ADDON:ImportObject(OBJECT_TYPE.BUTTON)
ADDON:ImportObject(OBJECT_TYPE.DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.NINE_PART_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.COLOR_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.WINDOW)
ADDON:ImportObject(OBJECT_TYPE.LABEL)
ADDON:ImportAPI(API_TYPE.CHAT.id)
ADDON:ImportAPI(API_TYPE.QUEST.id)

DebugPrint("startup: APIs and widget types imported")

local SAVE_KEY = "wayfinder_settings_v1"
local DEFAULTS = {
  x = 0,
  y = 0,
  width = 300,
  rowGap = 5,
  fontSize = 13,
  opacity = 0.94,
  accent = 0.30,
  backgroundOpacity = 0.90,
  locked = false,
  showCompleted = true,
  displayMode = "alongside",
}

local settings = {}
for key, value in pairs(DEFAULTS) do
  settings[key] = value
end

local saved = ADDON:LoadData(SAVE_KEY)
if type(saved) == "table" then
  for key, value in pairs(DEFAULTS) do
    if type(saved[key]) == type(value) then
      settings[key] = saved[key]
    end
  end
end
DebugPrint("startup: saved settings loaded")
settings.displayMode = "alongside" -- Replacement is not enabled until a supported method is verified.

local tracker
local settingsWindow
local rows = {}
local titleLabel
local statusLabel
local accentBar
local background
local settingsStatus
local previewMode = false

local function SaveSettings()
  ADDON:ClearData(SAVE_KEY)
  ADDON:SaveData(SAVE_KEY, settings)
end

local function Clamp(value, minValue, maxValue)
  return math.max(minValue, math.min(maxValue, value))
end

local function ResolvePosition()
  local scale = 1
  if UIParent ~= nil and UIParent.GetUIScale ~= nil then
    local currentScale = UIParent:GetUIScale()
    if type(currentScale) == "number" and currentScale > 0 then
      scale = currentScale
    end
  end
  return settings.x / scale, settings.y / scale
end

local function ApplyPosition()
  local x, y = ResolvePosition()
  tracker:RemoveAllAnchors()
  tracker:AddAnchor("TOPRIGHT", "UIParent", x, y)
end

local function ApplyStyle()
  if tracker == nil then
    return
  end
  tracker:SetAlpha(settings.opacity)
  titleLabel.style:SetFontSize(settings.fontSize + 2)
  titleLabel.style:SetColor(0.95, 0.83, 0.58, 1)
  accentBar:SetColor(0.78, 0.48 + settings.accent * 0.32, 0.22 + settings.accent * 0.48, 0.95)
  local visibleRows = 0
  for index, row in ipairs(rows) do
    if row:IsVisible() then
      visibleRows = visibleRows + 1
    end
    row:SetExtent(settings.width - 34, settings.fontSize + settings.rowGap + 9)
    row.style:SetFontSize(settings.fontSize)
    row:RemoveAllAnchors()
    row:AddAnchor("TOPLEFT", tracker, 19, 75 + ((index - 1) * (settings.fontSize + settings.rowGap + 9)))
  end
  tracker:SetExtent(settings.width, 77 + (visibleRows * (settings.fontSize + settings.rowGap + 9)))
  accentBar:RemoveAllAnchors()
  accentBar:AddAnchor("TOPLEFT", tracker, 0, 0)
  accentBar:AddAnchor("BOTTOMLEFT", tracker, 0, 0)
  accentBar:SetExtent(3, tracker:GetHeight())
  if background ~= nil then
    background:SetColor(0.025, 0.045, 0.055, settings.backgroundOpacity)
  end
end

local function CreateLabel(parent, name, text, fontSize, color)
  local label = parent:CreateChildWidget("label", name, 0, true)
  label:SetExtent(260, fontSize + 10)
  label.style:SetAlign(ALIGN_LEFT)
  label.style:SetFontSize(fontSize)
  label.style:SetColor(color[1], color[2], color[3], color[4] or 1)
  label:SetText(text)
  return label
end

local function CreateButton(parent, name, text, width, onClick)
  local button = parent:CreateChildWidget("button", name, 0, true)
  button:SetStyle("text_default")
  button:SetAutoResize(false)
  button:SetExtent(width, 26)
  button:SetText(text)
  button:SetHandler("OnClick", function(_, mouseButton)
    if mouseButton == "RightButton" then
      return
    end
    onClick()
  end)
  return button
end

local function RefreshQuests()
  if X2Quest == nil or X2Quest.GetActiveQuestListCount == nil then
    statusLabel:SetText("Quest API unavailable")
    return
  end

  local quests = {}
  local ok, count = pcall(function()
    return X2Quest:GetActiveQuestListCount()
  end)
  if not ok or type(count) ~= "number" then
    statusLabel:SetText("Could not read quests")
    return
  end

  for index = 1, count do
    local questOk, questType = pcall(function()
      return X2Quest:GetActiveQuestType(index)
    end)
    if questOk and type(questType) == "number" then
      local title = "Quest " .. tostring(questType)
      if X2Quest.GetQuestContextMainTitle ~= nil then
        local titleOk, result = pcall(function()
          return X2Quest:GetQuestContextMainTitle(questType)
        end)
        if titleOk and type(result) == "string" and result ~= "" then
          title = result
        end
      end
      local completed = false
      if X2Quest.IsCompleted ~= nil then
        local completionOk, result = pcall(function()
          return X2Quest:IsCompleted(questType)
        end)
        completed = completionOk and result == true
      end
      if settings.showCompleted or not completed then
        quests[#quests + 1] = { index = index, id = questType, title = title, completed = completed }
      end
    end
  end

  for index = #quests + 1, #rows do
    rows[index]:Show(false)
  end

  for index, quest in ipairs(quests) do
    local row = rows[index]
    if row == nil then
      row = CreateLabel(tracker, "questRow" .. tostring(index), "", settings.fontSize, { 0.90, 0.90, 0.88, 1 })
      row:EnablePick(true)
      row:SetHandler("OnClick", function(self, mouseButton)
        if mouseButton == "RightButton" or self.questIndex == nil then
          return
        end
        if X2Quest ~= nil and X2Quest.SetTrackingActiveQuest ~= nil then
          pcall(function()
            X2Quest:SetTrackingActiveQuest(self.questIndex)
          end)
          RefreshQuests()
        end
      end)
      rows[index] = row
    end
    row.questIndex = quest.index
    local mark = quest.completed and "  ·  Complete" or ""
    row:SetText(quest.title .. mark)
    row.style:SetColor(quest.completed and 0.60 or 0.88, quest.completed and 0.82 or 0.88, quest.completed and 0.62 or 0.84, 1)
    row:Show(true)
  end

  statusLabel:SetText(#quests == 0 and "No active quests" or (tostring(#quests) .. " active quest" .. (#quests == 1 and "" or "s") .. "  ·  click a quest to track"))
  ApplyStyle()
end

local function UpdateSettingsText()
  settingsStatus:SetText(string.format("Width %d    Text %d    Spacing %d    Opacity %d%%", settings.width, settings.fontSize, settings.rowGap, math.floor(settings.opacity * 100)))
end

local function ChangeSetting(key, amount, minValue, maxValue)
  settings[key] = Clamp(settings[key] + amount, minValue, maxValue)
  SaveSettings()
  ApplyStyle()
  UpdateSettingsText()
  statusLabel:SetText("Appearance saved · press Refresh to update quests")
end

local function ToggleSettings(show)
  if settingsWindow == nil then
    return
  end
  settingsWindow:Show(show == nil and not settingsWindow:IsVisible() or show)
end

local function ToggleTracker(show)
  if tracker == nil then
    return
  end
  tracker:Show(show == nil and not tracker:IsVisible() or show)
end

tracker = CreateEmptyWindow("wayfinderTracker", "UIParent")
DebugPrint("startup: tracker window created")
tracker:SetExtent(settings.width, 220)
tracker:SetUILayer("system")
tracker:Enable(true)
tracker:Clickable(true)
tracker:EnableDrag(true)
ApplyPosition()
tracker:Show(false)

local launcherButton = CreateSimpleButton("Wayfinder", 700, -380)
DebugPrint("startup: launcher created")
launcherButton:SetHandler("OnClick", function()
  local show = not tracker:IsVisible()
  tracker:Show(show)
  if show then
    tracker:Raise()
  end
end)

background = tracker:CreateColorDrawable(0.025, 0.045, 0.055, settings.backgroundOpacity, "background")
DebugPrint("startup: tracker background created")
background:AddAnchor("TOPLEFT", tracker, 0, 0)
background:AddAnchor("BOTTOMRIGHT", tracker, 0, 0)

accentBar = tracker:CreateColorDrawable(0.78, 0.59, 0.48, 0.95, "artwork")
accentBar:AddAnchor("TOPLEFT", tracker, 0, 0)
accentBar:SetExtent(3, 100)

titleLabel = CreateLabel(tracker, "title", "WAYFINDER", settings.fontSize + 2, { 0.95, 0.83, 0.58, 1 })
DebugPrint("startup: tracker title created")
titleLabel:SetExtent(settings.width - 146, 26)
titleLabel:AddAnchor("TOPLEFT", tracker, 17, 13)

local refreshButton = CreateButton(tracker, "refreshButton", "Refresh", 54, RefreshQuests)
refreshButton:AddAnchor("TOPRIGHT", tracker, -78, 8)
local settingsButton = CreateButton(tracker, "settingsButton", "⚙", 30, function() ToggleSettings(true) end)
settingsButton:AddAnchor("TOPRIGHT", tracker, -42, 8)
statusLabel = CreateLabel(tracker, "status", "Press Refresh to load quests", 11, { 0.67, 0.73, 0.73, 1 })
DebugPrint("startup: tracker controls created")
statusLabel:SetExtent(settings.width - 34, 18)
statusLabel:AddAnchor("TOPLEFT", tracker, 18, 43)

tracker:SetHandler("OnDragStart", function()
  if settings.locked then
    return false
  end
  tracker:StartMoving()
  return true
end)
tracker:SetHandler("OnDragStop", function()
  tracker:StopMovingOrSizing()
  local x, y = tracker:GetOffset()
  local scale = UIParent:GetUIScale()
  settings.x = x * scale
  settings.y = y * scale
  SaveSettings()
end)

settingsWindow = CreateEmptyWindow("wayfinderSettings", "UIParent")
DebugPrint("startup: settings window created")
settingsWindow:SetExtent(350, 430)
settingsWindow:SetUILayer("system")
settingsWindow:Enable(true)
settingsWindow:Clickable(true)
settingsWindow:EnableDrag(true)
settingsWindow:AddAnchor("CENTER", "UIParent", 0, 0)
settingsWindow:Show(false)
local settingsBackground = settingsWindow:CreateColorDrawable(0, 0.05, 0.08, 0.96, "background")
settingsBackground:AddAnchor("TOPLEFT", settingsWindow, 0, 0)
settingsBackground:AddAnchor("BOTTOMRIGHT", settingsWindow, 0, 0)
local settingsTitle = CreateLabel(settingsWindow, "settingsTitle", "WAYFINDER  /  CUSTOMIZE", 15, { 0.95, 0.83, 0.58, 1 })
settingsTitle:SetExtent(300, 28)
settingsTitle:AddAnchor("TOPLEFT", settingsWindow, 18, 14)
settingsStatus = CreateLabel(settingsWindow, "settingsStatus", "", 11, { 0.78, 0.83, 0.81, 1 })
settingsStatus:SetExtent(320, 20)
settingsStatus:AddAnchor("TOPLEFT", settingsWindow, 18, 50)

local function AddSettingRow(y, labelText, key, step, minValue, maxValue)
  local label = CreateLabel(settingsWindow, "settingLabel" .. tostring(y), labelText, 12, { 0.84, 0.86, 0.83, 1 })
  label:AddAnchor("TOPLEFT", settingsWindow, 20, y + 4)
  local down = CreateButton(settingsWindow, "settingDown" .. tostring(y), "−", 30, function() ChangeSetting(key, -step, minValue, maxValue) end)
  down:AddAnchor("TOPRIGHT", settingsWindow, -56, y)
  local up = CreateButton(settingsWindow, "settingUp" .. tostring(y), "+", 30, function() ChangeSetting(key, step, minValue, maxValue) end)
  up:AddAnchor("TOPRIGHT", settingsWindow, -18, y)
end

AddSettingRow(82, "Tracker width", "width", 10, 220, 500)
AddSettingRow(119, "Text size", "fontSize", 1, 10, 20)
AddSettingRow(156, "Row spacing", "rowGap", 1, 0, 14)
AddSettingRow(193, "Opacity", "opacity", 0.05, 0.35, 1)
AddSettingRow(230, "Accent tint", "accent", 0.05, 0, 1)
AddSettingRow(267, "Panel opacity", "backgroundOpacity", 0.05, 0.25, 1)

local lockButton
lockButton = CreateButton(settingsWindow, "lockButton", "Lock position", 145, function()
  settings.locked = not settings.locked
  SaveSettings()
  lockButton:SetText(settings.locked and "Unlock position" or "Lock position")
end)
lockButton:AddAnchor("TOPLEFT", settingsWindow, 20, 310)

local completedButton
completedButton = CreateButton(settingsWindow, "completedButton", "Completed: shown", 170, function()
  settings.showCompleted = not settings.showCompleted
  completedButton:SetText(settings.showCompleted and "Completed: shown" or "Completed: hidden")
  SaveSettings()
  statusLabel:SetText("Filter saved · press Refresh to update quests")
end)
completedButton:AddAnchor("TOPLEFT", settingsWindow, 175, 310)

local resetButton = CreateButton(settingsWindow, "resetButton", "Reset appearance", 145, function()
  for key, value in pairs(DEFAULTS) do
    settings[key] = value
  end
  settings.displayMode = "alongside"
  ApplyPosition()
  ApplyStyle()
  SaveSettings()
  lockButton:SetText("Lock position")
  completedButton:SetText("Completed: shown")
  UpdateSettingsText()
  statusLabel:SetText("Settings reset · press Refresh to update quests")
end)
resetButton:AddAnchor("TOPLEFT", settingsWindow, 20, 350)

local closeSettings = CreateButton(settingsWindow, "closeSettings", "Done", 90, function() ToggleSettings(false) end)
closeSettings:AddAnchor("TOPRIGHT", settingsWindow, -18, 350)

local previewButton = CreateButton(settingsWindow, "previewButton", "Preview", 90, function()
  _G.Wayfinder.Preview()
end)
previewButton:AddAnchor("TOPLEFT", settingsWindow, 20, 390)

settingsWindow:SetHandler("OnDragStart", function() settingsWindow:StartMoving(); return true end)
settingsWindow:SetHandler("OnDragStop", function() settingsWindow:StopMovingOrSizing() end)
DebugPrint("startup: settings controls created")
_G.Wayfinder = {
  Refresh = RefreshQuests,
  Toggle = ToggleTracker,
  Settings = ToggleSettings,
  Preview = function()
    previewMode = not previewMode
    previewButton:SetText(previewMode and "Live quests" or "Preview")
    if not previewMode then
      statusLabel:SetText("Press Refresh to load quests")
      return
    end
    statusLabel:SetText("PREVIEW  ·  style sample")
    for index = 1, 3 do
      if rows[index] == nil then
        rows[index] = CreateLabel(tracker, "previewRow" .. tostring(index), "", settings.fontSize, { 0.90, 0.90, 0.88, 1 })
      end
      rows[index].questIndex = nil
      rows[index]:SetText(({ "A Road Through Two Crowns", "Gather 6 × Blue Salt Clams", "Return to the Trading Post  ·  Complete" })[index])
      rows[index]:Show(true)
    end
    ApplyStyle()
  end,
}

lockButton:SetText(settings.locked and "Unlock position" or "Lock position")
completedButton:SetText(settings.showCompleted and "Completed: shown" or "Completed: hidden")
UpdateSettingsText()

DebugPrint("startup: applying final style")
ApplyStyle()
tracker:Show(true)
previewMode = true
previewButton:SetText("Live quests")
statusLabel:SetText("TEST PREVIEW  ·  sample rows; press Refresh for live quests")
for index = 1, 3 do
  if rows[index] == nil then
    rows[index] = CreateLabel(tracker, "previewRow" .. tostring(index), "", settings.fontSize, { 0.90, 0.90, 0.88, 1 })
  end
  rows[index].questIndex = nil
  rows[index]:SetText(({ "A Road Through Two Crowns", "Gather 6 × Blue Salt Clams", "Return to the Trading Post  ·  Complete" })[index])
  rows[index]:Show(true)
end
ApplyStyle()
DebugPrint("startup: complete (visual test preview shown)")
end

local initOk, initErr = pcall(Initialize)
if not initOk then
  DebugPrint("init failed: " .. tostring(initErr))
end
