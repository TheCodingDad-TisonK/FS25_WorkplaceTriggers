-- =========================================================
-- WorkplaceMultiplayerEvent.lua
-- Syncs trigger creation and shift start/end between server
-- and all clients.
-- Pattern: FS25 Event class (VehicleAttachEvent reference)
--
-- FS25 rules:
--   Engine auto-registers via Class(); NO Event.registerEvent()
--   Event.new() takes only the metatable (no typeId arg)
--   emptyNew() required for engine deserialisation
--   readStream must call self:run(connection) at the end
--
-- MP trigger-creation flow:
--   1. Client sends TYPE_CREATE_TRIGGER to server
--   2. Server calls g_placeableSystem:loadPlaceable(), generates
--      a stable cross-machine ID and broadcasts
--      TYPE_TRIGGER_CREATED to ALL clients
--   3. Every client (including originator) receives the stable
--      ID and queues the pendingCreate with it, then the
--      placeable replicates normally via the FS25 placeable
--      network layer
-- =========================================================

WorkplaceMultiplayerEvent = {}
WorkplaceMultiplayerEvent_mt = Class(WorkplaceMultiplayerEvent, Event)

WorkplaceMultiplayerEvent.TYPE_SHIFT_START     = 1
WorkplaceMultiplayerEvent.TYPE_SHIFT_END       = 2
WorkplaceMultiplayerEvent.TYPE_SHIFT_CONFIRM   = 3
WorkplaceMultiplayerEvent.TYPE_CREATE_TRIGGER  = 4   -- client -> server
WorkplaceMultiplayerEvent.TYPE_TRIGGER_CREATED = 5   -- server -> all clients
WorkplaceMultiplayerEvent.TYPE_UPDATE_TRIGGER  = 6   -- client -> server (edit existing)

local LOG = "[WorkplaceTriggers] MPEvent: "
local function wtLog(msg) print(LOG .. tostring(msg)) end

-- =========================================================
-- Stable ID counter (server-side only; safe because the server
-- is the sole writer and Lua is single-threaded)
-- =========================================================
WorkplaceMultiplayerEvent._serverIdCounter = 0

local function generateStableId()
    WorkplaceMultiplayerEvent._serverIdCounter =
        WorkplaceMultiplayerEvent._serverIdCounter + 1
    local t = g_currentMission and math.floor(g_currentMission.time) or 0
    return string.format("wt_%d_%d", t,
        WorkplaceMultiplayerEvent._serverIdCounter)
end

-- =========================================================
-- FS25 constructors
-- =========================================================
function WorkplaceMultiplayerEvent.emptyNew()
    local self = Event.new(WorkplaceMultiplayerEvent_mt)
    return self
end

function WorkplaceMultiplayerEvent.new(eventType, data)
    local self = WorkplaceMultiplayerEvent.emptyNew()
    self.eventType     = eventType or WorkplaceMultiplayerEvent.TYPE_SHIFT_START
    -- shift fields
    self.triggerId     = (data and data.triggerId)     or ""
    self.workplaceName = (data and data.workplaceName) or ""
    self.earnings      = (data and data.earnings)      or 0
    -- trigger create/update fields
    self.posX          = (data and data.posX)          or 0
    self.posY          = (data and data.posY)          or 0
    self.posZ          = (data and data.posZ)          or 0
    self.hourlyWage    = (data and data.hourlyWage)    or 500
    self.triggerRadius = (data and data.triggerRadius) or 4
    self.paySchedule   = (data and data.paySchedule)   or "hourly"
    self.farmId        = (data and data.farmId)        or 1
    return self
end

-- =========================================================
-- Serialization
-- =========================================================
function WorkplaceMultiplayerEvent:writeStream(streamId, connection)
    streamWriteUInt8(streamId,  self.eventType)
    streamWriteString(streamId, self.triggerId     or "")
    streamWriteString(streamId, self.workplaceName or "")
    streamWriteInt32(streamId,  math.floor(self.earnings or 0))
    -- trigger create/update fields (written for all types; cheap)
    streamWriteFloat32(streamId, self.posX          or 0)
    streamWriteFloat32(streamId, self.posY          or 0)
    streamWriteFloat32(streamId, self.posZ          or 0)
    streamWriteInt32(streamId,   math.floor(self.hourlyWage    or 500))
    streamWriteFloat32(streamId, self.triggerRadius or 4)
    streamWriteString(streamId,  self.paySchedule   or "hourly")
    streamWriteInt32(streamId,   math.floor(self.farmId or 1))
end

