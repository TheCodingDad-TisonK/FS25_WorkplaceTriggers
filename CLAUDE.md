# CLAUDE.md

## Project Overview
FS25_WorkplaceTriggers - Placeable off-farm work triggers for FS25.
Patterns: NPCFavor (HUD, RVB input, GUI, events) + SeasonalCropStress (save/load, placeables, integrations).

## Session Reminders
1. Read this file before writing any code
2. NEVER name i3d root node 'root'
3. addTrigger() second arg MUST be a string
4. No unicode in Lua files (FS25 Lua 5.1 parser rejects it)
5. g_gui:loadGui() arg 3 = class table, not instance
6. Dialog callbacks: NEVER name them onClose or onOpen
7. XML save: use OOP xmlFile:setInt() etc. (not legacy global API)
8. HUD Y=0 at BOTTOM, increases UP
9. Images from ZIP: set via setImageFilename() in Lua, not XML
10. No os.time() - use g_currentMission.time
11. Field/trigger registration: addUpdateable() + isMissionStarted guard pattern
12. No goto, no continue in Lua 5.1

## Architecture
Central coordinator: WorkplaceSystem (global: g_WorkplaceSystem)
Subsystems owned by coordinator: TriggerManager, ShiftTracker, FinanceIntegration, HUD, Input