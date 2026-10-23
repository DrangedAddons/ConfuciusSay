---------------------------------------------------------
--  ConfuciusSay - Widgets
--  Author: Dranged
---------------------------------------------------------
-- Small UI pieces built by hand (same look as CastCount), so nothing depends on old Classic
-- templates that Forever's client may not have.

local ADDON, CS = ...
local UI = CS.UI
local WHITE = "Interface\\Buttons\\WHITE8X8"
UI.WHITE = WHITE

---------------------------------------------------------
--  SECTION: Refresh registry
---------------------------------------------------------
-- Anything with a :Refresh() that shows a setting; RefreshAll re-reads them all.
local tracked = {}
function UI.Track(obj) tracked[#tracked + 1] = obj; return obj end
function UI.RefreshAll()
    for _, obj in ipairs(tracked) do
        if obj.Refresh then obj:Refresh() end
    end
end

---------------------------------------------------------
--  SECTION: Basics
---------------------------------------------------------
function UI.Backdrop(f, r, g, b, a, br, bg, bb, ba)
    f:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    f:SetBackdropColor(r or 0.06, g or 0.06, b or 0.07, a or 0.95)
    f:SetBackdropBorderColor(br or 0.25, bg or 0.25, bb or 0.28, ba or 1)
end

function UI.Text(parent, text, font, layer)
    local fs = parent:CreateFontString(nil, layer or "ARTWORK", font or "GameFontHighlight")
    fs:SetText(text or "")
    fs:SetJustifyH("LEFT")
    return fs
end

function UI.Button(parent, text, w, h, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w or 100, h or 22)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    return b
end

function UI.Check(parent, label, get, set)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    if cb.Text then cb.Text:SetText("") end
    if cb.text then cb.text:SetText("") end
    cb.label = UI.Text(cb, label)
    cb.label:SetPoint("LEFT", cb, "RIGHT", 2, 1)
    cb:SetScript("OnClick", function(self)
        set(self:GetChecked() and true or false)
        UI.RefreshAll()
    end)
    function cb:Refresh() self:SetChecked(get() and true or false) end
    function cb:SetActive(on)
        self:SetEnabled(on)
        local v = on and 1 or 0.5
        self.label:SetTextColor(v, v, v)
    end
    return UI.Track(cb)
end

-- Text box. kind "number" saves tonumber(text) (ignored if it isn't one); otherwise the text,
-- empty only with e.allowEmpty. Saves on Enter and on focus lost; Escape puts the old value back.
function UI.Edit(parent, width, maxLetters, get, set, kind)
    local e = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    e:SetSize(width, 20)
    e:SetAutoFocus(false)
    e:SetMaxLetters(maxLetters or 60)
    local function Save()
        local text = e:GetText()
        if kind == "number" then
            local v = tonumber(text)
            if v then set(math.max(0, v)) end
        elseif text ~= "" or e.allowEmpty then
            set(text)
        end
        e:Refresh()
    end
    e:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    e:SetScript("OnEditFocusLost", function(self)
        if self.cancelled then
            self.cancelled = nil
            self:Refresh()
        else
            Save()
        end
    end)
    e:SetScript("OnEscapePressed", function(self) self.cancelled = true; self:ClearFocus() end)
    function e:Refresh()
        if not self:HasFocus() then self:SetText(tostring(get() or "")) self:SetCursorPosition(0) end
    end
    function e:SetActive(on)
        self:SetEnabled(on)
        self:SetAlpha(on and 1 or 0.5)
    end
    return UI.Track(e)
end
