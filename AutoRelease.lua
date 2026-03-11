-- Auto release spirit in PvP instances to skip the manual click

local RELEASE_INTERVAL = 0.1
local RELEASE_TIMEOUT = 5
local releaseTicker = nil

-- Stop any active release ticker
local function stopReleaseTicker()
    if releaseTicker then
        releaseTicker:Cancel()
        releaseTicker = nil
    end
end

-- Check whether release is currently blocked by an aura or encounter
local function isReleaseBlocked()
    if HasNoReleaseAura() then return true end
    if C_InstanceEncounter and C_InstanceEncounter.IsEncounterSuppressingRelease then
        return C_InstanceEncounter.IsEncounterSuppressingRelease()
    end
    return false
end

-- Attempt to release every tick until successful or timed out
local function startReleaseAttempts()
    stopReleaseTicker()
    local elapsed = 0

    releaseTicker = C_Timer.NewTicker(RELEASE_INTERVAL, function()
        elapsed = elapsed + RELEASE_INTERVAL

        -- Give up after timeout to avoid running indefinitely
        if elapsed >= RELEASE_TIMEOUT then
            stopReleaseTicker()
            return
        end

        -- Wait if a blocking condition is active
        if isReleaseBlocked() then return end

        -- Release and stop ticking on success
        if UnitIsDeadOrGhost("player") then
            RepopMe()
            stopReleaseTicker()
        end
    end)
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_DEAD")
eventFrame:RegisterEvent("PLAYER_ALIVE")

eventFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_DEAD" then
        local _, instanceType = IsInInstance()
        if instanceType == "pvp" or instanceType == "arena" then
            startReleaseAttempts()
        end
    elseif event == "PLAYER_ALIVE" then
        -- Cancel if the player was resurrected before the ticker fired
        stopReleaseTicker()
    end
end)
