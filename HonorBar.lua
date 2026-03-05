-- Hide honor bar in PvP instances to reduce UI clutter because the default honor bar overlaps important elements

local ADDON_NAME = ...

local originalCanShowBar

-- Override CanShowBar to suppress honor bar in PvP because it clutters the arena interface

local function hookStatusTrackingBar()
    if not StatusTrackingBarManager then return end
    if originalCanShowBar then return end

    originalCanShowBar = StatusTrackingBarManager.CanShowBar
    StatusTrackingBarManager.CanShowBar = function(self, barIndex)
        if barIndex == StatusTrackingBarInfo.BarsEnum.Honor then
            local _, instanceType = IsInInstance()
            if instanceType == "pvp" or instanceType == "arena" then
                return false
            end
        end
        return originalCanShowBar(self, barIndex)
    end
    StatusTrackingBarManager:UpdateBarsShown()
end

-- Register events to hook honor bar on load and zone changes because the bar manager may initialize late

local eventFrame = CreateFrame("Frame")

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon == ADDON_NAME then
            hookStatusTrackingBar()
        end
    else
        hookStatusTrackingBar()
        C_Timer.After(0.5, function()
            if StatusTrackingBarManager then
                StatusTrackingBarManager:UpdateBarsShown()
            end
        end)
    end
end)
