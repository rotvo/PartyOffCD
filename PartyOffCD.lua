local ADDON_NAME = ...

local PartyOffCD = CreateFrame("Frame")
_G.PartyOffCD = PartyOffCD

local PREFIX = "POCD"
local MESSAGE_VERSION = "v1"
local DUPLICATE_WINDOW = 1.5
local UPDATE_INTERVAL = 0.2
local MAX_TRACKED_ROWS = 5
local ICON_SIZE = 30
local ICON_SPACING = 3
local FALLBACK_X = 210
local FALLBACK_Y = 120
local MINIMAP_RADIUS = 96

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

local SPELLS = {
    [31884] = { cd = 120, type = "OFF", class = "PALADIN" }, -- Avenging Wrath
    [216331] = { cd = 120, type = "OFF", class = "PALADIN" }, -- Avenging Crusader
    [642] = { cd = 240, type = "DEF", class = "PALADIN" }, -- Divine Shield
    [6940] = { cd = 120, type = "DEF", class = "PALADIN" }, -- Blessing of Sacrifice
    [31850] = { cd = 120, type = "DEF", class = "PALADIN" }, -- Ardent Defender
    [31821] = { cd = 180, type = "DEF", class = "PALADIN" }, -- Aura Mastery
    [375087] = { cd = 120, type = "OFF", class = "EVOKER" }, -- Dragonrage
    [370553] = { cd = 120, type = "OFF", class = "EVOKER" }, -- Tip the Scales
    [357210] = { cd = 120, type = "OFF", class = "EVOKER" }, -- Deep Breath
    [363916] = { cd = 90, type = "DEF", class = "EVOKER" }, -- Obsidian Scales
    [374227] = { cd = 90, type = "DEF", class = "EVOKER" }, -- Zephyr
    [190319] = { cd = 120, type = "OFF", class = "MAGE" }, -- Combustion
    [12042] = { cd = 90, type = "OFF", class = "MAGE" }, -- Arcane Power
    [12472] = { cd = 180, type = "OFF", class = "MAGE" }, -- Icy Veins
    [55342] = { cd = 120, type = "OFF", class = "MAGE" }, -- Mirror Image
    [45438] = { cd = 240, type = "DEF", class = "MAGE" }, -- Ice Block
    [10060] = { cd = 120, type = "OFF", class = "PRIEST" }, -- Power Infusion
    [228260] = { cd = 90, type = "OFF", class = "PRIEST" }, -- Void Eruption
    [200183] = { cd = 120, type = "OFF", class = "PRIEST" }, -- Apotheosis
    [47585] = { cd = 120, type = "DEF", class = "PRIEST" }, -- Dispersion
    [33206] = { cd = 180, type = "DEF", class = "PRIEST" }, -- Pain Suppression
    [47788] = { cd = 180, type = "DEF", class = "PRIEST" }, -- Guardian Spirit
    [19236] = { cd = 90, type = "DEF", class = "PRIEST" }, -- Desperate Prayer
    [13750] = { cd = 180, type = "OFF", class = "ROGUE" }, -- Adrenaline Rush
    [121471] = { cd = 180, type = "OFF", class = "ROGUE" }, -- Shadow Blades
    [31224] = { cd = 120, type = "DEF", class = "ROGUE" }, -- Cloak of Shadows
    [5277] = { cd = 120, type = "DEF", class = "ROGUE" }, -- Evasion
    [19574] = { cd = 90, type = "OFF", class = "HUNTER" }, -- Bestial Wrath
    [288613] = { cd = 120, type = "OFF", class = "HUNTER" }, -- Trueshot
    [266779] = { cd = 120, type = "OFF", class = "HUNTER" }, -- Coordinated Assault
    [186265] = { cd = 180, type = "DEF", class = "HUNTER" }, -- Aspect of the Turtle
    [109304] = { cd = 120, type = "DEF", class = "HUNTER" }, -- Exhilaration
    [191634] = { cd = 60, type = "OFF", class = "SHAMAN" }, -- Stormkeeper
    [321530] = { cd = 300, type = "OFF", class = "SHAMAN" }, -- Bloodlust
    [114050] = { cd = 180, type = "OFF", class = "SHAMAN" }, -- Ascendance
    [198067] = { cd = 150, type = "OFF", class = "SHAMAN" }, -- Fire Elemental
    [108271] = { cd = 90, type = "DEF", class = "SHAMAN" }, -- Astral Shift
    [115080] = { cd = 120, type = "OFF", class = "MONK" }, -- Touch of Death
    [137639] = { cd = 90, type = "OFF", class = "MONK" }, -- Storm, Earth, and Fire
    [123904] = { cd = 120, type = "OFF", class = "MONK" }, -- Invoke Xuen, the White Tiger
    [115203] = { cd = 180, type = "DEF", class = "MONK" }, -- Fortifying Brew
    [122783] = { cd = 90, type = "DEF", class = "MONK" }, -- Diffuse Magic
    [122278] = { cd = 120, type = "DEF", class = "MONK" }, -- Dampen Harm
    [1122] = { cd = 180, type = "OFF", class = "WARLOCK" }, -- Summon Infernal
    [205180] = { cd = 120, type = "OFF", class = "WARLOCK" }, -- Summon Darkglare
    [113860] = { cd = 120, type = "OFF", class = "WARLOCK" }, -- Dark Soul: Misery
    [265187] = { cd = 120, type = "OFF", class = "WARLOCK" }, -- Dark Soul: Summon demonic Tyrant
    [1276672] = { cd = 120, type = "OFF", class = "WARLOCK" }, -- Dark Soul: Summon Doomguard
    [108416] = { cd = 60, type = "DEF", class = "WARLOCK" }, -- Dark Pact
    [104773] = { cd = 180, type = "DEF", class = "WARLOCK" }, -- Unending Resolve
    [97462] = { cd = 180, type = "DEF", class = "WARRIOR" }, -- Rallying Cry
    [871] = { cd = 240, type = "DEF", class = "WARRIOR" }, -- Shield Wall
    [118038] = { cd = 120, type = "DEF", class = "WARRIOR" }, -- Die by the Sword
    [1719] = { cd = 90, type = "OFF", class = "WARRIOR" }, -- Recklessness
    [107574] = { cd = 90, type = "OFF", class = "WARRIOR" }, -- Avatar
    [22812] = { cd = 60, type = "DEF", class = "DRUID" }, -- Barkskin
    [61336] = { cd = 180, type = "DEF", class = "DRUID" }, -- Survival Instincts
    [102342] = { cd = 90, type = "DEF", class = "DRUID" }, -- Ironbark
    [106951] = { cd = 180, type = "OFF", class = "DRUID" }, -- Berserk
    [194223] = { cd = 180, type = "OFF", class = "DRUID" }, -- Celestial Alignment
    [22842] = { cd = 36, type = "DEF", class = "DRUID" }, -- Frenzied Regeneration
    [48792] = { cd = 180, type = "DEF", class = "DEATHKNIGHT" }, -- Icebound Fortitude
    [48707] = { cd = 60, type = "DEF", class = "DEATHKNIGHT" }, -- Anti-Magic Shell
    [51271] = { cd = 60, type = "OFF", class = "DEATHKNIGHT" }, -- Pillar of Frost
    [47568] = { cd = 120, type = "OFF", class = "DEATHKNIGHT" }, -- Empower Rune Weapon
    [315443] = { cd = 120, type = "OFF", class = "DEATHKNIGHT" }, -- Abomination Limb
    [1233448] = { cd = 45, type = "OFF", class = "DEATHKNIGHT" }, -- User provided Midnight DK CD
    [42650] = { cd = 90, type = "OFF", class = "DEATHKNIGHT" }, -- Army of the Dead
    [196555] = { cd = 120, type = "DEF", class = "DEMONHUNTER" }, -- Netherwalk
    [191427] = { cd = 180, type = "OFF", class = "DEMONHUNTER" }, -- Metamorphosis
    [198589] = { cd = 60, type = "DEF", class = "DEMONHUNTER" }, -- Blur
    [196718] = { cd = 300, type = "DEF", class = "DEMONHUNTER" }, -- Darkness
}

