local ADDON_NAME = ...

local PartyOffCD = CreateFrame("Frame")
_G.PartyOffCD = PartyOffCD

local PREFIX = "POCD"
local MESSAGE_VERSION = "v1"
local DUPLICATE_WINDOW = 1.5
local UPDATE_INTERVAL = 0.2
local REAL_SYNC_INTERVAL = 2.0
local REAL_SYNC_THRESHOLD = 0.5
local MAX_TRACKED_ROWS = 5
local ICON_SIZE = 30
local ICON_SPACING = 3
local INTERRUPT_BAR_WIDTH = 190
local INTERRUPT_ROW_HEIGHT = 22
local INTERRUPT_ICON_SIZE = 18
local FALLBACK_X = 210
local FALLBACK_Y = 120
local MINIMAP_RADIUS = 96

local SPELL_TYPES = { "OFF", "DEF", "INT" }
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
    [31821] = { cd = 180, type = "DEF", class = "PALADIN" }, -- Aura Mastery

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
    [12042] = { cd = 90, type = "OFF", class = "MAGE", specs = { "ARCANE" } }, -- Arcane Power
    [12472] = { cd = 180, type = "OFF", class = "MAGE", specs = { "FROST" } }, -- Icy Veins
    [55342] = { cd = 120, type = "OFF", class = "MAGE" }, -- Mirror Image
    [45438] = { cd = 240, type = "DEF", class = "MAGE" }, -- Ice Block

    -- PRIEST
    [10060] = { cd = 120, type = "OFF", class = "PRIEST" }, -- Power Infusion
    [15487] = { cd = 45, type = "INT", class = "PRIEST", specs = { "SHADOW" } }, -- Silence
    [228260] = { cd = 90, type = "OFF", class = "PRIEST", specs = { "SHADOW" } }, -- Void Eruption
    [200183] = { cd = 120, type = "OFF", class = "PRIEST", specs = { "HOLY" } }, -- Apotheosis
    [47585] = { cd = 120, type = "DEF", class = "PRIEST", specs = { "SHADOW" } }, -- Dispersion
    [33206] = { cd = 180, type = "DEF", class = "PRIEST", specs = { "DISC" } }, -- Pain Suppression
    [47788] = { cd = 180, type = "DEF", class = "PRIEST", specs = { "HOLY" } }, -- Guardian Spirit
    [19236] = { cd = 90, type = "DEF", class = "PRIEST" }, -- Desperate Prayer
    [11487] = { cd = 30, type = "INT", class = "PRIEST" }, -- Interrupt
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

local PANEL_SPELLS = {
    31884,
    375087,
    190319,
    12042,
    12472,
    19574,
    97462,
    871,
    22812,
    48792,
    642,
    102342,
}

local DB_DEFAULTS = {
    panelPoint = "CENTER",
    panelRelativePoint = "CENTER",
    panelX = 320,
    panelY = 0,
    configPoint = "CENTER",
    configRelativePoint = "CENTER",
    configX = 0,
    configY = 0,
    interruptPoint = "CENTER",
    interruptRelativePoint = "CENTER",
    interruptX = -260,
    interruptY = 140,
    minimap = {
        angle = 220,
    },
    classEnabled = {},
    spellEnabled = {},
    customSpells = {},
    syncedOverrides = {},
}

PartyOffCD.cooldowns = {}
PartyOffCD.duplicateCache = {}
PartyOffCD.roster = {}
PartyOffCD.rosterLookup = {}
PartyOffCD.rows = {}
PartyOffCD.iconPool = {}
PartyOffCD.playerKeys = {}
PartyOffCD.db = nil
PartyOffCD.trackerTicker = nil
PartyOffCD.configRows = {}
PartyOffCD.classAddEditorState = {}
PartyOffCD.interruptRows = {}
PartyOffCD.lastOverrideBroadcast = 0
PartyOffCD.lastRealtimeSync = 0
PartyOffCD.lastLocalReport = {}
PartyOffCD.senderSpecIDs = {}

local function DebugPrint(message)
    print("|cff33ff99PartyOffCD|r: " .. tostring(message))
end

local function CopyDefaults(target, defaults)
    if type(target) ~= "table" then
        target = {}
    end

    for key, value in pairs(defaults) do
        if type(value) == "table" then
            target[key] = CopyDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end

    return target
end

local function SafeGetSpellInfo(spellID)
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spellID)
        if info then
            return info.name, info.iconID
        end
    end

    local name, _, icon = GetSpellInfo(spellID)
    return name, icon
end

local function SafeGetSpellCooldown(spellID)
    if C_Spell and C_Spell.GetSpellCooldown then
        local info = C_Spell.GetSpellCooldown(spellID)
        if info then
            return info.startTime or 0, info.duration or 0, info.isEnabled ~= false
        end
    end

    local startTime, duration, enabled = GetSpellCooldown(spellID)
    return startTime or 0, duration or 0, enabled ~= 0
end

local function GetUnitSpecID(unit)
    if not unit or not UnitExists(unit) then
        return nil
    end

    if UnitIsUnit(unit, "player") then
        local currentSpecIndex = GetSpecialization and GetSpecialization()
        if currentSpecIndex and currentSpecIndex > 0 then
            local specID = GetSpecializationInfo(currentSpecIndex)
            return specID
        end
        return nil
    end

    if GetInspectSpecialization then
        local inspectSpecID = GetInspectSpecialization(unit)
        if inspectSpecID and inspectSpecID > 0 then
            return inspectSpecID
        end
    end

    return nil
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

local function FormatRemaining(seconds)
    if seconds <= 0 then
        return ""
    end

    if seconds >= 60 then
        local minutes = math.floor(seconds / 60)
        local remain = math.floor(seconds % 60)
        if remain == 0 then
            return string.format("%dm", minutes)
        end
        return string.format("%d:%02d", minutes, remain)
    end

    return tostring(math.ceil(seconds))
end

local function GetUnitFullName(unit)
    if not UnitExists(unit) then
        return nil
    end

    local name, realm = UnitFullName(unit)
    if not name then
        return nil
    end

    if realm and realm ~= "" then
        return name .. "-" .. realm
    end

    return name
end

local function NormalizeName(name)
    if not name or name == "" then
        return nil
    end

    return string.lower(name)
end

local function ApplyLightOutline(fontString)
    if not fontString or not fontString.GetFont or not fontString.SetFont then
        return
    end

    local fontPath, fontSize = fontString:GetFont()
    if fontPath and fontSize then
        fontString:SetFont(fontPath, fontSize, "OUTLINE")
    end
end

