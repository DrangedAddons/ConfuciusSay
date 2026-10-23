---------------------------------------------------------
--  ConfuciusSay - Config window
--  Author: Dranged
---------------------------------------------------------
-- /csay opens it. Tabs: Sayings (the list: on/off, add, edit, remove), Triggers (keywords and
-- chats), General.

local ADDON, CS = ...
local UI = CS.UI

local W, H = 700, 560
local win
local pages, tabButtons = {}, {}
local current = "sayings"

local TABS = {
    { key = "sayings",  label = "Sayings" },
    { key = "triggers", label = "Triggers" },
    { key = "general",  label = "General" },
}

local function Version()
    local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    return get and get(ADDON, "Version") or ""
end

local function Heading(page, text, x, y)
    local fs = UI.Text(page, text, "GameFontNormal")
    fs:SetPoint("TOPLEFT", x, y)
    return fs
end

local function Note(page, text, x, y, w)
    local fs = UI.Text(page, text, "GameFontHighlightSmall")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetWidth(w or 640)
    fs:SetTextColor(0.75, 0.75, 0.75)
    return fs
end

local function Refresher(fn) return UI.Track({ Refresh = fn }) end

-- Small toggle button used for the list filters.
local function FilterButton(parent, label, w, onClick)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(w, 22)
    UI.Backdrop(b, 0.1, 0.1, 0.11, 1)
    b.text = UI.Text(b, label, "GameFontNormalSmall")
    b.text:SetPoint("CENTER")
    b.text:SetJustifyH("CENTER")
    b:SetScript("OnClick", onClick)
    function b:SetSelectedLook(on)
        if on then
            self:SetBackdropColor(0.22, 0.18, 0.04, 1)
            self:SetBackdropBorderColor(1, 0.82, 0, 1)
            self.text:SetTextColor(1, 0.82, 0)
        else
            self:SetBackdropColor(0.1, 0.1, 0.11, 1)
            self:SetBackdropBorderColor(0.25, 0.25, 0.28, 1)
            self.text:SetTextColor(0.85, 0.85, 0.85)
        end
    end
    return b
end

local builders = {}

---------------------------------------------------------
--  SECTION: Sayings tab
---------------------------------------------------------
local FILTERS = {
    { key = "all",      label = "All",      test = function() return true end },
    { key = "on",       label = "Active",   test = function(s) return s.on end },
    { key = "off",      label = "Inactive", test = function(s) return not s.on end },
    { key = "rude",     label = "Rude",     test = function(s) return s.rude end },
    { key = "clean",    label = "Clean",    test = function(s) return not s.rude end },
    { key = "mine",     label = "Added by me", test = function(s) return not s.id end },
}

