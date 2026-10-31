local function DebugPrint(message)
  local text = "[Wayfinder] " .. tostring(message)
  local printed = false
  if type(aaprint) == "function" then
    printed = pcall(aaprint, text)
  end
  if not printed and X2Chat ~= nil then
    pcall(function()
      X2Chat:DispatchChatMessage(CMF_SYSTEM, text)
    end)
  end
end

local function Initialize()
local BUILD_ID = "WF-20261029.29"
local BUILD_MARKER = "WF" .. tostring(BUILD_ID:match("(%d+)$") or "?")
if API_TYPE == nil then
  ADDON:ImportAPI(8)
  X2Chat:DispatchChatMessage(CMF_SYSTEM, "Wayfinder requires the shared globals folder.")
  return
end

ADDON:ImportObject(OBJECT_TYPE.TEXT_STYLE)
ADDON:ImportObject(OBJECT_TYPE.BUTTON)
ADDON:ImportObject(OBJECT_TYPE.X2_EDITBOX)
ADDON:ImportObject(OBJECT_TYPE.DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.NINE_PART_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.COLOR_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.EMPTY_WIDGET)
ADDON:ImportObject(OBJECT_TYPE.WINDOW)
ADDON:ImportObject(OBJECT_TYPE.LABEL)
ADDON:ImportAPI(API_TYPE.CHAT.id)
ADDON:ImportAPI(API_TYPE.QUEST.id)
ADDON:ImportAPI(API_TYPE.INPUT.id)
ADDON:ImportAPI(API_TYPE.SOUND.id)

DebugPrint("startup: " .. BUILD_ID .. " APIs and widget types imported")

local SAVE_KEY = "wayfinder_settings_v1"
local DEFAULTS = {
  x = 0,
  y = 0,
  settingsWindowX = 0,
  settingsWindowY = 0,
  settingsWindowPositionSet = false,
  width = 300,
  height = 398,
  minimized = false,
  heightCustomized = false,
  rowGap = 5,
  fontSize = 13,
  titleFontSize = 15,
  continentFontSize = 15,
  zoneFontSize = 14,
  completedFontSize = 13,
  objectiveFontSize = 12,
  opacity = 0.94,
  accent = 0.30,
  backgroundOpacity = 0.90,
  borderSize = 1,
  borderColor = { 0.34, 0.43, 0.61 },
  locked = false,
  visible = true,
  hideDefaultTracker = false,
  hideDefaultLog = false,
  activeProfile = "Default",
  profiles = {},
  showCompleted = true,
  showCompletionLabel = true,
  showObjectives = false,
  showQuestIds = false,
  keyboardNavigation = false,
  pinnedOnly = false,
  collapsedSections = {},
  pinnedQuestIds = {},
  sortMode = "journal",
  autoTrackAccepted = false,
  notifyQuestCompletion = false,
  notifyQuestSound = false,
  titleColor = { 0.95, 0.83, 0.58 },
  continentColor = { 0.95, 0.78, 0.42 },
  zoneColor = { 0.70, 0.80, 0.92 },
  questColor = { 0.88, 0.88, 0.84 },
  completedColor = { 0.60, 0.82, 0.62 },
  objectiveColor = { 0.70, 0.78, 0.82 },
  displayMode = "alongside",
}

local function CopySettingValue(value)
  if type(value) ~= "table" then
    return value
  end
  local copy = {}
  for key, item in pairs(value) do
    copy[key] = type(item) == "table" and CopySettingValue(item) or item
  end
  return copy
end

local settings = {}
for key, value in pairs(DEFAULTS) do
  settings[key] = CopySettingValue(value)
end

local saved = ADDON:LoadData(SAVE_KEY)
local savedSettingsVersion = type(saved) == "table" and tonumber(saved.settingsVersion) or 0
if type(saved) == "table" then
  for key, value in pairs(DEFAULTS) do
    if type(saved[key]) == type(value) then
      settings[key] = CopySettingValue(saved[key])
    end
  end
end
if savedSettingsVersion < 3 then
  -- Version 2 introduced a hidden-completed default. That persisted default
  -- can suppress every row on clients whose completion getter differs.
  settings.showCompleted = true
  if type(settings.profiles) == "table" then
    for _, profile in pairs(settings.profiles) do
      if type(profile) == "table" then
        profile.showCompleted = true
      end
    end
  end
end
settings.settingsVersion = 3
DebugPrint("startup: saved settings loaded")
settings.displayMode = "alongside" -- Replacement is not enabled until a supported method is verified.

