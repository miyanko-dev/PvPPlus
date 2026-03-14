-- Countdown timers for PvP and PvE queue popups

-- White above 10 seconds, red at 10 or below
local function colorizeSeconds(seconds)
    local color = seconds > 10 and "ffffffff" or "ffff0000"
    return "|c" .. color .. SecondsToTime(seconds) .. "|r"
end

-- Apply font to a label frame
local function applyLargeFont(label)
    local fontPath = label:GetFont()
    label:SetFont(fontPath or "Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
end

-- PvP queue timer
local bgTimerFrame = CreateFrame("Frame")
local bgElapsed
local bgActiveQueue

local function getBgLabel()
    return PVPReadyDialog.label or PVPReadyDialog.text
end

getBgLabel():SetPoint("TOP", 0, -22)
applyLargeFont(getBgLabel())

local function updateBgTimer()
    if PVPReadyDialog_Showing(bgActiveQueue) then
        local remainSeconds = GetBattlefieldPortExpiration(bgActiveQueue)

        if remainSeconds and remainSeconds > 0 then
            getBgLabel():SetText(colorizeSeconds(remainSeconds))
        end
    else
        bgActiveQueue = nil
        bgElapsed = nil
        bgTimerFrame:SetScript("OnUpdate", nil)
    end
end

local function throttleBgTimer(_, elapsed)
    bgElapsed = bgElapsed + elapsed

    if bgElapsed < 0.1 then return end

    bgElapsed = 0
    updateBgTimer()
end

local function handleBgPop(queueIndex)
    bgActiveQueue = queueIndex
    updateBgTimer()
    bgElapsed = 0
    bgTimerFrame:SetScript("OnUpdate", throttleBgTimer)
end

local function checkBgQueue(queueIndex)
    local status = GetBattlefieldStatus(queueIndex)

    if status == "confirm" then
        handleBgPop(queueIndex)
    end
end

-- PvE queue timer
local lfgTimerFrame = CreateFrame("Frame")
local lfgElapsed
local lfgRemaining = 0

-- Block default label setter to prevent UI from overwriting countdown text
local lfgLabelSetText = LFGDungeonReadyDialog.label.SetText
LFGDungeonReadyDialog.label.SetText = function() end
LFGDungeonReadyDialog.label:SetPoint("TOP", 0, -22)
applyLargeFont(LFGDungeonReadyDialog.label)

local function updateLfgTimer()
    if lfgRemaining > 0 then
        lfgLabelSetText(LFGDungeonReadyDialog.label, colorizeSeconds(lfgRemaining))
    else
        lfgTimerFrame:SetScript("OnUpdate", nil)
        lfgElapsed = nil
    end
end

local function throttleLfgTimer(_, elapsed)
    lfgElapsed = lfgElapsed + elapsed

    if lfgElapsed < 0.1 then return end

    lfgRemaining = lfgRemaining - lfgElapsed
    lfgElapsed = 0
    updateLfgTimer()
end

local function handleLfgPopup()
    lfgRemaining = 40
    lfgElapsed = 0
    lfgTimerFrame:SetScript("OnUpdate", throttleLfgTimer)
end

-- Event registration
local eventFrame = CreateFrame("Frame")

eventFrame:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")
eventFrame:RegisterEvent("LFG_PROPOSAL_SHOW")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "UPDATE_BATTLEFIELD_STATUS" then
        local queueIndex = ...
        checkBgQueue(queueIndex)
    elseif event == "LFG_PROPOSAL_SHOW" then
        handleLfgPopup()
    end
end)
