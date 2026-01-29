local ADDON_NAME, ns = ...

-- Settings defaults
local defaults = {
    hideHonorBar = true,
    autoRelease = true,
    tabTargeting = true,
}

-- Hide honor/status tracking bars in PvP
local function UpdateStatusBarVisibility()
    if not EasyPvPDB.hideHonorBar then
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
    if not EasyPvPDB.autoRelease then return false end

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
    if not EasyPvPDB.tabTargeting then return end

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
        if not EasyPvPDB then EasyPvPDB = {} end
        for k, v in pairs(defaults) do
            if EasyPvPDB[k] == nil then
                EasyPvPDB[k] = v
            end
        end

        SLASH_EASYPVP1 = "/easypvp"
        SLASH_EASYPVP2 = "/epvp"
        SlashCmdList["EASYPVP"] = function(msg)
            msg = strlower(strtrim(msg or ""))
            if msg == "bar" then
                EasyPvPDB.hideHonorBar = not EasyPvPDB.hideHonorBar
                print("|cff00ccff[EasyPvP]|r Hide honor bar: " .. (EasyPvPDB.hideHonorBar and "ON" or "OFF"))
                UpdateStatusBarVisibility()
            elseif msg == "release" then
                EasyPvPDB.autoRelease = not EasyPvPDB.autoRelease
                print("|cff00ccff[EasyPvP]|r Auto release: " .. (EasyPvPDB.autoRelease and "ON" or "OFF"))
            elseif msg == "tab" then
                EasyPvPDB.tabTargeting = not EasyPvPDB.tabTargeting
                print("|cff00ccff[EasyPvP]|r Tab targeting: " .. (EasyPvPDB.tabTargeting and "ON" or "OFF"))
                UpdateTabTargeting()
            else
                print("|cff00ccff[EasyPvP]|r Commands:")
                print("  /easypvp bar - Toggle hide honor bar (" .. (EasyPvPDB.hideHonorBar and "ON" or "OFF") .. ")")
                print("  /easypvp release - Toggle auto release (" .. (EasyPvPDB.autoRelease and "ON" or "OFF") .. ")")
                print("  /easypvp tab - Toggle tab targeting (" .. (EasyPvPDB.tabTargeting and "ON" or "OFF") .. ")")
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
