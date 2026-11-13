-- ForeverExchange : arbre des catégories de l'hôtel des ventes.
-- Le vrai arbre (AuctionCategories, celui de l'HV de WoW Forever, avec ses
-- sous-catégories et sous-sous-catégories) n'existe qu'une fois l'interface
-- de l'HV chargée : on le recopie dans ForeverExchangeDB à chaque ouverture
-- de l'HV pour l'avoir ensuite n'importe où. Avant la première ouverture,
-- on construit un arbre équivalent à partir des classes d'objets.
local ADDON, ns = ...

-- Nœud : { name = "...", f = { {classID, subClassID|false, inventoryType|false}, ... }, s = { sous-nœuds } }

---------------------------------------------------------------------------
-- Copie de l'arbre du jeu
---------------------------------------------------------------------------

local function HasFlag(cat, flag)
    if type(cat.HasFlag) == "function" then
        local ok, v = pcall(cat.HasFlag, cat, flag)
        return ok and v
    end
    return cat.flags and cat.flags[flag]
end

local function Copy(cats)
    local out = {}
    for _, c in ipairs(cats) do
        if type(c) == "table" and c.name and not c.implicitFilter and not HasFlag(c, "WOW_TOKEN_FLAG") then
            local node = { name = c.name, f = {} }
            for _, flt in ipairs(c.filters or {}) do
                if flt.classID then
                    node.f[#node.f + 1] = { flt.classID, flt.subClassID or false, flt.inventoryType or false }
                end
            end
            if c.subCategories and #c.subCategories > 0 then
                node.s = Copy(c.subCategories)
                if #node.s == 0 then node.s = nil end
            end
            out[#out + 1] = node
        end
    end
    return out
end

function ns.CaptureCategories()
    if type(AuctionCategories) ~= "table" or #AuctionCategories == 0 then return false end
    local ok, tree = pcall(Copy, AuctionCategories)
    if ok and tree and #tree > 0 then
        ns.db.categories = tree
        ns.categoryTree = nil
        return true
    end
    return false
end

---------------------------------------------------------------------------
-- Arbre de repli (avant la première ouverture de l'HV)
---------------------------------------------------------------------------

local CLASSES = {
    { 2, "Armes" }, { 4, "Armures" }, { 1, "Conteneurs" }, { 3, "Gemmes" },
    { 8, "Améliorations d'objets" }, { 0, "Consommables" }, { 16, "Glyphes" },
    { 7, "Artisanat" }, { 9, "Recettes" }, { 19, "Métiers" }, { 17, "Mascottes de combat" },
    { 12, "Objets de quête" }, { 15, "Divers" },
}

-- Emplacements des armures en tissu / cuir / mailles / plaques (comme l'HV).
local SLOTS = {
    { "INVTYPE_HEAD", 1 }, { "INVTYPE_SHOULDER", 3 }, { "INVTYPE_CHEST", 5, 20 },
    { "INVTYPE_WAIST", 6 }, { "INVTYPE_LEGS", 7 }, { "INVTYPE_FEET", 8 },
    { "INVTYPE_WRIST", 9 }, { "INVTYPE_HAND", 10 },
}

local function ClassName(id, fallback)
    local get = (C_Item and C_Item.GetItemClassInfo) or GetItemClassInfo
    return (get and get(id)) or fallback
end

local function SubClassName(class, sub)
    local get = (C_Item and C_Item.GetItemSubClassInfo) or GetItemSubClassInfo
    return get and get(class, sub)
end

local function SubClasses(class)
    if C_AuctionHouse and C_AuctionHouse.GetAuctionItemSubClasses then
        local ok, list = pcall(C_AuctionHouse.GetAuctionItemSubClasses, class)
        if ok and type(list) == "table" and #list > 0 then return list end
    end
    local list = {}
    for sub = 0, 20 do
        if SubClassName(class, sub) then list[#list + 1] = sub end
    end
    return list
end

local function Fallback()
    local tree = {}
    for _, cl in ipairs(CLASSES) do
        local class = cl[1]
        local node = { name = ClassName(class, cl[2]), f = { { class, false, false } } }
        local subs = {}
        for _, sub in ipairs(SubClasses(class)) do
            local name = SubClassName(class, sub)
            if name and name ~= "" then
                local sn = { name = name, f = { { class, sub, false } } }
                if class == 4 and sub >= 1 and sub <= 4 then -- tissu, cuir, mailles, plaques
                    sn.s = {}
                    for _, slot in ipairs(SLOTS) do
                        local f = { { class, sub, slot[2] } }
                        if slot[3] then f[2] = { class, sub, slot[3] } end
                        sn.s[#sn.s + 1] = { name = _G[slot[1]] or slot[1], f = f }
                    end
                end
                subs[#subs + 1] = sn
            end
        end
        if #subs > 0 then node.s = subs end
        tree[#tree + 1] = node
    end
    return tree
end

-- Retire les catégories obsolètes laissées dans les données du jeu
-- (« Jewelry(OBSOLETE) », « Generic(OBSOLETE) »…).
local function Clean(nodes)
    local out = {}
    for _, n in ipairs(nodes) do
        if type(n.name) == "string" and not n.name:upper():find("OBSOLETE", 1, true) then
            if n.s then
                n.s = Clean(n.s)
                if #n.s == 0 then n.s = nil end
            end
            out[#out + 1] = n
        end
    end
    return out
end

-- Un parent sans filtre propre prend ceux de ses enfants.
-- (parent : utilisé à l'affichage, jamais sauvegardé car l'arbre préparé est une copie)
local function Prepare(nodes, depth, parent)
    for _, n in ipairs(nodes) do
        n.depth, n.parent = depth, parent
        if n.s then
            Prepare(n.s, depth + 1, n)
            if not n.f or #n.f == 0 then
                n.f = {}
                for _, c in ipairs(n.s) do
                    for _, flt in ipairs(c.f or {}) do n.f[#n.f + 1] = flt end
                end
            end
        end
        n.f = n.f or {}
    end
    return nodes
end

function ns.GetCategoryTree()
    if not ns.categoryTree then
        local saved = ns.db and ns.db.categories
        -- Copie profonde : parent/depth ne doivent pas finir dans les SavedVariables
        -- (référence circulaire).
        local function Clone(nodes)
            local out = {}
            for i, n in ipairs(nodes) do
                out[i] = { name = n.name, f = n.f, s = n.s and Clone(n.s) or nil }
            end
            return out
        end
        ns.categoryTree = Prepare(Clean(saved and Clone(saved) or Fallback()), 1, nil)
        ns.categoriesFromGame = saved and true or false
    end
    return ns.categoryTree
end

---------------------------------------------------------------------------
-- Correspondance objet <-> catégorie
---------------------------------------------------------------------------

local info = {}
function ns.ItemClassInfo(id)
    local c = info[id]
    if not c then
        local _, _, _, _, _, classID, subID = C_Item.GetItemInfoInstant(id)
        local inv = C_Item.GetItemInventoryTypeByID and C_Item.GetItemInventoryTypeByID(id)
        c = { classID or -1, subID or -1, inv or -1 }
        info[id] = c
    end
    return c[1], c[2], c[3]
end

function ns.ItemInCategory(id, node)
    local c, s, inv = ns.ItemClassInfo(id)
    for _, f in ipairs(node.f) do
        if f[1] == c and (not f[2] or f[2] == s) and (not f[3] or f[3] == inv) then return true end
    end
    return false
end
