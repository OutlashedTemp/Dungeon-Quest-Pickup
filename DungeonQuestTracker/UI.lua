local _, ns = ...

local UI = {}
ns.UI = UI

local ROW_H = 18
local PAD = 10
local SHARE_ATLAS = "socialqueuing-icon-group"
local SHARE_TEX = "Interface\\Icons\\Achievement_GuildPerk_EverybodysFriend"
local BG = { 0.04, 0.04, 0.045, 0.95 }
local ORANGE = { 0.945, 0.349, 0.165 }

local frame, scroll, content
local rows = {}

local function Hex(status)
    return ns.COLORS[status] and ns.COLORS[status][4] or "ffffff"
end

local function SetShareIcon(tex)
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(SHARE_ATLAS) then
        tex:SetAtlas(SHARE_ATLAS)
    else
        tex:SetTexture(SHARE_TEX)
    end
end

--------------------------------------------------------------------------
-- Tooltip (shared with map pins)
--------------------------------------------------------------------------
function UI.ShowQuestTooltip(owner, id)
    local q = ns.Data.Quests[id]
    if not q then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:AddLine(("|cff%s%s|r"):format(Hex(ns.Engine.Status(id)), q.name))

    local dependents = ns.Engine.Dependents(id)
    local dungeons, seen = {}, {}
    local function addDungeon(key)
        local d = key and ns.Data.Dungeons[key]
        if d and not seen[key] then
            seen[key] = true
            table.insert(dungeons, d.name)
        end
    end
    addDungeon(q.d)
    for _, depId in ipairs(dependents) do addDungeon(ns.Data.Quests[depId].d) end
    if #dungeons > 0 then
        GameTooltip:AddLine("Dungeon: |cffffffff" .. table.concat(dungeons, ", ") .. "|r", 0.945, 0.349, 0.165)
    end

    for _, depId in ipairs(dependents) do
        GameTooltip:AddLine("Pre-requisite for: |cffffffff" .. ns.Data.Quests[depId].name .. "|r", 0.3, 0.6, 1)
    end

    local stepId = ns.Engine.Status(id) ~= "ACTIVE" and ns.Engine.CurrentStep(id) or id
    if ns.Engine.GiverUnknown(ns.Data.Quests[stepId]) then
        GameTooltip:AddLine("Questgiver info unknown", 1, 0.13, 0.13)
    end

    if ns.Engine.IsShareable(id) then
        GameTooltip:AddLine("Can be shared", 0.25, 1, 0.25)
    else
        GameTooltip:AddLine("Can't be shared", 1, 0.25, 0.25)
    end
    GameTooltip:AddLine("Quest ID " .. id, 0.5, 0.5, 0.5)
    GameTooltip:Show()
end

--------------------------------------------------------------------------
-- Rows
--------------------------------------------------------------------------
local ignoredCollapsed = true -- collapsed on every login/reload

