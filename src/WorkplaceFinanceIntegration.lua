-- =========================================================
-- WorkplaceFinanceIntegration.lua
-- Pays shift earnings into the farm account.
-- =========================================================
-- Pattern: FinanceIntegration.lua from FS25_SeasonalCropStress
-- Uses farm:changeBalance as the canonical path (economyManager:updateFunds
-- always errors in practice); g_currentMission:updateFunds as fallback.
-- =========================================================

WorkplaceFinanceIntegration = {}
WorkplaceFinanceIntegration_mt = Class(WorkplaceFinanceIntegration)

local function wtLog(msg)
    print("[WorkplaceTriggers] Finance: " .. tostring(msg))
end

function WorkplaceFinanceIntegration.new(system)
    local self = setmetatable({}, WorkplaceFinanceIntegration_mt)
    self.system = system
    self.isInitialized = false
    return self
end

function WorkplaceFinanceIntegration:initialize()
    self.isInitialized = true
    wtLog("Initialized")
end

-- =========================================================
-- Add Money
-- Pays the amount into the player's farm account.
-- workplaceName is used for the log message only.
-- =========================================================
function WorkplaceFinanceIntegration:addMoney(amount, workplaceName)
    if not self.isInitialized then return end
    if amount == nil or amount <= 0 then return end

    local amountInt = math.floor(amount)
    local label = workplaceName or "Workplace"

    -- Determine farm ID
    local farmId = self:getPlayerFarmId()

    -- Canonical path: farm:changeBalance (confirmed working in FS25;
    -- economyManager:updateFunds was removed — it always errors in practice)
    if g_farmManager then
        local ok, err = pcall(function()
            local farm = g_farmManager:getFarmById(farmId)
            if farm then
                farm:changeBalance(amountInt)
            end
        end)
        if ok then
            wtLog(string.format("Paid $%d to farmId=%d from '%s' via farm:changeBalance", amountInt, farmId, label))
            return
        else
            wtLog("farm:changeBalance failed: " .. tostring(err))
        end
    end

    -- Fallback: g_currentMission:updateFunds
    if g_currentMission and g_currentMission.updateFunds then
        local ok, err = pcall(function()
            local reasonType = (FundsReasonType ~= nil and FundsReasonType.OTHER) or 0
            g_currentMission:updateFunds(farmId, amountInt, reasonType, true)
        end)
        if ok then
            wtLog(string.format("Paid $%d to farmId=%d from '%s' via updateFunds", amountInt, farmId, label))
            return
        else
            wtLog("updateFunds failed: " .. tostring(err))
        end
    end

    wtLog(string.format("WARNING: Could not pay $%d - no valid payment method found", amountInt))
end

-- =========================================================
-- Utility
-- =========================================================
function WorkplaceFinanceIntegration:getPlayerFarmId()
    -- Try local player's owned farm first
    if g_currentMission and g_currentMission.player then
        local player = g_currentMission.player
        if player.getOwnerFarmId then
            local ok, farmId = pcall(function() return player:getOwnerFarmId() end)
            if ok and farmId and farmId > 0 then
                return farmId
            end
        end
        if player.farmId and player.farmId > 0 then
            return player.farmId
        end
    end

    -- Fallback: farm 1 (first farm, typically the player's in singleplayer)
    return 1
end

-- =========================================================
-- Cleanup
-- =========================================================
function WorkplaceFinanceIntegration:delete()
    self.isInitialized = false
    wtLog("Deleted")
end
