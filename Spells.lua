local _, PartyOffCDCore = ...
PartyOffCDCore = PartyOffCDCore or _G.PartyOffCDCore

local PartyOffCD = _G.PartyOffCD
assert(PartyOffCD, "PartyOffCD: frame missing before loading Spells.lua")
assert(PartyOffCDCore, "PartyOffCD: core missing before loading Spells.lua")

local DB_DEFAULTS = PartyOffCDCore.DB_DEFAULTS or PartyOffCDCore.DEFAULTS
local MAX_TRACKER_COLUMNS = PartyOffCDCore.MAX_TRACKER_COLUMNS or 8
local MAX_VERTICAL_TRACKER_COLUMNS = PartyOffCDCore.MAX_VERTICAL_TRACKER_COLUMNS or 4
local MIN_TRACKER_ICON_SCALE = PartyOffCDCore.MIN_TRACKER_ICON_SCALE or 10
local MAX_TRACKER_ICON_SCALE = PartyOffCDCore.MAX_TRACKER_ICON_SCALE or 100
local BASE_ICON_SIZE = PartyOffCDCore.ICON_SIZE or 30

local SPELL_TYPE_PRIORITY = {
    OFF = 1,
    DEF = 2,
    INT = 3,
}

local CLASS_ORDER = {
    "PALADIN",
    "EVOKER",
    "MAGE",
    "PRIEST",
    "ROGUE",
    "HUNTER",
    "SHAMAN",
    "MONK",
    "WARLOCK",
    "WARRIOR",
    "DRUID",
    "DEATHKNIGHT",
    "DEMONHUNTER",
}

local CLASS_LABELS = {
    PALADIN = "Paladin",
    EVOKER = "Evoker",
    MAGE = "Mage",
    PRIEST = "Priest",
    ROGUE = "Rogue",
    HUNTER = "Hunter",
    SHAMAN = "Shaman",
    MONK = "Monk",
    WARLOCK = "Warlock",
    WARRIOR = "Warrior",
    DRUID = "Druid",
    DEATHKNIGHT = "Death Knight",
    DEMONHUNTER = "Demon Hunter",
}

local SPEC_ALIASES = {
    PALADIN = {
        HOLY = 65,
        PROTECTION = 66,
        RETRIBUTION = 70,
    },
    EVOKER = {
        DEVASTATION = 1467,
        PRESERVATION = 1468,
        AUGMENTATION = 1473,
    },
    MAGE = {
        ARCANE = 62,
        FIRE = 63,
        FROST = 64,
    },
    PRIEST = {
        DISC = 256,
        DISCIPLINE = 256,
        HOLY = 257,
        SHADOW = 258,
    },
    ROGUE = {
        ASSASSINATION = 259,
        OUTLAW = 260,
        SUBTLETY = 261,
    },
    HUNTER = {
        BM = 253,
        BEASTMASTERY = 253,
        BEAST_MASTERY = 253,
        MARKSMANSHIP = 254,
        MM = 254,
        SURVIVAL = 255,
        SV = 255,
    },
    SHAMAN = {
        ELEMENTAL = 262,
        ENHANCEMENT = 263,
        RESTORATION = 264,
        RESTO = 264,
    },
    MONK = {
        BREWMASTER = 268,
        MISTWEAVER = 270,
        WINDWALKER = 269,
    },
    WARLOCK = {
        AFFLICTION = 265,
        DEMO = 266,
        DEMONOLOGY = 266,
        DESTRUCTION = 267,
        DESTRO = 267,
    },
    WARRIOR = {
        ARMS = 71,
        FURY = 72,
        PROTECTION = 73,
    },
    DRUID = {
        BALANCE = 102,
        FERAL = 103,
        GUARDIAN = 104,
        RESTORATION = 105,
        RESTO = 105,
    },
    DEATHKNIGHT = {
        BLOOD = 250,
        FROST = 251,
        UNHOLY = 252,
    },
    DEMONHUNTER = {
        HAVOC = 577,
        VENGEANCE = 581,
    },
}

