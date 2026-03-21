# Architecture

## Overview

FS25_WorkplaceTriggers uses a central coordinator pattern (`WorkplaceSystem`) that owns all subsystems. A single global `g_WorkplaceSystem` is created in `main.lua` and destroyed on mission unload.

```
WorkplaceSystem (g_WorkplaceSystem)
  WorkplaceSettings          -- settings data, load/save per-savegame XML
  WorkplaceTriggerManager    -- owns all placed trigger data, map icons, 3-D markers
  WorkplaceShiftTracker      -- active shift state and earnings calculation
  WorkplaceFinanceIntegration -- deposits earnings into the farm account
  WorkplaceHUD               -- shift panel rendering and edit-mode drag/resize
  WorkplaceGUI               -- Workplace Manager list dialog (WTListDialog)
  WorkplaceInputHandler      -- binds WT_INTERACT / WT_MENU / WT_HUD_EDIT actions
  WorkplaceSaveLoad          -- saves/loads trigger placements to per-savegame XML
  WorkplaceSettingsIntegration -- adds mod settings to the game Settings screen
  NPCFavorIntegration        -- optional FS25_NPCFavor bridge
  WorkerCostsIntegration     -- optional FS25_WorkerCosts bridge
```

## Initialization Order

`main.lua` hooks `Mission00.loadMission00Finished`. After the mission finishes loading, `WorkplaceSystem:onMissionLoaded()` is called which:

1. Calls `WorkplaceSettings:load()` — must run first; all subsystems may read settings at init time
2. Initializes every subsystem in order (`triggerManager`, `shiftTracker`, `financeIntegration`, `hud`, `gui`, `inputHandler`, `saveLoad`, `settingsIntegration`, `npcFavorIntegration`, `workerCostsInteg`)
3. Registers console commands
4. **Server:** calls `loadFromXMLFile()` to restore saved triggers immediately
5. **Client:** arms `syncPending = true`; the `update()` loop fires `REQUEST_SYNC` after a 2-second warm-up delay, retrying every 8 seconds for up to 5 attempts

## Update and Draw

`WorkplaceSystem:update(dt)` is called every game tick with `dt` in milliseconds (FS25 convention). It converts to seconds internally and drives:

- Deferred client sync retry logic
- `triggerManager:update()` — player proximity checks
- `shiftTracker:update()` — zone-leave countdown
- `hud:update()` — panel animation
- `gui:update()` — dialog tick

`WorkplaceSystem:draw()` is called from a draw callback registered in `main.lua` and delegates to `hud:draw()` and `gui:draw()`.

## Source Files

| File | Purpose |
|------|---------|
| `main.lua` | Entry point; creates system, hooks mission/update/draw callbacks |
| `src/WorkplaceSystem.lua` | Central coordinator, console commands |
| `src/WorkplaceTriggerManager.lua` | Trigger registration, map icons, 3-D markers, proximity |
| `src/WorkplaceTrigger.lua` | Per-trigger data object, ActivatableObject interaction prompt |
| `src/WorkplaceShiftTracker.lua` | Active shift state, earnings calc, zone-leave penalty |
| `src/WorkplaceMultiplayerEvent.lua` | All MP event types serialized in one class |
| `src/WorkplaceFinanceIntegration.lua` | Wraps `g_currentMission:addMoney()` |
| `src/WorkplaceHUD.lua` | Shift panel draw, drag/resize edit mode |
| `src/WorkplaceGUI.lua` | Thin wrapper around WTListDialog |
| `src/WTListDialog.lua` | Workplace Manager list screen |
| `src/WTEditDialog.lua` | Add/Edit trigger dialog |
| `src/WTDialogLoader.lua` | Lazy-loads GUI XML; shows list or edit dialog |
| `src/WTMapHotspot.lua` | Per-trigger map icon drawn via ingameMap hook |
| `src/WorkplaceInputHandler.lua` | Registers input actions, calls back to WorkplaceSystem |
| `src/WorkplaceSaveLoad.lua` | Reads/writes trigger XML per savegame |
| `src/WorkplaceSettings.lua` | Settings data class with defaults and XML persistence |
| `src/WorkplaceSettingsIntegration.lua` | Injects settings into the game Settings screen |
| `src/NPCFavorIntegration.lua` | Optional FS25_NPCFavor bridge |
| `src/WorkerCostsIntegration.lua` | Optional FS25_WorkerCosts bridge |
| `placeables/workTrigger/` | Placeable specialization (legacy; triggers now use data-only registration) |
