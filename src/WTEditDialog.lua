-- =========================================================
-- WTEditDialog.lua
-- MessageDialog subclass for creating and editing triggers.
-- Uses TextInput for name, +/- buttons for wage and radius.
-- Pattern: NPCAdminEditDialog.lua from FS25_NPCFavor
-- =========================================================

WTEditDialog = {}
local WTEditDialog_mt = Class(WTEditDialog, MessageDialog)

WTEditDialog.WAGE_STEPS   = {1, 10, 100}
WTEditDialog.WAGE_MIN     = 0
WTEditDialog.WAGE_MAX     = 99999
WTEditDialog.RADIUS_MIN   = 1
WTEditDialog.RADIUS_MAX   = 50
WTEditDialog.RADIUS_STEP  = 1

function WTEditDialog.new(target, custom_mt)
    local self = MessageDialog.new(target, custom_mt or WTEditDialog_mt)
    self.system      = nil
    self.trigger     = nil    -- existing trigger being edited, or nil for new
    self.isNew       = false
    self.wage        = 500
    self.radius      = 4
    self.wageStep    = 10     -- current wage adjustment step
    self.paySchedule = WorkplaceShiftTracker.PAY_HOURLY
    self.posX        = 0
    self.posY        = 0
    self.posZ        = 0
    return self
end

function WTEditDialog:onCreate()
    local ok, err = pcall(function()
        WTEditDialog:superClass().onCreate(self)
    end)
    if not ok then
        print("[WorkplaceTriggers] WTEditDialog:onCreate error: " .. tostring(err))
    end
end

function WTEditDialog:setData(system, trigger, isNew)
    self.system  = system
    self.isNew   = isNew

    if isNew or trigger == nil then
        -- Defaults for new trigger
        self.trigger  = nil
        self.wage     = 500
        self.radius   = 4
        self.wageStep = 10
        self.paySchedule = WorkplaceShiftTracker.PAY_HOURLY
        -- Snap position to player immediately
        self:snapToPlayer()
    else
        self.trigger  = trigger
        self.wage     = trigger.hourlyWage    or 500
        self.radius   = trigger.triggerRadius or 4
        self.posX     = trigger.posX or 0
        self.posY     = trigger.posY or 0
        self.posZ     = trigger.posZ or 0
        self.wageStep = 10
        self.paySchedule = trigger.paySchedule or WorkplaceShiftTracker.PAY_HOURLY
    end
end

function WTEditDialog:snapToPlayer()
    if self.system and self.system.triggerManager then
        local pp = self.system.triggerManager:getPlayerPosition()
        if pp then
            self.posX = pp.x
            self.posY = pp.y
            self.posZ = pp.z
            return
        end
    end
    self.posX = 0
    self.posY = 0
    self.posZ = 0
end

function WTEditDialog:onOpen()
    local ok, err = pcall(function()
        WTEditDialog:superClass().onOpen(self)
    end)
    if not ok then
        print("[WorkplaceTriggers] WTEditDialog:onOpen error: " .. tostring(err))
        return
    end

    -- Set title
    if self.titleText then
        local titleKey = self.isNew and "wt_dialog_edit_title_new" or "wt_dialog_edit_title_edit"
        local titleFallback = self.isNew and "New Workplace Trigger" or "Edit Trigger"
        local titleStr = g_i18n:getText(titleKey)
        self.titleText:setText((titleStr and titleStr ~= "") and titleStr or titleFallback)
    end

    -- Populate name input
    if self.nameInput then
        local defaultName = g_i18n:getText("wt_dialog_edit_name_default")
        defaultName = (defaultName and defaultName ~= "") and defaultName or "New Workplace"
        local name = (self.trigger and self.trigger.workplaceName) or defaultName
        self.nameInput:setText(name)
    end

    -- Clear status
    if self.statusText then
        self.statusText:setText("")
    end

    -- Normalise wageStep in case it was left dirty from a previous open
    if self.wageStep ~= 1 and self.wageStep ~= 10 and self.wageStep ~= 100 then
        self.wageStep = 10
    end

    -- Set schedule button labels from translations (XML has English defaults)
    if self.schedHourlyTxt then self.schedHourlyTxt:setText(g_i18n:getText("wt_sched_hourly") or "Hourly")    end
    if self.schedFlatTxt   then self.schedFlatTxt:setText(g_i18n:getText("wt_sched_flat")     or "Flat Rate") end
    if self.schedDailyTxt  then self.schedDailyTxt:setText(g_i18n:getText("wt_sched_daily")   or "Daily")     end

    self:updateWageDisplay()
    self:updateRadiusDisplay()
    self:updatePosDisplay()
    self:updateStepDisplay()
    self:updateSchedDisplay()
