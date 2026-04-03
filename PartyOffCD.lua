local ADDON_NAME, PartyOffCDCore = ...
PartyOffCDCore = PartyOffCDCore or _G.PartyOffCDCore or {}
_G.PartyOffCDCore = PartyOffCDCore

local PartyOffCD = CreateFrame("Frame")
_G.PartyOffCD = PartyOffCD

local PREFIX = "POCD"
local MESSAGE_VERSION = "v1"
local DUPLICATE_WINDOW = 1.5
local UPDATE_INTERVAL = 0.2
local REAL_SYNC_INTERVAL = 2.0
local REAL_SYNC_THRESHOLD = 0.5
local MAX_TRACKED_ROWS = 5
local MAX_TRACKER_COLUMNS = 8
local MAX_VERTICAL_TRACKER_COLUMNS = 4
local MIN_TRACKER_ICON_SCALE = 10
local MAX_TRACKER_ICON_SCALE = 200
local ICON_SIZE = 30
local ICON_SPACING = 3
local INTERRUPT_BAR_WIDTH = 190
local INTERRUPT_ROW_HEIGHT = 22
local INTERRUPT_ICON_SIZE = 18
local FALLBACK_X = 210
local FALLBACK_Y = 120
local MINIMAP_RADIUS = 96
-- Interrupts still need cast/combat-log tracking because they do not produce a tracked aura.
local COMBAT_LOG_TRACKED_SUBEVENTS = {
    SPELL_CAST_SUCCESS = true,
    SPELL_INTERRUPT = true,
}

local SPELL_TYPES = { "OFF", "DEF", "INT" }
local DB_DEFAULTS = assert(
    PartyOffCDCore and PartyOffCDCore.DEFAULTS,
    "PartyOffCD: missing core defaults (Core.lua was not loaded)."
)

PartyOffCD.cooldowns = {}
PartyOffCD.duplicateCache = {}
PartyOffCD.roster = {}
PartyOffCD.rosterLookup = {}
PartyOffCD.rosterGuidLookup = {}
PartyOffCD.rows = {}
PartyOffCD.iconPool = {}
PartyOffCD.playerKeys = {}
PartyOffCD.db = nil
PartyOffCD.trackerTicker = nil
PartyOffCD.configRows = {}
PartyOffCD.classAddEditorState = {}
PartyOffCD.interruptRows = {}
PartyOffCD.missingBuffIconPool = {}
PartyOffCD.missingBuffIcons = {}
PartyOffCD.lastOverrideBroadcast = 0
PartyOffCD.lastRealtimeSync = 0
PartyOffCD.senderSpecIDs = {}
PartyOffCD.addonUsers = {}
PartyOffCD.partyCastFrames = {}
PartyOffCD.specInspectorBound = false
PartyOffCD.talentTrackerBound = false
PartyOffCD.cooldownAlerts = {}
PartyOffCD.specInspectorInitialized = false
PartyOffCD.observedAuraState = {}

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

local function TrySafeNumber(value)
    if value == nil then
        return nil
    end

    local ok, parsed = pcall(function()
        return tonumber(tostring(value))
    end)
    if ok and type(parsed) == "number" then
        return parsed
    end

    return nil
end

local function IsSecretValue(value)
    return type(issecretvalue) == "function" and issecretvalue(value)
end

local function NormalizeSpellID(value)
    if value == nil or IsSecretValue(value) then
        return nil
    end

    local spellID = tonumber(value)
    if type(spellID) ~= "number" or spellID <= 0 then
        return nil
    end

    return spellID
end

local function SafeGetSpellCooldown(spellID)
    if C_Spell and C_Spell.GetSpellCooldown then
        local info = C_Spell.GetSpellCooldown(spellID)
        if info then
            return info.startTime, info.duration, true
        end
    end

    local startTime, duration, enabled = GetSpellCooldown(spellID)
    return startTime, duration, enabled ~= 0
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

    local talentTracker = PartyOffCDCore and PartyOffCDCore.TalentTracker
    if talentTracker and talentTracker.GetUnitSpecID then
        local trackedSpecID = talentTracker:GetUnitSpecID(unit)
        if trackedSpecID and trackedSpecID > 0 then
            return trackedSpecID
        end
    end

    local specInspector = PartyOffCDCore and PartyOffCDCore.SpecInspector
    if specInspector and specInspector.GetUnitSpecID then
        local inspectSpecID = specInspector:GetUnitSpecID(unit)
        if inspectSpecID and inspectSpecID > 0 then
            return inspectSpecID
        end
    end

    if GetInspectSpecialization then
        local inspectSpecID = GetInspectSpecialization(unit)
        if inspectSpecID and inspectSpecID > 0 then
            return inspectSpecID
        end
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

