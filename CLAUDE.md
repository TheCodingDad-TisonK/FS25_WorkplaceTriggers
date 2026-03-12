# CLAUDE.md

## Project Overview
FS25_WorkplaceTriggers - Placeable off-farm work triggers for FS25.
Patterns: NPCFavor (HUD, RVB input, GUI, events) + SeasonalCropStress (save/load, placeables, integrations).

## !! MANDATORY: Before Writing ANY FS25 API Code !!
Before implementing any FS25 Lua API call, class usage, or game system interaction,
ALWAYS check the following local reference folders first. These contain CORRECT,
PROVEN API documentation - they are the ground truth. Do NOT rely on training data
for FS25 API specifics; it may be outdated, wrong, or hallucinated.

### Reference Locations
| Reference | Path | Use for |
|-----------|------|---------|
| FS25-Community-LUADOC | `C:\Users\tison\Desktop\FS25 MODS\FS25-Community-LUADOC` | Class APIs, method signatures, function arguments, return values, inheritance chains |
| FS25-lua-scripting | `C:\Users\tison\Desktop\FS25 MODS\FS25-lua-scripting` | Scripting patterns, working examples, proven integration approaches |

### When to Check (mandatory, not optional)
- Any `g_currentMission.*` call
- Any `g_gui.*` / dialog / GUI system usage
- Any hotspot / map icon API (`MapHotspot`, `PlaceableHotspot`, `IngameMap`, etc.)
- Any `addMapHotspot` / `removeMapHotspot` usage
- Any `Class()` / `isa()` / inheritance pattern
- Any `g_i3DManager` / i3d loading
- Any `g_overlayManager` / `Overlay.new` usage
- Any `g_inputBinding` / action event registration
- Any save/load XML API (`xmlFile:setInt`, `xmlFile:getValue`, etc.)
- Any `MessageType` / `g_messageCenter` subscription
- Any placeable specialization or `g_placeableSystem` usage
- Any finance / economy API call
- Any `Utils.*` helper you are not 100% certain about
- Any new FS25 system not previously used in this project

### How to Check
1. Search the LUADOC for the class or function name
2. Read the full method signature including ALL arguments and return values
3. Check inheritance - many FS25 classes require parent constructor calls
4. Look for working examples in FS25-lua-scripting before writing new code
5. If the API is NOT in either reference, state that clearly rather than guessing

### Lessons Learned (real bugs caught in this project)
- `PlaceableHotspot` base class sets `overlayUVs` in its own constructor.
  Inheriting without calling the real constructor → crash in `mouseEvent` (`unpack` on nil).
  FIX: Never inherit from PlaceableHotspot. Use a standalone Class() object.
- `addMapHotspot` filters by `hotspot:getCategory()` against `MapHotspot.CATEGORY_*` integers.
  Returning `0` from getCategory() → silently never drawn. No error, just invisible.
  FIX: Use `ingameMap.drawFields` hook directly (NPCFavor pattern).
- `InGameMenuMapFrame` calls `hotspot:isa()` on every registered hotspot every frame.
  Plain `setmetatable` table has no `isa()` → crash spam every update tick.
  FIX: Always define hotspot classes with `Class()` so `isa()` is injected automatically.
- `g_currentMission:addMapHotspot` vs `g_currentMission.hud.ingameMap:addMapHotspot` -
  these are different call sites with different behaviour. Check LUADOC for the right one.

---

## Session Reminders
1. Read this file before writing any code
2. Check the FS25 MODS reference folders before any API usage (see above)
3. NEVER name i3d root node 'root' - silent load failure
4. `addTrigger()` second arg MUST be a string, not a function
5. No unicode in Lua files (FS25 Lua 5.1 parser rejects it)
6. `g_gui:loadGui()` arg 3 = class table, not instance
7. Dialog callbacks: NEVER name them `onClose` or `onOpen`
8. XML save: use OOP `xmlFile:setInt()` etc. (not legacy global API)
9. HUD Y=0 at BOTTOM, increases UP
10. Images from ZIP: set via `setImageFilename()` in Lua, not XML
11. No `os.time()` - use `g_currentMission.time`
12. Field/trigger registration: `addUpdateable()` + `isMissionStarted` guard pattern
13. No `goto`, no `continue` in Lua 5.1
14. `Class()` gives every instance `isa()` - always use it for objects the game touches
15. Draw hooks (`drawFields`) are more reliable than `addMapHotspot` for custom map icons

## Architecture
Central coordinator: `WorkplaceSystem` (global: `g_WorkplaceSystem`)

| Subsystem | File | Responsibility |
|-----------|------|----------------|
| TriggerManager | WorkplaceTriggerManager.lua | Owns all trigger instances, map icons (drawFields hook), 3D markers |
| ShiftTracker | WorkplaceShiftTracker.lua | Active shift state, elapsed time, earnings calculation |
| FinanceIntegration | WorkplaceFinanceIntegration.lua | Deposits wages into farm account via FS25 finance API |
| HUD | WorkplaceHUD.lua | Shift info panel, edit mode, drag/resize, persistence |
| GUI | WorkplaceGUI.lua | Coordinates WTListDialog and WTEditDialog |
| InputHandler | WorkplaceInputHandler.lua | E-key, F4, Shift key action event registration |
| SaveLoad | WorkplaceSaveLoad.lua | XML persistence for triggers, HUD layout |
| Settings | WorkplaceSettings.lua | Settings values and defaults |
| SettingsIntegration | WorkplaceSettingsIntegration.lua | Hooks into FS25 settings menu UI |
| WTMapHotspot | WTMapHotspot.lua | Per-trigger map icon renderer (drawFields hook, NOT addMapHotspot) |

## Key Design Decisions
- **Map icons**: Use `ingameMap.drawFields` hook + direct `Overlay.new` rendering.
  Do NOT use `g_currentMission:addMapHotspot` - the category filter system requires
  undocumented integer constants and silently skips unknown categories.
- **Hotspot objects**: Defined with `Class()` for `isa()` compatibility even though
  they never get registered through the game's hotspot system.
- **Save format**: All trigger data saved in the career XML via `FSCareerMissionInfo.saveToXMLFile` hook.