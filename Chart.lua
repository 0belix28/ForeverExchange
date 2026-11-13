-- ForeverExchange : graphique d'historique (prix min, valeur marché, quantité).
local ADDON, ns = ...

local floor, max, min = math.floor, math.max, math.min

local COLOR_MIN = { 0.3, 0.8, 1 }
local COLOR_MKT = { 1, 0.82, 0.1 }
local COLOR_QTY = { 0.6, 0.6, 0.8, 0.22 }
local GRID = 4

function ns.CreateChart(parent)
    local c = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    c:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    c:SetBackdropColor(0, 0, 0, 0.35)
    c:SetBackdropBorderColor(1, 1, 1, 0.12)

    local plot = CreateFrame("Frame", nil, c)
    plot:SetPoint("TOPLEFT", 64, -10)
    plot:SetPoint("BOTTOMRIGHT", -10, 22)
    c.plot = plot

    c.lines, c.bars = {}, {}
    c.grid, c.ylab, c.xlab = {}, {}, {}
    for i = 0, GRID do
        local g = plot:CreateTexture(nil, "BACKGROUND")
        g:SetColorTexture(1, 1, 1, 0.07)
        g:SetHeight(1)
        c.grid[i] = g
        local l = c:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        l:SetJustifyH("RIGHT")
        l:SetWidth(58)
        c.ylab[i] = l
    end
    for i = 1, 3 do
        local l = c:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        c.xlab[i] = l
    end

    c.empty = c:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    c.empty:SetPoint("CENTER")

    c.marker = plot:CreateTexture(nil, "OVERLAY")
    c.marker:SetColorTexture(1, 1, 1, 0.35)
    c.marker:SetWidth(1)
    c.marker:Hide()

    -- Légende
    local legend = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    legend:SetPoint("TOPRIGHT", -12, -12)
    legend:SetText("|cff4dccff— Prix min|r   |cffffd11a— Valeur marché|r   |cff9999ccQuantité|r")

    local function Line(i)
        local l = c.lines[i]
        if not l then
            l = plot:CreateLine(nil, "ARTWORK")
            l:SetThickness(2)
            c.lines[i] = l
        end
        return l
    end

    local function Bar(i)
        local b = c.bars[i]
        if not b then
            b = plot:CreateTexture(nil, "BORDER")
            b:SetColorTexture(unpack(COLOR_QTY))
            c.bars[i] = b
        end
        return b
    end

    -- points : { {heure, min, marché, qté}, ... } croissant ; range en heures (nil = tout)
    function c:SetData(points, range)
        self.allPoints, self.range = points or {}, range
        self:Draw()
    end

    function c:Draw()
        for _, l in ipairs(self.lines) do l:Hide() end
        for _, b in ipairs(self.bars) do b:Hide() end
        self.marker:Hide()

        local pts = {}
        local nowH = floor(time() / 3600)
        for _, p in ipairs(self.allPoints or {}) do
            if not self.range or nowH - p[1] <= self.range then pts[#pts + 1] = p end
        end
        self.points = pts

        local W, H = plot:GetWidth(), plot:GetHeight()
        local show = #pts > 0 and W > 0 and H > 0
        for i = 0, GRID do
            self.grid[i]:SetShown(show)
            self.ylab[i]:SetShown(show)
        end
        for i = 1, 3 do self.xlab[i]:SetShown(show) end
        if not show then
            self.empty:SetText("Pas encore d'historique pour cet objet.\nOuvre l'HV et lance une analyse.")
            self.empty:Show()
            return
        end
        self.empty:Hide()

        local lo, hi, qmax = math.huge, 0, 1
        for _, p in ipairs(pts) do
            lo = min(lo, p[2], p[3])
            hi = max(hi, p[2], p[3])
            qmax = max(qmax, p[4])
        end
        if hi <= lo then lo, hi = lo * 0.9, hi * 1.1 + 1 end
        local pad = (hi - lo) * 0.08
        lo, hi = max(0, lo - pad), hi + pad

        local t0, t1 = pts[1][1], pts[#pts][1]
        if self.range then t0 = min(t0, nowH - self.range) end
        if t1 <= t0 then t0, t1 = t0 - 1, t1 + 1 end
        self.t0, self.t1, self.W = t0, t1, W

        local function X(t) return (t - t0) / (t1 - t0) * W end
        local function Y(v) return (v - lo) / (hi - lo) * H end

        for i = 0, GRID do
            local y = H * i / GRID
            local g = self.grid[i]
            g:ClearAllPoints()
            g:SetPoint("BOTTOMLEFT", plot, "BOTTOMLEFT", 0, y)
            g:SetPoint("BOTTOMRIGHT", plot, "BOTTOMRIGHT", 0, y)
            local l = self.ylab[i]
            l:ClearAllPoints()
            l:SetPoint("RIGHT", plot, "BOTTOMLEFT", -4, y)
            l:SetText(ns.MoneyShort(lo + (hi - lo) * i / GRID))
        end

        local fmt = (t1 - t0) <= 72 and "%d/%m %Hh" or "%d/%m"
        local anchors = { "LEFT", "CENTER", "RIGHT" }
        for i = 1, 3 do
            local t = t0 + (t1 - t0) * (i - 1) / 2
            local l = self.xlab[i]
            l:ClearAllPoints()
            l:SetPoint("TOP" .. (anchors[i] == "CENTER" and "" or anchors[i]), plot, "BOTTOM" .. (anchors[i] == "CENTER" and "" or anchors[i]), 0, -4)
            l:SetText(date(fmt, t * 3600))
        end

        -- Quantité : barres en fond
        local bw = max(2, min(14, W / max(1, #pts) * 0.6))
        for i, p in ipairs(pts) do
            local b = Bar(i)
            b:ClearAllPoints()
            b:SetSize(bw, max(1, p[4] / qmax * H * 0.35))
            b:SetPoint("BOTTOM", plot, "BOTTOMLEFT", X(p[1]), 0)
            b:Show()
        end

        local n = 0
        local function Series(idx, color)
            if #pts == 1 then
                n = n + 1
                local l = Line(n)
                local x, y = X(pts[1][1]), Y(pts[1][idx])
                l:SetColorTexture(color[1], color[2], color[3], 1)
                l:SetStartPoint("BOTTOMLEFT", plot, x - 3, y)
                l:SetEndPoint("BOTTOMLEFT", plot, x + 3, y)
                l:Show()
                return
            end
            for i = 2, #pts do
                n = n + 1
                local l = Line(n)
                l:SetColorTexture(color[1], color[2], color[3], 1)
                l:SetStartPoint("BOTTOMLEFT", plot, X(pts[i - 1][1]), Y(pts[i - 1][idx]))
                l:SetEndPoint("BOTTOMLEFT", plot, X(pts[i][1]), Y(pts[i][idx]))
                l:Show()
            end
        end
        Series(3, COLOR_MKT)
        Series(2, COLOR_MIN)
    end

    plot:SetScript("OnSizeChanged", function() if c.allPoints then c:Draw() end end)

    -- Survol : point le plus proche du curseur
    plot:EnableMouse(true)
    local function Hover()
        local pts = c.points
        if not pts or #pts == 0 or not c.W then return end
        local cx = GetCursorPosition() / plot:GetEffectiveScale() - plot:GetLeft()
        local best, bd
        for _, p in ipairs(pts) do
            local x = (p[1] - c.t0) / (c.t1 - c.t0) * c.W
            local d = math.abs(x - cx)
            if not bd or d < bd then best, bd = p, d end
        end
        if best ~= c.hovered then
            c.hovered = best
            local x = (best[1] - c.t0) / (c.t1 - c.t0) * c.W
            c.marker:ClearAllPoints()
            c.marker:SetPoint("TOPLEFT", plot, "TOPLEFT", x, 0)
            c.marker:SetPoint("BOTTOMLEFT", plot, "BOTTOMLEFT", x, 0)
            c.marker:Show()
            GameTooltip:SetOwner(plot, "ANCHOR_CURSOR")
            local recent = floor(time() / 3600) - best[1] <= 48
            GameTooltip:AddLine(date(recent and "%d/%m/%Y %Hh" or "%d/%m/%Y (moyenne du jour)", best[1] * 3600), 1, 1, 1)
            GameTooltip:AddDoubleLine("Prix min", ns.Money(best[2]), 0.3, 0.8, 1, 1, 1, 1)
            GameTooltip:AddDoubleLine("Valeur marché", ns.Money(best[3]), 1, 0.82, 0.1, 1, 1, 1)
            GameTooltip:AddDoubleLine("Quantité", BreakUpLargeNumbers(best[4]), 0.7, 0.7, 0.9, 1, 1, 1)
            GameTooltip:Show()
        end
    end
    plot:SetScript("OnEnter", function() plot:SetScript("OnUpdate", Hover) end)
    plot:SetScript("OnLeave", function()
        plot:SetScript("OnUpdate", nil)
        c.hovered = nil
        c.marker:Hide()
        GameTooltip:Hide()
    end)

    return c
end
