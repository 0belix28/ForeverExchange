-- ForeverExchange : panneau d'options (Échap > Options > AddOns) et bouton de la minicarte.
local ADDON, ns = ...

local floor, max, min = math.floor, math.max, math.min

local VALUE_STEPS = { 0, 100, 1000, 10000, 50000, 100000, 1000000, 10000000 }

---------------------------------------------------------------------------
-- Bouton de la minicarte (déplaçable autour de la minicarte)
---------------------------------------------------------------------------

local mmButton

local function PlaceMinimapButton()
    local a = math.rad(ns.settings.minimapAngle or 200)
    local r = Minimap:GetWidth() / 2 + 10
    mmButton:ClearAllPoints()
    mmButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
end

function ns.UpdateMinimapButton()
    if not ns.settings or not Minimap then return end
    if not ns.settings.minimap then
        if mmButton then mmButton:Hide() end
        return
    end
    if not mmButton then
        local b = CreateFrame("Button", "ForeverExchangeMinimapButton", Minimap)
        b:SetSize(32, 32)
        b:SetFrameStrata("MEDIUM")
        b:SetFrameLevel(8)
        local bg = b:CreateTexture(nil, "BACKGROUND")
        bg:SetSize(22, 22)
        bg:SetPoint("CENTER")
        bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
        local icon = b:CreateTexture(nil, "ARTWORK")
        icon:SetSize(22, 22)
        icon:SetPoint("CENTER")
        icon:SetTexture(ns.LOGO)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        local border = b:CreateTexture(nil, "OVERLAY")
        border:SetSize(54, 54)
        border:SetPoint("TOPLEFT")
        border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
        b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        b:RegisterForDrag("LeftButton")
        b:SetScript("OnClick", function(_, button)
            if button == "RightButton" then ns.OpenOptions() else ns.Toggle() end
        end)
        b:SetScript("OnDragStart", function(self)
            self:SetScript("OnUpdate", function()
                local mx, my = Minimap:GetCenter()
                local cx, cy = GetCursorPosition()
                local s = Minimap:GetEffectiveScale()
                ns.settings.minimapAngle = math.deg(math.atan2(cy / s - my, cx / s - mx))
                PlaceMinimapButton()
            end)
        end)
        b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:AddLine("|cff33ccffForeverExchange|r")
            GameTooltip:AddLine("Clic : ouvrir / fermer", 1, 1, 1)
            GameTooltip:AddLine("Clic droit : options", 1, 1, 1)
            GameTooltip:AddLine("Glisser : déplacer le bouton", 0.6, 0.6, 0.6)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", GameTooltip_Hide)
        mmButton = b
    end
    PlaceMinimapButton()
    mmButton:Show()
end

---------------------------------------------------------------------------
-- Panneau d'options
---------------------------------------------------------------------------

local category, panel

StaticPopupDialogs["FOREVEREXCHANGE_WIPE"] = {
    text = "Effacer tous les prix et l'historique enregistrés par ForeverExchange pour cet hôtel des ventes ?\n\nC'est définitif : il faudra refaire des scans.",
    button1 = YES,
    button2 = NO,
    OnAccept = function()
        local h = ns.house
        wipe(h.items)
        h.lastScan, h.lastItems, h.lastAuctions, h.scanCount, h.lastCompactDay = nil, nil, nil, 0, nil
        ns.Print("Données effacées.")
        ns.Notify("scan")
        if panel and panel:IsShown() then panel:Refresh() end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local function Header(parent, text, anchor, y)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    fs:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, y or -18)
    fs:SetText(text)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(1, 0.82, 0, 0.25)
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", fs, "BOTTOMLEFT", 0, -3)
    line:SetPoint("RIGHT", parent, "RIGHT", -20, 0)
    return fs
end

