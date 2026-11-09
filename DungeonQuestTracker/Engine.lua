local _, ns = ...

local Engine = {}
ns.Engine = Engine

local D, Q = ns.Data.Dungeons, ns.Data.Quests

-- Skyborne races use high bits in Forever race masks.
local RACE_BIT_OVERRIDES = { [95] = 32, [96] = 33 }
local FACTION_MASK = { Alliance = 4294967373, Horde = 8589934770 }
local FACTION_SHORT = { Alliance = "A", Horde = "H" }

local STATUS_ORDER = { ACTIVE = 1, AVAILABLE = 2, PREREQ = 3, LEVEL = 4 }
Engine.VISIBLE = STATUS_ORDER

local player = { level = 1, faction = "Alliance" }
Engine.player = player

local statusCache = {}

local function HasBit(mask, bit)
    return math.floor(mask / 2 ^ bit) % 2 == 1
end

function Engine.InitPlayer(level)
    player.level = level or UnitLevel("player") or 1
    player.faction = UnitFactionGroup("player") or "Alliance"
    local _, _, raceID = UnitRace("player")
    player.raceID = raceID
    player.raceBit = raceID and (RACE_BIT_OVERRIDES[raceID] or (raceID <= 31 and raceID - 1)) or nil
    local _, _, classID = UnitClass("player")
    player.classBit = classID and classID - 1 or nil
end

-- Horde and Skyborne characters haven't been tested in game yet.
function Engine.IsUntestedCharacter()
    return player.faction == "Horde" or player.raceID == 95 or player.raceID == 96
end

function Engine.Invalidate()
    wipe(statusCache)
end

local function IsCompleted(id)
    return C_QuestLog.IsQuestFlaggedCompleted(id) == true
end

local function IsActive(id)
    if C_QuestLog.IsOnQuest then
        return C_QuestLog.IsOnQuest(id) == true
    end
    return C_QuestLog.GetLogIndexForQuestID(id) ~= nil
end

local function IsDoneOrActive(id)
    return id and (IsCompleted(id) or IsActive(id))
end

local function Eligible(q)
    if q.faction and q.faction ~= "B" and q.faction ~= FACTION_SHORT[player.faction] then
        return false
    end
    if q.races and q.races ~= 0 then
        if player.raceBit then
            if not HasBit(q.races, player.raceBit) then return false end
        elseif q.races == FACTION_MASK[player.faction == "Alliance" and "Horde" or "Alliance"] then
            return false
        end
    end
    if q.classes and q.classes ~= 0 and player.classBit then
        if not HasBit(q.classes, player.classBit) then return false end
    end
    return true
end
Engine.Eligible = Eligible

-- A quest is superseded when an exclusive alternative, the next chain step,
-- or the quest this breadcrumb leads to has already been taken.
local function Superseded(q)
    if q.excl then
        for _, id in ipairs(q.excl) do
            if IsDoneOrActive(id) then return true end
        end
    end
    if q.next and IsDoneOrActive(q.next) then return true end
    if q.crumbFor and IsDoneOrActive(q.crumbFor) then return true end
    return false
end

local function EligibleId(id)
    local q = Q[id]
    return q == nil or Eligible(q)
end

-- Returns the list of prerequisite quest IDs that are still blocking q.
local function UnmetPrereqs(q)
    local unmet = {}
    if q.pre then
        for _, id in ipairs(q.pre) do
            if EligibleId(id) and not IsCompleted(id) then
                table.insert(unmet, id)
            end
        end
    end
    if q.preAny then
        local candidates, anyDone = {}, false
        for _, id in ipairs(q.preAny) do
            if EligibleId(id) then
                if IsCompleted(id) then anyDone = true break end
                table.insert(candidates, id)
            end
        end
        if not anyDone then
            for _, id in ipairs(candidates) do table.insert(unmet, id) end
        end
    end
    if q.parent and not IsActive(q.parent) then
        table.insert(unmet, q.parent)
    end
    if q.startWith and not IsDoneOrActive(q.startWith) then
        table.insert(unmet, q.startWith)
    end
    return unmet
end
Engine.UnmetPrereqs = UnmetPrereqs

function Engine.MinLevel(q)
    if q.min then return q.min end
    local d = q.d and D[q.d]
    return d and d.min or 1
