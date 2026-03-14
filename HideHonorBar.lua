-- Hide the honor bar inside arenas and battlegrounds because it clutters the interface and provides no immediate combat value

local playerVersusPlayerInstanceTypes = { pvp = true, arena = true }
local honorHideFrame = CreateFrame("Frame")

-- Check if the player is currently inside a valid player versus player instance because the honor bar should remain visible elsewhere

local function isInsidePlayerVersusPlayerInstance()
    local _, instanceType = IsInInstance()

    return playerVersusPlayerInstanceTypes[instanceType]
end

-- Override the default tracking bar manager to force the honor bar hidden because the native UI provides no toggle option

local function applyHonorBarHook()
    local originalVisibilityFunction = StatusTrackingBarManager.CanShowBar

    StatusTrackingBarManager.CanShowBar = function(self, trackingBar)
        if trackingBar == StatusTrackingBarInfo.BarsEnum.Honor and isInsidePlayerVersusPlayerInstance() then
            return false
        end

        return originalVisibilityFunction(self, trackingBar)
    end
end

-- Define modular event handlers to manage the honor bar lifecycle because different events require distinct responses

local frameEventHandlers = {

    -- Apply the hook after the addon fully loads to ensure the status tracking bar manager exists because it is loaded dynamically

    ADDON_LOADED = function(loadedAddonName)
        if loadedAddonName ~= "PvPPlus" then return end

        applyHonorBarHook()
        honorHideFrame:UnregisterEvent("ADDON_LOADED")
    end,

    -- Force the status bars to update when entering the world to apply the hide logic because instance transitions do not trigger automatically

    PLAYER_ENTERING_WORLD = function()
        RunNextFrame(function()
            if StatusTrackingBarManager then
                StatusTrackingBarManager:UpdateBarsShown()
            end
        end)
    end,
}

-- Dispatch registered events to their corresponding handler functions to encapsulate logic because a single monolithic function is hard to read

honorHideFrame:SetScript("OnEvent", function(_, dispatchedEvent, ...)
    if frameEventHandlers[dispatchedEvent] then
        frameEventHandlers[dispatchedEvent](...)
    end
end)

-- Register all defined events automatically to initialize the frame because manual registration is prone to omissions

for definedEvent in pairs(frameEventHandlers) do
    honorHideFrame:RegisterEvent(definedEvent)
end
