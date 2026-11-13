-- ForeverExchange : l'hôtel des ventes de WoW Forever, en jeu.
-- Scan complet de l'HV (C_AuctionHouse.ReplicateItems), historique des prix
-- par objet, valeur marché, prix bas, tendances, infobulles.
-- Consultation uniquement : l'addon n'achète et ne vend rien.
-- Aucune dépendance : les données sont à nous (ForeverExchangeDB).
local ADDON, ns = ...

BINDING_HEADER_FOREVEREXCHANGE = "ForeverExchange"
BINDING_NAME_FOREVEREXCHANGE_TOGGLE = "Ouvrir / fermer ForeverExchange"

local floor, max, min = math.floor, math.max, math.min

local PREFIX = "|cff33ccffForeverExchange|r : "
function ns.Print(msg) DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. msg) end

function ns.Version()
    local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    return (get and get(ADDON, "Version")) or "?"
end


local RECENT_HOURS = 48     -- avant : un point par heure ; après : un point par jour
local KEEP_DAYS = 120       -- historique conservé
local MARKET_SHARE = 0.15   -- valeur marché = moyenne des 15 % d'unités les moins chères

local DEFAULTS = {
    autoScan = true,     -- scan complet à l'ouverture de l'HV quand c'est possible
    tooltip = true,      -- prix dans les infobulles
    compare = false,     -- comparaison avec l'objet équipé dans les infobulles de l'addon
    dealPct = 70,        -- bonne affaire : prix min <= 70 % de la moyenne 30 j
    minValue = 10000,    -- valeur minimale (cuivre) pour affaires / tendances
    minHistory = 3,      -- points d'historique minimum pour l'onglet Prix bas
    minimap = true,      -- bouton de la minicarte
    minimapAngle = 200,  -- position du bouton autour de la minicarte (degrés)
}

ns.LOGO = "Interface\\AddOns\\ForeverExchange\\Logo"

---------------------------------------------------------------------------
-- Formatage
---------------------------------------------------------------------------

function ns.Money(c)
    c = floor(tonumber(c) or 0)
    if c <= 0 then return "|cff808080—|r" end
    if c >= 1000000 then c = c - (c % 10000) end -- au-delà de 100 po, argent/cuivre inutiles
    return GetMoneyString and GetMoneyString(c, true) or tostring(c)
end

-- Version courte (axes du graphique).
function ns.MoneyShort(c)
    c = tonumber(c) or 0
    if c >= 1000000 then return BreakUpLargeNumbers(floor(c / 10000)) .. " po" end
    if c >= 10000 then
        local s = ("%.1f"):format(c / 10000):gsub("%.0$", ""):gsub("%.", ",")
        return s .. " po"
    end
    if c >= 100 then return floor(c / 100) .. " pa" end
    return floor(c) .. " pc"
end

function ns.Ago(t)
    if not t then return "jamais" end
    local d = time() - t
    if d < 60 then return "à l'instant" end
    if d < 3600 then return ("il y a %d min"):format(floor(d / 60)) end
    if d < 86400 then return ("il y a %d h"):format(floor(d / 3600)) end
    return ("il y a %d j"):format(floor(d / 86400))
end

function ns.Pct(x)
    if not x then return "|cff808080—|r" end
    local p = x * 100
    local color = p > 0.5 and "|cff40ff40+" or (p < -0.5 and "|cffff5050" or "|cffcccccc")
    return ("%s%.0f %%|r"):format(color, p)
end

---------------------------------------------------------------------------
-- Objets
---------------------------------------------------------------------------

function ns.Item(id) return ns.house and ns.house.items[id] end

local pendingNames = {}
function ns.Name(id)
    local it = ns.Item(id)
    if it and it.n then return it.n end
    local n = C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
    if n then
        if it then it.n = n end
        return n
    end
    if not pendingNames[id] then
        pendingNames[id] = true
        if C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
    end
    return "Objet #" .. id
end

