local _, PartyOffCDCore = ...
PartyOffCDCore = PartyOffCDCore or _G.PartyOffCDCore

local PartyOffCD = _G.PartyOffCD
assert(PartyOffCD, "PartyOffCD: frame missing before loading Spells.lua")
assert(PartyOffCDCore, "PartyOffCD: core missing before loading Spells.lua")

local DB_DEFAULTS = PartyOffCDCore.DB_DEFAULTS or PartyOffCDCore.DEFAULTS

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
    -- PALADIN
    [31884] = { cd = 120, type = "OFF", class = "PALADIN" }, -- Avenging Wrath
    [96231] = { cd = 15, type = "INT", class = "PALADIN" }, -- Rebuke
    [216331] = { cd = 120, type = "OFF", class = "PALADIN" }, -- Avenging Crusader
    [642] = { cd = 240, type = "DEF", class = "PALADIN" }, -- Divine Shield
    [6940] = { cd = 120, type = "DEF", class = "PALADIN" }, -- Blessing of Sacrifice
    [31850] = { cd = 120, type = "DEF", class = "PALADIN" }, -- Ardent Defender

    -- EVOKER
    [375087] = { cd = 120, type = "OFF", class = "EVOKER", specs = { "DEVASTATION" } }, -- Dragonrage
    [351338] = { cd = 40, type = "INT", class = "EVOKER" }, -- Quell
    [370553] = { cd = 120, type = "OFF", class = "EVOKER" }, -- Tip the Scales
    [357210] = { cd = 120, type = "OFF", class = "EVOKER" }, -- Deep Breath
    [363916] = { cd = 90, type = "DEF", class = "EVOKER" }, -- Obsidian Scales
    [374227] = { cd = 90, type = "DEF", class = "EVOKER" }, -- Zephyr

    -- MAGE
    [190319] = { cd = 120, type = "OFF", class = "MAGE", specs = { "FIRE" } }, -- Combustion
    [2139] = { cd = 24, type = "INT", class = "MAGE" }, -- Counterspell
    [321507] = { cd = 45, type = "OFF", class = "MAGE", specs = { "ARCANE" } }, -- [Touch of the Magi]
    [365350] = { cd = 90, type = "OFF", class = "MAGE", specs = { "ARCANE" } }, -- [Arcane Surge]
    [12472] = { cd = 180, type = "OFF", class = "MAGE", specs = { "FROST" } }, -- Icy Veins
    [45438] = { cd = 240, type = "DEF", class = "MAGE" }, -- Ice Block
    [2139] = { cd = 20, type = "INT", class = "MAGE" }, -- Counterspell
    [342245] = { cd = 50, type = "DEF", class = "MAGE" }, -- Alter Time
    

    -- PRIEST
    [10060] = { cd = 120, type = "OFF", class = "PRIEST" }, -- Power Infusion
    [228260] = { cd = 90, type = "OFF", class = "PRIEST", specs = { "SHADOW" } }, -- Void Eruption
    [200183] = { cd = 120, type = "OFF", class = "PRIEST", specs = { "HOLY" } }, -- Apotheosis
    [47585] = { cd = 120, type = "DEF", class = "PRIEST", specs = { "SHADOW" } }, -- Dispersion
    [33206] = { cd = 180, type = "DEF", class = "PRIEST", specs = { "DISC" } }, -- Pain Suppression
    [47788] = { cd = 180, type = "DEF", class = "PRIEST", specs = { "HOLY" } }, -- Guardian Spirit
    [19236] = { cd = 90, type = "DEF", class = "PRIEST" }, -- Desperate Prayer
    [11487] = { cd = 30, type = "INT", class = "PRIEST", specs = { "SHADOW" } }, -- Interrupt
    [15286] = { cd = 120, type = "DEF", class = "PRIEST" }, --[Vampiric Embrace]

    -- ROGUE
    [13750] = { cd = 180, type = "OFF", class = "ROGUE", specs = { "OUTLAW" } }, -- Adrenaline Rush
    [1766] = { cd = 15, type = "INT", class = "ROGUE" }, -- Kick
    [121471] = { cd = 180, type = "OFF", class = "ROGUE" }, -- Shadow Blades
    [31224] = { cd = 120, type = "DEF", class = "ROGUE" }, -- Cloak of Shadows
    [5277] = { cd = 120, type = "DEF", class = "ROGUE" }, -- Evasion

    -- HUNTER
    [19574] = { cd = 90, type = "OFF", class = "HUNTER", specs = { "BM" } }, -- Bestial Wrath
    [147362] = { cd = 24, type = "INT", class = "HUNTER", specs = { "BM", "MM" } }, -- Counter Shot
    [187707] = { cd = 15, type = "INT", class = "HUNTER", specs = { "SV" } }, -- Muzzle
    [288613] = { cd = 120, type = "OFF", class = "HUNTER", specs = { "MM" } }, -- Trueshot
    [266779] = { cd = 120, type = "OFF", class = "HUNTER", specs = { "SV" } }, -- Coordinated Assault
    [186265] = { cd = 180, type = "DEF", class = "HUNTER" }, -- Aspect of the Turtle
    [109304] = { cd = 120, type = "DEF", class = "HUNTER" }, -- Exhilaration

    -- SHAMAN
    [191634] = { cd = 60, type = "OFF", class = "SHAMAN", specs = { "ELEMENTAL" } }, -- Stormkeeper
    [57994] = { cd = 12, type = "INT", class = "SHAMAN" }, -- Wind Shear
    [321530] = { cd = 300, type = "OFF", class = "SHAMAN" }, -- Bloodlust
    [114050] = { cd = 180, type = "OFF", class = "SHAMAN" }, -- Ascendance
    [198067] = { cd = 150, type = "OFF", class = "SHAMAN" }, -- Fire Elemental
    [108271] = { cd = 90, type = "DEF", class = "SHAMAN" }, -- Astral Shift

    -- MONK
    [115080] = { cd = 120, type = "OFF", class = "MONK", specs = { "WINDWALKER" } }, -- Touch of Death
    [116705] = { cd = 15, type = "INT", class = "MONK" }, -- Spear Hand Strike
    [137639] = { cd = 90, type = "OFF", class = "MONK", specs = { "WINDWALKER" } }, -- Storm, Earth, and Fire
    [123904] = { cd = 120, type = "OFF", class = "MONK", specs = { "WINDWALKER" } }, -- Invoke Xuen, the White Tiger
    [115203] = { cd = 360, type = "DEF", class = "MONK" }, -- Fortifying Brew
    [122783] = { cd = 90, type = "DEF", class = "MONK", specs = { "WINDWALKER" } }, -- Diffuse Magic
    [132578] = { cd = 120, type = "DEF", class = "MONK" },--[Invoke Niuzao, the Black Ox]
    [115399] = { cd = 135, type = "DEF", class = "MONK" },--[Black Ox Brew]
    [116844] = { cd = 45, type = "DEF", class = "MONK" },--[Ring of Peace]
    [119381] = { cd = 50, type = "DEF", class = "MONK" },--[Leg Sweep]
    [119582] = { cd = 20, type = "DEF", class = "MONK" },--[Purifying Brew]
    [1241059] = { cd = 20, type = "DEF", class = "MONK" },--[Celestial Infusion]
    [116705] = { cd = 15, type = "INT", class = "MONK" }, -- spear hand strike
    -- WARLOCK
    [1122] = { cd = 180, type = "OFF", class = "WARLOCK", specs = { "DESTRO" } }, -- Summon Infernal
    [205180] = { cd = 120, type = "OFF", class = "WARLOCK", specs = { "DEMO" } }, -- Summon Darkglare
    [113860] = { cd = 120, type = "OFF", class = "WARLOCK", specs = { "AFFLICTION" } }, -- Dark Soul: Misery
    [265187] = { cd = 120, type = "OFF", class = "WARLOCK", specs = { "DEMO" } }, -- Dark Soul: Summon demonic Tyrant
    [1276672] = { cd = 120, type = "OFF", class = "WARLOCK" }, -- Dark Soul: Summon Doomguard
    [108416] = { cd = 60, type = "DEF", class = "WARLOCK" }, -- Dark Pact
    [104773] = { cd = 180, type = "DEF", class = "WARLOCK" }, -- Unending Resolve
    [119914] = { cd = 30, type = "INT", class = "WARLOCK", specs = { "DEMO" } }, -- Axe Toss
    [119910] = { cd = 24, type = "INT", class = "WARLOCK" }, -- Spell Lock

    -- WARRIOR
    [97462] = { cd = 180, type = "DEF", class = "WARRIOR" }, -- Rallying Cry
    [6552] = { cd = 15, type = "INT", class = "WARRIOR" }, -- Pummel
    [871] = { cd = 240, type = "DEF", class = "WARRIOR" }, -- Shield Wall
    [118038] = { cd = 120, type = "DEF", class = "WARRIOR" }, -- Die by the Sword
    [1719] = { cd = 90, type = "OFF", class = "WARRIOR", specs = { "FURY" } }, -- Recklessness
    [107574] = { cd = 90, type = "OFF", class = "WARRIOR", specs = { "ARMS", "FURY" } }, -- Avatar

    -- DRUID
    [22812] = { cd = 60, type = "DEF", class = "DRUID" }, -- Barkskin
    [106839] = { cd = 15, type = "INT", class = "DRUID" }, -- Skull Bash
    [61336] = { cd = 180, type = "DEF", class = "DRUID" }, -- Survival Instincts
    [102342] = { cd = 90, type = "DEF", class = "DRUID" }, -- Ironbark
    [106951] = { cd = 180, type = "OFF", class = "DRUID", specs = { "FERAL" } }, -- Berserk
    [194223] = { cd = 180, type = "OFF", class = "DRUID", specs = { "BALANCE" } }, -- Celestial Alignment
    [204066] = { cd = 180, type = "DEF", class = "DRUID" , specs = { "GUARDIAN" } }, -- Lunar beam
    [22842] = { cd = 36, type = "DEF", class = "DRUID" , specs = { "GUARDIAN" }}, -- Frenzied Regeneration
    [102558] = { cd = 36, type = "DEF", class = "DRUID", specs = { "GUARDIAN" }},--[Incarnation: Guardian of Ursoc]

    -- DEATH KNIGHT
    [48792] = { cd = 120, type = "DEF", class = "DEATHKNIGHT" }, -- Icebound Fortitude
    [47528] = { cd = 15, type = "INT", class = "DEATHKNIGHT" }, -- Mind Freeze
    [48707] = { cd = 40, type = "DEF", class = "DEATHKNIGHT" }, -- Anti-Magic Shell
    [51271] = { cd = 60, type = "OFF", class = "DEATHKNIGHT", specs = { "FROST" } }, -- Pillar of Frost
    [47568] = { cd = 120, type = "OFF", class = "DEATHKNIGHT", specs = { "FROST" } }, -- Empower Rune Weapon
    [1233448] = { cd = 45, type = "OFF", class = "DEATHKNIGHT", specs = { "UNHOLY" } }, -- User provided Midnight DK CD
    [42650] = { cd = 90, type = "OFF", class = "DEATHKNIGHT", specs = { "UNHOLY" } }, -- Army of the Dead

    -- DEMON HUNTER
    [196555] = { cd = 120, type = "DEF", class = "DEMONHUNTER" }, -- Netherwalk
    [183752] = { cd = 15, type = "INT", class = "DEMONHUNTER" }, -- Disrupt
    [191427] = { cd = 180, type = "OFF", class = "DEMONHUNTER", specs = { "HAVOC" } }, -- Metamorphosis
    [198589] = { cd = 60, type = "DEF", class = "DEMONHUNTER", specs = { "HAVOC" } }, -- Blur
    [196718] = { cd = 300, type = "DEF", class = "DEMONHUNTER", specs = { "HAVOC" } }, -- Darkness
}