local function Check(parent, text, tip, key, after)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(26, 26)
    local label = cb.Text or cb.text
    if not label then
        label = cb:CreateFontString(nil, "OVERLAY")
        label:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    end
    label:SetFontObject("GameFontHighlight")
    label:SetText(text)
    cb:SetScript("OnClick", function(self)
        ns.settings[key] = self:GetChecked() and true or false
        if after then after() end
        ns.Notify("settings")
    end)
    cb:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(text)
        GameTooltip:AddLine(tip, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    cb:SetScript("OnLeave", GameTooltip_Hide)
    cb.key = key
    return cb
end

local function SmallButton(parent, text, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(26, 22)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    return b
end

local function Build()
    panel = CreateFrame("Frame")
    panel.name = "ForeverExchange"
    panel:Hide()

    -- En-tête : logo, titre, description
    local logo = panel:CreateTexture(nil, "ARTWORK")
    logo:SetSize(80, 80)
    logo:SetPoint("TOPLEFT", 16, -16)
    logo:SetTexture(ns.LOGO)

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 14, -6)
    title:SetText("|cff33ccffForeverExchange|r")
    local version = panel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    version:SetPoint("BOTTOMLEFT", title, "BOTTOMRIGHT", 8, 2)
    version:SetText("v" .. ns.Version())

    local desc = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    desc:SetPoint("RIGHT", panel, "RIGHT", -20, 0)
    desc:SetJustifyH("LEFT")
    desc:SetText("Les prix de l'hôtel des ventes de WoW Forever, consultables partout : historique, graphiques, "
        .. "prix bas et tendances. Uniquement pour regarder les prix : l'addon n'achète et ne vend rien.")

    local open = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    open:SetSize(200, 26)
    open:SetPoint("TOPLEFT", logo, "BOTTOMLEFT", 0, -10)
    open:SetText("Ouvrir ForeverExchange")
    open:SetScript("OnClick", function()
        if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
        ns.Show()
    end)
    local openHint = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    openHint:SetPoint("LEFT", open, "RIGHT", 10, 0)
    openHint:SetText("Aussi : /fx, bouton de la minicarte, raccourci clavier (Options > Raccourcis > AddOns)")

    -- Général
    local general = Header(panel, "Général", open, -22)
    local checks = {}
    checks[1] = Check(panel, "Bouton sur la minicarte",
        "Ouvre ForeverExchange depuis n'importe où. Clic droit : ces options. Glisser pour le déplacer.",
        "minimap", ns.UpdateMinimapButton)
    checks[1]:SetPoint("TOPLEFT", general, "BOTTOMLEFT", -2, -10)
    checks[2] = Check(panel, "Prix dans les infobulles",
        "Ajoute le prix min, la valeur marché et la moyenne 30 j aux infobulles de tous les objets.",
        "tooltip")
    checks[2]:SetPoint("TOPLEFT", checks[1], "BOTTOMLEFT", 0, -2)
    checks[3] = Check(panel, "Analyser l'HV automatiquement à son ouverture",
        "Les prix viennent d'une analyse complète de l'hôtel des ventes (lecture seule : rien n'est acheté ni vendu). "
        .. "Il suffit d'ouvrir l'HV un instant : le reste du temps, tout se consulte n'importe où.",
        "autoScan")
    checks[3]:SetPoint("TOPLEFT", checks[2], "BOTTOMLEFT", 0, -2)
    checks[4] = Check(panel, "Comparer avec l'objet équipé",
        "Quand tu survoles un objet dans ForeverExchange, affiche aussi l'infobulle de l'objet que tu portes au même emplacement.",
        "compare")
    checks[4]:SetPoint("TOPLEFT", checks[3], "BOTTOMLEFT", 0, -2)

    -- Onglet Prix bas
    local deals = Header(panel, "Onglets Prix bas et Tendances", checks[4], -16)
    local pctText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    pctText:SetPoint("TOPLEFT", deals, "BOTTOMLEFT", 4, -16)
    pctText:SetWidth(330)
    pctText:SetJustifyH("LEFT")
    local pctMinus = SmallButton(panel, "-", function()
        ns.settings.dealPct = max(10, ns.settings.dealPct - 5); panel:Refresh(); ns.Notify("settings")
    end)
    pctMinus:SetPoint("LEFT", pctText, "RIGHT", 6, 0)
    local pctPlus = SmallButton(panel, "+", function()
        ns.settings.dealPct = min(95, ns.settings.dealPct + 5); panel:Refresh(); ns.Notify("settings")
    end)
    pctPlus:SetPoint("LEFT", pctMinus, "RIGHT", 2, 0)

    local valText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    valText:SetPoint("TOPLEFT", pctText, "BOTTOMLEFT", 0, -16)
    valText:SetWidth(330)
    valText:SetJustifyH("LEFT")
    local function ValueStep(delta)
        local idx = 1
        for i, v in ipairs(VALUE_STEPS) do if v <= ns.settings.minValue then idx = i end end
        ns.settings.minValue = VALUE_STEPS[max(1, min(#VALUE_STEPS, idx + delta))]
        panel:Refresh()
        ns.Notify("settings")
    end
    local valMinus = SmallButton(panel, "-", function() ValueStep(-1) end)
    valMinus:SetPoint("LEFT", valText, "RIGHT", 6, 0)
    local valPlus = SmallButton(panel, "+", function() ValueStep(1) end)
    valPlus:SetPoint("LEFT", valMinus, "RIGHT", 2, 0)

    -- Données
    local data = Header(panel, "Données", valText, -20)
    local stats = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    stats:SetPoint("TOPLEFT", data, "BOTTOMLEFT", 4, -12)
    stats:SetPoint("RIGHT", panel, "RIGHT", -20, 0)
    stats:SetJustifyH("LEFT")
    stats:SetSpacing(3)
    local wipeBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    wipeBtn:SetSize(200, 24)
    wipeBtn:SetPoint("TOPLEFT", stats, "BOTTOMLEFT", -4, -10)
    wipeBtn:SetText("Effacer les données")
    wipeBtn:SetScript("OnClick", function() StaticPopup_Show("FOREVEREXCHANGE_WIPE") end)

    -- Commandes
    local cmds = Header(panel, "Commandes", wipeBtn, -20)
    local cmdText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cmdText:SetPoint("TOPLEFT", cmds, "BOTTOMLEFT", 4, -12)
    cmdText:SetJustifyH("LEFT")
    cmdText:SetSpacing(3)
    cmdText:SetText("|cffffd100/fx|r  ouvrir / fermer la fenêtre\n"
        .. "|cffffd100/fx <nom, lien ou ID>|r  voir le prix d'un objet\n"
        .. "|cffffd100/fx options|r  ce panneau\n"
        .. "|cffffd100/fx scan|r  analyser l'hôtel des ventes (HV ouvert)")

    function panel:Refresh()
        for _, cb in ipairs(checks) do cb:SetChecked(ns.settings[cb.key] and true or false) end
        pctText:SetText(("Prix bas : prix min ≤ |cffffffff%d %%|r de la moyenne 30 j"):format(ns.settings.dealPct))
        valText:SetText("Ignorer les objets dont la moyenne est sous " .. ns.Money(ns.settings.minValue))
        local h = ns.house
        local items, points = 0, 0
        for _, it in pairs(h.items) do
            items = items + 1
            if it.h and it.h ~= "" then
                local _, n = it.h:gsub(";", "")
                points = points + n + 1
            end
        end
        stats:SetText(("Hôtel des ventes : |cffffffff%s|r\nObjets connus : |cffffffff%s|r · points d'historique : |cffffffff%s|r\n"
            .. "Dernière analyse : |cffffffff%s|r · analyses effectuées : |cffffffff%s|r")
            :format(ns.HouseKey(), BreakUpLargeNumbers(items), BreakUpLargeNumbers(points),
                h.lastScan and (date("%d/%m/%Y %H:%M", h.lastScan) .. " (" .. ns.Ago(h.lastScan) .. ")") or "jamais",
                BreakUpLargeNumbers(h.scanCount or 0)))
    end
    panel:SetScript("OnShow", function(self) self:Refresh() end)

    if Settings and Settings.RegisterCanvasLayoutCategory then
        category = Settings.RegisterCanvasLayoutCategory(panel, "ForeverExchange")
        Settings.RegisterAddOnCategory(category)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end

function ns.CreateOptions()
    if not panel then Build() end
end

function ns.OpenOptions()
    if not panel then Build() end
    if category and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(category:GetID())
    elseif InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(panel)
        InterfaceOptionsFrame_OpenToCategory(panel)
    end
end
