-- Hide honor bar in PvP instances to reduce UI clutter

local ADDON_NAME = ...

-- Check whether the player is currently inside a battleground or arena
local function isInPvpInstance()
    local _, instanceType = IsInInstance()
    return instanceType == "pvp" or instanceType == "arena"
end

-- Override CanShowBar once to suppress the honor bar while in PvP instances
local function applyHonorBarHook()
    local original = StatusTrackingBarManager.CanShowBar

    StatusTrackingBarManager.CanShowBar = function(self, barIndex)
        if barIndex == StatusTrackingBarInfo.BarsEnum.Honor and isInPvpInstance() then
            return false
        end
        return original(self, barIndex)
    end
end

-- Trigger the bar manager to re-evaluate which bars should be visible
local function refreshBars()
    if StatusTrackingBarManager then
        StatusTrackingBarManager:UpdateBarsShown()
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        -- Apply the hook once when this addon loads, then stop listening
        if ... == ADDON_NAME then
            applyHonorBarHook()
            eventFrame:UnregisterEvent("ADDON_LOADED")
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Refresh on every zone transition so the bar appears or hides correctly
        C_Timer.After(0.1, refreshBars)
    end
end)
