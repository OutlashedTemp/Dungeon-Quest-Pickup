-- HAND-MAINTAINED: the 9 dungeons new in WoW Forever and their quests.
-- (Classic dungeons live in Classic.lua, which is generated - don't edit that one.)
--
-- Dungeon fields:
--   name, min, max          display name + level range
--   zone                    zone the entrance is in (display only)
--   entrance = { map, x, y } uiMapID + coords 0-100. Get them in-game with /dqt here
--
-- Quest fields (Q[questID] = { ... }):
--   name                    quest name
--   d                       dungeon key below. Leave nil for a prerequisite that is NOT a dungeon quest
--                           (it won't be listed, but is used for blue quests' map pins)
--   lvl                     quest level
--   min                     required level to pick up (falls back to the dungeon's min level)
--   faction                 "A", "H" or "B" (both)
--   pre = { id, ... }       ALL of these must be completed
--   preAny = { id, ... }    ANY one of these must be completed
--   share                   true if the quest can be shared
--   start = { npc = "Name", map = uiMapID, x = 0-100, y = 0-100 }
--   inside = true           quest starts inside the dungeon -> shown as [INSIDE], no map pin
--   (no start at all)       questgiver unknown -> red ! in the list, no map pin
--
-- Capture helper: talk to a quest giver for a new quest -> /dqt captured prints a draft line.
local _, ns = ...
local D, Q = ns.Data.Dungeons, ns.Data.Quests

-- uiMapIDs: Alterac Mountains 1416, Hillsbrad 1424, Undercity 1458, Ironforge 1455, Wetlands 1437,
-- Stranglethorn 1434, Dustwallow 1445, Azshara 1447, Un'Goro 1449, Riverglades 2548

D.THANES     = { name = "The Hall of Thanes",        min = 13, max = 18, isNew = true, zone = "Ironforge",          entrance = { map = 1455, x = 27.63, y = 47.83 } }
D.LORDAERON  = { name = "Ruins of Lordaeron",        min = 15, max = 20, isNew = true, zone = "Undercity",          entrance = { map = 1458, x = 72.41, y = 11.37 } }
D.EXCAVATION = { name = "Excavation Site: Wetlands", min = 24, max = 29, isNew = true, zone = "Wetlands",           entrance = { map = 1437, x = 47.79, y = 56.16 } }
D.DALARAN    = { name = "City of Dalaran",           min = 28, max = 33, isNew = true, zone = "Alterac Mountains",  entrance = { map = 1416, x = 8.46,  y = 59.21 } }
D.DROWNED    = { name = "The Drowned City",          min = 35, max = 40, isNew = true, zone = "Stranglethorn Vale" } -- TODO entrance (underwater, west of Grom'gol)
D.KROLDOK    = { name = "Krol'dok Stronghold",       min = 40, max = 45, isNew = true, zone = "Riverglades" }        -- TODO entrance
D.ALCAZ      = { name = "Alcaz Prison",              min = 48, max = 53, isNew = true, zone = "Dustwallow Marsh" }   -- TODO entrance (Alcaz Island)
D.BLACKMAW   = { name = "Blackmaw Hold",             min = 55, max = 60, isNew = true, zone = "Azshara" }            -- TODO entrance
D.SHAPER     = { name = "Shaper's Terrace",          min = 58, max = 60, isNew = true, zone = "Un'Goro Crater" }     -- TODO entrance (northern hills)

----------------------------------------------------------------------------
-- Source: Wowhead Forever DB (quest pages + NPC map data), scraped 2026-11-09.
-- Only quests Wowhead types as "Dungeon" are given a dungeon (d); chain helpers have d = nil.
----------------------------------------------------------------------------

-- The Hall of Thanes
Q[96391] = { name = "Underground Map", lvl = 15, min = 9, faction = "A" } -- starts from item "Dark Iron Map"
Q[96393] = { name = "Old Ironforge Incursion", d = "THANES", lvl = 16, min = 9,  faction = "A", pre = { 96391 }, share = true, start = { npc = "Earthseer Farsen", map = 1426, x = 64.8, y = 58.4 } }
Q[96394] = { name = "The Restless Dead",       d = "THANES", lvl = 15, min = 10, faction = "A", share = true, start = { npc = "Afadra Dunwall", map = 1455, x = 32.8, y = 48.6 } }
Q[96395] = { name = "An Ancient Grudge",       d = "THANES", lvl = 15, min = 10, faction = "B", share = true, inside = true, start = { npc = "Ghostly Attendant" } }
Q[96403] = { name = "Important Heirlooms",     d = "THANES", lvl = 15, min = 10, faction = "B", share = true, start = { npc = "Thom Filch", map = 1455, x = 31.4, y = 45.8 } }
Q[98423] = { name = "The Treaty of Understanding", d = "THANES", min = 9, faction = "A", inside = true, start = { object = "Vault (Reliquary of Kings)" } }

-- Ruins of Lordaeron
Q[92401] = { name = "A Frightened Request",     d = "LORDAERON", lvl = 22, min = 15, faction = "H", share = true, start = { npc = "Tabitha Heartweaver", map = 1421, x = 44.4, y = 42.8 } }
Q[92415] = { name = "Remember That I Love You", d = "LORDAERON", lvl = 22, min = 15, faction = "A" }
Q[92421] = { name = "Light's Justice",          d = "LORDAERON", lvl = 22, min = 15, faction = "H", share = true, start = { npc = "Morbin Lightbane", map = 1458, x = 57.4, y = 90.4 } }
Q[92422] = { name = "The Wrath of Rath'mael",   d = "LORDAERON", lvl = 22, min = 15, faction = "H", share = true, start = { npc = "Deathguard Kristof", map = 1420, x = 63.9, y = 61.4 } }
Q[95189] = { name = "Crest of Lordaeron",       d = "LORDAERON", lvl = 22, min = 15, faction = "A" }
Q[95195] = { name = "Bloodied Insignia",        d = "LORDAERON", lvl = 22, min = 15, faction = "A" }
Q[95204] = { name = "Crest of Lordaeron",       d = "LORDAERON", lvl = 22, min = 15, faction = "H" }
Q[95216] = { name = "The New Plague",           d = "LORDAERON", lvl = 22, min = 15, faction = "H", share = true, start = { npc = "Theodore Griffs", map = 1458, x = 46.2, y = 70.4 } }
Q[95250] = { name = "Abominable Creatures",     d = "LORDAERON", lvl = 21, min = 15, faction = "A", share = true }
Q[97288] = { name = "Unending Torment",         d = "LORDAERON", lvl = 21, min = 15, faction = "H" }

-- Excavation Site: Wetlands
Q[95646] = { name = "Horrors in the Highland",    d = "EXCAVATION", lvl = 31, min = 24, faction = "A", share = true, start = { npc = "Rethiel the Greenwarden", map = 1437, x = 56.2, y = 40.4 } }
Q[95647] = { name = "Lost in the Thicket Things", d = "EXCAVATION", lvl = 31, min = 24, faction = "A", share = true, start = { npc = "Caitlin Grassman", map = 1437, x = 11.6, y = 58.4 } }
Q[95663] = { name = "Dragonmaw Rumors",           d = "EXCAVATION", lvl = 31, min = 24, faction = "H", share = true, start = { npc = "Zaruk", map = 1417, x = 74.4, y = 35.4 } }
Q[95664] = { name = "Elder Knowledge",            d = "EXCAVATION", lvl = 31, min = 24, faction = "H" }
Q[95682] = { name = "Open the Maw",               d = "EXCAVATION", lvl = 31, min = 24, faction = "H", pre = { 95663 }, share = true, start = { npc = "Deathstalker Agent", map = 1437, x = 51.4, y = 59.2 } }
Q[95697] = { name = "Changing Tastes",            d = "EXCAVATION", lvl = 31, min = 24, faction = "H", share = true, start = { npc = "Borstan", map = 1454, x = 57.4, y = 53.4 } }
Q[95737] = { name = "Seeking Caitlin",            d = "EXCAVATION", lvl = 31, min = 24, faction = "A", share = true, start = { npc = "Llana", map = 1440, x = 35.0, y = 48.4 } }
Q[95772] = { name = "Songblade Search",           d = "EXCAVATION", lvl = 31, min = 24, faction = "A", share = true, start = { npc = "Dorin Songblade", map = 1433, x = 25.6, y = 46.4 } }
Q[95795] = { name = "Fallen in the Fen",          d = "EXCAVATION", lvl = 31, min = 24, faction = "A", share = true }
Q[95809] = { name = "Heartwoven",                 d = "EXCAVATION", lvl = 31, min = 24, faction = "A", pre = { 95647 } }
Q[95810] = { name = "Lost Relic Carry",           d = "EXCAVATION", lvl = 31, min = 24, faction = "A" }
Q[98815] = { name = "Highland Hides",             d = "EXCAVATION", lvl = 28, min = 24, faction = "A", share = true, start = { npc = "James Halloran", map = 1437, x = 8.4, y = 55.8 } }
Q[98823] = { name = "Earthen Echo",               d = "EXCAVATION", lvl = 31, min = 24, faction = "H", pre = { 95664 }, start = { npc = "Bashana Runetotem", map = 1456, x = 70.2, y = 33.6 } }
Q[98824] = { name = "Prehistoric Prism",          d = "EXCAVATION", lvl = 31, min = 24, faction = "A", pre = { 95810 }, start = { npc = "Prospector Whelgar", map = 1437, x = 38.8, y = 52.2 } }

-- City of Dalaran
-- An Alarming Request (A) / Blood in the Streets (H) are HARD prerequisites (confirmed by Valdemar),
-- even though Wowhead labels them breadcrumbs.
Q[92432] = { name = "An Alarming Request", lvl = 33, min = 30, faction = "A", share = true, start = { npc = "Emissary Jacques", map = 1424, x = 48.3, y = 60.1 } }
Q[92434] = { name = "Blood in the Streets", lvl = 34, min = 30, faction = "H", start = { npc = "Magus Wordeen Voidglare", map = 1424, x = 61.4, y = 20.8 } }
Q[92456] = { name = "A Green Sample",      d = "DALARAN", lvl = 33, min = 24, faction = "A", share = true, start = { npc = "Shylamiir", map = 1453, x = 15.0, y = 49.4 } }
Q[92457] = { name = "Starving Arcane",     d = "DALARAN", lvl = 33, min = 24, faction = "A", pre = { 92432 }, share = true, start = { npc = "Image of Archmage Modera", map = 1421, x = 68.4, y = 45.2 } }
Q[92458] = { name = "Heart of Disruption", d = "DALARAN", lvl = 33, min = 24, faction = "A", pre = { 92432 }, start = { npc = "Image of Archmage Modera", map = 1421, x = 68.4, y = 45.2 } }
Q[92489] = { name = "Power Overwhelming",  d = "DALARAN", lvl = 33, min = 24, faction = "A", share = true, start = { npc = "High Sorcerer Andromath", map = 1453, x = 37.6, y = 81.6 } }
Q[96984] = { name = "Heart of Disruption", d = "DALARAN", lvl = 33, min = 24, faction = "H", pre = { 92434 }, start = { npc = "Image of Archmage Modera", map = 1421, x = 68.4, y = 45.2 } }
Q[96800] = { name = "Past Due",            d = "DALARAN", faction = "A" }
Q[96986] = { name = "The Grave Knight",        d = "DALARAN", lvl = 33, min = 24, faction = "H", share = true, start = { npc = "Melisara", map = 1424, x = 62.4, y = 20.4 } }
Q[96987] = { name = "Opportunistic Education", d = "DALARAN", lvl = 33, min = 24, faction = "H", share = true }
Q[96988] = { name = "Source of Power",         d = "DALARAN", lvl = 33, min = 24, faction = "H", share = true, start = { npc = "Doctor Martin Felben", map = 1458, x = 45.8, y = 73.2 } }


-- The Drowned City
Q[95775] = { name = "The Drowned City",            d = "DROWNED", lvl = 40, min = 30, faction = "H", share = true, start = { npc = "Kin'weelay", map = 1434, x = 32.2, y = 27.8 } }
Q[95776] = { name = "The Only Good Brinescale...", d = "DROWNED", lvl = 38, min = 30, faction = "H", share = true, start = { npc = "Commander Aggro'gosh", map = 1434, x = 32.2, y = 28.8 } }
Q[95787] = { name = "Take Two With Water",         d = "DROWNED", lvl = 40, min = 30, faction = "A", share = true }
Q[95788] = { name = "Magics of the Drowned City",  d = "DROWNED", lvl = 40, min = 30, faction = "A", share = true }
Q[95789] = { name = "Shady Saltseers",             d = "DROWNED", lvl = 40, min = 34, faction = "B", share = true, start = { npc = "Krazek", map = 1434, x = 27.0, y = 77.2 } }
Q[95791] = { name = "The Saltseer Captain",        d = "DROWNED", lvl = 40, min = 34, faction = "B", share = true, start = { npc = "Krazek", map = 1434, x = 27.0, y = 77.2 } }
Q[96774] = { name = "Ancient Gurubashi Idol",      d = "DROWNED", lvl = 40, min = 30, faction = "H", share = true, start = { npc = "Mazu'kon", map = 1412, x = 32.4, y = 20.6 } }
Q[97130] = { name = "Ancient Gurubashi Secrets",   d = "DROWNED", lvl = 40, min = 34, faction = "A", share = true, start = { npc = "Archmage Timear", map = 1416, x = 15.4, y = 74.0 } }

-- Krol'dok Stronghold (Wowhead has no quest-giver data for these yet -> red ! in the list)
Q[94907] = { name = "A Small Favor",              lvl = 44, min = 36, faction = "A" }
Q[94968] = { name = "Eye of Mugg",                d = "KROLDOK", lvl = 45, min = 40, faction = "H", share = true }
Q[94972] = { name = "Tome of Twilight",           d = "KROLDOK", lvl = 44, min = 39, faction = "H", share = true }
Q[94975] = { name = "A Token of Vengeance",       d = "KROLDOK", lvl = 42, min = 38, faction = "H", share = true }
Q[94982] = { name = "Eye of Mugg",                d = "KROLDOK", lvl = 45, min = 40, faction = "A", share = true }
Q[94983] = { name = "Twilight Mementos",          d = "KROLDOK", lvl = 42, min = 38, faction = "A", share = true }
Q[94984] = { name = "Tome of Twilight",           d = "KROLDOK", lvl = 44, min = 39, faction = "A", pre = { 94907 }, share = true }
Q[96771] = { name = "Vengeance of the Highborne", d = "KROLDOK", lvl = 45, min = 37, faction = "A", share = true }

-- Alcaz Prison
Q[96772] = { name = "The Dragon's Journal", d = "ALCAZ", lvl = 53, min = 46, faction = "A", share = true }

-- Blackmaw Hold
Q[92345] = { name = "Beneath Nordrassil",   lvl = 55, min = 45, faction = "A", share = true }
Q[92344] = { name = "Get to the Roots of It", d = "BLACKMAW", lvl = 55, min = 45, faction = "A", pre = { 92345 }, share = true }
Q[97198] = { name = "Blackmaw Magic",         d = "BLACKMAW", lvl = 59, min = 52, faction = "H", share = true }

-- Shaper's Terrace: Wowhead lists no quests yet.
