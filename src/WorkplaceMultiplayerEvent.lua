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
WorkplaceMultiplayerEvent.TYPE_DELETE_TRIGGER  = 7   -- server -> all clients

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
    elseif t == WorkplaceMultiplayerEvent.TYPE_DELETE_TRIGGER  then self:handleDeleteTrigger(sys)
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

-- Runs on the SERVER when a dedicated-server client requests trigger creation.
-- In SP/listen-server this is bypassed by sendCreateTrigger() above.
function WorkplaceMultiplayerEvent:handleCreateTrigger(sys, connection)
    if not g_currentMission:getIsServer() then return end

    local stableId = generateStableId()
    wtLog("Server: creating trigger id=" .. stableId
          .. " name='" .. self.workplaceName .. "'")

    -- Register directly on the server (no placeable)
    local triggerData = {
        id            = stableId,
        workplaceName = self.workplaceName,
        hourlyWage    = self.hourlyWage,
        triggerRadius = self.triggerRadius,
        posX          = self.posX,
        posY          = self.posY,
        posZ          = self.posZ,
        paySchedule   = self.paySchedule,
        playerInside  = false,
    }
    local ok, err = pcall(function()
        sys.triggerManager:registerTrigger(triggerData)
    end)
    if not ok then
        wtLog("Server: registerTrigger error (trigger still queued): " .. tostring(err))
    end

    -- Broadcast to all clients so they register the same trigger data
    -- NOTE: broadcast runs even if visual setup failed above
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
    -- Server already registered it inside handleCreateTrigger
    if g_currentMission:getIsServer() then return end

    wtLog("Client: received trigger-created id=" .. tostring(self.triggerId)
          .. " name='" .. self.workplaceName .. "'")

    -- Register directly on this client (no placeable)
    local triggerData = {
        id            = self.triggerId,
        workplaceName = self.workplaceName,
        hourlyWage    = self.hourlyWage,
        triggerRadius = self.triggerRadius,
        posX          = self.posX,
        posY          = self.posY,
        posZ          = self.posZ,
        paySchedule   = self.paySchedule,
        playerInside  = false,
    }
    sys.triggerManager:registerTrigger(triggerData)
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
        -- SP / listen-server: create trigger data directly, no placeable needed
        local sys = g_WorkplaceSystem
        if sys == nil then return end
        local stableId = generateStableId()
        local triggerData = {
            id            = stableId,
            workplaceName = data.workplaceName or "Workplace",
            hourlyWage    = data.hourlyWage    or 500,
            triggerRadius = data.triggerRadius or 4,
            posX          = data.posX          or 0,
            posY          = data.posY          or 0,
            posZ          = data.posZ          or 0,
            paySchedule   = data.paySchedule   or "hourly",
            playerInside  = false,
        }
        local ok2, err2 = pcall(function()
            sys.triggerManager:registerTrigger(triggerData)
        end)
        if not ok2 then
            wtLog("sendCreateTrigger: registerTrigger error: " .. tostring(err2))
        end

        -- Listen-server: broadcast to any connected clients
        if g_server then
            g_server:broadcastEvent(WorkplaceMultiplayerEvent.new(
                WorkplaceMultiplayerEvent.TYPE_TRIGGER_CREATED,
                {
                    triggerId     = stableId,
                    workplaceName = triggerData.workplaceName,
                    hourlyWage    = triggerData.hourlyWage,
                    triggerRadius = triggerData.triggerRadius,
                    paySchedule   = triggerData.paySchedule,
                    posX          = triggerData.posX,
                    posY          = triggerData.posY,
                    posZ          = triggerData.posZ,
                    farmId        = data.farmId or 1,
                }
            ))
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

-- Runs on every machine to deregister a trigger by ID.
-- On a dedicated server, re-broadcasts to all other clients.
function WorkplaceMultiplayerEvent:handleDeleteTrigger(sys)
    if sys.shiftTracker and sys.shiftTracker:isShiftActive() then
        if tostring(sys.shiftTracker.activeTriggerId) == self.triggerId then
            sys.shiftTracker:endShift()
        end
    end
    if sys.triggerManager then
        sys.triggerManager:deregisterTrigger(self.triggerId)
    end
    wtLog("Deleted trigger id=" .. tostring(self.triggerId))

    -- Dedicated server: forward to all clients
    if g_currentMission:getIsServer() and g_server then
        g_server:broadcastEvent(WorkplaceMultiplayerEvent.new(
            WorkplaceMultiplayerEvent.TYPE_DELETE_TRIGGER,
            { triggerId = self.triggerId }
        ))
    end
end

-- Called from WTListDialog:onClickDel — routes through server so all clients sync
function WorkplaceMultiplayerEvent.sendDeleteTrigger(triggerId)
    if g_currentMission == nil then return end
    local sys = g_WorkplaceSystem
    if sys == nil then return end

    if g_currentMission:getIsServer() then
        -- SP / listen-server: deregister locally then broadcast
        if sys.shiftTracker and sys.shiftTracker:isShiftActive() then
            if tostring(sys.shiftTracker.activeTriggerId) == tostring(triggerId) then
                sys.shiftTracker:endShift()
            end
        end
        if sys.triggerManager then
            sys.triggerManager:deregisterTrigger(triggerId)
        end
        if g_server then
            g_server:broadcastEvent(WorkplaceMultiplayerEvent.new(
                WorkplaceMultiplayerEvent.TYPE_DELETE_TRIGGER,
                { triggerId = tostring(triggerId) }
            ))
        end
    else
        -- Dedicated server client: ask server to delete
        g_client:getServerConnection():sendEvent(
            WorkplaceMultiplayerEvent.new(
                WorkplaceMultiplayerEvent.TYPE_DELETE_TRIGGER,
                { triggerId = tostring(triggerId) }
            )
        )
    end
end

print("[WorkplaceTriggers] WorkplaceMultiplayerEvent loaded")