PartyOffCDCore.PREFIX = PREFIX
PartyOffCDCore.MESSAGE_VERSION = MESSAGE_VERSION
PartyOffCDCore.UPDATE_INTERVAL = UPDATE_INTERVAL
PartyOffCDCore.MAX_TRACKED_ROWS = MAX_TRACKED_ROWS
PartyOffCDCore.MAX_TRACKER_COLUMNS = MAX_TRACKER_COLUMNS
PartyOffCDCore.MAX_VERTICAL_TRACKER_COLUMNS = MAX_VERTICAL_TRACKER_COLUMNS
PartyOffCDCore.MIN_TRACKER_ICON_SCALE = MIN_TRACKER_ICON_SCALE
PartyOffCDCore.MAX_TRACKER_ICON_SCALE = MAX_TRACKER_ICON_SCALE
PartyOffCDCore.ICON_SIZE = ICON_SIZE
PartyOffCDCore.ICON_SPACING = ICON_SPACING
PartyOffCDCore.INTERRUPT_BAR_WIDTH = INTERRUPT_BAR_WIDTH
PartyOffCDCore.INTERRUPT_ROW_HEIGHT = INTERRUPT_ROW_HEIGHT
PartyOffCDCore.INTERRUPT_ICON_SIZE = INTERRUPT_ICON_SIZE
PartyOffCDCore.FALLBACK_X = FALLBACK_X
PartyOffCDCore.FALLBACK_Y = FALLBACK_Y
PartyOffCDCore.MINIMAP_RADIUS = MINIMAP_RADIUS
PartyOffCDCore.DB_DEFAULTS = DB_DEFAULTS
PartyOffCDCore.DebugPrint = DebugPrint
PartyOffCDCore.CopyDefaults = CopyDefaults
PartyOffCDCore.SafeGetSpellInfo = SafeGetSpellInfo
PartyOffCDCore.SafeGetSpellCooldown = SafeGetSpellCooldown
PartyOffCDCore.GetUnitSpecID = GetUnitSpecID
PartyOffCDCore.FormatRemaining = FormatRemaining
PartyOffCDCore.GetUnitFullName = GetUnitFullName
PartyOffCDCore.NormalizeName = NormalizeName
PartyOffCDCore.ApplyLightOutline = ApplyLightOutline
PartyOffCDCore.GetNextSpellType = GetNextSpellType
PartyOffCDCore.CreateCheckbox = CreateCheckbox
PartyOffCDCore.CreateNumericEditBox = CreateNumericEditBox
PartyOffCDCore.IsSecretValue = IsSecretValue
PartyOffCDCore.NormalizeSpellID = NormalizeSpellID

function PartyOffCD:GetClassLabel(classToken)
    return (PartyOffCDCore.CLASS_LABELS and PartyOffCDCore.CLASS_LABELS[classToken]) or classToken or "Unknown"
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

function PartyOffCD:GetCurrentContext()
    local inInstance, instanceType = IsInInstance()
    if not inInstance then
        return "world"
    end

    if instanceType == "arena" then
        return "arena"
    end

    if instanceType == "raid" or IsInRaid() then
        return "raid"
    end

    return "dungeons"
end

function PartyOffCD:GetCurrentContextLabel()
    local context = self:GetCurrentContext()
    if context == "arena" then
        return "Arena"
    end
    if context == "dungeons" then
        return "Dungeons"
    end
    if context == "raid" then
        return "Raids"
    end
    return "Open World"
end

function PartyOffCD:IsContextEnabled(contextKey)
    local defaults = DB_DEFAULTS.enabledContexts or {}
    local contexts = (self.db and self.db.enabledContexts) or defaults
    local value = contexts and contexts[contextKey]
    if value == nil then
        value = defaults[contextKey]
    end
    return value ~= false
end

function PartyOffCD:IsEnabledForCurrentContext()
    return self:IsContextEnabled(self:GetCurrentContext())
end

