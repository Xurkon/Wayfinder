# Changelog

I use this changelog to record Wayfinder’s development. The addon is still in concept/drawing stage; changes listed here describe the source and do not mean every feature has been verified in the live client.

## Unreleased — 2026-10-30

### Quest data and API diagnostics

- I added an offline quest metadata catalog with quest IDs, English titles, zones, continents, saga tags, and today-assignment tags, along with a generator for rebuilding it from the local ArcheAge database dump.
- I added exact quest-ID and title checks before applying catalog geography. Unknown or mismatched records remain visible with an unknown-location fallback.
- I separated active-list counts, quest IDs, completion state, objective counts, and rendered-row totals in the diagnostics. Wayfinder labels API candidates separately from confirmed journal or native-tracker quests.
- I added validation and counters for malformed active-list counts and quest IDs, duplicates, slot-read errors, title fallbacks, and objective-read errors. Invalid or failed reads no longer leave stale-looking counts or silently remove uncertain rows.
- I added an on-screen sample of the active-list slot, quest ID, completion state, and title, plus a build marker and function-presence flags to help identify stale builds and unavailable methods.
- I added a startup/refresh probe for stock notifier helpers and proposed API surfaces. For restricted or unverified methods, it checks only whether references are present and does not call them.
- I added optional objective rows using `X2Quest:GetActiveQuestObjectiveText(type, objIdx)`, with bounded 1-based iteration and diagnostics. ArcheRage announced this API as enabled on October 27, 2026; I still need to verify its live results and layout.
- My latest comparison showed 497 active-list API candidates while my native quest journal showed 57 quests. I have not resolved how to identify the exact native checked/tracked quest set, and Wayfinder does not label API candidates as confirmed tracked quests.

### Tracker controls and customization

- I added live quest scanning at startup, manual refresh, and an optional synthetic preview.
- I added completion styling, configurable completed-row visibility and completion labels, optional objective display, title search, alphabetical or journal ordering, pinned-only filtering, persistent quest pins, and collapsible continent/zone sections.
- I added a one-click list-filter reset that clears search and pinned-only filtering and expands sections without deleting pins or resetting unrelated settings.
- I added close and minimize/expand controls. Escape no longer closes the tracker, and continent/zone headers use compact plus/minus toggles.
- I added clipped, scrollable quest rows; bounded edge/corner resizing; position locking; and saved position and dimensions.
- I added appearance controls for width, height, text sizes, row spacing, colors, opacity, border, and background.
- I added per-character settings persistence and up to eight named profiles, including validated profile import/export.
- I added optional keyboard navigation and selected-quest tracking requests.
- I added optional auto-tracking for accepted quests and quest-completion chat/UI-sound alerts. These options default to off.
- I added optional controls to hide or restore the native quest notifier and quest list through `ADDON:ShowContent`; side-by-side mode remains the default.
- I registered Wayfinder with Addon Manager so its settings action can reopen the tracker and settings windows.

### Crash, layout, and persistence fixes

- I isolated the observed startup crash to an unsupported drawable layer value: the valid `artwork` layer loaded during isolation, while the earlier `accent` layer crashed.
- I restored the full tracker after crash-isolation testing and made live quest data the normal startup view, with preview available as an option.
- I changed Reset appearance to preserve quest filters, pins, sorting, profile/alert preferences, native UI visibility choices, and the settings-window position while resetting visual settings.
- I added guards for malformed quest counts and IDs. Click-to-track and auto-track now resolve the current active-list index immediately before requesting tracking, avoiding stale indices.

### Documentation and development tooling

- I rewrote the README to record the actual project status, observed progress, known data limitations, feature checklist, and which behavior still needs live verification.
- I added `docs/quest-api-reference.md` to document the local API allowlist discrepancies, stock journal/notifier behavior, scan diagnostics, geography, and unresolved tracked-set access.
- I added `docs/archerage-api-request.md` with the API capabilities Wayfinder needs and a request for the addon developers.
- I added Selene and LuaLS configuration for ArcheRage addon globals, along with the quest-catalog generator.
- I updated `toc.g` to load the quest catalog before `wayfinder.lua`.
- I refreshed the Wayfinder logo asset and documented the drawing-stage screenshot I supplied.

### Verification status

- My in-game screenshots show the tracker drawing quest rows and zone headings, and I confirmed the Addon Manager settings action opens Wayfinder. A runtime probe showed that the stock notifier helper globals are missing from Wayfinder’s addon namespace.
- The latest scan I supplied showed 497 API candidates versus 57 quests in my native journal. This mismatch remains unresolved, so I cannot claim Wayfinder accurately replaces the native tracked-quest list yet.
- I have not rechecked all later changes to settings-window dragging/position persistence, objective rendering, tracking actions, profile import/export, native UI visibility, or the complete latest source in game.
- The README records the latest Selene and Lua 5.1 syntax-check results. Passing static checks does not establish that the addon works correctly in the live client.
- I do not have a release build yet.