local SPELLS = {
    [1234768] = {
        cd = 300,
        type = "DEF",
        displayItemID = 241304,
        displayIconID = 7548909,
        trackMode = "POTION",
        alwaysShow = true,
        extraSlot = true,
        sortOrder = 999,
    }, -- Shared Silvermoon Health Potion slot

    -- PALADIN
    [31884] = {
        cd = 120,
        type = "OFF",
        class = "PALADIN",
        specs = { "HOLY", "PROTECTION", "RETRIBUTION" },
        excludeIfTalentBySpec = {
            HOLY = 216331,
            PROTECTION = 389539,
            RETRIBUTION = 458359,
        },
    }, -- Avenging Wrath
    [96231] = { cd = 15, type = "INT", class = "PALADIN" }, -- Rebuke
    [216331] = { cd = 60, type = "OFF", class = "PALADIN", specs = { "HOLY" }, requiresTalent = 216331 }, -- Avenging Crusader
    [389539] = { cd = 120, type = "OFF", class = "PALADIN", specs = { "PROTECTION" }, requiresTalent = 389539, excludeIfTalent = 31884 }, -- Sentinel
    [642] = { cd = 300, type = "DEF", class = "PALADIN" }, -- Divine Shield
    [1044] = { cd = 25, type = "DEF", class = "PALADIN" }, -- Blessing of Freedom
    [498] = { cd = 60, type = "DEF", class = "PALADIN", specs = { "HOLY" } }, -- Divine Protection
    [403876] = { cd = 90, type = "DEF", class = "PALADIN", specs = { "RETRIBUTION" } }, -- Divine Protection
    [204018] = { cd = 300, type = "DEF", class = "PALADIN", specs = { "HOLY", "PROTECTION", "RETRIBUTION" }, requiresTalent = 5692 }, -- Blessing of Spellwarding
    [1022] = { cd = 300, type = "DEF", class = "PALADIN", specs = { "HOLY", "PROTECTION", "RETRIBUTION" }, excludeIfTalent = 5692 }, -- Blessing of Protection
    [6940] = { cd = 120, type = "DEF", class = "PALADIN", specs = { "HOLY", "PROTECTION", "RETRIBUTION" } }, -- Blessing of Sacrifice
    [31850] = { cd = 90, type = "DEF", class = "PALADIN", specs = { "PROTECTION" } }, -- Ardent Defender
    [86659] = { cd = 180, type = "DEF", class = "PALADIN", specs = { "PROTECTION" } }, -- Guardian of Ancient Kings

    -- EVOKER
    [375087] = { cd = 120, type = "OFF", class = "EVOKER", specs = { "DEVASTATION" } }, -- Dragonrage
    [351338] = { cd = 20, type = "INT", class = "EVOKER" }, -- Quell
    [370553] = { cd = 120, type = "OFF", class = "EVOKER" }, -- Tip the Scales
    [357210] = { cd = 120, type = "OFF", class = "EVOKER" }, -- Deep Breath
    [357170] = { cd = 60, type = "DEF", class = "EVOKER", specs = { "PRESERVATION" } }, -- Time Dilation
    [363916] = { cd = 90, type = "DEF", class = "EVOKER" }, -- Obsidian Scales
    [374227] = { cd = 120, type = "DEF", class = "EVOKER" }, -- Zephyr

    -- MAGE
    [190319] = { cd = 120, type = "OFF", class = "MAGE", specs = { "FIRE" } }, -- Combustion
    [321507] = { cd = 45, type = "OFF", class = "MAGE", specs = { "ARCANE" } }, -- [Touch of the Magi]
    [365350] = { cd = 90, type = "OFF", class = "MAGE", specs = { "ARCANE" } }, -- [Arcane Surge]
    [12472] = { cd = 120, type = "OFF", class = "MAGE", specs = { "FROST" } }, -- Icy Veins
    [45438] = { cd = 240, type = "DEF", class = "MAGE", excludeIfTalent = 414659 }, -- Ice Block
    [414659] = { cd = 240, type = "DEF", class = "MAGE", requiresTalent = 414659 }, -- Ice Cold
    [2139] = { cd = 25, type = "INT", class = "MAGE" }, -- Counterspell
    [342246] = { cd = 50, type = "DEF", class = "MAGE" }, -- Alter Time

    -- PRIEST
    [10060] = { cd = 120, type = "OFF", class = "PRIEST" }, -- Power Infusion
    [228260] = { cd = 120, type = "OFF", class = "PRIEST", specs = { "SHADOW" } }, -- Voidform
    [200183] = { cd = 120, type = "OFF", class = "PRIEST", specs = { "HOLY" } }, -- Apotheosis
    [64843] = { cd = 180, type = "OFF", class = "PRIEST", specs = { "HOLY" } }, -- Divine Hymn
    [47585] = { cd = 120, type = "DEF", class = "PRIEST", specs = { "SHADOW" } }, -- Dispersion
    [33206] = { cd = 180, type = "DEF", class = "PRIEST", specs = { "DISC" } }, -- Pain Suppression
    [47788] = { cd = 180, type = "DEF", class = "PRIEST", specs = { "HOLY" } }, -- Guardian Spirit
    [19236] = { cd = 90, type = "DEF", class = "PRIEST", specs = { "DISC", "HOLY" } }, -- Desperate Prayer
    [15487] = { cd = 30, type = "INT", class = "PRIEST", specs = { "SHADOW" } }, -- Silence
    [15286] = { cd = 120, type = "DEF", class = "PRIEST", specs = { "SHADOW" } }, -- Vampiric Embrace

    -- ROGUE
    [13750] = { cd = 180, type = "OFF", class = "ROGUE", specs = { "OUTLAW" } }, -- Adrenaline Rush
    [1766] = { cd = 15, type = "INT", class = "ROGUE" }, -- Kick
    [121471] = { cd = 90, type = "OFF", class = "ROGUE", specs = { "SUBTLETY" } }, -- Shadow Blades
    [31224] = { cd = 120, type = "DEF", class = "ROGUE" }, -- Cloak of Shadows
    [5277] = { cd = 120, type = "DEF", class = "ROGUE" }, -- Evasion

    -- HUNTER
    [19574] = { cd = 90, type = "OFF", class = "HUNTER", specs = { "BM" } }, -- Bestial Wrath
    [147362] = { cd = 24, type = "INT", class = "HUNTER", specs = { "BM", "MM" } }, -- Counter Shot
    [187707] = { cd = 15, type = "INT", class = "HUNTER", specs = { "SV" } }, -- Muzzle
    [288613] = { cd = 120, type = "OFF", class = "HUNTER", specs = { "MM" } }, -- Trueshot
    [266779] = { cd = 120, type = "OFF", class = "HUNTER", specs = { "SV" } }, -- Coordinated Assault
    [1250646] = { cd = 90, type = "OFF", class = "HUNTER", specs = { "SV" } }, -- Takedown
    [186265] = { cd = 180, type = "DEF", class = "HUNTER" }, -- Aspect of the Turtle
    [264735] = { cd = 90, type = "DEF", class = "HUNTER" }, -- Survival of the Fittest
    [109304] = { cd = 120, type = "DEF", class = "HUNTER" }, -- Exhilaration

    -- SHAMAN
    [191634] = { cd = 60, type = "OFF", class = "SHAMAN", specs = { "ELEMENTAL" } }, -- Stormkeeper
    [57994] = { cd = 12, type = "INT", class = "SHAMAN" }, -- Wind Shear
    [2825] = { cd = 300, type = "OFF", class = "SHAMAN" }, -- Bloodlust
    [114050] = { cd = 180, type = "OFF", class = "SHAMAN", specs = { "ELEMENTAL" } }, -- Ascendance
    [198067] = { cd = 120, type = "OFF", class = "SHAMAN", specs = { "ELEMENTAL" } }, -- Fire Elemental
    [108271] = { cd = 120, type = "DEF", class = "SHAMAN" }, -- Astral Shift

    -- MONK
    [116705] = { cd = 15, type = "INT", class = "MONK", specs = { "BREWMASTER", "WINDWALKER" } }, -- Spear Hand Strike
    [137639] = { cd = 90, type = "OFF", class = "MONK", specs = { "WINDWALKER" } }, -- Storm, Earth, and Fire
    [123904] = { cd = 120, type = "OFF", class = "MONK", specs = { "WINDWALKER" } }, -- Invoke Xuen, the White Tiger
    [115203] = { cd = 120, cdBySpec = { BREWMASTER = 360 }, type = "DEF", class = "MONK" }, -- Fortifying Brew
    [122783] = { cd = 90, type = "DEF", class = "MONK", specs = { "WINDWALKER", "MISTWEAVER" } }, -- Diffuse Magic
    [132578] = { cd = 120, type = "DEF", class = "MONK", specs = { "BREWMASTER" } }, -- Invoke Niuzao, the Black Ox
    [116849] = { cd = 120, type = "DEF", class = "MONK", specs = { "MISTWEAVER" } }, -- Life Cocoon
    [115399] = { cd = 120, type = "DEF", class = "MONK", specs = { "BREWMASTER" } }, -- Black Ox Brew
    [119582] = { cd = 20, type = "DEF", class = "MONK", specs = { "BREWMASTER" } }, -- Purifying Brew
    [1241059] = { cd = 45, type = "DEF", class = "MONK", specs = { "BREWMASTER" } }, -- Celestial Infusion

    -- WARLOCK
    [1122] = { cd = 120, type = "OFF", class = "WARLOCK", specs = { "DESTRO" } }, -- Summon Infernal
    [205180] = { cd = 120, type = "OFF", class = "WARLOCK", specs = { "AFFLICTION" } }, -- Summon Darkglare
    [113860] = { cd = 120, type = "OFF", class = "WARLOCK", specs = { "AFFLICTION" } }, -- Dark Soul: Misery
    [265187] = { cd = 60, type = "OFF", class = "WARLOCK", specs = { "DEMO" } }, -- Summon Demonic Tyrant
    [1276672] = { cd = 120, type = "OFF", class = "WARLOCK", specs = { "DEMO" } }, -- Summon Doomguard
    [108416] = { cd = 60, type = "DEF", class = "WARLOCK" }, -- Dark Pact
    [104773] = { cd = 180, type = "DEF", class = "WARLOCK" }, -- Unending Resolve
    [119914] = { cd = 30, type = "INT", class = "WARLOCK", specs = { "DEMO" } }, -- Axe Toss
    [119910] = { cd = 24, type = "INT", class = "WARLOCK" }, -- Spell Lock

    -- WARRIOR
    [97462] = { cd = 180, type = "DEF", class = "WARRIOR" }, -- Rallying Cry
    [6552] = { cd = 15, type = "INT", class = "WARRIOR" }, -- Pummel
    [871] = { cd = 180, type = "DEF", class = "WARRIOR", specs = { "PROTECTION" } }, -- Shield Wall
    [118038] = { cd = 120, type = "DEF", class = "WARRIOR", specs = { "ARMS" } }, -- Die by the Sword
    [184364] = { cd = 120, type = "DEF", class = "WARRIOR", specs = { "FURY" } }, -- Enraged Regeneration
    [1719] = { cd = 90, type = "OFF", class = "WARRIOR", specs = { "FURY" } }, -- Recklessness
    [107574] = { cd = 90, type = "OFF", class = "WARRIOR", specs = { "ARMS", "FURY", "PROTECTION" }, requiresTalent = 107574 }, -- Avatar

    -- DRUID
    [22812] = { cd = 60, type = "DEF", class = "DRUID", specs = { "BALANCE", "GUARDIAN", "RESTORATION" } }, -- Barkskin
    [106839] = { cd = 15, type = "INT", class = "DRUID", specs = { "FERAL", "GUARDIAN" } }, -- Skull Bash
    [61336] = { cd = 180, type = "DEF", class = "DRUID", specs = { "FERAL", "GUARDIAN" } }, -- Survival Instincts
    [102342] = { cd = 90, type = "DEF", class = "DRUID", specs = { "RESTORATION" } }, -- Ironbark
    [106951] = { cd = 180, type = "OFF", class = "DRUID", specs = { "FERAL" }, excludeIfTalent = 102543 }, -- Berserk
    [102543] = { cd = 180, type = "OFF", class = "DRUID", specs = { "FERAL" }, requiresTalent = 102543 }, -- Incarnation: Avatar of Ashamane
    [194223] = { cd = 180, type = "OFF", class = "DRUID", specs = { "BALANCE" }, excludeIfTalent = 102560 }, -- Celestial Alignment
    [102560] = { cd = 180, type = "OFF", class = "DRUID", specs = { "BALANCE" }, requiresTalent = 102560 }, -- Incarnation: Chosen of Elune
    [204066] = { cd = 60, type = "DEF", class = "DRUID", specs = { "GUARDIAN" } }, -- Lunar Beam
    [22842] = { cd = 36, type = "DEF", class = "DRUID", specs = { "GUARDIAN" } }, -- Frenzied Regeneration
    [102558] = { cd = 180, type = "OFF", class = "DRUID", specs = { "GUARDIAN" } }, -- Incarnation: Guardian of Ursoc

    -- DEATH KNIGHT
    [48792] = { cd = 120, type = "DEF", class = "DEATHKNIGHT" }, -- Icebound Fortitude
    [47528] = { cd = 15, type = "INT", class = "DEATHKNIGHT" }, -- Mind Freeze
    [48707] = { cd = 60, type = "DEF", class = "DEATHKNIGHT" }, -- Anti-Magic Shell
    [55233] = { cd = 90, type = "DEF", class = "DEATHKNIGHT", specs = { "BLOOD" } }, -- Vampiric Blood
    [51271] = { cd = 45, type = "OFF", class = "DEATHKNIGHT", specs = { "FROST" } }, -- Pillar of Frost
    [47568] = { cd = 30, type = "OFF", class = "DEATHKNIGHT", specs = { "FROST" } }, -- Empower Rune Weapon
    [1233448] = { cd = 45, type = "OFF", class = "DEATHKNIGHT", specs = { "UNHOLY" } }, -- Dark Transformation
    [42650] = { cd = 90, type = "OFF", class = "DEATHKNIGHT", specs = { "UNHOLY" } }, -- Army of the Dead

    -- DEMON HUNTER
    [183752] = { cd = 15, type = "INT", class = "DEMONHUNTER" }, -- Disrupt
    [191427] = { cd = 120, type = "OFF", class = "DEMONHUNTER", specs = { "HAVOC" } }, -- Metamorphosis
    [198589] = { cd = 60, type = "DEF", class = "DEMONHUNTER", specs = { "HAVOC" } }, -- Blur
    [204021] = { cd = 60, type = "DEF", class = "DEMONHUNTER", specs = { "VENGEANCE" } }, -- Fiery Brand
    [196718] = { cd = 300, type = "DEF", class = "DEMONHUNTER" }, -- Darkness
}

