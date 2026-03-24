-- Auto release spirit in battlegrounds and arenas to skip the manual release delay

local PVP_INSTANCE_TYPES = { pvp = true, arena = true }

-- Release on death if inside a PvP instance and no self-resurrect is available

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_DEAD")

eventFrame:SetScript("OnEvent", function()
    local _, instanceType = IsInInstance()
    if not PVP_INSTANCE_TYPES[instanceType] then return end

    local options = C_DeathInfo
        and C_DeathInfo.GetSelfResurrectOptions
        and C_DeathInfo.GetSelfResurrectOptions()

    if options and #options > 0 then return end

    RunNextFrame(function()
        if UnitIsDeadOrGhost("player") then
            RepopMe()
        end
    end)
end)
