local ADDON, ns = ...

local UI = {}
ns.UI = UI

local CLASS_COLORS = RAID_CLASS_COLORS

-- Wick brand palette — see memory/reference_wick_brand_style.md
-- Fel #4FC778 · Void #0D0A14 · Shadow #171124 · Border #383058 · Text #D4C8A1
local C_BG          = { 0.051, 0.039, 0.078, 0.97 }
local C_HEADER_BG   = { 0.090, 0.067, 0.141, 1 }
local C_BORDER      = { 0.220, 0.188, 0.345, 1 }
local C_GREEN       = { 0.310, 0.780, 0.471, 1 }
local C_TEXT_NORMAL = { 0.831, 0.784, 0.631, 1 }

local BRACKET  = 10
local HEADER_H = 22
local MIN_W, MIN_H = 220, 60

local ICON_SIZE = 22
local ICON_GAP  = 2
local NAME_W    = 90
local ROW_PAD   = 3
local ROW_H     = ICON_SIZE + ROW_PAD
local ROW_TOP   = HEADER_H + 4

local frame
local rows = {}

local function spellIcon(spellId)
    local _, _, icon = GetSpellInfo(spellId)
    return icon
end

local function newTex(parent, layer, c)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND")
    if c then t:SetColorTexture(c[1], c[2], c[3], c[4] or 1) end
    return t
end

-- Four 1px edge textures in C_BORDER.
local function addBorder(f)
    local top    = newTex(f, "BORDER", C_BORDER)
    top:SetPoint("TOPLEFT");    top:SetPoint("TOPRIGHT");    top:SetHeight(1)
    local bot    = newTex(f, "BORDER", C_BORDER)
    bot:SetPoint("BOTTOMLEFT"); bot:SetPoint("BOTTOMRIGHT"); bot:SetHeight(1)
    local left   = newTex(f, "BORDER", C_BORDER)
    left:SetPoint("TOPLEFT");   left:SetPoint("BOTTOMLEFT"); left:SetWidth(1)
    local right  = newTex(f, "BORDER", C_BORDER)
    right:SetPoint("TOPRIGHT"); right:SetPoint("BOTTOMRIGHT"); right:SetWidth(1)
end

