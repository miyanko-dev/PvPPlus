-- Hide PvP and prestige badges on Player and Target frames
local function SilenceBadge(texture)
    if not texture then return end
    texture:Hide()
    texture:SetAlpha(0)
    hooksecurefunc(texture, "Show", function(self) self:Hide() end)
end

local function HideAll()
    local playerOverlay = PlayerFrame
        and PlayerFrame.PlayerFrameContent
        and PlayerFrame.PlayerFrameContent.PlayerFrameContentContextual
    if playerOverlay then
        SilenceBadge(playerOverlay.PVPIcon)
        SilenceBadge(playerOverlay.PrestigePortrait)
        SilenceBadge(playerOverlay.PrestigeBadge)
    end

    local targetOverlay = TargetFrame
        and TargetFrame.TargetFrameContent
        and TargetFrame.TargetFrameContent.TargetFrameContentContextual
    if targetOverlay then
        SilenceBadge(targetOverlay.PvpIcon)
        SilenceBadge(targetOverlay.PrestigePortrait)
        SilenceBadge(targetOverlay.PrestigeBadge)
    end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self)
    HideAll()
    self:UnregisterAllEvents()
end)
