-- Strip server suffix from unit name to return the short name

local function ShortName(fullName)
    if not fullName then return "?" end
    return fullName:match("^([^%-]+)") or fullName
end

-- Return true when player is inside a battleground instance

local function IsInBattleground()
    local inInstance, instanceType = IsInInstance()
    return inInstance and instanceType == "pvp"
end

-- Return battleground map name or fallback label

local function GetBattlegroundName()
    local name = GetInstanceInfo()
    return name or "Battleground"
end

-- Resolve team name through arena faction index

local function GetTeamName()
    local teamIndex = GetBattlefieldArenaFaction()
    if teamIndex == 1 then return "Alliance" end
    if teamIndex == 0 then return "Horde" end
    return UnitFactionGroup("player") or "Unknown"
end

local ROLE_LABELS = {
    TANK    = "Tank",
    HEALER  = "Healer",
    DAMAGER = "DPS",
}

-- Build member entry from unit token, name, and class

local function MakeMember(unit, name, class)
    local role = UnitGroupRolesAssigned(unit)
    return {
        name  = ShortName(name),
        class = class,
        role  = ROLE_LABELS[role] or "?",
    }
end

-- Collect sorted member data including name, class, and role

local function CollectRosterData()
    local selfGUID = UnitGUID("player")
    local members  = { MakeMember("player", UnitName("player"), UnitClass("player")) }

    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local memberName, _, _, _, memberClass = GetRaidRosterInfo(i)
            local unit = "raid" .. i
            local guid = UnitGUID(unit)
            if memberName and guid and guid ~= selfGUID then
                members[#members + 1] = MakeMember(unit, memberName, memberClass)
            end
        end
    elseif IsInGroup() then
        for i = 1, GetNumSubgroupMembers() do
            local unit = "party" .. i
            local memberName = UnitName(unit)
            if memberName then
                members[#members + 1] = MakeMember(unit, memberName, UnitClass(unit))
            end
        end
    end

    table.sort(members, function(a, b) return a.name < b.name end)
    return members
end

-- Build full roster text from battleground info and member data

local function BuildRosterText()
    local lines = {}
    for _, m in ipairs(CollectRosterData()) do
        lines[#lines + 1] = m.name .. ", " .. (m.class or "?") .. ", " .. m.role
    end
    return "Battleground: " .. GetBattlegroundName()
        .. "\nTeam / Faction: " .. GetTeamName()
        .. "\n\nTeam:\n" .. table.concat(lines, "\n")
end

local rosterFrame

-- Create roster window with scroll, editbox, and copy controls

local function BuildRosterFrame()
    if rosterFrame then return rosterFrame end

    local frame = CreateFrame("Frame", "PvPlusBlitzTacticsFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(320, 480)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetClampedToScreen(true)
    frame.TitleText:SetText("BG Roster")

    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT",     frame.InsetBg, "TOPLEFT",      4,  -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame.InsetBg, "BOTTOMRIGHT", -8, 0)

    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetSize(260, 900)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
    editBox:SetMaxLetters(0)
    editBox:SetPropagateKeyboardInput(false)
    editBox:SetScript("OnEscapePressed", function() frame:Hide() end)
    editBox:SetScript("OnKeyDown", function(self, key)
        if key == "C" and (IsControlKeyDown() or IsMetaKeyDown()) then
            C_Timer.After(0.05, function() frame:Hide() end)
        end
    end)

    scrollFrame:SetScrollChild(editBox)
    frame.editBox = editBox

    local hintLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hintLabel:SetPoint("BOTTOMLEFT", frame.InsetBg, "BOTTOMLEFT", 6, 12)
    hintLabel:SetText("Ctrl+C / Cmd+C  \226\128\148  copies and closes")
    hintLabel:SetTextColor(0.65, 0.65, 0.65)

    local selectAllButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    selectAllButton:SetSize(110, 22)
    selectAllButton:SetPoint("BOTTOMRIGHT", frame.InsetBg, "BOTTOMRIGHT", -2, 10)
    selectAllButton:SetText("Select All")
    selectAllButton:SetScript("OnClick", function()
        editBox:SetFocus()
        editBox:HighlightText()
    end)

    rosterFrame = frame
    return frame
end

-- Refresh roster text if window is currently visible

local function RefreshRoster()
    if rosterFrame and rosterFrame:IsShown() then
        rosterFrame.editBox:SetText(BuildRosterText())
        rosterFrame.editBox:HighlightText()
    end
end

StaticPopupDialogs["PVPPLUS_MATCH_ACTIVE"] = {
    text    = "Match is still in progress.\nWait until it's over to copy the roster.",
    button1 = "OK",
    timeout = 0,
    hideOnEscape = true,
}

-- Show roster window when inside a battleground and match is not engaged

local function OpenRosterWindow()
    if not IsInBattleground() then return end

    if C_PvP.GetActiveMatchState() == Enum.PvPMatchState.Engaged then
        StaticPopup_Show("PVPPLUS_MATCH_ACTIVE")
        return
    end

    local frame = BuildRosterFrame()
    frame.editBox:SetText(BuildRosterText())
    frame.editBox:SetFocus()
    frame.editBox:HighlightText()
    frame:Show()
end

-- Attach Roster button to the scoreboard

local function EnsureScoreboardButton()
    local sb = PVPMatchScoreboard
    if not sb then return end

    if not sb._pvplusBtn then
        local btn = CreateFrame("Button", nil, sb, "UIPanelButtonTemplate")
        btn:SetSize(90, 22)
        btn:SetText("Roster")
        btn:SetPoint("TOPRIGHT", sb, "TOPRIGHT", -36, -8)
        btn:SetScript("OnClick", OpenRosterWindow)
        sb._pvplusBtn = btn
        sb:HookScript("OnShow", function() sb._pvplusBtn:Show() end)
    end

    sb._pvplusBtn:Show()
end

-- Register PvP match, group, and score events to drive state

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("UPDATE_BATTLEFIELD_SCORE")
eventFrame:RegisterEvent("PVP_MATCH_ACTIVE")
eventFrame:RegisterEvent("PVP_MATCH_COMPLETE")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PVP_MATCH_ACTIVE" then
        if rosterFrame and rosterFrame:IsShown() then rosterFrame:Hide() end
        EnsureScoreboardButton()

    elseif event == "PVP_MATCH_COMPLETE" then
        EnsureScoreboardButton()

    elseif event == "PLAYER_ENTERING_WORLD" then
        if rosterFrame and rosterFrame:IsShown() then rosterFrame:Hide() end
        EnsureScoreboardButton()

    elseif event == "GROUP_ROSTER_UPDATE" then
        EnsureScoreboardButton()
        RefreshRoster()

    else  -- UPDATE_BATTLEFIELD_SCORE
        EnsureScoreboardButton()
        RefreshRoster()
    end
end)
