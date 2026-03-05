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
local ICON_SIZE = 30
local ICON_SPACING = 3
local INTERRUPT_BAR_WIDTH = 190
local INTERRUPT_ROW_HEIGHT = 22
local INTERRUPT_ICON_SIZE = 18
local FALLBACK_X = 210
local FALLBACK_Y = 120
local MINIMAP_RADIUS = 96

local SPELL_TYPES = { "OFF", "DEF", "INT" }
local DB_DEFAULTS = assert(
    PartyOffCDCore and PartyOffCDCore.DEFAULTS,
    "PartyOffCD: missing core defaults (Core.lua was not loaded)."
)

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
PartyOffCD.missingBuffIconPool = {}
PartyOffCD.missingBuffIcons = {}
PartyOffCD.lastOverrideBroadcast = 0
PartyOffCD.lastRealtimeSync = 0
PartyOffCD.lastLocalReport = {}
PartyOffCD.senderSpecIDs = {}
PartyOffCD.addonUsers = {}

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
            -- Avoid comparing secure booleans from C_Spell cooldown info in combat.
            return info.startTime or 0, info.duration or 0, true
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

function PartyOffCD:ReportSpellUse(spellID, silent)
    spellID = tonumber(spellID)
    local meta = self:GetSpellMeta(spellID)
    if not meta then
        if not silent then
            DebugPrint("Unsupported SpellID: " .. tostring(spellID))
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

    if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
    else
        DebugPrint("C_ChatInfo unavailable; network tracking will not work.")
    end

    self:CreateTrackerFrame()
    self:CreateInterruptFrame()
    self:CreateMissingBuffFrame()
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

    self:RefreshConfigPanel()
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
   The tracker now always shows all enabled spells; use the checkboxes to hide spells you do not want to see.
]]