function WorkplaceMultiplayerEvent:readStream(streamId, connection)
    self.eventType     = streamReadUInt8(streamId)
    self.triggerId     = streamReadString(streamId)
    self.workplaceName = streamReadString(streamId)
    self.earnings      = streamReadInt32(streamId)
    self.posX          = streamReadFloat32(streamId)
    self.posY          = streamReadFloat32(streamId)
    self.posZ          = streamReadFloat32(streamId)
    self.hourlyWage    = streamReadInt32(streamId)
    self.triggerRadius = streamReadFloat32(streamId)
    self.paySchedule   = streamReadString(streamId)
    self.farmId        = streamReadInt32(streamId)
    self:run(connection)   -- FS25 requirement
end

-- =========================================================
-- Processing
-- =========================================================
function WorkplaceMultiplayerEvent:run(connection)
    local sys = g_WorkplaceSystem
    if sys == nil then wtLog("run: g_WorkplaceSystem nil, ignoring"); return end

    local t = self.eventType
    if     t == WorkplaceMultiplayerEvent.TYPE_SHIFT_START     then self:handleShiftStart(sys, connection)
    elseif t == WorkplaceMultiplayerEvent.TYPE_SHIFT_END       then self:handleShiftEnd(sys, connection)
    elseif t == WorkplaceMultiplayerEvent.TYPE_SHIFT_CONFIRM   then self:handleShiftConfirm(sys)
    elseif t == WorkplaceMultiplayerEvent.TYPE_CREATE_TRIGGER  then self:handleCreateTrigger(sys, connection)
    elseif t == WorkplaceMultiplayerEvent.TYPE_TRIGGER_CREATED then self:handleTriggerCreated(sys)
    elseif t == WorkplaceMultiplayerEvent.TYPE_UPDATE_TRIGGER  then self:handleUpdateTrigger(sys)
    end
end

-- =========================================================
-- Shift handlers
-- =========================================================
function WorkplaceMultiplayerEvent:handleShiftStart(sys, connection)
    if g_currentMission:getIsServer() then
        local trigger = sys.triggerManager:getTriggerById(self.triggerId)
        if trigger then
            sys.shiftTracker:startShift(trigger)
            wtLog("Server: started shift at '" .. (trigger.workplaceName or "?") .. "'")
            g_server:broadcastEvent(WorkplaceMultiplayerEvent.new(
                WorkplaceMultiplayerEvent.TYPE_SHIFT_CONFIRM,
                { triggerId     = self.triggerId,
                  workplaceName = trigger.workplaceName or "",
                  earnings      = 0 }
            ))
        else
            wtLog("Server: shift start rejected - trigger not found: " .. tostring(self.triggerId))
        end
    end
    -- FIX: client branch removed.
    -- Clients update their HUD only when they receive TYPE_SHIFT_CONFIRM,
    -- never on an inbound TYPE_SHIFT_START. This prevents the HUD showing
    -- a shift that the server then rejects.
end

function WorkplaceMultiplayerEvent:handleShiftEnd(sys, connection)
    if g_currentMission:getIsServer() then
        if sys.shiftTracker:isShiftActive() then
            local earned = sys.shiftTracker:getCurrentEarnings()
            local name   = sys.shiftTracker:getActiveWorkplaceName()
            sys.shiftTracker:endShift()
            wtLog(string.format("Server: ended shift, paid $%d from '%s'", earned, name or "?"))
            g_server:broadcastEvent(WorkplaceMultiplayerEvent.new(
                WorkplaceMultiplayerEvent.TYPE_SHIFT_CONFIRM,
                { triggerId = "", workplaceName = name or "", earnings = earned }
            ))
        end
    end
    -- FIX: no client-side HUD update here either
end

function WorkplaceMultiplayerEvent:handleShiftConfirm(sys)
    -- This is the ONLY place client HUDs update for shift events
    if sys.hud then
        if self.earnings > 0 then
            sys.hud:onShiftEnded(self.workplaceName, self.earnings)
        else
            sys.hud:onShiftStarted(self.workplaceName, 0)
        end
    end
    wtLog("Received shift confirm for '" .. tostring(self.workplaceName) .. "'")
end

-- =========================================================
-- Trigger creation handlers
-- =========================================================