local BASE_SPELLS = {}
for spellID, meta in pairs(SPELLS) do
    BASE_SPELLS[spellID] = {
        cd = meta.cd,
        type = meta.type,
        class = meta.class,
        specs = meta.specs,
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


PartyOffCDCore.CLASS_ORDER = CLASS_ORDER
PartyOffCDCore.CLASS_LABELS = CLASS_LABELS
PartyOffCDCore.SPELL_TYPE_PRIORITY = SPELL_TYPE_PRIORITY
PartyOffCDCore.SPELLS = SPELLS
PartyOffCDCore.BASE_SPELLS = BASE_SPELLS
PartyOffCDCore.ResolveSpecValue = ResolveSpecValue

local DebugPrint = PartyOffCDCore.DebugPrint
local CopyDefaults = PartyOffCDCore.CopyDefaults
local SafeGetSpellInfo = PartyOffCDCore.SafeGetSpellInfo

function PartyOffCD:IsSpellEnabled(spellID)
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

function PartyOffCD:GetEffectiveMeta(senderKey, spellID)
    local override = self:GetPlayerOverride(spellID, senderKey)
    if override then
        return override
    end

    return BASE_SPELLS[spellID] or SPELLS[spellID]
end

function PartyOffCD:GetDisplayMeta(spellID)
    local playerKey = self:GetPlayerCanonical()
    return self:GetEffectiveMeta(playerKey, spellID) or SPELLS[spellID]
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


function PartyOffCD:GetSpellMeta(spellID)
    return SPELLS[spellID]
end


function PartyOffCD:InitializeDB()
    PartyOffCDDB = CopyDefaults(PartyOffCDDB, DB_DEFAULTS)
    self.db = PartyOffCDDB

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
                bucket[spellID] = {
                    cd = tonumber(meta.cd) or meta.cd,
                    type = meta.type,
                    class = meta.class,
                    custom = not BASE_SPELLS[spellID],
                    specs = meta.specs or (BASE_SPELLS[spellID] and BASE_SPELLS[spellID].specs) or nil,
                }
            end
        end
    end

    for senderKey, bucket in pairs(self.db.syncedOverrides) do
        if type(bucket) == "table" then
            for spellID, meta in pairs(bucket) do
                spellID = tonumber(spellID)
                if spellID and meta and meta.cd and meta.type and meta.class then
                    if not SPELLS[spellID] then
                        SPELLS[spellID] = {
                            cd = tonumber(meta.cd) or meta.cd,
                            type = meta.type,
                            class = meta.class,
                            custom = true,
                            specs = meta.specs,
                        }
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