-- Fel-green L brackets flush at each frame corner (Wick brand).
-- The BOTTOMRIGHT bracket lives on the resize grip so it acts as the grabber.
local function addCornerAccents(parent, resizeButton)
    for _, point in ipairs({ "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }) do
        local host = (point == "BOTTOMRIGHT") and resizeButton or parent
        local h = host:CreateTexture(nil, "OVERLAY")
        h:SetColorTexture(unpack(C_GREEN))
        h:SetPoint(point, host, point, 0, 0)
        h:SetSize(BRACKET, 2)
        local v = host:CreateTexture(nil, "OVERLAY")
        v:SetColorTexture(unpack(C_GREEN))
        v:SetPoint(point, host, point, 0, 0)
        v:SetSize(2, BRACKET)
    end
end

local function ensureFrame()
    if frame then return frame end

    frame = CreateFrame("Frame", "WicksCDTrackerFrame", UIParent)
    frame:SetSize(380, 200)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:SetResizable(true)
    if frame.SetResizeBounds then
        frame:SetResizeBounds(MIN_W, MIN_H)
    elseif frame.SetMinResize then
        frame:SetMinResize(MIN_W, MIN_H)
    end
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, rp, x, y = self:GetPoint()
        WCDTSettings = WCDTSettings or {}
        WCDTSettings.pos = { p, rp, x, y }
    end)

    -- Flat dark-purple panel background + thin muted-purple border (Wick style).
    local bg = newTex(frame, "BACKGROUND", C_BG)
    bg:SetAllPoints()
    addBorder(frame)

    -- Header strip.
    local header = newTex(frame, "ARTWORK", C_HEADER_BG)
    header:SetPoint("TOPLEFT",  1,  -1)
    header:SetPoint("TOPRIGHT", -1, -1)
    header:SetHeight(HEADER_H)
    local headerSep = newTex(frame, "ARTWORK", C_BORDER)
    headerSep:SetPoint("TOPLEFT",  1, -HEADER_H - 1)
    headerSep:SetPoint("TOPRIGHT", -1, -HEADER_H - 1)
    headerSep:SetHeight(1)

    local title = frame:CreateFontString(nil, "OVERLAY")
    title:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
    title:SetTextColor(C_TEXT_NORMAL[1], C_TEXT_NORMAL[2], C_TEXT_NORMAL[3], 1)
    title:SetPoint("LEFT", frame, "TOPLEFT", 10, -HEADER_H / 2)
    title:SetText("Wick's CD Tracker")

    -- Settings cog in the header's top-right corner.
    local cog = CreateFrame("Button", nil, frame)
    cog:SetSize(14, 14)
    cog:SetPoint("RIGHT", frame, "TOPRIGHT", -6, -HEADER_H / 2)
    local cogTex = cog:CreateTexture(nil, "ARTWORK")
    cogTex:SetAllPoints()
    cogTex:SetTexture("Interface\\Buttons\\UI-OptionsButton")
    cogTex:SetVertexColor(C_TEXT_NORMAL[1], C_TEXT_NORMAL[2], C_TEXT_NORMAL[3], 1)
    cog:SetScript("OnEnter", function() cogTex:SetVertexColor(unpack(C_GREEN)) end)
    cog:SetScript("OnLeave", function() cogTex:SetVertexColor(C_TEXT_NORMAL[1], C_TEXT_NORMAL[2], C_TEXT_NORMAL[3], 1) end)
    cog:SetScript("OnClick", function() if ns.Settings then ns.Settings:Toggle() end end)

    local grip = CreateFrame("Button", nil, frame)
    grip:SetSize(BRACKET + 2, BRACKET + 2)
    grip:SetPoint("BOTTOMRIGHT", 0, 0)
    grip:EnableMouse(true)
    grip:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" then frame:StartSizing("BOTTOMRIGHT") end
    end)
    grip:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing()
        WCDTSettings = WCDTSettings or {}
        WCDTSettings.size = { frame:GetWidth(), frame:GetHeight() }
    end)

    addCornerAccents(frame, grip)

    if WCDTSettings and WCDTSettings.pos then
        local p, rp, x, y = unpack(WCDTSettings.pos)
        frame:ClearAllPoints()
        frame:SetPoint(p, UIParent, rp, x, y)
    end
    if WCDTSettings and WCDTSettings.size then
        frame:SetSize(unpack(WCDTSettings.size))
    end
    return frame
end

local function makeIcon(row)
    local btn = CreateFrame("Frame", nil, row)
    btn:SetSize(ICON_SIZE, ICON_SIZE)

    local tex = btn:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    btn.tex = tex

    local cd = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
    cd:SetAllPoints()
    cd:SetDrawEdge(false)
    if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(true) end
    btn.cd = cd

    local txt = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    txt:SetPoint("CENTER", 0, 0)
    txt:SetTextColor(1, 1, 1, 1)
    btn.text = txt
    return btn
end

local function getRow(i)
    if rows[i] then return rows[i] end
    local y = -ROW_TOP - (i - 1) * ROW_H
    local row = CreateFrame("Frame", nil, frame)
    row:SetHeight(ICON_SIZE)
    row:SetPoint("TOPLEFT", 8, y)
    row:SetPoint("TOPRIGHT", -8, y)

    local name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    name:SetPoint("LEFT", 0, 0)
    name:SetWidth(NAME_W)
    name:SetJustifyH("LEFT")
    row.name = name

    row.icons = {}
    rows[i] = row
    return row
end

local function formatRemaining(r)
    if r >= 60 then
        return string.format("%d", math.ceil(r / 60)) .. "m"
    elseif r >= 10 then
        return tostring(math.ceil(r))
    else
        return string.format("%.1f", r)
    end
end