local BASE_SPELLS = {}
for spellID, meta in pairs(SPELLS) do
    BASE_SPELLS[spellID] = {
        cd = meta.cd,
        cdBySpec = meta.cdBySpec,
        type = meta.type,
        class = meta.class,
        displayItemID = meta.displayItemID,
        displayIconID = meta.displayIconID,
        trackMode = meta.trackMode,
        alwaysShow = meta.alwaysShow,
        extraSlot = meta.extraSlot,
        sortOrder = meta.sortOrder,
        specs = meta.specs,
        requiresTalent = meta.requiresTalent,
        excludeIfTalent = meta.excludeIfTalent,
        requiresTalentBySpec = meta.requiresTalentBySpec,
        excludeIfTalentBySpec = meta.excludeIfTalentBySpec,
    }
end

local function ResolveSpecValue(classToken, specValue)
    if type(specValue) == "number" then
        return specValue
    end

    if type(specValue) ~= "string" then
        return nil
    end

    local aliasKey = string.upper(specValue)
    local classSpecs = classToken and SPEC_ALIASES[classToken] or nil
    if classSpecs then
        return classSpecs[aliasKey]
    end

    return nil
end

local function CopyMeta(meta)
    if not meta then
        return nil
    end

    local copy = {}
    for key, value in pairs(meta) do
        if type(value) == "table" then
            local nested = {}
            for nestedKey, nestedValue in pairs(value) do
                nested[nestedKey] = nestedValue
            end
            copy[key] = nested
        else
            copy[key] = value
        end
    end

    return copy
