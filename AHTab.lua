-- ForeverExchange : onglet « ForeverExchange » en bas de la fenêtre de l'HV
-- (à côté d'Acheter / Vendre / Ventes), avec l'analyse des prix et les
-- raccourcis vers la fenêtre et les options.
--
-- Les onglets de l'HV ne doivent pas passer par PanelTemplates_SetNumTabs
-- sur AuctionHouseFrame (souillure/taint qui bloque ensuite les sacs).
-- Si la bibliothèque partagée LibAHTab est déjà chargée par un autre addon
-- (ex. Auctionator), on l'utilise pour que les onglets s'alignent ; sinon on
-- crée l'onglet nous-mêmes avec la même méthode.
local ADDON, ns = ...

local floor = math.floor
local TAB_ID = "ForeverExchange"
local panel, tab

---------------------------------------------------------------------------
-- Onglet sans bibliothèque
---------------------------------------------------------------------------

local function Deselect()
    if panel then panel:Hide() end
    if tab then PanelTemplates_DeselectTab(tab) end
end

local function SelectOwnTab()
    AuctionHouseFrame:SetDisplayMode({})
    AuctionHouseFrame.displayMode = nil
    for _, t in ipairs(AuctionHouseFrame.Tabs or {}) do PanelTemplates_DeselectTab(t) end
    PanelTemplates_SelectTab(tab)
    if AuctionHouseFrame.SetTitle then AuctionHouseFrame:SetTitle("ForeverExchange") end
    panel:Show()
end

local function CreateOwnTab()
    local tabs = AuctionHouseFrame.Tabs
    if not tabs or #tabs == 0 then return false end
    tab = CreateFrame("Button", "ForeverExchangeAHTab", AuctionHouseFrame, "AuctionHouseFrameDisplayModeTabTemplate")
    tab:SetText("ForeverExchange")
    PanelTemplates_TabResize(tab, 20, nil, 70)
    tab:SetPoint("TOPLEFT", tabs[#tabs], "TOPRIGHT", 3, 0)
    PanelTemplates_DeselectTab(tab)
    tab:SetScript("OnClick", SelectOwnTab)
    -- Un clic sur un onglet de Blizzard referme le nôtre.
    hooksecurefunc(AuctionHouseFrame, "SetDisplayMode", function(_, mode)
        if mode ~= nil and #mode > 0 then Deselect() end
    end)
    return true
end

---------------------------------------------------------------------------
-- Contenu de l'onglet
---------------------------------------------------------------------------

local function Label(parent, font, text)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    if text then fs:SetText(text) end
    return fs
end

local function Button(parent, text, w, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w, 26)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    return b
end

local function BuildPanel()
    local p = CreateFrame("Frame", "ForeverExchangeAHPanel", AuctionHouseFrame)
    p:SetPoint("TOPLEFT", AuctionHouseFrame, "TOPLEFT", 8, -60)
    p:SetPoint("BOTTOMRIGHT", AuctionHouseFrame, "BOTTOMRIGHT", -8, 28)
    p:Hide()

    local logo = p:CreateTexture(nil, "ARTWORK")
    logo:SetSize(96, 96)
    logo:SetPoint("TOP", 0, -20)
    logo:SetTexture(ns.LOGO)

    local title = Label(p, "GameFontNormalHuge", "|cff33ccffForeverExchange|r")
    title:SetPoint("TOP", logo, "BOTTOM", 0, -10)
    local version = Label(p, "GameFontDisable", "v" .. ns.Version())
    version:SetPoint("TOP", title, "BOTTOM", 0, -4)

    local desc = Label(p, "GameFontHighlight",
        "Relève les prix de toutes les enchères en cours pour les consulter ensuite n'importe où.\n"
        .. "Lecture seule : rien n'est acheté ni vendu.")
    desc:SetPoint("TOP", version, "BOTTOM", 0, -16)
    desc:SetWidth(620)

    -- Barre de progression de l'analyse
    local bar = CreateFrame("StatusBar", nil, p)
    bar:SetSize(420, 18)
    bar:SetPoint("TOP", desc, "BOTTOM", 0, -24)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(0.2, 0.75, 1)
    bar:SetMinMaxValues(0, 1)
    local bbg = bar:CreateTexture(nil, "BACKGROUND")
    bbg:SetAllPoints()
    bbg:SetColorTexture(0, 0, 0, 0.5)
    local border = CreateFrame("Frame", nil, bar, "BackdropTemplate")
    border:SetPoint("TOPLEFT", -2, 2)
    border:SetPoint("BOTTOMRIGHT", 2, -2)
    border:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    border:SetBackdropBorderColor(0.6, 0.5, 0.25, 0.8)
    bar.text = Label(bar, "GameFontHighlightSmall")
    bar.text:SetPoint("CENTER")

    local status = Label(p, "GameFontNormal")
    status:SetPoint("TOP", bar, "BOTTOM", 0, -12)
    status:SetWidth(620)

    local scanBtn = Button(p, "Analyser", 180, function() ns.StartScan(false) end)
    scanBtn:SetPoint("TOP", status, "BOTTOM", 0, -18)
    scanBtn:SetMotionScriptsWhileDisabled(true)
    scanBtn:SetScript("OnEnter", function(self)
        if not self.why then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(self.why, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    scanBtn:SetScript("OnLeave", GameTooltip_Hide)

    local openBtn = Button(p, "Ouvrir ForeverExchange", 180, function() ns.Show() end)
    openBtn:SetPoint("RIGHT", scanBtn, "LEFT", -8, 0)
    local optBtn = Button(p, "Options", 180, function() ns.OpenOptions() end)
    optBtn:SetPoint("LEFT", scanBtn, "RIGHT", 8, 0)

    local auto = CreateFrame("CheckButton", nil, p, "UICheckButtonTemplate")
    auto:SetSize(26, 26)
    auto:SetPoint("TOP", scanBtn, "BOTTOM", -120, -14)
    local autoLabel = auto.Text or auto.text or Label(auto, "GameFontHighlight")
    if not auto.Text and not auto.text then autoLabel:SetPoint("LEFT", auto, "RIGHT", 2, 0) end
    autoLabel:SetFontObject("GameFontHighlight")
    autoLabel:SetText("Analyser l'HV automatiquement à son ouverture")
    auto:SetScript("OnClick", function(self) ns.settings.autoScan = self:GetChecked() and true or false end)

    function p:Refresh()
        local s, h = ns.scan, ns.house
        auto:SetChecked(ns.settings.autoScan and true or false)
        if s.state == "waiting" then
            bar:SetValue(0.05)
            bar.text:SetText("Le serveur prépare la liste…")
        elseif s.state == "reading" or s.state == "processing" or s.state == "browsing" then
            bar:SetValue(s.progress)
            bar.text:SetText(("%d %%"):format(floor(s.progress * 100)))
        else
            bar:SetValue(h.lastScan and 1 or 0)
            bar.text:SetText(h.lastScan and "Terminé" or "")
        end
        if h.lastScan then
            status:SetText(("Dernière analyse %s · |cffffffff%s|r objets · |cffffffff%s|r enchères")
                :format(ns.Ago(h.lastScan), BreakUpLargeNumbers(h.lastItems or 0), BreakUpLargeNumbers(h.lastAuctions or 0)))
        else
            status:SetText("Aucune analyse pour l'instant.")
        end
        local ok, why = ns.CanScan()
        scanBtn:SetEnabled(ok and true or false)
        scanBtn.why = why
        scanBtn:SetText(ns.IsScanning() and "Analyse en cours…" or "Analyser")
    end

    local elapsed = 0
    p:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt
        if elapsed >= 0.25 then
            elapsed = 0
            self:Refresh()
        end
    end)
    p:SetScript("OnShow", function(self) self:Refresh() end)
    return p
end

---------------------------------------------------------------------------
-- Création à l'ouverture de l'HV
---------------------------------------------------------------------------

function ns.CreateAHTab()
    if panel or not AuctionHouseFrame then return end
    panel = BuildPanel()

    local lib = LibStub and LibStub("LibAHTab-1-0", true)
    if lib then
        local ok = pcall(lib.CreateTab, lib, TAB_ID, panel, "ForeverExchange", "ForeverExchange")
        if ok then return end
    end
    if not CreateOwnTab() then
        panel = nil
    end
end
