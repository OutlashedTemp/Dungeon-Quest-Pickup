local _, ns = ...

local Map = {}
ns.Map = Map

local PIN_TEMPLATE = "DQP_MapPinTemplate"
local TEX_YELLOW = "Interface\\GossipFrame\\AvailableQuestIcon"
local TEX_BLUE = "Interface\\GossipFrame\\DailyQuestIcon"
local PIN_SIZE, PIN_SIZE_FOCUSED = 16, 26

local provider
local ancestorCache = {}

local function IsAncestor(childMap, ancestorMap)
    local key = childMap .. ":" .. ancestorMap
    if ancestorCache[key] ~= nil then return ancestorCache[key] end
    local result, info, guard = false, C_Map.GetMapInfo(childMap), 0
    while info and info.parentMapID and info.parentMapID ~= 0 and guard < 10 do
        if info.parentMapID == ancestorMap then result = true break end
        info = C_Map.GetMapInfo(info.parentMapID)
        guard = guard + 1
    end
    ancestorCache[key] = result
    return result
end

-- Converts zone coordinates (0-1) to the map currently displayed (zone or continent).
local function Translate(pinMap, x, y, shownMap)
    if pinMap == shownMap then return x, y end
    if not IsAncestor(pinMap, shownMap) then return nil end
    local minX, maxX, minY, maxY = C_Map.GetMapRectOnMap(pinMap, shownMap)
    if not minX or maxX <= minX or maxY <= minY then return nil end
    local nx, ny = minX + x * (maxX - minX), minY + y * (maxY - minY)
    if nx < 0 or nx > 1 or ny < 0 or ny > 1 then return nil end
    return nx, ny
end

local function ShowsPinsOn(mapID)
    local info = C_Map.GetMapInfo(mapID)
    return info and info.mapType and info.mapType >= Enum.UIMapType.Continent
end

--------------------------------------------------------------------------
-- Pin mixin (template defined in Pins.xml)
--------------------------------------------------------------------------
DQP_MapPinMixin = CreateFromMixins(MapCanvasPinMixin or {})

function DQP_MapPinMixin:OnLoad()
    self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI")
    self:SetScalingLimits(1, 1.0, 1.2)
end

function DQP_MapPinMixin:OnAcquired(pin, nx, ny)
    self.pin = pin
    self:SetPosition(nx, ny)
    local focused = Map.focus == pin.id
    local size = focused and PIN_SIZE_FOCUSED or PIN_SIZE
    self:SetSize(size, size)
    self.Icon:SetTexture(pin.kind == "PREREQ" and TEX_BLUE or TEX_YELLOW)
    self.Glow:SetSize(size * 2.6, size * 2.6)
    self.Glow:SetVertexColor(0.945, 0.349, 0.165)
    self.Glow:SetShown(focused)
end

function DQP_MapPinMixin:OnMouseEnter()
    ns.UI.ShowQuestTooltip(self, self.pin.id)
end

function DQP_MapPinMixin:OnMouseLeave()
    GameTooltip:Hide()
end

--------------------------------------------------------------------------
-- Data provider
--------------------------------------------------------------------------
local function CreateProvider()
    local p = CreateFromMixins(MapCanvasDataProviderMixin)

    function p:RemoveAllData()
        self:GetMap():RemoveAllPinsByTemplate(PIN_TEMPLATE)
    end

    function p:RefreshAllData()
        self:RemoveAllData()
        local map = self:GetMap()
        local shownMap = map:GetMapID()
        if not shownMap or not ShowsPinsOn(shownMap) then return end
        for _, pin in ipairs(ns.Engine.GetMapPins()) do
            if ns.db.mapPins or Map.focus == pin.id then
                local nx, ny = Translate(pin.map, pin.x / 100, pin.y / 100, shownMap)
                if nx then
                    map:AcquirePin(PIN_TEMPLATE, pin, nx, ny)
                end
            end
        end
    end

    return p
end

local function Attach()
    if provider or not WorldMapFrame then return end
    provider = CreateProvider()
    WorldMapFrame:AddDataProvider(provider)
    WorldMapFrame:HookScript("OnHide", function()
        Map.focus = nil
    end)
end

function Map.Init()
    if WorldMapFrame then
        Attach()
    elseif EventUtil and EventUtil.ContinueOnAddOnLoaded then
        EventUtil.ContinueOnAddOnLoaded("Blizzard_WorldMap", Attach)
    end
    ns.OnRefresh(Map.Refresh)
end

function Map.Refresh()
    if provider and WorldMapFrame:IsShown() then
        provider:RefreshAllData()
    end
end

local function OpenAt(mapID)
    local ok = pcall(function()
        if OpenWorldMap then
            OpenWorldMap(mapID)
        else
            if not WorldMapFrame:IsShown() then ShowUIPanel(WorldMapFrame) end
            WorldMapFrame:SetMapID(mapID)
        end
    end)
    if not ok then
        ns.Print("couldn't open the world map right now (combat?)")
    end
    return ok
end

local function SetWaypoint(mapID, x, y)
    if not ns.db.setWaypoint or not C_Map.SetUserWaypoint or not UiMapPoint then return end
    if C_Map.CanSetUserWaypointOnMap and not C_Map.CanSetUserWaypointOnMap(mapID) then return end
    pcall(C_Map.SetUserWaypoint, UiMapPoint.CreateFromCoordinates(mapID, x / 100, y / 100))
end

-- Opens the world map on the quest's pickup location and highlights its pin.
function Map.ShowQuest(id)
    local mapID, x, y = ns.Engine.Location(id)
    local q = ns.Data.Quests[id]
    if not mapID then
        if ns.Engine.GiverUnknown(q) then
            ns.Print(("|cffffd100%s|r: questgiver info unknown"):format(q and q.name or "?"))
        elseif ns.Engine.IsInside(q) then
            ns.Print(("|cffffd100%s|r starts inside %s"):format(q.name, ns.Data.Dungeons[q.d].name))
        else
            ns.Print(("no location data for |cffffd100%s|r yet"):format(q and q.name or "?"))
        end
        return
    end
    Map.focus = id
    SetWaypoint(mapID, x, y)
    if OpenAt(mapID) then Map.Refresh() end
end

-- Blue quest: show where the first open prerequisite step is picked up.
function Map.ShowPrereq(id)
    local steps = ns.Engine.OpenSteps(id)
    if #steps == 0 then
        ns.Print("prerequisite is already in your quest log")
        return
    end
    for _, stepId in ipairs(steps) do
        if ns.Engine.Status(stepId) == "AVAILABLE" and ns.Engine.Location(stepId) then
            Map.ShowQuest(stepId)
            return
        end
    end
    local first = ns.Data.Quests[steps[1]]
    local name = first and first.name or "?"
    if first and ns.Engine.Status(steps[1]) == "LEVEL" then
        ns.Print(("prerequisite |cffff4040%s|r requires level %d"):format(name, ns.Engine.MinLevel(first)))
    elseif ns.Engine.GiverUnknown(first) then
        ns.Print(("prerequisite |cffffd100%s|r: questgiver info unknown"):format(name))
    elseif ns.Engine.IsInside(first) then
        ns.Print(("prerequisite |cffffd100%s|r starts inside %s"):format(name, ns.Data.Dungeons[first.d].name))
    else
        ns.Print(("no location data for prerequisite %s yet"):format(name))
    end
end
