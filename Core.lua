local ADDON, ns = ...

ns.roster = {}        -- ownerGUID -> { name, class, unit }
ns.petToOwner = {}    -- petGUID  -> ownerGUID
ns.cooldowns = {}     -- ownerGUID -> { [spellId] = { startTime, duration } }

-- Per-class spell list. `id` is the canonical spell used for display;
-- `aliases` are additional ranks/IDs that count as the same ability for CD
-- tracking purposes. `pet = true` means the cast is made by the player's pet
-- (CD attributed to the owner).
ns.CLASS_SPELLS = {
    WARRIOR = {
        { id = 6552,  cd = 10,  aliases = { 6554 }, interrupt = true },              -- Pummel
        { id = 72,    cd = 12,  aliases = { 1671, 1672, 29704 }, interrupt = true }, -- Shield Bash
        { id = 12292, cd = 180 },                                     -- Death Wish
        { id = 18499, cd = 30 },                                      -- Berserker Rage
        { id = 5246,  cd = 180 },                                     -- Intimidating Shout
    },
    ROGUE = {
        { id = 1766,  cd = 10,  aliases = { 1767, 1768, 1769, 38768 }, interrupt = true }, -- Kick
        { id = 5277,  cd = 300, aliases = { 26669 } },                -- Evasion
        { id = 2094,  cd = 180 },                                     -- Blind
        { id = 31224, cd = 60 },                                      -- Cloak of Shadows
        { id = 1856,  cd = 300, aliases = { 1857 } },                 -- Vanish
        { id = 13750, cd = 300 },                                     -- Adrenaline Rush
        { id = 13877, cd = 120 },                                     -- Blade Flurry
    },
    MAGE = {
        { id = 2139,  cd = 24,  interrupt = true },                   -- Counterspell
        { id = 45438, cd = 300 },                                     -- Ice Block
        { id = 12051, cd = 480 },                                     -- Evocation
        { id = 12042, cd = 180 },                                     -- Arcane Power
        { id = 12472, cd = 180 },                                     -- Icy Veins
        { id = 12043, cd = 180 },                                     -- Presence of Mind
    },
    PRIEST = {
        { id = 34433, cd = 300 },                                     -- Shadowfiend
        { id = 6346,  cd = 180 },                                     -- Fear Ward
        { id = 10060, cd = 180 },                                     -- Power Infusion
        { id = 15487, cd = 45,  interrupt = true },                   -- Silence
        { id = 14751, cd = 180 },                                     -- Inner Focus
    },
    WARLOCK = {
        { id = 19647, cd = 24,  aliases = { 19244 }, pet = true, interrupt = true }, -- Spell Lock
        { id = 6789,  cd = 120, aliases = { 17925, 17926, 27223 } },              -- Death Coil
        { id = 5484,  cd = 40,  aliases = { 17928 } },                            -- Howl of Terror
    },
    HUNTER = {
        { id = 3045,  cd = 300 },                                     -- Rapid Fire
        { id = 19574, cd = 120 },                                     -- Bestial Wrath
        { id = 19263, cd = 300 },                                     -- Deterrence
        { id = 34477, cd = 120 },                                     -- Misdirection
        { id = 19503, cd = 30,  interrupt = true },                   -- Scatter Shot
        { id = 5384,  cd = 30 },                                      -- Feign Death
    },
    DRUID = {
        { id = 29166, cd = 360 },                                     -- Innervate
        { id = 17116, cd = 180 },                                     -- Nature's Swiftness
        { id = 16979, cd = 15,  interrupt = true },                   -- Feral Charge
        { id = 22812, cd = 60 },                                      -- Barkskin
        { id = 22842, cd = 180 },                                     -- Frenzied Regeneration
    },
    PALADIN = {
        { id = 853,   cd = 60,  aliases = { 5588, 5589, 10308 } },    -- Hammer of Justice
        { id = 642,   cd = 300, aliases = { 1020 } },                 -- Divine Shield
        { id = 498,   cd = 300, aliases = { 5573 } },                 -- Divine Protection
        { id = 10278, cd = 300, aliases = { 1022, 5599 } },           -- Blessing of Protection
        { id = 1044,  cd = 25 },                                      -- Blessing of Freedom
        { id = 31884, cd = 180 },                                     -- Avenging Wrath
    },
    SHAMAN = {
        { id = 2825,  cd = 600 },                                     -- Bloodlust
        { id = 32182, cd = 600 },                                     -- Heroism
        { id = 25454, cd = 6,   aliases = { 8042, 8044, 8045, 8046, 10412, 10413, 10414 }, interrupt = true }, -- Earth Shock
        { id = 16188, cd = 180 },                                     -- Nature's Swiftness
        { id = 30823, cd = 120 },                                     -- Shamanistic Rage
        { id = 8177,  cd = 15 },                                      -- Grounding Totem
    },
}

