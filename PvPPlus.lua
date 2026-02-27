-- Hide honor bar in PvP instances and auto release on death in battlegrounds

local ADDON_NAME = ...

-- Hook CanShowBar to suppress honor bar in PvP and arena instances

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

-- Auto release ghost by clicking death popup when inside a battleground

local function TryAutoRelease(attempt)
    attempt = attempt or 1
    if attempt > 20 then return end

    -- Abort if a release-blocking aura or encounter is active

    if HasNoReleaseAura() then
        C_Timer.After(0.5, function() TryAutoRelease(attempt + 1) end)
        return
    end
    if C_InstanceEncounter and C_InstanceEncounter.IsEncounterSuppressingRelease and C_InstanceEncounter.IsEncounterSuppressingRelease() then
        C_Timer.After(0.5, function() TryAutoRelease(attempt + 1) end)
        return
    end

    -- Find and click the release button on the death popup

    local popup = StaticPopup_Visible("DEATH")
    if popup then
        local button = _G[popup .. "Button1"]
        if button and button:IsEnabled() then
            button:Click()
            return
        end
    end

    -- Retry until popup is ready or max attempts are reached

    if attempt < 20 then
        C_Timer.After(0.3, function() TryAutoRelease(attempt + 1) end)
    end
end

local pvpFrm = CreateFrame("Frame")
pvpFrm:RegisterEvent("ADDON_LOADED")
pvpFrm:RegisterEvent("PLAYER_DEAD")
pvpFrm:RegisterEvent("PLAYER_ENTERING_WORLD")
pvpFrm:RegisterEvent("ZONE_CHANGED_NEW_AREA")

pvpFrm:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
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
