-- Auto release spirit in battlegrounds and arenas to skip the manual release delay

local PVP_INSTANCE_TYPES = { pvp = true, arena = true }

-- Localize API upvalue to avoid repeated global chain traversal

local GetSelfResurrectOptions = C_DeathInfo and C_DeathInfo.GetSelfResurrectOptions

-- Release spirit on death, through instance and self-res checks, to skip the manual delay

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_DEAD")
eventFrame:SetScript("OnEvent", function()
    local _, instanceType = IsInInstance()
    if not PVP_INSTANCE_TYPES[instanceType] then return end

    local options = GetSelfResurrectOptions and GetSelfResurrectOptions()
    if options and #options > 0 then return end

    RunNextFrame(function()
        if UnitIsDeadOrGhost("player") then
            RepopMe()
        end
    end)
end)
