local ADDON, ns = ...

ns.Settings = {}
local S = ns.Settings

-- Wick brand palette (see memory/reference_wick_brand_style.md).
local C_BG          = { 0.05, 0.04, 0.08, 0.97 }
local C_HEADER_BG   = { 0.09, 0.07, 0.16, 1 }
local C_BORDER      = { 0.22, 0.18, 0.36, 1 }
local C_GREEN       = { 0.31, 0.78, 0.47, 1 }
local C_TEXT_NORMAL = { 0.83, 0.78, 0.63, 1 }
local C_TAB_BG      = { 0.07, 0.06, 0.12, 1 }
local C_TAB_BG_SEL  = { 0.14, 0.11, 0.23, 1 }
local C_INPUT_BG    = { 0.12, 0.10, 0.20, 1 }

local CLASS_COLORS = RAID_CLASS_COLORS

local BRACKET    = 10
local HEADER_H   = 22
local GLOBAL_H   = 26
local TAB_H      = 22
local ROW_H      = 26
local FRAME_W    = 360
local FRAME_PAD  = 10

local CLASSES = {
    "WARRIOR", "ROGUE", "MAGE", "PRIEST", "WARLOCK",
    "HUNTER", "DRUID", "PALADIN", "SHAMAN",
}
local CLASS_LABELS = {
    WARRIOR = "Warrior", ROGUE = "Rogue",   MAGE = "Mage",
    PRIEST  = "Priest",  WARLOCK = "Warlock", HUNTER = "Hunter",
    DRUID   = "Druid",   PALADIN = "Paladin", SHAMAN = "Shaman",
}

local frame
local tabs = {}
local rows = {}
local selectedClass = "WARRIOR"

-- ---------- settings accessors (safe before frame exists) ----------

function S:IsSpellEnabled(class, spellId)
    -- Kicks-only mode: hide anything not flagged as an interrupt.
    if WCDTSettings and WCDTSettings.kicksOnly then
        local info = ns.SPELL_LOOKUP and ns.SPELL_LOOKUP[spellId]
        if not info or not info.interrupt then return false end
    end
    local t = WCDTSettings and WCDTSettings.enabled and WCDTSettings.enabled[class]
    if not t then return true end
    if t[spellId] == false then return false end
    return true
end

function S:IsKicksOnly()
    return WCDTSettings and WCDTSettings.kicksOnly or false
end

function S:SetKicksOnly(enabled)
    WCDTSettings = WCDTSettings or {}
    WCDTSettings.kicksOnly = enabled and true or nil
    if ns.UI then ns.UI:Refresh() end
end

function S:SetSpellEnabled(class, spellId, enabled)
    WCDTSettings = WCDTSettings or {}
    WCDTSettings.enabled = WCDTSettings.enabled or {}
    WCDTSettings.enabled[class] = WCDTSettings.enabled[class] or {}
    -- Store false explicitly; nil means "default (enabled)" - keeps the table small.
    if enabled then
        WCDTSettings.enabled[class][spellId] = nil
    else
        WCDTSettings.enabled[class][spellId] = false
    end
    if ns.UI then ns.UI:Refresh() end
end

-- ---------- chrome helpers ----------

local function newTex(parent, layer, c)
    local t = parent:CreateTexture(nil, layer or "BACKGROUND")
    if c then t:SetColorTexture(c[1], c[2], c[3], c[4] or 1) end
    return t
end

local function addBorder(f)
    local t = newTex(f, "BORDER", C_BORDER); t:SetPoint("TOPLEFT");    t:SetPoint("TOPRIGHT");    t:SetHeight(1)
    local b = newTex(f, "BORDER", C_BORDER); b:SetPoint("BOTTOMLEFT"); b:SetPoint("BOTTOMRIGHT"); b:SetHeight(1)
    local l = newTex(f, "BORDER", C_BORDER); l:SetPoint("TOPLEFT");    l:SetPoint("BOTTOMLEFT");  l:SetWidth(1)
    local r = newTex(f, "BORDER", C_BORDER); r:SetPoint("TOPRIGHT");   r:SetPoint("BOTTOMRIGHT"); r:SetWidth(1)
end

