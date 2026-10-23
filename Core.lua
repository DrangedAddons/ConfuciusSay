---------------------------------------------------------
--  ConfuciusSay - Core
--  Author: Dranged
---------------------------------------------------------
-- On a character whose name contains "confucius", anyone who whispers you a trigger word gets a
-- random Confucius say whispered back. Guild, party and raid chat can trigger it too, each with
-- the default keywords or its own.

local ADDON, CS = ...
CS.UI = {}
-- Wowhead icon 2056011 (ui_chat), scaled up to 64x64 by tools/make_icon.py
CS.ICON = "Interface\\AddOns\\ConfuciusSay\\icon"

---------------------------------------------------------
--  SECTION: Settings
---------------------------------------------------------
-- Channels that can trigger a reply. replyInChannel: answer in that chat (true) or whisper the
-- sender (false). Whispers always answer by whisper.
CS.CHANNELS = {
    { key = "whisper", label = "Whispers",   events = { "CHAT_MSG_WHISPER" } },
    { key = "guild",   label = "Guild chat", events = { "CHAT_MSG_GUILD" }, chatType = "GUILD" },
    { key = "party",   label = "Party chat", events = { "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER" }, chatType = "PARTY" },
    { key = "raid",    label = "Raid chat",  events = { "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER" }, chatType = "RAID" },
}

local DEFAULTS = {
    enabled = true,
    nameMatch = "confucius",
    prefix = "Confucius say, ",
    keywords = "confucius",
    delay = 1.5,            -- seconds before replying
    playerCooldown = 10,    -- seconds before the same player gets another reply
    groupCooldown = 30,     -- seconds between replies posted in guild/party/raid chat
    channels = {
        whisper = { on = true,  useDefault = true, keywords = "", replyInChannel = false },
        guild   = { on = false, useDefault = true, keywords = "", replyInChannel = true },
        party   = { on = false, useDefault = true, keywords = "", replyInChannel = true },
        raid    = { on = false, useDefault = true, keywords = "", replyInChannel = true },
    },
    minimap = { hide = false },
}