end

local function ResolveSpecMappedValue(classToken, specID, valueMap)
    if type(valueMap) ~= "table" then
        return nil
    end

    if specID and valueMap[specID] ~= nil then
        return valueMap[specID]
    end

    for mapKey, mapValue in pairs(valueMap) do
        if mapKey ~= "default" then
            local resolvedSpecID = ResolveSpecValue(classToken, mapKey)
            if resolvedSpecID == specID then
                return mapValue
            end
        end
    end

    return valueMap.default
end


PartyOffCDCore.CLASS_ORDER = CLASS_ORDER
PartyOffCDCore.CLASS_LABELS = CLASS_LABELS
PartyOffCDCore.SPELL_TYPE_PRIORITY = SPELL_TYPE_PRIORITY
PartyOffCDCore.SPELLS = SPELLS
PartyOffCDCore.BASE_SPELLS = BASE_SPELLS
PartyOffCDCore.ResolveSpecValue = ResolveSpecValue
PartyOffCDCore.ResolveSpecMappedValue = ResolveSpecMappedValue

local DebugPrint = PartyOffCDCore.DebugPrint
local CopyDefaults = PartyOffCDCore.CopyDefaults
local SafeGetSpellInfo = PartyOffCDCore.SafeGetSpellInfo
local IsSecretValue = PartyOffCDCore.IsSecretValue or function()
    return false