function PartyOffCD:HasTrackedPartyMembers()
    if IsInRaid() then
        return false
    end

    for index = 1, MAX_TRACKED_ROWS - 1 do
        if UnitExists("party" .. index) then
            return true
        end
    end

    return false
end

function PartyOffCD:EnsureSpecInspector()
    if self.specInspectorInitialized or not self:HasTrackedPartyMembers() then
        return
    end

    local specInspector = PartyOffCDCore and PartyOffCDCore.SpecInspector
    if not (specInspector and specInspector.Init) then
        return
    end

    specInspector:Init(self.db)
    self.specInspectorInitialized = true

    if not self.specInspectorBound and specInspector.RegisterCallback then
        specInspector:RegisterCallback(function()
            PartyOffCD:BuildRoster()
            PartyOffCD:RefreshTracker()
        end)
        self.specInspectorBound = true
    end
end

function PartyOffCD:SetContextEnabled(contextKey, enabled)
    local defaults = DB_DEFAULTS.enabledContexts or {}
    if defaults[contextKey] == nil or not self.db then
        return false
    end

    self.db.enabledContexts = self.db.enabledContexts or CopyDefaults({}, defaults)

    local nextValue = enabled and true or false
    if self.db.enabledContexts[contextKey] == nextValue then
        return false
    end

    self.db.enabledContexts[contextKey] = nextValue
    self:RefreshPartySpellcastWatchers()
    if self:IsEnabledForCurrentContext() then
        self:RequestGroupOverrides()
        self:BroadcastLocalOverrides(true)
    end
    self:RefreshConfigPanel()
    self:RefreshTracker()
    return true
end

function PartyOffCD:HandleContextChanged()
    self:EnsureSpecInspector()
    self.observedAuraState = {}
    self:BuildRoster()
    self:RefreshPartySpellcastWatchers()
    if self:IsEnabledForCurrentContext() then
        self:RequestGroupOverrides()
        self:BroadcastLocalOverrides()
    end
    self:RefreshConfigPanel()
    self:RefreshTracker()
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

    -- Fallback for cross-realm sender formats (Name-Realm) when roster stores short names.
    local shortKey = key:match("^([^%-]+)")
    if shortKey and shortKey ~= key then
        local shortEntry = self.rosterLookup[shortKey]
        if shortEntry then
            return shortEntry.key
        end
    end

    return key
end

function PartyOffCD:GetSenderEntryByGUID(guid)
    if not guid or IsSecretValue(guid) then
        return nil
    end

    return self.rosterGuidLookup and self.rosterGuidLookup[guid] or nil
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

function PartyOffCD:GetLocalCooldownRemaining(spellID)
    local startTime, duration, enabled = SafeGetSpellCooldown(spellID)
    startTime = TrySafeNumber(startTime)
    duration = TrySafeNumber(duration)
    if not enabled then
        return 0, duration or 0, true
    end

    if not startTime or not duration then
        return nil, nil, false
    end

    local isShortCooldown = false
    local okShort = pcall(function()
        isShortCooldown = (duration <= 1.5 or startTime <= 0)
    end)
    if (not okShort) or isShortCooldown then
        if not okShort then
            return nil, nil, false
        end
        return 0, duration, true
    end

    local remaining = 0
    local okRemaining = pcall(function()
        remaining = (startTime + duration) - GetTime()
    end)
    if not okRemaining then
        return nil, nil, false
    end

    remaining = TrySafeNumber(remaining)
    if not remaining then
        return nil, nil, false
    end
    if remaining < 0 then
        remaining = 0
    end

    return remaining, duration, true
end

function PartyOffCD:StartCooldown(senderKey, spellID, senderTime)
    if not self:IsEnabledForCurrentContext() then
        return false
    end

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
    if not self:IsEnabledForCurrentContext() then
        return false
    end

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
    local remaining, _, reliable = self:GetLocalCooldownRemaining(spellID)
    if reliable and remaining and remaining > 0.2 then
        return false, remaining
    end

    return true, 0
end

