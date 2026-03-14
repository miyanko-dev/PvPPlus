-- Automatically release the player spirit in battlegrounds and arenas because waiting for the manual release button is inefficient

local playerVersusPlayerInstanceTypes = { pvp = true, arena = true }
local spiritReleaseFrame = CreateFrame("Frame")

-- Listen for the player dying event to trigger the release behavior because releasing requires the player to be dead

spiritReleaseFrame:RegisterEvent("PLAYER_DEAD")

spiritReleaseFrame:SetScript("OnEvent", function()
    local _, instanceType = IsInInstance()

    if not playerVersusPlayerInstanceTypes[instanceType] then return end

    local selfResurrectOptions = C_DeathInfo
        and C_DeathInfo.GetSelfResurrectOptions
        and C_DeathInfo.GetSelfResurrectOptions()

    if selfResurrectOptions and #selfResurrectOptions > 0 then return end

    RunNextFrame(function()
        if UnitIsDeadOrGhost("player") then
            RepopMe()
        end
    end)
end)
