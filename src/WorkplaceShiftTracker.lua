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

-- Pay schedule types
WorkplaceShiftTracker.PAY_HOURLY = "hourly"   -- wage * in-game hours elapsed
WorkplaceShiftTracker.PAY_FLAT   = "flat"     -- fixed amount paid at end of shift
WorkplaceShiftTracker.PAY_DAILY  = "daily"    -- wage paid once per in-game day worked

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
    self.activePaySchedule = WorkplaceShiftTracker.PAY_HOURLY
    self.shiftStartTime    = nil   -- g_currentMission.time at shift start (ms)
    self.shiftElapsedMs    = 0     -- accumulated ms (updated each frame)
    self.totalEarned       = 0     -- lifetime earnings this session

    -- Shift history log (capped at 50 entries)
    self.shiftHistory      = {}
    self.MAX_HISTORY       = 50

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
    self.activePaySchedule   = trigger.paySchedule or WorkplaceShiftTracker.PAY_HOURLY
    self.shiftStartTime      = self:getCurrentMissionTime()
    self.shiftElapsedMs      = 0

    wtLog(string.format("Shift started at '%s' | $%d/hr", self.activeWorkplaceName, self.activeHourlyWage))

    -- Notify HUD (client-only: dedicated server has no g_i18n / rendering context)
    if self.system.hud and g_currentMission and g_currentMission:getIsClient() then
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

    -- Record in history
    self:recordHistory(self.activeWorkplaceName, elapsedHours, earnings, self.activePaySchedule)

    -- Pay the farm
    if earnings > 0 then
        self.system.financeIntegration:addMoney(earnings, self.activeWorkplaceName)
    end

    self.totalEarned = self.totalEarned + earnings

    -- Notify HUD (client-only: dedicated server has no g_i18n / rendering context)
    if self.system.hud and g_currentMission and g_currentMission:getIsClient() then
        self.system.hud:onShiftEnded(self.activeWorkplaceName, earnings)
    end

    -- Notify integrations
    local activeTrigger = self.system.triggerManager
        and self.system.triggerManager:getTriggerById(self.activeTriggerId)
    if self.system.npcFavorIntegration then
        self.system.npcFavorIntegration:onShiftCompleted(activeTrigger, elapsedHours)
    end
    if self.system.workerCostsInteg then
        self.system.workerCostsInteg:onShiftCompleted(activeTrigger, earnings)
    end

    -- Reset state
    self.activeTriggerId     = nil
    self.activeWorkplaceName = nil
    self.activeHourlyWage    = 0
    self.activePaySchedule   = WorkplaceShiftTracker.PAY_HOURLY
    self.shiftStartTime      = nil
    self.shiftElapsedMs      = 0
end

-- =========================================================
-- Penalty End (player abandoned zone during countdown)
-- Pays 20% of what would have been earned and notifies player
-- =========================================================
WorkplaceShiftTracker.ABANDON_PAY_FRACTION = 0.20  -- 20% payout on abandon

