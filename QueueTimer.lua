-- Replace BG/dungeon queue popup labels with large countdown timers.

local THROTTLE_INTERVAL       = 0.1
local DUNGEON_TIMER_DURATION  = 40

local function ColorizeTime(remainingSeconds)
    local color = remainingSeconds > 10 and "ffffffff" or "ffff0000"
    local minutes = math.floor(remainingSeconds / 60)
    local seconds = math.floor(remainingSeconds % 60)
    local text = minutes > 0 and string.format("%dm %ds", minutes, seconds)
                            or string.format("%ds", seconds)
    return "|c" .. color .. text .. "|r"
end

local function ApplyLargeFont(label)
    local fontPath = label:GetFont()
    label:SetFont(fontPath or "Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
end

-- BG timer

local bgTimerFrame = CreateFrame("Frame")
local bgElapsed    = 0
local bgQueueIndex = nil

local function GetBgLabel() return PVPReadyDialog.label or PVPReadyDialog.text end

local function StartBgTimer(queueIndex)
    bgQueueIndex = queueIndex
    bgElapsed    = 0

    local function Tick()
        if not PVPReadyDialog_Showing(bgQueueIndex) then
            bgQueueIndex = nil
            bgElapsed    = 0
            bgTimerFrame:SetScript("OnUpdate", nil)
            return
        end
        local remaining = GetBattlefieldPortExpiration(bgQueueIndex)
        if remaining and remaining > 0 then
            GetBgLabel():SetText(ColorizeTime(remaining))
        end
    end

    local function Throttle(_, elapsed)
        bgElapsed = bgElapsed + elapsed
        if bgElapsed < THROTTLE_INTERVAL then return end
        bgElapsed = 0
        Tick()
    end

    Tick()
    bgTimerFrame:SetScript("OnUpdate", Throttle)
end

-- Dungeon timer

local dgTimerFrame    = CreateFrame("Frame")
local dgElapsed       = 0
local dgRemaining     = 0
local origLabelSetText = LFGDungeonReadyDialog.label.SetText

local function StartDgTimer()
    dgRemaining = DUNGEON_TIMER_DURATION
    dgElapsed    = 0

    local function Tick()
        if dgRemaining <= 0 then
            dgElapsed = 0
            dgTimerFrame:SetScript("OnUpdate", nil)
            return
        end
        origLabelSetText(LFGDungeonReadyDialog.label, ColorizeTime(dgRemaining))
    end

    local function Throttle(_, elapsed)
        dgElapsed = dgElapsed + elapsed
        if dgElapsed < THROTTLE_INTERVAL then return end
        dgRemaining = dgRemaining - dgElapsed
        dgElapsed   = 0
        Tick()
    end

    dgTimerFrame:SetScript("OnUpdate", Throttle)
end

-- Init

local bgLabel = GetBgLabel()
bgLabel:SetPoint("TOP", 0, -22)
ApplyLargeFont(bgLabel)

LFGDungeonReadyDialog.label.SetText = function() end
LFGDungeonReadyDialog.label:SetPoint("TOP", 0, -22)
ApplyLargeFont(LFGDungeonReadyDialog.label)

-- Events

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")
eventFrame:RegisterEvent("LFG_PROPOSAL_SHOW")
eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "UPDATE_BATTLEFIELD_STATUS" then
        local status = GetBattlefieldStatus(...)
        if status == "confirm" then StartBgTimer(...) end
    elseif event == "LFG_PROPOSAL_SHOW" then
        StartDgTimer()
    end
end)