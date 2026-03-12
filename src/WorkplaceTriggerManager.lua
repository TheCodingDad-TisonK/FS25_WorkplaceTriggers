-- =========================================================
-- WorkplaceTriggerManager.lua
-- Owns all placed trigger instances.
-- Handles registration, deregistration, and player proximity.
--
-- MAP ICONS:
--   Drawn via a hook on ingameMap.drawFields (same approach
--   as NPCFavor, AutoDrive, and other community mods).
--   Each trigger owns a WTMapHotspot that renders a coloured
--   icon square + name label directly onto the map each frame.
--   This bypasses the game's hotspot filter system entirely,
--   so no undocumented MapHotspot.CATEGORY_* values are needed.
--
-- FLOATING 3-D MARKER:
--   Shopping-icon i3d from the shared data pool floats above
--   the trigger origin at world level.
-- =========================================================

WorkplaceTriggerManager = {}
WorkplaceTriggerManager_mt = Class(WorkplaceTriggerManager)

WorkplaceTriggerManager.INTERACT_RADIUS = 3.0

local MARKER_I3D_RAW  = "$data/shared/assets/marker/markerIconShopping.i3d"
local MARKER_Y_OFFSET = 0.1

local function wtLog(msg)
    print("[WorkplaceTriggers] TriggerManager: " .. tostring(msg))
end

function WorkplaceTriggerManager.new(system)
    local self = setmetatable({}, WorkplaceTriggerManager_mt)
    self.system           = system
    self.triggers         = {}
    self.isInitialized    = false
    self.mapHookInstalled = false
    return self
end

function WorkplaceTriggerManager:initialize()
    self.isInitialized = true

    if g_messageCenter then
        g_messageCenter:subscribe(
            MessageType.SETTING_CHANGED[GameSettings.SETTING.SHOW_TRIGGER_MARKER],
            self.onTriggerMarkerSettingChanged, self)
    end

    wtLog("Initialized")
end

function WorkplaceTriggerManager:onTriggerMarkerSettingChanged()
    local visible = true
    if g_gameSettings then
        local ok, v = pcall(function()
            return g_gameSettings:getValue(GameSettings.SETTING.SHOW_TRIGGER_MARKER)
        end)
        if ok and v ~= nil then visible = v end
    end
    for _, trigger in ipairs(self.triggers) do
        if trigger._markerRootNode and trigger._markerRootNode ~= 0 then
            setVisibility(trigger._markerRootNode, visible)
        end
        -- Map icon visibility is controlled by the draw hook;
        -- we just hide/show via the trigger's own flag
        if trigger._mapHotspot then
            trigger._mapHotspot._visible = visible
        end
    end
end

-- =========================================================
-- Registration
-- =========================================================
function WorkplaceTriggerManager:registerTrigger(triggerData)
    if triggerData == nil then return end
    table.insert(self.triggers, triggerData)
    wtLog(string.format("Registered trigger '%s' (id=%s)",
        triggerData.workplaceName or "?", tostring(triggerData.id)))

    self:spawnMarkerForTrigger(triggerData)
    self:createMapHotspotForTrigger(triggerData)
end

function WorkplaceTriggerManager:deregisterTrigger(triggerId)
    for i = #self.triggers, 1, -1 do
        if self.triggers[i].id == triggerId then
            self:destroyMarkerForTrigger(self.triggers[i])
            self:destroyMapHotspotForTrigger(self.triggers[i])
            wtLog(string.format("Deregistered trigger id=%s", tostring(triggerId)))
            table.remove(self.triggers, i)
            return
        end
    end
end

-- =========================================================
-- Map Hotspot (draw-hook approach, no addMapHotspot)
-- =========================================================
function WorkplaceTriggerManager:createMapHotspotForTrigger(triggerData)
    if triggerData == nil or triggerData._mapHotspot ~= nil then return end

    local hs = WTMapHotspot.new(
        self.system and self.system.modDirectory or "")
    hs:setWorldPosition(triggerData.posX or 0, triggerData.posZ or 0)
    hs:setName(triggerData.workplaceName or "Workplace")
    hs:setIsActive(false)
    hs._visible = true

    triggerData._mapHotspot = hs
    wtLog(string.format("Map hotspot created for '%s'",
        triggerData.workplaceName or "?"))
