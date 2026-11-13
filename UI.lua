-- ForeverExchange : fenêtre au style de l'hôtel des ventes de WoW Forever.
-- Portrait, barre de recherche (favoris, recherche, filtre), catégories à
-- gauche, liste triable à droite, fiche objet avec graphique, onglets en bas.
-- Consultation des prix uniquement : aucun achat ni vente.
local ADDON, ns = ...

local floor, max, min = math.floor, math.max, math.min

local W, H = 830, 560
local CAT_W = 182
local ROW_H = 22
local TOP = -64      -- haut des zones de contenu (sous la barre de recherche)
local BOTTOM = 30    -- bas des zones de contenu (au-dessus du pied)

local frame
local pages, tabs = {}, {}
local currentTab = 1

---------------------------------------------------------------------------
-- Textures de l'HV (atlas) avec repli si l'atlas n'existe pas
---------------------------------------------------------------------------

local function HasAtlas(name)
    return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) ~= nil
end

local function Atlas(tex, atlas, fallback)
    if HasAtlas(atlas) then
        tex:SetAtlas(atlas)
        return true
    end
    if fallback then fallback(tex) end
    return false
end

-- Comparaison avec l'objet équipé dans les infobulles de l'addon (option).
function ns.ApplyCompare(tt)
    if ns.settings and ns.settings.compare then
        if GameTooltip_ShowCompareItem then pcall(GameTooltip_ShowCompareItem, tt) end
    else
        if GameTooltip_HideShoppingTooltips then
            pcall(GameTooltip_HideShoppingTooltips, tt)
        end
        local function Hide()
            for _, st in ipairs(tt.shoppingTooltips or { ShoppingTooltip1, ShoppingTooltip2 }) do
                if st then st:Hide() end
            end
        end
        Hide()
        C_Timer.After(0, Hide) -- au cas où le jeu l'affiche une image plus tard
    end
end

local function SetStar(tex, on)
    if HasAtlas("auctionhouse-icon-favorite") then
        tex:SetAtlas(on and "auctionhouse-icon-favorite" or "auctionhouse-icon-favorite-off")
    else
        tex:SetTexture("Interface\\Common\\ReputationStar")
        if on then tex:SetTexCoord(0, 0.5, 0, 0.5) else tex:SetTexCoord(0.5, 1, 0, 0.5) end
    end
end

local function Inset(parent)
    local ok, f = pcall(CreateFrame, "Frame", nil, parent, "InsetFrameTemplate")
    if ok and f then return f end
    f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    f:SetBackdropColor(0, 0, 0, 0.4)
    f:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.6)
    return f
end

---------------------------------------------------------------------------
-- Recherche insensible aux accents, catégories des objets
---------------------------------------------------------------------------

local ACCENTS = {
    ["à"] = "a", ["â"] = "a", ["ä"] = "a", ["á"] = "a", ["ç"] = "c",
    ["é"] = "e", ["è"] = "e", ["ê"] = "e", ["ë"] = "e", ["î"] = "i", ["ï"] = "i", ["í"] = "i",
    ["ô"] = "o", ["ö"] = "o", ["ó"] = "o", ["ù"] = "u", ["û"] = "u", ["ü"] = "u", ["ú"] = "u",
    ["ñ"] = "n", ["œ"] = "oe", ["æ"] = "ae",
    ["À"] = "a", ["Â"] = "a", ["Ä"] = "a", ["Ç"] = "c", ["É"] = "e", ["È"] = "e", ["Ê"] = "e",
    ["Ë"] = "e", ["Î"] = "i", ["Ï"] = "i", ["Ô"] = "o", ["Ö"] = "o", ["Ù"] = "u", ["Û"] = "u",
    ["Ü"] = "u", ["Œ"] = "oe",
}
local function Normalize(s)
    s = s:gsub("[\195\197][\128-\191]", ACCENTS)
    return s:lower()
end

local normCache = {}
local function NormName(id)
    local n = ns.Name(id)
    local c = normCache[id]
    if c and c[1] == n then return c[2] end
    local v = Normalize(n)
    normCache[id] = { n, v }
    return v
end


---------------------------------------------------------------------------
-- Petits widgets
---------------------------------------------------------------------------

local function Button(parent, text, w, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w, 22)
    b:SetText(text)
    if onClick then b:SetScript("OnClick", onClick) end
    return b
end

local function Label(parent, font, text)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    if text then fs:SetText(text) end
    return fs
end

local function StarButton(parent, size, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size, size)
    b.tex = b:CreateTexture(nil, "ARTWORK")
    b.tex:SetAllPoints()
    b:SetScript("OnClick", onClick)
    function b:SetOn(on)
        SetStar(self.tex, on)
        self.tex:SetAlpha(on and 1 or 0.45)
        self.on = on
    end
    b:SetScript("OnEnter", function(self) self.tex:SetAlpha(1) end)
    b:SetScript("OnLeave", function(self) self.tex:SetAlpha(self.on and 1 or 0.45) end)
    b:SetOn(false)
    return b
end

---------------------------------------------------------------------------
-- Liste virtuelle triable (en-têtes et lignes façon HV)
-- columns : { {key, label, width, fmt(entry)} } ; la 1re colonne (objet) est flexible
---------------------------------------------------------------------------