end
local NormalizeSpellID = PartyOffCDCore.NormalizeSpellID or function(value)
    if value == nil or IsSecretValue(value) then
        return nil
    end

    local spellID = tonumber(value)
    if type(spellID) ~= "number" or spellID <= 0 then
        return nil
    end

    return spellID
end

function PartyOffCD:IsSpellEnabled(spellID)
    spellID = NormalizeSpellID(spellID)
    if not spellID then
        return false
    end

    local meta = SPELLS[spellID]
    if not meta then
        return false
    end

    if self.db and self.db.classEnabled and self.db.classEnabled[meta.class] == false then
        return false
    end

    if self.db and self.db.spellEnabled and self.db.spellEnabled[spellID] == false then
        return false
    end

    return true
end

function PartyOffCD:GetOverrideBucket(senderKey, create)
    if not self.db then
        return nil
    end

    self.db.syncedOverrides = self.db.syncedOverrides or {}
    if create and not self.db.syncedOverrides[senderKey] then
        self.db.syncedOverrides[senderKey] = {}
    end

    return self.db.syncedOverrides[senderKey]
end

function PartyOffCD:GetPlayerOverride(spellID, senderKey)
    senderKey = self:ResolveSenderKey(senderKey)
    if not senderKey then
        return nil
    end

    local bucket = self:GetOverrideBucket(senderKey, false)
    if bucket then
        return bucket[spellID]
    end

    return nil
end

function PartyOffCD:GetSenderUnit(senderKey)
    senderKey = self:ResolveSenderKey(senderKey)
    if not senderKey then
        return nil
    end

    local rosterEntry = self.rosterLookup[senderKey]
    if rosterEntry and rosterEntry.unit then
        return rosterEntry.unit
    end

    if self:IsSelfSender(senderKey) then
        return "player"
    end

    return nil
end

function PartyOffCD:ResolveMetaCooldown(meta, specID)
    if not meta then
        return nil
    end

    local resolved = tonumber(meta.cd) or meta.cd
    local specCooldown = ResolveSpecMappedValue(meta.class, specID, meta.cdBySpec)
    if specCooldown ~= nil then
        resolved = tonumber(specCooldown) or specCooldown
    end

    return resolved
end

function PartyOffCD:GetEffectiveMeta(senderKey, spellID)
    local override = self:GetPlayerOverride(spellID, senderKey)
    if override then
        return override
    end

    local baseMeta = BASE_SPELLS[spellID] or SPELLS[spellID]
    if not baseMeta then
        return nil
    end

    local unit = self:GetSenderUnit(senderKey)
    local specID = self:GetSenderSpecID(senderKey)
    local effectiveMeta = CopyMeta(baseMeta)
    effectiveMeta.cd = self:ResolveMetaCooldown(baseMeta, specID)

    local talentTracker = PartyOffCDCore and PartyOffCDCore.TalentTracker
    if talentTracker and unit and effectiveMeta.class and effectiveMeta.cd then
        effectiveMeta.cd = talentTracker:GetUnitCooldown(unit, specID, effectiveMeta.class, spellID, effectiveMeta.cd)
    end

    return effectiveMeta
end

function PartyOffCD:GetDisplayMeta(spellID)
    local playerKey = self:GetPlayerCanonical()
    return self:GetEffectiveMeta(playerKey, spellID) or SPELLS[spellID]
end

