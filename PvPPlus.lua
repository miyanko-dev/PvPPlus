local ADDON_NAME, ns = ...

-- Settings defaults
local defaults = {
    hideHonorBar = true,
    autoRelease = true,
    tabTargeting = true,
}

-- Hide honor/status tracking bars in PvP
local function UpdateStatusBarVisibility()
    if not PvPPlusDB.hideHonorBar then
        if MainStatusTrackingBarContainer then
            MainStatusTrackingBarContainer:Show()
            MainStatusTrackingBarContainer:SetScript("OnShow", nil)
        end
        return
    end

    if not MainStatusTrackingBarContainer then return end

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

-- Auto release in battlegrounds and arenas
local function ShouldAutoRelease()
    if not PvPPlusDB.autoRelease then return false end

    if C_PvP.IsBattleground() then return true end

    local inInstance, instanceType = IsInInstance()
    if inInstance and (instanceType == "pvp" or instanceType == "arena") then
        return true
    end

    return false
end

local function TryAutoRelease(attempt)
    attempt = attempt or 1
    if attempt > 20 then return end

    if HasNoReleaseAura() then
        C_Timer.After(0.5, function() TryAutoRelease(attempt + 1) end)
        return
    end

    if C_InstanceEncounter and C_InstanceEncounter.IsEncounterSuppressingRelease and C_InstanceEncounter.IsEncounterSuppressingRelease() then
        C_Timer.After(0.5, function() TryAutoRelease(attempt + 1) end)
        return
    end

    RepopMe()
end

-- Tab targeting: players in PvP, all enemies outside
local function UpdateTabTargeting()
    if not PvPPlusDB.tabTargeting then return end

    local inInstance, instanceType = IsInInstance()
    local inPvP = inInstance and (instanceType == "pvp" or instanceType == "arena")

    if inPvP then
        SetCVar("targetNearestUseOld", 0)
        SetBinding("TAB", "TARGETNEARESTENEMYPLAYER")
    else
        SetBinding("TAB", "TARGETNEARESTENEMY")
    end
end

-- Event handler
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_DEAD")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_ENTERING_BATTLEGROUND")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        if not PvPPlusDB then PvPPlusDB = {} end
        for k, v in pairs(defaults) do
            if PvPPlusDB[k] == nil then
                PvPPlusDB[k] = v
            end
        end

        SLASH_PVPPLUS1 = "/pvpplus"
        SLASH_PVPPLUS2 = "/pvp+"
        SlashCmdList["PVPPLUS"] = function(msg)
            msg = strlower(strtrim(msg or ""))
            if msg == "bar" then
                PvPPlusDB.hideHonorBar = not PvPPlusDB.hideHonorBar
                print("|cff00ccff[PvP Plus]|r Hide honor bar: " .. (PvPPlusDB.hideHonorBar and "ON" or "OFF"))
                UpdateStatusBarVisibility()
            elseif msg == "release" then
                PvPPlusDB.autoRelease = not PvPPlusDB.autoRelease
                print("|cff00ccff[PvP Plus]|r Auto release: " .. (PvPPlusDB.autoRelease and "ON" or "OFF"))
            elseif msg == "tab" then
                PvPPlusDB.tabTargeting = not PvPPlusDB.tabTargeting
                print("|cff00ccff[PvP Plus]|r Tab targeting: " .. (PvPPlusDB.tabTargeting and "ON" or "OFF"))
                UpdateTabTargeting()
            else
                print("|cff00ccff[PvP Plus]|r Commands:")
                print("  /pvpplus bar - Toggle hide honor bar (" .. (PvPPlusDB.hideHonorBar and "ON" or "OFF") .. ")")
                print("  /pvpplus release - Toggle auto release (" .. (PvPPlusDB.autoRelease and "ON" or "OFF") .. ")")
                print("  /pvpplus tab - Toggle tab targeting (" .. (PvPPlusDB.tabTargeting and "ON" or "OFF") .. ")")
            end
        end

    elseif event == "PLAYER_DEAD" then
        if ShouldAutoRelease() then
            C_Timer.After(2, function() TryAutoRelease(1) end)
        end

    elseif event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_ENTERING_BATTLEGROUND" or event == "ZONE_CHANGED_NEW_AREA" then
        C_Timer.After(0.5, function()
            UpdateStatusBarVisibility()
            UpdateTabTargeting()
        end)
    end
end)
