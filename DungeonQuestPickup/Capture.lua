-- Dev helpers for filling Data/Forever.lua by hand (only active with /dqp dev):
--   * captures unknown Forever / dungeon quests when an NPC offers or you accept them
--   * /dqp here prints your position as a ready-to-paste data line
--   * /dqp api reports which APIs this client exposes
local _, ns = ...

local Capture = {}
ns.Capture = Capture

local FOREVER_ID_FLOOR = 90000
local DUNGEON_TAG = Enum.QuestTag and Enum.QuestTag.Dungeon or 81

local function PlayerPosition()
    local mapID = C_Map.GetBestMapForUnit("player")
    if not mapID then return nil end
    local pos = C_Map.GetPlayerMapPosition(mapID, "player")
    if not pos then return mapID end
    local x, y = pos:GetXY()
    return mapID, x * 100, y * 100
end

local function Store()
    ns.db.captured = ns.db.captured or {}
    return ns.db.captured
end

local function IsDungeonTagged(questID)
    if not C_QuestLog.GetQuestTagInfo then return false end
    local info = C_QuestLog.GetQuestTagInfo(questID)
    return info and info.tagID == DUNGEON_TAG
end

local events = CreateFrame("Frame")
events:RegisterEvent("QUEST_DETAIL")
events:RegisterEvent("QUEST_ACCEPTED")
events:SetScript("OnEvent", function(_, event, arg1, arg2)
    if not ns.db or not ns.db.devMode then return end
    if event == "QUEST_DETAIL" then
        local questID = GetQuestID and GetQuestID()
        if not questID or questID == 0 or ns.Data.Quests[questID] then return end
        if questID < FOREVER_ID_FLOOR and not IsDungeonTagged(questID) then return end
        local mapID, x, y = PlayerPosition()
        local entry = Store()[questID] or {}
        entry.name = GetTitleText and GetTitleText() or entry.name
        entry.npc = UnitName("questnpc") or UnitName("npc") or entry.npc
        entry.map, entry.x, entry.y = mapID, x, y
        entry.faction = UnitFactionGroup("player")
        entry.playerLevel = UnitLevel("player")
        Store()[questID] = entry
        ns.Print(("captured %s (%d)"):format(entry.name or "?", questID))
    elseif event == "QUEST_ACCEPTED" then
        local questID = arg2 or arg1
        if not questID or ns.Data.Quests[questID] then return end
        local entry = Store()[questID]
        if not entry and questID < FOREVER_ID_FLOOR and not IsDungeonTagged(questID) then return end
        entry = entry or {}
        local logIndex = C_QuestLog.GetLogIndexForQuestID(questID)
        local info = logIndex and C_QuestLog.GetInfo(logIndex)
        if info then
            entry.name = entry.name or info.title
            entry.lvl = info.level
        end
        if C_QuestLog.IsPushableQuest then
            entry.share = C_QuestLog.IsPushableQuest(questID)
        end
        entry.dungeonTag = IsDungeonTagged(questID)
        Store()[questID] = entry
    end
end)

function Capture.PrintHere()
    local mapID, x, y = PlayerPosition()
    if not mapID then
        ns.Print("no map position here")
        return
    end
    local info = C_Map.GetMapInfo(mapID)
    if x then
        ns.Print(("%s: map = %d, x = %.2f, y = %.2f"):format(info and info.name or "?", mapID, x, y))
    else
        ns.Print(("%s: map = %d (position hidden here)"):format(info and info.name or "?", mapID))
    end
end

function Capture.PrintCaptured()
    local list = ns.db.captured or {}
    local any = false
    for id, e in pairs(list) do
        any = true
        local where = e.map and e.x and (", map = %d, x = %.2f, y = %.2f"):format(e.map, e.x, e.y) or ""
        print(('Q[%d] = { name = "%s", d = "TODO", lvl = %s, faction = "%s", share = %s, start = { npc = "%s"%s } }'):format(
            id, e.name or "?", tostring(e.lvl or "nil"), (e.faction or "?"):sub(1, 1),
            tostring(e.share == true), e.npc or "?", where))
    end
    if not any then ns.Print("nothing captured yet - talk to quest givers for Forever dungeon quests") end
end

local API_CHECKS = {
    { "C_QuestLog.IsQuestFlaggedCompleted", function() return C_QuestLog.IsQuestFlaggedCompleted end },
    { "C_QuestLog.IsOnQuest", function() return C_QuestLog.IsOnQuest end },
    { "C_QuestLog.GetLogIndexForQuestID", function() return C_QuestLog.GetLogIndexForQuestID end },
    { "C_QuestLog.GetInfo", function() return C_QuestLog.GetInfo end },
    { "C_QuestLog.IsPushableQuest", function() return C_QuestLog.IsPushableQuest end },
    { "C_QuestLog.GetQuestTagInfo", function() return C_QuestLog.GetQuestTagInfo end },
    { "C_Map.GetMapRectOnMap", function() return C_Map.GetMapRectOnMap end },
    { "C_Map.GetPlayerMapPosition", function() return C_Map.GetPlayerMapPosition end },
    { "C_Map.SetUserWaypoint", function() return C_Map.SetUserWaypoint end },
    { "UiMapPoint", function() return UiMapPoint end },
    { "OpenWorldMap", function() return OpenWorldMap end },
    { "WorldMapFrame:AddDataProvider", function() return WorldMapFrame and WorldMapFrame.AddDataProvider end },
    { "MapCanvasPinMixin", function() return MapCanvasPinMixin end },
    { "GetQuestID", function() return GetQuestID end },
    { "C_Texture.GetAtlasInfo", function() return C_Texture and C_Texture.GetAtlasInfo end },
}

function Capture.ProbeApi()
    for _, check in ipairs(API_CHECKS) do
        local ok, value = pcall(check[2])
        local present = ok and value ~= nil
        print(("  %s %s"):format(present and "|cff40ff40OK|r" or "|cffff4040MISSING|r", check[1]))
    end
    local p = ns.Engine.player
    print(("  player: %s, race %s (bit %s), level %d"):format(p.faction, tostring(p.raceID), tostring(p.raceBit), p.level))
    local mapID = C_Map.GetBestMapForUnit("player")
    local info = mapID and C_Map.GetMapInfo(mapID)
    print(("  map: %s (%s)"):format(tostring(mapID), info and info.name or "?"))
end