end

-- =========================================================
-- Display helpers
-- =========================================================
function WTEditDialog:updateWageDisplay()
    if self.wageText then
        self.wageText:setText("$" .. tostring(self.wage) .. "/hr")
    end
end

function WTEditDialog:updateRadiusDisplay()
    if self.radText then
        self.radText:setText(tostring(self.radius) .. " m")
    end
end

function WTEditDialog:updatePosDisplay()
    if self.posText then
        self.posText:setText(string.format("Position: X=%.1f  Z=%.1f", self.posX, self.posZ))
    end
end

function WTEditDialog:updateStepDisplay()
    -- Highlight the active step button
    local stepIds = {1, 10, 100}
    for _, s in ipairs(stepIds) do
        local bg = self["step" .. s .. "bg"]
        if bg then
            if s == self.wageStep then
                bg:setImageColor(0.18, 0.30, 0.55, 1)
            else
                bg:setImageColor(0.10, 0.15, 0.28, 0.9)
            end
        end
        local txt = self["step" .. s .. "txt"]
        if txt then
            if s == self.wageStep then
                txt:setTextColor(1, 1, 1, 1)
            else
                txt:setTextColor(0.65, 0.75, 0.9, 1)
            end
        end
    end
end

-- =========================================================
-- Pay schedule display + click handlers
-- =========================================================
local function getSchedHint(sched)
    if sched == WorkplaceShiftTracker.PAY_FLAT then
        return g_i18n:getText("wt_sched_hint_flat")   or "Fixed payout at end of shift"
    elseif sched == WorkplaceShiftTracker.PAY_DAILY then
        return g_i18n:getText("wt_sched_hint_daily")  or "Earns wage x in-game days worked"
    end
    return g_i18n:getText("wt_sched_hint_hourly") or "Earns wage x hours worked"
end

local SCHED_IDS = {
    WorkplaceShiftTracker.PAY_HOURLY,
    WorkplaceShiftTracker.PAY_FLAT,
    WorkplaceShiftTracker.PAY_DAILY,
}

local SCHED_KEYS = {
    [WorkplaceShiftTracker.PAY_HOURLY] = "sched",
    [WorkplaceShiftTracker.PAY_FLAT]   = "schedFlat",
    [WorkplaceShiftTracker.PAY_DAILY]  = "schedDaily",
}

function WTEditDialog:updateSchedDisplay()
    local active = self.paySchedule or WorkplaceShiftTracker.PAY_HOURLY

    local schedBgIds = {
        [WorkplaceShiftTracker.PAY_HOURLY] = "schedHourlyBg",
        [WorkplaceShiftTracker.PAY_FLAT]   = "schedFlatBg",
        [WorkplaceShiftTracker.PAY_DAILY]  = "schedDailyBg",
    }
    local schedTxtIds = {
        [WorkplaceShiftTracker.PAY_HOURLY] = "schedHourlyTxt",
        [WorkplaceShiftTracker.PAY_FLAT]   = "schedFlatTxt",
        [WorkplaceShiftTracker.PAY_DAILY]  = "schedDailyTxt",
    }

    for _, s in ipairs(SCHED_IDS) do
        local bg  = self[schedBgIds[s]]
        local txt = self[schedTxtIds[s]]
        if bg then
            if s == active then
                bg:setImageColor(0.18, 0.30, 0.55, 1)
            else
                bg:setImageColor(0.10, 0.14, 0.28, 0.9)
            end
        end
        if txt then
            if s == active then
                txt:setTextColor(1, 1, 1, 1)
            else
                txt:setTextColor(0.65, 0.75, 0.9, 1)
            end
        end
    end

    -- Update wage label to reflect schedule
    if self.wageLabel then
        local labels = {
            [WorkplaceShiftTracker.PAY_HOURLY] = g_i18n:getText("wt_wage_label_hourly") or "Hourly Wage",
            [WorkplaceShiftTracker.PAY_FLAT]   = g_i18n:getText("wt_wage_label_flat")   or "Flat Rate (per shift)",
            [WorkplaceShiftTracker.PAY_DAILY]  = g_i18n:getText("wt_wage_label_daily")  or "Daily Rate",
        }
        self.wageLabel:setText(labels[active] or g_i18n:getText("wt_wage_label_hourly") or "Hourly Wage")
    end

    if self.schedHintText then
        self.schedHintText:setText(getSchedHint(active))
    end