function WorkplaceShiftTracker:endShiftPenalty()
    if not self:isShiftActive() then
        wtLog("endShiftPenalty: no active shift")
        return
    end

    local fullEarnings = self:getCurrentEarnings()
    local penaltyPay   = math.floor(fullEarnings * self.ABANDON_PAY_FRACTION)
    local elapsedHours = self:getElapsedHours()

    wtLog(string.format(
        "Shift ABANDONED at '%s' | %.2f hrs | full=$%d | penalty pay=$%d (20%%)",
        self.activeWorkplaceName, elapsedHours, fullEarnings, penaltyPay))

    -- Record in history with the reduced amount
    self:recordHistory(self.activeWorkplaceName, elapsedHours, penaltyPay, self.activePaySchedule)

    -- Pay only the penalty fraction
    if penaltyPay > 0 then
        self.system.financeIntegration:addMoney(penaltyPay, self.activeWorkplaceName)
    end

    self.totalEarned = self.totalEarned + penaltyPay

    -- Notify HUD with the penalty message (client-only)
    if self.system.hud and g_currentMission and g_currentMission:getIsClient() then
        self.system.hud:onShiftAbandonedPenalty(self.activeWorkplaceName, penaltyPay, fullEarnings)
    end

    -- Notify integrations (pass reduced earnings)
    local activeTrigger = self.system.triggerManager
        and self.system.triggerManager:getTriggerById(self.activeTriggerId)
    if self.system.npcFavorIntegration then
        self.system.npcFavorIntegration:onShiftCompleted(activeTrigger, elapsedHours)
    end
    if self.system.workerCostsInteg then
        self.system.workerCostsInteg:onShiftCompleted(activeTrigger, penaltyPay)
    end

    -- Reset state
    self.activeTriggerId     = nil
    self.activeWorkplaceName = nil
    self.activeHourlyWage    = 0
    self.activePaySchedule   = WorkplaceShiftTracker.PAY_HOURLY
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
    -- On a headless dedicated server there is no local player, so getPlayerPosition()
    -- returns nil and the distance check would always report "out of zone".
    -- Zone tracking runs on the client machine instead (see handleShiftConfirm sync).
    if not g_currentMission:getIsClient() then return end

    -- Respect the endShiftOnLeave setting
    local settings = self.system and self.system.settings
    if settings and settings.endShiftOnLeave == false then
        if self.leaveWarnActive then
            self.leaveWarnActive = false
            self.leaveWarnTimer  = 0
            if self.system.hud then self.system.hud:hideLeaveWarning() end
        end
        return
    end

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
            wtLog("Player left zone too long - auto-ending shift with penalty")
            self.leaveWarnActive = false
            self.leaveWarnTimer  = 0
            if self.system.hud then self.system.hud:hideLeaveWarning() end
            -- Clear activeTriggerId immediately so zone check stops while the
            -- penalty event travels to the server and SHIFT_CONFIRM comes back.
            self.activeTriggerId = nil
            WorkplaceMultiplayerEvent.sendShiftEnd(true)
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

-- Returns current shift earnings based on pay schedule
function WorkplaceShiftTracker:getCurrentEarnings()
    if not self:isShiftActive() then return 0 end
    local mult  = (self.system and self.system.settings and self.system.settings.wageMultiplier) or 1.0
    local sched = self.activePaySchedule or WorkplaceShiftTracker.PAY_HOURLY

    if sched == WorkplaceShiftTracker.PAY_FLAT then
        -- Flat rate: the wage IS the payout, paid in full at end of shift
        return math.floor(self.activeHourlyWage * mult)

    elseif sched == WorkplaceShiftTracker.PAY_DAILY then
        -- Daily rate: wage per in-game day (24 in-game hours)
        local hours = self:getElapsedHours()
        local days  = hours / 24.0
        return math.floor(self.activeHourlyWage * days * mult)

    else
        -- Hourly (default)
        local hours = self:getElapsedHours()
        return math.floor(self.activeHourlyWage * hours * mult)
    end
end

-- =========================================================
-- Shift History
-- =========================================================
function WorkplaceShiftTracker:recordHistory(name, hours, earned, schedule)
    local entry = {
        workplaceName = name or "Workplace",
        elapsedHours  = hours or 0,
        earned        = earned or 0,
        paySchedule   = schedule or WorkplaceShiftTracker.PAY_HOURLY,
        gameDay       = (g_currentMission and g_currentMission.environment
                         and g_currentMission.environment.currentDay) or 0,
    }
    table.insert(self.shiftHistory, 1, entry)   -- newest first
    if #self.shiftHistory > self.MAX_HISTORY then
        table.remove(self.shiftHistory)
    end
end

function WorkplaceShiftTracker:getHistory()
    return self.shiftHistory
end

function WorkplaceShiftTracker:clearHistory()
    self.shiftHistory = {}
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
