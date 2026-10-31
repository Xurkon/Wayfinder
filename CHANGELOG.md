# Changelog

All notable changes to Wayfinder are recorded here. The project is still in concept/drawing stage; an entry describes source changes and does not imply every feature has been verified in the live client.

## Unreleased — 2026-10-30

### Quest data and API diagnostics

- Added an offline quest metadata catalog with quest ID, English title, zone, continent, saga, and today-assignment tags, plus a generator for rebuilding the catalog from the local ArcheAge database dump.
- Added exact title-and-ID checks before applying catalog geography; unknown or mismatched records stay visible with an unknown-location fallback.
- Kept the active-list count/type scan, completion state, objective counts, and rendered-row totals as separate diagnostics. Labels distinguish API candidates from confirmed journal or native-tracker entries.
- Added validation for active-list counts and quest IDs, duplicate and malformed-ID accounting, slot-read errors, title fallbacks, and objective-read errors. Failed or invalid reads no longer leave stale-looking scan counts or silently remove uncertain rows.
- Added an on-screen sample of active-list slot, quest ID, completion state, and title, plus a build marker and function-presence flags for investigating stale builds and unavailable API methods.
- Added a startup/refresh inventory probe for stock notifier helpers and suggested API surfaces. It checks visibility/presence only for restricted or unverified methods and does not invoke them.
- Added optional objective rows using `X2Quest:GetActiveQuestObjectiveText(type, objIdx)`, with bounded 1-based iteration and diagnostics. ArcheRage announced this API as enabled on October 27, 2026; live result and layout checks remain pending.
- Documented that the active quest API currently returns substantially more candidates than the native journal shows (latest comparison: 497 versus 57). The native checked/tracked quest source remains unresolved; no candidate count is presented as the native tracked set.

### Tracker controls and customization

- Added live quest scanning on startup, manual refresh, and an optional synthetic preview.
- Added completion styling, configurable completed-row visibility and completion labels, optional objective display, title search, alphabetical or journal ordering, pinned-only filtering, persistent quest pins, and collapsible continent/zone sections.
- Added a one-click list-filter reset that clears search and pinned-only filtering and expands sections without deleting pins or resetting unrelated settings.
- Added tracker close and minimize/expand controls; Escape no longer closes the tracker. Continent and zone headers use compact plus/minus toggles.
- Added scrollable, clipped quest rows and bounded edge/corner resizing, position locking, and saved position and dimensions.
- Added appearance controls for width, height, text sizes, row spacing, colors, opacity, border, and background.
- Added per-character settings persistence and up to eight named profiles, including validated profile import/export.
- Added optional keyboard navigation and selected-quest tracking requests.
- Added optional auto-track for accepted quests and optional quest-completion chat and UI-sound alerts; these are disabled by default.
- Added optional controls for hiding/restoring the native quest notifier and quest list via `ADDON:ShowContent`, with side-by-side mode as the default.
- Registered Wayfinder with Addon Manager so its settings action can reopen the tracker and settings windows.

### Crash, layout, and persistence fixes

- Isolated the observed startup crash to an unsupported drawable layer value; the valid `artwork` layer loaded during isolation while the earlier `accent` layer crashed.
- Restored the full tracker after the crash-isolation pass and kept live quest data as the normal startup mode, with preview opt-in.
- Fixed settings reset behavior to preserve quest filters, pins, sorting, profile/alert preferences, native UI visibility choices, and the settings-window position while resetting appearance.
- Added guards for malformed quest counts and IDs, and made click-to-track/auto-track resolve the current active-list index immediately before requesting tracking to avoid stale indices.

### Documentation and development tooling

- Reworked the README with project status, actual observed progress, known data limitations, a detailed feature checklist, and explicit distinction between implemented source and live-verified behavior.
- Added `docs/quest-api-reference.md` covering local API allowlist conflicts, stock journal/notifier behavior, scan diagnostics, geography, and unresolved tracked-set access.
- Added `docs/archerage-api-request.md` with the APIs/capabilities Wayfinder needs and a developer-ready request.
- Added Selene and LuaLS configuration for ArcheRage addon globals, plus the quest-catalog generator.
- Updated `toc.g` to load the quest catalog before `wayfinder.lua`.
- Refreshed the Wayfinder logo asset and documented the supplied drawing-stage screenshot.

### Verification status

- The user has observed the tracker drawing, zone headings, controls, and Addon Manager settings entry in ArcheRage. A runtime probe confirmed the stock notifier helper globals are missing from Wayfinder's addon namespace.
- A live scan showed 497 API candidates versus 57 quests in the native journal; this mismatch is unresolved and prevents claiming accurate native-tracker replacement.
- Later changes to settings-window dragging/position persistence, optional objective rendering, tracking actions, profile import/export, native UI visibility, and the full latest source have not all been rechecked in-game.
- The repository README records the latest static Selene and Lua 5.1 syntax-check results. Static checks do not establish live-client correctness.
- No release build is available.
