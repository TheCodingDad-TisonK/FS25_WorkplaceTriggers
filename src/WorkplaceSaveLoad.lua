-- =========================================================
-- WorkplaceSaveLoad.lua
-- Saves/loads all workplace trigger definitions.
-- =========================================================
-- Pattern: SaveLoadHandler.lua from FS25_SeasonalCropStress
-- CRITICAL: Use OOP xmlFile:setInt() etc. NEVER legacy globals.
-- Save layout inside careerSavegame XML:
--   <workplaceTriggers>
--     <triggers>
--       <trigger idx="0" id="wt_1" name="Post Office" hourlyWage="500"
--                posX="100.0" posY="0.0" posZ="200.0"/>
--       ...
--     </triggers>
--   </workplaceTriggers>
-- =========================================================

WorkplaceSaveLoad = {}
WorkplaceSaveLoad_mt = Class(WorkplaceSaveLoad)

local ROOT = "careerSavegame.workplaceTriggers"

local function wtLog(msg)
    print("[WorkplaceTriggers] SaveLoad: " .. tostring(msg))
end

-- Helper: safe OOP XML write (falls back to legacy globals if needed)
local function setInt(xmlFile, key, value)
    if xmlFile.setInt then xmlFile:setInt(key, value)
    else setXMLInt(xmlFile, key, value) end
end

local function setFloat(xmlFile, key, value)
    if xmlFile.setFloat then xmlFile:setFloat(key, value)
    else setXMLFloat(xmlFile, key, value) end
end

local function setBool(xmlFile, key, value)
    if xmlFile.setBool then xmlFile:setBool(key, value)
    else setXMLBool(xmlFile, key, value) end
end

local function setString(xmlFile, key, value)
    if xmlFile.setString then xmlFile:setString(key, value)
    else setXMLString(xmlFile, key, value) end
end

-- Helper: safe OOP XML read
local function getInt(xmlFile, key, default)
    local v
    if xmlFile.getInt then v = xmlFile:getInt(key) else v = getXMLInt(xmlFile, key) end
    return v ~= nil and v or default
end

local function getFloat(xmlFile, key, default)
    local v
    if xmlFile.getFloat then v = xmlFile:getFloat(key) else v = getXMLFloat(xmlFile, key) end
    return v ~= nil and v or default
end

local function getString(xmlFile, key, default)
    local v
    if xmlFile.getString then v = xmlFile:getString(key) else v = getXMLString(xmlFile, key) end
    return v ~= nil and v or default
end

-- =========================================================
-- Constructor
-- =========================================================
function WorkplaceSaveLoad.new(system)
    local self = setmetatable({}, WorkplaceSaveLoad_mt)
    self.system = system
    self.isInitialized = false
    return self
end

function WorkplaceSaveLoad:initialize()
    self.isInitialized = true
    wtLog("Initialized")
end

-- =========================================================
-- SAVE
-- Called from main.lua FSCareerMissionInfo.saveToXMLFile hook.
-- xmlFile is an XMLFile OBJECT (FS25 OOP style).
-- =========================================================
function WorkplaceSaveLoad:saveToXMLFile(missionInfo)
    if not self.isInitialized then return end

    -- Get the xmlFile object from missionInfo (same as NPCFavor)
    local xmlFile = missionInfo and missionInfo.xmlFile
    if xmlFile == nil then
        wtLog("saveToXMLFile: no xmlFile on missionInfo - skipping")
        return
    end

    local triggers = self.system.triggerManager:getAllTriggers()
    local count = 0

    for idx, trigger in ipairs(triggers) do
        local i = idx - 1  -- 0-based index for XML array
        local key = string.format("%s.triggers.trigger(%d)", ROOT, i)
        setString(xmlFile, key .. "#id",          tostring(trigger.id or ""))
        setString(xmlFile, key .. "#name",         trigger.workplaceName or "Workplace")
        setInt(   xmlFile, key .. "#hourlyWage",   trigger.hourlyWage or 500)
        setFloat( xmlFile, key .. "#posX",         trigger.posX or 0)
        setFloat( xmlFile, key .. "#posY",         trigger.posY or 0)
        setFloat( xmlFile, key .. "#posZ",         trigger.posZ or 0)
        setFloat( xmlFile, key .. "#rotY",         trigger.rotY or 0)
        count = count + 1
    end

    -- Save trigger count for clean load iteration
    setInt(xmlFile, ROOT .. ".triggers#count", count)

    -- Save HUD layout
    local hud = self.system.hud
    if hud then
        setFloat(xmlFile, ROOT .. ".hudLayout#posX",      hud.posX)
        setFloat(xmlFile, ROOT .. ".hudLayout#posY",      hud.posY)
        setFloat(xmlFile, ROOT .. ".hudLayout#scale",     hud.scale)
        setFloat(xmlFile, ROOT .. ".hudLayout#widthMult", hud.widthMult)
        wtLog("Saved HUD layout")
    end

    wtLog(string.format("Saved %d triggers", count))

    -- Delegate settings save to WorkplaceSettings (writes its own separate XML)
    if self.system.settings then
        self.system.settings:saveToXMLFile(missionInfo)
    end
end

