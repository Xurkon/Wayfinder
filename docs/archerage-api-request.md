# ArcheRage quest and achievement API access request

This note turns Wayfinder's feature needs into a concrete request for the ArcheRage addon developers. It separates APIs already present in the local addon reference from missing capabilities and unverified runtime behavior.

## What the local references show

- The local generated `X2Quest` stub lists `GetActiveQuestListCount`, `GetActiveQuestType`, `GetQuestContextMainTitle`, `GetQuestJournalObjectiveCount`, `GetQuestJournalObjectiveText`, `IsCompleted`, `IsReadyForCompleteQuest`, and `SetTrackingActiveQuest`.
- The older `api_functions.txt` lists only five of those under **Allowed**; the objective methods appear under **Available/not allowed** there. Treat this as a version mismatch and ask the developers to confirm the live allowlist before relying on any method.
- ArcheRage explicitly enabled `X2Quest:GetActiveQuestObjectiveText` for Wayfinder on October 27, 2026, according to the project's recorded server permission update. Do not request it again unless the developers say that permission has changed.
- The same `api_functions.txt` lists the `X2Achievement` category, list, info, trace, and daily-assignment methods below under **Allowed**. Their presence in the reference does not replace checking the current server permission state.
- The observed quest scan returned 497 active-list candidates while the native journal showed 57 quests. The addon needs an authoritative journal-membership source; the active-list candidate array does not establish that a quest is in the player's journal or selected in the HUD.
- The public ArcheRage addon announcement says `api_functions` documents APIs available now and that more APIs can be added at player request. It directs addon authors to the ArcheRage Discord `#Addons` channel. [Announcement](https://na.archerage.to/forums/threads/server-updates-10-29-lua-addons-enabled-and-more.12038/)

## APIs already documented as available

### Quest methods

The newer generated stub lists these; confirm that all eight are currently allowed on the live server:

```text
X2Quest:GetActiveQuestListCount()
X2Quest:GetActiveQuestType(index)
X2Quest:GetQuestContextMainTitle(questType)
X2Quest:GetQuestJournalObjectiveCount(index)
X2Quest:GetQuestJournalObjectiveText(questTypeOrIndex, objectiveIndex)
X2Quest:IsCompleted(questType)
X2Quest:IsReadyForCompleteQuest(questType)
X2Quest:SetTrackingActiveQuest(indexOrQuestType) -- documented parameter semantics are unclear
```

The generated signatures disagree about whether objective count/text take a journal index or quest ID. Ask the developers to document the canonical argument and returned fields. `SetTrackingActiveQuest` is currently documented with uncertain index-versus-ID semantics.

### Achievement and assignment methods

The local `api_functions.txt` marks these as allowed:

```text
X2Achievement:GetAchievementName(type)
X2Achievement:GetCategories(kind)
X2Achievement:GetSubcategoryInfo(subCategory)
X2Achievement:GetCategoryCount(kind, categoryType, subCategoryType, filter)
X2Achievement:GetAchievementTracingList(kind)
X2Achievement:GetAchievementMainList(kind, subCategoryType, filter)
X2Achievement:GetAchievementSubList(mainType, filter)
X2Achievement:GetAchievementInfo(achievementType)
X2Achievement:AddTracingAchievement(kind, achievementType)
X2Achievement:RemoveTracingAchievement(kind, achievementType)
X2Achievement:IsTracingAchievement(kind, achievementType)
X2Achievement:GetTodayAssignmentInfo(todayType, index)
X2Achievement:GetTodayAssignmentInfoForChange(todayType, index)
X2Achievement:GetTodayAssignmentCount(todayType)
X2Achievement:GetTodayAssignmentGoal()
X2Achievement:GetTodayAssignmentStatus()
X2Achievement:IsTodayAssignmentQuest(todayType, questType)
X2Achievement:GetTodayAssignmentResetCount(todayType)
```

The current stub describes achievement records with fields such as `complete`, `current`, `completeNum`, `totalSubCount`, `objective`, `tracing`, `name`, and `desc`; daily assignment records include `questType`, `title`, `status`, `satisfy`, and level/item requirements. These shapes still need live validation. The API type is `X2Achievement` (local type ID 67); Wayfinder must import it before calling these methods.

## Capabilities to request for Wayfinder

Ask for supported behavior and data shapes rather than insisting the server adopt speculative method names.

### Required for a correct quest tracker

1. **Authoritative journal membership.** Provide either an array of quest IDs currently accepted in the character's quest journal, or a per-ID membership query. Specify how it treats quests complete but awaiting turn-in, abandoned quests, hidden quests, and completed history. It must not enumerate every quest definition in the game.
2. **Exact native HUD selection.** Provide the exact quest IDs checked in the native quest notifier, plus separately tracked daily/assignment entries if those use a distinct list. Alternatively provide a per-quest checked-state query. This must distinguish accepted-but-unchecked quests from checked quests.
3. **Native selection updates.** Provide a documented event when a quest is checked/unchecked, accepted, abandoned, completed, or removed from the journal. Existing event names in local types include `ADD_GIVEN_QUEST_INFO`, `ADD_NOTIFY_QUEST_INFO`, `REMOVE_NOTIFY_QUEST_INFO`, `CLEAR_NOTIFY_QUEST_INFO`, `QUEST_NOTIFIER_START`, and `QUEST_CONTEXT_UPDATED`; ask which are actually registered for addons and what their arguments mean.
4. **Objective state.** For each journal quest, expose objective text and structured current/required progress, completion state, and a stable objective index. Clarify whether the existing journal objective calls can supply this data and their correct ID/index arguments.
5. **Quest classification.** Expose stable category/type flags or one structured quest type for main/story, saga, daily, weekly, livelihood, repeatable, hidden, group, and assignment quests. The old inventory marks predicates such as `IsMainQuest`, `IsSagaQuest`, `IsDailyQuest`, `IsTodayQuest`, `IsWeeklyQuest`, `IsHiddenQuest`, `IsLivelihoodQuest`, `IsRepeatableQuest`, `IsGroupQuest`, and `IsSelectiveQuest` as available/not allowed; request only the categories Wayfinder needs or a single structured replacement.

### Needed for richer rows and navigation

6. **Geography and target.** Return the quest's current zone/continent and, where meaningful, the active objective's target name and world/map coordinates. If the client can supply it, include distance and direction to the active target. Clarify how quests with no spatial target should be represented. Do not rely on accept-zone as a substitute for the current objective location.
7. **Quest timing and state details.** If enabled, expose remaining time, ready-to-turn-in state, and a stable status value. Existing candidates in the old inventory include `GetQuestContextLeftTime`, `GetActiveQuestListStatus`, `GetActiveQuestListStatusByType`, and active-list level/status methods; confirm which are supported and safe for addons.
8. **Tracking action semantics.** Document whether `SetTrackingActiveQuest` accepts a current list index or quest type ID, whether it toggles or selects, and how an addon can refresh the native set. Do not add a writer API if the supported product policy is read-only tracking.
9. **Native UI replacement controls.** Confirm addon permission to show/hide `UIC_QUEST_NOTIFIER` and `UIC_QUEST_LIST` via `ADDON:ShowContent`, including any restrictions around restoring visibility. The local UI API reference lists the content controls, so this may need confirmation rather than a new function.

### Achievement tracker coverage

10. **Confirm the current achievement allowlist and returned structures** for the documented `X2Achievement` calls above, across `EAK_ACHIEVEMENT`, `EAK_ARCHERAGE`, `EAK_COLLECTION`, and `EAK_RACIAL_MISSION`.
11. **Expose per-criterion progress if aggregate info is insufficient.** For each achievement criterion, Wayfinder needs its label, current value, required value, and completed state. Confirm whether `GetAchievementInfo` and `GetAchievementSubList` already provide these, or enable one documented detail query.
12. **Achievement update events.** Confirm addon registration and payloads for `ACHIEVEMENT_UPDATE` and `COMPLETE_ACHIEVEMENT`; for assignment rows, also confirm `START_TODAY_ASSIGNMENT`, `UPDATE_TODAY_ASSIGNMENT`, and reset-count events.
13. **Achievement HUD replacement is optional.** If Wayfinder will replace the achievement notifier too, confirm access to its exact component ID and `ShowContent` behavior. Do not request this for quest-only replacement.

## Suggested developer request

> We are building Wayfinder, a customizable ArcheRage quest tracker, with a later achievement/assignment view. Our current `GetActiveQuestListCount` / `GetActiveQuestType` scan reports 497 candidates while the player's native quest journal shows 57, so we need an authoritative way to distinguish actual journal membership from all returned candidates, and to distinguish journal membership from the native HUD's checked/selected set.
>
> Could you confirm the current addon allowlist and enable/document the following capabilities if they are not already permitted?
>
> 1. Enumerate only quest IDs currently in the player's journal (including a documented policy for completed-but-unturned-in quests), or query journal membership for a supplied quest ID.
> 2. Read the exact IDs selected in the native quest notifier, including any separate daily/assignment tracker selection, or query checked state by ID.
> 3. Read each journal quest's objective text, stable objective index, current/required progress, objective completion, quest status, and ready-to-turn-in state; document parameter semantics for the existing objective calls.
> 4. Read quest category/type and current zone/continent; where available, expose active objective target name/coordinates and distance/direction.
> 5. Receive addon events for journal add/remove/update, notifier selection changes, objective progress, quest completion, and achievement/assignment updates, with payload documentation.
> 6. Confirm the existing `X2Achievement` category/list/info/tracing and today-assignment APIs are currently enabled and document whether their info records include criterion-level progress. If not, expose that detail.
> 7. Confirm the permitted native component IDs and `ADDON:ShowContent` behavior for optional replacement of the quest notifier and quest list.
>
> We do not need methods for accepting, abandoning, completing, or resetting quests. Read-only data access is sufficient except for the existing user-initiated native tracking action, whose `SetTrackingActiveQuest` argument semantics need clarification.

## Diagnostic approach

A full blind probe is not the right first step. The server allowlist is authoritative; probing names does not grant access, and stock UI code does not prove addon permission. First ask the developers to confirm the allowed methods and response schemas. Then use a small, read-only in-game diagnostic against those methods only:

1. Record the native journal count and exact displayed/known quest IDs.
2. Compare one accepted-and-checked quest, one accepted-but-unchecked quest, one completed-but-still-listed quest, one absent-but-valid ID, and one daily/assignment quest.
3. For each permitted call, log returned Lua type, relevant keys/values, and errors separately; do not dump unbounded tables or call guessed/forbidden methods.
4. Change one native checkbox and one objective, then record which documented events fire and whether the query results update.
5. For achievements, query a known incomplete achievement, one with partial criterion progress, and one complete achievement; compare `GetAchievementInfo` with the UI and trace state.

This narrow probe determines semantics after permission is confirmed. A presence-only inventory and a broad `pcall` sweep cannot establish that a method is safe, permitted, or semantically correct.
