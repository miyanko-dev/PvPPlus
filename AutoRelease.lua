-- Auto release spirit on death in PvP instances.

local PVP_INSTANCE_TYPES = { pvp = true, arena = true }

local GetSelfResurrectOptions = C_DeathInfo and C_DeathInfo.GetSelfResurrectOptions or function() return {} end

local function CanAutoRelease()
    local _, instanceType = IsInInstance()
    if not PVP_INSTANCE_TYPES[instanceType] then return false end
    local options = GetSelfResurrectOptions()
    return not (options and #options > 0)
end

local function TryRelease()
    if UnitIsDeadOrGhost("player") then
        RepopMe()
    end
end

local function OnPlayerDead()
    if not CanAutoRelease() then return end
    RunNextFrame(TryRelease)
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_DEAD")
eventFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_DEAD" then
        OnPlayerDead()
    end
end)