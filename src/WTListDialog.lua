-- =========================================================
-- WTListDialog.lua
-- MessageDialog subclass - Workplace Trigger list manager.
-- Shows up to 8 triggers per page with Edit and Delete per row.
-- Pattern: NPCListDialog.lua from FS25_NPCFavor
-- =========================================================
-- RULES:
--   - No unicode
--   - Dialog callbacks NEVER named onClose or onOpen
--   - g_gui:loadGui() arg 3 = class table, not instance
-- =========================================================

WTListDialog = {}
local WTListDialog_mt = Class(WTListDialog, MessageDialog)

WTListDialog.MAX_ROWS = 8

function WTListDialog.new(target, custom_mt)
    local self = MessageDialog.new(target, custom_mt or WTListDialog_mt)
    self.system      = nil
    self.scrollOffset = 0
    self.rowTriggerIndex = {}   -- rowNum (1-8) -> trigger list index
    return self
end

function WTListDialog:onCreate()
    local ok, err = pcall(function()
        WTListDialog:superClass().onCreate(self)
    end)
    if not ok then
        print("[WorkplaceTriggers] WTListDialog:onCreate error: " .. tostring(err))
    end
end

function WTListDialog:setSystem(system)
    self.system = system
end

function WTListDialog:onOpen()
    local ok, err = pcall(function()
        WTListDialog:superClass().onOpen(self)
    end)
    if not ok then
        print("[WorkplaceTriggers] WTListDialog:onOpen error: " .. tostring(err))
        return
    end
    self.scrollOffset = 0
    self:refresh()
end

-- =========================================================
-- Refresh display
-- =========================================================
function WTListDialog:refresh()
    local triggers = self:getTriggers()
    local total    = #triggers

    -- Title
    if self.titleText then
        self.titleText:setText(g_i18n:getText("wt_dialog_list_title") or "Workplace Triggers")
    end
    if self.subtitleText then
        local sub
        if total == 1 then
            sub = g_i18n:getText("wt_dialog_list_subtitle_one") or "1 trigger placed"
        else
            sub = string.format(g_i18n:getText("wt_dialog_list_subtitle_many") or "%d triggers placed", total)
        end
        self.subtitleText:setText(sub)
    end

    -- Clear all rows
    for i = 1, self.MAX_ROWS do
        self:clearRow(i)
    end
    self.rowTriggerIndex = {}

    -- Fill visible rows
    local startIdx = self.scrollOffset + 1
    local endIdx   = math.min(total, self.scrollOffset + self.MAX_ROWS)
    local rowNum   = 0

    for i = startIdx, endIdx do
        rowNum = rowNum + 1
        self.rowTriggerIndex[rowNum] = i
        self:fillRow(rowNum, triggers[i])
    end

    -- Empty state message
    if self.statusText then
        if total == 0 then
            self.statusText:setText(g_i18n:getText("wt_dialog_list_empty") or "No triggers placed. Click '+ New Trigger' to add one.")
        else
            local showing = (startIdx == endIdx) and tostring(startIdx)
                or (tostring(startIdx) .. "-" .. tostring(endIdx))
            self.statusText:setText(string.format(g_i18n:getText("wt_dialog_list_showing") or "Showing %s of %d", showing, total))
        end
    end

    -- Scroll button visibility
    local hasUp = (self.scrollOffset > 0)
    local hasDn = (endIdx < total)
    self:setScrollVisible(hasUp, hasDn)
end

function WTListDialog:getTriggers()
    if self.system and self.system.triggerManager then
        return self.system.triggerManager:getAllTriggers()
    end
    return {}
end

-- =========================================================
-- Row rendering
-- =========================================================
function WTListDialog:clearRow(rowNum)
    local p = "r" .. rowNum
    local function hide(id)
        local el = self[id]
        if el then
            if el.setText then el:setText("") end
            el:setVisible(false)
        end
    end
    hide(p .. "bg")
    hide(p .. "name")
    hide(p .. "wage")
    hide(p .. "pos")
    hide(p .. "editbg")
    hide(p .. "edittxt")
    hide(p .. "edit")
    hide(p .. "delbg")
    hide(p .. "deltxt")
    hide(p .. "del")