local function HeaderButton(parent)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(22)
    local tex = "Interface\\FriendsFrame\\WhoFrame-ColumnTabs"
    local l = b:CreateTexture(nil, "BACKGROUND")
    l:SetTexture(tex)
    l:SetTexCoord(0, 0.078125, 0, 0.75)
    l:SetSize(5, 22)
    l:SetPoint("TOPLEFT")
    local r = b:CreateTexture(nil, "BACKGROUND")
    r:SetTexture(tex)
    r:SetTexCoord(0.90625, 0.96875, 0, 0.75)
    r:SetSize(4, 22)
    r:SetPoint("TOPRIGHT")
    local m = b:CreateTexture(nil, "BACKGROUND")
    m:SetTexture(tex)
    m:SetTexCoord(0.078125, 0.90625, 0, 0.75)
    m:SetPoint("TOPLEFT", l, "TOPRIGHT")
    m:SetPoint("BOTTOMRIGHT", r, "BOTTOMLEFT")
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-Tab-Highlight")
    hl:SetBlendMode("ADD")
    hl:SetPoint("TOPLEFT", 2, 4)
    hl:SetPoint("BOTTOMRIGHT", -2, -6)
    b.fs = Label(b, "GameFontHighlightSmall")
    b.arrow = b:CreateTexture(nil, "OVERLAY")
    b.arrow:SetSize(9, 8)
    Atlas(b.arrow, "auctionhouse-ui-sortarrow", function(t)
        t:SetTexture("Interface\\Buttons\\UI-SortArrow")
        t:SetSize(9, 8)
        t:SetTexCoord(0, 0.5625, 0, 1)
    end)
    return b
end

local function CreateTable(parent, columns, defaultSort, defaultDesc, onClick)
    local t = CreateFrame("Frame", nil, parent)
    t.entries, t.rows, t.offset = {}, {}, 0
    t.sortKey, t.sortDesc = defaultSort, defaultDesc

    -- Décalages des colonnes depuis la droite
    local rights, acc = {}, 0
    for i = #columns, 2, -1 do
        rights[i] = -acc
        acc = acc + columns[i].width
    end
    rights[1] = -acc

    local header = CreateFrame("Frame", nil, t)
    header:SetPoint("TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", -12, 0)
    header:SetHeight(22)

    t.headers = {}
    for i, col in ipairs(columns) do
        local b = HeaderButton(header)
        if i == 1 then
            b:SetPoint("TOPLEFT", 0, 0)
            b:SetPoint("TOPRIGHT", header, "TOPRIGHT", rights[1], 0)
            b.fs:SetPoint("LEFT", 8, 0)
            b.fs:SetJustifyH("LEFT")
        else
            b:SetPoint("TOPRIGHT", header, "TOPRIGHT", rights[i], 0)
            b:SetWidth(col.width)
            b.fs:SetPoint("RIGHT", -8, 0)
            b.fs:SetJustifyH("RIGHT")
        end
        b.fs:SetText(col.label)
        b.arrow:SetPoint("LEFT", b.fs, "RIGHT", 3, 0)
        if i ~= 1 then
            b.arrow:ClearAllPoints()
            b.arrow:SetPoint("RIGHT", b.fs, "LEFT", -3, 0)
        end
        b:SetScript("OnClick", function()
            if t.sortKey == col.key then t.sortDesc = not t.sortDesc
            else t.sortKey, t.sortDesc = col.key, i ~= 1 end
            t:Sort()
        end)
        b.key = col.key
        t.headers[i] = b
    end

    local function UpdateHeaders()
        for _, b in ipairs(t.headers) do
            b.arrow:SetShown(b.key == t.sortKey)
            b.arrow:SetRotation(t.sortDesc and 0 or math.pi)
        end
    end

    local body = CreateFrame("Frame", nil, t)
    body:SetPoint("TOPLEFT", 0, -24)
    body:SetPoint("BOTTOMRIGHT", -12, 0)
    body:EnableMouseWheel(true)
    t.body = body

    t.empty = Label(body, "GameFontDisable")
    t.empty:SetPoint("TOP", 0, -40)
    t.empty:SetPoint("LEFT", 20, 0)
    t.empty:SetPoint("RIGHT", -20, 0)

    -- Barre de défilement fine
    local sb = CreateFrame("Slider", nil, t)
    sb:SetPoint("TOPRIGHT", 0, -24)
    sb:SetPoint("BOTTOMRIGHT", 0, 0)
    sb:SetWidth(8)
    sb:SetOrientation("VERTICAL")
    local sbg = sb:CreateTexture(nil, "BACKGROUND")
    sbg:SetAllPoints()
    sbg:SetColorTexture(0, 0, 0, 0.4)
    local thumb = sb:CreateTexture(nil, "OVERLAY")
    thumb:SetColorTexture(0.75, 0.62, 0.3, 0.9)
    thumb:SetSize(8, 36)
    sb:SetThumbTexture(thumb)
    sb:SetMinMaxValues(0, 0)
    sb:SetValueStep(1)
    if sb.SetObeyStepOnDrag then sb:SetObeyStepOnDrag(true) end
    sb:SetScript("OnValueChanged", function(_, v)
        v = floor(v + 0.5)
        if v ~= t.offset then
            t.offset = v
            t:Refresh()
        end
    end)
    t.sb = sb
    body:SetScript("OnMouseWheel", function(_, delta) sb:SetValue(t.offset - delta * 3) end)

    local function Row(i)
        local r = t.rows[i]
        if r then return r end
        r = CreateFrame("Button", nil, body)
        r:SetHeight(ROW_H)
        r:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
        r:SetPoint("TOPRIGHT", 0, -(i - 1) * ROW_H)
        local stripe = r:CreateTexture(nil, "BACKGROUND")
        stripe:SetAllPoints()
        Atlas(stripe, i % 2 == 1 and "auctionhouse-rowstripe-1" or "auctionhouse-rowstripe-2", function(tx)
            tx:SetColorTexture(1, 1, 1, i % 2 == 0 and 0.04 or 0)
        end)
        -- Surbrillance translucide (calque HIGHLIGHT = au-dessus du texte) :
        -- mélange additif et opacité réduite pour garder la ligne lisible.
        local hl = r:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        Atlas(hl, "auctionhouse-ui-row-highlight", function(tx)
            tx:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        end)
        hl:SetBlendMode("ADD")
        hl:SetAlpha(0.35)

        r.star = StarButton(r, 14, function(self)
            if self:GetParent().id then ns.ToggleFavorite(self:GetParent().id) end
        end)
        r.star:SetPoint("LEFT", 4, 0)
        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetSize(ROW_H - 4, ROW_H - 4)
        r.icon:SetPoint("LEFT", 22, 0)

        r.cells = {}
        for c, col in ipairs(columns) do
            local fs = Label(r, "GameFontHighlightSmall")
            fs:SetWordWrap(false)
            if c == 1 then
                fs:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
                fs:SetPoint("RIGHT", r, "RIGHT", rights[1] - 4, 0)
                fs:SetJustifyH("LEFT")
            else
                fs:SetPoint("RIGHT", r, "RIGHT", rights[c] - 8, 0)
                fs:SetWidth(col.width - 12)
                fs:SetJustifyH("RIGHT")
            end
            r.cells[c] = fs
        end

        r:SetScript("OnEnter", function(self)
            if not self.id then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetItemByID(self.id)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("Clic : détails et historique · Maj+clic : lien dans le chat", 0.6, 0.6, 0.6)
            GameTooltip:Show()
            ns.ApplyCompare(GameTooltip)
        end)
        r:SetScript("OnLeave", GameTooltip_Hide)
        r:SetScript("OnClick", function(self)
            if not self.id then return end
            if IsModifiedClick() then
                local link = ns.Link(self.id)
                if link then HandleModifiedItemClick(link) end
            elseif onClick then
                onClick(self.id)
            end
        end)
        t.rows[i] = r
        return r
    end

    function t:Visible() return max(1, floor(body:GetHeight() / ROW_H)) end

    function t:Refresh()
        local vis = self:Visible()
        local n = #self.entries
        local maxOff = max(0, n - vis)
        self.sb:SetMinMaxValues(0, maxOff)
        self.sb:SetShown(maxOff > 0)
        if self.offset > maxOff then self.offset = maxOff end
        for i = 1, vis do
            local e = self.entries[self.offset + i]
            local r = Row(i)
            if e then
                r.id = e.id
                r.icon:SetTexture(ns.Icon(e.id))
                r.star:SetOn(ns.IsFavorite(e.id))
                for c, col in ipairs(columns) do r.cells[c]:SetText(col.fmt(e)) end
                r:Show()
            else
                r.id = nil
                r:Hide()
            end
        end
        for i = vis + 1, #self.rows do self.rows[i]:Hide() end
        self.empty:SetShown(n == 0)
    end

    function t:Sort()
        local key, desc = self.sortKey, self.sortDesc
        table.sort(self.entries, function(a, b)
            local x, y = a[key], b[key]
            if x == y then return a.id < b.id end
            if x == nil then return false end
            if y == nil then return true end
            if desc then return x > y end
            return x < y
        end)
        UpdateHeaders()
        self:Refresh()
    end

    function t:Set(entries, emptyText)
        self.entries = entries
        self.empty:SetText(emptyText or "")
        self:Sort()
    end

    function t:ResetScroll()
        self.offset = 0
        self.sb:SetValue(0)
    end

    body:SetScript("OnSizeChanged", function() t:Refresh() end)
    UpdateHeaders()
    return t
