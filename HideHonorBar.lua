-- Hide all status tracking bars in PvP instances, by overriding CanShowBar, to suppress the honor bar

local PVP_INSTANCE_TYPES = { pvp = true, arena = true }

-- Check if the player is currently inside a PvP instance type

local function IsInPvPInstance()
    local _, instanceType = IsInInstance()
    return PVP_INSTANCE_TYPES[instanceType]
end

-- Override bar visibility and refresh on zone entry, to keep bars hidden in PvP instances

local evtFrame = CreateFrame("Frame")
evtFrame:RegisterEvent("PLAYER_LOGIN")
evtFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
evtFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        local origCanShow = StatusTrackingBarManager.CanShowBar
        StatusTrackingBarManager.CanShowBar = function(self, ...)
            if IsInPvPInstance() then return false end
            return origCanShow(self, ...)
        end
        evtFrame:UnregisterEvent("PLAYER_LOGIN")
    elseif event == "PLAYER_ENTERING_WORLD" then
        RunNextFrame(function()
            if StatusTrackingBarManager then
                StatusTrackingBarManager:UpdateBarsShown()
            end
        end)
    end
end)