--------------------------------------------------------------------------
-- Copy-link popup (Ctrl+C)
--------------------------------------------------------------------------
local linkFrame
local function ShowLinkPopup(title, url)
    if not linkFrame then
        linkFrame = CreateFrame("Frame", "DQT_LinkFrame", UIParent, "BackdropTemplate")
        linkFrame:SetSize(420, 86)
        linkFrame:SetPoint("CENTER", 0, 120)
        linkFrame:SetFrameStrata("DIALOG")
        linkFrame:EnableMouse(true)
        linkFrame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        linkFrame:SetBackdropColor(unpack(BG))
        linkFrame:SetBackdropBorderColor(ORANGE[1], ORANGE[2], ORANGE[3], 0.8)
        tinsert(UISpecialFrames, "DQT_LinkFrame")

        linkFrame.title = linkFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        linkFrame.title:SetPoint("TOPLEFT", PAD, -PAD)
        linkFrame.title:SetPoint("RIGHT", -30, 0)
        linkFrame.title:SetJustifyH("LEFT")

        local hint = linkFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        hint:SetPoint("BOTTOMLEFT", PAD, PAD)
        hint:SetText("Ctrl+C to copy, Esc to close")

        local close = CreateFrame("Button", nil, linkFrame, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", 2, 2)
        close:SetScript("OnClick", function() linkFrame:Hide() end)

        local box = CreateFrame("EditBox", nil, linkFrame, "InputBoxTemplate")
        box:SetPoint("LEFT", PAD + 6, 0)
        box:SetPoint("RIGHT", -PAD, 0)
        box:SetHeight(20)
        box:SetAutoFocus(false)
        -- Read-only: any edit snaps back to the link and re-selects it.
        box:SetScript("OnTextChanged", function(self, userInput)
            if userInput then self:SetText(linkFrame.url) self:HighlightText() end
        end)
        box:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
        box:SetScript("OnEscapePressed", function() linkFrame:Hide() end)
        box:SetScript("OnEnterPressed", function() linkFrame:Hide() end)
        box:SetScript("OnKeyUp", function(_, key)
            if key == "C" and IsControlKeyDown() then linkFrame:Hide() end
        end)
        linkFrame.box = box
    end
    linkFrame.url = url
    linkFrame.title:SetText(title)
    linkFrame.box:SetText(url)
    linkFrame:Show()
    linkFrame.box:SetFocus()
    linkFrame.box:HighlightText()
end

local function WowheadUrl(questID)
    return ("https://www.wowhead.com/forever/quest=%d"):format(questID)
end

-- items: { { label, action, refresh }, ... }
local function ContextMenu(row, title, items)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then
        local first = items[1]
        first[2]()
        if first[3] then ns.RequestRefresh() end
        return
    end
    MenuUtil.CreateContextMenu(row, function(_, root)
        root:CreateTitle(title)
        for _, item in ipairs(items) do
            root:CreateButton(item[1], function()
                item[2]()
                if item[3] then ns.RequestRefresh() end
            end)
        end
    end)
end

local function OnRightClick(row, e)
    local Engine = ns.Engine
    local function linkItem()
        return { "WoWHead link", function() ShowLinkPopup(e.q.name, WowheadUrl(e.id)) end, false }
    end
    if e.type == "dungeon" then
        ContextMenu(row, e.def.name, { { "Hide this dungeon", function() Engine.SetDungeonIgnored(e.key, true) end, true } })
    elseif e.type == "quest" then
        ContextMenu(row, e.q.name, { { "Hide this quest", function() Engine.SetQuestIgnored(e.id, true) end, true }, linkItem() })
    elseif e.type == "ignoredDungeon" then
        ContextMenu(row, e.def.name, { { "Un-ignore", function() Engine.SetDungeonIgnored(e.key, false) end, true } })
    elseif e.type == "ignoredQuest" then
        ContextMenu(row, e.q.name, { { "Un-ignore", function() Engine.SetQuestIgnored(e.id, false) end, true }, linkItem() })
    end
end

local function OnRowClick(row, button)
    local e = row.entry
    if not e then return end
    if button == "RightButton" then
        OnRightClick(row, e)
    elseif e.type == "ignoredHeader" then
        ignoredCollapsed = not ignoredCollapsed
        UI.Refresh()
    elseif e.type == "dungeon" then
        ns.db.collapsed[e.key] = not ns.db.collapsed[e.key]
        UI.Refresh()
    elseif e.type ~= "quest" then
        return
    elseif e.status == "AVAILABLE" then
        ns.Map.ShowQuest(e.id)
    elseif e.status == "PREREQ" then
        ns.Map.ShowPrereq(e.id)
    end
end

local function CreateRow(i)
    local row = CreateFrame("Button", nil, content)
    row:SetHeight(ROW_H)
    row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
    row:SetPoint("RIGHT", content, "RIGHT")
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    row.hl = row:CreateTexture(nil, "HIGHLIGHT")
    row.hl:SetAllPoints()
    row.hl:SetColorTexture(ORANGE[1], ORANGE[2], ORANGE[3], 0.12)

    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(false)

    row.share = row:CreateTexture(nil, "OVERLAY")
    row.share:SetSize(14, 14)
    row.share:SetPoint("RIGHT", -4, 0)
    SetShareIcon(row.share)

    row.text:SetPoint("LEFT", 4, 0)
    row.text:SetPoint("RIGHT", row.share, "LEFT", -4, 0)

    row:SetScript("OnClick", OnRowClick)
    row:SetScript("OnEnter", function(self)
        if self.entry and (self.entry.type == "quest" or self.entry.type == "ignoredQuest") then
            UI.ShowQuestTooltip(self, self.entry.id)
        end
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    rows[i] = row
    return row
end

local function BuildEntries()
    local entries = {}
    local counts = { ACTIVE = 0, AVAILABLE = 0, PREREQ = 0, LEVEL = 0 }
    for _, dungeon in ipairs(ns.Engine.GetDungeonList()) do
        local collapsed = ns.db.collapsed[dungeon.key]
        table.insert(entries, { type = "dungeon", key = dungeon.key, def = dungeon.def, n = #dungeon.quests, collapsed = collapsed })
        for _, item in ipairs(dungeon.quests) do
            counts[item.status] = counts[item.status] + 1
            if not collapsed then
                table.insert(entries, { type = "quest", id = item.id, q = item.q, status = item.status })
            end
        end
    end

    local ignoredDungeons, ignoredQuests = ns.Engine.GetIgnored()
    local nIgnored = #ignoredDungeons + #ignoredQuests
    if nIgnored > 0 then
        table.insert(entries, { type = "ignoredHeader", n = nIgnored, collapsed = ignoredCollapsed })
        if not ignoredCollapsed then
            for _, d in ipairs(ignoredDungeons) do
                table.insert(entries, { type = "ignoredDungeon", key = d.key, def = d.def })
            end
            for _, item in ipairs(ignoredQuests) do
                table.insert(entries, { type = "ignoredQuest", id = item.id, q = item.q, status = item.status })
            end
        end
    end
    return entries, counts
end

local zoneNames = {}
local function ZoneName(mapID)
    if not mapID then return nil end
    if zoneNames[mapID] == nil then
        local info = C_Map.GetMapInfo(mapID)
        zoneNames[mapID] = info and info.name or false
    end
    return zoneNames[mapID] or nil
end

-- Suffix describing where the step happens: red ! (giver unknown), [INSIDE] or [Zone].
local function StepSuffix(stepQ)
    if ns.Engine.GiverUnknown(stepQ) then return " |cffff2020!|r" end
    if ns.Engine.IsInside(stepQ) then return " |cff888888[INSIDE]|r" end
    local zone = stepQ.start and ZoneName(stepQ.start.map)
    return zone and (" |cff888888[" .. zone .. "]|r") or ""
end

local function QuestRowText(e)
    local lvl = (e.q.lvl and e.q.lvl > 0) and e.q.lvl or ns.Engine.MinLevel(e.q)
    local text = ("|cff%s[%d] %s|r"):format(Hex(e.status), lvl, e.q.name)
    if e.status == "ACTIVE" then return text end
    local stepId = ns.Engine.CurrentStep(e.id)
    local stepQ = stepId and ns.Data.Quests[stepId]
    if not stepQ then return text end
    if stepId ~= e.id then
        text = text .. (" |cff%s-> %s|r"):format(Hex(ns.Engine.Status(stepId)), stepQ.name)
    end
    return text .. StepSuffix(stepQ)
end

function UI.Refresh()
    if not frame or not frame:IsShown() then return end
    local entries, counts = BuildEntries()
    for i, e in ipairs(entries) do
        local row = rows[i] or CreateRow(i)
        row.entry = e
        if e.type == "dungeon" then
            local arrow = e.collapsed and "+ " or "- "
            local new = e.def.isNew and " |cff" .. ns.ACCENT .. "NEW|r" or ""
            row.text:SetFontObject("GameFontNormal")
            row.text:SetText(("|cff%s%s%s|r |cff888888(%d-%d)  %d|r%s"):format(ns.ACCENT, arrow, e.def.name, e.def.min, e.def.max, e.n, new))
            row.share:Hide()
        elseif e.type == "quest" then
            row.text:SetFontObject("GameFontHighlightSmall")
            row.text:SetText("      " .. QuestRowText(e))
            row.share:SetShown(ns.Engine.IsShareable(e.id))
        elseif e.type == "ignoredHeader" then
            row.text:SetFontObject("GameFontNormal")
            row.text:SetText(("|cff888888%sIgnored  %d|r"):format(e.collapsed and "+ " or "- ", e.n))
            row.share:Hide()
        elseif e.type == "ignoredDungeon" then
            row.text:SetFontObject("GameFontHighlightSmall")
            row.text:SetText(("      |cff%s%s|r |cff888888(%d-%d)|r"):format(ns.ACCENT, e.def.name, e.def.min, e.def.max))
            row.share:Hide()
        else -- ignoredQuest
            row.text:SetFontObject("GameFontHighlightSmall")
            local d = e.q.d and ns.Data.Dungeons[e.q.d]
            row.text:SetText("      " .. QuestRowText(e) .. (d and (" |cff888888- " .. d.name .. "|r") or ""))
            row.share:Hide()
        end
        row:Show()
    end
    for i = #entries + 1, #rows do
        rows[i]:Hide()
        rows[i].entry = nil
    end
    content:SetHeight(math.max(1, #entries * ROW_H))
    content:SetWidth(scroll:GetWidth())

    local p = ns.Engine.player
    local untested = ns.Engine.IsUntestedCharacter() and ("  |cff%s(Horde/Skyborne untested)|r"):format(ns.ACCENT) or ""
    frame.subtitle:SetText(("%s  -  level %d%s"):format(p.faction, p.level, untested))
    frame.footer:SetText(("|cff%s%d active|r   |cff%s%d available|r   |cff%s%d prereq|r   |cff%s%d level|r"):format(
        Hex("ACTIVE"), counts.ACTIVE, Hex("AVAILABLE"), counts.AVAILABLE,
        Hex("PREREQ"), counts.PREREQ, Hex("LEVEL"), counts.LEVEL))
    if #entries == 0 then
        frame.empty:Show()
    else
        frame.empty:Hide()
    end
end

--------------------------------------------------------------------------
-- Frame
--------------------------------------------------------------------------
local function SavePosition()
    local point, _, _, x, y = frame:GetPoint()
    local pos = ns.db.frame
    pos.point, pos.x, pos.y = point, x, y
    pos.w, pos.h = frame:GetWidth(), frame:GetHeight()
end

local function CreateScroll(parent)
    for _, template in ipairs({ "ScrollFrameTemplate", "UIPanelScrollFrameTemplate" }) do
        local ok, sf = pcall(CreateFrame, "ScrollFrame", nil, parent, template)
        if ok and sf then return sf, true end
    end
    local sf = CreateFrame("ScrollFrame", nil, parent)
    sf:EnableMouseWheel(true)
    sf:SetScript("OnMouseWheel", function(self, delta)
        local max = math.max(0, content:GetHeight() - self:GetHeight())
        self:SetVerticalScroll(math.min(max, math.max(0, self:GetVerticalScroll() - delta * ROW_H * 3)))
    end)
    return sf, false
end

local function Build()
    local pos = ns.db.frame
    frame = CreateFrame("Frame", "DQT_MainFrame", UIParent, "BackdropTemplate")
    frame:SetSize(pos.w, pos.h)
    frame:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetResizable(true)
    if frame.SetResizeBounds then frame:SetResizeBounds(280, 240, 700, 1000) end
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() SavePosition() end)
    frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    frame:SetBackdropColor(unpack(BG))
    frame:SetBackdropBorderColor(ORANGE[1], ORANGE[2], ORANGE[3], 0.8)
    tinsert(UISpecialFrames, "DQT_MainFrame")

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", PAD, -PAD)
    title:SetText("|cff" .. ns.ACCENT .. "Dungeon Quest Tracker|r")

    frame.subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    -- The template's default handler goes through HideUIPanel, which is blocked in combat.
    close:SetScript("OnClick", function() frame:Hide() end)

    local sf, hasBar = CreateScroll(frame)
    scroll = sf
    scroll:SetPoint("TOPLEFT", PAD, -48)
    scroll:SetPoint("BOTTOMRIGHT", hasBar and -28 or -PAD, 30)

    content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    scroll:HookScript("OnSizeChanged", function(_, w) content:SetWidth(w) end)

    frame.footer = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.footer:SetPoint("BOTTOMLEFT", PAD, PAD)

    frame.empty = frame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    frame.empty:SetPoint("CENTER")
    frame.empty:SetText("No open dungeon quests")

    local grip = CreateFrame("Button", nil, frame)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", -2, 2)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetScript("OnMouseDown", function() frame:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        SavePosition()
        UI.Refresh()
    end)

    frame:SetScript("OnShow", UI.Refresh)
    ns.OnRefresh(UI.Refresh)
end

function UI.Toggle()
    if not frame then Build() frame:Hide() end
    frame:SetShown(not frame:IsShown())
end