-- Runs on the SERVER when a client requests trigger creation.
function WorkplaceMultiplayerEvent:handleCreateTrigger(sys, connection)
    if not g_currentMission:getIsServer() then return end

    -- Generate a stable ID that will be the same string on every machine
    local stableId = generateStableId()
    wtLog("Server: creating trigger id=" .. stableId
          .. " name='" .. self.workplaceName .. "'")

    -- Queue the pendingCreate on the server with the stable ID, so that
    -- when the placeable's onLoad fires it picks up the right config.
    if sys.saveLoad then
        sys.saveLoad:queuePendingCreate({
            stableId      = stableId,
            workplaceName = self.workplaceName,
            hourlyWage    = self.hourlyWage,
            triggerRadius = self.triggerRadius,
            paySchedule   = self.paySchedule,
            posX          = self.posX,
            posY          = self.posY,
            posZ          = self.posZ,
        })
    end

    -- Only the SERVER places the placeable; FS25 then replicates it to all
    -- connected clients automatically via the placeable network layer.
    local xmlFilename = sys.modDirectory .. "placeables/workTrigger/workTrigger.xml"
    if g_placeableSystem and g_placeableSystem.loadPlaceable then
        g_placeableSystem:loadPlaceable(
            xmlFilename,
            self.posX, self.posY, self.posZ,
            0, 0, 0,
            self.farmId,
            0,      -- price: free
            true,   -- isServer
            true,   -- isClient
            nil
        )
    end

    -- Broadcast the stable ID and full config to ALL clients so they can
    -- queue their pendingCreate before the replicated placeable arrives.
    g_server:broadcastEvent(WorkplaceMultiplayerEvent.new(
        WorkplaceMultiplayerEvent.TYPE_TRIGGER_CREATED,
        {
            triggerId     = stableId,
            workplaceName = self.workplaceName,
            hourlyWage    = self.hourlyWage,
            triggerRadius = self.triggerRadius,
            paySchedule   = self.paySchedule,
            posX          = self.posX,
            posY          = self.posY,
            posZ          = self.posZ,
            farmId        = self.farmId,
        }
    ))
end

-- Runs on every CLIENT after the server acknowledged creation.
function WorkplaceMultiplayerEvent:handleTriggerCreated(sys)
    -- Server already handled this inside handleCreateTrigger
    if g_currentMission:getIsServer() then return end

    wtLog("Client: received trigger-created id=" .. tostring(self.triggerId)
          .. " name='" .. self.workplaceName .. "'")

    -- Queue pendingCreate with the stable ID so that when the replicated
    -- placeable arrives and calls onLoad, it picks up the right name/wage.
    if sys.saveLoad then
        sys.saveLoad:queuePendingCreate({
            stableId      = self.triggerId,
            workplaceName = self.workplaceName,
            hourlyWage    = self.hourlyWage,
            triggerRadius = self.triggerRadius,
            paySchedule   = self.paySchedule,
            posX          = self.posX,
            posY          = self.posY,
            posZ          = self.posZ,
        })
    end

    -- Race-condition guard: if the placeable replicated before this event
    -- arrived, it already registered with default values. Find it by position
    -- and patch it now, then pop the queue entry so it does not accumulate.
    if sys.triggerManager and sys.saveLoad then
        local px, py, pz = self.posX or 0, self.posY or 0, self.posZ or 0
        for _, trigger in ipairs(sys.triggerManager:getAllTriggers()) do
            local dx = (trigger.posX or 0) - px
            local dy = (trigger.posY or 0) - py
            local dz = (trigger.posZ or 0) - pz
            if (dx*dx + dy*dy + dz*dz) < 1.0 then
                trigger.workplaceName = self.workplaceName
                trigger.hourlyWage    = self.hourlyWage
                trigger.triggerRadius = self.triggerRadius
                if trigger.placeableRef then
                    trigger.placeableRef.workplaceName = self.workplaceName
                    trigger.placeableRef.hourlyWage    = self.hourlyWage
                    trigger.placeableRef.triggerRadius = self.triggerRadius
                    local ringNode = trigger.placeableRef._groundRingNode
                    if ringNode and ringNode ~= 0 then
                        local s = self.triggerRadius
                        setScale(ringNode, s, 1.0, s)
                    end
                end
                sys.triggerManager:updateMapHotspotName(trigger)
                sys.saveLoad:popPendingCreate()
                wtLog(string.format("Race-guard: patched trigger at (%.1f,%.1f,%.1f) -> '%s'",
                    px, py, pz, self.workplaceName))
                break
            end
        end
    end
end