local BASE_SPELLS = {}
for spellID, meta in pairs(SPELLS) do
    BASE_SPELLS[spellID] = {
        cd = meta.cd,
        type = meta.type,
        class = meta.class,
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
PartyOffCD.lastOverrideBroadcast = 0

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

function PartyOffCD:EncodeUseMessage(spellID, timestamp)
    return table.concat({
        MESSAGE_VERSION,
        "U",
        tostring(spellID),
        string.format("%.2f", timestamp or GetTime()),
    }, ";")
end

function PartyOffCD:EncodeSyncMessage(spellID, cooldown, spellType, classToken)
    return table.concat({
        MESSAGE_VERSION,
        "S",
        tostring(spellID),
        tostring(cooldown),
        tostring(spellType),
        tostring(classToken),
    }, ";")
end

function PartyOffCD:EncodeTimerAdjustMessage(spellID, remaining)
    return table.concat({
        MESSAGE_VERSION,
        "R",
        tostring(spellID),
        tostring(remaining),
    }, ";")
end

function PartyOffCD:DecodeMessage(message)
    if type(message) ~= "string" or message == "" then
        return nil
    end

    local version, action, a, b, c, d = strsplit(";", message)
    if version ~= MESSAGE_VERSION then
        return nil
    end

    if action == "U" then
        local spellID = tonumber(a)
        local senderTime = tonumber(b)
        if not spellID then
            return nil
        end

        return action, spellID, senderTime
    end

    if action == "S" then
        local spellID = tonumber(a)
        local cooldown = tonumber(b)
        local spellType = c
        local classToken = d
        if not spellID or not cooldown or cooldown <= 0 then
            return nil
        end

        return action, spellID, cooldown, spellType, classToken
    end

    if action == "R" then
        local spellID = tonumber(a)
        local remaining = tonumber(b)
        if not spellID or remaining == nil then
            return nil
        end

        return action, spellID, remaining
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

    local message = self:EncodeSyncMessage(spellID, meta.cd, meta.type, meta.class)
    C_ChatInfo.SendAddonMessage(PREFIX, message, channel)
    return true
end

function PartyOffCD:SendTimerAdjustMessage(spellID, remaining)
    local channel = self:GetTargetChannel()
    if not channel then
        return false
    end

    local message = self:EncodeTimerAdjustMessage(spellID, remaining)
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

function PartyOffCD:NotifyTimerAdjusted(sender, spellID, remaining)
    local spellName = SafeGetSpellInfo(spellID) or ("Spell " .. tostring(spellID))
    local senderName = Ambiguate and Ambiguate(sender or "?", "short") or (sender or "?")
    local message = string.format("%s ajusto %s a %ss restantes", senderName, spellName, tostring(remaining))
    DebugPrint(message)

    if UIErrorsFrame and UIErrorsFrame.AddMessage then
        UIErrorsFrame:AddMessage(message, 0.3, 0.9, 1, 1.5)
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

    if spellType ~= "OFF" and spellType ~= "DEF" then
        DebugPrint("Tipo invalido. Usa OFF o DEF.")
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

function PartyOffCD:SendUseMessage(spellID)
    local channel = self:GetTargetChannel()
    if not channel then
        return false
    end

    local message = self:EncodeUseMessage(spellID, GetTime())
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

    local action, spellID, valueA, valueB, valueC = self:DecodeMessage(message)
    if not action or not spellID then
        return
    end

    local senderKey = self:ResolveSenderKey(sender)
    if not senderKey then
        return
    end

    if action == "U" then
        local senderTime = valueA
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

        if spellType ~= "OFF" and spellType ~= "DEF" then
            return
        end

        if not CLASS_LABELS[classToken] then
            return
        end

        local bucket = self:GetOverrideBucket(senderKey, true)
        bucket[spellID] = {
            cd = cooldown,
            type = spellType,
            class = classToken,
            custom = not BASE_SPELLS[spellID],
        }

        if not SPELLS[spellID] then
            SPELLS[spellID] = {
                cd = cooldown,
                type = spellType,
                class = classToken,
                custom = true,
            }
        end

        self:NotifyOverrideReceived(sender, spellID, bucket[spellID])
        self:RefreshConfigPanel()
        self:RefreshTracker()
        return
    end

    if action == "R" then
        local remaining = valueA
        local meta = self:GetEffectiveMeta(senderKey, spellID)
        if not meta or not self:IsSpellEnabled(spellID) then
            return
        end

        self:SetRemainingCooldown(senderKey, spellID, remaining, true)
        self:NotifyTimerAdjusted(sender, spellID, remaining)
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

            if fullName and shortName then
                local entry = {
                    unit = unit,
                    name = shortName,
                    fullName = fullName,
                    key = NormalizeName(fullName),
                    shortKey = NormalizeName(shortName),
                }

                self.roster[#self.roster + 1] = entry

                if entry.key then
                    self.rosterLookup[entry.key] = entry
                end

                if entry.shortKey and not self.rosterLookup[entry.shortKey] then
                    self.rosterLookup[entry.shortKey] = entry
                end
            end
        end
    end

    local playerFull = GetUnitFullName("player")
    local playerShort = UnitName("player")
    self.playerKeys.full = NormalizeName(playerFull)
    self.playerKeys.short = NormalizeName(playerShort)
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

    icon.border = icon:CreateTexture(nil, "OVERLAY")
    icon.border:SetAllPoints()
    icon.border:SetColorTexture(0, 0, 0, 0.45)

    icon.cooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
    icon.cooldown:SetAllPoints()
    if icon.cooldown.SetDrawBling then
        icon.cooldown:SetDrawBling(false)
    end
    if icon.cooldown.SetHideCountdownNumbers then
        icon.cooldown:SetHideCountdownNumbers(true)
    end

    icon.timeText = icon:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    icon.timeText:SetPoint("BOTTOM", icon, "BOTTOM", 0, 2)
    icon.timeText:SetShadowOffset(1, -1)

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

function PartyOffCD:GetSortedCooldowns(senderKey)
    local senderCooldowns = self.cooldowns[senderKey]
    if not senderCooldowns then
        return nil
    end

    local now = GetTime()
    local entries = {}

    for spellID, cooldownData in pairs(senderCooldowns) do
        local endTime = type(cooldownData) == "table" and cooldownData.endTime or cooldownData
        local duration = type(cooldownData) == "table" and cooldownData.duration or nil
        local remaining = endTime - now
        if remaining > 0 and self:IsSpellEnabled(spellID) then
            local meta = self:GetEffectiveMeta(senderKey, spellID)
            if meta then
                entries[#entries + 1] = {
                    spellID = spellID,
                    endTime = endTime,
                    remaining = remaining,
                    meta = meta,
                    duration = duration or meta.cd,
                }
            end
        end
    end

    table.sort(entries, function(a, b)
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

    for iconIndex, entry in ipairs(entries) do
        local icon = self:AcquireIcon(row)
        local _, texture = SafeGetSpellInfo(entry.spellID)

        icon.spellID = entry.spellID
        icon.baseCD = entry.meta.cd
        icon.texture:SetTexture(texture or 134400)
        icon.timeText:SetText(FormatRemaining(entry.remaining))
        icon.typeText:SetText("")
        icon.cooldown:SetCooldown(entry.endTime - entry.duration, entry.duration)
        if iconIndex == 1 then
            icon:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        else
            icon:SetPoint("RIGHT", row.icons[iconIndex - 1], "LEFT", -ICON_SPACING, 0)
        end

        row.icons[iconIndex] = icon
    end
end

function PartyOffCD:RefreshTracker()
    self:PruneState()

    if not IsInGroup() and not IsInRaid() then
        if self.trackerFrame then
            self.trackerFrame:Hide()
        end

        for _, row in ipairs(self.rows) do
            self:ReleaseRowIcons(row)
            row:Hide()
        end
        return
    end

    self:BuildRoster()

    if #self.roster == 0 then
        if self.trackerFrame then
            self.trackerFrame:Hide()
        end
        return
    end

    self:CreateTrackerFrame()
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

        local overlay = button:CreateTexture(nil, "OVERLAY")
        overlay:SetAllPoints()
        overlay:SetColorTexture(0, 0, 0, 0.2)

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
    instructions:SetText("Class toggle disables the whole class. Spell toggle is per spell. Minimap icon is always on.")

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

            y = y - 26

            local spellIDBox = CreateNumericEditBox(nil, content, 54, 8)
            spellIDBox:SetPoint("TOPLEFT", content, "TOPLEFT", 20, y)
            spellIDBox:SetText("")
            self.configRows[#self.configRows + 1] = spellIDBox

            local spellIDLabel = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            spellIDLabel:SetPoint("LEFT", spellIDBox, "RIGHT", 4, 0)
            spellIDLabel:SetText("ID")
            self.configRows[#self.configRows + 1] = spellIDLabel

            local cdBox = CreateNumericEditBox(nil, content, 42, 5)
            cdBox:SetPoint("LEFT", spellIDLabel, "RIGHT", 10, 0)
            cdBox:SetText("90")
            self.configRows[#self.configRows + 1] = cdBox

            local cdLabel = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            cdLabel:SetPoint("LEFT", cdBox, "RIGHT", 4, 0)
            cdLabel:SetText("CD")
            self.configRows[#self.configRows + 1] = cdLabel

            local addOffButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
            addOffButton:SetSize(62, 20)
            addOffButton:SetPoint("LEFT", cdLabel, "RIGHT", 10, 0)
            addOffButton:SetText("Sync OFF")
            addOffButton:SetScript("OnClick", function()
                PartyOffCD:AddCustomSpell(classToken, spellIDBox:GetText(), cdBox:GetText(), "OFF")
            end)
            self.configRows[#self.configRows + 1] = addOffButton

            local addDefButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
            addDefButton:SetSize(62, 20)
            addDefButton:SetPoint("LEFT", addOffButton, "RIGHT", 4, 0)
            addDefButton:SetText("Sync DEF")
            addDefButton:SetScript("OnClick", function()
                PartyOffCD:AddCustomSpell(classToken, spellIDBox:GetText(), cdBox:GetText(), "DEF")
            end)
            self.configRows[#self.configRows + 1] = addDefButton

            y = y - 26

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
                label:SetText(string.format("%s (%s, %ss, id %d%s%s)", spellName or ("Spell " .. spellID), meta.type, meta.cd, spellID, customSuffix, overrideSuffix))
                if self.db.classEnabled[classToken] == false then
                    label:SetTextColor(0.55, 0.55, 0.55)
                else
                    label:SetTextColor(0.9, 0.9, 0.9)
                end
                self.configRows[#self.configRows + 1] = label

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
    self:CreatePanel()
    self:CreateConfigPanel()
    self:CreateMinimapButton()

    if not self.trackerTicker then
        self.trackerTicker = C_Timer.NewTicker(UPDATE_INTERVAL, function()
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

    self:RefreshPanelButtons()
    self:RefreshConfigPanel()
    self:RefreshMinimapButton()
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
        PartyOffCD:BroadcastLocalOverrides()
        PartyOffCD:RefreshTracker()
        return
    end

    if event == "CHAT_MSG_ADDON" then
        PartyOffCD:HandleAddonMessage(...)
    end
end)

PartyOffCD:RegisterEvent("PLAYER_LOGIN")

--[[
PartyOffCD notes:

1) How to extend the spell table
   Add a new entry to SPELLS using:
   [spellID] = { cd = <seconds>, type = "OFF" or "DEF", class = "<CLASS_TOKEN>" }
   Example:
   [31884] = { cd = 120, type = "OFF", class = "PALADIN" }
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
   Each class section includes boxes to add or overwrite a spell:
   enter SpellID, enter base CD in seconds, then click Sync OFF or Sync DEF.
   When a party member sends an override, you will see a short notification.

5) Manual timer adjustment
   Use /pocd timer <spellID> <remainingSeconds> to correct an active timer.
   Example: /pocd timer 31884 45
   This updates your own running timer and notifies the group.
]]