local function CreateStoredSpellMeta(spellID, meta)
    if not meta then
        return nil
    end

    local baseMeta = BASE_SPELLS[spellID] or SPELLS[spellID]
    return {
        cd = tonumber(meta.cd) or meta.cd,
        type = meta.type,
        class = meta.class,
        custom = not BASE_SPELLS[spellID],
        displayItemID = meta.displayItemID or (baseMeta and baseMeta.displayItemID) or nil,
        displayIconID = meta.displayIconID or (baseMeta and baseMeta.displayIconID) or nil,
        trackMode = meta.trackMode or (baseMeta and baseMeta.trackMode) or nil,
        alwaysShow = meta.alwaysShow or (baseMeta and baseMeta.alwaysShow) or nil,
        extraSlot = meta.extraSlot or (baseMeta and baseMeta.extraSlot) or nil,
        sortOrder = meta.sortOrder or (baseMeta and baseMeta.sortOrder) or nil,
        specs = meta.specs or (baseMeta and baseMeta.specs) or nil,
        requiresTalent = meta.requiresTalent or (baseMeta and baseMeta.requiresTalent) or nil,
        excludeIfTalent = meta.excludeIfTalent or (baseMeta and baseMeta.excludeIfTalent) or nil,
        requiresTalentBySpec = meta.requiresTalentBySpec or (baseMeta and baseMeta.requiresTalentBySpec) or nil,
        excludeIfTalentBySpec = meta.excludeIfTalentBySpec or (baseMeta and baseMeta.excludeIfTalentBySpec) or nil,
    }
end

function PartyOffCD:ClearTrackedSpellState(senderKey, spellID)
    senderKey = self:ResolveSenderKey(senderKey)
    if not senderKey or not spellID then
        return
    end

    local senderCooldowns = self.cooldowns[senderKey]
    if senderCooldowns then
        senderCooldowns[spellID] = nil
        if not next(senderCooldowns) then
            self.cooldowns[senderKey] = nil
        end
    end

    local senderDuplicates = self.duplicateCache[senderKey]
    if senderDuplicates then
        senderDuplicates[spellID] = nil
        if not next(senderDuplicates) then
            self.duplicateCache[senderKey] = nil
        end
    end

    if self:IsSelfSender(senderKey) then
        self.lastLocalReport[spellID] = nil
    end
end

function PartyOffCD:RefreshGlobalCustomSpell(spellID)
    spellID = tonumber(spellID)
    if not spellID or BASE_SPELLS[spellID] then
        return
    end

    local replacement
    for _, bucket in pairs(self.db.syncedOverrides or {}) do
        local meta = type(bucket) == "table" and bucket[spellID] or nil
        if meta and meta.cd and meta.type and meta.class then
            replacement = meta
            break
        end
    end

    if replacement then
        SPELLS[spellID] = CreateStoredSpellMeta(spellID, replacement)
        if self.db.spellEnabled[spellID] == nil then
            self.db.spellEnabled[spellID] = true
        end
    else
        SPELLS[spellID] = nil
        self.db.spellEnabled[spellID] = nil
    end
end

function PartyOffCD:DeleteSenderOverride(senderKey, spellID)
    senderKey = self:ResolveSenderKey(senderKey)
    spellID = tonumber(spellID)
    if not senderKey or not spellID then
        return false
    end

    local bucket = self:GetOverrideBucket(senderKey, false)
    if not bucket or not bucket[spellID] then
        return false
    end

    local isBaseSpell = BASE_SPELLS[spellID] ~= nil
    bucket[spellID] = nil
    if not next(bucket) then
        self.db.syncedOverrides[senderKey] = nil
    end

    if senderKey == self:GetPlayerCanonical() and self.db.customSpells then
        self.db.customSpells[spellID] = nil
    end

    if not isBaseSpell then
        self:ClearTrackedSpellState(senderKey, spellID)
    end

    self:RefreshGlobalCustomSpell(spellID)
    return true
end


function PartyOffCD:SetClassEnabled(classToken, isEnabled)
    self.db.classEnabled[classToken] = isEnabled and true or false

    for spellID, meta in pairs(SPELLS) do
        if meta.class == classToken then
            self.db.spellEnabled[spellID] = isEnabled and true or false
        end
    end

    self:PruneDisabledCooldowns()
    self:RefreshConfigPanel()
    self:RefreshTracker()
end

function PartyOffCD:SetSpellEnabled(spellID, isEnabled)
    if not SPELLS[spellID] then
        return
    end

    self.db.spellEnabled[spellID] = isEnabled and true or false
    self:PruneDisabledCooldowns()
    self:RefreshConfigPanel()
    self:RefreshTracker()
end


function PartyOffCD:AddCustomSpell(classToken, spellID, cooldown, spellType)
    spellID = tonumber(spellID)
    cooldown = tonumber(cooldown)
    spellType = spellType and string.upper(spellType) or nil

    if not classToken or not CLASS_LABELS[classToken] then
        DebugPrint("Invalid class for custom spell.")
        return false
    end

    if not spellID or spellID <= 0 then
        DebugPrint("Invalid SpellID.")
        return false
    end

    if not cooldown or cooldown <= 0 then
        DebugPrint("Invalid CD. It must be a number in seconds.")
        return false
    end

    if not SPELL_TYPE_PRIORITY[spellType] then
        DebugPrint("Invalid type. Use OFF, DEF or INT.")
        return false
    end

    local spellName = SafeGetSpellInfo(spellID)
    if not spellName then
        DebugPrint("That SpellID does not exist or is not available on this client.")
        return false
    end

    local existing = SPELLS[spellID]
    local playerKey = self:GetPlayerCanonical()
    if not playerKey then
        DebugPrint("Could not identify your character to save the override.")
        return false
    end

    local override = {
        cd = cooldown,
        type = spellType,
        class = classToken,
        custom = not existing,
        specs = existing and existing.specs or nil,
        requiresTalent = existing and existing.requiresTalent or nil,
        excludeIfTalent = existing and existing.excludeIfTalent or nil,
        requiresTalentBySpec = existing and existing.requiresTalentBySpec or nil,
        excludeIfTalentBySpec = existing and existing.excludeIfTalentBySpec or nil,
    }

    self:GetOverrideBucket(playerKey, true)[spellID] = override
    self.db.customSpells[spellID] = override

    if not existing then
        SPELLS[spellID] = {
            cd = cooldown,
            type = spellType,
            class = classToken,
            custom = true,
        }
    end

    if self.db.spellEnabled[spellID] == nil then
        self.db.spellEnabled[spellID] = true
    else
        self.db.spellEnabled[spellID] = true
    end

    local synced = self:SendSyncMessage(spellID, override)
    self:RefreshConfigPanel()
    self:RefreshTracker()
    if existing then
        DebugPrint(string.format("Spell updated: %s (%d, %s, %ss)", spellName, spellID, spellType, cooldown))
    else
        DebugPrint(string.format("Custom spell added: %s (%d, %s, %ss)", spellName, spellID, spellType, cooldown))
    end
    if synced then
        DebugPrint("Override synced with the group.")
    end
    return true