end

function WTListDialog:fillRow(rowNum, trigger)
    local p = "r" .. rowNum

    local function show(id)
        local el = self[id]
        if el then el:setVisible(true) end
        return el
    end

    show(p .. "bg")

    -- Name (truncate at 24 chars)
    local nameEl = show(p .. "name")
    if nameEl then
        local name = trigger.workplaceName or "Workplace"
        if #name > 24 then name = string.sub(name, 1, 22) .. ".." end
        nameEl:setText(name)
    end

    -- Wage
    local wageEl = show(p .. "wage")
    if wageEl then
        wageEl:setText("$" .. tostring(trigger.hourlyWage or 0) .. "/hr")
    end

    -- Position
    local posEl = show(p .. "pos")
    if posEl then
        posEl:setText(string.format("%.0f, %.0f", trigger.posX or 0, trigger.posZ or 0))
    end

    -- Edit button (3 layers)
    show(p .. "editbg")
    show(p .. "edittxt")
    show(p .. "edit")

    -- Delete button (3 layers)
    show(p .. "delbg")
    show(p .. "deltxt")
    show(p .. "del")
end

function WTListDialog:setScrollVisible(showUp, showDn)
    local function setVis(id, vis)
        local el = self[id]
        if el then el:setVisible(vis) end
    end
    setVis("scrollUpBg",  showUp)
    setVis("scrollUpTxt", showUp)
    setVis("scrollUp",    showUp)
    setVis("scrollDnBg",  showDn)
    setVis("scrollDnTxt", showDn)
    setVis("scrollDn",    showDn)
end

-- =========================================================
-- Row click handlers (generated for rows 1-8)
-- =========================================================
for i = 1, WTListDialog.MAX_ROWS do
    WTListDialog["onClickEdit" .. i] = function(self)
        local idx = self.rowTriggerIndex[i]
        if not idx then return end
        local triggers = self:getTriggers()
        local t = triggers[idx]
        if not t then return end
        self:close()
        if WTDialogLoader then
            WTDialogLoader.showEdit(self.system, t, false)
        end
    end

    WTListDialog["onClickDel" .. i] = function(self)
        local idx = self.rowTriggerIndex[i]
        if not idx then return end
        local triggers = self:getTriggers()
        local t = triggers[idx]
        if not t then return end
        -- End shift if active at this trigger
        if self.system and self.system.shiftTracker then
            local st = self.system.shiftTracker
            if st:isShiftActive() and st.activeTriggerId == t.id then
                st:endShift()
            end
        end
        -- Deregister
        if self.system and self.system.triggerManager then
            self.system.triggerManager:deregisterTrigger(t.id)
        end
        -- Clamp scroll
        local remaining = #self:getTriggers()
        if self.scrollOffset > 0 and self.scrollOffset >= remaining then
            self.scrollOffset = math.max(0, remaining - self.MAX_ROWS)
        end
        self:refresh()
    end
end

-- =========================================================
-- Other button handlers
-- =========================================================
function WTListDialog:onClickNew()
    self:close()
    if WTDialogLoader then
        WTDialogLoader.showEdit(self.system, nil, true)
    end
end

function WTListDialog:onClickScrollUp()
    self.scrollOffset = math.max(0, self.scrollOffset - 1)
    self:refresh()
end

function WTListDialog:onClickScrollDown()
    local total = #self:getTriggers()
    local maxOffset = math.max(0, total - self.MAX_ROWS)
    self.scrollOffset = math.min(maxOffset, self.scrollOffset + 1)
    self:refresh()
end

function WTListDialog:onClickClose()
    self:close()
end

function WTListDialog:wtOnClose()
    WTListDialog:superClass().onClose(self)
end

print("[WorkplaceTriggers] WTListDialog loaded")
