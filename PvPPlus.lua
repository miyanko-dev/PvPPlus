-- Hide honor bar and auto release spirit to improve PvP quality of life because default UI is cluttered

local ADDON_NAME = ...

-- Override CanShowBar to hide honor bar in PvP because it clutters the arena interface

local originalCanShowBar
local function HookStatusTrackingBar()
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

-- Click release button automatically to skip manual release because it delays respawning

local function TryAutoRelease(attempt)
    attempt = attempt or 1
    if attempt > 20 then return end

    -- Skip release attempt to avoid errors because a blocking aura or encounter is active

    if HasNoReleaseAura() then
        C_Timer.After(0.5, function() TryAutoRelease(attempt + 1) end)
        return
    end
    if C_InstanceEncounter and C_InstanceEncounter.IsEncounterSuppressingRelease and C_InstanceEncounter.IsEncounterSuppressingRelease() then
        C_Timer.After(0.5, function() TryAutoRelease(attempt + 1) end)
        return
    end

    -- Find and click release button to release spirit because the death popup is visible

    local popup = StaticPopup_Visible("DEATH")
    if popup then
        local button = _G[popup .. "Button1"]
        if button and button:IsEnabled() then
            button:Click()
            return
        end
    end

    -- Retry release attempt to handle delayed popup because the button may not be ready yet

    if attempt < 20 then
        C_Timer.After(0.3, function() TryAutoRelease(attempt + 1) end)
    end
end

-- Create event frame to listen for PvP lifecycle events because addon needs event-driven activation

local pvpFrame = CreateFrame("Frame")
pvpFrame:RegisterEvent("ADDON_LOADED")
pvpFrame:RegisterEvent("PLAYER_DEAD")
pvpFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
pvpFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")

-- Route events to handlers to trigger PvP features because each event requires different logic

pvpFrame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" and addonName == ADDON_NAME then
        HookStatusTrackingBar()
    elseif event == "PLAYER_DEAD" then
        local _, instanceType = IsInInstance()
        if instanceType == "pvp" or instanceType == "arena" then
            C_Timer.After(0.5, function() TryAutoRelease(1) end)
        end
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        HookStatusTrackingBar()
        C_Timer.After(0.5, function()
            if StatusTrackingBarManager then
                StatusTrackingBarManager:UpdateBarsShown()
            end
        end)
    end
end)