function ns.Quality(id)
    local it = ns.Item(id)
    if it and it.q then return it.q end
    return C_Item.GetItemQualityByID and C_Item.GetItemQualityByID(id) or 1
end

function ns.ColoredName(id)
    local q = ns.Quality(id) or 1
    local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
    local hex = c and c.hex or "|cffffffff"
    return hex .. ns.Name(id) .. "|r"
end

function ns.Link(id)
    local _, link = C_Item.GetItemInfo(id)
    return link
end

function ns.Icon(id)
    return (C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)) or 134400
end

-- Prix minimum actuel : le plus récent entre le dernier scan complet et la
-- dernière recherche à l'HV. Renvoie prix, date, enVente.
function ns.Current(it)
    local h = ns.house
    if not it then return nil end
    local listed = it.t and h.lastScan and it.t == h.lastScan
    if it.lt and it.lmin and (not it.t or it.lt > it.t) then
        return it.lmin, it.lt, true, it.lqty
    end
    return it.min, it.t, listed, it.qty
end

---------------------------------------------------------------------------
-- Historique : chaîne "heure,min,marché,qté;..." (heures depuis l'epoch)
---------------------------------------------------------------------------

function ns.ParseHistory(h)
    local out = {}
    if not h or h == "" then return out end
    for H, mn, mk, q in h:gmatch("(%d+),(%d+),(%d+),(%d+)") do
        out[#out + 1] = { tonumber(H), tonumber(mn), tonumber(mk), tonumber(q) }
    end
    return out
end

local function Serialize(list)
    local parts = {}
    for i, e in ipairs(list) do
        parts[i] = floor(e[1]) .. "," .. floor(e[2] + 0.5) .. "," .. floor(e[3] + 0.5) .. "," .. floor(e[4])
    end
    return table.concat(parts, ";")
end

-- Points récents : un par heure ; plus vieux que 48 h : un par jour ;
-- plus vieux que 120 jours : supprimés.
local function Compact(list, nowH)
    local out = {}
    local recent = nowH - RECENT_HOURS
    local oldestDay = floor(nowH / 24) - KEEP_DAYS
    for _, e in ipairs(list) do
        local D = floor(e[1] / 24)
        if D >= oldestDay then
            if e[1] < recent then
                local last = out[#out]
                if last and last.day == D then
                    last.n = last.n + 1
                    last[2], last[3] = last[2] + e[2], last[3] + e[3]
                    last[4] = max(last[4], e[4])
                else
                    out[#out + 1] = { D * 24 + 12, e[2], e[3], e[4], day = D, n = 1 }
                end
            else
                out[#out + 1] = e
            end
        end
    end
    for _, e in ipairs(out) do
        if e.n then
            e[2], e[3] = e[2] / e.n, e[3] / e.n
            e.n, e.day = nil, nil
        end
    end
    return out
end

-- Moyennes 7 / 30 j de la valeur marché et évolution sur 7 j.
local function Stats(list, nowH)
    local s7, n7, s30, n30, base = 0, 0, 0, 0, nil
    for _, e in ipairs(list) do
        local age = nowH - e[1]
        if age <= 30 * 24 then s30, n30 = s30 + e[3], n30 + 1 end
        if age <= 7 * 24 then
            s7, n7 = s7 + e[3], n7 + 1
            base = base or e
        end
    end
    local last = list[#list]
    local ch7
    if base and last and last[1] - base[1] >= 24 and base[3] > 0 then
        ch7 = (last[3] - base[3]) / base[3]
    end
    return n7 > 0 and floor(s7 / n7) or nil, n30 > 0 and floor(s30 / n30) or nil, ch7, #list
end

-- pl : { {prixUnitaire, qté}, ... } trié par prix croissant.
local function Market(pl)
    local total = 0
    for _, p in ipairs(pl) do total = total + p[2] end
    local target = max(1, math.ceil(total * MARKET_SHARE))
    local acc, sum = 0, 0
    for _, p in ipairs(pl) do
        local take = min(p[2], target - acc)
        sum, acc = sum + take * p[1], acc + take
        if acc >= target then break end
    end
    return sum / acc, total
end

---------------------------------------------------------------------------
-- Base de données
---------------------------------------------------------------------------

-- WoW Forever est sans royaume ; on garde quand même royaume + faction au cas
-- où les HV seraient séparés.
function ns.HouseKey()
    return (GetRealmName() or "?") .. " - " .. (UnitFactionGroup("player") or "Neutral")
end

local function InitDB()
    ForeverExchangeDB = ForeverExchangeDB or {}
    local db = ForeverExchangeDB
    db.settings = db.settings or {}
    for k, v in pairs(DEFAULTS) do
        if db.settings[k] == nil then db.settings[k] = v end
    end
    db.favorites = db.favorites or {}
    db.houses = db.houses or {}
    local key = ns.HouseKey()
    db.houses[key] = db.houses[key] or { items = {}, scanCount = 0 }
    ns.db, ns.settings, ns.house = db, db.settings, db.houses[key]
end

function ns.IsFavorite(id) return ns.db and ns.db.favorites[id] and true or false end
function ns.ToggleFavorite(id)
    ns.db.favorites[id] = (not ns.db.favorites[id]) or nil
    ns.Notify()
end

-- L'UI s'abonne ici pour se rafraîchir.
function ns.Notify(what)
    if ns.OnDataChanged then ns.OnDataChanged(what) end
end

---------------------------------------------------------------------------
-- Scan complet
---------------------------------------------------------------------------

local scan = { state = "idle", progress = 0 }  -- idle / waiting / reading / processing
ns.scan = scan

-- Pas de délai imposé par l'addon : seule une analyse en cours bloque le bouton.
function ns.ScanWait() return 0 end

function ns.CanScan()
    if not ns.ahOpen then return false, "Ouvre l'hôtel des ventes pour lancer une analyse." end
    if scan.state ~= "idle" then return false, "Analyse en cours…" end
    return true
end

function ns.IsScanning() return scan.state ~= "idle" end

function ns.StartScan(silent)
    local ok, why = ns.CanScan()
    if not ok then
        if not silent then ns.Print(why) end
        return
    end
    ns.BeginWaiting(true)
    C_AuctionHouse.ReplicateItems()
end

local StartReading, StartBrowseScan, StartProcessing

-- Une analyse complète a été demandée (par nous ou par un autre addon, ex.
-- Auctionator) : on attend que le serveur envoie la liste pour la lire.
-- En plus du signal REPLICATE_ITEM_LIST_UPDATE, on regarde chaque seconde si
-- la liste est arrivée (au cas où le signal serait manqué).
function ns.BeginWaiting(ours)
    scan.state, scan.progress = "waiting", 0
    local token = {}
    scan.token = token
    ns.db.lastReplicate = time()
    if ours then
        ns.Print("Analyse de l'hôtel des ventes lancée, le serveur prépare la liste…")
    else
        ns.Print("Analyse lancée par un autre addon : ForeverExchange lit aussi les données.")
    end
    ns.Notify("scan")

    local before = C_AuctionHouse.GetNumReplicateItems() or 0
    local lastN, stable, elapsed = -1, 0, 0
    local ticker
    ticker = C_Timer.NewTicker(1, function()
        if scan.state ~= "waiting" or scan.token ~= token then
            ticker:Cancel()
            return
        end
        elapsed = elapsed + 1
        local n = C_AuctionHouse.GetNumReplicateItems() or 0
        stable = (n == lastN) and stable + 1 or 0
        lastN = n
        -- Liste nouvelle (taille différente) et stable, ou liste présente depuis un moment.
        if n > 0 and ((n ~= before and stable >= 2) or (elapsed >= 15 and stable >= 3)) then
            ticker:Cancel()
            StartReading(ours)
        elseif elapsed >= 10 and n == 0 then
            -- Le serveur de WoW Forever n'envoie pas la liste complète : on passe
            -- par une recherche vide à l'HV, page après page.
            ticker:Cancel()
            StartBrowseScan()
        end
    end)
end

---------------------------------------------------------------------------
-- Analyse par recherche : recherche vide à l'HV (comme « Rechercher » sans
-- texte), on demande toutes les pages de résultats. Donne pour chaque objet
-- le prix minimum et la quantité totale en vente.
---------------------------------------------------------------------------

local function SendFullBrowse()
    scan.lastBrowseEvent = GetTime()
    local sortOrder = Enum.AuctionHouseSortOrder and Enum.AuctionHouseSortOrder.Name or 1
    C_AuctionHouse.SendBrowseQuery({
        searchString = "",
        sorts = { { sortOrder = sortOrder, reverseSort = false } },
        filters = {},
        itemClassFilters = {},
    })
end

local function ThrottleReady()
    return not C_AuctionHouse.IsThrottledMessageSystemReady or C_AuctionHouse.IsThrottledMessageSystemReady()
end

local function CollectBrowse()
    local ok, results = pcall(C_AuctionHouse.GetBrowseResults)
    if not ok or type(results) ~= "table" then results = {} end
    for _, r in ipairs(results) do
        local id = r.itemKey and r.itemKey.itemID
        local qty = r.totalQuantity or 0
        if id and r.minPrice and r.minPrice > 0 and qty > 0 then
            local a = scan.agg[id]
            if not a then
                a = {}
                scan.agg[id] = a
                scan.meta[id] = {}
            end
            a[#a + 1] = r.minPrice
            a[#a + 1] = qty
            scan.auctions = scan.auctions + qty
        end
    end
    if next(scan.agg) == nil then
        scan.state = "idle"
        ns.Print("L'hôtel des ventes n'a renvoyé aucun objet : analyse annulée.")
        ns.Notify("scan")
        return
    end
    StartProcessing()
end

local function BrowseStep()
    if scan.state ~= "browsing" then return end
    if scan.needSend then
        if not ThrottleReady() then return end
        scan.needSend = false
        SendFullBrowse()
        return
    end
    if not scan.gotFirst then return end -- attendre la réponse à notre recherche
    if C_AuctionHouse.HasFullBrowseResults() then
        CollectBrowse()
    elseif ThrottleReady() then
        scan.lastBrowseEvent = GetTime()
        C_AuctionHouse.RequestMoreBrowseResults()
    end
end
ns.BrowseStep = BrowseStep

StartBrowseScan = function()
    if not ns.ahOpen then
        scan.state = "idle"
        ns.Notify("scan")
        return
    end
    scan.state, scan.progress = "browsing", 0.02
    scan.agg, scan.meta, scan.auctions = {}, {}, 0
    scan.browseCount, scan.needSend, scan.gotFirst = 0, true, false
    scan.lastBrowseEvent = GetTime()
    ns.Print("Lecture de tous les objets en vente…")
    ns.Notify("scan")
    BrowseStep()
    -- Surveillance : relance si le serveur était occupé, termine si plus rien n'arrive.
    local ticker
    ticker = C_Timer.NewTicker(1, function()
        if scan.state ~= "browsing" then
            ticker:Cancel()
            return
        end
        if GetTime() - scan.lastBrowseEvent > 20 then
            ticker:Cancel()
            CollectBrowse()
        else
            BrowseStep()
        end
    end)
end

-- Nouvelle page de résultats reçue pendant l'analyse par recherche.
function ns.OnBrowseScanEvent()
    if scan.state ~= "browsing" or scan.needSend then return end
    scan.gotFirst = true
    scan.lastBrowseEvent = GetTime()
    local ok, results = pcall(C_AuctionHouse.GetBrowseResults)
    scan.browseCount = ok and type(results) == "table" and #results or scan.browseCount
    local expected = max(2000, (ns.house.lastItems or 0) * 1.1)
    scan.progress = min(0.58, 0.02 + 0.56 * scan.browseCount / expected)
    ns.Notify("progress")
    BrowseStep()
end

if C_AuctionHouse and C_AuctionHouse.ReplicateItems then
    hooksecurefunc(C_AuctionHouse, "ReplicateItems", function()
        if not ns.db then return end
        if scan.state == "idle" then ns.BeginWaiting(false) end
    end)
end

local ProcessBatch

local function Finish()
    local h = ns.house
    h.lastScan = scan.now
    h.scanCount = (h.scanCount or 0) + 1
    h.lastAuctions, h.lastItems = scan.auctions, scan.itemCount
    if scan.compact then h.lastCompactDay = floor(scan.now / 86400) end
    scan.state, scan.progress, scan.lastDone = "idle", 1, time()
    scan.agg, scan.meta, scan.ids = nil, nil, nil
    ns.Print(("Analyse terminée : %s enchères, %s objets différents.")
        :format(BreakUpLargeNumbers(h.lastAuctions), BreakUpLargeNumbers(h.lastItems)))
    ns.Notify("scan")
end

StartProcessing = function()
    local h = ns.house
    scan.state = "processing"
    scan.now = time()
    scan.nowH = floor(scan.now / 3600)
    scan.compact = (h.lastCompactDay or 0) < floor(scan.now / 86400)
    local ids, n = {}, 0
    for id in pairs(h.items) do ids[#ids + 1] = id end
    for id in pairs(scan.agg) do
        n = n + 1
        if not h.items[id] then
            h.items[id] = {}
            ids[#ids + 1] = id
        end
    end
    scan.itemCount = n
    scan.ids, scan.j = ids, 1
    ProcessBatch()
end

ProcessBatch = function()
    if scan.state ~= "processing" then return end
    local h, nowH = ns.house, scan.nowH
    local stop = min(scan.j + 400 - 1, #scan.ids)
    for j = scan.j, stop do
        local id = scan.ids[j]
        local it = h.items[id]
        local a = scan.agg[id]
        local list
        if a then
            local pl = {}
            for k = 1, #a, 2 do pl[#pl + 1] = { a[k], a[k + 1] } end
            table.sort(pl, function(x, y) return x[1] < y[1] end)
            local mkt, qty = Market(pl)
            local meta = scan.meta[id]
            if meta[1] then it.n = meta[1] end
            if meta[2] then it.q = meta[2] end
            it.t, it.min, it.mkt, it.qty, it.auc = scan.now, floor(pl[1][1]), floor(mkt), qty, #pl
            list = ns.ParseHistory(it.h)
            local last = list[#list]
            local point = { nowH, it.min, it.mkt, qty }
            if last and last[1] == nowH then list[#list] = point else list[#list + 1] = point end
        elseif scan.compact and it.h then
            list = ns.ParseHistory(it.h)
        end
        if list then
            list = Compact(list, nowH)
            if #list == 0 and (not it.lt or scan.now - it.lt > KEEP_DAYS * 86400) then
                h.items[id] = nil
            else
                it.h = Serialize(list)
                it.a7, it.a30, it.ch7, it.np = Stats(list, nowH)
            end
        end
    end
    scan.j = stop + 1
    scan.progress = 0.6 + 0.4 * (stop / max(1, #scan.ids))
    ns.Notify("progress")
    if stop >= #scan.ids then Finish() else C_Timer.After(0, ProcessBatch) end
end

local function ReadBatch()
    if scan.state ~= "reading" then return end
    local GetInfo = C_AuctionHouse.GetReplicateItemInfo
    local stop = min(scan.i + 2000, scan.n)
    for i = scan.i, stop - 1 do
        local name, _, count, quality, _, _, _, _, _, buyout, _, _, _, _, _, _, itemID = GetInfo(i)
        if itemID and count and count > 0 and buyout and buyout > 0 then
            local a = scan.agg[itemID]
            if not a then
                a = {}
                scan.agg[itemID] = a
                scan.meta[itemID] = { name, quality }
            elseif name and not scan.meta[itemID][1] then
                scan.meta[itemID][1] = name
            end
            a[#a + 1] = buyout / count
            a[#a + 1] = count
            scan.auctions = scan.auctions + 1
        end
    end
    scan.i = stop
    scan.progress = 0.6 * stop / scan.n
    ns.Notify("progress")
    if stop >= scan.n then StartProcessing() else C_Timer.After(0, ReadBatch) end
end

StartReading = function()
    local n = C_AuctionHouse.GetNumReplicateItems() or 0
    if n == 0 then return false end -- liste pas encore prête : on continue d'attendre
    scan.n = n
    scan.state, scan.i, scan.auctions = "reading", 0, 0
    scan.agg, scan.meta = {}, {}
    ns.Print(("Lecture de %s enchères…"):format(BreakUpLargeNumbers(n)))
    ReadBatch()
    return true
end

local function OnReplicate()
    if scan.state == "waiting" then
        StartReading()
    elseif scan.state == "idle" and ns.ahOpen and time() - (scan.lastDone or 0) > 60 then
        -- Analyse lancée sans passer par C_AuctionHouse.ReplicateItems (cas improbable).
        ns.db.lastReplicate = time()
        StartReading()
    end
end

-- Résultats des recherches faites à l'HV (dont les marchandises) : prix
-- minimum en direct, sans attendre le prochain scan.
local function OnBrowse()
    if not ns.house then return end
    local ok, results = pcall(C_AuctionHouse.GetBrowseResults)
    if not ok or type(results) ~= "table" then return end
    local now = time()
    for _, r in ipairs(results) do
        local id = r.itemKey and r.itemKey.itemID
        if id and r.minPrice and r.minPrice > 0 then
            local it = ns.house.items[id]
            if not it then
                it = {}
                ns.house.items[id] = it
            end
            it.lt, it.lmin, it.lqty = now, r.minPrice, r.totalQuantity
        end
    end
    ns.Notify("browse")
end

---------------------------------------------------------------------------
-- Infobulles
---------------------------------------------------------------------------

local TAG = "|cff33ccffFX|r "

local function AddTooltip(tt, id)
    if not ns.settings or not ns.settings.tooltip then return end
    local it = ns.Item(id)
    if not it or not (it.min or it.lmin) then return end
    local cur, t, listed = ns.Current(it)
    tt:AddDoubleLine(TAG .. "Prix min" .. (listed and "" or " |cff808080(" .. ns.Ago(t) .. ")|r"),
        ns.Money(cur), 1, 0.82, 0, 1, 1, 1)
    if it.mkt then tt:AddDoubleLine(TAG .. "Valeur marché", ns.Money(it.mkt), 1, 0.82, 0, 1, 1, 1) end
    if it.a30 then
        tt:AddDoubleLine(TAG .. "Moyenne 30 j", ns.Money(it.a30) .. "  " .. ns.Pct(it.ch7) .. " |cff8080807 j|r",
            1, 0.82, 0, 1, 1, 1)
    end
end

local function HookTooltips()
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt, data)
            if not tt or not tt.AddDoubleLine or tt.fxNoPrice then return end
            local id = data and data.id
            if not id or (issecretvalue and issecretvalue(id)) then return end
            pcall(AddTooltip, tt, id)
        end)
    elseif GameTooltip:HasScript("OnTooltipSetItem") then
        GameTooltip:HookScript("OnTooltipSetItem", function(tt)
            local _, link = tt:GetItem()
            local id = link and tonumber(link:match("item:(%d+)"))
            if id then pcall(AddTooltip, tt, id) end
        end)
    end
end

---------------------------------------------------------------------------
-- Événements
---------------------------------------------------------------------------

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("AUCTION_HOUSE_SHOW")
ev:RegisterEvent("AUCTION_HOUSE_CLOSED")
ev:RegisterEvent("REPLICATE_ITEM_LIST_UPDATE")
ev:RegisterEvent("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
ev:RegisterEvent("AUCTION_HOUSE_BROWSE_RESULTS_ADDED")
ev:RegisterEvent("AUCTION_HOUSE_THROTTLED_SYSTEM_READY")
ev:RegisterEvent("GET_ITEM_INFO_RECEIVED")

local namesDirty = false
ev:SetScript("OnEvent", function(_, event, arg1, arg2)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        InitDB()
    elseif event == "PLAYER_LOGIN" then
        HookTooltips()
        if ns.CreateOptions then ns.CreateOptions() end
        if ns.UpdateMinimapButton then ns.UpdateMinimapButton() end
    elseif event == "AUCTION_HOUSE_SHOW" then
        ns.ahOpen = true
        if ns.OnAHShow then ns.OnAHShow() end
        -- Recopie des catégories de l'HV (avec sous-catégories) pour les avoir partout.
        C_Timer.After(0.5, function()
            if ns.CaptureCategories and ns.CaptureCategories() then ns.Notify("categories") end
        end)
        if ns.settings.autoScan then
            C_Timer.After(2, function()
                if ns.ahOpen and ns.CanScan() then ns.StartScan(true) end
            end)
        end
        ns.Notify("ah")
    elseif event == "AUCTION_HOUSE_CLOSED" then
        ns.ahOpen = false
        if scan.state == "waiting" or scan.state == "reading" or scan.state == "browsing" then
            scan.state, scan.agg, scan.meta = "idle", nil, nil
            ns.Print("HV fermé pendant l'analyse : analyse annulée.")
        end
        ns.Notify("ah")
    elseif event == "REPLICATE_ITEM_LIST_UPDATE" then
        OnReplicate()
    elseif event == "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED" or event == "AUCTION_HOUSE_BROWSE_RESULTS_ADDED" then
        OnBrowse()
        ns.OnBrowseScanEvent()
    elseif event == "AUCTION_HOUSE_THROTTLED_SYSTEM_READY" then
        if scan.state == "browsing" then ns.BrowseStep() end
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        if pendingNames[arg1] and arg2 ~= false then
            pendingNames[arg1] = nil
            local it = ns.Item(arg1)
            if it and not it.n then it.n = C_Item.GetItemNameByID(arg1) end
            if not namesDirty then
                namesDirty = true
                C_Timer.After(0.5, function()
                    namesDirty = false
                    ns.Notify("names")
                end)
            end
        end
    end
end)

---------------------------------------------------------------------------
-- Commandes
---------------------------------------------------------------------------

function ForeverExchange_Toggle()
    if ns.Toggle then ns.Toggle() end
end

SLASH_FOREVEREXCHANGE1 = "/fx"
SLASH_FOREVEREXCHANGE2 = "/fexchange"
SlashCmdList.FOREVEREXCHANGE = function(msg)
    msg = strtrim(msg or "")
    local cmd = msg:lower()
    if cmd == "" then
        ForeverExchange_Toggle()
    elseif cmd == "options" or cmd == "config" then
        if ns.OpenOptions then ns.OpenOptions() end
    elseif cmd == "scan" then
        ns.StartScan(false)
    elseif cmd == "infobulle" or cmd == "tooltip" then
        ns.settings.tooltip = not ns.settings.tooltip
        ns.Print("Prix dans les infobulles : " .. (ns.settings.tooltip and "activés" or "désactivés"))
        ns.Notify("settings")
    elseif cmd == "auto" then
        ns.settings.autoScan = not ns.settings.autoScan
        ns.Print("Analyse automatique à l'ouverture de l'HV : " .. (ns.settings.autoScan and "activé" or "désactivé"))
        ns.Notify("settings")
    elseif cmd == "aide" or cmd == "help" then
        ns.Print("v" .. ns.Version() .. " — /fx : fenêtre · /fx options : options · /fx scan : analyser l'HV · /fx <objet> : chercher"
            .. " · /fx auto : analyse auto on/off · /fx infobulle : prix dans les infobulles on/off")
    else
        if ns.Show then ns.Show() end
        if ns.SearchFor then ns.SearchFor(msg) end
    end
end