-- =========================================================
-- LOAD
-- Called from main.lua Mission00.onStartMission hook.
-- Reads saved trigger metadata and pushes it back into the
-- TriggerManager. The placeables themselves are respawned
-- by FS25's own placeable system - we only restore the names
-- and wages which are stored in our XML, not in placeable XML.
-- =========================================================
function WorkplaceSaveLoad:loadFromXMLFile(missionInfo)
    if not self.isInitialized then return end

    local xmlFile = missionInfo and missionInfo.xmlFile
    if xmlFile == nil then
        wtLog("loadFromXMLFile: no xmlFile - fresh game")
        return
    end

    local count = 0
    local i = 0

    while true do
        local key = string.format("%s.triggers.trigger(%d)", ROOT, i)
        local savedId = getString(xmlFile, key .. "#id", nil)
        if savedId == nil or savedId == "" then break end

        local savedName = getString(xmlFile, key .. "#name", "Workplace")
        local savedWage = getInt(   xmlFile, key .. "#hourlyWage", 500)
        local savedPosX = getFloat( xmlFile, key .. "#posX", 0)
        local savedPosY = getFloat( xmlFile, key .. "#posY", 0)
        local savedPosZ = getFloat( xmlFile, key .. "#posZ", 0)

        -- Find the matching trigger in the TriggerManager by id
        -- (placeable was re-created by FS25 before this runs)
        local trigger = self.system.triggerManager:getTriggerById(savedId)
        if trigger then
            trigger.workplaceName = savedName
            trigger.hourlyWage    = savedWage
            wtLog(string.format("Restored trigger '%s' (id=%s) wage=$%d", savedName, savedId, savedWage))
            count = count + 1
        else
            -- Trigger placeable not re-created yet (save/load timing edge case)
            -- Store as pending restore - will be applied by registerTrigger()
            self:storePendingRestore(savedId, savedName, savedWage, savedPosX, savedPosY, savedPosZ)
        end

        i = i + 1
    end

    wtLog(string.format("Loaded %d trigger configs", i))

    -- Load HUD layout
    local hudPosX      = getFloat(xmlFile, ROOT .. ".hudLayout#posX",      nil)
    local hudPosY      = getFloat(xmlFile, ROOT .. ".hudLayout#posY",      nil)
    local hudScale     = getFloat(xmlFile, ROOT .. ".hudLayout#scale",     nil)
    local hudWidthMult = getFloat(xmlFile, ROOT .. ".hudLayout#widthMult", nil)
    if hudPosX and self.system.hud then
        self.system.hud:loadFromSettings({
            hudPosX      = hudPosX,
            hudPosY      = hudPosY,
            hudScale     = hudScale,
            hudWidthMult = hudWidthMult,
        })
        wtLog("Loaded HUD layout")
    end
end

-- =========================================================
-- Immediate HUD Position Save (called on drag/resize release)
-- Writes directly to the career savegame XML if available.
-- =========================================================
function WorkplaceSaveLoad:savePendingHUD()
    local hud = self.system and self.system.hud
    if not hud then return end

    -- Try to write to the active missionInfo xmlFile if available
    local missionInfo = g_currentMission and g_currentMission.missionInfo
    local xmlFile = missionInfo and missionInfo.xmlFile
    if xmlFile then
        setFloat(xmlFile, ROOT .. ".hudLayout#posX",      hud.posX)
        setFloat(xmlFile, ROOT .. ".hudLayout#posY",      hud.posY)
        setFloat(xmlFile, ROOT .. ".hudLayout#scale",     hud.scale)
        setFloat(xmlFile, ROOT .. ".hudLayout#widthMult", hud.widthMult)
        wtLog(string.format("HUD layout quick-saved: pos=%.3f,%.3f scale=%.2f width=%.2f",
            hud.posX, hud.posY, hud.scale, hud.widthMult))
    else
        -- Will be written on next full save - that is fine
        wtLog("HUD layout queued for next full save")
    end
end

-- =========================================================
-- Pending Restore (handles load-before-placeable edge case)
-- =========================================================
function WorkplaceSaveLoad:storePendingRestore(id, name, wage, posX, posY, posZ)
    if self.pendingRestores == nil then
        self.pendingRestores = {}
    end
    self.pendingRestores[id] = {
        workplaceName = name,
        hourlyWage    = wage,
        posX          = posX,
        posY          = posY,
        posZ          = posZ,
    }
    wtLog(string.format("Stored pending restore for trigger id=%s ('%s')", id, name))
end

-- Called by WorkTriggerPlaceable:onLoad after registering, to pick up any pending restore data
function WorkplaceSaveLoad:applyPendingRestore(trigger)
    if self.pendingRestores == nil then return end
    local pending = self.pendingRestores[tostring(trigger.id)]
    if pending then
        trigger.workplaceName = pending.workplaceName
        trigger.hourlyWage    = pending.hourlyWage
        self.pendingRestores[tostring(trigger.id)] = nil
        wtLog(string.format("Applied pending restore to trigger '%s'", trigger.workplaceName))
    end
end

-- =========================================================
-- Cleanup
-- =========================================================
function WorkplaceSaveLoad:delete()
    self.pendingRestores = nil
    self.isInitialized = false
    wtLog("Deleted")
end