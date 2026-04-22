-- Suppress honor/participation status bars inside PvP instances.

local PVP_INSTANCE_TYPES = { pvp = true, arena = true }

local function IsInPvPInstance()
    local _, instanceType = IsInInstance()
    return PVP_INSTANCE_TYPES[instanceType]
end

local function ApplyBarPatch()
    local origCanShow = StatusTrackingBarManager.CanShowBar
    StatusTrackingBarManager.CanShowBar = function(self, ...)
        if IsInPvPInstance() then return false end
        return origCanShow(self, ...)
    end
end

local function RefreshBars()
    RunNextFrame(function()
        if StatusTrackingBarManager then
            StatusTrackingBarManager:UpdateBarsShown()
        end
    end)
end

local evtFrame = CreateFrame("Frame")
evtFrame:RegisterEvent("PLAYER_LOGIN")
evtFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
evtFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        ApplyBarPatch()
        evtFrame:UnregisterEvent("PLAYER_LOGIN")
    elseif event == "PLAYER_ENTERING_WORLD" then
        RefreshBars()
    end
end)