local PROFILE_KEYS = {}
for key in pairs(DEFAULTS) do
  if key ~= "activeProfile" and key ~= "profiles" and key ~= "visible" and key ~= "displayMode" and key ~= "pinnedQuestIds"
      and key ~= "settingsWindowX" and key ~= "settingsWindowY" and key ~= "settingsWindowPositionSet" then
    PROFILE_KEYS[#PROFILE_KEYS + 1] = key
  end
end
table.sort(PROFILE_KEYS)
local PROFILE_KEY_SET = {}
for _, key in ipairs(PROFILE_KEYS) do
  PROFILE_KEY_SET[key] = true
end

local function IsValidProfileName(name)
  return type(name) == "string" and #name >= 1 and #name <= 24 and name:match("^[%w _%-]+$") ~= nil
end

local function CaptureProfile()
  local profile = {}
  for _, key in ipairs(PROFILE_KEYS) do
    profile[key] = CopySettingValue(settings[key])
  end
  return profile
end

if type(settings.profiles) ~= "table" then
  settings.profiles = {}
end
local validProfiles = {}
for name, profile in pairs(settings.profiles) do
  if IsValidProfileName(name) and type(profile) == "table" then
    local snapshot = {}
    for _, key in ipairs(PROFILE_KEYS) do
      if type(profile[key]) == type(DEFAULTS[key]) then
        snapshot[key] = CopySettingValue(profile[key])
      end
    end
    validProfiles[name] = snapshot
  end
end
settings.profiles = validProfiles
if not IsValidProfileName(settings.activeProfile) or settings.profiles[settings.activeProfile] == nil then
  settings.activeProfile = "Default"
end

local tracker
local settingsWindow
local questViewport
local rows = {}
local questScrollOffset = 0
local questRowHeight = 0
local questViewportHeight = 320
local visibleQuestCount = 0
local visibleRowCount = 0
local questContentHeight = 0
local trackerDragMode
local trackerResizeHandles = {}
local keyboardCursorIndex
local keyboardCursorQuestId
local titleLabel
local statusLabel
local diagnosticLabel
local filterDiagnosticLabel
local sampleDiagnosticLabel
local questSearchEdit
local questSearchText = ""
local previewButton
local accentBar
local background
local borderTop
local borderBottom
local borderLeft
local borderRight
local settingsStatus
local previewMode = false
local completionSoundButton
local keyboardNavigationButton
local questIdsButton
local trackerMinimizeButton
local trackerCloseButton

local function SaveSettings()
  if settings.profiles == nil then
    settings.profiles = {}
  end
  if IsValidProfileName(settings.activeProfile) then
    settings.profiles[settings.activeProfile] = CaptureProfile()
  end
  ADDON:ClearData(SAVE_KEY)
  ADDON:SaveData(SAVE_KEY, settings)
end

local function SetNativeQuestUIVisibility(category, visible)
  if ADDON == nil or ADDON.ShowContent == nil or category == nil then
    return false
  end
  local ok, result = pcall(function()
    return ADDON:ShowContent(category, visible == true)
  end)
  return ok and result ~= false
end

local function ApplyNativeQuestUISettings()
  -- Showing a UIC category can open its full panel (notably the quest log).
  -- On startup/event refreshes, only enforce opt-in hides. The settings
  -- buttons explicitly restore a component when the user asks for it.
  local trackerOk = not settings.hideDefaultTracker or SetNativeQuestUIVisibility(UIC_QUEST_NOTIFIER, false)
  local logOk = not settings.hideDefaultLog or SetNativeQuestUIVisibility(UIC_QUEST_LIST, false)
  return trackerOk and logOk
end

local function Clamp(value, minValue, maxValue)
  return math.max(minValue, math.min(maxValue, value))
end

local function IsValidActiveQuestCount(count)
  return type(count) == "number" and count == count and count >= 0 and count < math.huge and count == math.floor(count)
end

local function IsFiniteNumber(value)
  return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function IsValidQuestType(questType)
  return IsFiniteNumber(questType) and questType > 0 and questType == math.floor(questType)
end

local function FindActiveQuestIndex(questType)
  if not IsValidQuestType(questType) then
    return nil, "Invalid quest ID"
  end
  if X2Quest == nil or
      type(X2Quest.GetActiveQuestListCount) ~= "function" or
      type(X2Quest.GetActiveQuestType) ~= "function" then
    return nil, "Quest list API unavailable"
  end
  local countOk, count = pcall(function()
    return X2Quest:GetActiveQuestListCount()
  end)
  if not countOk or not IsValidActiveQuestCount(count) then
    return nil, "Quest list read failed"
  end
  local readErrors = 0
  for index = 1, count do
    local questOk, activeQuestType = pcall(function()
      return X2Quest:GetActiveQuestType(index)
    end)
    if questOk and activeQuestType == questType then
      return index
    elseif not questOk then
      readErrors = readErrors + 1
    end
  end
  if readErrors > 0 then
    return nil, "Quest index lookup failed"
  end
  return nil, "Quest is no longer active"
end

local function NormalizeNumber(value, fallback, minValue, maxValue)
  if type(value) ~= "number" or value ~= value then
    value = fallback
  end
  return Clamp(value, minValue, maxValue)
end

local function NormalizeSettings()
settings.x = NormalizeNumber(settings.x, DEFAULTS.x, -10000, 10000)
settings.y = NormalizeNumber(settings.y, DEFAULTS.y, -10000, 10000)
settings.settingsWindowX = NormalizeNumber(settings.settingsWindowX, DEFAULTS.settingsWindowX, -10000, 10000)
settings.settingsWindowY = NormalizeNumber(settings.settingsWindowY, DEFAULTS.settingsWindowY, -10000, 10000)
settings.width = NormalizeNumber(settings.width, DEFAULTS.width, 220, 500)
settings.height = NormalizeNumber(settings.height, DEFAULTS.height, 200, 780)
settings.rowGap = NormalizeNumber(settings.rowGap, DEFAULTS.rowGap, 0, 14)
settings.fontSize = NormalizeNumber(settings.fontSize, DEFAULTS.fontSize, 10, 22)
for _, fontKey in ipairs({ "titleFontSize", "continentFontSize", "zoneFontSize", "completedFontSize", "objectiveFontSize" }) do
  settings[fontKey] = NormalizeNumber(settings[fontKey], DEFAULTS[fontKey], 10, 22)
end
settings.opacity = NormalizeNumber(settings.opacity, DEFAULTS.opacity, 0.35, 1)
settings.accent = NormalizeNumber(settings.accent, DEFAULTS.accent, 0, 1)
settings.backgroundOpacity = NormalizeNumber(settings.backgroundOpacity, DEFAULTS.backgroundOpacity, 0.25, 1)
settings.borderSize = NormalizeNumber(settings.borderSize, DEFAULTS.borderSize, 0, 8)
for _, colorKey in ipairs({ "titleColor", "continentColor", "zoneColor", "questColor", "completedColor", "objectiveColor", "borderColor" }) do
  local savedColor = settings[colorKey]
  local defaultColor = DEFAULTS[colorKey]
  local color = {}
  for channel = 1, 3 do
    local value = type(savedColor) == "table" and savedColor[channel] or nil
    color[channel] = NormalizeNumber(value, defaultColor[channel], 0, 1)
  end
  settings[colorKey] = color
end
settings.heightCustomized = settings.heightCustomized == true
settings.minimized = settings.minimized == true
settings.settingsWindowPositionSet = settings.settingsWindowPositionSet == true
settings.locked = settings.locked == true
-- A manager reload should always reopen the tracker; manual hiding is session-only.
settings.visible = true
settings.hideDefaultTracker = settings.hideDefaultTracker == true
settings.hideDefaultLog = settings.hideDefaultLog == true
settings.showCompleted = settings.showCompleted == true
settings.showCompletionLabel = settings.showCompletionLabel ~= false
settings.showObjectives = settings.showObjectives == true
settings.showQuestIds = settings.showQuestIds == true
settings.keyboardNavigation = settings.keyboardNavigation == true
settings.pinnedOnly = settings.pinnedOnly == true
settings.autoTrackAccepted = settings.autoTrackAccepted == true
settings.notifyQuestCompletion = settings.notifyQuestCompletion == true
settings.notifyQuestSound = settings.notifyQuestSound == true
if type(settings.collapsedSections) ~= "table" then
  settings.collapsedSections = {}
end
if type(settings.pinnedQuestIds) ~= "table" then
  settings.pinnedQuestIds = {}
end
if settings.sortMode ~= "journal" and settings.sortMode ~= "alphabetical" then
  settings.sortMode = DEFAULTS.sortMode
end
if type(settings.profiles) ~= "table" then
  settings.profiles = {}
end
if not IsValidProfileName(settings.activeProfile) then
  settings.activeProfile = "Default"
end
end
NormalizeSettings()
SaveSettings()

local function ResolvePosition()
  -- Saved coordinates are in GetOffset/AddAnchor UI units. Dividing here
  -- applies UI scale twice and makes a moved tracker jump after reload.
  return settings.x, settings.y
end

local function ApplyPosition()
  local x, y = ResolvePosition()
  tracker:RemoveAllAnchors()
  tracker:AddAnchor("TOPLEFT", "UIParent", x, y)
end

local function CorrectWidgetPosition(widget, currentX, currentY)
  if widget == nil or UIParent == nil or type(UIParent.GetUIScale) ~= "function" or type(widget.CorrectOffsetByScreen) ~= "function" then
    return nil, nil, false
  end
  local offsetOk, pixelX, pixelY = pcall(function()
    return widget:CorrectOffsetByScreen()
  end)
  if not offsetOk or not IsFiniteNumber(pixelX) or not IsFiniteNumber(pixelY) then
    return nil, nil, false
  end
  local scaleOk, scale = pcall(function()
    return UIParent:GetUIScale()
  end)
  if not scaleOk or not IsFiniteNumber(scale) or scale <= 0 then
    return nil, nil, false
  end
  local x = pixelX / scale
  local y = pixelY / scale
  if not IsFiniteNumber(x) or not IsFiniteNumber(y) then
    return nil, nil, false
  end
  local changed = not IsFiniteNumber(currentX) or not IsFiniteNumber(currentY) or math.abs(x - currentX) >= 0.5 or math.abs(y - currentY) >= 0.5
  if changed then
    widget:RemoveAllAnchors()
    widget:AddAnchor("TOPLEFT", "UIParent", x, y)
  end
  return x, y, changed
end

local function SaveSettingsWindowPosition(x, y)
  if not IsFiniteNumber(x) or not IsFiniteNumber(y) then
    return false
  end
  settings.settingsWindowX = x
  settings.settingsWindowY = y
  settings.settingsWindowPositionSet = true
  SaveSettings()
  return true
end

local function CorrectTrackerPosition()
  local x, y, changed = CorrectWidgetPosition(tracker, settings.x, settings.y)
  if not changed then
    return false
  end
  settings.x = x
  settings.y = y
  SaveSettings()
  return true
end

local function SetUtilityWindowDragHandlers(window, onPositionChanged)
  window:SetHandler("OnDragStart", function(self)
    self:StartMoving()
    return true
  end)
  window:SetHandler("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local x, y = CorrectWidgetPosition(self)
    if type(onPositionChanged) == "function" then
      onPositionChanged(x, y)
    end
  end)
end

local function UpdateTrackerResizeHandles()
  if tracker == nil then
    return
  end
  local width = tracker:GetWidth()
  local height = tracker:GetHeight()
  local edgeSize = 8
  local cornerSize = 12
  for _, handle in ipairs(trackerResizeHandles) do
    local x, y, handleWidth, handleHeight
    if handle.edge == "top" then
      x, y, handleWidth, handleHeight = cornerSize, 0, width - (cornerSize * 2), edgeSize
    elseif handle.edge == "bottom" then
      x, y, handleWidth, handleHeight = cornerSize, height - edgeSize, width - (cornerSize * 2), edgeSize
    elseif handle.edge == "left" then
      x, y, handleWidth, handleHeight = 0, cornerSize, edgeSize, height - (cornerSize * 2)
    elseif handle.edge == "right" then
      x, y, handleWidth, handleHeight = width - edgeSize, cornerSize, edgeSize, height - (cornerSize * 2)
    elseif handle.edge == "topLeft" then
      x, y, handleWidth, handleHeight = 0, 0, cornerSize, cornerSize
    elseif handle.edge == "topRight" then
      x, y, handleWidth, handleHeight = width - cornerSize, 0, cornerSize, cornerSize
    elseif handle.edge == "bottomLeft" then
      x, y, handleWidth, handleHeight = 0, height - cornerSize, cornerSize, cornerSize
    else
      x, y, handleWidth, handleHeight = width - cornerSize, height - cornerSize, cornerSize, cornerSize
    end
    handle.widget:RemoveAllAnchors()
    handle.widget:SetExtent(handleWidth, handleHeight)
    handle.widget:AddAnchor("TOPLEFT", tracker, x, y)
    handle.widget:Show(not settings.minimized)
  end
end

local function ApplyStyle(preserveTrackerExtent)
  if tracker == nil then
    return
  end
  tracker:SetAlpha(settings.opacity)
  titleLabel.style:SetFontSize(settings.titleFontSize)
  local titleColor = settings.titleColor
  titleLabel.style:SetColor(titleColor[1], titleColor[2], titleColor[3], 1)
  titleLabel:SetExtent(settings.width - 34, 28)
  if trackerCloseButton ~= nil then
    titleLabel:SetExtent(math.max(80, settings.width - 78), 28)
  end
  statusLabel:SetExtent(settings.width - 34, 18)
  if questSearchEdit ~= nil then
    questSearchEdit:SetExtent(settings.width - 36, 24)
  end
  if diagnosticLabel ~= nil then
    diagnosticLabel:SetExtent(settings.width - 34, 16)
  end
  if filterDiagnosticLabel ~= nil then
    filterDiagnosticLabel:SetExtent(settings.width - 34, 16)
  end
  if sampleDiagnosticLabel ~= nil then
    sampleDiagnosticLabel:SetExtent(settings.width - 34, 16)
  end
  accentBar:SetColor(0.78, 0.48 + settings.accent * 0.32, 0.22 + settings.accent * 0.48, 0.95)
  local largestFontSize = math.max(settings.fontSize, settings.continentFontSize, settings.zoneFontSize, settings.completedFontSize, settings.objectiveFontSize)
  questRowHeight = largestFontSize + settings.rowGap + 9
  questContentHeight = 0
  for index, row in ipairs(rows) do
    local rowHeight = row.isHeader and (questRowHeight + 3) or questRowHeight
    row:SetExtent(settings.width - 38, rowHeight)
    local fontSize = settings.fontSize
    if row.isContinentHeader then
      fontSize = settings.continentFontSize
    elseif row.isZoneHeader then
      fontSize = settings.zoneFontSize
    elseif row.isObjective then
      fontSize = settings.objectiveFontSize
    elseif row.colorKey == "completedColor" then
      fontSize = settings.completedFontSize
    end
    row.style:SetFontSize(fontSize)
    local color = settings[row.colorKey or "questColor"] or settings.questColor
    row.style:SetColor(color[1], color[2], color[3], 1)
    if index <= visibleRowCount then
      row:RemoveAllAnchors()
      row:AddAnchor("TOPLEFT", questViewport, 1, questContentHeight)
      questContentHeight = questContentHeight + rowHeight
    else
      row:Show(false)
    end
  end
  if settings.heightCustomized then
    questViewportHeight = math.max(76, settings.height - 158)
  else
    questViewportHeight = math.min(696, math.max(76, 3 * questRowHeight, questContentHeight))
  end
  questViewport:SetExtent(settings.width - 36, questViewportHeight)
  local maxOffset = math.max(0, questContentHeight - questViewportHeight)
  questScrollOffset = Clamp(questScrollOffset, 0, maxOffset)
  questViewport:ChangeChildAnchorByScrollValue("vert", questScrollOffset)
  if not preserveTrackerExtent then
    tracker:SetExtent(settings.width, settings.minimized and 62 or (158 + questViewportHeight))
  end
  for _, widget in ipairs({ questSearchEdit, statusLabel, diagnosticLabel, filterDiagnosticLabel, sampleDiagnosticLabel, questViewport }) do
    if widget ~= nil then
      widget:Show(not settings.minimized)
    end
  end
  if trackerMinimizeButton ~= nil then
    trackerMinimizeButton:SetText(settings.minimized and "+" or "-")
    trackerMinimizeButton:SetAutoResize(false)
    trackerMinimizeButton:SetExtent(18, 18)
  end
  if trackerCloseButton ~= nil then
    trackerCloseButton:SetAutoResize(false)
    trackerCloseButton:SetExtent(18, 18)
  end
  UpdateTrackerResizeHandles()
  accentBar:RemoveAllAnchors()
  accentBar:AddAnchor("TOPLEFT", tracker, 0, 0)
  accentBar:AddAnchor("BOTTOMLEFT", tracker, 0, 0)
  accentBar:SetExtent(3, tracker:GetHeight())
  if background ~= nil then
    background:SetColor(0.025, 0.045, 0.055, settings.backgroundOpacity)
  end
  if borderTop ~= nil then
    local color = settings.borderColor
    local size = settings.borderSize
    borderTop:SetColor(color[1], color[2], color[3], 1)
    borderBottom:SetColor(color[1], color[2], color[3], 1)
    borderLeft:SetColor(color[1], color[2], color[3], 1)
    borderRight:SetColor(color[1], color[2], color[3], 1)
    borderTop:SetExtent(settings.width, math.max(size, 1))
    borderBottom:SetExtent(settings.width, math.max(size, 1))
    borderLeft:SetExtent(math.max(size, 1), tracker:GetHeight())
    borderRight:SetExtent(math.max(size, 1), tracker:GetHeight())
    local showBorder = size > 0
    borderTop:Show(showBorder)
    borderBottom:Show(showBorder)
    borderLeft:Show(showBorder)
    borderRight:Show(showBorder)
  end
  CorrectTrackerPosition()
end

local function CreateLabel(parent, name, text, fontSize, color)
  local label = parent:CreateChildWidget("label", name, 0, true)
  label:SetExtent(260, fontSize + 10)
  label:SetAutoResize(false)
  label.style:SetAlign(ALIGN_LEFT)
  label.style:SetFontSize(fontSize)
  label.style:SetEllipsis(true)
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

local function ScrollQuestList(direction)
  if questViewport == nil or questRowHeight <= 0 then
    return
  end
  local maxOffset = math.max(0, questContentHeight - questViewportHeight)
  questScrollOffset = Clamp(questScrollOffset + (direction * questRowHeight), 0, maxOffset)
  questViewport:ChangeChildAnchorByScrollValue("vert", questScrollOffset)
end

local function GetQuestTitle(questType)
  if type(X2Quest.GetQuestContextMainTitle) == "function" then
    local ok, title = pcall(function()
      return X2Quest:GetQuestContextMainTitle(questType)
    end)
    if ok and type(title) == "string" then
      title = title:gsub("[%c]", " "):gsub("^%s+", ""):gsub("%s+$", "")
      if title ~= "" then
        return title, false
      end
    end
  end
  return "Quest " .. tostring(questType), true
end

local function GetActiveQuestObjectiveTexts(questType)
  local objectives = {}
  if type(X2Quest.GetActiveQuestObjectiveText) ~= "function" then
    return objectives, 1
  end
  local maxObjectives = 10
  if IsValidActiveQuestCount(MAX_QUEST_OBJECTIVE) then
    maxObjectives = math.min(MAX_QUEST_OBJECTIVE, 10)
  end
  for index = 1, maxObjectives do
    local ok, objective = pcall(function()
      return X2Quest:GetActiveQuestObjectiveText(questType, index)
    end)
    if not ok then
      return objectives, 1
    end
    if objective == false or objective == nil then
      break
    end
    if type(objective) ~= "string" then
      return objectives, 1
    end
    objective = objective:gsub("[%c]", " "):gsub("^%s+", ""):gsub("%s+$", "")
    if objective ~= "" then
      objectives[#objectives + 1] = objective
    end
  end
  return objectives, 0
end

local function GetQuestCatalogEntry(questType, title)
  local catalog = _G.WAYFINDER_QUEST_CATALOG
  local entry = type(catalog) == "table" and catalog[questType] or nil
  if type(entry) == "table" and entry[1] == title then
    return entry
  end
  return nil
end

local function GetQuestGeography(catalogEntry)
  if type(catalogEntry) == "table" then
    return catalogEntry[3] or "Other", catalogEntry[2] or "Unknown Zone"
  end
  return "Other", "Unknown Zone"
end

local QUEST_API_SURFACE_GROUPS = {
  { marker = "F", methods = { "IsHiddenQuest", "IsTodayQuest", "IsSagaQuest", "IsPublicQuest" } },
  { marker = "J", methods = { "IsProgressQuestInJournal", "IsReadyQuestInJournal" } },
  { marker = "L", methods = { "IsMainQuest", "GetMainQuestListCount", "GetMainQuestType" } },
  { marker = "S", methods = { "GetActiveQuestListStatus", "GetActiveQuestListStatusByType" } },
}

local function GetQuestAPISurfaceFlags()
  local flags = {}
  for _, group in ipairs(QUEST_API_SURFACE_GROUPS) do
    local present = X2Quest ~= nil
    for _, methodName in ipairs(group.methods) do
      if not present or type(X2Quest[methodName]) ~= "function" then
        present = false
        break
      end
    end
    flags[#flags + 1] = group.marker .. (present and "+" or "-")
  end
  return table.concat(flags, " ")
end

local lastEmptyScanSignature
local lastInvalidTypeSignature
local RefreshQuests

local function FindKeyboardQuestRow(startIndex, step)
  local rowCount = #rows
  if rowCount == 0 then return nil end
  local index = startIndex
  for _ = 1, rowCount do
    index = ((index - 1 + step) % rowCount) + 1
    if rows[index] ~= nil and rows[index].isQuestRow then
      return index
    end
  end
  return nil
end

local function UpdateKeyboardCursorText()
  for index, row in ipairs(rows) do
    if row.isQuestRow and row.baseText ~= nil then
      local text = settings.keyboardNavigation and index == keyboardCursorIndex and ("› " .. row.baseText) or row.baseText
      row:SetText(text)
    end
  end
end

local function ScrollKeyboardCursorIntoView()
  if keyboardCursorIndex == nil or questViewport == nil then return end
  local rowTop = 0
  for index = 1, keyboardCursorIndex - 1 do
    local row = rows[index]
    if row ~= nil then
      rowTop = rowTop + questRowHeight + (row.isHeader and 3 or 0)
    end
  end
  local row = rows[keyboardCursorIndex]
  local rowBottom = rowTop + questRowHeight + (row ~= nil and row.isHeader and 3 or 0)
  if rowTop < questScrollOffset then
    questScrollOffset = rowTop
  elseif rowBottom > questScrollOffset + questViewportHeight then
    questScrollOffset = rowBottom - questViewportHeight
  end
  questScrollOffset = Clamp(questScrollOffset, 0, math.max(0, questContentHeight - questViewportHeight))
  questViewport:ChangeChildAnchorByScrollValue("vert", questScrollOffset)
end

local function HandleQuestRowAction(self, mouseButton)
  if self.isObjective then return end
  if self.isQuestRow and self.questDisplayIndex ~= nil then
    keyboardCursorIndex = self.questDisplayIndex
    keyboardCursorQuestId = self.questId
    UpdateKeyboardCursorText()
    if settings.keyboardNavigation and mouseButton == "LeftButton" then
      statusLabel:SetText("Selected: " .. tostring(self.baseText or "quest"))
      return
    end
  end
  if mouseButton == "RightButton" then
    if not self.isQuestRow or self.questId == nil then return end
    local key = tostring(self.questId)
    local pinned = settings.pinnedQuestIds[key] == true
    if pinned then
      settings.pinnedQuestIds[key] = nil
    else
      settings.pinnedQuestIds[key] = true
    end
    SaveSettings()
    statusLabel:SetText(pinned and "Quest unpinned" or "Quest pinned")
    RefreshQuests()
    return
  end
  if self.collapseKey ~= nil then
    settings.collapsedSections[self.collapseKey] = not self.collapsed
    SaveSettings()
    RefreshQuests()
    return
  end
  local questId = self.questId
  if questId == nil then
    statusLabel:SetText("This row has no quest to track")
    return
  end
  if X2Quest ~= nil and type(X2Quest.SetTrackingActiveQuest) == "function" then
    local activeIndex, lookupError = FindActiveQuestIndex(questId)
    if activeIndex == nil then
      DebugPrint("tracking lookup failed for quest " .. tostring(questId) .. ": " .. tostring(lookupError))
      statusLabel:SetText(lookupError or "Could not find this quest")
      return
    end
    local ok = pcall(function()
      X2Quest:SetTrackingActiveQuest(activeIndex)
    end)
    if ok then
      RefreshQuests()
      statusLabel:SetText("Tracking request sent")
    else
      DebugPrint("tracking selection failed for quest " .. tostring(questId))
      statusLabel:SetText("Could not select that quest for tracking")
    end
  else
    statusLabel:SetText("Quest tracking API unavailable")
  end
end

local function ClearQuestResults(message, detail)
  for _, row in ipairs(rows) do
    row:Show(false)
    row.isQuestRow = false
    row.baseText = nil
  end
  keyboardCursorIndex = nil
  keyboardCursorQuestId = nil
  visibleQuestCount = 0
  visibleRowCount = 0
  questContentHeight = 0
  questScrollOffset = 0
  if questViewport ~= nil then
    questViewport:ChangeChildAnchorByScrollValue("vert", 0)
  end
  statusLabel:SetText(BUILD_MARKER .. " · " .. message)
  diagnosticLabel:SetText(BUILD_MARKER .. " A? T? C? I? U? " .. GetQuestAPISurfaceFlags())
  filterDiagnosticLabel:SetText(detail or "E? R? H? M? Q? X? O? V? D? P? S?")
  if sampleDiagnosticLabel ~= nil then
    sampleDiagnosticLabel:SetText("")
    sampleDiagnosticLabel:Show(false)
  end
  lastEmptyScanSignature = nil
  lastInvalidTypeSignature = nil
  ApplyStyle()
  DebugPrint("quest scan unavailable: " .. message)
end

RefreshQuests = function()
  previewMode = false
  if previewButton ~= nil then
    previewButton:SetText("Preview")
  end
  if tracker ~= nil then
    settings.visible = true
    tracker:Show(true)
    tracker:Raise()
  end
  if X2Quest == nil or X2Quest.GetActiveQuestListCount == nil then
    ClearQuestResults("Quest API unavailable")
    return
  end

  local quests = {}
  local seenQuestTypes = {}
  local activeQuestTypeErrorCount = 0
  local invalidQuestTypeCount = 0
  local duplicateQuestTypeCount = 0
  local invalidQuestTypeSamples = {}
  local activeValidTypeCount = 0
  local objectiveReadErrorCount = 0
  local titleFallbackCount = 0
  local unknownCompletionCount = 0
  local completedQuestCount = 0
  local notCompletedQuestCount = 0
  local journalObjectiveCountAvailable = type(X2Quest.GetQuestJournalObjectiveCount) == "function"
  local journalObjectivePositiveCount = 0
  local journalObjectiveZeroCount = 0
  local journalObjectiveReadErrorCount = 0
  local catalogMatchCount = 0
  local catalogTaggedCount = 0
  local candidateQuestCount = 0
  local eligibleQuestCount = 0
  local diagnosticSamplesByState = {}
  local eligibleTitleMatchCount = 0
  local eligiblePinnedMatchCount = 0
  local eligibleSearchAndPinMatchCount = 0
  local ok, count = pcall(function()
    return X2Quest:GetActiveQuestListCount()
  end)
  if not ok or not IsValidActiveQuestCount(count) then
    ClearQuestResults("Quest scan failed", "Active count invalid")
    return
  end
  for index = 1, count do
    local questOk, questType = pcall(function()
      return X2Quest:GetActiveQuestType(index)
    end)
    local validQuestType = questOk and IsValidQuestType(questType)
    if validQuestType and not seenQuestTypes[questType] then
      seenQuestTypes[questType] = true
      activeValidTypeCount = activeValidTypeCount + 1
      local journalObjectiveCount
      if journalObjectiveCountAvailable then
        local objectiveCountOk, objectiveCount = pcall(function()
          return X2Quest:GetQuestJournalObjectiveCount(index)
        end)
        if objectiveCountOk and IsFiniteNumber(objectiveCount) and objectiveCount >= 0 and objectiveCount == math.floor(objectiveCount) then
          journalObjectiveCount = objectiveCount
          if objectiveCount > 0 then
            journalObjectivePositiveCount = journalObjectivePositiveCount + 1
          else
            journalObjectiveZeroCount = journalObjectiveZeroCount + 1
          end
        else
          journalObjectiveReadErrorCount = journalObjectiveReadErrorCount + 1
        end
      end
      local completed
      if type(X2Quest.IsCompleted) == "function" then
        local completedOk, result = pcall(function()
          return X2Quest:IsCompleted(questType)
        end)
        if completedOk and type(result) == "boolean" then
          completed = result
          if completed then
            completedQuestCount = completedQuestCount + 1
          else
            notCompletedQuestCount = notCompletedQuestCount + 1
          end
        else
          unknownCompletionCount = unknownCompletionCount + 1
        end
      else
        unknownCompletionCount = unknownCompletionCount + 1
      end

      local title, titleFallback = GetQuestTitle(questType)
      if titleFallback then
        titleFallbackCount = titleFallbackCount + 1
      end
      local state = completed == true and "C" or completed == false and "I" or "?"
      if diagnosticSamplesByState[state] == nil then
        local titleSample = titleFallback and ("? " .. title) or title
        local objectiveSample = journalObjectiveCount ~= nil and tostring(journalObjectiveCount) or "?"
        diagnosticSamplesByState[state] = string.format("%d@%d:%s=%s:J%s", index, questType, state, titleSample:sub(1, 24), objectiveSample)
      end
      local catalogEntry = GetQuestCatalogEntry(questType, title)
      if catalogEntry ~= nil then
        catalogMatchCount = catalogMatchCount + 1
        if catalogEntry[4] == true or catalogEntry[5] == true then
          catalogTaggedCount = catalogTaggedCount + 1
        end
      end
      -- Completion is display state, not active-list membership. The stock
      -- tracker enumerates active entries regardless of completion state.
      candidateQuestCount = candidateQuestCount + 1
      local eligible = settings.showCompleted or completed ~= true
      if eligible then eligibleQuestCount = eligibleQuestCount + 1 end
      local pinned = settings.pinnedQuestIds[tostring(questType)] == true
      local searchMatches = questSearchText == "" or string.find(string.lower(title), questSearchText, 1, true) ~= nil
      local pinnedMatches = not settings.pinnedOnly or pinned
      if eligible then
        if searchMatches then
          eligibleTitleMatchCount = eligibleTitleMatchCount + 1
        end
        if pinned then
          eligiblePinnedMatchCount = eligiblePinnedMatchCount + 1
        end
        if searchMatches and pinned then
          eligibleSearchAndPinMatchCount = eligibleSearchAndPinMatchCount + 1
        end
        if searchMatches and pinnedMatches then
          local continentName, zoneName = GetQuestGeography(catalogEntry)
          local objectives = {}
          if settings.showObjectives then
            local objectiveErrors
            objectives, objectiveErrors = GetActiveQuestObjectiveTexts(questType)
            objectiveReadErrorCount = objectiveReadErrorCount + objectiveErrors
          end
          quests[#quests + 1] = {
            index = index,
            id = questType,
            title = title,
            continent = continentName,
            zone = zoneName,
            completed = completed == true,
            pinned = pinned,
            objectives = objectives,
          }
        end
      end
    elseif validQuestType then
      duplicateQuestTypeCount = duplicateQuestTypeCount + 1
    elseif questOk then
      invalidQuestTypeCount = invalidQuestTypeCount + 1
      if #invalidQuestTypeSamples < 3 then
        invalidQuestTypeSamples[#invalidQuestTypeSamples + 1] = string.format("%d:%s", index, type(questType))
      end
    else
      activeQuestTypeErrorCount = activeQuestTypeErrorCount + 1
    end
  end

  local diagnosticSamples = {}
  for _, state in ipairs({ "I", "C", "?" }) do
    if diagnosticSamplesByState[state] ~= nil then
      diagnosticSamples[#diagnosticSamples + 1] = diagnosticSamplesByState[state]
    end
  end

  local groupsByContinent = {}
  for _, quest in ipairs(quests) do
    local continent = groupsByContinent[quest.continent]
    if continent == nil then
      continent = {}
      groupsByContinent[quest.continent] = continent
    end
    local group = continent[quest.zone]
    if group == nil then
      group = {}
      continent[quest.zone] = group
    end
    group[#group + 1] = quest
  end

  for _, zones in pairs(groupsByContinent) do
    for _, zoneQuests in pairs(zones) do
      table.sort(zoneQuests, function(left, right)
        if left.pinned ~= right.pinned then
          return left.pinned
        end
        if settings.sortMode == "alphabetical" then
          return string.lower(left.title) < string.lower(right.title)
        end
        local leftOrder = left.index or math.huge
        local rightOrder = right.index or math.huge
        if leftOrder ~= rightOrder then
          return leftOrder < rightOrder
        end
        return left.id < right.id
      end)
    end
  end

  local displayRows = {}
  local renderedQuestCount = 0
  local continentNames = {}
  for continentName in pairs(groupsByContinent) do
    continentNames[#continentNames + 1] = continentName
  end
  table.sort(continentNames)
  for _, continentName in ipairs(continentNames) do
    local continentKey = "continent:" .. continentName
    local continentCollapsed = settings.collapsedSections[continentKey] == true
    displayRows[#displayRows + 1] = { kind = "continent", title = continentName, collapseKey = continentKey, collapsed = continentCollapsed }
    local zones = groupsByContinent[continentName]
    if not continentCollapsed then
      local zoneNames = {}
      for zoneName in pairs(zones) do
        zoneNames[#zoneNames + 1] = zoneName
      end
      table.sort(zoneNames)
      for _, zoneName in ipairs(zoneNames) do
        local zoneKey = "zone:" .. continentName .. "/" .. zoneName
        local zoneCollapsed = settings.collapsedSections[zoneKey] == true
        displayRows[#displayRows + 1] = { kind = "zone", title = zoneName, collapseKey = zoneKey, collapsed = zoneCollapsed }
        if not zoneCollapsed then
          for _, quest in ipairs(zones[zoneName]) do
            displayRows[#displayRows + 1] = { kind = "quest", quest = quest }
            renderedQuestCount = renderedQuestCount + 1
            for _, objective in ipairs(quest.objectives) do
              displayRows[#displayRows + 1] = { kind = "objective", title = objective }
            end
          end
        end
      end
    end
  end

  for index, displayRow in ipairs(displayRows) do
    local row = rows[index]
    if row == nil then
      row = CreateLabel(questViewport, "questRow" .. tostring(index), "", settings.fontSize, { 0.90, 0.90, 0.88, 1 })
      row:EnablePick(true)
      rows[index] = row
    end
    row.questDisplayIndex = index
    row:SetHandler("OnClick", HandleQuestRowAction)
    row:EnableFocus(settings.keyboardNavigation and displayRow.kind == "quest")
    row:EnableKeyboard(settings.keyboardNavigation and displayRow.kind == "quest")
    row:SetHandler("OnKeyDown", function(self, key)
      if not settings.keyboardNavigation or not self.isQuestRow then return end
      if key == "up" or key == "down" then
        local currentIndex = keyboardCursorIndex or self.questDisplayIndex
        keyboardCursorIndex = FindKeyboardQuestRow(currentIndex, key == "down" and 1 or -1)
        keyboardCursorQuestId = keyboardCursorIndex ~= nil and rows[keyboardCursorIndex].questId or nil
        UpdateKeyboardCursorText()
        ScrollKeyboardCursorIntoView()
      elseif key == "enter" and keyboardCursorIndex ~= nil and rows[keyboardCursorIndex] ~= nil then
        HandleQuestRowAction(rows[keyboardCursorIndex], "Enter")
      end
    end)
    row.isContinentHeader = displayRow.kind == "continent"
    row.isZoneHeader = displayRow.kind == "zone"
    row.isHeader = row.isContinentHeader or row.isZoneHeader
    row.isObjective = displayRow.kind == "objective"
    row.isQuestRow = displayRow.kind == "quest"
    row.collapseKey = displayRow.collapseKey
    row.collapsed = displayRow.collapsed
    if row.isHeader then
      row.questIndex = nil
      row.questId = nil
      local marker = displayRow.collapsed and "+ " or "- "
      row.colorKey = row.isContinentHeader and "continentColor" or "zoneColor"
      row:SetText(row.isContinentHeader and (marker .. displayRow.title) or ("  " .. marker .. displayRow.title))
    elseif row.isObjective then
      row.questIndex = nil
      row.questId = nil
      row.collapseKey = nil
      row.colorKey = "objectiveColor"
      row:SetText("    · " .. displayRow.title)
    else
      row.collapseKey = nil
      local quest = displayRow.quest
      row.isQuestRow = true
      row.colorKey = quest.completed and "completedColor" or "questColor"
      row.questIndex = quest.index
      row.questId = quest.id
      local mark = quest.completed and settings.showCompletionLabel and "  ·  Complete" or ""
      local questIdPrefix = settings.showQuestIds and string.format("[slot %d | type %d] ", quest.index, quest.id) or ""
      row.baseText = questIdPrefix .. (quest.pinned and "★ " or "") .. quest.title .. mark
      row:SetText(row.baseText)
    end
    if not row.isQuestRow then row.baseText = nil end
    row:Show(true)
  end

  for index = #displayRows + 1, #rows do
    rows[index]:Show(false)
    rows[index].isQuestRow = false
    rows[index].baseText = nil
  end
  local selectionFound = false
  if keyboardCursorQuestId ~= nil then
    for index, row in ipairs(rows) do
      if row.isQuestRow and row.questId == keyboardCursorQuestId then
        keyboardCursorIndex = index
        selectionFound = true
        break
      end
    end
  end
  if not selectionFound then
    keyboardCursorIndex = FindKeyboardQuestRow(0, 1)
    keyboardCursorQuestId = keyboardCursorIndex ~= nil and rows[keyboardCursorIndex].questId or nil
  end
  UpdateKeyboardCursorText()
  visibleQuestCount = #quests
  visibleRowCount = #displayRows
  questScrollOffset = 0
  if sampleDiagnosticLabel ~= nil then
    local sampleText
    if #diagnosticSamples > 0 then
      sampleText = "API slot@ID: " .. diagnosticSamples[1]
    elseif #invalidQuestTypeSamples > 0 then
      sampleText = "API invalid slot: " .. invalidQuestTypeSamples[1]
    end
    sampleDiagnosticLabel:SetText(sampleText or "")
    sampleDiagnosticLabel:Show(sampleText ~= nil)
  end
  local summary
  if #quests == 0 and count == 0 then
    summary = "API list empty"
  elseif #quests == 0 and activeValidTypeCount == 0 then
    summary = string.format("No valid IDs · %d slots", count)
  elseif #quests == 0 and settings.pinnedOnly and questSearchText ~= "" then
    summary = eligibleTitleMatchCount == 0 and "No title matches · clear search" or "No pinned match · Pinned only on"
  elseif #quests == 0 and settings.pinnedOnly and eligiblePinnedMatchCount == 0 then
    summary = "No pins · Pinned only on"
  elseif #quests == 0 and questSearchText ~= "" and eligibleTitleMatchCount == 0 then
    summary = "No title matches · clear search"
  elseif #quests == 0 and eligibleQuestCount > 0 then
    summary = string.format("No matches · %d candidates", eligibleQuestCount)
  elseif #quests == 0 and candidateQuestCount > 0 and eligibleQuestCount == 0 then
    summary = string.format("All %d candidates completed · show in Settings", candidateQuestCount)
  elseif #quests == 0 and unknownCompletionCount > 0 then
    summary = string.format("No rows · %d unknown", unknownCompletionCount)
  elseif #quests == 0 then
    summary = string.format("No rows · scanned %d IDs", activeValidTypeCount)
  elseif renderedQuestCount ~= #quests then
    summary = string.format("%d visible · %d filtered candidates", renderedQuestCount, #quests)
  elseif settings.pinnedOnly or questSearchText ~= "" or not settings.showCompleted then
    summary = string.format("%d filtered candidates", #quests)
  else
    summary = string.format("%d API quest candidates", #quests)
  end
  statusLabel:SetText(BUILD_MARKER .. " · " .. summary)
  diagnosticLabel:SetText(string.format("%s A%d T%d C%d I%d U%d %s", BUILD_MARKER, count, activeValidTypeCount, completedQuestCount, notCompletedQuestCount, unknownCompletionCount, GetQuestAPISurfaceFlags()))
  local journalObjectiveDiagnostic
  if journalObjectiveCountAvailable then
    if settings.width >= 280 then
      journalObjectiveDiagnostic = string.format("JC%d J0%d J?%d", journalObjectivePositiveCount, journalObjectiveZeroCount, journalObjectiveReadErrorCount)
    else
      journalObjectiveDiagnostic = string.format("JC%d", journalObjectivePositiveCount)
    end
  else
    journalObjectiveDiagnostic = "JC-"
  end
  filterDiagnosticLabel:SetText(string.format(
    "E%d R%d H%d M%d Q%d X%d O%d V%s D%s P%s S%s %s",
    eligibleQuestCount,
    renderedQuestCount,
    titleFallbackCount,
    invalidQuestTypeCount,
    duplicateQuestTypeCount,
    activeQuestTypeErrorCount,
    objectiveReadErrorCount,
    settings.showObjectives and "+" or "-",
    settings.showCompleted and "+" or "-",
    settings.pinnedOnly and "+" or "-",
    questSearchText ~= "" and "+" or "-",
    journalObjectiveDiagnostic
  ))
  DebugPrint(string.format("quest scan: active slots %d, read errors %d, invalid IDs %d, duplicate IDs %d, unique IDs %d, completed %d, not completed %d, completion errors %d, journal objectives positive %d, zero %d, errors %d, objective text errors %d, title fallbacks %d, catalog matches %d, catalog tagged %d, eligible %d, title matches %d, pinned matches %d, title+pin matches %d, matched quests %d, rendered quests %d", count, activeQuestTypeErrorCount, invalidQuestTypeCount, duplicateQuestTypeCount, activeValidTypeCount, completedQuestCount, notCompletedQuestCount, unknownCompletionCount, journalObjectivePositiveCount, journalObjectiveZeroCount, journalObjectiveReadErrorCount, objectiveReadErrorCount, titleFallbackCount, catalogMatchCount, catalogTaggedCount, eligibleQuestCount, eligibleTitleMatchCount, eligiblePinnedMatchCount, eligibleSearchAndPinMatchCount, #quests, renderedQuestCount))
  if invalidQuestTypeCount > 0 then
    local signature = table.concat(invalidQuestTypeSamples, ", ")
    if signature ~= lastInvalidTypeSignature then
      DebugPrint("invalid active-list slots: " .. signature)
      lastInvalidTypeSignature = signature
    end
  else
    lastInvalidTypeSignature = nil
  end
  if #quests == 0 and #diagnosticSamples > 0 then
    local signature = table.concat(diagnosticSamples, " | ")
    if signature ~= lastEmptyScanSignature then
      DebugPrint("empty scan samples: " .. signature)
      lastEmptyScanSignature = signature
    end
  elseif #quests > 0 then
    lastEmptyScanSignature = nil
  end
  ApplyStyle()
  if settings.keyboardNavigation then
    ScrollKeyboardCursorIntoView()
  end
end

local function ApplyQuestSearch()
  questSearchText = string.lower(questSearchEdit:GetText() or "")
  previewMode = false
  if previewButton ~= nil then
    previewButton:SetText("Preview")
  end
  RefreshQuests()
end

local function ProbeStockQuestListHelper(helperName)
  local helper = _G[helperName]
  if type(helper) ~= "function" then
    return nil, "missing"
  end

  local ok, result = pcall(helper)
  if not ok then
    return nil, "call failed: " .. tostring(result)
  end
  if type(result) ~= "table" then
    return nil, "returned " .. type(result)
  end

  local count = #result
  local sample = {}
  for index = 1, math.min(count, 8) do
    sample[#sample + 1] = tostring(result[index])
  end
  return result, string.format("array count=%d sample=%s", count, #sample > 0 and table.concat(sample, ",") or "(empty)")
end

local function ProbePrint(message)
  local text = "[Wayfinder probe] " .. tostring(message)
  if X2Chat ~= nil and type(X2Chat.DispatchChatMessage) == "function" then
    local ok = pcall(function()
      X2Chat:DispatchChatMessage(CMF_SYSTEM, text)
    end)
    if ok then
      return
    end
  end
  DebugPrint(message)
end

local function RunAPIInventoryProbe()
  ProbePrint("runtime probe: stock quest helper visibility")
  local notifierList, notifierResult = ProbeStockQuestListHelper("GetNotifierQuestList")
  ProbePrint("GetNotifierQuestList: " .. notifierResult)
  local _, todayResult = ProbeStockQuestListHelper("GetTodayQuestList")
  ProbePrint("GetTodayQuestList: " .. todayResult)

  local checkboxHelper = _G.GetQuestListCheckValue
  if type(checkboxHelper) ~= "function" then
    ProbePrint("GetQuestListCheckValue: missing")
  elseif notifierList ~= nil and type(notifierList[1]) == "number" then
    local ok, state = pcall(checkboxHelper, notifierList[1])
    if ok then
      ProbePrint("GetQuestListCheckValue: " .. type(state) .. " " .. tostring(state))
    else
      ProbePrint("GetQuestListCheckValue call failed: " .. tostring(state))
    end
  else
    ProbePrint("GetQuestListCheckValue: present; no notifier quest to sample")
  end

  local zoneGetterType = X2Quest ~= nil and type(X2Quest.GetQuestAcceptZoneName) or "no X2Quest"
  ProbePrint("X2Quest.GetQuestAcceptZoneName=" .. zoneGetterType .. " (presence only; not invoked)")
  ProbePrint("X2Quest.GetNotifierQuestList=" .. tostring(X2Quest ~= nil and type(X2Quest.GetNotifierQuestList) or "no X2Quest"))

  local function GetSurfaceTypes(object, names)
    local result = {}
    for _, name in ipairs(names) do
      local value = nil
      if object ~= nil then
        value = object[name]
      end
      result[#result + 1] = name .. "=" .. tostring(type(value))
    end
    return table.concat(result, " ")
  end

  ProbePrint("track API (presence only): " .. GetSurfaceTypes(X2Quest, {
    "IsTrackedQuest", "GetQuestContextNotify", "GetQuestContextState", "GetTrackingActiveQuest",
    "GetQuestDirInfo",
  }))
  ProbePrint("journal API (presence only): " .. GetSurfaceTypes(X2Quest, {
    "IsProgressQuestInJournal", "IsReadyQuestInJournal", "GetActiveQuestListStatus",
    "GetActiveQuestListStatusByType", "IsCompleted",
  }))
  ProbePrint("category API (presence only): " .. GetSurfaceTypes(X2Quest, {
    "IsHiddenQuest", "IsTodayQuest", "IsSagaQuest", "IsPublicQuest",
  }))
  ProbePrint("stock helpers (presence only): " .. GetSurfaceTypes(_G, {
    "IsTrackedQuest", "GetQuestContextNotify", "GetQuestContextState", "IsCompleteQuest",
    "IsHiddenQuest", "IsTodayQuest", "IsSagaQuest", "IsPublicQuest",
  }))
  ProbePrint("X2 notifier getters (presence only): " .. GetSurfaceTypes(X2, {
    "GetQuestNotifierListUiData", "GetQuestContextStateValuesUiData",
  }))
end

local function ShowPreviewRows()
  local preview = {
    { kind = "zone", title = "Two Crowns" },
    { kind = "quest", title = "A Road Through Two Crowns" },
    { kind = "quest", title = "Gather 6 × Blue Salt Clams" },
    { kind = "quest", title = "Return to the Trading Post", completed = true },
  }
  visibleQuestCount = 3
  visibleRowCount = #preview
  questScrollOffset = 0
  if sampleDiagnosticLabel ~= nil then
    sampleDiagnosticLabel:SetText("")
    sampleDiagnosticLabel:Show(false)
  end
  for index, entry in ipairs(preview) do
    local row = rows[index]
    if row == nil then
      row = CreateLabel(questViewport, "previewRow" .. tostring(index), "", settings.fontSize, { 0.90, 0.90, 0.88, 1 })
      row:EnablePick(true)
      row:SetHandler("OnClick", function() end)
      rows[index] = row
    end
    row.isZoneHeader = entry.kind == "zone"
    row.isContinentHeader = false
    row.isHeader = row.isZoneHeader
    row.isObjective = false
    row.colorKey = row.isZoneHeader and "zoneColor" or (entry.completed and "completedColor" or "questColor")
    row.questIndex = nil
    row.questId = nil
    row.collapseKey = nil
    row.collapsed = false
    local completionMark = entry.completed and settings.showCompletionLabel and "  ·  Complete" or ""
    row:SetText(row.isZoneHeader and ("— " .. entry.title .. " —") or (entry.title .. completionMark))
    row:Show(true)
  end
  for index = #preview + 1, #rows do
    rows[index]:Show(false)
  end
  ApplyStyle()
end

local function UpdateSettingsText()
  settingsStatus:SetText(string.format("Size %d × %d    Text %d    Spacing %d    Opacity %d%%", settings.width, settings.height, settings.fontSize, settings.rowGap, math.floor(settings.opacity * 100)))
end

local function ChangeSetting(key, amount, minValue, maxValue)
  local previous = settings[key]
  settings[key] = Clamp(settings[key] + amount, minValue, maxValue)
  if key == "fontSize" then
    local delta = settings[key] - previous
    for _, fontKey in ipairs({ "titleFontSize", "continentFontSize", "zoneFontSize", "completedFontSize", "objectiveFontSize" }) do
      settings[fontKey] = Clamp(settings[fontKey] + delta, 10, 22)
    end
  end
  SaveSettings()
  ApplyStyle()
  UpdateSettingsText()
  statusLabel:SetText("Appearance saved · press Refresh to update quests")
end

local function ToggleSettings(show)
  if settingsWindow == nil then
    return
  end
  local shouldShow
  if show == nil then
    shouldShow = not settingsWindow:IsVisible()
  else
    shouldShow = show
  end
  settingsWindow:Show(shouldShow)
  if shouldShow then
    CorrectWidgetPosition(settingsWindow)
  end
end

local function ToggleTracker(show)
  if tracker == nil then
    return
  end
  if show == nil then
    settings.visible = not tracker:IsVisible()
  else
    settings.visible = show
  end
  tracker:Show(settings.visible)
  SaveSettings()
end

UIParent:SetEventHandler(UIEVENT_TYPE.UI_ADDON, function()
  DebugPrint("Addon Manager settings requested")
  ToggleTracker(true)
  if settingsWindow == nil then
    DebugPrint("settings window unavailable; initialization is incomplete")
    return
  end
  ToggleSettings(true)
  tracker:Raise()
  settingsWindow:Raise()
end)

tracker = CreateEmptyWindow("wayfinderTracker", "UIParent")
tracker:SetCloseOnEscape(false)
DebugPrint("startup: tracker window created")
tracker:SetExtent(settings.width, 220)
tracker:SetUILayer("system")
tracker:Enable(true)
tracker:Clickable(true)
tracker:EnableDrag(true)
tracker:SetMinResizingExtent(220, 200)
tracker:SetMaxResizingExtent(500, 780)
tracker:SetResizingBorderSize(8, 8, 8, 8)
tracker:UseResizing(true)
ApplyPosition()
tracker:Show(false)

local launcherButton = CreateSimpleButton("Wayfinder", 700, -380)
DebugPrint("startup: launcher created")
launcherButton:SetHandler("OnClick", function()
  ToggleTracker()
  if settings.visible then
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

borderTop = tracker:CreateColorDrawable(0.34, 0.43, 0.61, 1, "artwork")
borderTop:AddAnchor("TOPLEFT", tracker, 0, 0)
borderTop:AddAnchor("TOPRIGHT", tracker, 0, 0)
borderBottom = tracker:CreateColorDrawable(0.34, 0.43, 0.61, 1, "artwork")
borderBottom:AddAnchor("BOTTOMLEFT", tracker, 0, 0)
borderBottom:AddAnchor("BOTTOMRIGHT", tracker, 0, 0)
borderLeft = tracker:CreateColorDrawable(0.34, 0.43, 0.61, 1, "artwork")
borderLeft:AddAnchor("TOPLEFT", tracker, 0, 0)
borderLeft:AddAnchor("BOTTOMLEFT", tracker, 0, 0)
borderRight = tracker:CreateColorDrawable(0.34, 0.43, 0.61, 1, "artwork")
borderRight:AddAnchor("TOPRIGHT", tracker, 0, 0)
borderRight:AddAnchor("BOTTOMRIGHT", tracker, 0, 0)

titleLabel = CreateLabel(tracker, "title", "WAYFINDER", settings.titleFontSize, { 0.95, 0.83, 0.58, 1 })
DebugPrint("startup: tracker title created")
titleLabel:SetExtent(settings.width - 34, 28)
titleLabel:AddAnchor("TOPLEFT", tracker, 17, 10)

questSearchEdit = tracker:CreateChildWidget("x2editbox", "questTitleFilter", 0, true)
questSearchEdit:SetExtent(settings.width - 36, 24)
questSearchEdit:AddAnchor("TOPLEFT", tracker, 18, 63)
questSearchEdit:SetInset(6, 3, 6, 3)
questSearchEdit:SetGuideText("Filter quest titles · Enter to apply")
questSearchEdit:SetMaxTextLength(64)
questSearchEdit.style:SetAlign(ALIGN_LEFT)
questSearchEdit.style:SetFontSize(11)
questSearchEdit.style:SetColor(0.90, 0.90, 0.88, 1)
local searchBackground = questSearchEdit:CreateColorDrawable(0.06, 0.08, 0.10, 0.96, "background")
searchBackground:AddAnchor("TOPLEFT", questSearchEdit, 0, 0)
searchBackground:AddAnchor("BOTTOMRIGHT", questSearchEdit, 0, 0)
questSearchEdit:SetHandler("OnTextChanged", function()
  ApplyQuestSearch()
end)
questSearchEdit:SetHandler("OnEnterPressed", ApplyQuestSearch)

local refreshButton = CreateButton(tracker, "refreshButton", "Refresh", 64, function()
  ApplyQuestSearch()
  RunAPIInventoryProbe()
end)
refreshButton:AddAnchor("TOPRIGHT", tracker, -98, 34)
local settingsButton = CreateButton(tracker, "settingsButton", "Settings", 72, function() ToggleSettings(true) end)
settingsButton:AddAnchor("TOPRIGHT", tracker, -18, 34)
trackerMinimizeButton = CreateButton(tracker, "minimizeButton", "-", 18, function()
  settings.minimized = not settings.minimized
  ApplyStyle()
  SaveSettings()
end)
trackerMinimizeButton:SetExtent(18, 18)
trackerMinimizeButton:AddAnchor("TOPRIGHT", tracker, -38, 7)
trackerCloseButton = CreateButton(tracker, "closeButton", "x", 18, function() ToggleTracker(false) end)
trackerCloseButton:SetExtent(18, 18)
trackerCloseButton:AddAnchor("TOPRIGHT", tracker, -10, 7)
statusLabel = CreateLabel(tracker, "status", "Press Refresh to load quests", 11, { 0.67, 0.73, 0.73, 1 })
DebugPrint("startup: tracker controls created")
statusLabel:SetExtent(settings.width - 34, 18)
statusLabel:AddAnchor("TOPLEFT", tracker, 18, 88)
diagnosticLabel = CreateLabel(tracker, "scanDiagnostics", "", 9, { 0.67, 0.73, 0.73, 1 })
diagnosticLabel:SetExtent(settings.width - 34, 16)
diagnosticLabel:AddAnchor("TOPLEFT", tracker, 18, 106)
filterDiagnosticLabel = CreateLabel(tracker, "filterDiagnostics", "", 9, { 0.67, 0.73, 0.73, 1 })
filterDiagnosticLabel:SetExtent(settings.width - 34, 16)
filterDiagnosticLabel:AddAnchor("TOPLEFT", tracker, 18, 122)
sampleDiagnosticLabel = CreateLabel(tracker, "sampleDiagnostics", "", 9, { 0.67, 0.73, 0.73, 1 })
sampleDiagnosticLabel:SetExtent(settings.width - 34, 16)
sampleDiagnosticLabel:AddAnchor("TOPLEFT", tracker, 18, 140)
sampleDiagnosticLabel:Show(false)

questViewport = tracker:CreateChildWidget("emptywidget", "questViewport", 0, true)
questViewport:AddAnchor("TOPLEFT", tracker, 18, 158)
questViewport:SetExtent(settings.width - 36, questViewportHeight)
questViewport:EnableScroll(true)
questViewport:SetHandler("OnWheelUp", function() ScrollQuestList(-1) end)
questViewport:SetHandler("OnWheelDown", function() ScrollQuestList(1) end)

local function FinishTrackerDrag()
  tracker:StopMovingOrSizing()
  CorrectTrackerPosition()
  local x, y = tracker:GetOffset()
  settings.x = x
  settings.y = y
  if trackerDragMode == "resize" then
    settings.width = Clamp(tracker:GetWidth(), 220, 500)
    settings.height = Clamp(tracker:GetHeight(), 200, 780)
    settings.heightCustomized = true
    ApplyStyle()
  end
  trackerDragMode = nil
  ApplyPosition()
  SaveSettings()
  UpdateSettingsText()
end

tracker:SetHandler("OnDragStart", function()
  if settings.locked then
    return false
  end
  trackerDragMode = "move"
  tracker:StartMoving()
  return true
end)
tracker:SetHandler("OnDragStop", FinishTrackerDrag)

local trackerResizeHandleSpecs = {
  { edge = "top", sizingAnchor = "TOP" },
  { edge = "bottom", sizingAnchor = "BOTTOM" },
  { edge = "left", sizingAnchor = "LEFT" },
  { edge = "right", sizingAnchor = "RIGHT" },
  { edge = "topLeft", sizingAnchor = "TOPLEFT" },
  { edge = "topRight", sizingAnchor = "TOPRIGHT" },
  { edge = "bottomLeft", sizingAnchor = "BOTTOMLEFT" },
  { edge = "bottomRight", sizingAnchor = "BOTTOMRIGHT" },
}
for _, spec in ipairs(trackerResizeHandleSpecs) do
  local sizingAnchor = spec.sizingAnchor
  local handle = tracker:CreateChildWidget("emptywidget", "resizeHandle_" .. spec.edge, 0, true)
  handle:Enable(true)
  handle:Clickable(true)
  handle:EnableDrag(true)
  handle:SetHandler("OnDragStart", function()
    trackerDragMode = "resize"
    tracker:StartSizing(sizingAnchor)
    return true
  end)
  handle:SetHandler("OnDragStop", FinishTrackerDrag)
  trackerResizeHandles[#trackerResizeHandles + 1] = { widget = handle, edge = spec.edge }
end
UpdateTrackerResizeHandles()

tracker:SetHandler("OnUpdate", function(self)
  if trackerDragMode ~= "resize" then
    return
  end

  local width = Clamp(self:GetWidth(), 220, 500)
  local height = Clamp(self:GetHeight(), 200, 780)
  if width == settings.width and height == settings.height then
    return
  end

  settings.width = width
  settings.height = height
  settings.heightCustomized = true
  ApplyStyle(true)
end)

settingsWindow = CreateEmptyWindow("wayfinderSettings", "UIParent")
DebugPrint("startup: settings window created")
settingsWindow:SetExtent(430, 650)
settingsWindow:SetUILayer("system")
settingsWindow:Enable(true)
settingsWindow:Clickable(true)
settingsWindow:EnableDrag(true)
if settings.settingsWindowPositionSet then
  settingsWindow:AddAnchor("TOPLEFT", "UIParent", settings.settingsWindowX, settings.settingsWindowY)
else
  settingsWindow:AddAnchor("CENTER", "UIParent", 0, 0)
end
settingsWindow:Show(false)
local settingsBackground = settingsWindow:CreateColorDrawable(0, 0.05, 0.08, 0.96, "background")
settingsBackground:AddAnchor("TOPLEFT", settingsWindow, 0, 0)
settingsBackground:AddAnchor("BOTTOMRIGHT", settingsWindow, 0, 0)
local settingsTitle = CreateLabel(settingsWindow, "settingsTitle", "WAYFINDER  /  CUSTOMIZE", 15, { 0.95, 0.83, 0.58, 1 })
settingsTitle:SetExtent(280, 28)
settingsTitle:AddAnchor("TOPLEFT", settingsWindow, 18, 14)
settingsTitle:EnablePick(true)
settingsTitle:EnableDrag(true)
settingsTitle:SetHandler("OnDragStart", function()
  settingsWindow:StartMoving()
  return true
end)
settingsTitle:SetHandler("OnDragStop", function()
  settingsWindow:StopMovingOrSizing()
  local x, y = CorrectWidgetPosition(settingsWindow)
  SaveSettingsWindowPosition(x, y)
end)
settingsStatus = CreateLabel(settingsWindow, "settingsStatus", "", 11, { 0.78, 0.83, 0.81, 1 })
settingsStatus:SetExtent(320, 20)
settingsStatus:AddAnchor("TOPLEFT", settingsWindow, 18, 50)

local function AddSettingRow(y, labelText, key, step, minValue, maxValue)
  local label = CreateLabel(settingsWindow, "settingLabel" .. tostring(y), labelText, 12, { 0.84, 0.86, 0.83, 1 })
  label:SetExtent(230, 24)
  label:AddAnchor("TOPLEFT", settingsWindow, 20, y + 4)
  local down = CreateButton(settingsWindow, "settingDown" .. tostring(y), "−", 36, function() ChangeSetting(key, -step, minValue, maxValue) end)
  down:AddAnchor("TOPLEFT", settingsWindow, 275, y)
  local up = CreateButton(settingsWindow, "settingUp" .. tostring(y), "+", 36, function() ChangeSetting(key, step, minValue, maxValue) end)
  up:AddAnchor("TOPLEFT", settingsWindow, 365, y)
end

AddSettingRow(82, "Tracker width", "width", 10, 220, 500)
AddSettingRow(119, "Quest text size", "fontSize", 1, 10, 22)
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
  previewMode = false
  if previewButton ~= nil then
    previewButton:SetText("Preview")
  end
  RefreshQuests()
end)
completedButton:AddAnchor("TOPLEFT", settingsWindow, 175, 310)

local completionLabelButton
completionLabelButton = CreateButton(settingsWindow, "completionLabelButton", "Complete tag: shown", 170, function()
  settings.showCompletionLabel = not settings.showCompletionLabel
  completionLabelButton:SetText(settings.showCompletionLabel and "Complete tag: shown" or "Complete tag: hidden")
  SaveSettings()
  previewMode = false
  if previewButton ~= nil then
    previewButton:SetText("Preview")
  end
  RefreshQuests()
end)
completionLabelButton:AddAnchor("TOPLEFT", settingsWindow, 20, 350)

local objectivesButton
objectivesButton = CreateButton(settingsWindow, "objectivesButton", "Objectives: hidden", 145, function()
  settings.showObjectives = not settings.showObjectives
  objectivesButton:SetText(settings.showObjectives and "Objectives: shown" or "Objectives: hidden")
  SaveSettings()
  previewMode = false
  if previewButton ~= nil then
    previewButton:SetText("Preview")
  end
  RefreshQuests()
end)
objectivesButton:AddAnchor("TOPLEFT", settingsWindow, 175, 385)

local pinnedOnlyButton
local showAllQuestsButton
showAllQuestsButton = CreateButton(settingsWindow, "showAllQuestsButton", "Clear list filters", 145, function()
  settings.showCompleted = true
  settings.pinnedOnly = false
  settings.collapsedSections = {}
  questSearchText = ""
  questSearchEdit:SetText("")
  previewMode = false
  if previewButton ~= nil then
    previewButton:SetText("Preview")
  end
  completedButton:SetText("Completed: shown")
  pinnedOnlyButton:SetText("Pinned only: off")
  SaveSettings()
  settingsStatus:SetText("List filters cleared")
  RefreshQuests()
end)
showAllQuestsButton:AddAnchor("TOPLEFT", settingsWindow, 20, 385)

local defaultTrackerButton
defaultTrackerButton = CreateButton(settingsWindow, "defaultTrackerButton", "Default tracker: shown", 205, function()
  local hide = not settings.hideDefaultTracker
  local applied = SetNativeQuestUIVisibility(UIC_QUEST_NOTIFIER, not hide)
  if not applied then
    statusLabel:SetText("Could not change the default tracker")
    return
  end
  settings.hideDefaultTracker = hide
  defaultTrackerButton:SetText(hide and "Default tracker: hidden" or "Default tracker: shown")
  SaveSettings()
  statusLabel:SetText(hide and "Default tracker hidden" or "Default tracker restored")
end)
defaultTrackerButton:AddAnchor("TOPLEFT", settingsWindow, 20, 420)

local defaultLogButton
defaultLogButton = CreateButton(settingsWindow, "defaultLogButton", "Quest log: shown", 205, function()
  local hide = not settings.hideDefaultLog
  local applied = SetNativeQuestUIVisibility(UIC_QUEST_LIST, not hide)
  if not applied then
    statusLabel:SetText("Could not change the default quest log")
    return
  end
  settings.hideDefaultLog = hide
  defaultLogButton:SetText(hide and "Quest log: hidden" or "Quest log: shown")
  SaveSettings()
  statusLabel:SetText(hide and "Default quest log hidden" or "Default quest log restored")
end)
defaultLogButton:AddAnchor("TOPLEFT", settingsWindow, 20, 455)

local sortButton
sortButton = CreateButton(settingsWindow, "sortButton", "Quest order: journal", 205, function()
  settings.sortMode = settings.sortMode == "journal" and "alphabetical" or "journal"
  sortButton:SetText(settings.sortMode == "alphabetical" and "Quest order: A–Z" or "Quest order: journal")
  SaveSettings()
  RefreshQuests()
end)
sortButton:AddAnchor("TOPLEFT", settingsWindow, 20, 490)

local autoTrackButton
autoTrackButton = CreateButton(settingsWindow, "autoTrackButton", "Auto-track: off", 145, function()
  settings.autoTrackAccepted = not settings.autoTrackAccepted
  autoTrackButton:SetText(settings.autoTrackAccepted and "Auto-track: on" or "Auto-track: off")
  SaveSettings()
  statusLabel:SetText(settings.autoTrackAccepted and "New quests will be tracked" or "Auto-tracking disabled")
end)
autoTrackButton:AddAnchor("TOPLEFT", settingsWindow, 20, 525)

local completionAlertButton
completionAlertButton = CreateButton(settingsWindow, "completionAlertButton", "Done alert: off", 90, function()
  settings.notifyQuestCompletion = not settings.notifyQuestCompletion
  completionAlertButton:SetText(settings.notifyQuestCompletion and "Done alert: on" or "Done alert: off")
  SaveSettings()
  statusLabel:SetText(settings.notifyQuestCompletion and "Quest completion alerts enabled" or "Quest completion alerts disabled")
end)
completionAlertButton:AddAnchor("TOPLEFT", settingsWindow, 320, 525)

completionSoundButton = CreateButton(settingsWindow, "completionSoundButton", "Done sound: off", 90, function()
  settings.notifyQuestSound = not settings.notifyQuestSound
  completionSoundButton:SetText(settings.notifyQuestSound and "Done sound: on" or "Done sound: off")
  SaveSettings()
  statusLabel:SetText(settings.notifyQuestSound and "Quest completion sound enabled" or "Quest completion sound disabled")
end)
completionSoundButton:AddAnchor("TOPLEFT", settingsWindow, 320, 560)

pinnedOnlyButton = CreateButton(settingsWindow, "pinnedOnlyButton", "Pinned only: off", 145, function()
  settings.pinnedOnly = not settings.pinnedOnly
  pinnedOnlyButton:SetText(settings.pinnedOnly and "Pinned only: on" or "Pinned only: off")
  SaveSettings()
  RefreshQuests()
end)
pinnedOnlyButton:AddAnchor("TOPLEFT", settingsWindow, 175, 525)

local colorsWindow = CreateEmptyWindow("wayfinderColors", "UIParent")
colorsWindow:SetExtent(440, 400)
colorsWindow:SetUILayer("system")
colorsWindow:Enable(true)
colorsWindow:Clickable(true)
colorsWindow:EnableDrag(true)
colorsWindow:AddAnchor("CENTER", "UIParent", 0, 0)
colorsWindow:Show(false)
local colorsBackground = colorsWindow:CreateColorDrawable(0, 0.05, 0.08, 0.97, "background")
colorsBackground:AddAnchor("TOPLEFT", colorsWindow, 0, 0)
colorsBackground:AddAnchor("BOTTOMRIGHT", colorsWindow, 0, 0)
local colorsTitle = CreateLabel(colorsWindow, "colorsTitle", "WAYFINDER  /  TEXT COLORS", 15, { 0.95, 0.83, 0.58, 1 })
colorsTitle:SetExtent(390, 26)
colorsTitle:AddAnchor("TOPLEFT", colorsWindow, 18, 12)
local colorsHint = CreateLabel(colorsWindow, "colorsHint", "Adjust each RGB channel from 0 to 255", 11, { 0.78, 0.83, 0.81, 1 })
colorsHint:SetExtent(390, 18)
colorsHint:AddAnchor("TOPLEFT", colorsWindow, 18, 40)

local colorEntries = {
  { key = "titleColor", label = "Title" },
  { key = "continentColor", label = "Continent headers" },
  { key = "zoneColor", label = "Zone headers" },
  { key = "questColor", label = "Quest text" },
  { key = "completedColor", label = "Completed text" },
  { key = "objectiveColor", label = "Objective text" },
  { key = "borderColor", label = "Tracker border" },
}
local function UpdateColorLabels()
  for _, entry in ipairs(colorEntries) do
    local color = settings[entry.key]
    entry.valueLabel:SetText(string.format("#%02X%02X%02X", math.floor(color[1] * 255), math.floor(color[2] * 255), math.floor(color[3] * 255)))
  end
end
for rowIndex, entry in ipairs(colorEntries) do
  local entryKey = entry.key
  local rowY = 68 + (rowIndex - 1) * 35
  local label = CreateLabel(colorsWindow, "colorName" .. rowIndex, entry.label, 11, { 0.84, 0.86, 0.83, 1 })
  label:SetExtent(122, 22)
  label:AddAnchor("TOPLEFT", colorsWindow, 16, rowY + 3)
  entry.valueLabel = CreateLabel(colorsWindow, "colorValue" .. rowIndex, "#FFFFFF", 10, { 0.78, 0.83, 0.81, 1 })
  entry.valueLabel:SetExtent(58, 22)
  entry.valueLabel:AddAnchor("TOPLEFT", colorsWindow, 136, rowY + 3)
  for channel = 1, 3 do
    local channelIndex = channel
    local x = 204 + (channel - 1) * 74
    local channelName = ({ "R", "G", "B" })[channel]
    local down = CreateButton(colorsWindow, "colorDown" .. rowIndex .. channel, channelName .. "−", 34, function()
      local color = settings[entryKey]
      color[channelIndex] = Clamp(color[channelIndex] - (1 / 255), 0, 1)
      SaveSettings()
      UpdateColorLabels()
      ApplyStyle()
    end)
    down:SetExtent(34, 24)
    down:AddAnchor("TOPLEFT", colorsWindow, x, rowY)
    local up = CreateButton(colorsWindow, "colorUp" .. rowIndex .. channel, channelName .. "+", 34, function()
      local color = settings[entryKey]
      color[channelIndex] = Clamp(color[channelIndex] + (1 / 255), 0, 1)
      SaveSettings()
      UpdateColorLabels()
      ApplyStyle()
    end)
    up:SetExtent(34, 24)
    up:AddAnchor("TOPLEFT", colorsWindow, x + 36, rowY)
  end
end
UpdateColorLabels()
local borderSizeLabel = CreateLabel(colorsWindow, "borderSizeLabel", "Border thickness", 11, { 0.84, 0.86, 0.83, 1 })
borderSizeLabel:SetExtent(130, 22)
borderSizeLabel:AddAnchor("TOPLEFT", colorsWindow, 16, 320)
local borderSizeValue = CreateLabel(colorsWindow, "borderSizeValue", tostring(settings.borderSize), 10, { 0.78, 0.83, 0.81, 1 })
borderSizeValue:SetExtent(34, 22)
borderSizeValue:AddAnchor("TOPLEFT", colorsWindow, 152, 320)
local borderSizeDown = CreateButton(colorsWindow, "borderSizeDown", "−", 36, function()
  settings.borderSize = Clamp(settings.borderSize - 1, 0, 8)
  borderSizeValue:SetText(tostring(settings.borderSize))
  SaveSettings()
  ApplyStyle()
end)
borderSizeDown:AddAnchor("TOPLEFT", colorsWindow, 220, 317)
local borderSizeUp = CreateButton(colorsWindow, "borderSizeUp", "+", 36, function()
  settings.borderSize = Clamp(settings.borderSize + 1, 0, 8)
  borderSizeValue:SetText(tostring(settings.borderSize))
  SaveSettings()
  ApplyStyle()
end)
borderSizeUp:AddAnchor("TOPLEFT", colorsWindow, 260, 317)
local closeColors = CreateButton(colorsWindow, "closeColors", "Done", 90, function() colorsWindow:Show(false) end)
closeColors:AddAnchor("BOTTOMRIGHT", colorsWindow, -16, -12)

local colorsButton = CreateButton(settingsWindow, "colorsButton", "Text colors", 130, function()
  colorsWindow:Show(true)
  CorrectWidgetPosition(colorsWindow)
  colorsWindow:Raise()
end)
colorsButton:AddAnchor("TOPLEFT", settingsWindow, 20, 560)

local typographyWindow = CreateEmptyWindow("wayfinderTypography", "UIParent")
typographyWindow:SetExtent(440, 326)
typographyWindow:SetUILayer("system")
typographyWindow:Enable(true)
typographyWindow:Clickable(true)
typographyWindow:EnableDrag(true)
typographyWindow:AddAnchor("CENTER", "UIParent", 0, 0)
typographyWindow:Show(false)
local typographyBackground = typographyWindow:CreateColorDrawable(0, 0.05, 0.08, 0.97, "background")
typographyBackground:AddAnchor("TOPLEFT", typographyWindow, 0, 0)
typographyBackground:AddAnchor("BOTTOMRIGHT", typographyWindow, 0, 0)
local typographyTitle = CreateLabel(typographyWindow, "typographyTitle", "WAYFINDER  /  TEXT SIZES", 15, { 0.95, 0.83, 0.58, 1 })
typographyTitle:SetExtent(390, 26)
typographyTitle:AddAnchor("TOPLEFT", typographyWindow, 18, 12)
local typographyHint = CreateLabel(typographyWindow, "typographyHint", "Set each element from 10 to 22 points", 11, { 0.78, 0.83, 0.81, 1 })
typographyHint:SetExtent(390, 18)
typographyHint:AddAnchor("TOPLEFT", typographyWindow, 18, 40)
local fontEntries = {
  { key = "titleFontSize", label = "Title" },
  { key = "continentFontSize", label = "Continent headers" },
  { key = "zoneFontSize", label = "Zone headers" },
  { key = "fontSize", label = "Quest text" },
  { key = "completedFontSize", label = "Completed text" },
  { key = "objectiveFontSize", label = "Objective text" },
}
local function UpdateFontLabels()
  for _, entry in ipairs(fontEntries) do
    entry.valueLabel:SetText(tostring(settings[entry.key]))
  end
end
for rowIndex, entry in ipairs(fontEntries) do
  local fontKey = entry.key
  local rowY = 68 + (rowIndex - 1) * 35
  local label = CreateLabel(typographyWindow, "fontName" .. rowIndex, entry.label, 11, { 0.84, 0.86, 0.83, 1 })
  label:SetExtent(128, 22)
  label:AddAnchor("TOPLEFT", typographyWindow, 16, rowY + 3)
  entry.valueLabel = CreateLabel(typographyWindow, "fontValue" .. rowIndex, "13", 10, { 0.78, 0.83, 0.81, 1 })
  entry.valueLabel:SetExtent(34, 22)
  entry.valueLabel:AddAnchor("TOPLEFT", typographyWindow, 152, rowY + 3)
  local down = CreateButton(typographyWindow, "fontDown" .. rowIndex, "−", 36, function()
    ChangeSetting(fontKey, -1, 10, 22)
    UpdateFontLabels()
  end)
  down:AddAnchor("TOPLEFT", typographyWindow, 220, rowY)
  local up = CreateButton(typographyWindow, "fontUp" .. rowIndex, "+", 36, function()
    ChangeSetting(fontKey, 1, 10, 22)
    UpdateFontLabels()
  end)
  up:AddAnchor("TOPLEFT", typographyWindow, 260, rowY)
end
UpdateFontLabels()
local closeTypography = CreateButton(typographyWindow, "closeTypography", "Done", 90, function() typographyWindow:Show(false) end)
closeTypography:AddAnchor("BOTTOMRIGHT", typographyWindow, -16, -12)
local typographyButton = CreateButton(settingsWindow, "typographyButton", "Text sizes", 130, function()
  typographyWindow:Show(true)
  CorrectWidgetPosition(typographyWindow)
  typographyWindow:Raise()
end)
typographyButton:AddAnchor("TOPLEFT", settingsWindow, 175, 560)

local profilesWindow = CreateEmptyWindow("wayfinderProfiles", "UIParent")
profilesWindow:SetExtent(440, 390)
profilesWindow:SetUILayer("system")
profilesWindow:Enable(true)
profilesWindow:Clickable(true)
profilesWindow:EnableDrag(true)
profilesWindow:AddAnchor("CENTER", "UIParent", 0, 0)
profilesWindow:Show(false)
local profilesBackground = profilesWindow:CreateColorDrawable(0, 0.05, 0.08, 0.97, "background")
profilesBackground:AddAnchor("TOPLEFT", profilesWindow, 0, 0)
profilesBackground:AddAnchor("BOTTOMRIGHT", profilesWindow, 0, 0)
local profilesTitle = CreateLabel(profilesWindow, "profilesTitle", "WAYFINDER  /  PROFILES", 15, { 0.95, 0.83, 0.58, 1 })
profilesTitle:SetExtent(390, 26)
profilesTitle:AddAnchor("TOPLEFT", profilesWindow, 18, 12)
local profilesHint = CreateLabel(profilesWindow, "profilesHint", "Save a named snapshot of tracker settings", 11, { 0.78, 0.83, 0.81, 1 })
profilesHint:SetExtent(390, 18)
profilesHint:AddAnchor("TOPLEFT", profilesWindow, 18, 40)
local profileNameEdit = profilesWindow:CreateChildWidget("x2editbox", "profileName", 0, true)
profileNameEdit:SetExtent(270, 28)
profileNameEdit:AddAnchor("TOPLEFT", profilesWindow, 18, 68)
profileNameEdit:SetInset(6, 3, 6, 3)
profileNameEdit:SetGuideText("Profile name (up to 24 chars)")
profileNameEdit:SetMaxTextLength(24)
profileNameEdit.style:SetAlign(ALIGN_LEFT)
profileNameEdit.style:SetFontSize(11)
profileNameEdit.style:SetColor(0.90, 0.90, 0.88, 1)
local profileNameBackground = profileNameEdit:CreateColorDrawable(0.06, 0.08, 0.10, 0.96, "background")
profileNameBackground:AddAnchor("TOPLEFT", profileNameEdit, 0, 0)
profileNameBackground:AddAnchor("BOTTOMRIGHT", profileNameEdit, 0, 0)
local profileStatus = CreateLabel(profilesWindow, "profileStatus", "", 11, { 0.78, 0.83, 0.81, 1 })
profileStatus:SetExtent(390, 18)
profileStatus:AddAnchor("TOPLEFT", profilesWindow, 18, 102)
local profileEntryLabels = {}
local profileEntryNames = {}
for index = 1, 8 do
  local entryIndex = index
  local label = CreateLabel(profilesWindow, "profileEntry" .. tostring(index), "", 10, { 0.72, 0.78, 0.80, 1 })
  label:SetExtent(398, 16)
  label:AddAnchor("TOPLEFT", profilesWindow, 18, 126 + ((index - 1) * 16))
  label:EnablePick(true)
  label:SetHandler("OnClick", function()
    local name = profileEntryNames[entryIndex]
    if name ~= nil then
      profileNameEdit:SetText(name)
      profileStatus:SetText("Selected: " .. name)
    end
  end)
  profileEntryLabels[index] = label
end
local profileTransferHint = CreateLabel(profilesWindow, "profileTransferHint", "Portable text · Ctrl+C to export, Ctrl+V to import · same-name import replaces", 10, { 0.78, 0.83, 0.81, 1 })
profileTransferHint:SetExtent(398, 16)
profileTransferHint:AddAnchor("TOPLEFT", profilesWindow, 18, 288)
local profileTransferEdit = profilesWindow:CreateChildWidget("x2editbox", "profileTransfer", 0, true)
profileTransferEdit:SetExtent(398, 26)
profileTransferEdit:AddAnchor("TOPLEFT", profilesWindow, 18, 306)
profileTransferEdit:SetInset(6, 3, 6, 3)
profileTransferEdit:SetGuideText("Paste an exported Wayfinder profile string")
profileTransferEdit:SetMaxTextLength(4096)
profileTransferEdit.style:SetAlign(ALIGN_LEFT)
profileTransferEdit.style:SetFontSize(9)
profileTransferEdit.style:SetColor(0.90, 0.90, 0.88, 1)
local profileTransferBackground = profileTransferEdit:CreateColorDrawable(0.06, 0.08, 0.10, 0.96, "background")
profileTransferBackground:AddAnchor("TOPLEFT", profileTransferEdit, 0, 0)
profileTransferBackground:AddAnchor("BOTTOMRIGHT", profileTransferEdit, 0, 0)

local function UpdateProfileList()
  local names = {}
  for name in pairs(settings.profiles) do
    names[#names + 1] = name
  end
  table.sort(names)
  for index, label in ipairs(profileEntryLabels) do
    local name = names[index]
    if name ~= nil then
      profileEntryNames[index] = name
      label:SetText((name == settings.activeProfile and "• " or "  ") .. name)
      label:Show(true)
    else
      profileEntryNames[index] = nil
      label:SetText("")
      label:Show(false)
    end
  end
  profileStatus:SetText("Active: " .. settings.activeProfile)
end

local function GetEnteredProfileName()
  local name = tostring(profileNameEdit:GetText() or ""):match("^%s*(.-)%s*$")
  if not IsValidProfileName(name) then
    profileStatus:SetText("Use 1–24 letters, numbers, spaces, _ or -")
    return nil
  end
  return name
end

local function EncodePortableString(value)
  return tostring(value):gsub("([^%w%._%-])", function(character)
    return string.format("%%%02X", string.byte(character))
  end)
end

local function DecodePortableString(value)
  local unescaped = value:gsub("%%(%x%x)", "")
  if unescaped:find("%%") or unescaped:find("[^%w%._%-]") then
    return nil
  end
  local decoded = value:gsub("%%(%x%x)", function(hex)
    return string.char(tonumber(hex, 16))
  end)
  if decoded:find("%c") then
    return nil
  end
  return decoded
end

local function EncodePortableScalar(value)
  if type(value) == "boolean" then
    return value and "b:1" or "b:0"
  end
  if type(value) == "number" then
    if value ~= value or value == math.huge or value == -math.huge then
      return nil
    end
    local encodedNumber = string.format("%.9g", value):gsub(",", ".")
    return "n:" .. encodedNumber
  end
  if type(value) == "string" then
    return "s:" .. EncodePortableString(value)
  end
  return nil
end

local function DecodePortableScalar(value)
  local valueType, payload = value:match("^([bns]):(.*)$")
  if valueType == "b" then
    if payload == "1" then return true end
    if payload == "0" then return false end
  elseif valueType == "n" then
    local number = tonumber((payload:gsub(",", ".")))
    if number ~= nil and number == number and number ~= math.huge and number ~= -math.huge then
      return number
    end
  elseif valueType == "s" then
    return DecodePortableString(payload)
  end
  return nil
end

local function EncodePortableProfile(profile)
  local fields = {}
  for _, key in ipairs(PROFILE_KEYS) do
    local value = profile[key]
    if value == nil then
      value = DEFAULTS[key]
    end
    local encodedValue
    if type(value) == "table" then
      local entries = {}
      for entryKey, entryValue in pairs(value) do
        local scalar = EncodePortableScalar(entryValue)
        if scalar == nil or (type(entryKey) ~= "string" and type(entryKey) ~= "number") then
          return nil, "Profile contains unsupported data"
        end
        entries[#entries + 1] = EncodePortableString(entryKey) .. "=" .. scalar
      end
      table.sort(entries)
      encodedValue = "t:" .. table.concat(entries, ",")
    else
      encodedValue = EncodePortableScalar(value)
      if encodedValue == nil then
        return nil, "Profile contains unsupported data"
      end
    end
    fields[#fields + 1] = key .. "=" .. encodedValue
  end
  return "WAYFINDER_PROFILE_V1;" .. table.concat(fields, ";")
end

local function DecodePortableProfile(text)
  local prefix = "WAYFINDER_PROFILE_V1;"
  if type(text) ~= "string" or #text > 4096 or text:sub(1, #prefix) ~= prefix or text:find(";;") or text:sub(-1) == ";" then
    return nil, "Unrecognized profile text"
  end
  local profile = {}
  local seen = {}
  for field in text:sub(#prefix + 1):gmatch("([^;]+)") do
    local key, encodedValue = field:match("^([^=]+)=(.*)$")
    if key == nil or not PROFILE_KEY_SET[key] or seen[key] then
      return nil, "Profile has an unknown or duplicate field"
    end
    seen[key] = true
    local default = DEFAULTS[key]
    if type(default) == "table" then
      if encodedValue:sub(1, 2) ~= "t:" then
        return nil, "Profile field type mismatch"
      end
      local value = {}
      local isColor = default[1] ~= nil
      local tablePayload = encodedValue:sub(3)
      if tablePayload:sub(1, 1) == "," or tablePayload:sub(-1) == "," or tablePayload:find(",,") then
        return nil, "Profile table contains an empty entry"
      end
      if tablePayload ~= "" then
        for entry in tablePayload:gmatch("([^,]+)") do
          local encodedKey, encodedScalar = entry:match("^([^=]+)=(.+)$")
          local decodedKey = encodedKey ~= nil and DecodePortableString(encodedKey) or nil
          local scalar
          if encodedScalar ~= nil then
            scalar = DecodePortableScalar(encodedScalar)
          end
          if decodedKey == nil or scalar == nil then
            return nil, "Profile table contains invalid data"
          end
          local tableKey = decodedKey
          if isColor then
            tableKey = tonumber(decodedKey)
            if tableKey == nil or tableKey < 1 or tableKey > 3 or tableKey ~= math.floor(tableKey) or type(scalar) ~= "number" then
              return nil, "Profile color is invalid"
            end
          elseif key == "collapsedSections" then
            local isContinentKey = decodedKey:sub(1, 10) == "continent:" and #decodedKey > 10
            local isZoneKey = decodedKey:sub(1, 5) == "zone:" and #decodedKey > 5
            if (not isContinentKey and not isZoneKey) or #decodedKey > 256 or type(scalar) ~= "boolean" then
              return nil, "Collapsed-section data is invalid"
            end
          else
            return nil, "Unsupported profile table"
          end
          if value[tableKey] ~= nil then
            return nil, "Profile table has duplicate keys"
          end
          value[tableKey] = scalar
        end
      end
      if isColor and (value[1] == nil or value[2] == nil or value[3] == nil) then
        return nil, "Profile color is incomplete"
      end
      profile[key] = value
    else
      local value = DecodePortableScalar(encodedValue)
      if value == nil or type(value) ~= type(default) then
        return nil, "Profile field type mismatch"
      end
      profile[key] = value
    end
  end
  for _, key in ipairs(PROFILE_KEYS) do
    if not seen[key] then
      if key == "notifyQuestCompletion" or key == "notifyQuestSound" or key == "showCompletionLabel" or key == "showQuestIds" or key == "keyboardNavigation" then
        profile[key] = DEFAULTS[key]
      else
        return nil, "Profile is missing a required field"
      end
    end
  end
  return profile
end

local function ApplyProfile(name)
  local profile = settings.profiles[name]
  if type(profile) ~= "table" then
    profileStatus:SetText("Profile not found")
    return false
  end
  local wasTrackerHidden = settings.hideDefaultTracker
  local wasLogHidden = settings.hideDefaultLog
  for _, key in ipairs(PROFILE_KEYS) do
    local value = profile[key]
    settings[key] = type(value) == type(DEFAULTS[key]) and CopySettingValue(value) or CopySettingValue(DEFAULTS[key])
  end
  settings.activeProfile = name
  NormalizeSettings()
  local nativeUiApplied = true
  if settings.hideDefaultTracker or wasTrackerHidden then
    nativeUiApplied = SetNativeQuestUIVisibility(UIC_QUEST_NOTIFIER, not settings.hideDefaultTracker) and nativeUiApplied
  end
  if settings.hideDefaultLog or wasLogHidden then
    nativeUiApplied = SetNativeQuestUIVisibility(UIC_QUEST_LIST, not settings.hideDefaultLog) and nativeUiApplied
  end
  ApplyPosition()
  ApplyStyle()
  lockButton:SetText(settings.locked and "Unlock position" or "Lock position")
  completedButton:SetText(settings.showCompleted and "Completed: shown" or "Completed: hidden")
  completionLabelButton:SetText(settings.showCompletionLabel and "Complete tag: shown" or "Complete tag: hidden")
  showAllQuestsButton:SetText("Clear list filters")
  objectivesButton:SetText(settings.showObjectives and "Objectives: shown" or "Objectives: hidden")
  defaultTrackerButton:SetText(settings.hideDefaultTracker and "Default tracker: hidden" or "Default tracker: shown")
  defaultLogButton:SetText(settings.hideDefaultLog and "Quest log: hidden" or "Quest log: shown")
  sortButton:SetText(settings.sortMode == "alphabetical" and "Quest order: A–Z" or "Quest order: journal")
  autoTrackButton:SetText(settings.autoTrackAccepted and "Auto-track: on" or "Auto-track: off")
  completionAlertButton:SetText(settings.notifyQuestCompletion and "Done alert: on" or "Done alert: off")
  completionSoundButton:SetText(settings.notifyQuestSound and "Done sound: on" or "Done sound: off")
  questIdsButton:SetText(settings.showQuestIds and "Quest IDs: on" or "Quest IDs: off")
  keyboardNavigationButton:SetText(settings.keyboardNavigation and "Keyboard: on" or "Keyboard: off")
  pinnedOnlyButton:SetText(settings.pinnedOnly and "Pinned only: on" or "Pinned only: off")
  UpdateSettingsText()
  UpdateColorLabels()
  borderSizeValue:SetText(tostring(settings.borderSize))
  UpdateFontLabels()
  SaveSettings()
  RefreshQuests()
  UpdateProfileList()
  profileStatus:SetText(nativeUiApplied and ("Loaded: " .. name) or ("Loaded " .. name .. "; native UI toggle failed"))
  return true, nativeUiApplied
end

local function CountProfiles()
  local count = 0
  for _ in pairs(settings.profiles) do count = count + 1 end
  return count
end

local saveProfileButton = CreateButton(profilesWindow, "saveProfile", "Save as", 100, function()
  local name = GetEnteredProfileName()
  if name == nil then return end
  if settings.profiles[name] == nil and CountProfiles() >= 8 then
    profileStatus:SetText("Maximum of 8 profiles reached")
    return
  end
  settings.profiles[name] = CaptureProfile()
  settings.activeProfile = name
  SaveSettings()
  UpdateProfileList()
  profileStatus:SetText("Saved: " .. name)
end)
saveProfileButton:AddAnchor("TOPLEFT", profilesWindow, 304, 68)
local loadProfileButton = CreateButton(profilesWindow, "loadProfile", "Load", 90, function()
  local name = GetEnteredProfileName()
  if name ~= nil then ApplyProfile(name) end
end)
loadProfileButton:AddAnchor("TOPLEFT", profilesWindow, 18, 258)
local deleteProfileButton = CreateButton(profilesWindow, "deleteProfile", "Delete", 90, function()
  local name = GetEnteredProfileName()
  if name == nil then return end
  if name == "Default" then
    profileStatus:SetText("The Default profile is protected")
    return
  end
  if settings.profiles[name] == nil then
    profileStatus:SetText("Profile not found")
    return
  end
  settings.profiles[name] = nil
  if settings.activeProfile == name then
    ApplyProfile("Default")
  else
    SaveSettings()
    UpdateProfileList()
    profileStatus:SetText("Deleted: " .. name)
  end
end)
deleteProfileButton:AddAnchor("TOPLEFT", profilesWindow, 116, 258)
local exportProfileButton = CreateButton(profilesWindow, "exportProfile", "Export", 88, function()
  local enteredName = tostring(profileNameEdit:GetText() or ""):match("^%s*(.-)%s*$")
  local name = enteredName == "" and settings.activeProfile or enteredName
  if not IsValidProfileName(name) then
    profileStatus:SetText("Use 1–24 letters, numbers, spaces, _ or -")
    return
  end
  local profile = settings.profiles[name]
  if type(profile) ~= "table" then
    profileStatus:SetText("Profile not found")
    return
  end
  local encoded, encodeError = EncodePortableProfile(profile)
  if encoded == nil then
    profileStatus:SetText(encodeError or "Could not export profile")
    return
  end
  if #encoded > 4096 then
    profileStatus:SetText("Profile text exceeds the 4096-character limit")
    return
  end
  profileNameEdit:SetText(name)
  profileTransferEdit:SetText(encoded)
  profileStatus:SetText("Export ready · click text, Ctrl+A, Ctrl+C")
end)
exportProfileButton:AddAnchor("TOPLEFT", profilesWindow, 18, 344)
local importProfileButton = CreateButton(profilesWindow, "importProfile", "Import & Load", 100, function()
  local name = GetEnteredProfileName()
  if name == nil then return end
  local imported, importError = DecodePortableProfile(profileTransferEdit:GetText() or "")
  if imported == nil then
    profileStatus:SetText(importError or "Could not import profile")
    return
  end
  if settings.profiles[name] == nil and CountProfiles() >= 8 then
    profileStatus:SetText("Maximum of 8 profiles reached")
    return
  end
  settings.profiles[name] = imported
  settings.activeProfile = name
  local loaded, nativeUiApplied = ApplyProfile(name)
  if loaded then
    profileStatus:SetText(nativeUiApplied and ("Imported and loaded: " .. name) or ("Imported " .. name .. "; native UI toggle failed"))
  end
end)
importProfileButton:AddAnchor("TOPLEFT", profilesWindow, 116, 344)
local closeProfilesButton = CreateButton(profilesWindow, "closeProfiles", "Done", 90, function() profilesWindow:Show(false) end)
closeProfilesButton:AddAnchor("BOTTOMRIGHT", profilesWindow, -16, -12)
UpdateProfileList()
local profilesButton = CreateButton(settingsWindow, "profilesButton", "Profiles", 130, function()
  profilesWindow:Show(true)
  CorrectWidgetPosition(profilesWindow)
  profilesWindow:Raise()
  UpdateProfileList()
end)
profilesButton:AddAnchor("TOPLEFT", settingsWindow, 20, 595)

keyboardNavigationButton = CreateButton(settingsWindow, "keyboardNavigationButton", "Keyboard: off", 145, function()
  settings.keyboardNavigation = not settings.keyboardNavigation
  keyboardNavigationButton:SetText(settings.keyboardNavigation and "Keyboard: on" or "Keyboard: off")
  SaveSettings()
  RefreshQuests()
  settingsStatus:SetText(settings.keyboardNavigation and "Click a quest; Up/Down select; Enter tracks" or "Keyboard navigation disabled")
end)
keyboardNavigationButton:AddAnchor("TOPLEFT", settingsWindow, 175, 595)

questIdsButton = CreateButton(settingsWindow, "questIdsButton", "Quest IDs: off", 90, function()
  settings.showQuestIds = not settings.showQuestIds
  questIdsButton:SetText(settings.showQuestIds and "Quest IDs: on" or "Quest IDs: off")
  SaveSettings()
  RefreshQuests()
  settingsStatus:SetText(settings.showQuestIds and "Rows show slot / quest ID" or "Quest ID labels hidden")
end)
questIdsButton:AddAnchor("TOPLEFT", settingsWindow, 320, 595)

local function RefreshAfterQuestEvent()
  ApplyNativeQuestUISettings()
  RefreshQuests()
end

local function OnQuestContextUpdated(questType, status)
  local autoTrackMessage
  local completionAlertMessage
  if settings.notifyQuestCompletion and status == "completed" and IsValidQuestType(questType) then
    local title = GetQuestTitle(questType)
    local message = "[Wayfinder] Quest complete: " .. title
    if X2Chat ~= nil and type(X2Chat.DispatchChatMessage) == "function" then
      local notifyOk = pcall(function()
        X2Chat:DispatchChatMessage(CMF_SYSTEM, message)
      end)
      if not notifyOk then
        DebugPrint("quest completion alert dispatch failed for " .. tostring(questType))
      end
    end
    completionAlertMessage = "Completed: " .. title
  end
  if settings.notifyQuestSound and status == "completed" and IsValidQuestType(questType) then
    if X2Sound ~= nil and type(X2Sound.PlayUISound) == "function" then
      local soundOk = pcall(function()
        X2Sound:PlayUISound("event_quest_completed_normal", false)
      end)
      if not soundOk then
        DebugPrint("quest completion sound failed for " .. tostring(questType))
      end
    else
      DebugPrint("quest completion sound skipped: sound API unavailable")
    end
  end
  if settings.autoTrackAccepted and status == "started" then
    if not IsValidQuestType(questType) then
      autoTrackMessage = "Auto-track: invalid quest ID"
      DebugPrint("auto-track skipped: invalid quest ID " .. tostring(questType))
    elseif X2Quest == nil or type(X2Quest.SetTrackingActiveQuest) ~= "function" then
      autoTrackMessage = "Auto-track APIs unavailable"
      DebugPrint("auto-track skipped: tracking API unavailable")
    else
      local foundIndex, lookupError = FindActiveQuestIndex(questType)
      if foundIndex == nil then
        autoTrackMessage = "Auto-track: " .. string.lower(lookupError or "quest lookup failed")
        DebugPrint("auto-track could not resolve quest " .. tostring(questType) .. ": " .. tostring(lookupError))
      else
        local trackOk = pcall(function()
          X2Quest:SetTrackingActiveQuest(foundIndex)
        end)
        if trackOk then
          autoTrackMessage = "Auto-track request sent"
        else
          autoTrackMessage = "Auto-track request failed"
          DebugPrint("auto-track failed for quest " .. tostring(questType))
        end
      end
    end
  end
  RefreshAfterQuestEvent()
  if completionAlertMessage ~= nil then
    statusLabel:SetText(completionAlertMessage)
  elseif autoTrackMessage ~= nil then
    statusLabel:SetText(autoTrackMessage)
  end
end

for _, eventName in ipairs({
  UIEVENT_TYPE.ENTERED_WORLD,
  UIEVENT_TYPE.LEFT_LOADING,
  UIEVENT_TYPE.ENTERED_SUBZONE,
  UIEVENT_TYPE.QUEST_NOTIFIER_START,
}) do
  UIParent:SetEventHandler(eventName, RefreshAfterQuestEvent)
end
UIParent:SetEventHandler(UIEVENT_TYPE.QUEST_CONTEXT_UPDATED, OnQuestContextUpdated)

UIParent:SetEventHandler(UIEVENT_TYPE.UI_RELOADED, function()
  DebugPrint("UI_RELOADED received; restoring tracker")
  RefreshAfterQuestEvent()
end)

local resetButton = CreateButton(settingsWindow, "resetButton", "Reset appearance", 145, function()
  local settingsWindowX = settings.settingsWindowX
  local settingsWindowY = settings.settingsWindowY
  local settingsWindowPositionSet = settings.settingsWindowPositionSet
  local showCompleted = settings.showCompleted
  local showCompletionLabel = settings.showCompletionLabel
  local pinnedOnly = settings.pinnedOnly
  local sortMode = settings.sortMode
  local autoTrackAccepted = settings.autoTrackAccepted
  local notifyQuestCompletion = settings.notifyQuestCompletion
  local notifyQuestSound = settings.notifyQuestSound
  local showObjectives = settings.showObjectives
  local showQuestIds = settings.showQuestIds
  local keyboardNavigation = settings.keyboardNavigation
  local collapsedSections = settings.collapsedSections
  local hideDefaultTracker = settings.hideDefaultTracker
  local hideDefaultLog = settings.hideDefaultLog
  local pinnedQuestIds = settings.pinnedQuestIds
  local profiles = settings.profiles
  local activeProfile = settings.activeProfile
  for key, value in pairs(DEFAULTS) do
    settings[key] = CopySettingValue(value)
  end
  settings.hideDefaultTracker = hideDefaultTracker
  settings.hideDefaultLog = hideDefaultLog
  settings.settingsWindowX = settingsWindowX
  settings.settingsWindowY = settingsWindowY
  settings.settingsWindowPositionSet = settingsWindowPositionSet
  settings.pinnedQuestIds = pinnedQuestIds
  settings.showCompleted = showCompleted
  settings.showCompletionLabel = showCompletionLabel
  settings.pinnedOnly = pinnedOnly
  settings.sortMode = sortMode
  settings.autoTrackAccepted = autoTrackAccepted
  settings.notifyQuestCompletion = notifyQuestCompletion
  settings.notifyQuestSound = notifyQuestSound
  settings.showObjectives = showObjectives
  settings.showQuestIds = showQuestIds
  settings.keyboardNavigation = keyboardNavigation
  settings.collapsedSections = collapsedSections
  settings.profiles = profiles
  settings.activeProfile = activeProfile
  questSearchText = ""
  questSearchEdit:SetText("")
  settings.displayMode = "alongside"
  settings.visible = true
  NormalizeSettings()
  ApplyPosition()
  ApplyStyle()
  tracker:Show(true)
  ApplyNativeQuestUISettings()
  SaveSettings()
  lockButton:SetText("Lock position")
  completedButton:SetText(settings.showCompleted and "Completed: shown" or "Completed: hidden")
  completionLabelButton:SetText(settings.showCompletionLabel and "Complete tag: shown" or "Complete tag: hidden")
  objectivesButton:SetText(settings.showObjectives and "Objectives: shown" or "Objectives: hidden")
  defaultTrackerButton:SetText(settings.hideDefaultTracker and "Default tracker: hidden" or "Default tracker: shown")
  defaultLogButton:SetText(settings.hideDefaultLog and "Quest log: hidden" or "Quest log: shown")
  sortButton:SetText(settings.sortMode == "alphabetical" and "Quest order: A–Z" or "Quest order: journal")
  autoTrackButton:SetText(settings.autoTrackAccepted and "Auto-track: on" or "Auto-track: off")
  completionAlertButton:SetText(settings.notifyQuestCompletion and "Done alert: on" or "Done alert: off")
  completionSoundButton:SetText(settings.notifyQuestSound and "Done sound: on" or "Done sound: off")
  questIdsButton:SetText(settings.showQuestIds and "Quest IDs: on" or "Quest IDs: off")
  keyboardNavigationButton:SetText(settings.keyboardNavigation and "Keyboard: on" or "Keyboard: off")
  pinnedOnlyButton:SetText(settings.pinnedOnly and "Pinned only: on" or "Pinned only: off")
  UpdateSettingsText()
  UpdateColorLabels()
  UpdateProfileList()
  borderSizeValue:SetText(tostring(settings.borderSize))
  UpdateFontLabels()
  settingsStatus:SetText("Appearance reset")
  RefreshQuests()
end)
resetButton:AddAnchor("TOPLEFT", settingsWindow, 200, 350)

local closeSettings = CreateButton(settingsWindow, "closeSettings", "Done", 90, function() ToggleSettings(false) end)
closeSettings:AddAnchor("TOPRIGHT", settingsWindow, -18, 14)

previewButton = CreateButton(settingsWindow, "previewButton", "Preview", 90, function()
  _G.Wayfinder.Preview()
end)
previewButton:AddAnchor("TOPLEFT", settingsWindow, 320, 385)

settingsWindow:SetCloseOnEscape(true)
SetUtilityWindowDragHandlers(settingsWindow, SaveSettingsWindowPosition)
for _, utilityWindow in ipairs({ colorsWindow, typographyWindow, profilesWindow }) do
  utilityWindow:SetCloseOnEscape(true)
  SetUtilityWindowDragHandlers(utilityWindow)
end
DebugPrint("startup: settings controls created")
_G.Wayfinder = {
  Refresh = RefreshQuests,
  RunAPIInventoryProbe = RunAPIInventoryProbe,
  Toggle = ToggleTracker,
  Settings = ToggleSettings,
  Preview = function()
    previewMode = not previewMode
    previewButton:SetText(previewMode and "Live quests" or "Preview")
    if not previewMode then
      RefreshQuests()
      return
    end
    statusLabel:SetText("PREVIEW  ·  style sample")
    ShowPreviewRows()
  end,
}

lockButton:SetText(settings.locked and "Unlock position" or "Lock position")
completedButton:SetText(settings.showCompleted and "Completed: shown" or "Completed: hidden")
completionLabelButton:SetText(settings.showCompletionLabel and "Complete tag: shown" or "Complete tag: hidden")
objectivesButton:SetText(settings.showObjectives and "Objectives: shown" or "Objectives: hidden")
defaultTrackerButton:SetText(settings.hideDefaultTracker and "Default tracker: hidden" or "Default tracker: shown")
defaultLogButton:SetText(settings.hideDefaultLog and "Quest log: hidden" or "Quest log: shown")
sortButton:SetText(settings.sortMode == "alphabetical" and "Quest order: A–Z" or "Quest order: journal")
autoTrackButton:SetText(settings.autoTrackAccepted and "Auto-track: on" or "Auto-track: off")
completionAlertButton:SetText(settings.notifyQuestCompletion and "Done alert: on" or "Done alert: off")
completionSoundButton:SetText(settings.notifyQuestSound and "Done sound: on" or "Done sound: off")
questIdsButton:SetText(settings.showQuestIds and "Quest IDs: on" or "Quest IDs: off")
keyboardNavigationButton:SetText(settings.keyboardNavigation and "Keyboard: on" or "Keyboard: off")
pinnedOnlyButton:SetText(settings.pinnedOnly and "Pinned only: on" or "Pinned only: off")
UpdateSettingsText()

DebugPrint("startup: applying final style")
ApplyStyle()
settings.visible = true
tracker:Show(true)
tracker:Raise()
previewMode = false
visibleQuestCount = 0
questScrollOffset = 0
previewButton:SetText("Preview")
statusLabel:SetText("Scanning quests…")
RefreshQuests()
if not ApplyNativeQuestUISettings() then
  settings.hideDefaultTracker = false
  settings.hideDefaultLog = false
  SetNativeQuestUIVisibility(UIC_QUEST_NOTIFIER, true)
  SetNativeQuestUIVisibility(UIC_QUEST_LIST, true)
  defaultTrackerButton:SetText("Default tracker: shown")
  defaultLogButton:SetText("Quest log: shown")
  SaveSettings()
  DebugPrint("default quest tracker toggle unavailable; left visible")
end
DebugPrint("startup: complete (live quest scan shown; preview available from settings)")
RunAPIInventoryProbe()
end

local initOk, initErr = pcall(Initialize)
if not initOk then
  DebugPrint("init failed: " .. tostring(initErr))
end
