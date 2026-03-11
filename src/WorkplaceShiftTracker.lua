-- =========================================================
-- WorkplaceShiftTracker.lua
-- Tracks the active shift: start/stop, elapsed game time,
-- and earnings calculation.
-- =========================================================
-- Uses g_currentMission.time (milliseconds since mission start)
-- Never use os.time() - forbidden in FS25 Lua 5.1 sandbox.
-- =========================================================

WorkplaceShiftTracker = {}
WorkplaceShiftTracker_mt = Class(WorkplaceShiftTracker)

-- In-game time multiplier: FS25 default is 1 real second = 1 in-game minute
-- g_currentMission.missionDuration stores the speed factor.
-- We calculate real elapsed ms and convert to in-game hours:
--   inGameHours = (elapsedRealMs * timeScale) / (1000 * 60 * 60)
-- where timeScale is mission time scale (default 1).

local function wtLog(msg)
    print("[WorkplaceTriggers] ShiftTracker: " .. tostring(msg))
end

function WorkplaceShiftTracker.new(system)
    local self = setmetatable({}, WorkplaceShiftTracker_mt)
    self.system = system

    self.activeTriggerId   = nil
    self.activeWorkplaceName = nil
    self.activeHourlyWage  = 0
    self.shiftStartTime    = nil   -- g_currentMission.time at shift start (ms)
    self.shiftElapsedMs    = 0     -- accumulated ms (updated each frame)
    self.totalEarned       = 0     -- lifetime earnings this session

    self.isInitialized = false
    return self
end

function WorkplaceShiftTracker:initialize()
    self.isInitialized = true
    wtLog("Initialized")
end

-- =========================================================
-- Shift Control
-- =========================================================
function WorkplaceShiftTracker:startShift(trigger)
    if trigger == nil then
        wtLog("startShift: nil trigger")
        return
    end

    if self:isShiftActive() then
        wtLog("startShift: shift already active, ending first")
        self:endShift()
    end

    self.activeTriggerId     = trigger.id
    self.activeWorkplaceName = trigger.workplaceName or "Workplace"
    self.activeHourlyWage    = trigger.hourlyWage or 500
    self.shiftStartTime      = self:getCurrentMissionTime()
    self.shiftElapsedMs      = 0

    wtLog(string.format("Shift started at '%s' | $%d/hr", self.activeWorkplaceName, self.activeHourlyWage))

    -- Notify HUD
    if self.system.hud then
        self.system.hud:onShiftStarted(self.activeWorkplaceName, self.activeHourlyWage)
    end
end

function WorkplaceShiftTracker:endShift()
    if not self:isShiftActive() then
        wtLog("endShift: no active shift")
        return
    end

    local earnings = self:getCurrentEarnings()
    local elapsedHours = self:getElapsedHours()

    wtLog(string.format("Shift ended at '%s' | %.2f hrs | $%d earned",
        self.activeWorkplaceName, elapsedHours, earnings))

    -- Pay the farm
    if earnings > 0 then
        self.system.financeIntegration:addMoney(earnings, self.activeWorkplaceName)
    end

    self.totalEarned = self.totalEarned + earnings

    -- Notify HUD
    if self.system.hud then
        self.system.hud:onShiftEnded(self.activeWorkplaceName, earnings)
    end

    -- Reset state
    self.activeTriggerId     = nil
    self.activeWorkplaceName = nil
    self.activeHourlyWage    = 0
    self.shiftStartTime      = nil
    self.shiftElapsedMs      = 0
end

-- =========================================================
-- Update
-- =========================================================
-- Grace period before shift is auto-cancelled when player leaves zone
WorkplaceShiftTracker.WARN_GRACE_SECONDS = 10.0   -- seconds to return before cancel
WorkplaceShiftTracker.WARN_EXTRA_RADIUS  = 8.0    -- metres beyond trigger radius before countdown starts

function WorkplaceShiftTracker:update(dtSec)
    if not self.isInitialized then return end
    if not self:isShiftActive() then return end

    -- Accumulate real elapsed time in ms
    self.shiftElapsedMs = self.shiftElapsedMs + (dtSec * 1000.0)

    -- Zone-leave detection
    self:updateZoneCheck(dtSec)