local function Fill(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            Fill(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

function CS.Print(msg)
    print("|cffffd100ConfuciusSay|r: " .. msg)
end

local readyFns = {}
function CS.OnReady(fn) readyFns[#readyFns + 1] = fn end

---------------------------------------------------------
--  SECTION: Sayings list
---------------------------------------------------------
-- db.sayings: { id, text, on, rude }. db.known[id]: defaults already added once, so a removed
-- default doesn't come back on the next login.

local function AddMissingDefaults(all)
    local have = {}
    for _, s in ipairs(CS.db.sayings) do
        if s.id then have[s.id] = true end
    end
    local added = 0
    for _, d in ipairs(CS.DEFAULT_SAYINGS) do
        local id = d[1]
        if not have[id] and (all or not CS.db.known[id]) then
            table.insert(CS.db.sayings, { id = id, text = d[2], on = true, rude = d[3] or false })
            added = added + 1
        end
        CS.db.known[id] = true
    end
    return added
end

-- Puts back every default that's been removed. Returns how many.
function CS.RestoreDefaults()
    return AddMissingDefaults(true)
end

function CS.AddSaying(text)
    local s = { text = text, on = true, rude = false }
    table.insert(CS.db.sayings, s)
    return s
end

function CS.RemoveSaying(s)
    for i, t in ipairs(CS.db.sayings) do
        if t == s then
            table.remove(CS.db.sayings, i)
            s.removed = true
            return
        end
    end
end

function CS.CountActive()
    local n = 0
    for _, s in ipairs(CS.db.sayings) do
        if s.on then n = n + 1 end
    end
    return n, #CS.db.sayings
end

-- A shuffled deck of the active sayings, so nobody hears the same one twice until the whole list
-- has gone round. Sayings switched off or removed since the shuffle are skipped.
local deck, last = {}, nil

local function Shuffle()
    deck = {}
    for _, s in ipairs(CS.db.sayings) do
        if s.on then deck[#deck + 1] = s end
    end
    for i = #deck, 2, -1 do
        local j = math.random(i)
        deck[i], deck[j] = deck[j], deck[i]
    end
    -- the next draw comes off the end; don't start the new round with the last one sent
    if #deck > 1 and deck[#deck] == last then deck[1], deck[#deck] = deck[#deck], deck[1] end
end

function CS.PickSaying()
    for _ = 1, 2 do
        while #deck > 0 do
            local s = table.remove(deck)
            if s.on and not s.removed then
                last = s
                return s
            end
        end
        Shuffle()
    end
end

function CS.Format(s)
    local prefix = CS.db.prefix or ""
    local text = s.text
    if prefix == "" then text = text:gsub("^%l", string.upper) end
    text = prefix .. text
    if #text > 255 then text = text:sub(1, 255) end
    return text
end

---------------------------------------------------------
--  SECTION: Triggers
---------------------------------------------------------

function CS.ParseKeywords(str)
    local list = {}
    for word in (str or ""):gmatch("[^,]+") do
        word = strtrim(word):lower()
        if word ~= "" then list[#list + 1] = word end
    end
    return list
end

function CS.KeywordsFor(key)
    local c = CS.db.channels[key]
    if c.useDefault then return CS.ParseKeywords(CS.db.keywords) end
    return CS.ParseKeywords(c.keywords)
end

function CS.MyName()
    return UnitName("player") or ""
end

-- Is this a Confucius character? An empty name filter means every character.
function CS.IsActiveHere()
    local match = strtrim(CS.db.nameMatch or ""):lower()
    if match == "" then return true end
    return CS.MyName():lower():find(match, 1, true) ~= nil
end

local function IsSecret(v)
    return issecretvalue and issecretvalue(v)
end

local function IsMe(sender)
    local name = Ambiguate and Ambiguate(sender, "none") or sender:match("^[^-]+")
    return name == CS.MyName()
end

-- Another ConfuciusSay (or our own echo) posting a saying shouldn't set off a reply, or two
-- players running it in the same guild would answer each other forever.
local function IsASaying(lower)
    for _, s in ipairs(CS.db.sayings) do
        if lower:find(s.text:lower(), 1, true) then return true end
    end
    return false
end

function CS.Send(text, chatType, target)
    local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
    local ok, err = pcall(send, text, chatType, nil, target)
    if not ok then CS.Print("couldn't send the reply: " .. tostring(err)) end
end

local lastByPlayer, lastInChannel = {}, {}

local function OnChat(chan, msg, sender)
    local db = CS.db
    if not db.enabled then return end
    local c = db.channels[chan.key]
    if not c.on or not CS.IsActiveHere() then return end
    -- Forever can hide chat text from addons (secret values), e.g. in encounters
    if IsSecret(msg) or IsSecret(sender) then return end
    if type(msg) ~= "string" or type(sender) ~= "string" or sender == "" then return end
    if IsMe(sender) then return end

    local lower = msg:lower()
    local hit = false
    for _, word in ipairs(CS.KeywordsFor(chan.key)) do
        if lower:find(word, 1, true) then hit = true break end
    end
    if not hit or IsASaying(lower) then return end

    local now = GetTime()
    local who = sender:lower()
    if lastByPlayer[who] and now - lastByPlayer[who] < (db.playerCooldown or 0) then return end
    local inChannel = chan.chatType and c.replyInChannel
    if inChannel then
        if lastInChannel[chan.key] and now - lastInChannel[chan.key] < (db.groupCooldown or 0) then return end
        lastInChannel[chan.key] = now
    end
    lastByPlayer[who] = now

    local s = CS.PickSaying()
    if not s then return end
    local text = CS.Format(s)
    local chatType, target = "WHISPER", sender
    if inChannel then chatType, target = chan.chatType, nil end
    C_Timer.After(math.max(0, db.delay or 0), function() CS.Send(text, chatType, target) end)
end

---------------------------------------------------------
--  SECTION: Events
---------------------------------------------------------
local f = CreateFrame("Frame")
local byEvent = {}

local function SafeRegister(event)
    if C_EventUtils and C_EventUtils.IsEventValid and not C_EventUtils.IsEventValid(event) then return false end
    return pcall(f.RegisterEvent, f, event)
end

f:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        if ... ~= ADDON then return end
        ConfuciusSayDB = ConfuciusSayDB or {}
        CS.db = ConfuciusSayDB
        Fill(CS.db, DEFAULTS)
        CS.db.sayings = CS.db.sayings or {}
        CS.db.known = CS.db.known or {}
        AddMissingDefaults(false)
        f:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        for _, fn in ipairs(readyFns) do
            local ok, err = pcall(fn)
            if not ok then CS.Print("error: " .. tostring(err)) end
        end
    else
        local chan = byEvent[event]
        if chan and CS.db then OnChat(chan, ...) end
    end
end)

f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
for _, chan in ipairs(CS.CHANNELS) do
    for _, event in ipairs(chan.events) do
        if SafeRegister(event) then byEvent[event] = chan end
    end
end

---------------------------------------------------------
--  SECTION: Slash commands
---------------------------------------------------------
SLASH_CONFUCIUSSAY1 = "/csay"
SLASH_CONFUCIUSSAY2 = "/confuciussay"
SlashCmdList.CONFUCIUSSAY = function(arg)
    arg = strtrim(arg or ""):lower()
    if arg == "test" then
        local s = CS.PickSaying()
        CS.Print(s and CS.Format(s) or "no active sayings.")
    elseif arg == "on" or arg == "off" then
        CS.db.enabled = (arg == "on")
        CS.Print(CS.db.enabled and "replies on." or "replies off.")
        if CS.UI.RefreshAll then CS.UI.RefreshAll() end
    elseif arg == "" then
        CS.ToggleConfig()
    else
        CS.Print("/csay opens the settings. /csay test prints a random saying (only you see it). /csay on | off.")
    end
end