-- Flat lookup built from CLASS_SPELLS: spellId -> { class, cd, displayId, pet }.
-- Every alias also resolves here, mapping back to the canonical displayId so
-- any rank of a spell triggers the CD on the display icon.
ns.SPELL_LOOKUP = {}
do
    for class, list in pairs(ns.CLASS_SPELLS) do
        for _, s in ipairs(list) do
            local entry = {
                class     = class,
                cd        = s.cd,
                displayId = s.id,
                pet       = s.pet,
                interrupt = s.interrupt,
            }
            ns.SPELL_LOOKUP[s.id] = entry
            if s.aliases then
                for _, alt in ipairs(s.aliases) do
                    ns.SPELL_LOOKUP[alt] = entry
                end
            end
        end
    end
end

local function RefreshRoster()
    wipe(ns.roster)
    wipe(ns.petToOwner)

    local function addUnit(unit)
        if not UnitExists(unit) then return end
        local guid = UnitGUID(unit)
        if not guid then return end
        local _, class = UnitClass(unit)
        if not ns.CLASS_SPELLS[class] then return end
        ns.roster[guid] = { name = UnitName(unit), class = class, unit = unit }

        if class == "WARLOCK" or class == "HUNTER" then
            local petUnit = (unit == "player") and "pet" or (unit .. "pet")
            local petGUID = UnitGUID(petUnit)
            if petGUID then ns.petToOwner[petGUID] = guid end
        end
    end

    addUnit("player")
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do addUnit("raid" .. i) end
    else
        for i = 1, GetNumSubgroupMembers() do addUnit("party" .. i) end
    end

    if ns.UI then ns.UI:Refresh() end
end

local function OnCombatLog()
    local _, sub, _, sourceGUID, _, _, _, _, _, _, _, spellId = CombatLogGetCurrentEventInfo()
    if sub ~= "SPELL_CAST_SUCCESS" then return end

    local info = ns.SPELL_LOOKUP[spellId]
    if not info then return end

    local owner = info.pet and ns.petToOwner[sourceGUID] or sourceGUID
    if not owner or not ns.roster[owner] then return end

    -- Respect user settings: don't track CDs the user has disabled for this class.
    if ns.Settings and not ns.Settings:IsSpellEnabled(info.class, info.displayId) then return end

    ns.cooldowns[owner] = ns.cooldowns[owner] or {}
    ns.cooldowns[owner][info.displayId] = {
        startTime = GetTime(),
        duration  = info.cd,
    }
    if ns.UI then ns.UI:Refresh() end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("GROUP_ROSTER_UPDATE")
events:RegisterEvent("UNIT_PET")
events:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
events:SetScript("OnEvent", function(_, event)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        OnCombatLog()
    else
        RefreshRoster()
    end
end)

SLASH_WICKSCDT1 = "/cds"
SLASH_WICKSCDT2 = "/wcdt"
SlashCmdList.WICKSCDT = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "reset" then
        if ns.UI then ns.UI:ResetPosition() end
    elseif msg == "settings" or msg == "config" or msg == "options" then
        if ns.Settings then ns.Settings:Toggle() end
    elseif msg == "debug" then
        print("|cff44ff44Wick's CD Tracker|r roster:")
        for guid, r in pairs(ns.roster) do
            print(" -", r.name, r.class, guid)
        end
    else
        if ns.UI then ns.UI:Toggle() end
    end
end