end

function PartyOffCD:DeleteCustomSpell(spellID, skipSync)
    spellID = tonumber(spellID)
    if not spellID or spellID <= 0 then
        DebugPrint("Invalid SpellID.")
        return false
    end

    if BASE_SPELLS[spellID] then
        DebugPrint("Base spells cannot be deleted; disable them instead.")
        return false
    end

    if not self.db.customSpells or not self.db.customSpells[spellID] then
        DebugPrint("That custom spell is not owned by this character.")
        return false
    end

    local playerKey = self:GetPlayerCanonical()
    if not playerKey then
        DebugPrint("Could not identify your character to delete the custom spell.")
        return false
    end

    local spellName = SafeGetSpellInfo(spellID) or ("Spell " .. tostring(spellID))
    if not self:DeleteSenderOverride(playerKey, spellID) then
        DebugPrint("That custom spell could not be removed.")
        return false
    end

    local synced = false
    if not skipSync and self.SendDeleteMessage then
        synced = self:SendDeleteMessage(spellID)
    end

    self:RefreshConfigPanel()
    self:RefreshTracker()
    DebugPrint(string.format("Custom spell deleted: %s (%d)", spellName, spellID))
    if synced then
        DebugPrint("Delete synced with the group.")
    end
    return true
end


function PartyOffCD:GetSpellMeta(spellID)
    spellID = NormalizeSpellID(spellID)
    if not spellID then
        return nil
    end

    return SPELLS[spellID]
end

function PartyOffCD:IsSpecAllowedForMeta(meta, specID)
    if not meta or not meta.specs or not specID then
        return true
    end

    for _, specValue in ipairs(meta.specs) do
        local allowedSpecID = ResolveSpecValue(meta.class, specValue)
        if allowedSpecID == specID then
            return true
        end
    end

    return false
end

function PartyOffCD:IsTalentAllowedForMeta(meta, unit, specID)
    if not meta or not unit then
        return true
    end

    local talentTracker = PartyOffCDCore and PartyOffCDCore.TalentTracker
    if not talentTracker or not talentTracker.UnitHasTalent then
        return true
    end

    local excludeTalent = meta.excludeIfTalent or ResolveSpecMappedValue(meta.class, specID, meta.excludeIfTalentBySpec)
    if excludeTalent and talentTracker:UnitHasTalent(unit, excludeTalent, specID) then
        return false
    end

    local requiredTalent = meta.requiresTalent or ResolveSpecMappedValue(meta.class, specID, meta.requiresTalentBySpec)
    if requiredTalent and not talentTracker:UnitHasTalent(unit, requiredTalent, specID) then
        return false
    end

    return true
end

function PartyOffCD:DoesMetaMatchUnit(meta, classToken, specID, unit)
    if not meta then
        return false
    end

    if classToken and meta.class and meta.class ~= classToken then
        return false
    end

    if not self:IsSpecAllowedForMeta(meta, specID) then
        return false
    end

    return self:IsTalentAllowedForMeta(meta, unit, specID)
end

function PartyOffCD:GetSingleSpecIDForMeta(meta)
    if not meta or type(meta.specs) ~= "table" or #meta.specs ~= 1 then
        return nil
    end

    return ResolveSpecValue(meta.class, meta.specs[1])
end


