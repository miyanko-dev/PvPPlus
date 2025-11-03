-- Hides status tracking bars in arenas, battlegrounds, and PvP zones

local function updateStatusTrackingBarVisibility()
    if not MainStatusTrackingBarContainer then
        return
    end

    local _, instanceType = IsInInstance()
    local zonePvpInfo = GetZonePVPInfo()
    
    if instanceType == "arena" or instanceType == "pvp" or zonePvpInfo == "combat" then
        MainStatusTrackingBarContainer:Hide()
        MainStatusTrackingBarContainer:SetScript("OnShow", MainStatusTrackingBarContainer.Hide)
    else
        MainStatusTrackingBarContainer:Show()
        MainStatusTrackingBarContainer:SetScript("OnShow", nil)
    end
end

local statusTrackingBarEventFrame = CreateFrame("Frame")
statusTrackingBarEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
statusTrackingBarEventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
statusTrackingBarEventFrame:SetScript("OnEvent", updateStatusTrackingBarVisibility)
