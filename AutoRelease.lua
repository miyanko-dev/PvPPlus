local pvpInstanceTypes = { pvp = true, arena = true }
local pvpReleaseFrame  = CreateFrame("Frame")

pvpReleaseFrame:RegisterEvent("PLAYER_DEAD")
pvpReleaseFrame:SetScript("OnEvent", function()
    local _, instanceType = IsInInstance()
    if not pvpInstanceTypes[instanceType] then return end

    local selfResOptions = C_DeathInfo
        and C_DeathInfo.GetSelfResurrectOptions
        and C_DeathInfo.GetSelfResurrectOptions()
    if selfResOptions and #selfResOptions > 0 then return end

    RunNextFrame(function()
        if UnitIsDeadOrGhost("player") then
            RepopMe()
        end
    end)
end)