function PartyOffCD:InitializeDB()
    PartyOffCDDB = CopyDefaults(PartyOffCDDB, DB_DEFAULTS)
    self.db = PartyOffCDDB

    local attach = string.upper(tostring(self.db.trackerAttach or DB_DEFAULTS.trackerAttach or "LEFT"))
    if attach ~= "LEFT" and attach ~= "RIGHT" and attach ~= "CENTER" and attach ~= "TOP" and attach ~= "BOTTOM" then
        attach = DB_DEFAULTS.trackerAttach or "LEFT"
    end
    self.db.trackerAttach = attach

    local trackerOffsetX = tonumber(self.db.trackerOffsetX)
    if trackerOffsetX == nil then
        trackerOffsetX = tonumber(DB_DEFAULTS.trackerOffsetX) or -4
    end
    if trackerOffsetX < -250 then
        trackerOffsetX = -250
    elseif trackerOffsetX > 250 then
        trackerOffsetX = 250
    end
    self.db.trackerOffsetX = math.floor(trackerOffsetX)

    local trackerOffsetY = tonumber(self.db.trackerOffsetY)
    if trackerOffsetY == nil then
        trackerOffsetY = tonumber(DB_DEFAULTS.trackerOffsetY) or 0
    end
    if trackerOffsetY < -250 then
        trackerOffsetY = -250
    elseif trackerOffsetY > 250 then
        trackerOffsetY = 250
    end
    self.db.trackerOffsetY = math.floor(trackerOffsetY)

    local columns = tonumber(self.db.trackerColumns) or tonumber(DB_DEFAULTS.trackerColumns) or 1
    columns = math.floor(columns)
    local maxColumns = MAX_TRACKER_COLUMNS
    if attach == "TOP" or attach == "BOTTOM" then
        maxColumns = math.min(MAX_TRACKER_COLUMNS, MAX_VERTICAL_TRACKER_COLUMNS)
    end
    if columns < 1 then
        columns = 1
    elseif columns > maxColumns then
        columns = maxColumns
    end
    self.db.trackerColumns = columns

    local trackerRows = tonumber(self.db.trackerRows)
    if trackerRows == nil then
        trackerRows = tonumber(DB_DEFAULTS.trackerRows) or 1
    end
    trackerRows = math.floor(trackerRows)
    if trackerRows < 1 then
        trackerRows = 1
    elseif trackerRows > 3 then
        trackerRows = 3
    end
    self.db.trackerRows = trackerRows

    local trackerMaxIcons = tonumber(self.db.trackerMaxIcons)
    if trackerMaxIcons == nil then
        trackerMaxIcons = tonumber(DB_DEFAULTS.trackerMaxIcons) or 10
    end
    trackerMaxIcons = math.floor(trackerMaxIcons)
    if trackerMaxIcons < 1 then
        trackerMaxIcons = 1
    elseif trackerMaxIcons > 12 then
        trackerMaxIcons = 12
    end
    self.db.trackerMaxIcons = trackerMaxIcons

    local iconScale = tonumber(self.db.trackerIconScale)
    if not iconScale and self.db.trackerIconSize then
        iconScale = (tonumber(self.db.trackerIconSize) or BASE_ICON_SIZE) * 100 / BASE_ICON_SIZE
    end
    if not iconScale then
        iconScale = tonumber(DB_DEFAULTS.trackerIconScale) or 100
    end
    iconScale = math.floor(iconScale)
    if iconScale < MIN_TRACKER_ICON_SCALE then
        iconScale = MIN_TRACKER_ICON_SCALE
    elseif iconScale > MAX_TRACKER_ICON_SCALE then
        iconScale = MAX_TRACKER_ICON_SCALE
    end
    self.db.trackerIconScale = iconScale

    if self.db.trackerShowOffensive == nil then
        self.db.trackerShowOffensive = DB_DEFAULTS.trackerShowOffensive ~= false
    end
    if self.db.trackerShowDefensive == nil then
        self.db.trackerShowDefensive = DB_DEFAULTS.trackerShowDefensive ~= false
    end
    if self.db.trackerShowTooltips == nil then
        self.db.trackerShowTooltips = DB_DEFAULTS.trackerShowTooltips ~= false
    end
    if self.db.trackerReverseCooldown == nil then
        self.db.trackerReverseCooldown = DB_DEFAULTS.trackerReverseCooldown == true
    end
    if self.db.trackerExcludeSelf == nil then
        self.db.trackerExcludeSelf = DB_DEFAULTS.trackerExcludeSelf == true
    end

    for _, classToken in ipairs(CLASS_ORDER) do
        if self.db.classEnabled[classToken] == nil then
            self.db.classEnabled[classToken] = true
        end
    end

    for spellID in pairs(BASE_SPELLS) do
        if self.db.spellEnabled[spellID] == nil then
            self.db.spellEnabled[spellID] = true
        end
    end

    local playerKey = self:GetPlayerCanonical()

    if playerKey and self.db.customSpells and next(self.db.customSpells) then
        local bucket = self:GetOverrideBucket(playerKey, true)
        for spellID, meta in pairs(self.db.customSpells) do
            spellID = tonumber(spellID)
            if spellID and meta and meta.cd and meta.type and meta.class and not bucket[spellID] then
                bucket[spellID] = CreateStoredSpellMeta(spellID, meta)
            end
        end
    end

    for senderKey, bucket in pairs(self.db.syncedOverrides) do
        if type(bucket) == "table" then
            for spellID, meta in pairs(bucket) do
                spellID = tonumber(spellID)
                if spellID and meta and meta.cd and meta.type and meta.class then
                    if not SPELLS[spellID] then
                        SPELLS[spellID] = CreateStoredSpellMeta(spellID, meta)
                    end

                    if self.db.spellEnabled[spellID] == nil then
                        self.db.spellEnabled[spellID] = true
                    end
                end
            end
        else
            self.db.syncedOverrides[senderKey] = nil
        end
    end
end



