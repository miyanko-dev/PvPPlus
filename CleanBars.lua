-- Hides status tracking bars in arenas, battlegrounds, and PvP zones

local function updateBarVisibility()
    if not MainStatusTrackingBarContainer then
        return
    end

    local _, instanceType = IsInInstance()
    local zonePvp = GetZonePVPInfo()
    
    if instanceType == "arena" or instanceType == "pvp" or zonePvp == "combat" then
        MainStatusTrackingBarContainer:Hide()
        MainStatusTrackingBarContainer:SetScript("OnShow", MainStatusTrackingBarContainer.Hide)
    else
        MainStatusTrackingBarContainer:Show()
        MainStatusTrackingBarContainer:SetScript("OnShow", nil)
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
eventFrame:SetScript("OnEvent", updateBarVisibility)
