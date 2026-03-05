-- Auto release spirit in PvP instances to skip the manual click because it delays respawning

-- Click release button automatically to skip manual release because it delays respawning

local function tryAutoRelease(attempt)
    attempt = attempt or 1
    if attempt > 20 then return end

    -- Skip release attempt to avoid errors because a blocking aura or encounter is active

    if HasNoReleaseAura() then
        C_Timer.After(0.5, function() tryAutoRelease(attempt + 1) end)
        return
    end

    if C_InstanceEncounter and C_InstanceEncounter.IsEncounterSuppressingRelease and C_InstanceEncounter.IsEncounterSuppressingRelease() then
        C_Timer.After(0.5, function() tryAutoRelease(attempt + 1) end)
        return
    end

    -- Find and click release button to release spirit because the death popup is visible

    local popup = StaticPopup_Visible("DEATH")

    if popup then
        local releaseButton = _G[popup .. "Button1"]
        if releaseButton and releaseButton:IsEnabled() then
            releaseButton:Click()
            return
        end
    end

    -- Retry release attempt to handle delayed popup because the button may not be ready yet

    if attempt < 20 then
        C_Timer.After(0.3, function() tryAutoRelease(attempt + 1) end)
    end
end

-- Register death event to trigger auto release in PvP because manual clicking delays respawning

local eventFrame = CreateFrame("Frame")

eventFrame:RegisterEvent("PLAYER_DEAD")

eventFrame:SetScript("OnEvent", function()
    local _, instanceType = IsInInstance()
    if instanceType == "pvp" or instanceType == "arena" then
        C_Timer.After(0.5, function() tryAutoRelease(1) end)
    end
end)
