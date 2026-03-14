local ADDON_NAME = ...
local pvpInstanceTypes = { pvp = true, arena = true }
local pvpHonorHideFrame = CreateFrame("Frame")

local function isInPvpInstance()
    local _, instanceType = IsInInstance()
    return pvpInstanceTypes[instanceType]
end

local function applyHonorBarHook()
    local original = StatusTrackingBarManager.CanShowBar
    StatusTrackingBarManager.CanShowBar = function(self, bar)
        if bar == StatusTrackingBarInfo.BarsEnum.Honor and isInPvpInstance() then
            return false
        end
        return original(self, bar)
    end
end

local handlers = {
    ADDON_LOADED = function(addonName)
        if addonName ~= ADDON_NAME then return end
        applyHonorBarHook()
        pvpHonorHideFrame:UnregisterEvent("ADDON_LOADED")
    end,
    PLAYER_ENTERING_WORLD = function()
        RunNextFrame(function()
            if StatusTrackingBarManager then
                StatusTrackingBarManager:UpdateBarsShown()
            end
        end)
    end,
}

pvpHonorHideFrame:SetScript("OnEvent", function(_, event, ...)
    if handlers[event] then handlers[event](...) end
end)

for event in pairs(handlers) do
    pvpHonorHideFrame:RegisterEvent(event)
end
