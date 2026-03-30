-- Spec names keyed by player GUID
local specCache = {}
local inspectQueue = {}
local inspectBusy = false
local inspectCurrentUnit = nil


local INSPECT_THROTTLE_SECONDS = 0.5


local ROLE_DISPLAY_LABELS = {
    TANK    = "Tank",
    HEALER  = "Healer",
    DAMAGER = "DPS",
}


-- ┌─────────────────────────────────────────────────────────────────────────┐
-- │  CHANGED: prompt now enforces real BG-chat shorthand and clipped style  │
-- └─────────────────────────────────────────────────────────────────────────┘
local STRAT_PROMPT_TEMPLATE = [[You are a BG call sheet generator for World of Warcraft: Midnight.

Output format — each line must look exactly like this:

Name1, Name2: Callout.

Rules:
- Every player appears exactly once across all lines
- Group players sharing the same task on one line
- Write like a veteran WoW PvP player calling in BG chat: short, clipped, imperative
- Use real BG shorthand — cap, def, mid, FC, flag, GY, inc — and node abbreviations (BS, LM, farm, mine, DR, BE, MT, etc.)
- Nothing but destination and action — no abilities, no tips, no filler words
- Call lines only — no headers, no sections, no blank lines, no extra text
- First names only, exactly as listed in the roster below]]


-- Return true when the player is inside a battleground (including prep phase)
local function IsInBattleground()
    local inInstance, instanceType = IsInInstance()
    return inInstance and instanceType == "pvp"
end


local function GetBattlegroundName()
    return GetInstanceInfo() or "Battleground"
end


local function GetPlayerFaction()
    if IsInBattleground() then
        local teamIndex = GetBattlefieldArenaFaction()
        if teamIndex == 1 then return "Alliance" end
        if teamIndex == 0 then return "Horde" end
    end
    return UnitFactionGroup("player") or "Unknown"
end


-- Strip realm suffix from "Name-Server" strings
local function ShortName(fullName)
    if not fullName then return "?" end
    return fullName:match("^([^%-]+)") or fullName
end


local function CacheLocalPlayerSpec()
    local specIndex = C_SpecializationInfo.GetSpecialization()
    if not specIndex or specIndex == 0 then return end
    local _, specName = C_SpecializationInfo.GetSpecializationInfo(specIndex)
    local guid = UnitGUID("player")
    if guid and specName then
        specCache[guid] = specName
    end
end


local function ResolveSpecDisplay(guid, role)
    if specCache[guid] then return specCache[guid] end
    return ROLE_DISPLAY_LABELS[role] or "?"
end


local function AdvanceInspectQueue()
    if #inspectQueue == 0 then
        inspectBusy = false
        return
    end
    inspectBusy = true
    inspectCurrentUnit = table.remove(inspectQueue, 1)
    NotifyInspect(inspectCurrentUnit)
end


local function QueueGroupMembersForInspect()
    wipe(inspectQueue)
    local localPlayerGUID = UnitGUID("player")

    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local unitToken = "raid" .. i
            local guid = UnitGUID(unitToken)
            if guid and guid ~= localPlayerGUID then
                table.insert(inspectQueue, unitToken)
            end
        end
    elseif IsInGroup() then
        for i = 1, GetNumSubgroupMembers() do
            table.insert(inspectQueue, "party" .. i)
        end
    end

    if not inspectBusy then
        AdvanceInspectQueue()
    end
end


local function CollectGroupMemberData()
    local memberList = {}
    local localPlayerGUID = UnitGUID("player")

    table.insert(memberList, {
        name  = ShortName(UnitName("player")),
        class = UnitClass("player"),
        spec  = ResolveSpecDisplay(localPlayerGUID, UnitGroupRolesAssigned("player")),
    })

    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local memberName, _, _, _, memberClass = GetRaidRosterInfo(i)
            local unitToken = "raid" .. i
            local guid = UnitGUID(unitToken)
            if memberName and guid and guid ~= localPlayerGUID then
                table.insert(memberList, {
                    name  = ShortName(memberName),
                    class = memberClass,
                    spec  = ResolveSpecDisplay(guid, UnitGroupRolesAssigned(unitToken)),
                })
            end
        end
    elseif IsInGroup() then
        for i = 1, GetNumSubgroupMembers() do
            local unitToken = "party" .. i
            local memberName = UnitName(unitToken)
            local guid = UnitGUID(unitToken)
            if memberName and guid then
                table.insert(memberList, {
                    name  = ShortName(memberName),
                    class = UnitClass(unitToken),
                    spec  = ResolveSpecDisplay(guid, UnitGroupRolesAssigned(unitToken)),
                })
            end
        end
    end

    table.sort(memberList, function(a, b) return a.name < b.name end)
    return memberList
