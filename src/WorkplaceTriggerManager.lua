-- =========================================================
-- WorkplaceTriggerManager.lua
-- Owns all placed trigger instances.
-- Handles registration, deregistration, and player proximity.
--
-- MAP DOT:   Drawn via ingameMap.drawFields hook (world->screen
--            coords using map.layout:getMapObjectPosition).
--            PlaceableHotspot.overlay is always nil for standalone
--            hotspots in FS25 - drawing directly is the only
--            reliable approach. Hook is installed from main.lua
--            after loadMission00Finished fires.
--
-- GROUND RING: Bundled flat cylinder mesh in workTrigger.i3d
--              (nodeId=5, groundRing). Scaled at runtime in
--              workTrigger.lua:onLoad() to match triggerRadius.
--              No shared i3d needed.
-- =========================================================

WorkplaceTriggerManager = {}
WorkplaceTriggerManager_mt = Class(WorkplaceTriggerManager)

WorkplaceTriggerManager.INTERACT_RADIUS = 3.0

-- Map dot appearance
WorkplaceTriggerManager.DOT_R          = 0.25   -- green when inactive
WorkplaceTriggerManager.DOT_G          = 0.85
WorkplaceTriggerManager.DOT_B          = 0.30
WorkplaceTriggerManager.DOT_A          = 1.0
WorkplaceTriggerManager.DOT_ACTIVE_R   = 0.25   -- gold when on shift
WorkplaceTriggerManager.DOT_ACTIVE_G   = 0.80
WorkplaceTriggerManager.DOT_ACTIVE_B   = 0.10
WorkplaceTriggerManager.DOT_SIZE       = 0.012  -- dot radius in normalised screen units

local function wtLog(msg)
    print("[WorkplaceTriggers] TriggerManager: " .. tostring(msg))
end

function WorkplaceTriggerManager.new(system)
    local self = setmetatable({}, WorkplaceTriggerManager_mt)
    self.system          = system
    self.triggers        = {}
    self.isInitialized   = false
    self.mapHookInstalled = false
    return self
end

function WorkplaceTriggerManager:initialize()
    self.isInitialized = true

    -- Subscribe to the game setting so markers hide/show when player toggles it
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

    -- Spawn a floating marker i3d at the trigger position (same asset the base game uses)
    self:spawnMarkerForTrigger(triggerData)
end

function WorkplaceTriggerManager:deregisterTrigger(triggerId)
    for i = #self.triggers, 1, -1 do
        if self.triggers[i].id == triggerId then
            -- Clean up the marker node we created
            self:destroyMarkerForTrigger(self.triggers[i])
            wtLog(string.format("Deregistered trigger id=%s", tostring(triggerId)))
            table.remove(self.triggers, i)
            return
        end
    end
end

-- =========================================================
-- Floating Marker Management
-- Loads $data/shared/assets/marker/markerIconUnload.i3d async
-- (the FS25 shared trigger marker used by silos, stations, etc.)
-- and links it to a transform at the trigger world position.
--
-- API used: g_i3DManager:loadSharedI3DFileAsync / releaseSharedI3DFile
-- (replaces the FS22 streamSharedI3DFile global which is gone in FS25)
-- =========================================================
-- Utils.getFilename() must be called at runtime (not load time) to expand $data.
-- The second arg is a baseDirectory; for $data paths the engine ignores it and
-- resolves against its own data root, so an empty string is fine.
local MARKER_I3D_RAW  = "$data/shared/assets/marker/markerIconUnload.i3d"
local MARKER_Y_OFFSET = 0.2   -- metres above trigger origin

function WorkplaceTriggerManager:spawnMarkerForTrigger(triggerData)
    if triggerData == nil then return end
    -- Skip if a marker is already present
    if triggerData._markerRootNode and triggerData._markerRootNode ~= 0 then return end

    -- Create a world-space root transform at the trigger position
    local rootNode = createTransformGroup("wt_marker_" .. tostring(triggerData.id))
    if rootNode == nil or rootNode == 0 then
        wtLog("spawnMarkerForTrigger: createTransformGroup failed")
        return
    end

    local x = triggerData.posX or 0
    local y = (triggerData.posY or 0) + MARKER_Y_OFFSET
    local z = triggerData.posZ or 0
    setWorldTranslation(rootNode, x, y, z)

    if getRootNode then
        link(getRootNode(), rootNode)
    end

    triggerData._markerRootNode = rootNode

    -- Async load via the FS25 i3d manager
    local markerI3D = Utils.getFilename(MARKER_I3D_RAW, "")
    local sharedLoadRequestId = g_i3DManager:loadSharedI3DFileAsync(
        markerI3D,
        false,   -- addPhysics
        false,   -- asyncCallbackFunction (use method below)
        self.onMarkerI3DLoaded,
        self,
        { triggerData = triggerData }
    )
    triggerData._markerLoadRequestId = sharedLoadRequestId
    triggerData._markerI3DResolved   = markerI3D   -- store for release
end