end

-- True if the player can work on at least one missing prerequisite right now
-- (it's in the log, can be picked up, or its own chain is workable).
local function PrereqReachable(q)
    for _, pid in ipairs(UnmetPrereqs(q)) do
        local st = Engine.Status(pid)
        if st == "ACTIVE" or st == "AVAILABLE" or st == "PREREQ" or st == "UNKNOWN" then
            return true
        end
    end
    return false
end

-- Status priority: DONE > ACTIVE (green) > PREREQ (blue) > LEVEL (red) > AVAILABLE (yellow)
-- A missing prerequisite the player can't get yet (level-locked chain) counts as LEVEL (red).
function Engine.Status(id)
    local cached = statusCache[id]
    if cached then return cached end
    local q = Q[id]
    local s
    if not q then
        s = "UNKNOWN"
    elseif IsCompleted(id) then
        s = "DONE"
    elseif IsActive(id) then
        s = "ACTIVE"
    elseif not Eligible(q) then
        s = "HIDDEN"
    elseif Superseded(q) then
        s = "DONE"
    elseif #UnmetPrereqs(q) > 0 then
        statusCache[id] = "PREREQ" -- provisional: guards against cyclic prerequisite data
        s = PrereqReachable(q) and "PREREQ" or "LEVEL"
    elseif player.level < Engine.MinLevel(q) then
        s = "LEVEL"
    else
        s = "AVAILABLE"
    end
    statusCache[id] = s
    return s
end

-- Walks the prerequisite chain and returns the first steps the player can act on.
function Engine.OpenSteps(id)
    local result, seen = {}, {}
    local function walk(qid, depth)
        local q = Q[qid]
        if not q or depth > 20 then return end
        for _, pid in ipairs(UnmetPrereqs(q)) do
            if not seen[pid] then
                seen[pid] = true
                local st = Engine.Status(pid)
                if st == "PREREQ" then
                    walk(pid, depth + 1)
                elseif st == "AVAILABLE" or st == "LEVEL" or st == "UNKNOWN" then
                    table.insert(result, pid)
                end
            end
        end
    end
    walk(id, 0)
    return result
end

-- A dungeon quest that starts inside the instance (item drop, NPC inside, or flagged by hand).
function Engine.IsInside(q)
    if not q or not q.d then return false end
    if q.inside ~= nil then return q.inside end
    return q.start ~= nil and q.start.map == nil
end

-- No data on who/what starts the quest.
function Engine.GiverUnknown(q)
    local s = q and q.start
    return not (s and (s.npc or s.object or s.item))
end

-- The quest the player has to act on next for this dungeon quest: the quest itself, or the
-- first open prerequisite (pickable first, then level-locked, then one already in the log).
function Engine.CurrentStep(id)
    local q = Q[id]
    if not q then return nil end
    local unmet = UnmetPrereqs(q)
    if #unmet == 0 then return id end
    local steps = Engine.OpenSteps(id)
    for _, wanted in ipairs({ "AVAILABLE", "LEVEL", "UNKNOWN" }) do
        for _, s in ipairs(steps) do
            if Engine.Status(s) == wanted then return s end
        end
    end
    for _, pid in ipairs(unmet) do
        if Engine.Status(pid) == "ACTIVE" then return pid end
    end
    return unmet[1]
end

-- Returns map, x, y (0-100) for where a quest is picked up, or nil (unknown or inside a dungeon).
function Engine.Location(id)
    local q = Q[id]
    local s = q and q.start
    if s and s.map and s.x and s.y then
        return s.map, s.x, s.y
    end
    return nil
end

local function SortQuests(a, b)
    local oa, ob = STATUS_ORDER[a.status], STATUS_ORDER[b.status]
    if oa ~= ob then return oa < ob end
    local la, lb = a.q.lvl or 0, b.q.lvl or 0
    if la ~= lb then return la < lb end
    return a.q.name < b.q.name
end

--------------------------------------------------------------------------
-- Ignore list (per character)
--------------------------------------------------------------------------
local function IgnoreStore()
    return ns.chardb and ns.chardb.ignored or { quests = {}, dungeons = {} }
end

function Engine.IsIgnored(id)
    local q = Q[id]
    local store = IgnoreStore()
    return store.quests[id] == true or (q ~= nil and q.d ~= nil and store.dungeons[q.d] == true)
end

function Engine.SetQuestIgnored(id, ignored)
    IgnoreStore().quests[id] = ignored or nil
end

function Engine.SetDungeonIgnored(key, ignored)
    IgnoreStore().dungeons[key] = ignored or nil
end

-- Ignored dungeons (always listed) and individually ignored quests that are still open.
function Engine.GetIgnored()
    local store = IgnoreStore()
    local dungeons, quests = {}, {}
    for key in pairs(store.dungeons) do
        if D[key] then table.insert(dungeons, { key = key, def = D[key] }) end
    end
    for id in pairs(store.quests) do
        local st = Q[id] and Engine.Status(id)
        if st and STATUS_ORDER[st] then
            table.insert(quests, { id = id, q = Q[id], status = st })
        end
    end
    table.sort(dungeons, function(a, b) return a.def.min < b.def.min end)
    table.sort(quests, SortQuests)
    return dungeons, quests
end

function Engine.GetDungeonList()
    local byDungeon = {}
    for id, q in pairs(Q) do
        if q.d and D[q.d] and not Engine.IsIgnored(id) then
            local st = Engine.Status(id)
            if STATUS_ORDER[st] then
                byDungeon[q.d] = byDungeon[q.d] or {}
                table.insert(byDungeon[q.d], { id = id, q = q, status = st })
            end
        end
    end
    local list = {}
    for key, quests in pairs(byDungeon) do
        table.sort(quests, SortQuests)
        table.insert(list, { key = key, def = D[key], quests = quests })
    end
    table.sort(list, function(a, b)
        if a.def.min ~= b.def.min then return a.def.min < b.def.min end
        return a.def.name < b.def.name
    end)
    return list
end

-- Pins: every yellow dungeon quest, plus the first open prerequisite step of every blue one
-- (only steps the player can pick up now - level-locked steps get no pin). Ignored quests are skipped.
function Engine.GetMapPins()
    local pins, byId = {}, {}
    local function add(id, kind, unlocks)
        local pin = byId[id]
        if not pin then
            local map, x, y = Engine.Location(id)
            if not map then return end
            pin = { id = id, kind = kind, map = map, x = x, y = y, unlocks = {} }
            byId[id] = pin
            table.insert(pins, pin)
        end
        if kind == "AVAILABLE" then pin.kind = "AVAILABLE" end
        if unlocks then table.insert(pin.unlocks, unlocks) end
    end
    for id, q in pairs(Q) do
        if q.d and D[q.d] and not Engine.IsIgnored(id) then
            local st = Engine.Status(id)
            if st == "AVAILABLE" then
                add(id, "AVAILABLE")
            elseif st == "PREREQ" then
                for _, stepId in ipairs(Engine.OpenSteps(id)) do
                    if Engine.Status(stepId) == "AVAILABLE" then
                        add(stepId, "PREREQ", id)
                    end
                end
            end
        end
    end
    return pins
end

-- Open dungeon quests that directly require this quest.
local dependentsIndex
function Engine.Dependents(id)
    if not dependentsIndex then
        dependentsIndex = {}
        for qid, q in pairs(Q) do
            if q.d then
                local refs = {}
                for _, r in ipairs(q.pre or {}) do refs[r] = true end
                for _, r in ipairs(q.preAny or {}) do refs[r] = true end
                if q.parent then refs[q.parent] = true end
                if q.startWith then refs[q.startWith] = true end
                for r in pairs(refs) do
                    dependentsIndex[r] = dependentsIndex[r] or {}
                    table.insert(dependentsIndex[r], qid)
                end
            end
        end
    end
    local result = {}
    for _, qid in ipairs(dependentsIndex[id] or {}) do
        if STATUS_ORDER[Engine.Status(qid)] then table.insert(result, qid) end
    end
    table.sort(result, function(a, b) return Q[a].name < Q[b].name end)
    return result
end

function Engine.IsShareable(id)
    if IsActive(id) and C_QuestLog.IsPushableQuest then
        return C_QuestLog.IsPushableQuest(id) == true
    end
    local q = Q[id]
    return q and q.share == true
end
