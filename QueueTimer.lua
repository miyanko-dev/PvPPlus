-- Countdown timers for PvP and PvE queue popups

local DEFAULT_CHAT_FRAME = _G.DEFAULT_CHAT_FRAME


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


-- Print queue wait duration to chat
local function printWaitTime(seconds)
    local queueMessage = "Queue popped "

    if seconds < 1 then
        queueMessage = queueMessage .. "instantly!"
    else
        queueMessage = queueMessage .. "after " .. SecondsToTime(seconds)
    end

    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99PvP+|r: " .. queueMessage)
end


-- PvP queue timer
local bgTimerFrame = CreateFrame("Frame")
local bgElapsed
local bgActiveQueue
local bgWaitTimes = {}


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

    if bgWaitTimes[queueIndex] ~= nil then
        printWaitTime(bgWaitTimes[queueIndex] / 1000)
        bgWaitTimes[queueIndex] = nil
    end

    updateBgTimer()
    bgElapsed = 0
    bgTimerFrame:SetScript("OnUpdate", throttleBgTimer)
end


local function checkBgQueue(queueIndex)
    local status = GetBattlefieldStatus(queueIndex)

    if status == "queued" then
        bgWaitTimes[queueIndex] = GetBattlefieldTimeWaited(queueIndex)
    elseif status == "confirm" then
        handleBgPop(queueIndex)
    end
end


-- PvE queue timer
local lfgTimerFrame = CreateFrame("Frame")
local lfgElapsed
local lfgRemaining = 0
local lfgWaitTimes = {}


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


-- Find closest queue key to match raid queues with inexact IDs
local function findClosestQueue(waitTimes, targetId)
    local closestId, closestDist

    for queueId in pairs(waitTimes) do
        local distance = math.abs(targetId - queueId)

        if closestDist == nil or distance < closestDist then
            closestId = queueId
            closestDist = distance
        end
    end

    return closestId
end


local function printLfgWaitTime(dungeonId)
    if lfgWaitTimes[dungeonId] ~= nil then
        printWaitTime(GetTime() - lfgWaitTimes[dungeonId])
        return
    end

    local closestId = findClosestQueue(lfgWaitTimes, dungeonId)

    if closestId ~= nil then
        printWaitTime(GetTime() - lfgWaitTimes[closestId])
    end
end


local function storeLfgQueues()
    for categoryIndex = 1, 6 do
        local categoryList = GetLFGQueuedList(categoryIndex)
        local startTime = select(17, GetLFGQueueStats(categoryIndex))

        for dungeonId in pairs(categoryList) do
            if startTime ~= nil then
                lfgWaitTimes[dungeonId] = startTime
            end
        end
    end
end


local function handleLfgPopup()
    local proposalInfo = {GetLFGProposal()}
    local dungeonId = proposalInfo[2]

    printLfgWaitTime(dungeonId)
    lfgRemaining = 40
    lfgElapsed = 0
    lfgTimerFrame:SetScript("OnUpdate", throttleLfgTimer)
end


-- Event registration
local eventFrame = CreateFrame("Frame")

eventFrame:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")
eventFrame:RegisterEvent("LFG_QUEUE_STATUS_UPDATE")
eventFrame:RegisterEvent("LFG_PROPOSAL_FAILED")
eventFrame:RegisterEvent("LFG_PROPOSAL_SHOW")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "UPDATE_BATTLEFIELD_STATUS" then
        local queueIndex = ...
        checkBgQueue(queueIndex)
    elseif event == "LFG_QUEUE_STATUS_UPDATE" or event == "LFG_PROPOSAL_FAILED" then
        storeLfgQueues()
    elseif event == "LFG_PROPOSAL_SHOW" then
        handleLfgPopup()
    end
end)