end


local function BuildStrategyText()
    local rosterLines = {}
    for _, member in ipairs(CollectGroupMemberData()) do
        rosterLines[#rosterLines + 1] = "- " .. member.name
            .. " \226\128\148 " .. (member.class or "?")
            .. " \226\128\148 " .. (member.spec  or "?")
    end

    return STRAT_PROMPT_TEMPLATE
        .. "\n\nBattleground: " .. GetBattlegroundName()
        .. "\nFaction: "        .. GetPlayerFaction()
        .. "\nRoster:\n"        .. table.concat(rosterLines, "\n")
end


local strategyFrame


local function BuildStrategyFrame()
    if strategyFrame then return strategyFrame end

    local frame = CreateFrame("Frame", "BGHelperStratFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(680, 360)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    -- CHANGED: title
    frame.TitleText:SetText("BG Call Sheet")

    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT",     frame.InsetBg, "TOPLEFT",      4,  -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame.InsetBg, "BOTTOMRIGHT", -24, 34)

    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetSize(620, 900)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(GameFontHighlight)
    editBox:SetMaxLetters(0)
    editBox:SetPropagateKeyboardInput(false)
    editBox:SetScript("OnEscapePressed", function() frame:Hide() end)

    -- Close after clipboard write completes on Ctrl+C / Cmd+C
    editBox:SetScript("OnKeyDown", function(self, key)
        if key == "C" and (IsControlKeyDown() or IsMetaKeyDown()) then
            C_Timer.After(0.05, function() frame:Hide() end)
        end
    end)

    scrollFrame:SetScrollChild(editBox)
    frame.editBox = editBox

    local hintLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hintLabel:SetPoint("BOTTOMLEFT", frame.InsetBg, "BOTTOMLEFT", 6, 12)
    hintLabel:SetText("Ctrl+C / Cmd+C  -  copies and closes")
    hintLabel:SetTextColor(0.65, 0.65, 0.65)

    local selectAllButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    selectAllButton:SetSize(110, 22)
    selectAllButton:SetPoint("BOTTOMRIGHT", frame.InsetBg, "BOTTOMRIGHT", -2, 10)
    selectAllButton:SetText("Select All")
    selectAllButton:SetScript("OnClick", function()
        editBox:SetFocus()
        editBox:HighlightText()
    end)

    strategyFrame = frame
    return frame
end


local function RefreshStrategyWindowIfOpen()
    if strategyFrame and strategyFrame:IsShown() then
        strategyFrame.editBox:SetText(BuildStrategyText())
        strategyFrame.editBox:HighlightText()
    end
end


local function OpenStrategyWindow()
    if not IsInBattleground() then
        -- CHANGED: casual error message
        print("|cffffcc00BGHelper:|r /strat only works inside a BG.")
        return
    end

    local frame = BuildStrategyFrame()
    frame.editBox:SetText(BuildStrategyText())
    frame.editBox:SetFocus()
    frame.editBox:HighlightText()
    frame:Show()

    QueueGroupMembersForInspect()
end


local eventFrame = CreateFrame("Frame")

eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("INSPECT_READY")

eventFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_ENTERING_WORLD" then
        wipe(specCache)
        CacheLocalPlayerSpec()
        if IsInBattleground() then
            C_Timer.After(3.0, QueueGroupMembersForInspect)
        end

    elseif event == "GROUP_ROSTER_UPDATE" then
        if IsInBattleground() then
            C_Timer.After(1.0, QueueGroupMembersForInspect)
        end

    elseif event == "INSPECT_READY" then
        if inspectCurrentUnit then
            local guid = UnitGUID(inspectCurrentUnit)
            local specIndex = C_SpecializationInfo.GetSpecialization(true)
            if guid and specIndex and specIndex ~= 0 then
                local _, specName = C_SpecializationInfo.GetSpecializationInfo(specIndex, true)
                if specName then
                    specCache[guid] = specName
                end
            end
            ClearInspectPlayer()
            inspectCurrentUnit = nil
        end
        inspectBusy = false
        RefreshStrategyWindowIfOpen()
        C_Timer.After(INSPECT_THROTTLE_SECONDS, AdvanceInspectQueue)
    end
end)


-- /strat: open the BG call sheet window
SLASH_BGHELPERSTRAT1 = "/strat"
SlashCmdList["BGHELPERSTRAT"] = function()
    OpenStrategyWindow()
end