StaticPopupDialogs["CONFUCIUSSAY_REMOVE"] = {
    text = "Remove this saying?\n\n%s",
    button1 = YES or "Yes",
    button2 = NO or "No",
    OnAccept = function(_, data) if data and data.fn then data.fn() end end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

function builders.sayings(p)
    local PW = 672
    local ROWS, ROWH = 9, 34
    local filter, search = "all", ""
    local shown, offset, selected = {}, 0, nil
    local filterButtons = {}
    local UpdateList

    -- Filters along the top, search box on the right.
    local x = 0
    for _, fl in ipairs(FILTERS) do
        local w = (fl.key == "mine") and 86 or 64
        local b = FilterButton(p, fl.label, w, function()
            filter = fl.key
            offset = 0
            UpdateList()
        end)
        b:SetPoint("TOPLEFT", x, 0)
        filterButtons[fl.key] = b
        x = x + w + 4
    end

    local searchBox = CreateFrame("EditBox", nil, p, "InputBoxTemplate")
    searchBox:SetSize(150, 20)
    searchBox:SetPoint("TOPRIGHT", -4, -1)
    searchBox:SetAutoFocus(false)
    searchBox:SetMaxLetters(40)
    local searchHint = UI.Text(searchBox, "Search", "GameFontDisableSmall")
    searchHint:SetPoint("LEFT", 2, 0)
    searchBox:SetScript("OnTextChanged", function(self)
        searchHint:SetShown(self:GetText() == "")
        if not self:HasFocus() then return end
        search = strtrim(self:GetText()):lower()
        offset = 0
        UpdateList()
    end)
    searchBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    searchBox:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        search = ""
        self:ClearFocus()
        UpdateList()
    end)

    -- The list.
    local list = CreateFrame("Frame", nil, p, "BackdropTemplate")
    list:SetSize(PW, ROWS * ROWH + 4)
    list:SetPoint("TOPLEFT", 0, -30)
    UI.Backdrop(list, 0.03, 0.03, 0.035, 0.95)

    local count = UI.Text(p, "", "GameFontHighlightSmall")
    count:SetPoint("TOPLEFT", list, "BOTTOMLEFT", 2, -4)
    count:SetTextColor(0.75, 0.75, 0.75)

    local editor, saveBtn, removeBtn, rudeCheck

    local function Select(s)
        selected = s
        editor:SetText(s and s.text or "")
        editor:SetCursorPosition(0)
        UpdateList()
    end

    local rows = {}
    for i = 1, ROWS do
        local r = CreateFrame("Button", nil, list)
        r:SetHeight(ROWH)
        r:SetPoint("TOPLEFT", 2, -2 - (i - 1) * ROWH)
        r:SetPoint("RIGHT", list, "RIGHT", -10, 0)
        r.sel = r:CreateTexture(nil, "BACKGROUND")
        r.sel:SetAllPoints()
        r.sel:SetColorTexture(1, 0.82, 0, 0.2)
        r.sel:Hide()
        r:SetHighlightTexture(UI.WHITE)
        local hl = r:GetHighlightTexture()
        hl:SetVertexColor(1, 1, 1)
        hl:SetAlpha(0.06)

        r.check = CreateFrame("CheckButton", nil, r, "UICheckButtonTemplate")
        r.check:SetSize(24, 24)
        r.check:SetPoint("LEFT", 2, 0)
        if r.check.Text then r.check.Text:SetText("") end
        r.check:SetScript("OnClick", function(self)
            if r.item then r.item.on = self:GetChecked() and true or false end
            UpdateList()
        end)
        r.check:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:AddLine("Active: can be sent as a reply", 1, 1, 1)
            GameTooltip:Show()
        end)
        r.check:SetScript("OnLeave", GameTooltip_Hide)

        r.tag = UI.Text(r, "", "GameFontHighlightSmall")
        r.tag:SetPoint("RIGHT", -6, 0)
        r.tag:SetJustifyH("RIGHT")
        r.tag:SetWidth(70)

        r.text = UI.Text(r, "")
        r.text:SetPoint("LEFT", r.check, "RIGHT", 4, 0)
        r.text:SetPoint("RIGHT", r.tag, "LEFT", -6, 0)
        r.text:SetHeight(ROWH - 2)
        r.text:SetJustifyV("MIDDLE")
        r.text:SetWordWrap(true)

        r:SetScript("OnClick", function(self)
            if self.item then Select(self.item ~= selected and self.item or nil) end
        end)
        rows[i] = r
    end

    local track = CreateFrame("Frame", nil, list)
    track:SetPoint("TOPRIGHT", -2, -2)
    track:SetPoint("BOTTOMRIGHT", -2, 2)
    track:SetWidth(6)
    local tbg = track:CreateTexture(nil, "BACKGROUND")
    tbg:SetAllPoints()
    tbg:SetColorTexture(0.12, 0.12, 0.12, 1)
    local thumb = track:CreateTexture(nil, "OVERLAY")
    thumb:SetColorTexture(0.55, 0.55, 0.55, 1)
    thumb:SetWidth(6)

    local function MaxOffset() return math.max(0, #shown - ROWS) end

    local empty = UI.Text(list, "", "GameFontDisable")
    empty:SetPoint("CENTER")

    function UpdateList()
        local test = FILTERS[1].test
        for _, fl in ipairs(FILTERS) do
            if fl.key == filter then test = fl.test end
            filterButtons[fl.key]:SetSelectedLook(fl.key == filter)
        end
        shown = {}
        local selectedStillThere = false
        for _, s in ipairs(CS.db.sayings) do
            if s == selected then selectedStillThere = true end
            if test(s) and (search == "" or s.text:lower():find(search, 1, true)) then
                shown[#shown + 1] = s
            end
        end
        if not selectedStillThere then selected = nil end
        offset = math.max(0, math.min(MaxOffset(), offset))

        for i, r in ipairs(rows) do
            local s = shown[offset + i]
            r.item = s
            if s then
                r.check:SetChecked(s.on)
                r.text:SetText(s.text)
                local v = s.on and 1 or 0.45
                r.text:SetTextColor(v, v, v)
                if s.rude then
                    r.tag:SetText("|cffff6060rude|r")
                elseif not s.id then
                    r.tag:SetText("|cff66bbffadded|r")
                else
                    r.tag:SetText("")
                end
                r.sel:SetShown(s == selected)
                r:Show()
            else
                r:Hide()
            end
        end
        empty:SetText(#shown == 0 and "No sayings here." or "")

        local max = MaxOffset()
        track:SetShown(max > 0)
        if max > 0 then
            local th = track:GetHeight()
            local h = math.max(10, th * ROWS / #shown)
            thumb:SetHeight(h)
            thumb:ClearAllPoints()
            thumb:SetPoint("TOP", track, "TOP", 0, -(th - h) * offset / max)
        end

        local on, total = CS.CountActive()
        count:SetText(string.format("%d of %d sayings active%s", on, total,
            (#shown ~= total) and string.format("  ·  %d shown", #shown) or ""))

        saveBtn:SetEnabled(selected ~= nil)
        removeBtn:SetEnabled(selected ~= nil)
        rudeCheck:SetActive(selected ~= nil)
        rudeCheck:SetChecked(selected and selected.rude or false)
    end

    local function ScrollTo(o)
        offset = math.max(0, math.min(MaxOffset(), math.floor(o + 0.5)))
        UpdateList()
    end
    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(_, delta) ScrollTo(offset - delta * 3) end)
    local function FromCursor()
        local _, y = GetCursorPosition()
        y = y / track:GetEffectiveScale()
        local top, h = track:GetTop(), track:GetHeight()
        if top and h and h > 0 then ScrollTo((top - y) / h * MaxOffset()) end
    end
    track:EnableMouse(true)
    track:SetScript("OnMouseDown", function(self) FromCursor(); self:SetScript("OnUpdate", FromCursor) end)
    track:SetScript("OnMouseUp", function(self) self:SetScript("OnUpdate", nil) end)

    -- Editor: type a new saying and Add, or click one in the list to edit or remove it.
    local edY = -(30 + ROWS * ROWH + 4 + 26)
    Heading(p, "Saying", 0, edY)
    local prefix = UI.Text(p, "", "GameFontDisable")
    prefix:SetPoint("TOPLEFT", 0, edY - 22)
    Refresher(function() prefix:SetText(CS.db.prefix or "") end)

    editor = CreateFrame("EditBox", nil, p, "InputBoxTemplate")
    editor:SetHeight(20)
    editor:SetPoint("LEFT", prefix, "RIGHT", 8, 0)
    editor:SetPoint("RIGHT", p, "RIGHT", -4, 0)
    editor:SetAutoFocus(false)
    editor:SetMaxLetters(230)
    editor:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    local function EditorText()
        return strtrim(editor:GetText() or "")
    end

    local addBtn = UI.Button(p, "Add new", 110, 22, function()
        local text = EditorText()
        if text == "" then return end
        local s = CS.AddSaying(text)
        editor:ClearFocus()
        filter, search = "all", ""
        searchBox:SetText("")
        selected = s
        UpdateList()
        ScrollTo(#shown)
    end)
    addBtn:SetPoint("TOPLEFT", 0, edY - 48)

    saveBtn = UI.Button(p, "Save changes", 110, 22, function()
        local text = EditorText()
        if not selected or text == "" then return end
        selected.text = text
        editor:ClearFocus()
        UpdateList()
    end)
    saveBtn:SetPoint("LEFT", addBtn, "RIGHT", 6, 0)

    removeBtn = UI.Button(p, "Remove", 110, 22, function()
        if not selected then return end
        local s = selected
        StaticPopup_Show("CONFUCIUSSAY_REMOVE", s.text, nil, { fn = function()
            CS.RemoveSaying(s)
            Select(nil)
        end })
    end)
    removeBtn:SetPoint("LEFT", saveBtn, "RIGHT", 6, 0)

    rudeCheck = UI.Check(p, "Rude", function() return selected and selected.rude end, function(v)
        if selected then selected.rude = v end
        UpdateList()
    end)
    rudeCheck:SetPoint("LEFT", removeBtn, "RIGHT", 10, 0)

    editor:SetScript("OnEnterPressed", function(self)
        if selected then saveBtn:Click() else addBtn:Click() end
        self:ClearFocus()
    end)

    -- Bulk buttons along the bottom.
    local function SetAllShown(on)
        for _, s in ipairs(shown) do s.on = on end
        UpdateList()
    end
    local allOn = UI.Button(p, "Activate shown", 130, 22, function() SetAllShown(true) end)
    allOn:SetPoint("BOTTOMLEFT", 0, 0)
    local allOff = UI.Button(p, "Deactivate shown", 130, 22, function() SetAllShown(false) end)
    allOff:SetPoint("LEFT", allOn, "RIGHT", 6, 0)
    local restore = UI.Button(p, "Restore defaults", 130, 22, function()
        local n = CS.RestoreDefaults()
        CS.Print(n == 0 and "every default saying is already in the list."
            or string.format("put back %d default saying%s.", n, n == 1 and "" or "s"))
        UpdateList()
    end)
    restore:SetPoint("LEFT", allOff, "RIGHT", 6, 0)
    restore:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Restore defaults", 1, 1, 1)
        GameTooltip:AddLine("Puts back built-in sayings you removed. Your own sayings and on/off choices stay as they are.", nil, nil, nil, true)
        GameTooltip:Show()
    end)
    restore:SetScript("OnLeave", GameTooltip_Hide)
    local test = UI.Button(p, "Test", 80, 22, function()
        local s = CS.PickSaying()
        CS.Print(s and CS.Format(s) or "no active sayings.")
    end)
    test:SetPoint("BOTTOMRIGHT", -4, 0)
    test:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Prints a random active saying in your chat. Only you see it.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    test:SetScript("OnLeave", GameTooltip_Hide)

    Refresher(function() if p:IsShown() then UpdateList() end end)
    p:SetScript("OnShow", UpdateList)
end

---------------------------------------------------------
--  SECTION: Triggers tab
---------------------------------------------------------
function builders.triggers(p)
    Heading(p, "Default keywords", 0, 0)
    Note(p, "Separate them with commas. A message containing any of them, in any case, gets a reply. "
        .. "Each chat below can use these or its own.", 0, -18, 640)
    local kw = UI.Edit(p, 420, 200, function() return CS.db.keywords end, function(v) CS.db.keywords = v end)
    kw:SetPoint("TOPLEFT", 6, -48)

    local y = -88
    for _, chan in ipairs(CS.CHANNELS) do
        local key = chan.key
        local c = function() return CS.db.channels[key] end

        local box = CreateFrame("Frame", nil, p, "BackdropTemplate")
        box:SetPoint("TOPLEFT", 0, y)
        box:SetSize(672, 70)
        UI.Backdrop(box, 0.08, 0.08, 0.09, 0.9)

        local main = UI.Check(box, chan.chatType and ("Reply to " .. chan.label:lower()) or "Reply to whispers",
            function() return c().on end, function(v) c().on = v end)
        main:SetPoint("TOPLEFT", 8, -6)
        main.label:SetFontObject(GameFontNormal)

        local inChannel
        if chan.chatType then
            inChannel = UI.Check(box, "Post the reply in " .. chan.label:lower(),
                function() return c().replyInChannel end, function(v) c().replyInChannel = v end)
            inChannel:SetPoint("TOPLEFT", 300, -6)
            inChannel:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:AddLine("Checked: everyone in " .. chan.label:lower() .. " sees the reply.", 1, 1, 1, true)
                GameTooltip:AddLine("Unchecked: the reply is whispered to whoever said the keyword.", 1, 1, 1, true)
                GameTooltip:Show()
            end)
            inChannel:SetScript("OnLeave", GameTooltip_Hide)
        end

        local useDefault = UI.Check(box, "Use default keywords",
            function() return c().useDefault end, function(v) c().useDefault = v end)
        useDefault:SetPoint("TOPLEFT", 32, -36)

        local own = UI.Edit(box, 330, 200, function() return c().keywords end, function(v) c().keywords = v end)
        own.allowEmpty = true
        own:SetPoint("TOPLEFT", 300, -38)
        local ownHint = UI.Text(box, "Own keywords:", "GameFontHighlightSmall")
        ownHint:SetPoint("RIGHT", own, "LEFT", -10, 0)

        Refresher(function()
            local on = c().on
            if inChannel then inChannel:SetActive(on) end
            useDefault:SetActive(on)
            own:SetActive(on and not c().useDefault)
            local v = (on and not c().useDefault) and 1 or 0.5
            ownHint:SetTextColor(v, v, v)
        end)

        y = y - 78
    end

    Note(p, "Your own messages and other players' Confucius sayings never trigger a reply, so two players "
        .. "running ConfuciusSay can't set each other off.", 0, y - 6, 640)
end

---------------------------------------------------------
--  SECTION: General tab
---------------------------------------------------------
function builders.general(p)
    local enabled = UI.Check(p, "Reply when someone says a keyword", function() return CS.db.enabled end,
        function(v) CS.db.enabled = v end)
    enabled:SetPoint("TOPLEFT", 0, 0)
    enabled.label:SetFontObject(GameFontNormal)

    Heading(p, "Only on characters whose name contains", 0, -40)
    local name = UI.Edit(p, 160, 24, function() return CS.db.nameMatch end, function(v) CS.db.nameMatch = v end)
    name.allowEmpty = true
    name:SetPoint("TOPLEFT", 6, -60)
    local status = UI.Text(p, "", "GameFontHighlightSmall")
    status:SetPoint("LEFT", name, "RIGHT", 14, 0)
    Refresher(function()
        local here = CS.IsActiveHere()
        local on = here and CS.db.enabled
        status:SetText(string.format("%s: %s", CS.MyName(),
            on and "|cff33ff55replies are on|r"
            or (not here and "|cffff6060name doesn't match, no replies|r")
            or "|cffff6060replies are off|r"))
    end)
    Note(p, "Leave it empty to reply on every character.", 0, -84)

    Heading(p, "Replies start with", 0, -116)
    local prefix = UI.Edit(p, 200, 40, function() return CS.db.prefix end, function(v) CS.db.prefix = v end)
    prefix.allowEmpty = true
    prefix:SetPoint("TOPLEFT", 6, -136)
    local sample = UI.Text(p, "", "GameFontHighlightSmall")
    sample:SetPoint("TOPLEFT", 0, -162)
    sample:SetWidth(640)
    sample:SetTextColor(0.75, 0.75, 0.75)
    Refresher(function()
        local s = { text = "man who run behind bus get exhausted" }
        sample:SetText("Example: |cffff80ff" .. CS.Format(s) .. "|r")
    end)

    local function NumberRow(label, y, key, tip)
        local fs = Heading(p, label, 0, y)
        local e = UI.Edit(p, 50, 5, function() return CS.db[key] end, function(v) CS.db[key] = v end, "number")
        e:SetPoint("TOPLEFT", 330, y + 3)
        local n = Note(p, tip, 392, y, 270)
        return fs, e, n
    end
    NumberRow("Wait before replying (seconds)", -200, "delay", "So it doesn't look instant.")
    NumberRow("Same player again after (seconds)", -230, "playerCooldown", "Stops one player spamming replies out of you.")
    NumberRow("Guild/party/raid reply again after (seconds)", -260, "groupCooldown", "Only when the reply is posted in that chat.")

    local mm = UI.Check(p, "Show minimap button", function() return not CS.db.minimap.hide end,
        function(v) CS.SetMinimapShown(v) end)
    mm:SetPoint("TOPLEFT", 0, -300)

    Note(p, "/csay opens this window. /csay test prints a random saying that only you see. /csay on, /csay off.",
        0, -340, 640)
end

---------------------------------------------------------
--  SECTION: Window
---------------------------------------------------------
local function ShowTab(key)
    current = key
    for k, b in pairs(tabButtons) do b:SetSelectedLook(k == key) end
    for k, pg in pairs(pages) do pg:SetShown(k == key) end
    UI.RefreshAll()
end

local function TabButton(parent, label, onClick)
    local b = FilterButton(parent, label, 112, onClick)
    b:SetHeight(24)
    b.text:SetFontObject(GameFontNormal)
    return b
end

local function Build()
    win = CreateFrame("Frame", "ConfuciusSayConfig", UIParent, "BackdropTemplate")
    win:SetSize(W, H)
    win:SetPoint("TOP", UIParent, "TOP", 0, -60)
    win:SetFrameStrata("HIGH")
    win:SetToplevel(true)
    UI.Backdrop(win, 0.05, 0.05, 0.06, 0.97)
    win:EnableMouse(true)
    win:SetMovable(true)
    win:SetClampedToScreen(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", win.StartMoving)
    win:SetScript("OnDragStop", win.StopMovingOrSizing)
    tinsert(UISpecialFrames, "ConfuciusSayConfig")

    local icon = win:CreateTexture(nil, "ARTWORK")
    icon:SetSize(22, 22)
    icon:SetPoint("TOPLEFT", 12, -9)
    icon:SetTexture(CS.ICON)
    local title = UI.Text(win, "ConfuciusSay", "GameFontNormalLarge")
    title:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    local ver = UI.Text(win, "v" .. Version(), "GameFontDisableSmall")
    ver:SetPoint("LEFT", title, "RIGHT", 6, -1)
    local close = CreateFrame("Button", nil, win, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)

    for i, tab in ipairs(TABS) do
        local b = TabButton(win, tab.label, function() ShowTab(tab.key) end)
        b:SetPoint("TOPLEFT", 14 + (i - 1) * 118, -40)
        tabButtons[tab.key] = b

        local page = CreateFrame("Frame", nil, win)
        page:SetPoint("TOPLEFT", 14, -78)
        page:SetPoint("BOTTOMRIGHT", -14, 14)
        page:Hide()
        pages[tab.key] = page
        builders[tab.key](page)
    end

    win:SetScript("OnShow", function() ShowTab(current) end)
end

function CS.ShowConfig()
    if not CS.db then return end
    if not win then Build() end
    if win:IsShown() then ShowTab(current) else win:Show() end
end

function CS.ToggleConfig()
    if win and win:IsShown() then win:Hide() else CS.ShowConfig() end
end

-- The addon list button (top of the minimap) opens the window too.
function ConfuciusSay_OnCompartmentClick()
    CS.ToggleConfig()
end

---------------------------------------------------------
--  SECTION: Game settings entry
---------------------------------------------------------
CS.OnReady(function()
    if not (Settings and Settings.RegisterCanvasLayoutCategory) then return end
    local panel = CreateFrame("Frame")
    panel.name = "ConfuciusSay"
    local title = UI.Text(panel, "ConfuciusSay", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    local text = UI.Text(panel, "ConfuciusSay has its own settings window. You can also open it with /csay.")
    text:SetPoint("TOPLEFT", 16, -46)
    local open = UI.Button(panel, "Open ConfuciusSay", 160, 24, function()
        if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
        CS.ShowConfig()
    end)
    open:SetPoint("TOPLEFT", 16, -74)
    local category = Settings.RegisterCanvasLayoutCategory(panel, "ConfuciusSay")
    Settings.RegisterAddOnCategory(category)
end)
