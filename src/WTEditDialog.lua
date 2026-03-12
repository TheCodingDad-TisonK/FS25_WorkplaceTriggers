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
        self.titleText:setText(g_i18n:getText(titleKey) or titleFallback)
    end

    -- Populate name input
    if self.nameInput then
        local defaultName = g_i18n:getText("wt_dialog_edit_name_default") or "New Workplace"
        local name = (self.trigger and self.trigger.workplaceName) or defaultName
        self.nameInput:setText(name)
    end

    -- Clear status
    if self.statusText then
        self.statusText:setText("")
    end

    self:updateWageDisplay()
    self:updateRadiusDisplay()
    self:updatePosDisplay()
    self:updateStepDisplay()
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
        self.statusText:setText(g_i18n:getText("wt_dialog_snap_done") or "Position snapped to player location.")
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
        -- Spawn the actual workTrigger placeable so its i3d markerNode exists in
        -- the world and the floating marker is visible.
        -- The placeable's onLoad() will call triggerManager:registerTrigger() itself,
        -- so we do NOT register a separate data record here.
        local xmlFilename = (self.system and self.system.modDirectory or "") .. "placeables/workTrigger/workTrigger.xml"
        local posX = self.posX or 0
        local posY = self.posY or 0
        local posZ = self.posZ or 0

        -- Queue the name/wage so workTrigger.lua:onLoad() can pick them up via
        -- saveLoad:applyPendingRestore() after the placeable registers itself.
        if self.system and self.system.saveLoad then
            self.system.saveLoad:queuePendingCreate({
                workplaceName = name,
                hourlyWage    = self.wage,
                triggerRadius = self.radius,
                posX          = posX,
                posY          = posY,
                posZ          = posZ,
            })
        end

        -- Use PlaceableSystem to load and place the placeable at the chosen position.
        -- Price=0 so the player is never charged; farm=local player's farm.
        local farmId = g_currentMission:getFarmId()
        if g_placeableSystem and g_placeableSystem.loadPlaceable then
            -- FS25 public API: loadPlaceable(xmlFilename, x, y, z, rotX, rotY, rotZ,
            --                                farmId, price, isServer, isClient, callback)
            g_placeableSystem:loadPlaceable(
                xmlFilename,
                posX, posY, posZ,
                0, 0, 0,
                farmId,
                0,        -- price: free
                true,     -- isServer
                true,     -- isClient
                nil       -- no extra callback needed; onLoad handles registration
            )
            print("[WorkplaceTriggers] Spawning placeable for trigger: " .. name)
        else
            -- Fallback: PlaceableSystem API unavailable - fall back to data-only record
            -- (marker will not show, but the trigger zone will still function)
            print("[WorkplaceTriggers] WARNING: g_placeableSystem unavailable - creating data-only trigger (no floating marker)")
            local id = "gui_" .. tostring(g_currentMission and math.floor(g_currentMission.time) or 0)
                       .. "_" .. tostring(WTEditDialog.idCounter or 0)
            WTEditDialog.idCounter = (WTEditDialog.idCounter or 0) + 1
            local t = {
                id            = id,
                workplaceName = name,
                hourlyWage    = self.wage,
                triggerRadius = self.radius,
                posX          = posX,
                posY          = posY,
                posZ          = posZ,
                rotY          = 0,
                playerInside  = false,
                placeableRef  = nil,
                isRuntimeOnly = true,
            }
            if self.system and self.system.triggerManager then
                self.system.triggerManager:registerTrigger(t)
            end
        end
        print("[WorkplaceTriggers] Created trigger: " .. name)
    else
        -- Update existing
        local t = self.trigger
        if t then
            t.workplaceName = name
            t.hourlyWage    = self.wage
            t.triggerRadius = self.radius
            if t.placeableRef then
                local ref = t.placeableRef
                if ref.setWorkplaceName then ref:setWorkplaceName(name) end
                if ref.setHourlyWage    then ref:setHourlyWage(self.wage) end
            end
            -- Sync map hotspot name live
            if self.system and self.system.triggerManager then
                self.system.triggerManager:updateMapHotspotName(t)
            end
        end
        print("[WorkplaceTriggers] Updated trigger: " .. name)
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