local function addCorners(f)
    for _, p in ipairs({ "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }) do
        local h = f:CreateTexture(nil, "OVERLAY"); h:SetColorTexture(unpack(C_GREEN))
        h:SetPoint(p, f, p, 0, 0); h:SetSize(BRACKET, 2)
        local v = f:CreateTexture(nil, "OVERLAY"); v:SetColorTexture(unpack(C_GREEN))
        v:SetPoint(p, f, p, 0, 0); v:SetSize(2, BRACKET)
    end
end

local function newText(parent, size, color)
    local t = parent:CreateFontString(nil, "OVERLAY")
    t:SetFont("Fonts\\FRIZQT__.TTF", size or 11, "")
    local c = color or C_TEXT_NORMAL
    t:SetTextColor(c[1], c[2], c[3], c[4] or 1)
    return t
end

local function makeCheckbox(parent)
    local cb = CreateFrame("Button", nil, parent)
    cb:SetSize(14, 14)
    local bg = newTex(cb, "BACKGROUND", C_INPUT_BG); bg:SetAllPoints()
    -- thin border
    local t = newTex(cb, "BORDER", C_BORDER); t:SetPoint("TOPLEFT");    t:SetPoint("TOPRIGHT");    t:SetHeight(1)
    local b = newTex(cb, "BORDER", C_BORDER); b:SetPoint("BOTTOMLEFT"); b:SetPoint("BOTTOMRIGHT"); b:SetHeight(1)
    local l = newTex(cb, "BORDER", C_BORDER); l:SetPoint("TOPLEFT");    l:SetPoint("BOTTOMLEFT");  l:SetWidth(1)
    local r = newTex(cb, "BORDER", C_BORDER); r:SetPoint("TOPRIGHT");   r:SetPoint("BOTTOMRIGHT"); r:SetWidth(1)
    local check = newTex(cb, "ARTWORK", C_GREEN)
    check:SetPoint("TOPLEFT", 3, -3); check:SetPoint("BOTTOMRIGHT", -3, 3)
    check:Hide()
    cb.check = check
    function cb:SetChecked(v) if v then check:Show() else check:Hide() end end
    function cb:IsCheckedNow() return check:IsShown() end
    return cb
end

local function makeTab(class)
    local btn = CreateFrame("Button", nil, frame)
    btn:SetSize(70, TAB_H)

    local bg = newTex(btn, "BACKGROUND", C_TAB_BG); bg:SetAllPoints()
    btn.bg = bg

    local color = CLASS_COLORS[class] or { r = 1, g = 1, b = 1 }
    local text = newText(btn, 10, { color.r, color.g, color.b, 1 })
    text:SetPoint("CENTER")
    text:SetText(CLASS_LABELS[class])

    local indicator = newTex(btn, "OVERLAY", C_GREEN)
    indicator:SetPoint("BOTTOMLEFT"); indicator:SetPoint("BOTTOMRIGHT"); indicator:SetHeight(2)
    indicator:Hide()
    btn.indicator = indicator

    btn.class = class
    btn:SetScript("OnClick", function()
        selectedClass = class
        S:UpdateContent()
    end)
    return btn
end

local function getRow(i)
    if rows[i] then return rows[i] end
    local row = CreateFrame("Frame", nil, frame)
    row:SetHeight(ROW_H - 4)

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18); icon:SetPoint("LEFT", 4, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.icon = icon

    local name = newText(row, 11)
    name:SetPoint("LEFT", icon, "RIGHT", 8, 0)
    name:SetJustifyH("LEFT")
    row.name = name

    local cb = makeCheckbox(row)
    cb:SetPoint("RIGHT", -8, 0)
    row.cb = cb

    rows[i] = row
    return row
end

-- ---------- public update ----------

function S:UpdateContent()
    if not frame then return end

    for _, tab in ipairs(tabs) do
        if tab.class == selectedClass then
            tab.indicator:Show()
            tab.bg:SetColorTexture(C_TAB_BG_SEL[1], C_TAB_BG_SEL[2], C_TAB_BG_SEL[3], 1)
        else
            tab.indicator:Hide()
            tab.bg:SetColorTexture(C_TAB_BG[1], C_TAB_BG[2], C_TAB_BG[3], 1)
        end
    end

    local spells = ns.CLASS_SPELLS[selectedClass] or {}
    local listTop = HEADER_H + GLOBAL_H + TAB_H * 2 + 8  -- header + global row + 2 tab rows + gap

    for i, spell in ipairs(spells) do
        local row = getRow(i)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", FRAME_PAD, -(listTop + (i - 1) * ROW_H))
        row:SetPoint("RIGHT", -FRAME_PAD, 0)

        local spellName, _, texture = GetSpellInfo(spell.id)
        row.icon:SetTexture(texture)
        row.name:SetText(spellName or ("Spell " .. spell.id))

        row.cb:SetChecked(S:IsSpellEnabled(selectedClass, spell.id))
        row.cb.spellId = spell.id
        row.cb:SetScript("OnClick", function(self)
            local newState = not self:IsCheckedNow()
            self:SetChecked(newState)
            S:SetSpellEnabled(selectedClass, self.spellId, newState)
        end)

        row:Show()
    end
    for i = #spells + 1, #rows do rows[i]:Hide() end

    local bottomBar = 36
    frame:SetHeight(listTop + #spells * ROW_H + bottomBar)
end

-- ---------- frame construction ----------

local function ensureFrame()
    if frame then return frame end

    frame = CreateFrame("Frame", "WicksCDTrackerSettingsFrame", UIParent)
    frame:SetSize(FRAME_W, 420)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetFrameStrata("DIALOG")
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

    local bg = newTex(frame, "BACKGROUND", C_BG); bg:SetAllPoints()
    addBorder(frame)

    -- Header
    local header = newTex(frame, "ARTWORK", C_HEADER_BG)
    header:SetPoint("TOPLEFT", 1, -1); header:SetPoint("TOPRIGHT", -1, -1); header:SetHeight(HEADER_H)
    local headerSep = newTex(frame, "ARTWORK", C_BORDER)
    headerSep:SetPoint("TOPLEFT", 1, -HEADER_H - 1); headerSep:SetPoint("TOPRIGHT", -1, -HEADER_H - 1); headerSep:SetHeight(1)

    local title = newText(frame, 12)
    title:SetPoint("LEFT", frame, "TOPLEFT", 10, -HEADER_H / 2)
    title:SetText("Wick's CD Tracker - Settings")

    local closeBtn = CreateFrame("Button", nil, frame)
    closeBtn:SetSize(HEADER_H - 4, HEADER_H - 4)
    closeBtn:SetPoint("RIGHT", frame, "TOPRIGHT", -4, -HEADER_H / 2)
    local closeText = newText(closeBtn, 14)
    closeText:SetPoint("CENTER"); closeText:SetText("×")
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    -- "Interrupts Only" global toggle, placed between header and class tabs.
    local kicksRow = CreateFrame("Frame", nil, frame)
    kicksRow:SetHeight(GLOBAL_H)
    kicksRow:SetPoint("TOPLEFT",  1, -(HEADER_H + 1))
    kicksRow:SetPoint("TOPRIGHT", -1, -(HEADER_H + 1))

    local kicksLabel = newText(kicksRow, 11)
    kicksLabel:SetPoint("LEFT", FRAME_PAD, 0)
    kicksLabel:SetText("Interrupts only")

    local kicksCb = makeCheckbox(kicksRow)
    kicksCb:SetPoint("LEFT", kicksLabel, "RIGHT", 8, 0)
    kicksCb:SetChecked(S:IsKicksOnly())
    kicksCb:SetScript("OnClick", function(self)
        local newState = not self:IsCheckedNow()
        self:SetChecked(newState)
        S:SetKicksOnly(newState)
    end)
    frame.kicksCb = kicksCb

    local globalSep = newTex(frame, "ARTWORK", C_BORDER)
    globalSep:SetPoint("TOPLEFT",  1, -(HEADER_H + GLOBAL_H + 1))
    globalSep:SetPoint("TOPRIGHT", -1, -(HEADER_H + GLOBAL_H + 1))
    globalSep:SetHeight(1)

    -- Tabs: 9 classes across 2 rows of up to 5
    for i, class in ipairs(CLASSES) do
        local tab = makeTab(class)
        local col = (i - 1) % 5
        local rowIdx = math.floor((i - 1) / 5)
        tab:SetPoint("TOPLEFT", 4 + col * 71, -(HEADER_H + GLOBAL_H + 2 + rowIdx * (TAB_H + 2)))
        tabs[#tabs + 1] = tab
    end

    -- Enable / Disable all buttons along the bottom
    local function makeBottomBtn(label, color, onClick)
        local btn = CreateFrame("Button", nil, frame)
        btn:SetSize(110, 22)
        local bbg = newTex(btn, "BACKGROUND", C_TAB_BG); bbg:SetAllPoints()
        local bt = newTex(btn, "BORDER", C_BORDER); bt:SetPoint("TOPLEFT");    bt:SetPoint("TOPRIGHT");    bt:SetHeight(1)
        local bb = newTex(btn, "BORDER", C_BORDER); bb:SetPoint("BOTTOMLEFT"); bb:SetPoint("BOTTOMRIGHT"); bb:SetHeight(1)
        local bl = newTex(btn, "BORDER", C_BORDER); bl:SetPoint("TOPLEFT");    bl:SetPoint("BOTTOMLEFT");  bl:SetWidth(1)
        local br = newTex(btn, "BORDER", C_BORDER); br:SetPoint("TOPRIGHT");   br:SetPoint("BOTTOMRIGHT"); br:SetWidth(1)
        local t = newText(btn, 11, color)
        t:SetPoint("CENTER"); t:SetText(label)
        btn:SetScript("OnClick", onClick)
        return btn
    end

    local enableBtn = makeBottomBtn("Enable All", C_GREEN, function()
        for _, s in ipairs(ns.CLASS_SPELLS[selectedClass] or {}) do
            S:SetSpellEnabled(selectedClass, s.id, true)
        end
        S:UpdateContent()
    end)
    enableBtn:SetPoint("BOTTOMLEFT", 10, 10)

    local disableBtn = makeBottomBtn("Disable All", C_TEXT_NORMAL, function()
        for _, s in ipairs(ns.CLASS_SPELLS[selectedClass] or {}) do
            S:SetSpellEnabled(selectedClass, s.id, false)
        end
        S:UpdateContent()
    end)
    disableBtn:SetPoint("BOTTOMRIGHT", -10, 10)

    addCorners(frame)
    frame:Hide()
    return frame
end

function S:Show()
    ensureFrame()
    if not ns.CLASS_SPELLS[selectedClass] then
        local _, playerClass = UnitClass("player")
        selectedClass = ns.CLASS_SPELLS[playerClass] and playerClass or "WARRIOR"
    end
    if frame.kicksCb then frame.kicksCb:SetChecked(S:IsKicksOnly()) end
    S:UpdateContent()
    frame:Show()
end

function S:Toggle()
    ensureFrame()
    if frame:IsShown() then frame:Hide() else S:Show() end
end
