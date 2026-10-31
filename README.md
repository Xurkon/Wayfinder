<p align="center">
  <img src="docs/images/wayfinder-logo.png" alt="Wayfinder fantasy-gold W wordmark" width="680">
</p>

<div align="center">

![Status](https://img.shields.io/badge/status-concept%20phase-orange?style=for-the-badge)
![Game](https://img.shields.io/badge/game-ArcheRage-7d5cff?style=for-the-badge)
![Release](https://img.shields.io/badge/release-none-lightgrey?style=for-the-badge)

**A customizable quest-tracker concept for ArcheRage.**

Wayfinder aims to become a complete, player-configurable replacement for the default quest tracker, while retaining a side-by-side mode for users who want both trackers.

</div>

---

## Project status: concept / drawing stage

Wayfinder is an early prototype, not an alpha release. It has reached the drawing stage: the addon creates and renders a tracker frame, grouped quest candidates, settings, and controls in ArcheRage. The latest screenshot confirms zone headers and quest rows render, but also confirms the main data bug remains: Wayfinder scans and displays 497 active-list API candidates while the native quest log has 57 entries. These candidates are not an accurate copy of the journal. There are no releases or user-ready builds.

Crash-isolation testing identified an invalid drawable layer value as the cause of the observed startup crash: creating a color drawable with the valid `artwork` layer loaded, while the earlier `accent` layer crashed. The full prototype has since been restored. This establishes the cause of that isolated crash, not reliability of every current feature.

**Current confidence:** The latest live WF27 probe found the stock notifier globals `GetNotifierQuestList`, `GetTodayQuestList`, and `GetQuestListCheckValue` missing from Wayfinder's addon namespace; `X2Quest.GetNotifierQuestList` and `X2Quest.GetQuestAcceptZoneName` are nil. The scan reported 494 active-list IDs, 440 not completed, and 440 eligible candidates, with 210 rows outside collapsed sections. These are not counts of the quests selected in the native tracker. The stock state accessors are marked available/not allowed, so accurate tracked-only sourcing needs an addon-permitted notifier-list accessor or another confirmed state source. This phase targets the native tracked HUD set; matching the full journal is out of scope. Zone headers appear in the screenshot, but their mapping remains provisional: the bundled title-checked English database is AA 10.8.1.0 while the latest ArcheRage log reports client 10.0.2.9. Unmatched entries remain visible with unknown-location fallback. The first diagnostic line reports whether restricted method groups (`F`, `J`, `L`, `S`) exist as function references; those flags do not invoke methods or prove server permission. Totals are explicitly labeled API candidates, not confirmed native tracked quests. Settings-window dragging and saved coordinates are now implemented in source, including preserving its position through Reset appearance; this update has not been tested in-game. Other optional features also need live verification. The source is copied to the live addon through a junction; source equality does not establish what the running client has loaded.

### Drawing-stage screenshot

![Wayfinder drawing-stage screenshot](docs/images/wayfinder-drawing-stage.png)

This is a real in-game screenshot supplied during development, not a finished mockup. It shows the current tracker with zone headers and quest rows, while its `497 API quest candidates` status confirms the journal-membership bug is still unresolved (the native log has 57 entries). It also shows the settings panel and its crowded controls. Source now gives settings a title drag target and persists its corrected position; reset preserves those coordinates. These settings changes still need an in-game check.

## What exists in the prototype

These items describe code present in the source, not features confirmed to work in-game.

- Standalone tracker with live quest scan on startup, optional preview mode, refresh, settings, and Addon Manager entry.
- Quest scan over unique active-list IDs, with completed rows shown by default and an option to hide them; offline saga/today tags are reported but not yet used to exclude entries.
- Quest rows with completion styling, click-to-request tracking through the allowed active-list index API, and opt-in auto-tracking for newly accepted quests. Both tracking paths resolve the quest ID to its current active-list index immediately before requesting selection, avoiding stale indices after list changes. Completed entries are shown by default because the active-list count includes them, and can be filtered in settings. Existing version 2 saves migrate once to this default. Selected-row highlighting remains pending; optional objective rows use the function ArcheRage explicitly enabled on October 27, with live-client verification pending.
- Optional quest-completion system-chat and UI-sound alerts for the `completed` status handled by stock `QUEST_CONTEXT_UPDATED`; both disabled by default. Sound uses the allowlisted `X2Sound:PlayUISound` API and the documented `event_quest_completed_normal` sound name; event timing and actual playback need in-game verification.
- Title-verified zone/continent lookup from the downloaded game database, with `Other / Unknown Zone` fallback for unmatched entries.
- Live title search, journal/alphabetical ordering, pinned-only filtering, persistent quest pins, and collapsible sections.
- Dedicated close and minimize/expand controls; Escape no longer closes the tracker, and continent/zone toggles use plain `+` / `-` markers.
- A one-click list-filter reset clears search, pinned-only mode, and collapsed sections without deleting saved pins or changing appearance.
- Optional completed-row visibility, a toggleable “Complete” row suffix, and objective-row visibility.
- Appearance controls for width, height, typography, row spacing, colors, opacity, border, and background.
- Scrollable viewport, bounded edge/corner resize, position locking, and saved position/dimensions.
- Per-character settings persistence and up to eight named profiles, including validated text import/export.
- Optional controls to hide or restore the native quest notifier and quest list. Side-by-side mode remains the default.

Quest discovery, objective/profile copy-paste behavior, tracker layout, tracking selection, and native UI visibility still need live verification against the current source. The user has observed that the tracker stays open across Addon Manager refresh; persistence of individual settings through refresh, profile switching, appearance reset, and import/export still needs feature-specific verification.

## Development checklist

### 1. Safe, visible foundation

- [x] Isolate the startup crash to the unsupported drawable layer value and restore the complete prototype source.
- [x] Load the shared UI helper and import the widget types used by the custom tracker.
- [x] Add a synthetic preview so drawing can be checked independently from quest discovery.
- [x] Start with a live quest scan, keep preview opt-in, and refresh live data when leaving preview or resetting appearance.
- [x] Clear stale quest rows and mark scan counters unknown when the active-quest API is unavailable or fails.
- [x] Reject malformed active-quest counts before looping; use the same finite-integer check in auto-track lookup.
- [x] Validate quest IDs consistently before rendering, tracking, or sending completion alerts.
- [x] Register Wayfinder with Addon Manager so its settings action can reopen the tracker and settings.
- [x] Persist appearance settings and tracker position through the addon's data API.
- [x] Keep the tracker visible during initial prototype testing and reopen it after manager refresh.
- [ ] Confirm the complete addon reaches the world reliably across repeated launches.
- [ ] Verify panel layering, screen positioning, scaling, resolution changes, relog, and refresh behavior.
- [ ] Verify launcher, drag, lock, refresh, settings, and preview controls against the latest source.

### 2. Source the native tracked-quest set

- [x] Identify the native notifier's selected quest list and its separate daily-assignment list in the stock client scripts.
- [x] Probe stock list and checkbox helpers in the live ArcheRage addon environment. In WF27, `GetNotifierQuestList`, `GetTodayQuestList`, and `GetQuestListCheckValue` were missing; `X2Quest.GetNotifierQuestList` and `X2Quest.GetQuestAcceptZoneName` were nil.
- [x] Confirm the underlying X2 state accessors `X2:GetQuestNotifierListUiData()` and `X2:GetQuestContextStateValuesUiData()` are marked available/not allowed in the local inventory.
- [ ] Request or obtain an addon-permitted tracked/notifier list accessor, including any separately tracked daily assignments.
- [ ] Populate Wayfinder rows only from the native tracked set; use active-list lookup only when a tracked row needs an index for a tracking action.
- [ ] Verify Wayfinder adds and removes rows when native tracker selections change, including daily assignments, reloads, and abandoned/completed quests.
- [x] Keep active-list candidate, completion, objective-count, and rendering counters available for diagnosis; they do not establish notifier membership.
- [x] Keep completed-row presentation configurable for completed quests that remain in the native tracked set.
- [x] Migrate version 2 settings and profiles once to the show-completed default so previously saved filters do not suppress rows after refresh.
- [x] Keep “Reset appearance” scoped to visual settings while preserving quest filters, pins, sorting, and alert/auto-track preferences.
- [x] Show on-screen counters for API slots, valid IDs, completion states, eligible candidates, rendered quest rows, title fallbacks, invalid IDs, duplicates, unreadable slots, and optional objective-read failures; mode flags identify objective visibility, completed visibility, pinned-only, and search filters. Keep catalog-match counts and sampled details in the debug output. These are not presented as a verified journal count.
- [x] Show a compact active-list slot/ID/completion/title sample directly in the tracker on every scan, prioritizing an ID reported not completed when available, so row-count mismatches and empty scans can be diagnosed without chat output.
- [x] Report API candidates separately from rows actually visible after collapsing sections; label these counts as candidates, not confirmed native-journal quests.
- [x] Make empty states explain when completed-only or pinned-only settings are hiding quest rows.
- [x] Add a one-click filter reset that restores completed rows, clears search and pinned-only filtering, expands all sections, and preserves saved pins.
- [x] Distinguish a zero-slot active-list response from nonzero slots that yield no valid quest IDs; show the API slot count and invalid/read-error counters.
- [x] Show the source build marker at the start of the tracker status line and in scan diagnostics, so stale loaded scripts are easy to spot.
- [x] Show non-invasive runtime function-presence flags for journal-state predicates, stock category filters, main-list methods, and quest status getters without calling methods outside the local allowlist.
- [x] Probe stock notifier helper visibility at startup and on manual Refresh, sample normal/daily quest arrays and checkbox state, and check zone-getter presence without invoking the unverified zone method.
- [x] Extend the startup/Refresh probe to report presence only for the proposed tracking, context-state, journal-state, completion, category, distance, and underlying X2 notifier getters; do not invoke these methods.
- [ ] Review the WF29 startup/Refresh probe in ArcheRage; presence alone does not prove an API is permitted or has native-tracker semantics.
- [x] Add opt-in objective rows using the function ArcheRage explicitly enabled on October 27, 2026; use the stock client's false-terminated, 1-based iteration pattern and show read errors in diagnostics.
- [ ] Verify objective getters, returned text/counts, and visual layout in ArcheRage; the installed legacy inventory is stale for these explicit server permissions.
- [x] Count active-list entries with positive, zero, or failed journal objective-count results for diagnostics without using those results as a membership filter.
- [ ] Compare objective-count diagnostics with the 57 native journal entries and confirm completed zero-objective rows before considering any filter.
- [ ] Verify the objective toggle persists through Addon Manager refresh, appearance reset, named-profile save/load, and portable profile import/export; confirm objective iteration stops cleanly on the native `false` terminator.
- [ ] Refresh in-game and compare active/main counts, filter counters, and displayed rows against the reported 57 quests.
- [ ] Compare the 497 active-list candidates with the 57 native journal entries using the visible build marker and scan counters. If a refresh shows zero quest rows, capture A/T/C/I/U and E/R/H/M/Q/X/O/V/D/P/S beside the native journal count and include search, pinned-only, completed, and collapsed-section states.
- [ ] Compare representative native main/story, normal/zone, daily, weekly, and vocation rows by exact title and active-list ID/slot; do not infer category from numeric ID ranges. See [quest API diagnostic procedure](docs/quest-api-reference.md#quest-identifiers-are-not-quest-categories).
- [x] Add an opt-in **Quest IDs** diagnostic that labels each rendered row with its active-list slot and `questType` ID, without calling restricted category APIs.
- [ ] Verify titles, objectives, completion state, and selected-quest tracking on real journal entries.
- [ ] Confirm accept, objective update, complete, abandon, turn-in, world-entry, and zone-change refreshes.
- [ ] Test completed quests, long titles, empty results, duplicate IDs, and unexpected API responses.

### 3. Quest organization and interaction

- [x] Group title-verified catalog entries under static zone and continent labels; retain unknown fallbacks.
- [x] Exclude explicit untranslated catalog placeholders, normalize catalog titles to the runtime title-cleanup rules, and use `Unknown Zone` when zone data is missing instead of treating quest category labels as geography.
- [x] Validate catalog IDs and metadata before output, and replace the catalog atomically so interrupted generation preserves the previous file.
- [x] Add persistent collapsible sections, quest pins, pinned-first ordering, and pinned-only filtering.
- [x] Add journal or alphabetical sorting and a title search.
- [x] Add optional completed-row visibility.
- [ ] Verify grouping labels, collapsed-state persistence, sorting, search, and pinning in-game.
- [x] Derive the `w_` → Nuia, `e_` → Haranya, and `o_` → Auroria mapping from game zone-group IDs and cross-check representative zones against the official ArcheRage Wiki; other group types fall back to `Other`.
- [ ] Confirm the current build marker appears after Addon Manager refresh, then verify catalog title/location matches, unknown-location fallbacks, and continent headers in-game.
- [ ] Verify auto-tracking of newly accepted quests with ArcheRage events and tracking APIs.
- [x] Add basic quest-row actions with permitted APIs: left-click resolves the current active-list index and requests tracking; right-click toggles a persistent pin. Additional context-menu actions remain pending verified APIs.
- [x] Add an opt-in quest-completion alert using the `completed` status handled by stock quest-context code and imported chat API; leave event timing verification pending.
- [x] Add a separately configurable, opt-in quest-completion sound using the allowed UI sound API and a documented quest-completion sound name; keep it off by default and persist it with settings and profiles.
- [ ] Verify the sound, event timing, manager-refresh persistence, appearance-reset preservation, profile save/load, and portable profile import/export in ArcheRage.

### 4. Visual customization and window behavior

- [x] Add configurable width, height, text sizes, row spacing, opacity, panel background, border, and per-element text colors.
- [x] Keep the “Reset appearance” action scoped to visual settings while preserving quest filters, pins, sorting, and alert/auto-track preferences.
- [x] Keep labels inside the panel with fixed extents and ellipsis; separate title and controls.
- [x] Add a clipped, mouse-wheel-scrollable quest viewport.
- [x] Add eight transparent edge/corner resize targets backed by `Widget:StartSizing`, without using the locally blocked `X2Input:GetMousePos`, and persist resized dimensions.
- [x] Add position locking and persistent saved position.
- [x] Correct saved, resized, and dragged window positions to screen bounds using the client UI-bounds API.
- [x] Make settings, color, typography, and profile panels draggable and correct their positions when opened or released.
- [x] Add a title-area drag target for the settings panel, save its corrected position, and preserve that position through Reset appearance.
- [ ] Verify text clipping, control spacing, scrolling, resizing, bounds, and persistence at narrow/wide sizes and different UI scales.
- [ ] Verify settings-panel dragging, bounds, saved position, and Reset appearance behavior in-game.
- [x] Add a persisted “Complete” suffix toggle for completed rows, independent of completion color and filtering. Further row-level spacing and icon/status treatments remain pending confirmed APIs and live testing.
- [x] Keep the tracker open on Escape and add explicit close and minimize/expand controls.
- [x] Replace potentially unsupported collapse glyphs with plain plus/minus markers for continent and zone headers.
- [ ] Verify Escape behavior, minimize/expand, close, and header toggles in-game.
- [x] Add opt-in keyboard navigation for quest rows: click to focus, use Up/Down to select, and Enter to request tracking; persist the option in settings and profiles.
- [ ] Verify keyboard focus, selection scrolling, tracking requests, refresh persistence, profile import/export, and behavior while the search box has focus; add localization.

### 5. Native tracker replacement and optional navigation

- [x] Add opt-in visibility controls for the documented native quest notifier and quest list; default to side-by-side mode.
- [x] Avoid an unsolicited native “show” call on startup that can open the stock quest log.
- [ ] Verify hide, restore, profile transitions, and behavior after manager refresh in ArcheRage.
- [ ] Determine whether a fully synchronized replacement can match stock selection, objective updates, and tracking behavior.
- [ ] Keep a reliable way to restore the native tracker before treating replacement mode as complete.
- [ ] Request addon permission for `X2Quest:GetQuestDirInfo(questType)` before attempting distance sorting; the stock notifier uses its `dist`, `angle`, and `height`, but the local X2 inventory marks it available/not allowed. The stock decal APIs are also restricted; do not call them unless ArcheRage enables them.

## Intended experience

The long-term goal is a complete visual and functional replacement for the default quest tracker, with control over layout, information density, sorting, filtering, interaction, and persistence. Users should also be able to run both trackers simultaneously. Replacement mode is not considered reliable until live testing proves that the native tracker can be suppressed and restored while Wayfinder keeps accurate quest state.

Potential later additions include context actions, more completion-notification choices, map integration, and addon integration hooks. They depend on supported ArcheRage APIs and server rules.

## Settings profiles

Open **Settings → Profiles**, enter a name, and choose **Save as**. Select a saved profile row or enter its name to load or delete it; `Default` cannot be deleted. Up to eight profiles are stored per character. The active profile follows subsequent settings changes. Pins are shared across profiles and omitted from portable strings. **Export** writes a versioned text value into the field for manual copy. To import, paste a value, enter a destination profile name, and choose **Import & Load**. Existing names are overwritten; creating a ninth profile is rejected. Older V1 exports without the completion-alert or sound setting import with those options off; exports without the newer completion-label option keep that label enabled. Copy/paste, import validation, and native visibility transitions need in-game verification.

**Settings → Keyboard** enables optional row navigation. Click a quest row to select/focus it without tracking, use **Up/Down** to move the selection, and press **Enter** to request tracking. The selected row is marked with `›` and scrolls into view. This preference is included in named profiles and portable exports; older exports default it off. Focus behavior still needs in-game verification.

## Safety and compatibility

- This addon targets **ArcheRage**. Compatibility with ArcheAge Classic or other servers is not established.
- WoW addons are inspiration for interaction and customization only; WoW APIs do not imply equivalent ArcheRage capabilities.
- Use sanctioned ArcheRage addon Lua/UI APIs and verify behavior in the target client.
- The local legacy inventory separates addon-allowed methods from “Available/not allowed” methods. Do not call a stock-only method merely because stock UI scripts use it.
- Lua `pcall` can catch ordinary Lua errors; it cannot make unsafe native UI arguments valid or guarantee recovery from a client crash.

## Installation and testing

There is no public release yet. Development testing uses the maintainer's local ArcheRage addon folder. The current tracker can be opened from Wayfinder's Addon Manager settings action if its window is hidden or its launcher is unavailable. The status must start with the current short build marker (`WF27`); if it still shows `WF26`, the Addon Manager likely has not loaded this source. Startup and manual **Refresh** both print the bounded `[Wayfinder probe]` diagnostics; these use ArcheRage's `X2Chat` API, not WoW APIs. Press **Refresh** to rerun the probe after the native tracker is initialized, and capture its output together with the status line, both quest diagnostic lines, and the quest count visible in the native log. Current code reports “API list empty” for zero API slots and “No valid IDs” for slots without valid IDs, and applies title search as you type. Nonempty totals say **API quest candidates** or **filtered candidates**; when sections are collapsed, the status also gives the visible-row count. These are not confirmed native-journal entries. The first diagnostic line also includes `F`, `J`, `L`, and `S` function-presence flags for restricted API groups; these are indicators only and do not call those methods. The API sample line identifies the active-list slot, ID, and objective count when available. The filter line shows `JC` for positive counts, with `J0` and `J?` for zero/error counts on wider panels; these counts do not establish quest membership. Enable **Objectives** in settings to inspect objective text; `O` records text-read failures and `V+` shows the setting is on. **Settings → Clear list filters** restores completed rows, clears search and pinned-only mode, and expands all sections while preserving pins. Turn **Quest IDs** on to show `[slot N | type N]` for each displayed row. The native journal does not print a comparable numeric ID; match the exact title and objective, then confirm Wayfinder resolves the same type to an active-list slot when tracking. That proves internal consistency, not that the type is the journal's canonical database ID. Enable **Done sound** to check the optional quest-completion cue; it remains off by default. Current local `ArcheRage.log` and `Chat.log` were written October 29 at 4:39 PM and 4:36 PM; searches found no Wayfinder scan counters in either file, so use the on-screen diagnostics for quest comparisons.

For ArcheAge-aware editor diagnostics, X2's README recommends the Lua Language Server and its API definitions. Wayfinder's [`.luarc.jsonc`](.luarc.jsonc) loads both `Addon/x2/src` and the shared `Addon/globals` directory (adjust the relative paths if your folders are arranged differently). Run the installed `lua-language-server.exe` with `--check=<Wayfinder-root>` and `--configpath=<Wayfinder-root>/.luarc.jsonc`. This check reports 7 warnings and no errors; one known warning is that the local X2 `X2Quest` stub lacks `GetActiveQuestObjectiveText`, which ArcheRage enabled in its October 27 update. The remaining warnings concern nil/type annotations and event-handler return annotations.

Generic supplemental checks: `selene --config selene.toml wayfinder.lua quest_catalog.lua` (ArcheAge globals are declared in `archeage.yml`) and, from WSL Ubuntu, `luac -p wayfinder.lua`. The current Selene run reports 0 errors and 19 style/global-usage warnings, including an unused local. The WSL Lua 5.1 syntax check passed. Neither static check replaces a live ArcheRage UI test.

## Contributing and feedback

Wayfinder remains in concept stage. Feedback about tracker behavior, layout, and useful features is welcome. See the [ArcheRage quest and achievement API access request](docs/archerage-api-request.md) for the current capability list and a developer-ready request. API proposals should include a reference or reproducible in-game observation, since unsupported UI calls can crash the client.

## License

No license has been selected yet. Until one is added, the repository does not grant permission to redistribute or publish modified copies.
