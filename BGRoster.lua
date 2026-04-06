-- Strip server suffix from a unit name to return the short name only

local function ShortName(fullName)
    if not fullName then return "?" end
    return fullName:match("^([^%-]+)") or fullName
end


-- Check if the player is currently inside a battleground instance

local function IsInBattleground()
    local inInstance, instanceType = IsInInstance()
    return inInstance and instanceType == "pvp"
end


-- Return the current battleground map name or a fallback label

local function GetBattlegroundName()
    local name = GetInstanceInfo()
    return name or "Battleground"
end


-- Resolve the player's team name through arena faction index

local function GetTeamName()
    local teamIndex = GetBattlefieldArenaFaction()
    if teamIndex == 1 then return "Alliance" end
    if teamIndex == 0 then return "Horde" end
    return UnitFactionGroup("player") or "Unknown"
end


-- Gather sorted short names of all group members including the player

local function CollectRosterNames()
    local names    = { ShortName(UnitName("player")) }
    local selfGUID = UnitGUID("player")

    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local unit = "raid" .. i
            local guid = UnitGUID(unit)
            if guid and guid ~= selfGUID then
                local name = UnitName(unit)
                if name then
                    names[#names + 1] = ShortName(name)
                end
            end
        end
    elseif IsInGroup() then
        for i = 1, GetNumSubgroupMembers() do
            local name = UnitName("party" .. i)
            if name then
                names[#names + 1] = ShortName(name)
            end
        end
    end

    table.sort(names)
    return names
end


-- Compose the full roster text block from battleground, team, and member names

local function BuildRosterText()
    return GetBattlegroundName()
        .. "\n" .. GetTeamName()
        .. "\n\n" .. table.concat(CollectRosterNames(), "\n")
end


local rosterFrame


-- Create the roster window with scroll, editbox, and copy controls

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
    scrollFrame:SetPoint("BOTTOMRIGHT", frame.InsetBg, "BOTTOMRIGHT", -24, 34)

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


-- Refresh the roster text if the window is currently visible

local function RefreshRosterWindowIfOpen()
    if rosterFrame and rosterFrame:IsShown() then
        rosterFrame.editBox:SetText(BuildRosterText())
        rosterFrame.editBox:HighlightText()
    end
end


-- Populate and show the roster window when inside a battleground

local function OpenRosterWindow()
    if not IsInBattleground() then return end

    local frame = BuildRosterFrame()
    frame.editBox:SetText(BuildRosterText())
    frame.editBox:SetFocus()
    frame.editBox:HighlightText()
    frame:Show()
end


local matchIsActive = false


-- Attach the Roster button to the scoreboard, hidden during active matches

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
    end

    if matchIsActive then
        sb._pvplusBtn:Hide()
    else
        sb._pvplusBtn:Show()
    end
end


-- Register PvP match and group events to drive button and roster window state

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("UPDATE_BATTLEFIELD_SCORE")
eventFrame:RegisterEvent("PVP_MATCH_ACTIVE")
eventFrame:RegisterEvent("PVP_MATCH_COMPLETE")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

eventFrame:SetScript("OnEvent", function(self, event)
    if event == "PVP_MATCH_ACTIVE" then
        matchIsActive = true
        local sb = PVPMatchScoreboard
        if sb and sb._pvplusBtn then sb._pvplusBtn:Hide() end
        if rosterFrame and rosterFrame:IsShown() then rosterFrame:Hide() end

    elseif event == "PVP_MATCH_COMPLETE" then
        matchIsActive = false
        EnsureScoreboardButton()

    elseif event == "PLAYER_ENTERING_WORLD" then
        matchIsActive = false
        if rosterFrame and rosterFrame:IsShown() then rosterFrame:Hide() end
        EnsureScoreboardButton()

    else  -- GROUP_ROSTER_UPDATE, UPDATE_BATTLEFIELD_SCORE
        EnsureScoreboardButton()
        RefreshRosterWindowIfOpen()
    end
end)