function WorkplaceTriggerManager:onMarkerI3DLoaded(i3dNode, failedReason, args)
    local td = args and args.triggerData
    if td == nil then return end

    td._markerLoadRequestId = nil

    if i3dNode == nil or i3dNode == 0 then
        wtLog(string.format("onMarkerI3DLoaded: load failed (reason=%s) for '%s'",
            tostring(failedReason), tostring(td.workplaceName)))
        return
    end

    -- Trigger may have been deleted while the async load was in flight
    if td._markerRootNode == nil or td._markerRootNode == 0 then
        g_i3DManager:releaseSharedI3DFile(td._markerI3DResolved or Utils.getFilename(MARKER_I3D_RAW, ""))
        return
    end

    link(td._markerRootNode, i3dNode)
    setTranslation(i3dNode, 0, 0, 0)
    td._markerI3DNode = i3dNode

    -- Respect the global SHOW_TRIGGER_MARKER setting
    local visible = true
    if g_gameSettings then
        local ok, v = pcall(function()
            return g_gameSettings:getValue(GameSettings.SETTING.SHOW_TRIGGER_MARKER)
        end)
        if ok and v ~= nil then visible = v end
    end
    setVisibility(td._markerRootNode, visible)

    wtLog(string.format("Marker loaded for '%s'", tostring(td.workplaceName)))
end

function WorkplaceTriggerManager:destroyMarkerForTrigger(triggerData)
    if triggerData == nil then return end
    -- Setting _markerRootNode to nil before the async callback arrives is enough
    -- to make onMarkerI3DLoaded bail out safely.
    triggerData._markerLoadRequestId = nil
    if triggerData._markerRootNode and triggerData._markerRootNode ~= 0 then
        delete(triggerData._markerRootNode)   -- deletes root + all linked children
        triggerData._markerRootNode = nil
        triggerData._markerI3DNode  = nil
        g_i3DManager:releaseSharedI3DFile(triggerData._markerI3DResolved or Utils.getFilename(MARKER_I3D_RAW, ""))
    end
end

-- =========================================================
-- Map dot hook  (called from main.lua after mission load)
-- Hooks ingameMap.drawFields to draw a coloured dot + name
-- label for every registered trigger.
-- =========================================================
function WorkplaceTriggerManager:installMapHook()
    if self.mapHookInstalled then return end
    if not (g_currentMission and g_currentMission.hud
            and g_currentMission.hud.ingameMap) then
        wtLog("ingameMap not available - map dots skipped")
        return
    end

    local mgr = self  -- capture for closure

    g_currentMission.hud.ingameMap.drawFields = Utils.appendedFunction(
        g_currentMission.hud.ingameMap.drawFields,
        function(map)
            mgr:drawMapDots(map)
        end
    )

    self.mapHookInstalled = true
    wtLog("Map draw hook installed")
end

function WorkplaceTriggerManager:drawMapDots(map)
    if not map or not map.layout then return end
    if not self.triggers or #self.triggers == 0 then return end

    local activeId = self.system.shiftTracker
        and self.system.shiftTracker.activeTriggerId

    -- Pre-compute text size once
    local _, textSize = getNormalizedScreenValues(0, 8)
    local _, dotSize  = getNormalizedScreenValues(0, 10)

    for _, trigger in ipairs(self.triggers) do
        pcall(function()
            -- Convert world position to map-normalised coords
            -- Pattern: NPCEntity.lua:drawMapLabels from FS25_NPCFavor
            local nx = (trigger.posX + map.worldCenterOffsetX) / map.worldSizeX
                       * map.mapExtensionScaleFactor + map.mapExtensionOffsetX
            local nz = (trigger.posZ + map.worldCenterOffsetZ) / map.worldSizeZ
                       * map.mapExtensionScaleFactor + map.mapExtensionOffsetZ

            local screenX, screenY, _, visible =
                map.layout:getMapObjectPosition(nx, nz, 0.01, 0.01, 0, false)

            if not visible then return end

            local isActive = (trigger.id == activeId)

            -- Dot colour: gold when on shift, green otherwise
            local r = isActive and WorkplaceTriggerManager.DOT_ACTIVE_R or WorkplaceTriggerManager.DOT_R
            local g = isActive and WorkplaceTriggerManager.DOT_ACTIVE_G or WorkplaceTriggerManager.DOT_G
            local b = isActive and WorkplaceTriggerManager.DOT_ACTIVE_B or WorkplaceTriggerManager.DOT_B

            -- Draw filled dot using renderOverlay on the 1x1 pixel graph texture
            if g_currentMission and g_currentMission.hud then
                local overlay = g_currentMission.hud.moneyIcon
                    or g_currentMission.hud.speedMeterIcon
                if overlay == nil then
                    -- Create a simple overlay if none available as anchor
                    -- renderText at position gives us a "dot" via a Unicode bullet
                    setTextAlignment(RenderText.ALIGN_CENTER)
                    setTextColor(r, g, b, 1.0)
                    setTextBold(true)
                    renderText(screenX, screenY, dotSize, "\xE2\x80\xa2")  -- UTF-8 bullet
                    setTextBold(false)
                    setTextColor(1, 1, 1, 1)
                    setTextAlignment(RenderText.ALIGN_LEFT)
                end
            end

            -- Name label slightly above the dot
            local _, labelOffset = getNormalizedScreenValues(0, 12)
            setTextAlignment(RenderText.ALIGN_CENTER)
            setTextBold(false)
            setTextColor(1, 1, 1, 0.92)
            renderText(screenX, screenY + labelOffset, textSize,
                trigger.workplaceName or "Workplace")
            setTextColor(1, 1, 1, 1)
            setTextAlignment(RenderText.ALIGN_LEFT)
        end)
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
end

-- =========================================================
-- Update hotspot name (called from WTEditDialog on rename)
-- =========================================================
function WorkplaceTriggerManager:updateMapHotspotName(trigger)
    -- Name is read live from trigger.workplaceName in drawMapDots - no extra work needed
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
    end
    self.triggers        = {}
    self.mapHookInstalled = false
    self.isInitialized   = false
    wtLog("Deleted")
end