local function GetNextSpellType(currentType)
    for index, spellType in ipairs(SPELL_TYPES) do
        if spellType == currentType then
            return SPELL_TYPES[(index % #SPELL_TYPES) + 1]
        end
    end

    return SPELL_TYPES[1]
end

local function CreateCheckbox(name, parent, labelText)
    local checkbox = CreateFrame("CheckButton", name, parent, "UICheckButtonTemplate")
    local label = checkbox.Text or (checkbox.GetName and checkbox:GetName() and _G[checkbox:GetName() .. "Text"])
    if label then
        label:SetText(labelText or "")
        label:SetJustifyH("LEFT")
    end
    return checkbox
end

local function CreateNumericEditBox(name, parent, width, maxLetters)
    local editBox = CreateFrame("EditBox", name, parent, "InputBoxTemplate")
    editBox:SetAutoFocus(false)
    editBox:SetNumeric(true)
    editBox:SetWidth(width)
    editBox:SetHeight(20)
    editBox:SetMaxLetters(maxLetters or 8)
    editBox:SetJustifyH("CENTER")
    return editBox
end

function PartyOffCD:GetClassLabel(classToken)
    return CLASS_LABELS[classToken] or classToken or "Unknown"
end

function PartyOffCD:GetPlayerCanonical()
    return self.playerKeys.full or self.playerKeys.short
end

function PartyOffCD:GetCurrentPlayerSpecID()
    local specID = GetUnitSpecID("player") or self.playerKeys.specID
    if specID and specID > 0 then
        self.playerKeys.specID = specID
        if self.playerKeys.full then
            self.senderSpecIDs[self.playerKeys.full] = specID
        end
        if self.playerKeys.short then
            self.senderSpecIDs[self.playerKeys.short] = specID
        end
        return specID
    end

    return nil
end

function PartyOffCD:IsSelfSender(sender)
    local key = NormalizeName(sender)
    if not key then
        return false
    end

    return key == self.playerKeys.full or key == self.playerKeys.short
end

function PartyOffCD:ResolveSenderKey(sender)
    local key = NormalizeName(sender)
    if not key then
        return nil
    end

    local rosterEntry = self.rosterLookup[key]
    if rosterEntry then
        return rosterEntry.key
    end

    return key
end

function PartyOffCD:GetTargetChannel()
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return "INSTANCE_CHAT"
    end

    if IsInRaid() then
        return "RAID"
    end

    if IsInGroup() then
        return "PARTY"
    end

    return nil
end

function PartyOffCD:EncodeUseMessage(spellID, timestamp, specID)
    return table.concat({
        MESSAGE_VERSION,
        "U",
        tostring(spellID),
        string.format("%.2f", timestamp or GetTime()),
        tostring(specID or 0),
    }, ";")
end

function PartyOffCD:EncodeSyncMessage(spellID, cooldown, spellType, classToken, specID)
    return table.concat({
        MESSAGE_VERSION,
        "S",
        tostring(spellID),
        tostring(cooldown),
        tostring(spellType),
        tostring(classToken),
        tostring(specID or 0),
    }, ";")
end

function PartyOffCD:EncodeTimerAdjustMessage(spellID, remaining, specID)
    return table.concat({
        MESSAGE_VERSION,
        "R",
        tostring(spellID),
        tostring(remaining),
        tostring(specID or 0),
    }, ";")
end

function PartyOffCD:EncodeHelloMessage(specID)
    return table.concat({
        MESSAGE_VERSION,
        "H",
        tostring(specID or 0),
    }, ";")
end

function PartyOffCD:DecodeMessage(message)
    if type(message) ~= "string" or message == "" then
        return nil
    end

    local version, action, a, b, c, d, e = strsplit(";", message)
    if version ~= MESSAGE_VERSION then
        return nil
    end

    if action == "U" then
        local spellID = tonumber(a)
        local senderTime = tonumber(b)
        local senderSpecID = tonumber(c)
        if not spellID then
            return nil
        end

        return action, spellID, senderTime, senderSpecID
    end

    if action == "S" then
        local spellID = tonumber(a)
        local cooldown = tonumber(b)
        local spellType = c
        local classToken = d
        local senderSpecID = tonumber(e)
        if not spellID or not cooldown or cooldown <= 0 then
            return nil
        end

        return action, spellID, cooldown, spellType, classToken, senderSpecID
    end

    if action == "R" then
        local spellID = tonumber(a)
        local remaining = tonumber(b)
        local senderSpecID = tonumber(c)
        if not spellID or remaining == nil then
            return nil
        end

        return action, spellID, remaining, senderSpecID
    end

    if action == "H" then
        local senderSpecID = tonumber(a)
        return action, nil, senderSpecID
    end

    return nil
end

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

function PartyOffCD:GetSenderClass(senderKey)
    senderKey = self:ResolveSenderKey(senderKey)
    if not senderKey then
        return nil
    end

    local rosterEntry = self.rosterLookup[senderKey]
    if rosterEntry and rosterEntry.class then
        return rosterEntry.class
    end

    if senderKey == self.playerKeys.full or senderKey == self.playerKeys.short then
        return self.playerKeys.class
    end

    return nil
end

function PartyOffCD:GetSenderSpecID(senderKey)
    senderKey = self:ResolveSenderKey(senderKey)
    if not senderKey then
        return nil
    end

    local rosterEntry = self.rosterLookup[senderKey]
    if rosterEntry and rosterEntry.specID then
        return rosterEntry.specID
    end

    if rosterEntry then
        if rosterEntry.key and self.senderSpecIDs[rosterEntry.key] then
            return self.senderSpecIDs[rosterEntry.key]
        end
        if rosterEntry.shortKey and self.senderSpecIDs[rosterEntry.shortKey] then
            return self.senderSpecIDs[rosterEntry.shortKey]
        end
    end

    if self.senderSpecIDs[senderKey] then
        return self.senderSpecIDs[senderKey]
    end

    if senderKey == self.playerKeys.full or senderKey == self.playerKeys.short then
        return self.playerKeys.specID
    end

    return nil
end

function PartyOffCD:UpdateSenderSpecID(senderKey, specID)
    senderKey = self:ResolveSenderKey(senderKey)
    specID = tonumber(specID)
    if not senderKey or not specID or specID <= 0 then
        return false
    end

    self.senderSpecIDs[senderKey] = specID

    local rosterEntry = self.rosterLookup[senderKey]
    if rosterEntry then
        rosterEntry.specID = specID
        if rosterEntry.key then
            self.senderSpecIDs[rosterEntry.key] = specID
        end
        if rosterEntry.shortKey then
            self.senderSpecIDs[rosterEntry.shortKey] = specID
        end
    end

    if senderKey == self.playerKeys.full or senderKey == self.playerKeys.short then
        self.playerKeys.specID = specID
    end

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
    self:RefreshPanelButtons()
    self:RefreshConfigPanel()
    self:RefreshTracker()
end

function PartyOffCD:SetSpellEnabled(spellID, isEnabled)
    if not SPELLS[spellID] then
        return
    end

    self.db.spellEnabled[spellID] = isEnabled and true or false
    self:PruneDisabledCooldowns()
    self:RefreshPanelButtons()
    self:RefreshConfigPanel()
    self:RefreshTracker()
end

function PartyOffCD:SendSyncMessage(spellID, meta)
    local channel = self:GetTargetChannel()
    if not channel then
        return false
    end

    local message = self:EncodeSyncMessage(spellID, meta.cd, meta.type, meta.class, self:GetCurrentPlayerSpecID())
    C_ChatInfo.SendAddonMessage(PREFIX, message, channel)
    return true
end

function PartyOffCD:SendTimerAdjustMessage(spellID, remaining)
    local channel = self:GetTargetChannel()
    if not channel then
        return false
    end

    local message = self:EncodeTimerAdjustMessage(spellID, remaining, self:GetCurrentPlayerSpecID())
    C_ChatInfo.SendAddonMessage(PREFIX, message, channel)
    return true
end

function PartyOffCD:SendHelloMessage()
    local channel = self:GetTargetChannel()
    if not channel then
        return false
    end

    local message = self:EncodeHelloMessage(self:GetCurrentPlayerSpecID())
    C_ChatInfo.SendAddonMessage(PREFIX, message, channel)
    return true
end

function PartyOffCD:NotifyOverrideReceived(sender, spellID, meta)
    local spellName = SafeGetSpellInfo(spellID) or ("Spell " .. tostring(spellID))
    local senderName = Ambiguate and Ambiguate(sender or "?", "short") or (sender or "?")
    local message = string.format("%s actualizo %s a %ss", senderName, spellName, tostring(meta.cd))
    DebugPrint(message)

    if UIErrorsFrame and UIErrorsFrame.AddMessage then
        UIErrorsFrame:AddMessage(message, 0.3, 1, 0.5, 1.5)
    end
end

function PartyOffCD:BroadcastLocalOverrides(force)
    local channel = self:GetTargetChannel()
    if not channel then
        return
    end

    local now = GetTime()
    if not force and (now - (self.lastOverrideBroadcast or 0)) < 3 then
        return
    end

    local playerKey = self:GetPlayerCanonical()
    if not playerKey then
        return
    end

    local bucket = self:GetOverrideBucket(playerKey, false)
    if not bucket then
        return
    end

    self.lastOverrideBroadcast = now

    for spellID, meta in pairs(bucket) do
        self:SendSyncMessage(spellID, meta)
    end
end

function PartyOffCD:RequestGroupOverrides()
    self:SendHelloMessage()
end

function PartyOffCD:AddCustomSpell(classToken, spellID, cooldown, spellType)
    spellID = tonumber(spellID)
    cooldown = tonumber(cooldown)
    spellType = spellType and string.upper(spellType) or nil

    if not classToken or not CLASS_LABELS[classToken] then
        DebugPrint("Clase invalida para custom spell.")
        return false
    end

    if not spellID or spellID <= 0 then
        DebugPrint("SpellID invalido.")
        return false
    end

    if not cooldown or cooldown <= 0 then
        DebugPrint("CD invalido. Debe ser un numero en segundos.")
        return false
    end

    if not SPELL_TYPE_PRIORITY[spellType] then
        DebugPrint("Tipo invalido. Usa OFF, DEF o INT.")
        return false
    end

    local spellName = SafeGetSpellInfo(spellID)
    if not spellName then
        DebugPrint("Ese spellID no existe o no esta disponible en el cliente.")
        return false
    end

    local existing = SPELLS[spellID]
    local playerKey = self:GetPlayerCanonical()
    if not playerKey then
        DebugPrint("No se pudo identificar tu personaje para guardar el override.")
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
    self:RefreshPanelButtons()
    self:RefreshConfigPanel()
    self:RefreshTracker()
    if existing then
        DebugPrint(string.format("Spell actualizado: %s (%d, %s, %ss)", spellName, spellID, spellType, cooldown))
    else
        DebugPrint(string.format("Custom spell agregado: %s (%d, %s, %ss)", spellName, spellID, spellType, cooldown))
    end
    if synced then
        DebugPrint("Override sincronizado con el grupo.")
    end
    return true
end

function PartyOffCD:ShouldIgnoreDuplicate(senderKey, spellID)
    local now = GetTime()
    self.duplicateCache[senderKey] = self.duplicateCache[senderKey] or {}

    local lastSeen = self.duplicateCache[senderKey][spellID]
    if lastSeen and (now - lastSeen) < DUPLICATE_WINDOW then
        return true
    end

    self.duplicateCache[senderKey][spellID] = now
    return false
end

function PartyOffCD:PruneDisabledCooldowns()
    for senderKey, spells in pairs(self.cooldowns) do
        for spellID in pairs(spells) do
            if not self:IsSpellEnabled(spellID) then
                spells[spellID] = nil
            end
        end

        if not next(spells) then
            self.cooldowns[senderKey] = nil
        end
    end
end

function PartyOffCD:PruneState()
    local now = GetTime()

    for senderKey, spells in pairs(self.cooldowns) do
        for spellID, cooldownData in pairs(spells) do
            local endTime = type(cooldownData) == "table" and cooldownData.endTime or cooldownData
            if endTime <= now or not self:IsSpellEnabled(spellID) then
                spells[spellID] = nil
            end
        end

        if not next(spells) then
            self.cooldowns[senderKey] = nil
        end
    end

    for senderKey, spells in pairs(self.duplicateCache) do
        for spellID, lastSeen in pairs(spells) do
            if (now - lastSeen) > 10 then
                spells[spellID] = nil
            end
        end

        if not next(spells) then
            self.duplicateCache[senderKey] = nil
        end
    end
end

function PartyOffCD:GetSpellMeta(spellID)
    return SPELLS[spellID]
end

function PartyOffCD:GetLocalCooldownRemaining(spellID)
    local startTime, duration, enabled = SafeGetSpellCooldown(spellID)
    if not enabled or not startTime or not duration then
        return 0, duration or 0
    end

    if duration <= 1.5 or startTime <= 0 then
        return 0, duration
    end

    local remaining = (startTime + duration) - GetTime()
    if remaining < 0 then
        remaining = 0
    end

    return remaining, duration
end

function PartyOffCD:StartCooldown(senderKey, spellID, senderTime)
    senderKey = self:ResolveSenderKey(senderKey)
    local meta = self:GetEffectiveMeta(senderKey, spellID)
    if not meta or not self:IsSpellEnabled(spellID) then
        return false
    end

    if not senderKey then
        return false
    end

    local now = GetTime()
    local startTime = tonumber(senderTime) or now
    if startTime > (now + 10) or startTime < (now - 600) then
        startTime = now
    end

    self.cooldowns[senderKey] = self.cooldowns[senderKey] or {}
    self.cooldowns[senderKey][spellID] = {
        endTime = startTime + meta.cd,
        duration = meta.cd,
        type = meta.type,
    }
    return true
end

function PartyOffCD:SetRemainingCooldown(senderKey, spellID, remaining, skipSend)
    senderKey = self:ResolveSenderKey(senderKey)
    remaining = tonumber(remaining)
    if not senderKey or not remaining then
        return false
    end

    if remaining <= 0 then
        if self.cooldowns[senderKey] then
            self.cooldowns[senderKey][spellID] = nil
            if not next(self.cooldowns[senderKey]) then
                self.cooldowns[senderKey] = nil
            end
        end
        self:RefreshTracker()
        return true
    end

    local meta = self:GetEffectiveMeta(senderKey, spellID)
    if not meta or not self:IsSpellEnabled(spellID) then
        return false
    end

    self.cooldowns[senderKey] = self.cooldowns[senderKey] or {}
    self.cooldowns[senderKey][spellID] = {
        endTime = GetTime() + remaining,
        duration = remaining,
        type = meta.type,
    }

    if not skipSend and self:IsSelfSender(senderKey) then
        self:SendTimerAdjustMessage(spellID, remaining)
    end

    self:RefreshTracker()
    return true
end

function PartyOffCD:CanReportLocalUse(spellID)
    local remaining = self:GetLocalCooldownRemaining(spellID)
    if remaining and remaining > 0.2 then
        return false, remaining
    end

    return true, 0
end

function PartyOffCD:HandleLocalSpellcastSucceeded(spellID)
    spellID = tonumber(spellID)
    if not spellID or not self:GetSpellMeta(spellID) or not self:IsSpellEnabled(spellID) then
        return
    end

    local now = GetTime()
    local last = self.lastLocalReport[spellID]
    if last and (now - last) < 0.75 then
        return
    end

    self.lastLocalReport[spellID] = now
    self:ReportSpellUse(spellID, true)
end

function PartyOffCD:SyncLocalRealCooldowns()
    local playerKey = self:GetPlayerCanonical()
    if not playerKey or not self.cooldowns[playerKey] then
        return
    end

    local now = GetTime()
    if (now - (self.lastRealtimeSync or 0)) < REAL_SYNC_INTERVAL then
        return
    end

    self.lastRealtimeSync = now

    for spellID, cooldownData in pairs(self.cooldowns[playerKey]) do
        if self:IsSpellEnabled(spellID) then
            local trackedRemaining = (type(cooldownData) == "table" and cooldownData.endTime or 0) - now
            local realRemaining = self:GetLocalCooldownRemaining(spellID)

            if trackedRemaining < 0 then
                trackedRemaining = 0
            end

            if realRemaining <= 0 then
                if trackedRemaining > REAL_SYNC_THRESHOLD then
                    self:SetRemainingCooldown(playerKey, spellID, 0)
                end
            elseif math.abs(realRemaining - trackedRemaining) >= REAL_SYNC_THRESHOLD then
                self:SetRemainingCooldown(playerKey, spellID, math.ceil(realRemaining))
            end
        end
    end
end

function PartyOffCD:SendUseMessage(spellID)
    local channel = self:GetTargetChannel()
    if not channel then
        return false
    end

    local message = self:EncodeUseMessage(spellID, GetTime(), self:GetCurrentPlayerSpecID())
    C_ChatInfo.SendAddonMessage(PREFIX, message, channel)
    return true
end

function PartyOffCD:ReportSpellUse(spellID, silent)
    spellID = tonumber(spellID)
    local meta = self:GetSpellMeta(spellID)
    if not meta then
        if not silent then
            DebugPrint("SpellID no soportado: " .. tostring(spellID))
        end
        return
    end

    if not self:IsSpellEnabled(spellID) then
        if not silent then
            DebugPrint("Ese spell esta desactivado en la configuracion.")
        end
        return
    end

    if not silent then
        local canReport, remaining = self:CanReportLocalUse(spellID)
        if not canReport then
            DebugPrint(string.format("Ese spell aun esta en cooldown real (%.1fs).", remaining))
            return
        end
    end

    local playerKey = self:GetPlayerCanonical()
    if playerKey then
        self:StartCooldown(playerKey, spellID, GetTime())
    end

    local sent = self:SendUseMessage(spellID)
    if not sent and not silent then
        DebugPrint("No estas en grupo; se inicio solo el timer local para " .. tostring(spellID))
    end

    self:RefreshTracker()
end

function PartyOffCD:HandleAddonMessage(prefix, message, _, sender)
    if prefix ~= PREFIX then
        return
    end

    if self:IsSelfSender(sender) then
        return
    end

    local action, spellID, valueA, valueB, valueC, valueD = self:DecodeMessage(message)
    if not action then
        return
    end

    local senderKey = self:ResolveSenderKey(sender)
    if not senderKey then
        return
    end

    if action == "H" then
        local senderSpecID = valueA
        self:UpdateSenderSpecID(senderKey, senderSpecID)
        self:BroadcastLocalOverrides(true)
        self:RefreshTracker()
        return
    end

    if not spellID then
        return
    end

    if action == "U" then
        local senderTime = valueA
        local senderSpecID = valueB
        self:UpdateSenderSpecID(senderKey, senderSpecID)
        local meta = self:GetEffectiveMeta(senderKey, spellID)
        if not meta or not self:IsSpellEnabled(spellID) then
            return
        end

        if self:ShouldIgnoreDuplicate(senderKey, spellID) then
            return
        end

        self:StartCooldown(senderKey, spellID, senderTime)
        self:RefreshTracker()
        return
    end

    if action == "S" then
        local cooldown = valueA
        local spellType = valueB
        local classToken = valueC
        local senderSpecID = valueD
        self:UpdateSenderSpecID(senderKey, senderSpecID)

        if not SPELL_TYPE_PRIORITY[spellType] then
            return
        end

        if not CLASS_LABELS[classToken] then
            return
        end

        local bucket = self:GetOverrideBucket(senderKey, true)
        local previous = bucket[spellID]
        local previousCooldown = previous and tonumber(previous.cd) or nil
        local sameOverride = previous and previousCooldown == cooldown and previous.type == spellType and previous.class == classToken
        bucket[spellID] = {
            cd = cooldown,
            type = spellType,
            class = classToken,
            custom = not BASE_SPELLS[spellID],
            specs = (BASE_SPELLS[spellID] and BASE_SPELLS[spellID].specs) or (SPELLS[spellID] and SPELLS[spellID].specs) or nil,
        }

        local addedGlobalSpell = false
        if not SPELLS[spellID] then
            SPELLS[spellID] = {
                cd = cooldown,
                type = spellType,
                class = classToken,
                custom = true,
            }
            addedGlobalSpell = true
        end

        if not sameOverride then
            self:NotifyOverrideReceived(sender, spellID, bucket[spellID])
        end

        if not sameOverride or addedGlobalSpell then
            self:RefreshConfigPanel()
            self:RefreshTracker()
        end
        return
    end

    if action == "R" then
        local remaining = valueA
        local senderSpecID = valueB
        self:UpdateSenderSpecID(senderKey, senderSpecID)
        local meta = self:GetEffectiveMeta(senderKey, spellID)
        if not meta or not self:IsSpellEnabled(spellID) then
            return
        end

        self:SetRemainingCooldown(senderKey, spellID, remaining, true)
    end
end

function PartyOffCD:BuildRoster()
    wipe(self.roster)
    wipe(self.rosterLookup)

    local units = {}

    if IsInRaid() then
        for index = 1, math.min(GetNumGroupMembers(), MAX_TRACKED_ROWS) do
            units[#units + 1] = "raid" .. index
        end
    elseif IsInGroup() then
        units[#units + 1] = "player"
        for index = 1, MAX_TRACKED_ROWS - 1 do
            units[#units + 1] = "party" .. index
        end
    end

    for _, unit in ipairs(units) do
        if UnitExists(unit) then
            local fullName = GetUnitFullName(unit)
            local shortName = UnitName(unit)
            local _, classToken = UnitClass(unit)
            local specID = GetUnitSpecID(unit)
            local key = NormalizeName(fullName)
            local shortKey = NormalizeName(shortName)

            if not specID then
                specID = (key and self.senderSpecIDs[key]) or (shortKey and self.senderSpecIDs[shortKey]) or nil
            end

            if fullName and shortName then
                local entry = {
                    unit = unit,
                    name = shortName,
                    fullName = fullName,
                    class = classToken,
                    specID = specID,
                    key = key,
                    shortKey = shortKey,
                }

                self.roster[#self.roster + 1] = entry

                if entry.key then
                    self.rosterLookup[entry.key] = entry
                end

                if entry.shortKey and not self.rosterLookup[entry.shortKey] then
                    self.rosterLookup[entry.shortKey] = entry
                end

                if specID then
                    if entry.key then
                        self.senderSpecIDs[entry.key] = specID
                    end
                    if entry.shortKey then
                        self.senderSpecIDs[entry.shortKey] = specID
                    end
                end
            end
        end
    end

    local playerFull = GetUnitFullName("player")
    local playerShort = UnitName("player")
    local _, playerClass = UnitClass("player")
    local playerSpecID = GetUnitSpecID("player")
    local playerFullKey = NormalizeName(playerFull)
    local playerShortKey = NormalizeName(playerShort)
    if not playerSpecID then
        playerSpecID = (playerFullKey and self.senderSpecIDs[playerFullKey]) or (playerShortKey and self.senderSpecIDs[playerShortKey]) or nil
    end
    self.playerKeys.full = playerFullKey
    self.playerKeys.short = playerShortKey
    self.playerKeys.class = playerClass
    self.playerKeys.specID = playerSpecID
    if playerSpecID then
        if self.playerKeys.full then
            self.senderSpecIDs[self.playerKeys.full] = playerSpecID
        end
        if self.playerKeys.short then
            self.senderSpecIDs[self.playerKeys.short] = playerSpecID
        end
    end
end

local function GetCompactPartyAnchor(index)
    local frame = _G["CompactPartyFrameMember" .. index]
    if frame and frame:IsShown() then
        return frame
    end

    local raidFrame = _G["CompactRaidFrame" .. index]
    if raidFrame and raidFrame:IsShown() then
        return raidFrame
    end

    return nil
end

function PartyOffCD:CreateTrackerFrame()
    if self.trackerFrame then
        return
    end

    local frame = CreateFrame("Frame", "PartyOffCDTrackerFrame", UIParent)
    frame:SetSize(260, 180)
    frame:SetPoint("LEFT", UIParent, "LEFT", FALLBACK_X, FALLBACK_Y)
    frame:Hide()

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 4)
    title:SetText("PartyOffCD")

    self.trackerFrame = frame
end

function PartyOffCD:AcquireIcon(parent)
    local icon = tremove(self.iconPool)
    if icon then
        icon:SetParent(parent)
        icon:Show()
        return icon
    end

    icon = CreateFrame("Button", nil, parent)
    icon:SetSize(ICON_SIZE, ICON_SIZE)

    icon.texture = icon:CreateTexture(nil, "ARTWORK")
    icon.texture:SetAllPoints()
    icon.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    icon.cooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
    icon.cooldown:SetAllPoints()
    if icon.cooldown.SetDrawSwipe then
        icon.cooldown:SetDrawSwipe(false)
    end
    if icon.cooldown.SetDrawBling then
        icon.cooldown:SetDrawBling(false)
    end
    if icon.cooldown.SetHideCountdownNumbers then
        icon.cooldown:SetHideCountdownNumbers(true)
    end

    icon.timeText = icon:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    icon.timeText:SetPoint("BOTTOM", icon, "BOTTOM", 0, 2)
    icon.timeText:SetShadowOffset(1, -1)
    ApplyLightOutline(icon.timeText)

    icon.typeText = icon:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    icon.typeText:SetPoint("TOP", icon, "TOP", 0, -2)

    icon:SetScript("OnEnter", function(button)
        if not button.spellID then
            return
        end

        GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
        GameTooltip:SetSpellByID(button.spellID)
        GameTooltip:AddLine("Base CD: " .. tostring(button.baseCD) .. "s", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)

    icon:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    return icon
end

function PartyOffCD:ReleaseRowIcons(row)
    if not row.icons then
        return
    end

    for _, icon in ipairs(row.icons) do
        icon:Hide()
        icon:ClearAllPoints()
        icon:SetParent(UIParent)
        icon.spellID = nil
        icon.baseCD = nil
        icon:SetAlpha(1)
        if icon.texture.SetDesaturated then
            icon.texture:SetDesaturated(false)
        end
        icon.cooldown:SetCooldown(0, 0)
        icon.timeText:SetText("")
        icon.typeText:SetText("")
        tinsert(self.iconPool, icon)
    end

    wipe(row.icons)
end

function PartyOffCD:CreateRow(index)
    local row = CreateFrame("Frame", nil, self.trackerFrame)
    row:SetSize(240, 28)
    row.index = index
    row.icons = {}

    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.label:SetPoint("RIGHT", row, "LEFT", -6, 0)
    row.label:SetJustifyH("RIGHT")
    row.label:SetWidth(90)

    self.rows[index] = row
    return row
end

function PartyOffCD:GetRow(index)
    return self.rows[index] or self:CreateRow(index)
end

function PartyOffCD:GetSortedCooldowns(senderKey, onlyType)
    local senderCooldowns = self.cooldowns[senderKey]
    local now = GetTime()
    local entries = {}
    local senderClass = self:GetSenderClass(senderKey)
    local senderSpecID = self:GetSenderSpecID(senderKey)

    for spellID in pairs(SPELLS) do
        if self:IsSpellEnabled(spellID) then
            local meta = self:GetEffectiveMeta(senderKey, spellID)
            local passesType = meta and ((onlyType and meta.type == onlyType) or (not onlyType and meta.type ~= "INT"))
            local passesClass = meta and (not senderClass or meta.class == senderClass)
            local passesSpec = passesType and passesClass and ((not meta.specs) or (not senderSpecID))
            if passesClass and not passesSpec and meta.specs and senderSpecID then
                for _, specValue in ipairs(meta.specs) do
                    local allowedSpecID = ResolveSpecValue(meta.class, specValue)
                    if allowedSpecID == senderSpecID then
                        passesSpec = true
                        break
                    end
                end
            end

            if passesType and passesClass and passesSpec then
                local cooldownData = senderCooldowns and senderCooldowns[spellID] or nil
                local endTime = cooldownData and (type(cooldownData) == "table" and cooldownData.endTime or cooldownData) or 0
                local duration = cooldownData and (type(cooldownData) == "table" and cooldownData.duration or meta.cd) or meta.cd
                local remaining = endTime - now
                local isActive = remaining > 0

                if not isActive then
                    remaining = 0
                    endTime = 0
                    duration = meta.cd
                end

                entries[#entries + 1] = {
                    spellID = spellID,
                    endTime = endTime,
                    remaining = remaining,
                    meta = meta,
                    duration = duration,
                    isActive = isActive,
                }
            end
        end
    end

    table.sort(entries, function(a, b)
        if onlyType == "INT" then
            if a.remaining == b.remaining then
                return a.spellID < b.spellID
            end
            return a.remaining < b.remaining
        end

        if a.meta.type ~= b.meta.type then
            return (SPELL_TYPE_PRIORITY[a.meta.type] or 99) < (SPELL_TYPE_PRIORITY[b.meta.type] or 99)
        end
        if a.meta.class ~= b.meta.class then
            return tostring(a.meta.class) < tostring(b.meta.class)
        end
        if a.meta.cd ~= b.meta.cd then
            return a.meta.cd < b.meta.cd
        end
        if a.remaining == b.remaining then
            return a.spellID < b.spellID
        end
        return a.remaining < b.remaining
    end)

    return entries
end

function PartyOffCD:AnchorRow(row, index)
    row:ClearAllPoints()

    local target = GetCompactPartyAnchor(index)
    if target then
        row:SetParent(target)
        row:SetPoint("RIGHT", target, "LEFT", -4, 0)
    else
        row:SetParent(self.trackerFrame)
        if index == 1 then
            row:SetPoint("TOPLEFT", self.trackerFrame, "TOPLEFT", 0, 0)
        else
            row:SetPoint("TOPLEFT", self.rows[index - 1], "BOTTOMLEFT", 0, -8)
        end
    end
end

function PartyOffCD:RenderRow(row, rosterEntry)
    row.label:SetText(rosterEntry.name or "?")
    self:ReleaseRowIcons(row)

    local entries = self:GetSortedCooldowns(rosterEntry.key)
    if not entries or #entries == 0 then
        row:Hide()
        return
    end

    row:Show()
    self:AnchorRow(row, row.index)

    local previousEntry = nil
    for iconIndex, entry in ipairs(entries) do
        local icon = self:AcquireIcon(row)
        local _, texture = SafeGetSpellInfo(entry.spellID)

        icon.spellID = entry.spellID
        icon.baseCD = entry.meta.cd
        icon.texture:SetTexture(texture or 134400)
        icon.typeText:SetText("")
        if entry.isActive then
            icon:SetAlpha(1)
            if icon.texture.SetDesaturated then
                icon.texture:SetDesaturated(false)
            end
            icon.timeText:SetText(FormatRemaining(entry.remaining))
            icon.cooldown:SetCooldown(entry.endTime - entry.duration, entry.duration)
        else
            icon:SetAlpha(0.55)
            if icon.texture.SetDesaturated then
                icon.texture:SetDesaturated(true)
            end
            icon.timeText:SetText("")
            icon.cooldown:SetCooldown(0, 0)
        end
        if iconIndex == 1 then
            icon:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        else
            local spacing = ICON_SPACING
            if previousEntry and previousEntry.meta.type ~= entry.meta.type then
                spacing = ICON_SPACING + 8
            end
            icon:SetPoint("RIGHT", row.icons[iconIndex - 1], "LEFT", -spacing, 0)
        end

        row.icons[iconIndex] = icon
        previousEntry = entry
    end
end

function PartyOffCD:CreateInterruptFrame()
    if self.interruptFrame then
        return
    end

    local frame = CreateFrame("Frame", "PartyOffCDInterruptFrame", UIParent)
    frame:SetSize(INTERRUPT_BAR_WIDTH, 32)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(selfFrame)
        selfFrame:StopMovingOrSizing()
        local point, _, relativePoint, x, y = selfFrame:GetPoint(1)
        PartyOffCD.db.interruptPoint = point
        PartyOffCD.db.interruptRelativePoint = relativePoint
        PartyOffCD.db.interruptX = x
        PartyOffCD.db.interruptY = y
    end)

    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.10, 0.06, 0.18, 0.88)

    local borderTop = frame:CreateTexture(nil, "BORDER")
    borderTop:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    borderTop:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    borderTop:SetHeight(1)
    borderTop:SetColorTexture(0.95, 0.82, 0.2, 0.9)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOP", frame, "TOP", 0, -6)
    title:SetText("Interrupts")
    title:SetTextColor(1, 0.85, 0.15)

    local emptyText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    emptyText:SetPoint("TOP", title, "BOTTOM", 0, -8)
    emptyText:SetText("Drag to move")
    emptyText:SetTextColor(0.75, 0.75, 0.75)
    frame.emptyText = emptyText

    local db = self.db or DB_DEFAULTS
    frame:SetPoint(
        db.interruptPoint or DB_DEFAULTS.interruptPoint,
        UIParent,
        db.interruptRelativePoint or DB_DEFAULTS.interruptRelativePoint,
        db.interruptX or DB_DEFAULTS.interruptX,
        db.interruptY or DB_DEFAULTS.interruptY
    )

    self.interruptFrame = frame
end

function PartyOffCD:CreateInterruptRow(index)
    local row = CreateFrame("StatusBar", nil, self.interruptFrame)
    row:SetSize(INTERRUPT_BAR_WIDTH - 12, INTERRUPT_ROW_HEIGHT)
    row:SetMinMaxValues(0, 1)
    row:SetValue(0)
    row:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    row.index = index

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(0.05, 0.05, 0.05, 0.55)

    row.iconBackdrop = row:CreateTexture(nil, "ARTWORK")
    row.iconBackdrop:SetSize(INTERRUPT_ICON_SIZE + 2, INTERRUPT_ICON_SIZE + 2)
    row.iconBackdrop:SetPoint("LEFT", row, "LEFT", 2, 0)
    row.iconBackdrop:SetColorTexture(0.02, 0.02, 0.02, 0.95)

    row.icon = row:CreateTexture(nil, "OVERLAY")
    row.icon:SetSize(INTERRUPT_ICON_SIZE, INTERRUPT_ICON_SIZE)
    row.icon:SetPoint("CENTER", row.iconBackdrop, "CENTER", 0, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.nameText:SetPoint("LEFT", row.iconBackdrop, "RIGHT", 6, 0)
    row.nameText:SetJustifyH("LEFT")
    row.nameText:SetWidth(110)

    row.timeText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.timeText:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    row.timeText:SetJustifyH("RIGHT")
    ApplyLightOutline(row.timeText)

    self.interruptRows[index] = row
    return row
end

function PartyOffCD:GetInterruptRow(index)
    return self.interruptRows[index] or self:CreateInterruptRow(index)
end

function PartyOffCD:GetActiveInterruptEntry(senderKey)
    local entries = self:GetSortedCooldowns(senderKey, "INT")
    for _, entry in ipairs(entries) do
        if entry.isActive then
            return entry
        end
    end

    return nil
end

function PartyOffCD:RenderInterruptRow(row, rosterEntry, entry)
    local _, texture = SafeGetSpellInfo(entry.spellID)
    local classColor = RAID_CLASS_COLORS and RAID_CLASS_COLORS[rosterEntry.class] or nil
    local remaining = math.max(0, entry.remaining or 0)
    local duration = math.max(1, entry.duration or entry.meta.cd or 1)

    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", self.interruptFrame, "TOPLEFT", 6, -24 - ((row.index - 1) * (INTERRUPT_ROW_HEIGHT + 2)))
    row:SetMinMaxValues(0, duration)
    row:SetValue(remaining)
    row.icon:SetTexture(texture or 134400)
    row.nameText:SetText(rosterEntry.name or "?")
    row.timeText:SetText(FormatRemaining(remaining))

    if classColor then
        row:SetStatusBarColor(classColor.r, classColor.g, classColor.b)
    else
        row:SetStatusBarColor(0.6, 0.45, 0.2)
    end

    row:Show()
end

function PartyOffCD:RefreshInterruptBar()
    if not self.interruptFrame then
        return
    end

    local activeCount = 0
    for _, rosterEntry in ipairs(self.roster) do
        local entry = self:GetActiveInterruptEntry(rosterEntry.key)
        if entry then
            activeCount = activeCount + 1
            local row = self:GetInterruptRow(activeCount)
            self:RenderInterruptRow(row, rosterEntry, entry)
        end
    end

    for index = (activeCount + 1), #self.interruptRows do
        self.interruptRows[index]:Hide()
    end

    if activeCount == 0 then
        self.interruptFrame:SetHeight(44)
        if self.interruptFrame.emptyText then
            self.interruptFrame.emptyText:Show()
        end
        self.interruptFrame:Show()
        return
    end

    if self.interruptFrame.emptyText then
        self.interruptFrame.emptyText:Hide()
    end
    self.interruptFrame:SetHeight(28 + (activeCount * (INTERRUPT_ROW_HEIGHT + 2)))
    self.interruptFrame:Show()
end

function PartyOffCD:RefreshTracker()
    self:PruneState()

    if not IsInGroup() and not IsInRaid() then
        if self.trackerFrame then
            self.trackerFrame:Hide()
        end
        if self.interruptFrame then
            self.interruptFrame:Hide()
        end

        for _, row in ipairs(self.rows) do
            self:ReleaseRowIcons(row)
            row:Hide()
        end
        for _, row in ipairs(self.interruptRows) do
            row:Hide()
        end
        return
    end

    self:BuildRoster()

    if #self.roster == 0 then
        if self.trackerFrame then
            self.trackerFrame:Hide()
        end
        if self.interruptFrame then
            self.interruptFrame:Hide()
        end
        for _, row in ipairs(self.interruptRows) do
            row:Hide()
        end
        return
    end

    self:CreateTrackerFrame()
    self:CreateInterruptFrame()
    self.trackerFrame:Show()

    for index, entry in ipairs(self.roster) do
        local row = self:GetRow(index)
        self:RenderRow(row, entry)
    end

    for index = (#self.roster + 1), #self.rows do
        local row = self.rows[index]
        self:ReleaseRowIcons(row)
        row:Hide()
    end

    self:RefreshInterruptBar()
end

function PartyOffCD:RefreshPanelButtons()
    if not self.panel or not self.panel.buttons then
        return
    end

    for _, button in ipairs(self.panel.buttons) do
        local enabled = self:IsSpellEnabled(button.spellID)
        if button.texture.SetDesaturated then
            button.texture:SetDesaturated(not enabled)
        end
        button:SetAlpha(enabled and 1 or 0.35)
    end
end

function PartyOffCD:CreatePanel()
    if self.panel then
        return
    end

    local panel = CreateFrame("Frame", "PartyOffCDPanel", UIParent)
    panel:SetSize(242, 116)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetClampedToScreen(true)
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
        local point, _, relativePoint, x, y = frame:GetPoint(1)
        PartyOffCD.db.panelPoint = point
        PartyOffCD.db.panelRelativePoint = relativePoint
        PartyOffCD.db.panelX = x
        PartyOffCD.db.panelY = y
    end)

    local bg = panel:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.03, 0.03, 0.03, 0.8)

    local borderTop = panel:CreateTexture(nil, "BORDER")
    borderTop:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    borderTop:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, 0)
    borderTop:SetHeight(1)
    borderTop:SetColorTexture(0.2, 0.7, 0.95, 0.7)

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -8)
    title:SetText("PartyOffCD Panel")

    local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -10, -10)
    hint:SetText("Drag")

    panel.buttons = {}

    local columns = 6
    for index, spellID in ipairs(PANEL_SPELLS) do
        local button = CreateFrame("Button", nil, panel)
        button:SetSize(32, 32)

        local row = math.floor((index - 1) / columns)
        local column = (index - 1) % columns
        button:SetPoint("TOPLEFT", panel, "TOPLEFT", 10 + (column * 37), -30 - (row * 37))

        button.texture = button:CreateTexture(nil, "ARTWORK")
        button.texture:SetAllPoints()
        button.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        local _, texture = SafeGetSpellInfo(spellID)
        button.texture:SetTexture(texture or 134400)

        button.spellID = spellID
        button:RegisterForClicks("LeftButtonUp")
        button:SetScript("OnClick", function(selfButton)
            PartyOffCD:ReportSpellUse(selfButton.spellID)
        end)

        button:SetScript("OnEnter", function(selfButton)
            GameTooltip:SetOwner(selfButton, "ANCHOR_RIGHT")
            local meta = PartyOffCD:GetDisplayMeta(selfButton.spellID) or SPELLS[selfButton.spellID]
            if meta then
                GameTooltip:SetSpellByID(selfButton.spellID)
                GameTooltip:AddLine("Click: reportar uso", 0.8, 0.8, 0.8)
                GameTooltip:AddLine("Clase: " .. PartyOffCD:GetClassLabel(meta.class), 0.8, 0.8, 0.8)
                GameTooltip:AddLine("Base CD: " .. meta.cd .. "s", 0.8, 0.8, 0.8)
                if not PartyOffCD:IsSpellEnabled(selfButton.spellID) then
                    GameTooltip:AddLine("Desactivado en configuracion", 1, 0.2, 0.2)
                end
                GameTooltip:Show()
            end
        end)

        button:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        panel.buttons[#panel.buttons + 1] = button
    end

    panel:Hide()

    local db = self.db or DB_DEFAULTS
    panel:SetPoint(db.panelPoint or DB_DEFAULTS.panelPoint, UIParent, db.panelRelativePoint or DB_DEFAULTS.panelRelativePoint, db.panelX or DB_DEFAULTS.panelX, db.panelY or DB_DEFAULTS.panelY)

    self.panel = panel
    self:RefreshPanelButtons()
end

function PartyOffCD:TogglePanel()
    self:CreatePanel()
    if self.panel:IsShown() then
        self.panel:Hide()
    else
        self.panel:Show()
    end
end

function PartyOffCD:CreateConfigPanel()
    if self.configPanel then
        return
    end

    local frame = CreateFrame("Frame", "PartyOffCDConfigPanel", UIParent)
    frame:SetSize(420, 470)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(selfFrame)
        selfFrame:StopMovingOrSizing()
        local point, _, relativePoint, x, y = selfFrame:GetPoint(1)
        PartyOffCD.db.configPoint = point
        PartyOffCD.db.configRelativePoint = relativePoint
        PartyOffCD.db.configX = x
        PartyOffCD.db.configY = y
    end)

    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.05, 0.05, 0.06, 0.92)

    local borderTop = frame:CreateTexture(nil, "BORDER")
    borderTop:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    borderTop:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    borderTop:SetHeight(2)
    borderTop:SetColorTexture(0.2, 0.7, 0.95, 0.9)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -10)
    title:SetText("PartyOffCD Configuration")

    local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -34)
    subtitle:SetText("Disable by class or by individual spell.")

    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)

    local quickPanelButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    quickPanelButton:SetSize(130, 22)
    quickPanelButton:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -58)
    quickPanelButton:SetText("Toggle Report Panel")
    quickPanelButton:SetScript("OnClick", function()
        PartyOffCD:TogglePanel()
    end)

    local instructions = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    instructions:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -86)
    instructions:SetText("Use + to add a spell to that class. Edit/Save changes your personal CD and syncs it automatically.")

    local scrollFrame = CreateFrame("ScrollFrame", "PartyOffCDConfigScrollFrame", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -110)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -32, 12)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(360, 1)
    scrollFrame:SetScrollChild(content)

    frame.scrollFrame = scrollFrame
    frame.content = content
    frame:Hide()

    local db = self.db or DB_DEFAULTS
    frame:SetPoint(db.configPoint or DB_DEFAULTS.configPoint, UIParent, db.configRelativePoint or DB_DEFAULTS.configRelativePoint, db.configX or DB_DEFAULTS.configX, db.configY or DB_DEFAULTS.configY)

    self.configPanel = frame
    self:RefreshConfigPanel()