end

function WorkplaceShiftTracker:updateZoneCheck(dtSec)
    local tm = self.system.triggerManager
    if not tm then return end

    local activeTrigger = tm:getTriggerById(self.activeTriggerId)
    if not activeTrigger then return end

    local playerPos = tm:getPlayerPosition()
    if not playerPos then return end

    local dx   = (activeTrigger.posX or 0) - playerPos.x
    local dz   = (activeTrigger.posZ or 0) - playerPos.z
    local dist = math.sqrt(dx * dx + dz * dz)
    local radius     = activeTrigger.triggerRadius or 4.0
    local warnRadius = radius + self.WARN_EXTRA_RADIUS

    if dist <= radius then
        -- Back inside zone - cancel warning
        if self.leaveWarnActive then
            self.leaveWarnActive = false
            self.leaveWarnTimer  = 0
            if self.system.hud then self.system.hud:hideLeaveWarning() end
        end

    elseif dist <= warnRadius then
        -- In the warning ring - show warning but freeze timer
        if not self.leaveWarnActive then
            self.leaveWarnActive = true
            self.leaveWarnTimer  = 0
        end
        if self.system.hud then
            self.system.hud:showLeaveWarning(self.WARN_GRACE_SECONDS - self.leaveWarnTimer)
        end

    else
        -- Beyond warning radius - countdown to auto-cancel
        if not self.leaveWarnActive then
            self.leaveWarnActive = true
            self.leaveWarnTimer  = 0
        end
        self.leaveWarnTimer = (self.leaveWarnTimer or 0) + dtSec
        if self.system.hud then
            self.system.hud:showLeaveWarning(self.WARN_GRACE_SECONDS - self.leaveWarnTimer)
        end
        if self.leaveWarnTimer >= self.WARN_GRACE_SECONDS then
            wtLog("Player left zone too long - auto-ending shift")
            self.leaveWarnActive = false
            self.leaveWarnTimer  = 0
            if self.system.hud then self.system.hud:hideLeaveWarning() end
            self:endShift()
        end
    end
end

-- =========================================================
-- Queries
-- =========================================================
function WorkplaceShiftTracker:isShiftActive()
    return self.activeTriggerId ~= nil
end

function WorkplaceShiftTracker:getActiveWorkplaceName()
    return self.activeWorkplaceName
end

function WorkplaceShiftTracker:getElapsedHours()
    if not self:isShiftActive() then return 0 end
    -- Convert real ms to in-game hours using the mission time scale
    local timeScale = self:getMissionTimeScale()
    return (self.shiftElapsedMs * timeScale) / (1000.0 * 60.0 * 60.0)
end

function WorkplaceShiftTracker:getElapsedMinutes()
    return self:getElapsedHours() * 60.0
end

-- Returns current shift earnings (wage * in-game hours elapsed)
function WorkplaceShiftTracker:getCurrentEarnings()
    if not self:isShiftActive() then return 0 end
    local hours = self:getElapsedHours()
    return math.floor(self.activeHourlyWage * hours)
end

function WorkplaceShiftTracker:getActiveHourlyWage()
    return self.activeHourlyWage
end

-- =========================================================
-- Utility
-- =========================================================
function WorkplaceShiftTracker:getCurrentMissionTime()
    if g_currentMission and g_currentMission.time then
        return g_currentMission.time
    end
    return 0
end

-- FS25 time scale: g_currentMission.environment.timeScale is the raw multiplier.
-- e.g. 120 means 120 in-game seconds pass per real second.
-- Returns the raw multiplier; getElapsedHours() handles the /3600 conversion.
function WorkplaceShiftTracker:getMissionTimeScale()
    if g_currentMission and g_currentMission.environment
       and g_currentMission.environment.timeScale then
        return g_currentMission.environment.timeScale
    end
    -- Fallback: FS25 default is 120x speed
    return 120.0
end

-- =========================================================
-- Cleanup
-- =========================================================
function WorkplaceShiftTracker:delete()
    if self:isShiftActive() then
        wtLog("delete: ending active shift")
        self:endShift()
    end
    self.isInitialized = false
    wtLog("Deleted")
end
