-- Format remaining seconds to indicate urgency because visual priority should increase as time expires

local function colorizeRemainingSeconds(remainingSeconds)
    local alertColor = remainingSeconds > 10 and "ffffffff" or "ffff0000"
    local minutesRemaining = math.floor(remainingSeconds / 60)
    local secondsRemaining = math.floor(remainingSeconds % 60)
    local formattedTime = minutesRemaining > 0 and string.format("%dm %ds", minutesRemaining, secondsRemaining) or string.format("%ds", secondsRemaining)

    return "|c" .. alertColor .. formattedTime .. "|r"
end

-- Apply an oversized outlined font to a given text label because standard dialog fonts are too small to read instantly

local function applyLargeFont(textLabel)
    local originalFontPath = textLabel:GetFont()

    textLabel:SetFont(originalFontPath or "Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
end

--------------------------------------------------------------------------------
-- Battleground Queue Timer
--------------------------------------------------------------------------------

local battlegroundTimerFrame = CreateFrame("Frame")
local battlegroundElapsedSeconds
local activeBattlegroundQueueIndex

-- Retrieve the active text label for the ready dialog because the default frame dynamically swaps elements

local function getBattlegroundLabel()
    return PVPReadyDialog.label or PVPReadyDialog.text
end

getBattlegroundLabel():SetPoint("TOP", 0, -22)
applyLargeFont(getBattlegroundLabel())

-- Update the battleground timer label every tick because the expiration value needs continuous polling

local function updateBattlegroundTimer()
    if PVPReadyDialog_Showing(activeBattlegroundQueueIndex) then
        local remainingSeconds = GetBattlefieldPortExpiration(activeBattlegroundQueueIndex)

        if remainingSeconds and remainingSeconds > 0 then
            getBattlegroundLabel():SetText(colorizeRemainingSeconds(remainingSeconds))
        end
    else
        activeBattlegroundQueueIndex = nil
        battlegroundElapsedSeconds = nil
        battlegroundTimerFrame:SetScript("OnUpdate", nil)
    end
end

-- Throttle the battleground timer execution to every tenth of a second because running every frame degrades client performance

local function throttleBattlegroundTimer(_, elapsedSeconds)
    battlegroundElapsedSeconds = battlegroundElapsedSeconds + elapsedSeconds

    if battlegroundElapsedSeconds < 0.1 then return end

    battlegroundElapsedSeconds = 0
    updateBattlegroundTimer()
end

-- Initialize the timer state when a battleground queue pops because the countdown must start immediately

local function handleBattlegroundPopup(queueIndex)
    activeBattlegroundQueueIndex = queueIndex
    updateBattlegroundTimer()

    battlegroundElapsedSeconds = 0
    battlegroundTimerFrame:SetScript("OnUpdate", throttleBattlegroundTimer)
end

-- Inspect the current queue status to detect confirm messages because the event fires for multiple different state changes

local function checkBattlegroundQueue(queueIndex)
    local queueStatus = GetBattlefieldStatus(queueIndex)

    if queueStatus == "confirm" then
        handleBattlegroundPopup(queueIndex)
    end
end

--------------------------------------------------------------------------------
-- Dungeon Queue Timer
--------------------------------------------------------------------------------

local dungeonTimerFrame = CreateFrame("Frame")
local dungeonElapsedSeconds
local dungeonRemainingSeconds = 0

-- Block the default label mutator to prevent the UI from overwriting our countdown text because Blizzard constantly refreshes it

local originalDungeonLabelSetText = LFGDungeonReadyDialog.label.SetText

LFGDungeonReadyDialog.label.SetText = function() end
LFGDungeonReadyDialog.label:SetPoint("TOP", 0, -22)
applyLargeFont(LFGDungeonReadyDialog.label)

-- Update the looking for group timer label every tick because it counts down manually from forty seconds

local function updateDungeonTimer()
    if dungeonRemainingSeconds > 0 then
        originalDungeonLabelSetText(LFGDungeonReadyDialog.label, colorizeRemainingSeconds(dungeonRemainingSeconds))
    else
        dungeonTimerFrame:SetScript("OnUpdate", nil)
        dungeonElapsedSeconds = nil
    end
end

-- Throttle the dungeon timer to decrement remaining seconds predictably because manual tracking is required

local function throttleDungeonTimer(_, elapsedSeconds)
    dungeonElapsedSeconds = dungeonElapsedSeconds + elapsedSeconds

    if dungeonElapsedSeconds < 0.1 then return end

    dungeonRemainingSeconds = dungeonRemainingSeconds - dungeonElapsedSeconds
    dungeonElapsedSeconds = 0
    updateDungeonTimer()
end

-- Reset the dungeon timer state starting at forty seconds because standard looking for group popups have a fixed duration

local function handleDungeonPopup()
    dungeonRemainingSeconds = 40
    dungeonElapsedSeconds = 0

    dungeonTimerFrame:SetScript("OnUpdate", throttleDungeonTimer)
end

--------------------------------------------------------------------------------
-- Event Registration
--------------------------------------------------------------------------------

local queueEventFrame = CreateFrame("Frame")

-- Register queue lifecycle events to trigger the appropriate handlers because popups spawn dynamically entirely based on these triggers

queueEventFrame:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")
queueEventFrame:RegisterEvent("LFG_PROPOSAL_SHOW")

queueEventFrame:SetScript("OnEvent", function(_, dispatchedEvent, ...)
    if dispatchedEvent == "UPDATE_BATTLEFIELD_STATUS" then
        local passedQueueIndex = ...
        checkBattlegroundQueue(passedQueueIndex)

    elseif dispatchedEvent == "LFG_PROPOSAL_SHOW" then
        handleDungeonPopup()
    end
end)