function PartyOffCD:HandleObservedSenderSpellcast(sender, spellID, senderTime, unitHint)
    spellID = NormalizeSpellID(spellID)
    if not self:IsEnabledForCurrentContext() or not spellID or not sender then
        return false
    end

    local baseMeta = self:GetSpellMeta(spellID)
    if not baseMeta or not self:IsSpellEnabled(spellID) then
        return false
    end

    local senderKey = self:ResolveSenderKey(sender)
    if not senderKey then
        return false
    end

    local unit = unitHint or self:GetSenderUnit(senderKey)
    if unit and not UnitExists(unit) then
        unit = nil
    end

    local effectiveMeta = self:GetEffectiveMeta(senderKey, spellID)
    if not effectiveMeta then
        return false
    end

    local classToken = unit and select(2, UnitClass(unit)) or self:GetSenderClass(senderKey)
    if not classToken or (effectiveMeta.class and effectiveMeta.class ~= classToken) then
        return false
    end

    local specID = (unit and GetUnitSpecID(unit)) or self:GetSenderSpecID(senderKey)
    local inferredSpecID = self:GetSingleSpecIDForMeta(effectiveMeta)
    if inferredSpecID and inferredSpecID > 0 then
        specID = inferredSpecID
        self:UpdateSenderSpecID(senderKey, inferredSpecID)
    elseif specID and specID > 0 then
        self:UpdateSenderSpecID(senderKey, specID)
    end

    if not self:DoesMetaMatchUnit(effectiveMeta, classToken, specID, unit) then
        return false
    end

    if self:ShouldIgnoreDuplicate(senderKey, spellID) then
        return false
    end

    if not self:StartCooldown(senderKey, spellID, senderTime or GetTime()) then
        return false
    end

    if effectiveMeta.type ~= "INT" then
        self:ShowCooldownUseAlert(senderKey, spellID)
    end
    self:RefreshTracker()
    return true
end

function PartyOffCD:HandleObservedCombatLogSpellcast(sourceGUID, sourceName, spellID, senderTime)
    spellID = NormalizeSpellID(spellID)
    if not self:IsEnabledForCurrentContext() or not spellID then
        return false
    end

    local rosterEntry = self:GetSenderEntryByGUID(sourceGUID)
    if rosterEntry then
        return self:HandleObservedSenderSpellcast(
            rosterEntry.fullName or rosterEntry.name or rosterEntry.key,
            spellID,
            senderTime,
            rosterEntry.unit
        )
    end

    if sourceName and not IsSecretValue(sourceName) then
        return self:HandleObservedSenderSpellcast(sourceName, spellID, senderTime)
    end

    return false
end

function PartyOffCD:HandleCombatLogEvent()
    if not self:IsEnabledForCurrentContext() then
        return
    end

    local timestamp, subevent, _, sourceGUID, sourceName, _, _, _, _, _, _, spellID = CombatLogGetCurrentEventInfo()
    spellID = NormalizeSpellID(spellID)
    if not COMBAT_LOG_TRACKED_SUBEVENTS[subevent] or not spellID then
        return
    end

    local meta = self:GetSpellMeta(spellID)
    if not meta or meta.type ~= "INT" or not self:IsSpellEnabled(spellID) then
        return
    end

    self:HandleObservedCombatLogSpellcast(sourceGUID, sourceName, spellID, timestamp or GetTime())
end

