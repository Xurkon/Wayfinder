# Wayfinder

<div align="center">

![Status](https://img.shields.io/badge/status-concept%20phase-orange?style=for-the-badge)
![Game](https://img.shields.io/badge/game-ArcheRage-7d5cff?style=for-the-badge)
![Release](https://img.shields.io/badge/release-none-lightgrey?style=for-the-badge)

**A customizable quest-tracker concept for ArcheRage.**

Wayfinder aims to become a complete, player-configurable replacement for the default quest tracker, while retaining a safe side-by-side mode when replacement is unavailable or unwanted.

</div>

---

## Project status: concept phase

Wayfinder is an early prototype, not an alpha release. The project is still establishing which ArcheRage UI and quest APIs are safe and supported, and the current interface has not yet been validated in a live game session. There are no releases or user-ready builds.

The present code is a UI prototype restored after crash-isolation testing. A test confirmed that creating a color drawable with the valid `artwork` layer succeeds where the earlier `accent` layer crashed during client startup. This points to an invalid native UI layer argument as the crash cause. It does **not** establish that the complete tracker or its quest behavior works reliably.

**Current confidence:** the addon has reached the in-game load stage in isolation tests; visible tracker layout, controls, quest API calls, persistence, and replacement behavior still need live validation.

## What exists in the prototype

- A standalone tracker window intended to run beside the game’s default tracker.
- A launcher button, tracker title, refresh and settings controls, and a preview mode.
- A separate appearance panel with controls for width, font size, row spacing, and opacity.
- Position locking and saved settings using the addon data API.
- Lua code to enumerate active quests, show completion state, and request tracking selection.
- Startup diagnostic messages and defensive `pcall` around selected Lua/API operations.

These items describe code currently present, not features confirmed to work in-game. In particular, quest enumeration, quest tracking selection, settings persistence, and the finished visible layout remain unverified.

## Development checklist

### 1. Establish a safe, visible foundation

- [x] Identify and replace the invalid drawable layer value that caused a client crash in isolation testing.
- [x] Restore the full prototype source after the minimal crash-isolation pass.
- [x] Set the prototype to show the tracker at startup for visual testing.
- [ ] Confirm the complete addon reaches the world reliably across repeated launches.
- [ ] Confirm the panel is visible, positioned correctly, and rendered above the game UI.
- [ ] Verify launcher, drag, lock, refresh, settings, and preview controls in-game.
- [ ] Check UI scaling, resolution changes, saved position, and relog behavior.

### 2. Validate quest behavior

- [ ] Verify active quest list indexing and title retrieval against the live ArcheRage client.
- [ ] Verify completion state and selected-quest tracking behavior.
- [ ] Handle quest accept, update, complete, abandon, and turn-in events safely.
- [ ] Test empty lists, long titles, large quest counts, and unexpected API results.
- [ ] Confirm that failures are visible and recoverable without destabilizing the client.

### 3. Build the customizable tracker

- [ ] Add configurable colors, typography, row height, padding, background, border, and opacity per element.
- [ ] Add adaptive height, maximum height, scrolling, and resize controls.
- [ ] Add sorting, filters, categories, pinning, and optional completed-quest display.
- [ ] Add collapsible sections and remember each section’s state.
- [ ] Add per-character profiles and settings import/export.
- [ ] Add localization and accessible interaction options.

### 4. Investigate optional integrations

- [ ] Check whether supported events permit automatic refresh without polling.
- [ ] Determine whether any permitted API supports distance, zone, or waypoint data.
- [ ] Research whether the default tracker can be hidden through a documented, permitted method.
- [ ] If replacement is supported, add an explicit opt-in mode with a reliable way to restore the default tracker.
- [ ] Keep side-by-side mode as the default until replacement behavior is verified.

## Intended experience

The long-term goal is a complete visual and functional replacement for the default tracker, with user control over layout, information density, sorting, filtering, interaction, and persistence. Wayfinder should also support running beside the default tracker so players can compare behavior or keep both visible. Replacement mode is conditional on a supported and permitted ArcheRage method; it is not currently implemented or promised.

Potential later additions include focused quest pinning, context actions, completion notifications, optional sounds, map integration, and addon integration hooks. These are exploratory ideas and depend on available APIs and server rules.

## Safety and compatibility

- This addon targets **ArcheRage**. Compatibility with ArcheAge Classic or other servers is not established.
- WoW addons are inspiration for interaction and customization only; WoW APIs do not imply equivalent ArcheRage capabilities.
- Use only sanctioned ArcheRage addon Lua/UI APIs and verify behavior in the target client.
- API reference files can be incomplete or inaccurate. Treat them as clues and confirm important behavior in-game.
- Lua `pcall` can catch ordinary Lua errors; it cannot make unsafe native UI arguments valid or guarantee recovery from a client crash.

## Installation and testing

There is no public release yet. Development testing uses the local addon folder and source tree configured on the maintainer’s machine. Installation instructions will be published once the file layout and in-game behavior are stable.

For current development tests, enable Wayfinder through the ArcheRage addon manager, load into the world, and check whether the tracker appears near the upper-right. Use **Preview** to inspect sample rows and **Settings** to inspect appearance controls. Use **Refresh** to test quest retrieval. Record whether the game reaches the world and which visible controls respond; a successful addon load alone does not confirm quest functionality.

## Contributing and feedback

Wayfinder is at the concept stage, so feedback about desired tracker behavior, layout, and useful features is welcome. API proposals should include a reference or reproducible in-game observation, since unsupported UI calls can crash the client.

## License

No license has been selected yet. Until one is added, the repository does not grant permission to redistribute or publish modified copies.