function UI:Refresh()
    ensureFrame()

    -- Build sorted player list (alphabetical by name, stable is better than
    -- ready-first when there are many icons per row).
    local list = {}
    local maxIcons = 0
    for guid, info in pairs(ns.roster) do
        list[#list + 1] = { guid = guid, name = info.name, class = info.class }
        local n = 0
        for _, s in ipairs(ns.CLASS_SPELLS[info.class] or {}) do
            if not ns.Settings or ns.Settings:IsSpellEnabled(info.class, s.id) then
                n = n + 1
            end
        end
        if n > maxIcons then maxIcons = n end
    end
    table.sort(list, function(a, b) return a.name < b.name end)

    -- Enforce a minimum frame width that fits the widest row's icons. Frames
    -- don't clip children, so without this the icons visually spill past the
    -- backdrop on classes with many tracked CDs.
    local needed = 16 + NAME_W + 4 + maxIcons * (ICON_SIZE + ICON_GAP)
    if frame:GetWidth() < needed then frame:SetWidth(needed) end
    if frame.SetResizeBounds then
        frame:SetResizeBounds(needed, MIN_H)
    elseif frame.SetMinResize then
        frame:SetMinResize(needed, MIN_H)
    end

    local now = GetTime()
    for i, r in ipairs(list) do
        local row = getRow(i)
        row:Show()

        local color = CLASS_COLORS[r.class] or { r = 1, g = 1, b = 1 }
        row.name:SetText(r.name)
        row.name:SetTextColor(color.r, color.g, color.b)

        local spells = ns.CLASS_SPELLS[r.class] or {}
        local cdMap  = ns.cooldowns[r.guid]

        local renderIdx = 0
        for _, s in ipairs(spells) do
            if ns.Settings and not ns.Settings:IsSpellEnabled(r.class, s.id) then
                -- skip disabled spells entirely
            else
                renderIdx = renderIdx + 1
                local ico = row.icons[renderIdx] or makeIcon(row)
                row.icons[renderIdx] = ico
                ico:ClearAllPoints()
                if renderIdx == 1 then
                    ico:SetPoint("LEFT", row.name, "RIGHT", 4, 0)
                else
                    ico:SetPoint("LEFT", row.icons[renderIdx - 1], "RIGHT", ICON_GAP, 0)
                end
                ico.tex:SetTexture(spellIcon(s.id))
                ico:Show()

                local cdState = cdMap and cdMap[s.id]
                if cdState then
                    local remaining = (cdState.startTime + cdState.duration) - now
                    if remaining > 0 then
                        ico.tex:SetDesaturated(true)
                        ico.cd:SetCooldown(cdState.startTime, cdState.duration)
                        ico.text:SetText(formatRemaining(remaining))
                    else
                        cdMap[s.id] = nil
                        ico.tex:SetDesaturated(false)
                        ico.cd:Clear()
                        ico.text:SetText("")
                    end
                else
                    ico.tex:SetDesaturated(false)
                    ico.cd:Clear()
                    ico.text:SetText("")
                end
            end
        end
        -- Hide any extra icons from a longer prior render or class with more CDs.
        for idx = renderIdx + 1, #row.icons do row.icons[idx]:Hide() end
    end
    for i = #list + 1, #rows do rows[i]:Hide() end
end

function UI:Toggle()
    ensureFrame()
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
        UI:Refresh()
    end
end

function UI:ResetPosition()
    ensureFrame()
    frame:ClearAllPoints()
    frame:SetPoint("CENTER")
    WCDTSettings = WCDTSettings or {}
    WCDTSettings.pos = nil
end

-- Live countdown tick: updates the numeric text and clears expired CDs.
local ticker = CreateFrame("Frame")
local accum = 0
ticker:SetScript("OnUpdate", function(_, elapsed)
    accum = accum + elapsed
    if accum < 0.1 then return end
    accum = 0
    if frame and frame:IsShown() then
        local anyActive = false
        for _, perPlayer in pairs(ns.cooldowns) do
            if next(perPlayer) then anyActive = true break end
        end
        if anyActive then UI:Refresh() end
    end
end)