end

local function ItemCol(e)
    local s = ns.ColoredName(e.id)
    if e.listed == false then s = s .. " |cff808080(absent)|r" end
    return s
end

local function Entry(id, it)
    local cur, _, listed, qty = ns.Current(it)
    return {
        id = id, name = NormName(id), min = cur, mkt = it.mkt,
        qty = listed and qty or 0, a7 = it.a7, a30 = it.a30, ch7 = it.ch7,
        listed = listed and true or false,
    }
end

---------------------------------------------------------------------------
-- Liste des catégories (à gauche, comme l'HV)
---------------------------------------------------------------------------

local BTN_H = 21

local function CreateCategories(parent, onSelect)
    local c = CreateFrame("Frame", nil, parent)
    c.buttons, c.offset, c.list = {}, 0, {}
    c:EnableMouseWheel(true)

    local bg = c:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    Atlas(bg, "auctionhouse-background-index", function(t) t:SetColorTexture(0, 0, 0, 0.25) end)

    local function Btn(i)
        local b = c.buttons[i]
        if b then return b end
        b = CreateFrame("Button", nil, c)
        b:SetHeight(BTN_H - 1)
        b:SetPoint("TOPLEFT", 4, -4 - (i - 1) * BTN_H)
        b:SetPoint("TOPRIGHT", -4, -4 - (i - 1) * BTN_H)
        b.normal = b:CreateTexture(nil, "BACKGROUND")
        b.normal:SetAllPoints()
        b.sel = b:CreateTexture(nil, "ARTWORK")
        b.sel:SetAllPoints()
        Atlas(b.sel, "auctionhouse-nav-button-select", function(t)
            t:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-Tab-Highlight")
            t:SetBlendMode("ADD")
        end)
        local hl = b:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        Atlas(hl, "auctionhouse-nav-button-highlight", function(t)
            t:SetTexture("Interface\\PaperDollInfoFrame\\UI-Character-Tab-Highlight")
            t:SetBlendMode("ADD")
        end)
        b.star = b:CreateTexture(nil, "OVERLAY")
        b.star:SetSize(13, 13)
        b.star:SetPoint("LEFT", 8, 0)
        SetStar(b.star, true)
        b.text = Label(b, "GameFontNormalSmall")
        b.text:SetJustifyH("LEFT")
        b.text:SetWordWrap(false)
        b:SetScript("OnClick", function(self) onSelect(self.entry) end)
        c.buttons[i] = b
        return b
    end

    -- Niveau 1 : catégorie, niveau 2 : sous-catégorie, niveau 3 : sous-sous-catégorie (comme l'HV).
    local NAV = { "auctionhouse-nav-button", "auctionhouse-nav-button-secondary", "auctionhouse-nav-button-tertiary" }
    local function Style(b, e)
        local depth = e.node and e.node.depth or 1
        if depth == 1 then
            Atlas(b.normal, NAV[1], function(t)
                t:SetTexture("Interface\\AuctionFrame\\UI-AuctionFrame-FilterBg")
                t:SetTexCoord(0, 0.53125, 0, 0.625)
            end)
        else
            Atlas(b.normal, NAV[min(depth, 3)], function(t)
                t:SetColorTexture(1, 1, 1, depth == 2 and 0.04 or 0.02)
            end)
        end
        b.text:ClearAllPoints()
        b.text:SetPoint("LEFT", e.kind == "fav" and 26 or (10 + (depth - 1) * 12), 0)
        b.text:SetPoint("RIGHT", -6, 0)
        b.text:SetFontObject(depth == 1 and "GameFontNormalSmall" or "GameFontHighlightSmall")
        b.star:SetShown(e.kind == "fav")
    end

    -- Affiche les catégories ; seules les branches du chemin sélectionné sont dépliées.
    function c:Rebuild(sel)
        local list = { { kind = "fav", label = "Favoris" }, { kind = "all", label = "Tous les objets" } }
        local open = {}
        local n = sel and sel.node
        while n do
            open[n] = true
            n = n.parent
        end
        local function Add(nodes)
            for _, node in ipairs(nodes) do
                list[#list + 1] = { kind = "node", node = node, label = node.name }
                if open[node] and node.s then Add(node.s) end
            end
        end
        Add(ns.GetCategoryTree())
        self.list, self.sel = list, sel
        self:Refresh()
    end

    function c:Refresh()
        local vis = max(1, floor((self:GetHeight() - 8) / BTN_H))
        self.offset = max(0, min(self.offset, #self.list - vis))
        for i = 1, vis do
            local e = self.list[self.offset + i]
            local b = Btn(i)
            if e then
                b.entry = e
                Style(b, e)
                b.text:SetText(e.label)
                local s = self.sel
                local selected = s and s.kind == e.kind and s.node == e.node
                b.sel:SetShown(selected and true or false)
                b:Show()
            else
                b:Hide()
            end
        end
        for i = vis + 1, #self.buttons do self.buttons[i]:Hide() end
    end

    c:SetScript("OnMouseWheel", function(self, delta)
        self.offset = self.offset - delta * 2
        self:Refresh()
    end)
    c:SetScript("OnSizeChanged", function(self) if self.list then self:Refresh() end end)
    return c
end

---------------------------------------------------------------------------
-- Fiche objet (dans la zone de droite de l'onglet Parcourir)
---------------------------------------------------------------------------

local RANGES = { { "48 h", 48 }, { "7 j", 24 * 7 }, { "30 j", 24 * 30 }, { "Tout", nil } }

local function CreateDetail(parent, onBack)
    local p = CreateFrame("Frame", nil, parent)
    p.range = 24 * 30

    local back = Button(p, "< Retour", 90, onBack)
    back:SetPoint("TOPLEFT", 8, -8)

    local iconBtn = CreateFrame("Button", nil, p)
    iconBtn:SetSize(40, 40)
    iconBtn:SetPoint("TOPLEFT", back, "BOTTOMLEFT", 2, -8)
    p.icon = iconBtn:CreateTexture(nil, "ARTWORK")
    p.icon:SetAllPoints()
    iconBtn:SetScript("OnEnter", function(self)
        if not p.id then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip.fxNoPrice = true
        GameTooltip:SetItemByID(p.id)
        GameTooltip.fxNoPrice = nil
        GameTooltip:Show()
        ns.ApplyCompare(GameTooltip)
    end)
    iconBtn:SetScript("OnLeave", GameTooltip_Hide)
    iconBtn:SetScript("OnClick", function()
        local link = p.id and ns.Link(p.id)
        if link and IsModifiedClick() then HandleModifiedItemClick(link) end
    end)

    p.star = StarButton(p, 20, function() if p.id then ns.ToggleFavorite(p.id) end end)
    p.star:SetPoint("TOPLEFT", iconBtn, "TOPRIGHT", 8, -2)
    p.name = Label(p, "GameFontNormalLarge")
    p.name:SetPoint("LEFT", p.star, "RIGHT", 6, 0)
    p.name:SetPoint("RIGHT", p, "RIGHT", -12, 0)
    p.name:SetJustifyH("LEFT")
    p.name:SetWordWrap(false)
    p.sub = Label(p, "GameFontDisableSmall")
    p.sub:SetPoint("TOPLEFT", p.star, "BOTTOMLEFT", 0, -6)

    p.stats = {}
    local labels = {
        "Prix min", "Valeur marché", "Quantité",
        "Moyenne 7 j", "Moyenne 30 j", "Évolution 7 j",
        "Plus bas 30 j", "Plus haut 30 j", "Enchères",
    }
    for i, text in ipairs(labels) do
        local col, row = (i - 1) % 3, floor((i - 1) / 3)
        local l = Label(p, "GameFontNormalSmall", text)
        l:SetPoint("TOPLEFT", iconBtn, "BOTTOMLEFT", col * 205, -10 - row * 30)
        local v = Label(p, "GameFontHighlight")
        v:SetPoint("TOPLEFT", l, "BOTTOMLEFT", 0, -2)
        p.stats[i] = v
    end

    p.chart = ns.CreateChart(p)
    p.chart:SetPoint("TOPLEFT", iconBtn, "BOTTOMLEFT", -4, -100)
    p.chart:SetPoint("BOTTOMRIGHT", -6, 32)

    p.rangeBtns = {}
    for i, r in ipairs(RANGES) do
        local b = Button(p, r[1], 56, function()
            p.range = r[2]
            p:Update()
        end)
        b:SetPoint("BOTTOMLEFT", 6 + (i - 1) * 58, 6)
        b.range = r[2]
        p.rangeBtns[i] = b
    end
    p.note = Label(p, "GameFontDisableSmall")
    p.note:SetPoint("BOTTOMRIGHT", -10, 12)

    function p:Update()
        local id = self.id
        if not id then return end
        local it = ns.Item(id) or {}
        self.icon:SetTexture(ns.Icon(id))
        self.name:SetText(ns.ColoredName(id))
        self.star:SetOn(ns.IsFavorite(id))
        local cur, t, listed, qty = ns.Current(it)
        self.sub:SetText((listed and "|cff40ff40En vente|r" or "|cffff5050Absent de la dernière analyse|r")
            .. " · prix vu " .. ns.Ago(t) .. " · ID " .. id)

        local pts = ns.ParseHistory(it.h)
        local nowH = floor(time() / 3600)
        local lo30, hi30
        for _, e in ipairs(pts) do
            if nowH - e[1] <= 24 * 30 then
                lo30 = lo30 and min(lo30, e[2]) or e[2]
                hi30 = hi30 and max(hi30, e[2]) or e[2]
            end
        end
        local v = {
            ns.Money(cur), ns.Money(it.mkt), BreakUpLargeNumbers(listed and qty or 0),
            ns.Money(it.a7), ns.Money(it.a30), ns.Pct(it.ch7),
            ns.Money(lo30), ns.Money(hi30), listed and it.auc and BreakUpLargeNumbers(it.auc) or "|cff808080—|r",
        }
        for i, s in ipairs(v) do self.stats[i]:SetText(s) end
        for _, b in ipairs(self.rangeBtns) do b:SetEnabled(b.range ~= self.range) end
        self.note:SetText(BreakUpLargeNumbers(#pts) .. " points · 1 par heure sur 48 h, puis 1 par jour")
        self.chart:SetData(pts, self.range)
    end

    return p
end

---------------------------------------------------------------------------
-- Onglet Parcourir : recherche + favoris + catégories + liste / fiche
---------------------------------------------------------------------------

local function BuildBrowse(p)
    p.query, p.cat, p.onlyListed = "", { kind = "all" }, true

    -- Barre de recherche (à droite du portrait, comme l'HV)
    local favBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    favBtn:SetSize(30, 26)
    favBtn:SetPoint("TOPLEFT", 66, -30)
    favBtn.icon = favBtn:CreateTexture(nil, "OVERLAY")
    favBtn.icon:SetSize(16, 16)
    favBtn.icon:SetPoint("CENTER")
    SetStar(favBtn.icon, true)
    favBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Favoris")
        GameTooltip:AddLine("Affiche tes objets favoris. Clique sur l'étoile d'un objet pour l'ajouter.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    favBtn:SetScript("OnLeave", GameTooltip_Hide)

    local ok, box = pcall(CreateFrame, "EditBox", "ForeverExchangeSearchBox", p, "SearchBoxTemplate")
    if not ok or not box then
        box = CreateFrame("EditBox", "ForeverExchangeSearchBox", p, "InputBoxTemplate")
    end
    box:SetSize(260, 22)
    box:SetPoint("LEFT", favBtn, "RIGHT", 10, 0)
    box:SetAutoFocus(false)
    box:SetMaxLetters(80)
    if box.Instructions then box.Instructions:SetText("Rechercher un objet") end
    p.box = box

    local filterBtn = Button(p, "Filtre", 90)
    filterBtn:SetPoint("LEFT", box, "RIGHT", 8, 0)
    local searchBtn = Button(p, "Rechercher", 110)
    searchBtn:SetPoint("LEFT", filterBtn, "RIGHT", 4, 0)

    p.count = Label(p, "GameFontDisableSmall")
    p.count:SetPoint("RIGHT", p, "TOPRIGHT", -14, -43)

    -- Zones
    local catInset = Inset(p)
    catInset:SetPoint("TOPLEFT", 8, TOP)
    catInset:SetPoint("BOTTOMLEFT", 8, BOTTOM)
    catInset:SetWidth(CAT_W)
    local listInset = Inset(p)
    listInset:SetPoint("TOPLEFT", catInset, "TOPRIGHT", 6, 0)
    listInset:SetPoint("BOTTOMRIGHT", -8, BOTTOM)

    local cats
    local function Select(entry)
        -- Recliquer sur la catégorie sélectionnée la replie (retour au parent).
        if entry.kind == "node" and p.cat.kind == "node" and p.cat.node == entry.node then
            local parent = entry.node.parent
            entry = parent and { kind = "node", node = parent, label = parent.name } or { kind = "all" }
        end
        p.cat = entry
        p.detailId = nil
        p.table:ResetScroll()
        p:Update()
    end
    cats = CreateCategories(catInset, Select)
    cats:SetPoint("TOPLEFT", 2, -2)
    cats:SetPoint("BOTTOMRIGHT", -2, 2)
    p.cats = cats

    p.table = CreateTable(listInset, {
        { key = "name", label = "Nom", fmt = ItemCol },
        { key = "min", label = "Prix min", width = 112, fmt = function(e) return ns.Money(e.min) end },
        { key = "mkt", label = "Valeur marché", width = 112, fmt = function(e) return ns.Money(e.mkt) end },
        { key = "qty", label = "Disponible", width = 72, fmt = function(e) return BreakUpLargeNumbers(e.qty or 0) end },
        { key = "ch7", label = "7 j", width = 54, fmt = function(e) return ns.Pct(e.ch7) end },
    }, "mkt", true, function(id) ns.ShowItem(id) end)
    p.table:SetPoint("TOPLEFT", 4, -4)
    p.table:SetPoint("BOTTOMRIGHT", -4, 4)

    p.detail = CreateDetail(listInset, function()
        p.detailId = nil
        p:Update()
    end)
    p.detail:SetAllPoints(listInset)
    p.detail:Hide()

    favBtn:SetScript("OnClick", function() Select({ kind = "fav", label = "Favoris" }) end)

    local pending = false
    local function Schedule()
        if pending then return end
        pending = true
        C_Timer.After(0.25, function()
            pending = false
            p.detailId = nil
            p.table:ResetScroll()
            p:Update()
        end)
    end
    box:HookScript("OnTextChanged", function(self)
        p.query = Normalize(strtrim(self:GetText()))
        Schedule()
    end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus(); Schedule() end)
    searchBtn:SetScript("OnClick", function() box:ClearFocus(); Schedule() end)

    local function OnInsertLink(link)
        if box:HasFocus() and type(link) == "string" then
            local name = link:match("%[(.-)%]")
            if name then box:SetText(name) end
        end
    end
    if ChatEdit_InsertLink then hooksecurefunc("ChatEdit_InsertLink", OnInsertLink) end
    if ChatFrameUtil and ChatFrameUtil.InsertLink then hooksecurefunc(ChatFrameUtil, "InsertLink", OnInsertLink) end

    filterBtn:SetScript("OnClick", function(self)
        if MenuUtil and MenuUtil.CreateContextMenu then
            MenuUtil.CreateContextMenu(self, function(_, root)
                root:CreateCheckbox("En vente uniquement", function() return p.onlyListed end,
                    function() p.onlyListed = not p.onlyListed; p:Update() end)
                root:CreateButton("Réinitialiser la recherche", function()
                    p.onlyListed = true
                    box:SetText("")
                    Select({ kind = "all" })
                end)
            end)
        else
            p.onlyListed = not p.onlyListed
            ns.Print("En vente uniquement : " .. (p.onlyListed and "oui" or "non"))
            p:Update()
        end
    end)

    function p:Update()
        local h = ns.house
        local tree = ns.GetCategoryTree()
        if self.tree ~= tree then -- arbre remplacé par celui de l'HV : l'ancienne sélection n'existe plus
            if self.tree and self.cat.kind == "node" then self.cat = { kind = "all" } end
            self.tree = tree
        end
        cats:Rebuild(self.cat)
        if self.detailId then
            self.table:Hide()
            self.detail.id = self.detailId
            self.detail:Show()
            self.detail:Update()
            self.count:SetText("")
            return
        end
        self.detail:Hide()
        self.table:Show()

        local cat, q, favs = self.cat, self.query, ns.db.favorites
        local out = {}
        for id, it in pairs(h.items) do
            if it.min or it.lmin then
                local okCat = true
                if cat.kind == "fav" then
                    okCat = favs[id]
                elseif cat.kind == "node" then
                    okCat = ns.ItemInCategory(id, cat.node)
                end
                if okCat and (q == "" or NormName(id):find(q, 1, true)) then
                    local e = Entry(id, it)
                    if not self.onlyListed or e.listed or cat.kind == "fav" then out[#out + 1] = e end
                end
            end
        end
        self.count:SetText(BreakUpLargeNumbers(#out) .. " objets")
        local emptyText
        if not h.lastScan and not next(h.items) then
            emptyText = "Aucun prix enregistré pour l'instant.\n\nOuvre l'hôtel des ventes un instant : une analyse des prix se fait toute seule.\nEnsuite, tout se consulte n'importe où."
        elseif cat.kind == "fav" then
            emptyText = "Aucun favori.\nClique sur l'étoile à gauche d'un objet pour l'ajouter à tes favoris."
        else
            emptyText = "Aucun objet ne correspond."
        end
        self.table:Set(out, emptyText)
    end
end

---------------------------------------------------------------------------
-- Onglet Prix bas
---------------------------------------------------------------------------

local VALUE_STEPS = { 0, 100, 1000, 10000, 50000, 100000, 1000000, 10000000 }

local function BuildDeals(p)
    local s = ns.settings

    local function Step(delta)
        s.dealPct = max(10, min(95, s.dealPct + delta))
        p:Update()
    end
    local function ValueStep(delta)
        local idx = 1
        for i, v in ipairs(VALUE_STEPS) do if v <= s.minValue then idx = i end end
        s.minValue = VALUE_STEPS[max(1, min(#VALUE_STEPS, idx + delta))]
        p:Update()
    end
    local pctText = Label(p, "GameFontNormal")
    pctText:SetPoint("TOPLEFT", 70, -36)
    local pctMinus = Button(p, "-", 24, function() Step(-5) end)
    pctMinus:SetPoint("LEFT", pctText, "RIGHT", 6, 0)
    local pctPlus = Button(p, "+", 24, function() Step(5) end)
    pctPlus:SetPoint("LEFT", pctMinus, "RIGHT", 2, 0)
    local valText = Label(p, "GameFontNormal")
    valText:SetPoint("LEFT", pctPlus, "RIGHT", 24, 0)
    local valMinus = Button(p, "-", 24, function() ValueStep(-1) end)
    valMinus:SetPoint("LEFT", valText, "RIGHT", 6, 0)
    local valPlus = Button(p, "+", 24, function() ValueStep(1) end)
    valPlus:SetPoint("LEFT", valMinus, "RIGHT", 2, 0)

    p.count = Label(p, "GameFontDisableSmall")
    p.count:SetPoint("RIGHT", p, "TOPRIGHT", -14, -43)

    local inset = Inset(p)
    inset:SetPoint("TOPLEFT", 8, TOP)
    inset:SetPoint("BOTTOMRIGHT", -8, BOTTOM)

    p.table = CreateTable(inset, {
        { key = "name", label = "Nom", fmt = ItemCol },
        { key = "min", label = "Prix min", width = 115, fmt = function(e) return ns.Money(e.min) end },
        { key = "ref", label = "Moyenne 30 j", width = 115, fmt = function(e) return ns.Money(e.ref) end },
        { key = "qty", label = "Disponible", width = 72, fmt = function(e) return BreakUpLargeNumbers(e.qty or 0) end },
        { key = "off", label = "Sous la moy.", width = 82, fmt = function(e) return ("|cff40ff40-%.0f %%|r"):format(e.off * 100) end },
        { key = "gain", label = "Écart", width = 105, fmt = function(e) return ns.Money(e.gain) end },
    }, "off", true, function(id) ns.ShowItem(id) end)
    p.table:SetPoint("TOPLEFT", 4, -4)
    p.table:SetPoint("BOTTOMRIGHT", -4, 4)

    function p:Update()
        pctText:SetText(("Prix min ≤ |cffffffff%d %%|r de la moyenne 30 j"):format(s.dealPct))
        valText:SetText("Moyenne ≥ " .. ns.Money(s.minValue))
        local out = {}
        for id, it in pairs(ns.house.items) do
            local cur, _, listed, qty = ns.Current(it)
            local ref = it.a30 or it.a7
            if listed and cur and ref and ref >= max(1, s.minValue) and (it.np or 0) >= s.minHistory
                and cur <= ref * s.dealPct / 100 then
                out[#out + 1] = {
                    id = id, name = NormName(id), min = cur, ref = ref, qty = qty or 0,
                    off = 1 - cur / ref, gain = ref - cur, listed = true,
                }
            end
        end
        self.count:SetText(BreakUpLargeNumbers(#out) .. " objets")
        self.table:Set(out, ns.house.lastScan
            and "Aucun objet nettement sous son prix habituel avec ces réglages.\nIl faut des analyses sur plusieurs jours pour avoir des moyennes fiables."
            or "Ouvre l'hôtel des ventes un instant pour analyser les prix.")
    end
end

---------------------------------------------------------------------------
-- Onglet Tendances
---------------------------------------------------------------------------

local function BuildTrends(p)
    p.up = true
    local upBtn = Button(p, "Hausses", 100, function() p.up = true; p:Update() end)
    upBtn:SetPoint("TOPLEFT", 66, -32)
    local downBtn = Button(p, "Baisses", 100, function() p.up = false; p:Update() end)
    downBtn:SetPoint("LEFT", upBtn, "RIGHT", 4, 0)
    local info = Label(p, "GameFontDisableSmall", "Évolution de la valeur marché sur 7 jours")
    info:SetPoint("LEFT", downBtn, "RIGHT", 12, 0)

    p.count = Label(p, "GameFontDisableSmall")
    p.count:SetPoint("RIGHT", p, "TOPRIGHT", -14, -43)

    local inset = Inset(p)
    inset:SetPoint("TOPLEFT", 8, TOP)
    inset:SetPoint("BOTTOMRIGHT", -8, BOTTOM)

    p.table = CreateTable(inset, {
        { key = "name", label = "Nom", fmt = ItemCol },
        { key = "mkt", label = "Valeur marché", width = 115, fmt = function(e) return ns.Money(e.mkt) end },
        { key = "a7", label = "Moyenne 7 j", width = 115, fmt = function(e) return ns.Money(e.a7) end },
        { key = "qty", label = "Disponible", width = 72, fmt = function(e) return BreakUpLargeNumbers(e.qty or 0) end },
        { key = "ch7", label = "7 j", width = 64, fmt = function(e) return ns.Pct(e.ch7) end },
    }, "ch7", true, function(id) ns.ShowItem(id) end)
    p.table:SetPoint("TOPLEFT", 4, -4)
    p.table:SetPoint("BOTTOMRIGHT", -4, 4)

    function p:Update()
        upBtn:SetEnabled(not self.up)
        downBtn:SetEnabled(self.up)
        local out = {}
        for id, it in pairs(ns.house.items) do
            if it.ch7 and it.a7 and it.a7 >= ns.settings.minValue
                and it.t == ns.house.lastScan
                and ((self.up and it.ch7 > 0) or (not self.up and it.ch7 < 0)) then
                out[#out + 1] = Entry(id, it)
            end
        end
        self.table.sortKey, self.table.sortDesc = "ch7", self.up
        self.count:SetText(BreakUpLargeNumbers(#out) .. " objets")
        self.table:Set(out, "Pas assez d'historique : il faut des analyses espacées d'au moins un jour.")
    end
end

---------------------------------------------------------------------------
-- Fenêtre
---------------------------------------------------------------------------

local TABS = {
    { label = "Parcourir", build = BuildBrowse },
    { label = "Prix bas", build = BuildDeals },
    { label = "Tendances", build = BuildTrends },
}

local function UpdateFooter()
    if not frame then return end
    local s, h = ns.scan, ns.house
    local text
    if s.state == "waiting" then
        text = "|cffffd100Analyse : le serveur prépare la liste…|r"
    elseif s.state == "reading" or s.state == "processing" or s.state == "browsing" then
        text = ("|cffffd100Analyse : %d %%|r"):format(floor(s.progress * 100))
    elseif h.lastScan then
        text = ("Dernière analyse %s · %s objets · %s enchères"):format(ns.Ago(h.lastScan),
            BreakUpLargeNumbers(h.lastItems or 0), BreakUpLargeNumbers(h.lastAuctions or 0))
    else
        text = "Aucune analyse pour l'instant : ouvre l'hôtel des ventes un instant."
    end
    frame.status:SetText(text)

    local ok, why = ns.CanScan()
    frame.scanBtn:SetEnabled(ok and true or false)
    frame.scanBtn:SetText(ns.IsScanning() and "Analyse en cours…" or "Analyser")
    frame.scanBtn.why = why
end

local function SelectTab(i)
    currentTab = i
    for k, page in ipairs(pages) do page:SetShown(k == i) end
    if frame.useTemplateTabs then
        PanelTemplates_SetTab(frame, i)
    else
        for k, b in ipairs(tabs) do b:SetEnabled(k ~= i) end
    end
    if pages[i] and pages[i].Update then pages[i]:Update() end
end

local function SetPortrait(f)
    if f.SetPortraitToAsset and pcall(f.SetPortraitToAsset, f, ns.LOGO) then return end
    local tex = (f.PortraitContainer and f.PortraitContainer.portrait) or f.portrait
    if tex then
        tex:SetTexture(ns.LOGO)
        return
    end
    local logo = f:CreateTexture(nil, "OVERLAY")
    logo:SetSize(52, 52)
    logo:SetPoint("TOPLEFT", 6, -4)
    logo:SetTexture(ns.LOGO)
end

local function CreateTabs(f)
    local okTabs = PanelTemplates_SetNumTabs and PanelTemplates_SetTab
    for i, def in ipairs(TABS) do
        local b
        if okTabs then
            local ok, tb = pcall(CreateFrame, "Button", "ForeverExchangeFrameTab" .. i, f, "PanelTabButtonTemplate")
            if ok and tb then b = tb else okTabs = false end
        end
        if not b then
            b = Button(f, def.label, 120)
        end
        b:SetText(def.label)
        b:SetID(i)
        b:SetScript("OnClick", function() SelectTab(i) end)
        if i == 1 then
            b:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 12, 2)
        else
            b:SetPoint("LEFT", tabs[i - 1], "RIGHT", okTabs and 3 or 4, 0)
        end
        if okTabs and PanelTemplates_TabResize then pcall(PanelTemplates_TabResize, b, 0) end
        tabs[i] = b
    end
    f.Tabs = tabs
    if okTabs then
        f.useTemplateTabs = true
        PanelTemplates_SetNumTabs(f, #tabs)
    end
end

local function Build()
    local f
    for _, template in ipairs({ "PortraitFrameTemplate", "BasicFrameTemplateWithInset" }) do
        local ok, fr = pcall(CreateFrame, "Frame", "ForeverExchangeFrame", UIParent, template)
        if ok and fr then
            f = fr
            break
        end
    end
    if not f then
        f = CreateFrame("Frame", "ForeverExchangeFrame", UIParent, "BackdropTemplate")
        f:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 8, right = 8, top = 8, bottom = 8 },
        })
        local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -4, -4)
    end
    frame = f
    f:SetSize(W, H)
    f:SetPoint("CENTER")
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    tinsert(UISpecialFrames, "ForeverExchangeFrame")

    local title = "ForeverExchange |cff808080v" .. ns.Version() .. "|r"
    if f.SetTitle then
        f:SetTitle(title)
    else
        local t = f.TitleText or f.title or Label(f, "GameFontNormal")
        if not f.TitleText and not f.title then t:SetPoint("TOP", 0, -6) end
        t:SetText(title)
    end
    SetPortrait(f)

    for i, def in ipairs(TABS) do
        local page = CreateFrame("Frame", nil, f)
        page:SetAllPoints(f)
        page:Hide()
        def.build(page)
        pages[i] = page
    end
    CreateTabs(f)

    -- Pied de fenêtre
    local scanBtn = Button(f, "Analyser", 140, function() ns.StartScan(false) end)
    scanBtn:SetPoint("BOTTOMRIGHT", -8, 5)
    scanBtn:SetMotionScriptsWhileDisabled(true)
    scanBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Analyser l'hôtel des ventes")
        GameTooltip:AddLine("Lit toutes les enchères en cours (lecture seule : rien n'est acheté ni vendu). "
            .. "Possible quand l'HV est ouvert.", 1, 1, 1, true)
        if self.why then GameTooltip:AddLine(self.why, 1, 0.3, 0.3, true) end
        GameTooltip:Show()
    end)
    scanBtn:SetScript("OnLeave", GameTooltip_Hide)
    f.scanBtn = scanBtn

    local optBtn = Button(f, "Options", 80, function()
        f:Hide()
        ns.OpenOptions()
    end)
    optBtn:SetPoint("RIGHT", scanBtn, "LEFT", -4, 0)

    f.status = Label(f, "GameFontDisableSmall")
    f.status:SetPoint("BOTTOMLEFT", 14, 11)
    f.status:SetPoint("RIGHT", optBtn, "LEFT", -10, 0)
    f.status:SetJustifyH("LEFT")

    local elapsed = 0
    f:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed >= 1 then
            elapsed = 0
            UpdateFooter()
        end
    end)
    f:SetScript("OnShow", function()
        UpdateFooter()
        SelectTab(currentTab)
    end)

    SelectTab(currentTab)
    UpdateFooter()
end

function ns.Show()
    if not frame then Build() end
    frame:Show()
end

function ns.Toggle()
    if frame and frame:IsShown() then frame:Hide() else ns.Show() end
end

function ns.ShowItem(id)
    ns.Show()
    pages[1].detailId = id
    SelectTab(1)
end

function ns.SearchFor(text)
    local id = tonumber(text) or tonumber(text:match("item:(%d+)"))
    if id then
        ns.ShowItem(id)
        return
    end
    ns.Show()
    local p = pages[1]
    p.detailId = nil
    p.cat = { kind = "all" }
    SelectTab(1)
    p.box:SetText(text:match("%[(.-)%]") or text)
end

-- Rafraîchissement quand les données changent (regroupé).
local dirty = false
function ns.OnDataChanged(what)
    if not frame or not frame:IsShown() then return end
    UpdateFooter()
    if what == "progress" then return end
    if dirty then return end
    dirty = true
    C_Timer.After(0.3, function()
        dirty = false
        local page = pages[currentTab]
        if frame:IsShown() and page and page.Update then page:Update() end
    end)
end

---------------------------------------------------------------------------
-- Ouverture de l'HV : onglet ForeverExchange (AHTab.lua)
---------------------------------------------------------------------------

function ns.OnAHShow()
    if ns.CreateAHTab then ns.CreateAHTab() end
end

-- Ouvre la fenêtre à côté de l'HV quand il est ouvert.
local baseShow = ns.Show
function ns.Show()
    local wasShown = frame and frame:IsShown()
    baseShow()
    if not wasShown and ns.ahOpen and AuctionHouseFrame and AuctionHouseFrame:IsShown() then
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", AuctionHouseFrame, "TOPRIGHT", 8, 0)
    end
end