-- Runs when any client edits an existing trigger's name/wage/radius.
function WorkplaceMultiplayerEvent:handleUpdateTrigger(sys)
    if g_currentMission:getIsServer() then
        local trigger = sys.triggerManager:getTriggerById(self.triggerId)
        if trigger then
            trigger.workplaceName = self.workplaceName
            trigger.hourlyWage    = self.hourlyWage
            trigger.triggerRadius = self.triggerRadius
            trigger.paySchedule   = self.paySchedule
            if sys.triggerManager then
                sys.triggerManager:updateMapHotspotName(trigger)
            end
            wtLog("Server: updated trigger '" .. self.workplaceName .. "'")
            -- Broadcast authoritative update to all other clients
            g_server:broadcastEvent(WorkplaceMultiplayerEvent.new(
                WorkplaceMultiplayerEvent.TYPE_UPDATE_TRIGGER,
                {
                    triggerId     = self.triggerId,
                    workplaceName = self.workplaceName,
                    hourlyWage    = self.hourlyWage,
                    triggerRadius = self.triggerRadius,
                    paySchedule   = self.paySchedule,
                }
            ))
        else
            wtLog("Server: update rejected - trigger not found: " .. tostring(self.triggerId))
        end
    else
        -- Apply the authoritative update that came from the server
        local trigger = sys.triggerManager:getTriggerById(self.triggerId)
        if trigger then
            trigger.workplaceName = self.workplaceName
            trigger.hourlyWage    = self.hourlyWage
            trigger.triggerRadius = self.triggerRadius
            trigger.paySchedule   = self.paySchedule
            if sys.triggerManager then
                sys.triggerManager:updateMapHotspotName(trigger)
            end
        end
    end
end

-- =========================================================
-- Public send helpers (called from WorkplaceSystem / WTEditDialog)
-- =========================================================
function WorkplaceMultiplayerEvent.sendShiftStart(triggerId)
    if g_currentMission == nil then return end
    if g_currentMission:getIsServer() then
        local sys = g_WorkplaceSystem
        if sys then
            local trigger = sys.triggerManager:getTriggerById(triggerId)
            if trigger then sys.shiftTracker:startShift(trigger) end
        end
    else
        g_client:getServerConnection():sendEvent(
            WorkplaceMultiplayerEvent.new(
                WorkplaceMultiplayerEvent.TYPE_SHIFT_START,
                { triggerId = triggerId })
        )
    end
end

function WorkplaceMultiplayerEvent.sendShiftEnd()
    if g_currentMission == nil then return end
    if g_currentMission:getIsServer() then
        local sys = g_WorkplaceSystem
        if sys and sys.shiftTracker:isShiftActive() then
            sys.shiftTracker:endShift()
        end
    else
        g_client:getServerConnection():sendEvent(
            WorkplaceMultiplayerEvent.new(
                WorkplaceMultiplayerEvent.TYPE_SHIFT_END, {})
        )
    end
end

-- Called from WTEditDialog:onClickSave() for new triggers
function WorkplaceMultiplayerEvent.sendCreateTrigger(data)
    if g_currentMission == nil then return end
    if g_currentMission:getIsServer() then
        -- SP / listen-server host: handle directly (no network round-trip needed)
        local sys = g_WorkplaceSystem
        if sys == nil then return end
        local stableId = generateStableId()
        data.stableId = stableId
        if sys.saveLoad then
            sys.saveLoad:queuePendingCreate(data)
        end
        local xmlFilename = sys.modDirectory .. "placeables/workTrigger/workTrigger.xml"
        if g_placeableSystem and g_placeableSystem.loadPlaceable then
            g_placeableSystem:loadPlaceable(
                xmlFilename,
                data.posX or 0, data.posY or 0, data.posZ or 0,
                0, 0, 0,
                data.farmId or g_currentMission:getFarmId(),
                0, true, true, nil
            )
        end
    else
        g_client:getServerConnection():sendEvent(
            WorkplaceMultiplayerEvent.new(
                WorkplaceMultiplayerEvent.TYPE_CREATE_TRIGGER, data)
        )
    end
end

-- Called from WTEditDialog:onClickSave() when editing an existing trigger
function WorkplaceMultiplayerEvent.sendUpdateTrigger(triggerId, data)
    if g_currentMission == nil then return end
    data.triggerId = triggerId
    if g_currentMission:getIsServer() then
        local sys = g_WorkplaceSystem
        if sys then
            local trigger = sys.triggerManager:getTriggerById(triggerId)
            if trigger then
                trigger.workplaceName = data.workplaceName
                trigger.hourlyWage    = data.hourlyWage
                trigger.triggerRadius = data.triggerRadius
                trigger.paySchedule   = data.paySchedule
                if sys.triggerManager then
                    sys.triggerManager:updateMapHotspotName(trigger)
                end
            end
        end
    else
        g_client:getServerConnection():sendEvent(
            WorkplaceMultiplayerEvent.new(
                WorkplaceMultiplayerEvent.TYPE_UPDATE_TRIGGER, data)
        )
    end
end

print("[WorkplaceTriggers] WorkplaceMultiplayerEvent loaded")
