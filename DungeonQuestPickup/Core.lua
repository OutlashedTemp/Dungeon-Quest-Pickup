-- Dungeon Quest Pickup by CrownedFoxxy. Licensed under GPL-3.0, see LICENSE.
local ADDON, ns = ...

ns.Data = { Dungeons = {}, Quests = {} }

ns.COLORS = {
    ACTIVE    = { 0.25, 1.00, 0.25, "40ff40" }, -- green: in quest log
    AVAILABLE = { 1.00, 0.82, 0.00, "ffd100" }, -- yellow: can be picked up
    LEVEL     = { 1.00, 0.25, 0.25, "ff4040" }, -- red: level too low
    PREREQ    = { 0.30, 0.60, 1.00, "4d99ff" }, -- blue: prerequisite missing
}
ns.ACCENT = "F1592A"

local DEFAULTS = {
    minimap = { angle = 200, hide = false },
    frame = { point = "CENTER", x = 0, y = 0, w = 380, h = 520 },
    mapPins = true,
    setWaypoint = true,
    collapsed = {},
    devMode = false, -- data-entry helpers (quest capture, /dqp here, /dqp api)
}

local CHAR_DEFAULTS = {
    ignored = { quests = {}, dungeons = {} },
}

local function ApplyDefaults(target, defaults)
    for k, v in pairs(defaults) do
        if type(v) == "table" then
            target[k] = type(target[k]) == "table" and target[k] or {}
            ApplyDefaults(target[k], v)
        elseif target[k] == nil then
            target[k] = v
        end
    end
end

function ns.Print(msg)
    print("|cff" .. ns.ACCENT .. "DQP|r " .. tostring(msg))
end

-- Simple callback list: modules register to be told when quest state changes.
ns.listeners = {}
function ns.OnRefresh(fn)
    table.insert(ns.listeners, fn)
end

local pending = false
function ns.RequestRefresh()
    if pending then return end
    pending = true
    C_Timer.After(0.25, function()
        pending = false
        ns.Engine.Invalidate()
        for _, fn in ipairs(ns.listeners) do
            local ok, err = pcall(fn)
            if not ok then ns.Print("refresh error: " .. tostring(err)) end
        end
    end)
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_LEVEL_UP")
events:RegisterEvent("QUEST_ACCEPTED")
events:RegisterEvent("QUEST_REMOVED")
events:RegisterEvent("QUEST_TURNED_IN")
events:RegisterEvent("QUEST_LOG_UPDATE")

events:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON then return end
        DQP_DB = DQP_DB or {}
        DQP_CharDB = DQP_CharDB or {}
        ApplyDefaults(DQP_DB, DEFAULTS)
        ApplyDefaults(DQP_CharDB, CHAR_DEFAULTS)
        ns.db = DQP_DB
        ns.chardb = DQP_CharDB
        if ns.Minimap then ns.Minimap.Init() end
        if ns.Map then ns.Map.Init() end
        return
    end
    if event == "PLAYER_ENTERING_WORLD" then
        ns.Engine.InitPlayer()
        if ns.Engine.IsUntestedCharacter() and not ns.chardb.untestedNoticeShown then
            ns.chardb.untestedNoticeShown = true
            ns.Print("Horde and Skyborne characters haven't been tested yet - quest data or colors may be wrong. Please report issues.")
        end
    elseif event == "PLAYER_LEVEL_UP" then
        ns.Engine.InitPlayer(arg1)
    end
    ns.RequestRefresh()
end)

local function Help()
    ns.Print("commands:")
    print("  /dqp - toggle window")
    print("  /dqp pins - toggle world map pins")
    print("  /dqp minimap - toggle minimap button")
    print("  /dqp waypoint - toggle native waypoint on click")
    if ns.db.devMode then
        print("  dev: /dqp here, /dqp captured, /dqp api, /dqp dev (turn off)")
    end
end

local DEV_COMMANDS = {
    here = function() ns.Capture.PrintHere() end,
    captured = function() ns.Capture.PrintCaptured() end,
    api = function() ns.Capture.ProbeApi() end,
}

SLASH_DQP1 = "/dqp"
SlashCmdList.DQP = function(msg)
    local cmd = strtrim(msg or ""):lower()
    if cmd == "" then
        ns.UI.Toggle()
    elseif cmd == "pins" then
        ns.db.mapPins = not ns.db.mapPins
        ns.Print("map pins " .. (ns.db.mapPins and "on" or "off"))
        ns.RequestRefresh()
    elseif cmd == "minimap" then
        ns.db.minimap.hide = not ns.db.minimap.hide
        ns.Minimap.UpdateVisibility()
        ns.Print("minimap button " .. (ns.db.minimap.hide and "hidden" or "shown"))
    elseif cmd == "waypoint" then
        ns.db.setWaypoint = not ns.db.setWaypoint
        ns.Print("waypoint on click " .. (ns.db.setWaypoint and "on" or "off"))
    elseif cmd == "dev" then
        ns.db.devMode = not ns.db.devMode
        ns.Print("dev mode " .. (ns.db.devMode and "on" or "off"))
    elseif DEV_COMMANDS[cmd] and ns.db.devMode then
        DEV_COMMANDS[cmd]()
    else
        Help()
    end
end

function DQP_OnAddonCompartmentClick()
    ns.UI.Toggle()
end
