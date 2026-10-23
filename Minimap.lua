---------------------------------------------------------
--  ConfuciusSay - Minimap button
--  Author: Dranged
---------------------------------------------------------
-- A LibDBIcon button (so minimap addons can collect it): click opens the settings.

local ADDON, CS = ...

local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
local DBI = LibStub and LibStub("LibDBIcon-1.0", true)

function CS.SetMinimapShown(on)
    CS.db.minimap.hide = not on
    if not DBI then return end
    if on then DBI:Show("ConfuciusSay") else DBI:Hide("ConfuciusSay") end
end

CS.OnReady(function()
    if not (LDB and DBI) then return end
    local launcher = LDB:NewDataObject("ConfuciusSay", {
        type = "launcher",
        text = "ConfuciusSay",
        icon = CS.ICON,
        OnClick = function() CS.ToggleConfig() end,
        OnTooltipShow = function(tt)
            tt:AddLine("ConfuciusSay")
            tt:AddLine("|cffffd100Click|r to open the settings", 1, 1, 1)
            tt:AddLine("|cffffd100Drag|r to move this button", 1, 1, 1)
        end,
    })
    DBI:Register("ConfuciusSay", launcher, CS.db.minimap)
end)