end

function WorkplaceTriggerManager:destroyMapHotspotForTrigger(triggerData)
    if triggerData == nil then return end
    local hs = triggerData._mapHotspot
    if hs == nil then return end
    hs:delete()
    triggerData._mapHotspot = nil
end

function WorkplaceTriggerManager:updateMapHotspotName(trigger)
    if trigger and trigger._mapHotspot then
        trigger._mapHotspot:setName(trigger.workplaceName or "Workplace")
    end
end

function WorkplaceTriggerManager:updateHotspotActiveState()
    local activeId = self.system.shiftTracker
        and self.system.shiftTracker.activeTriggerId
    for _, trigger in ipairs(self.triggers) do
        if trigger._mapHotspot then
            trigger._mapHotspot:setIsActive(trigger.id == activeId)
        end
    end
end

-- =========================================================
-- Map draw hook  (installed from main.lua after mission load)
-- Hooks ingameMap.drawFields to draw all trigger icons.
-- =========================================================
function WorkplaceTriggerManager:installMapHook()
    if self.mapHookInstalled then return end

    local ingameMap = g_currentMission
        and g_currentMission.hud
        and g_currentMission.hud.ingameMap

    if not ingameMap then
        wtLog("installMapHook: ingameMap not available")
        return
    end

    local mgr = self

    ingameMap.drawFields = Utils.appendedFunction(
        ingameMap.drawFields,
        function(map)
            if not mgr.isInitialized then return end
            for _, trigger in ipairs(mgr.triggers) do
                if trigger._mapHotspot and trigger._mapHotspot._visible ~= false then
                    pcall(function()
                        trigger._mapHotspot:drawOnMap(map)
                    end)
                end
            end
        end
    )

    self.mapHookInstalled = true
    wtLog("Map draw hook installed ("
        .. tostring(#self.triggers) .. " triggers at hook time)")
end

-- =========================================================
-- Floating 3-D Marker
-- =========================================================
function WorkplaceTriggerManager:spawnMarkerForTrigger(triggerData)
    if triggerData == nil then return end
    if triggerData._markerRootNode and triggerData._markerRootNode ~= 0 then return end

    local rootNode = createTransformGroup("wt_marker_" .. tostring(triggerData.id))
    if rootNode == nil or rootNode == 0 then
        wtLog("spawnMarkerForTrigger: createTransformGroup failed")
        return
    end

    setWorldTranslation(rootNode,
        triggerData.posX or 0,
        (triggerData.posY or 0) + MARKER_Y_OFFSET,
        triggerData.posZ or 0)

    if getRootNode then link(getRootNode(), rootNode) end

    triggerData._markerRootNode = rootNode

    local markerI3D = Utils.getFilename(MARKER_I3D_RAW, "")
    triggerData._markerLoadRequestId = g_i3DManager:loadSharedI3DFileAsync(
        markerI3D, false, false,
        self.onMarkerI3DLoaded, self,
        { triggerData = triggerData })
    triggerData._markerI3DResolved = markerI3D
end

function WorkplaceTriggerManager:onMarkerI3DLoaded(i3dNode, failedReason, args)
    local td = args and args.triggerData
    if td == nil then return end
    td._markerLoadRequestId = nil

    if i3dNode == nil or i3dNode == 0 then
        wtLog(string.format("3-D marker load failed (reason=%s) for '%s'",
            tostring(failedReason), tostring(td.workplaceName)))
        if td._markerRootNode and td._markerRootNode ~= 0 then
            delete(td._markerRootNode)
            td._markerRootNode = nil
        end
        return
    end

    if td._markerRootNode == nil or td._markerRootNode == 0 then
        g_i3DManager:releaseSharedI3DFile(
            td._markerI3DResolved or Utils.getFilename(MARKER_I3D_RAW, ""))
        return
    end

    link(td._markerRootNode, i3dNode)
    setTranslation(i3dNode, 0, 0, 0)
    td._markerI3DNode = i3dNode

    local visible = true
    if g_gameSettings then
        local ok, v = pcall(function()
            return g_gameSettings:getValue(GameSettings.SETTING.SHOW_TRIGGER_MARKER)
        end)
        if ok and v ~= nil then visible = v end
    end
    setVisibility(td._markerRootNode, visible)
    wtLog(string.format("3-D marker loaded for '%s'", tostring(td.workplaceName)))
end

function WorkplaceTriggerManager:destroyMarkerForTrigger(triggerData)
    if triggerData == nil then return end
    triggerData._markerLoadRequestId = nil
    if triggerData._markerRootNode and triggerData._markerRootNode ~= 0 then
        delete(triggerData._markerRootNode)
        triggerData._markerRootNode = nil
        triggerData._markerI3DNode  = nil
        g_i3DManager:releaseSharedI3DFile(
            triggerData._markerI3DResolved or Utils.getFilename(MARKER_I3D_RAW, ""))
    end
end

-- =========================================================
-- Update
-- =========================================================
function WorkplaceTriggerManager:update(dtSec)
    if not self.isInitialized then return end

    local playerPos = self:getPlayerPosition()
    if playerPos == nil then return end
    for _, trigger in ipairs(self.triggers) do
        trigger.playerInside = self:isPlayerInsideTrigger(trigger, playerPos)
    end

    self:updateHotspotActiveState()
end

-- =========================================================
-- Proximity Queries
-- =========================================================
function WorkplaceTriggerManager:getNearestPlayerTrigger()
    local playerPos = self:getPlayerPosition()
    if playerPos == nil then return nil end
    local best, bestDist = nil, math.huge
    for _, trigger in ipairs(self.triggers) do
        if trigger.playerInside then
            local dx = (trigger.posX or 0) - playerPos.x
            local dz = (trigger.posZ or 0) - playerPos.z
            local dist = math.sqrt(dx*dx + dz*dz)
            if dist < bestDist then bestDist = dist; best = trigger end
        end
    end
    return best
end

function WorkplaceTriggerManager:getActiveTrigger()
    if not self.system.shiftTracker then return nil end
    local activeId = self.system.shiftTracker.activeTriggerId
    if not activeId then return nil end
    for _, trigger in ipairs(self.triggers) do
        if trigger.id == activeId then return trigger end
    end
    return nil
end

function WorkplaceTriggerManager:getAllTriggers()   return self.triggers end

function WorkplaceTriggerManager:getTriggerById(id)
    for _, trigger in ipairs(self.triggers) do
        if trigger.id == id then return trigger end
    end
    return nil
end

-- =========================================================
-- Geometry
-- =========================================================
function WorkplaceTriggerManager:isPlayerInsideTrigger(trigger, playerPos)
    if trigger.triggerRadius then
        local dx = (trigger.posX or 0) - playerPos.x
        local dz = (trigger.posZ or 0) - playerPos.z
        return (dx*dx + dz*dz) <= (trigger.triggerRadius * trigger.triggerRadius)
    end
    return trigger.playerInside or false
end

-- =========================================================
-- Player Position (4 fallback methods)
-- =========================================================
function WorkplaceTriggerManager:getPlayerPosition()
    if g_localPlayer and g_localPlayer.getPosition then
        local ok, x, y, z = pcall(function() return g_localPlayer:getPosition() end)
        if ok and x then return {x=x, y=y, z=z} end
    end
    local mp = g_currentMission and g_currentMission.player
    if mp and mp.getPosition then
        local ok, x, y, z = pcall(function() return mp:getPosition() end)
        if ok and x then return {x=x, y=y, z=z} end
    end
    local v = g_currentMission and g_currentMission.controlledVehicle
    if v then
        local ok, x, y, z = pcall(function() return getWorldTranslation(v.rootNode) end)
        if ok and x then return {x=x, y=y, z=z} end
    end
    if getCamera then
        local cam = getCamera()
        if cam and cam ~= 0 then
            local ok, x, y, z = pcall(function() return getWorldTranslation(cam) end)
            if ok and x then return {x=x, y=y, z=z} end
        end
    end
    return nil
end

-- =========================================================
-- Cleanup
-- =========================================================
function WorkplaceTriggerManager:delete()
    if g_messageCenter then
        g_messageCenter:unsubscribeAll(self)
    end
    for _, trigger in ipairs(self.triggers) do
        self:destroyMarkerForTrigger(trigger)
        self:destroyMapHotspotForTrigger(trigger)
    end
    self.triggers         = {}
    self.mapHookInstalled = false
    self.isInitialized    = false
    wtLog("Deleted")
end
