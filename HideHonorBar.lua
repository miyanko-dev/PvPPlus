-- Hide the honor bar inside battlegrounds and arenas to reduce interface clutter

local PVP_INSTANCE_TYPES = { pvp = true, arena = true }
local eventFrame = CreateFrame("Frame")

-- Check if the player is currently inside a PvP instance
local function IsInPvPInstance()
    local _, instanceType = IsInInstance()
    return PVP_INSTANCE_TYPES[instanceType]
end

-- Override the tracking bar visibility to suppress the honor bar in PvP instances
local function ApplyHonorBarHook()
    local OriginalCanShowBar = StatusTrackingBarManager.CanShowBar

    StatusTrackingBarManager.CanShowBar = function(self, bar)
        if bar == StatusTrackingBarInfo.BarsEnum.Honor and IsInPvPInstance() then
            return false
        end
        return OriginalCanShowBar(self, bar)
    end
end

-- Event handlers for honor bar lifecycle management
local eventHandlers = {

    -- Apply hook after addon loads to ensure the status tracking bar manager exists
    ADDON_LOADED = function(addonName)
        if addonName ~= "SuperPvP" then return end

        ApplyHonorBarHook()
        eventFrame:UnregisterEvent("ADDON_LOADED")
    end,

    -- Force status bars to update on world entry because instance transitions skip refresh
    PLAYER_ENTERING_WORLD = function()
        RunNextFrame(function()
            if StatusTrackingBarManager then
                StatusTrackingBarManager:UpdateBarsShown()
            end
        end)
    end,
}

-- Dispatch events to their handlers
eventFrame:SetScript("OnEvent", function(_, event, ...)
    if eventHandlers[event] then
        eventHandlers[event](...)
    end
end)

for event in pairs(eventHandlers) do
    eventFrame:RegisterEvent(event)
end