end

function PartyOffCD:RefreshConfigPanel()
    if not self.configPanel then
        return
    end

    local frame = self.configPanel
    local content = frame.content

    for _, widget in ipairs(self.configRows) do
        widget:Hide()
        widget:SetParent(UIParent)
    end
    wipe(self.configRows)

    local y = -4

    for _, classToken in ipairs(CLASS_ORDER) do
        local spellList = {}
        for spellID, meta in pairs(SPELLS) do
            if meta.class == classToken then
                spellList[#spellList + 1] = spellID
            end
        end

        if #spellList > 0 then
            table.sort(spellList, function(a, b)
                local aName = SafeGetSpellInfo(a)
                local bName = SafeGetSpellInfo(b)
                aName = aName or tostring(a)
                bName = bName or tostring(b)
                return aName < bName
            end)

            local classCheck = CreateCheckbox(nil, content, "")
            classCheck:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
            classCheck:SetChecked(self.db.classEnabled[classToken] ~= false)
            classCheck:SetScript("OnClick", function(selfCheck)
                PartyOffCD:SetClassEnabled(classToken, selfCheck:GetChecked())
            end)
            self.configRows[#self.configRows + 1] = classCheck

            local header = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            header:SetPoint("LEFT", classCheck, "RIGHT", 6, 0)
            header:SetText(self:GetClassLabel(classToken))
            self.configRows[#self.configRows + 1] = header

            local addButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
            addButton:SetSize(22, 18)
            addButton:SetPoint("TOPLEFT", content, "TOPLEFT", 230, y + 1)
            addButton:SetText(self.classAddEditorState[classToken] and "-" or "+")
            addButton:SetScript("OnClick", function()
                PartyOffCD.classAddEditorState[classToken] = not PartyOffCD.classAddEditorState[classToken]
                PartyOffCD:RefreshConfigPanel()
            end)
            self.configRows[#self.configRows + 1] = addButton

            y = y - 26

            if self.classAddEditorState[classToken] then
                local spellIDBox = CreateNumericEditBox(nil, content, 52, 8)
                spellIDBox:SetPoint("TOPLEFT", content, "TOPLEFT", 20, y)
                spellIDBox:SetText("")
                self.configRows[#self.configRows + 1] = spellIDBox

                local spellIDLabel = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                spellIDLabel:SetPoint("LEFT", spellIDBox, "RIGHT", 4, 0)
                spellIDLabel:SetText("ID")
                self.configRows[#self.configRows + 1] = spellIDLabel

                local cdBox = CreateNumericEditBox(nil, content, 38, 5)
                cdBox:SetPoint("LEFT", spellIDLabel, "RIGHT", 10, 0)
                cdBox:SetText("90")
                self.configRows[#self.configRows + 1] = cdBox

                local cdLabel = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                cdLabel:SetPoint("LEFT", cdBox, "RIGHT", 4, 0)
                cdLabel:SetText("CD")
                self.configRows[#self.configRows + 1] = cdLabel

                local typeButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
                typeButton:SetSize(42, 18)
                typeButton:SetPoint("LEFT", cdLabel, "RIGHT", 10, 0)
                typeButton:SetText("OFF")
                typeButton.currentType = "OFF"
                typeButton:SetScript("OnClick", function(selfButton)
                    selfButton.currentType = GetNextSpellType(selfButton.currentType)
                    selfButton:SetText(selfButton.currentType)
                end)
                self.configRows[#self.configRows + 1] = typeButton

                local saveNewButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
                saveNewButton:SetSize(42, 18)
                saveNewButton:SetPoint("LEFT", typeButton, "RIGHT", 6, 0)
                saveNewButton:SetText("Save")
                saveNewButton:SetScript("OnClick", function()
                    if PartyOffCD:AddCustomSpell(classToken, spellIDBox:GetText(), cdBox:GetText(), typeButton.currentType) then
                        PartyOffCD.classAddEditorState[classToken] = false
                        PartyOffCD:RefreshConfigPanel()
                    end
                end)
                self.configRows[#self.configRows + 1] = saveNewButton

                y = y - 24
            end

            for _, spellID in ipairs(spellList) do
                local spellName, texture = SafeGetSpellInfo(spellID)
                local meta = self:GetDisplayMeta(spellID) or SPELLS[spellID]

                local spellCheck = CreateCheckbox(nil, content, "")
                spellCheck:SetPoint("TOPLEFT", content, "TOPLEFT", 16, y)
                spellCheck:SetChecked(self:IsSpellEnabled(spellID))
                spellCheck:SetEnabled(self.db.classEnabled[classToken] ~= false)
                spellCheck:SetScript("OnClick", function(selfCheck)
                    PartyOffCD:SetSpellEnabled(spellID, selfCheck:GetChecked())
                end)
                self.configRows[#self.configRows + 1] = spellCheck

                local icon = content:CreateTexture(nil, "ARTWORK")
                icon:SetSize(18, 18)
                icon:SetPoint("LEFT", spellCheck, "RIGHT", 2, 0)
                icon:SetTexture(texture or 134400)
                self.configRows[#self.configRows + 1] = icon

                local label = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                label:SetPoint("LEFT", icon, "RIGHT", 6, 0)
                local playerOverride = self:GetPlayerOverride(spellID, self:GetPlayerCanonical())
                local customSuffix = meta.custom and ", custom" or ""
                local overrideSuffix = playerOverride and ", override" or ""
                label:SetWidth(155)
                label:SetJustifyH("LEFT")
                label:SetText(string.format("%s (%ss, id %d%s%s)", spellName or ("Spell " .. spellID), meta.cd, spellID, customSuffix, overrideSuffix))
                if self.db.classEnabled[classToken] == false then
                    label:SetTextColor(0.55, 0.55, 0.55)
                else
                    label:SetTextColor(0.9, 0.9, 0.9)
                end
                self.configRows[#self.configRows + 1] = label

                local editButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
                editButton:SetSize(40, 18)
                editButton:SetPoint("TOPLEFT", content, "TOPLEFT", 215, y + 1)
                editButton:SetText("Edit")
                self.configRows[#self.configRows + 1] = editButton

                local editBox = CreateNumericEditBox(nil, content, 34, 5)
                editBox:SetPoint("TOPLEFT", content, "TOPLEFT", 259, y)
                editBox:SetText(tostring(meta.cd))
                editBox:Hide()
                self.configRows[#self.configRows + 1] = editBox

                local saveButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
                saveButton:SetSize(42, 18)
                saveButton:SetPoint("TOPLEFT", content, "TOPLEFT", 299, y + 1)
                saveButton:SetText("Save")
                saveButton:Hide()
                self.configRows[#self.configRows + 1] = saveButton

                editButton:SetScript("OnClick", function()
                    editBox:SetText(tostring((PartyOffCD:GetDisplayMeta(spellID) or meta).cd))
                    editBox:Show()
                    saveButton:Show()
                end)

                saveButton:SetScript("OnClick", function()
                    local newCooldown = tonumber(editBox:GetText())
                    if not newCooldown or newCooldown <= 0 then
                        DebugPrint("Ingresa un CD valido en segundos.")
                        return
                    end

                    if PartyOffCD:AddCustomSpell(meta.class, spellID, newCooldown, meta.type) then
                        editBox:Hide()
                        saveButton:Hide()
                    end
                end)

                y = y - 22
            end

            y = y - 8
        end
    end

    content:SetHeight(math.max(1, -y + 8))
end

function PartyOffCD:ToggleConfigPanel()
    self:CreateConfigPanel()
    if self.configPanel:IsShown() then
        self.configPanel:Hide()
    else
        self:RefreshConfigPanel()
        self.configPanel:Show()
    end
end

function PartyOffCD:UpdateMinimapButtonPosition()
    if not self.minimapButton then
        return
    end

    local angle = self.db.minimap.angle or 220
    local radians = math.rad(angle)
    local x = math.cos(radians) * MINIMAP_RADIUS
    local y = math.sin(radians) * MINIMAP_RADIUS
    self.minimapButton:ClearAllPoints()
    self.minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

function PartyOffCD:RefreshMinimapButton()
    if not self.minimapButton then
        return
    end

    self.minimapButton:Show()
    self:UpdateMinimapButtonPosition()
end

function PartyOffCD:CreateMinimapButton()
    if self.minimapButton then
        return
    end

    local button = CreateFrame("Button", "PartyOffCDMinimapButton", Minimap)
    button:SetSize(30, 30)
    button:SetFrameStrata("MEDIUM")
    button:SetMovable(true)
    button:EnableMouse(true)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")

    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.05, 0.05, 0.05, 0.85)
    button.bg = bg

    local border = button:CreateTexture(nil, "BORDER")
    border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    border:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
    border:SetHeight(1)
    border:SetColorTexture(0.95, 0.82, 0.2, 0.95)
    button.border = border

    local texture = button:CreateTexture(nil, "ARTWORK")
    texture:SetSize(18, 18)
    texture:SetPoint("CENTER", button, "CENTER", 0, 0)
    texture:SetTexture(136116)
    button.icon = texture

    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then
            PartyOffCD:TogglePanel()
        else
            PartyOffCD:ToggleConfigPanel()
        end
    end)

    button:SetScript("OnDragStart", function()
        button.isDragging = true
    end)

    button:SetScript("OnDragStop", function()
        button.isDragging = false
    end)

    button:SetScript("OnUpdate", function(selfButton)
        if not selfButton.isDragging then
            return
        end

        local mx, my = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        local cx, cy = Minimap:GetCenter()
        local dx = (mx / scale) - cx
        local dy = (my / scale) - cy
        local angle = math.deg(math.atan2(dy, dx))
        PartyOffCD.db.minimap.angle = angle
        PartyOffCD:UpdateMinimapButtonPosition()
    end)

    button:SetScript("OnEnter", function(selfButton)
        GameTooltip:SetOwner(selfButton, "ANCHOR_LEFT")
        GameTooltip:AddLine("PartyOffCD")
        GameTooltip:AddLine("Left Click: configuracion", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Right Click: report panel", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Drag: mover icono", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    self.minimapButton = button
    self:RefreshMinimapButton()
end

function PartyOffCD:RunTest()
    local samples = { 31884, 97462, 190319 }
    for _, spellID in ipairs(samples) do
        if self:IsSpellEnabled(spellID) then
            self:ReportSpellUse(spellID, true)
        end
    end
    DebugPrint("Test disparado con timers locales de ejemplo.")
end

function PartyOffCD:PrintConfig()
    local channel = self:GetTargetChannel() or "NONE"
    local inGroup = (IsInGroup() or IsInRaid()) and "yes" or "no"
    local panelShown = (self.panel and self.panel:IsShown()) and "shown" or "hidden"
    local configShown = (self.configPanel and self.configPanel:IsShown()) and "shown" or "hidden"
    local minimapShown = "shown"

    DebugPrint("Prefix: " .. PREFIX .. " | Channel: " .. channel .. " | InGroup: " .. inGroup)
    DebugPrint("Spells activos: " .. tostring(self:GetEnabledSpellCount()) .. "/" .. tostring(self:GetSupportedSpellCount()))
    DebugPrint("Panel: " .. panelShown .. " | Config: " .. configShown .. " | Minimap: " .. minimapShown)
    DebugPrint("Comandos: /pocd use <spellID>, /pocd timer <spellID> <seg>, /pocd test, /pocd panel, /pocd config")
    DebugPrint("UI: Usa + por clase para agregar spells, y Edit/Save por fila para guardar tu CD personal.")
end

function PartyOffCD:GetSupportedSpellCount()
    local count = 0
    for _ in pairs(SPELLS) do
        count = count + 1
    end
    return count
end

function PartyOffCD:GetEnabledSpellCount()
    local count = 0
    for spellID in pairs(SPELLS) do
        if self:IsSpellEnabled(spellID) then
            count = count + 1
        end
    end
    return count
end

function PartyOffCD:HandleSlashCommand(input)
    local command, rest = strsplit(" ", (input or ""), 2)
    command = string.lower(command or "")
    rest = rest and strtrim(rest) or ""

    if command == "use" then
        local spellID = tonumber(rest)
        if not spellID then
            DebugPrint("Uso: /pocd use <spellID>")
            return
        end

        self:ReportSpellUse(spellID)
        return
    end

    if command == "test" then
        self:RunTest()
        return
    end

    if command == "timer" then
        local spellIDText, remainingText = strsplit(" ", rest, 2)
        local spellID = tonumber(spellIDText)
        local remaining = tonumber(remainingText)
        if not spellID or remaining == nil then
            DebugPrint("Uso: /pocd timer <spellID> <segundosRestantes>")
            return
        end

        local playerKey = self:GetPlayerCanonical()
        if not playerKey then
            DebugPrint("No se pudo identificar tu personaje.")
            return
        end

        if not self:SetRemainingCooldown(playerKey, spellID, remaining) then
            DebugPrint("No se pudo ajustar ese timer.")
        end
        return
    end

    if command == "panel" then
        self:TogglePanel()
        return
    end

    if command == "config" or command == "" then
        self:PrintConfig()
        self:ToggleConfigPanel()
        return
    end

    DebugPrint("Comando desconocido: " .. tostring(command))
    self:PrintConfig()
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

function PartyOffCD:Initialize()
    self:BuildRoster()
    self:InitializeDB()

    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
    else
        DebugPrint("C_ChatInfo no disponible; el tracking de red no funcionara.")
    end

    self:CreateTrackerFrame()
    self:CreateInterruptFrame()
    self:CreatePanel()
    self:CreateConfigPanel()
    self:CreateMinimapButton()

    if not self.trackerTicker then
        self.trackerTicker = C_Timer.NewTicker(UPDATE_INTERVAL, function()
            PartyOffCD:SyncLocalRealCooldowns()
            PartyOffCD:RefreshTracker()
        end)
    end

    SLASH_PARTYOFFCD1 = "/pocd"
    SlashCmdList.PARTYOFFCD = function(msg)
        PartyOffCD:HandleSlashCommand(msg)
    end

    self:RegisterEvent("GROUP_ROSTER_UPDATE")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("CHAT_MSG_ADDON")
    self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")

    self:RefreshPanelButtons()
    self:RefreshConfigPanel()
    self:RefreshMinimapButton()
    self:RequestGroupOverrides()
    self:BroadcastLocalOverrides(true)
    self:RefreshTracker()
    DebugPrint("Cargado. Usa /pocd config o click izquierdo en el minimapa.")
end

PartyOffCD:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        PartyOffCD:Initialize()
        return
    end

    if event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
        PartyOffCD:BuildRoster()
        PartyOffCD:RequestGroupOverrides()
        PartyOffCD:BroadcastLocalOverrides()
        PartyOffCD:RefreshTracker()
        return
    end

    if event == "CHAT_MSG_ADDON" then
        PartyOffCD:HandleAddonMessage(...)
        return
    end

    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, _, spellID = ...
        if unit == "player" then
            PartyOffCD:HandleLocalSpellcastSucceeded(spellID)
        end
    end
end)

PartyOffCD:RegisterEvent("PLAYER_LOGIN")

--[[
PartyOffCD notes:

1) How to extend the spell table
   Add a new entry to SPELLS using:
   [spellID] = { cd = <seconds>, type = "OFF" / "DEF" / "INT", class = "<CLASS_TOKEN>" }
   Example:
   [31884] = { cd = 120, type = "OFF", class = "PALADIN" }
   Optional spec filter:
   specs = { "FROST" } or specs = { "ARMS", "FURY" }
   If you want the spell on the clickable panel, also add its spellID to PANEL_SPELLS.
   New spells appear automatically in the config panel under their class.
   The config panel can also overwrite existing base spells with your own CD/type/class values.
   Overrides are stored per character and are broadcast to party members automatically.

2) Midnight limitations
   This addon does not read the real cooldown state.
   It only tracks base timers from local author-reports plus addon comms.
   Talents, resets, cooldown reduction, encounter modifiers, spec changes, and failed casts
   can make timers inaccurate. This is expected by design for the MVP.

3) Slash examples
   /pocd use 31884
   /pocd timer 31884 45
   /pocd use 97462
   /pocd use 190319
   /pocd test
   /pocd panel
   /pocd config

4) Minimap and config
   Left click the minimap button opens the config panel.
   Right click the minimap button opens the quick report panel.
   Drag the minimap button to move it around the minimap.
   The minimap icon is always enabled.
   Each class row has a + button to add a new spell to that class.
   Pick SpellID, CD, choose OFF/DEF/INT, then Save.
   Custom spells are stored per character and synced to the group.
   Each spell row has an Edit button.
   Click Edit, type your personal CD in seconds, then click Save.
   Save stores it in your per-character SavedVariables and syncs it to the group.
   When a party member sends an override, you will see a short notification.

5) Manual timer adjustment
   Use /pocd timer <spellID> <remainingSeconds> to correct an active timer.
   Example: /pocd timer 31884 45
   This updates your own running timer and notifies the group.
   The addon also requests and rebroadcasts custom overrides whenever you join or change group.
   The tracker now always shows all enabled spells; use the checkboxes to hide spells you do not want to see.
]]
