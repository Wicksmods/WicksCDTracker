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
local C_TEXT_DIM    = { 0.55, 0.52, 0.42, 1 }

local BRACKET  = 10
local HEADER_H = 32
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
-- Pass a resizeButton to parent the BOTTOMRIGHT bracket to it (so the bracket
-- doubles as a resize grabber). Pass nil (or omit) to parent all four
-- brackets to the frame — CD Tracker now auto-sizes to its roster, so it
-- omits the grip.
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
    -- Frame size is fully data-driven in UI:Refresh (width = widest row,
    -- height = one row per tracked player). No user resize — closed the
    -- loop on "rows spilling past the backdrop."
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

    -- ---- HEADER ----
    local header = CreateFrame("Frame", nil, frame)
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    header:SetHeight(HEADER_H)

    local headerBG = newTex(header, "BACKGROUND", C_HEADER_BG)
    headerBG:SetAllPoints()

    -- Green underline on header
    local headerLine = newTex(header, "BORDER")
    headerLine:SetColorTexture(C_GREEN[1], C_GREEN[2], C_GREEN[3], 0.35)
    headerLine:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 40, 0)
    headerLine:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", -40, 0)
    headerLine:SetHeight(1)

    -- Header bottom border
    local headerBotBorder = newTex(header, "BORDER", C_BORDER)
    headerBotBorder:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
    headerBotBorder:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, 0)
    headerBotBorder:SetHeight(1)

    local title = header:CreateFontString(nil, "OVERLAY")
    title:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
    title:SetText("|cff4FC778Wick's|r |cffD4C8A1CD Tracker|r")
    title:SetPoint("LEFT", header, "LEFT", 12, 0)

    -- Close (✕) button at far top-right of the header.
    local closeBtn = CreateFrame("Button", nil, header)
    closeBtn:SetSize(16, 16)
    closeBtn:SetPoint("RIGHT", header, "RIGHT", -8, 0)

    local closeBG = newTex(closeBtn, "BACKGROUND", C_HEADER_BG)
    closeBG:SetAllPoints()
    addBorder(closeBtn)

    local closeText = closeBtn:CreateFontString(nil, "OVERLAY")
    closeText:SetFont("Fonts\\FRIZQT__.TTF", 9, "")
    closeText:SetText("✕")
    closeText:SetTextColor(C_TEXT_DIM[1], C_TEXT_DIM[2], C_TEXT_DIM[3], 1)
    closeText:SetAllPoints()
    closeText:SetJustifyH("CENTER")
    closeText:SetJustifyV("MIDDLE")
    closeBtn:SetScript("OnEnter", function() closeText:SetTextColor(1, 0.3, 0.3, 1) end)
    closeBtn:SetScript("OnLeave", function() closeText:SetTextColor(C_TEXT_DIM[1], C_TEXT_DIM[2], C_TEXT_DIM[3], 1) end)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    -- Settings cog sits to the left of the close button (12px gap).
    local cog = CreateFrame("Button", nil, header)
    cog:SetSize(14, 14)
    cog:SetPoint("RIGHT", closeBtn, "LEFT", -12, 0)
    local cogTex = cog:CreateTexture(nil, "ARTWORK")
    cogTex:SetAllPoints()
    cogTex:SetTexture("Interface\\Buttons\\UI-OptionsButton")
    cogTex:SetVertexColor(C_TEXT_NORMAL[1], C_TEXT_NORMAL[2], C_TEXT_NORMAL[3], 1)
    cog:SetScript("OnEnter", function() cogTex:SetVertexColor(unpack(C_GREEN)) end)
    cog:SetScript("OnLeave", function() cogTex:SetVertexColor(C_TEXT_NORMAL[1], C_TEXT_NORMAL[2], C_TEXT_NORMAL[3], 1) end)
    cog:SetScript("OnClick", function() if ns.Settings then ns.Settings:Toggle() end end)

    -- Make header draggable too
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() frame:StartMoving() end)
    header:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        local p, _, rp, x, y = frame:GetPoint()
        WCDTSettings = WCDTSettings or {}
        WCDTSettings.pos = { p, rp, x, y }
    end)

    -- All four L-brackets anchor to the frame itself (no resize grip anymore).
    addCornerAccents(frame)

    if WCDTSettings and WCDTSettings.pos then
        local p, rp, x, y = unpack(WCDTSettings.pos)
        frame:ClearAllPoints()
        frame:SetPoint(p, UIParent, rp, x, y)
    end
    -- Intentionally ignore any legacy WCDTSettings.size — frame sizes itself
    -- to the roster in UI:Refresh.
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

    -- Frame size is fully data-driven so the backdrop always covers every
    -- row: width fits the widest row's icons, height fits one row per
    -- tracked player plus the header. Frames don't clip children, so
    -- without this, rows visually spill past the backdrop.
    local neededW = 16 + NAME_W + 4 + maxIcons * (ICON_SIZE + ICON_GAP)
    local neededH = ROW_TOP + #list * ROW_H + 4
    frame:SetSize(math.max(MIN_W, neededW), math.max(MIN_H, neededH))

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