end

function WTEditDialog:onClickSchedHourly()
    self.paySchedule = WorkplaceShiftTracker.PAY_HOURLY
    self:updateSchedDisplay()
    self:updateWageDisplay()
end

function WTEditDialog:onClickSchedFlat()
    self.paySchedule = WorkplaceShiftTracker.PAY_FLAT
    self:updateSchedDisplay()
    self:updateWageDisplay()
end

function WTEditDialog:onClickSchedDaily()
    self.paySchedule = WorkplaceShiftTracker.PAY_DAILY
    self:updateSchedDisplay()
    self:updateWageDisplay()
end

-- =========================================================
-- Wage adjustment
-- =========================================================
function WTEditDialog:onClickWageDec()
    self.wage = math.max(self.WAGE_MIN, self.wage - self.wageStep)
    self:updateWageDisplay()
end

function WTEditDialog:onClickWageInc()
    self.wage = math.min(self.WAGE_MAX, self.wage + self.wageStep)
    self:updateWageDisplay()
end

function WTEditDialog:onClickStep1()
    self.wageStep = 1
    self:updateStepDisplay()
end

function WTEditDialog:onClickStep10()
    self.wageStep = 10
    self:updateStepDisplay()
end

function WTEditDialog:onClickStep100()
    self.wageStep = 100
    self:updateStepDisplay()
end

-- =========================================================
-- Radius adjustment
-- =========================================================
function WTEditDialog:onClickRadDec()
    self.radius = math.max(self.RADIUS_MIN, self.radius - self.RADIUS_STEP)
    self:updateRadiusDisplay()
end

function WTEditDialog:onClickRadInc()
    self.radius = math.min(self.RADIUS_MAX, self.radius + self.RADIUS_STEP)
    self:updateRadiusDisplay()
end

-- =========================================================
-- Snap position
-- =========================================================
function WTEditDialog:onClickSnap()
    self:snapToPlayer()
    self:updatePosDisplay()
    if self.statusText then
        local snapMsg = g_i18n:getText("wt_dialog_snap_done")
        self.statusText:setText((snapMsg and snapMsg ~= "") and snapMsg or "Position snapped to player location.")
    end
end

-- =========================================================
-- Save
-- =========================================================
function WTEditDialog:onClickSave()
    local name = ""
    if self.nameInput then
        name = self.nameInput:getText() or ""
    end
    name = name:match("^%s*(.-)%s*$")  -- trim whitespace
    if name == "" then name = "Workplace" end

    if self.isNew then
        local farmId = g_currentMission and g_currentMission:getFarmId() or 1
        local ok, err = pcall(function()
            WorkplaceMultiplayerEvent.sendCreateTrigger({
                workplaceName = name,
                hourlyWage    = self.wage,
                triggerRadius = self.radius,
                paySchedule   = self.paySchedule,
                posX          = self.posX or 0,
                posY          = self.posY or 0,
                posZ          = self.posZ or 0,
                farmId        = farmId,
            })
        end)
        if not ok then
            print("[WorkplaceTriggers] onClickSave ERROR: " .. tostring(err))
        end
        print("[WorkplaceTriggers] Requested trigger creation: " .. name)
    else
        -- FIX: route edits through the MP event layer as well, so every client
        -- sees the updated name/wage/radius without a rejoin.
        local t = self.trigger
        if t then
            WorkplaceMultiplayerEvent.sendUpdateTrigger(tostring(t.id), {
                workplaceName = name,
                hourlyWage    = self.wage,
                triggerRadius = self.radius,
                paySchedule   = self.paySchedule,
            })
        end
        print("[WorkplaceTriggers] Requested trigger update: " .. name)
    end

    self:close()
    -- Reopen list
    if WTDialogLoader then
        WTDialogLoader.showList(self.system)
    end
end

-- =========================================================
-- Cancel
-- =========================================================
function WTEditDialog:onClickCancel()
    self:close()
    if WTDialogLoader then
        WTDialogLoader.showList(self.system)
    end
end

function WTEditDialog:wtOnClose()
    WTEditDialog:superClass().onClose(self)
end

print("[WorkplaceTriggers] WTEditDialog loaded")