function PartyOffCD:RefreshPartySpellcastWatchers()
    local shouldWatchParty = self:IsEnabledForCurrentContext() and self:HasTrackedPartyMembers()
    local units = { "player" }
    for index = 1, MAX_TRACKED_ROWS - 1 do
        units[#units + 1] = "party" .. index
    end

    for _, unit in ipairs(units) do
        local frame = self.partyCastFrames[unit]

        if not frame then
            frame = CreateFrame("Frame")
            frame:SetScript("OnEvent", function(_, event, eventUnit, ...)
                local watchedUnit = eventUnit or unit
                if event == "UNIT_SPELLCAST_SUCCEEDED" then
                    PartyOffCD:HandleObservedUnitSpellcastEvidence(watchedUnit)
                elseif event == "UNIT_AURA" then
                    PartyOffCD:HandleObservedUnitAuraChanged(watchedUnit, ...)
                elseif event == "UNIT_FLAGS" then
                    PartyOffCD:HandleObservedUnitFlagsChanged(watchedUnit)
                end
            end)
            self.partyCastFrames[unit] = frame
        end

        frame:UnregisterAllEvents()
        if shouldWatchParty then
            frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", unit)
            frame:RegisterUnitEvent("UNIT_AURA", unit)
            frame:RegisterUnitEvent("UNIT_FLAGS", unit)
        else
            self.observedAuraState[unit] = nil
        end
    end
end

function PartyOffCD:SyncLocalRealCooldowns()
    if not self:IsEnabledForCurrentContext() then
        return
    end

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
            local realRemaining, _, reliable = self:GetLocalCooldownRemaining(spellID)

            if trackedRemaining < 0 then
                trackedRemaining = 0
            end

            if reliable and realRemaining and realRemaining > 0 then
                if math.abs(realRemaining - trackedRemaining) >= REAL_SYNC_THRESHOLD then
                    self:SetRemainingCooldown(playerKey, spellID, math.ceil(realRemaining))
                end
            end
        end
    end
end

function PartyOffCD:ReportSpellUse(spellID, silent)
    spellID = tonumber(spellID)
    local meta = self:GetSpellMeta(spellID)
    if not meta then
        if not silent then
            DebugPrint("Unsupported SpellID: " .. tostring(spellID))
        end
        return
    end

    if not self:IsEnabledForCurrentContext() then
        if not silent then
            DebugPrint("The addon is disabled in the current context.")
        end
        return
    end

    if not self:IsSpellEnabled(spellID) then
        if not silent then
            DebugPrint("That spell is disabled in configuration.")
        end
        return
    end

    if not silent then
        local canReport, remaining = self:CanReportLocalUse(spellID)
        if not canReport then
            DebugPrint(string.format("That spell is still on real cooldown (%.1fs).", remaining))
            return
        end
    end

    local playerKey = self:GetPlayerCanonical()
    if playerKey then
        self:StartCooldown(playerKey, spellID, GetTime())
    end

    local sent = self:SendUseMessage(spellID)
    if not sent and not silent then
        DebugPrint("You are not in a group; only the local timer was started for " .. tostring(spellID))
    end

    self:RefreshTracker()
end


function PartyOffCD:Initialize()
    self:BuildRoster()
    self:InitializeDB()

    local talentTracker = PartyOffCDCore and PartyOffCDCore.TalentTracker
    if talentTracker and talentTracker.Init then
        talentTracker:Init(self.db)
        if not self.talentTrackerBound and talentTracker.RegisterCallback then
            talentTracker:RegisterCallback(function()
                PartyOffCD:BuildRoster()
                PartyOffCD:RefreshTracker()
            end)
            self.talentTrackerBound = true
        end
    end

    self:EnsureSpecInspector()

    self:BuildRoster()

    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
    else
        DebugPrint("C_ChatInfo unavailable; network tracking will not work.")
    end

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
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    self:RegisterEvent("CHAT_MSG_ADDON")
    self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    self:RegisterEvent("UNIT_ABSORB_AMOUNT_CHANGED")

    self:RefreshPartySpellcastWatchers()
    self:RefreshMinimapButton()
    self:RequestGroupOverrides()
    self:BroadcastLocalOverrides(true)
    self:RefreshTracker()
    DebugPrint("Loaded. Use /pocd config or click the minimap button.")
end


PartyOffCD:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        PartyOffCD:Initialize()
        return
    end

    if event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_SPECIALIZATION_CHANGED" then
        PartyOffCD:HandleContextChanged()
        return
    end

    if event == "CHAT_MSG_ADDON" then
        PartyOffCD:HandleAddonMessage(...)
        return
    end

    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        PartyOffCD:HandleCombatLogEvent()
        return
    end

    if event == "UNIT_ABSORB_AMOUNT_CHANGED" then
        local unit = ...
        PartyOffCD:HandleObservedAbsorbAmountChanged(unit)
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
   New spells appear automatically in the config panel under their class.
   The config panel can also overwrite existing base spells with your own CD/type/class values.
   Overrides are stored per character and are broadcast to party members automatically.

2) Tracking model
   Offensive and defensive cooldowns are inferred from aura appearance/removal plus evidence
   such as cast, debuff, shield, and unit-flag events. Only spells with explicit rules in
   AuraTracker.lua auto-track with this model.
   Interrupts still use combat-log tracking because they do not leave a tracked aura.

3) Slash examples
   /pocd use 31884
   /pocd timer 31884 45
   /pocd use 97462
   /pocd use 190319
   /pocd test
   /pocd config

4) Minimap and config
   Click the minimap button opens the config panel.
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
   The tracker shows aura-supported offensive/defensive spells plus any active manual timers.
]]
