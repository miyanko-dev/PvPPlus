-- Replace queue popup labels with large countdown timers that turn red below ten seconds

local THROTTLE_INTERVAL = 0.1
local DUNGEON_TIMER_DURATION = 40

-- Format seconds as colored time text, through white-or-red selection, to signal urgency

local function ColorizeTime(remainingSeconds)
    local color = remainingSeconds > 10 and "ffffffff" or "ffff0000"
    local minutes = math.floor(remainingSeconds / 60)
    local seconds = math.floor(remainingSeconds % 60)
    local text = minutes > 0 and string.format("%dm %ds", minutes, seconds) or string.format("%ds", seconds)

    return "|c" .. color .. text .. "|r"
end

-- Apply oversized outlined font to a popup label for better readability

local function ApplyLargeFont(label)
    local fontPath = label:GetFont()
    label:SetFont(fontPath or "Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
end

-- Declare BG timer state and cache the ready dialog label to avoid repeated lookups per tick

local bgTimerFrame = CreateFrame("Frame")
local bgElapsed
local bgQueueIndex
local bgLabel = PVPReadyDialog.label or PVPReadyDialog.text

-- Reposition and enlarge the BG label upfront to prepare it for countdown display

bgLabel:SetPoint("TOP", 0, -22)
ApplyLargeFont(bgLabel)

-- Update the battleground countdown or stop the timer when the dialog closes

local function UpdateBattlegroundTimer()
    if PVPReadyDialog_Showing(bgQueueIndex) then
        local remaining = GetBattlefieldPortExpiration(bgQueueIndex)

        if remaining and remaining > 0 then
            bgLabel:SetText(ColorizeTime(remaining))
        end
    else
        bgQueueIndex = nil
        bgElapsed = nil
        bgTimerFrame:SetScript("OnUpdate", nil)
    end
end

-- Throttle battleground timer updates, via elapsed accumulation, to every tenth of a second

local function ThrottleBattlegroundTimer(_, elapsed)
    bgElapsed = bgElapsed + elapsed
    if bgElapsed < THROTTLE_INTERVAL then return end

    bgElapsed = 0
    UpdateBattlegroundTimer()
end

-- Start the battleground countdown when a queue pops with confirm status

local function HandleBattlegroundPopup(queueIndex)
    bgQueueIndex = queueIndex
    bgElapsed = 0

    UpdateBattlegroundTimer()
    bgTimerFrame:SetScript("OnUpdate", ThrottleBattlegroundTimer)
end

-- Check queue status and trigger the popup handler if the slot is confirmed

local function CheckBattlegroundQueue(queueIndex)
    local status = GetBattlefieldStatus(queueIndex)

    if status == "confirm" then
        HandleBattlegroundPopup(queueIndex)
    end
end

-- Declare dungeon timer state and capture the original label setter to drive the countdown

local dgTimerFrame = CreateFrame("Frame")
local dgElapsed
local dgRemaining = 0
local origLabelSetText = LFGDungeonReadyDialog.label.SetText

-- Block the default label setter and resize the dungeon label to prepare for countdown display

LFGDungeonReadyDialog.label.SetText = function() end
LFGDungeonReadyDialog.label:SetPoint("TOP", 0, -22)
ApplyLargeFont(LFGDungeonReadyDialog.label)

-- Update the dungeon countdown or stop the timer when time expires

local function UpdateDungeonTimer()
    if dgRemaining > 0 then
        origLabelSetText(LFGDungeonReadyDialog.label, ColorizeTime(dgRemaining))
    else
        dgTimerFrame:SetScript("OnUpdate", nil)
        dgElapsed = nil
    end
end

-- Throttle dungeon timer and decrement remaining time, via elapsed accumulation, each frame

local function ThrottleDungeonTimer(_, elapsed)
    dgElapsed = dgElapsed + elapsed
    if dgElapsed < THROTTLE_INTERVAL then return end

    dgRemaining = dgRemaining - dgElapsed
    dgElapsed = 0
    UpdateDungeonTimer()
end

-- Start the dungeon countdown at forty seconds when a proposal popup shows

local function HandleDungeonPopup()
    dgRemaining = DUNGEON_TIMER_DURATION
    dgElapsed = 0

    dgTimerFrame:SetScript("OnUpdate", ThrottleDungeonTimer)
end

-- Dispatch queue events to their corresponding timer handlers

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")
eventFrame:RegisterEvent("LFG_PROPOSAL_SHOW")
eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "UPDATE_BATTLEFIELD_STATUS" then
        CheckBattlegroundQueue(...)
    elseif event == "LFG_PROPOSAL_SHOW" then
        HandleDungeonPopup()
    end
end)
