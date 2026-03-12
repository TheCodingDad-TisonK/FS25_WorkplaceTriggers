-- =========================================================
-- WorkplaceMultiplayerEvent.lua
-- Syncs shift start/end between server and all clients.
-- Pattern: FS25 Event class (VehicleAttachEvent reference)
--
-- FS25 rules:
--   Engine auto-registers via Class(); NO Event.registerEvent()
--   Event.new() takes only the metatable (no typeId arg)
--   emptyNew() required for engine deserialisation
--   readStream must call self:run(connection) at the end
-- =========================================================

WorkplaceMultiplayerEvent = {}
WorkplaceMultiplayerEvent_mt = Class(WorkplaceMultiplayerEvent, Event)

WorkplaceMultiplayerEvent.TYPE_SHIFT_START   = 1
WorkplaceMultiplayerEvent.TYPE_SHIFT_END     = 2
WorkplaceMultiplayerEvent.TYPE_SHIFT_CONFIRM = 3

local LOG = "[WorkplaceTriggers] MPEvent: "
local function wtLog(msg) print(LOG .. tostring(msg)) end

-- =========================================================
-- FS25 constructors
-- =========================================================
function WorkplaceMultiplayerEvent.emptyNew()
    local self = Event.new(WorkplaceMultiplayerEvent_mt)
    return self
end

function WorkplaceMultiplayerEvent.new(eventType, triggerId, workplaceName, earnings)
    local self = WorkplaceMultiplayerEvent.emptyNew()
    self.eventType     = eventType     or WorkplaceMultiplayerEvent.TYPE_SHIFT_START
    self.triggerId     = triggerId     or ""
    self.workplaceName = workplaceName or ""
    self.earnings      = earnings      or 0
    return self
end

-- =========================================================
-- Serialization
-- =========================================================
function WorkplaceMultiplayerEvent:writeStream(streamId, connection)
    streamWriteUInt8(streamId, self.eventType)
    streamWriteString(streamId, self.triggerId or "")
    streamWriteString(streamId, self.workplaceName or "")
    streamWriteInt32(streamId, math.floor(self.earnings or 0))
end

function WorkplaceMultiplayerEvent:readStream(streamId, connection)
    self.eventType     = streamReadUInt8(streamId)
    self.triggerId     = streamReadString(streamId)
    self.workplaceName = streamReadString(streamId)
    self.earnings      = streamReadInt32(streamId)
    self:run(connection)   -- FS25 requirement
end

-- =========================================================
-- Processing
-- =========================================================
function WorkplaceMultiplayerEvent:run(connection)
    local sys = g_WorkplaceSystem
    if sys == nil then wtLog("run: g_WorkplaceSystem nil, ignoring"); return end

    if self.eventType == WorkplaceMultiplayerEvent.TYPE_SHIFT_START then
        self:handleShiftStart(sys, connection)
    elseif self.eventType == WorkplaceMultiplayerEvent.TYPE_SHIFT_END then
        self:handleShiftEnd(sys, connection)
    elseif self.eventType == WorkplaceMultiplayerEvent.TYPE_SHIFT_CONFIRM then
        self:handleShiftConfirm(sys)
    end
end

function WorkplaceMultiplayerEvent:handleShiftStart(sys, connection)
    if g_currentMission:getIsServer() then
        local trigger = sys.triggerManager:getTriggerById(self.triggerId)
        if trigger then
            sys.shiftTracker:startShift(trigger)
            wtLog("Server: started shift at '" .. (trigger.workplaceName or "?") .. "'")
            g_server:broadcastEvent(WorkplaceMultiplayerEvent.new(
                WorkplaceMultiplayerEvent.TYPE_SHIFT_CONFIRM,
                self.triggerId, trigger.workplaceName or "", 0
            ))
        else
            wtLog("Server: shift start rejected - trigger not found: " .. tostring(self.triggerId))
        end
    else
        if sys.hud then sys.hud:onShiftStarted(self.workplaceName, 0) end
    end
end

function WorkplaceMultiplayerEvent:handleShiftEnd(sys, connection)
    if g_currentMission:getIsServer() then
        if sys.shiftTracker:isShiftActive() then
            local earned = sys.shiftTracker:getCurrentEarnings()
            local name   = sys.shiftTracker:getActiveWorkplaceName()
            sys.shiftTracker:endShift()
            wtLog(string.format("Server: ended shift, paid $%d from '%s'", earned, name or "?"))
            g_server:broadcastEvent(WorkplaceMultiplayerEvent.new(
                WorkplaceMultiplayerEvent.TYPE_SHIFT_CONFIRM, "", name or "", earned
            ))
        end
    else
        if sys.hud then sys.hud:onShiftEnded(self.workplaceName, self.earnings) end
    end
end

function WorkplaceMultiplayerEvent:handleShiftConfirm(sys)
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
-- Send helpers
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
            WorkplaceMultiplayerEvent.new(WorkplaceMultiplayerEvent.TYPE_SHIFT_START, triggerId, "", 0)
        )
    end
end

function WorkplaceMultiplayerEvent.sendShiftEnd()
    if g_currentMission == nil then return end
    if g_currentMission:getIsServer() then
        local sys = g_WorkplaceSystem
        if sys and sys.shiftTracker:isShiftActive() then sys.shiftTracker:endShift() end
    else
        g_client:getServerConnection():sendEvent(
            WorkplaceMultiplayerEvent.new(WorkplaceMultiplayerEvent.TYPE_SHIFT_END, "", "", 0)
        )
    end
end

print("[WorkplaceTriggers] WorkplaceMultiplayerEvent loaded")
