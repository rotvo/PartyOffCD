local _, PartyOffCDCore = ...
PartyOffCDCore = PartyOffCDCore or _G.PartyOffCDCore

local PartyOffCD = _G.PartyOffCD
assert(PartyOffCD, "PartyOffCD: frame missing before loading Tracker.lua")
assert(PartyOffCDCore, "PartyOffCD: core missing before loading Tracker.lua")

local MAX_TRACKED_ROWS = PartyOffCDCore.MAX_TRACKED_ROWS
local MAX_TRACKER_COLUMNS = PartyOffCDCore.MAX_TRACKER_COLUMNS or 8
local MAX_VERTICAL_TRACKER_COLUMNS = PartyOffCDCore.MAX_VERTICAL_TRACKER_COLUMNS or 4
local MIN_TRACKER_ICON_SCALE = PartyOffCDCore.MIN_TRACKER_ICON_SCALE or 10
local MAX_TRACKER_ICON_SCALE = PartyOffCDCore.MAX_TRACKER_ICON_SCALE or 100
local ICON_SIZE = PartyOffCDCore.ICON_SIZE
local ICON_SPACING = PartyOffCDCore.ICON_SPACING
local INTERRUPT_BAR_WIDTH = PartyOffCDCore.INTERRUPT_BAR_WIDTH
local INTERRUPT_ROW_HEIGHT = PartyOffCDCore.INTERRUPT_ROW_HEIGHT
local INTERRUPT_ICON_SIZE = PartyOffCDCore.INTERRUPT_ICON_SIZE
local FALLBACK_X = PartyOffCDCore.FALLBACK_X
local FALLBACK_Y = PartyOffCDCore.FALLBACK_Y
local SPELLS = PartyOffCDCore.SPELLS
local SPELL_TYPE_PRIORITY = PartyOffCDCore.SPELL_TYPE_PRIORITY
local DB_DEFAULTS = PartyOffCDCore.DEFAULTS
local TRACKER_TYPE_GAP = ICON_SPACING + 8
local MISSING_BUFF_ICON_SIZE = 36
local MISSING_BUFF_ICON_SPACING = 8
local COOLDOWN_ALERT_DURATION = 0.9
local COOLDOWN_ALERT_HOLD = 0.45
local MISSING_BUFFS = {
    { class = "MAGE", spellIDs = { 1459 } }, -- Arcane Intellect
    { class = "PRIEST", spellIDs = { 21562 } }, -- Power Word: Fortitude
    { class = "WARRIOR", spellIDs = { 6673 } }, -- Battle Shout
    { class = "EVOKER", spellIDs = { 381746 } }, -- Blessing of the Bronze
    { class = "DRUID", spellIDs = { 1126 } }, -- Mark of the Wild
    { class = "SHAMAN", spellIDs = { 462854, 204330 } }, -- Skyfury (version fallback)
}

local SafeGetSpellInfo = PartyOffCDCore.SafeGetSpellInfo
local GetUnitSpecID = PartyOffCDCore.GetUnitSpecID
local FormatRemaining = PartyOffCDCore.FormatRemaining
local GetUnitFullName = PartyOffCDCore.GetUnitFullName
local NormalizeName = PartyOffCDCore.NormalizeName
local ApplyLightOutline = PartyOffCDCore.ApplyLightOutline

local function IsValidTrackerAttach(attach)
    return attach == "LEFT" or attach == "RIGHT" or attach == "CENTER" or attach == "TOP" or attach == "BOTTOM"
end

local function NormalizeTrackerAttach(attach)
    attach = string.upper(tostring(attach or ""))
    if not IsValidTrackerAttach(attach) then
        return "LEFT"
    end
    return attach
end

local function GetSpacingForIconSize(iconSize)
    return math.max(1, math.floor(ICON_SPACING * (iconSize / ICON_SIZE)))
end

local function GetCrossAxisSize(iconSize, crossSlots)
    if crossSlots <= 0 then
        return 0
    end
    local spacing = GetSpacingForIconSize(iconSize)
    return (crossSlots * iconSize) + (math.max(0, crossSlots - 1) * spacing)
end

local function GetSpanSize(slotCount, itemSize, gap)
    if slotCount <= 0 then
        return 0
    end

    return (slotCount * itemSize) + (math.max(0, slotCount - 1) * gap)
end

local function GetMaxIconSizeForCrossSlots(maxCrossSize, crossSlots)
    if not maxCrossSize or maxCrossSize <= 0 or not crossSlots or crossSlots <= 0 then
        return ICON_SIZE
    end

    local low = 1
    local high = math.max(1, math.floor(maxCrossSize))
    local best = 1

    while low <= high do
        local mid = math.floor((low + high) / 2)
        local usedSize = GetCrossAxisSize(mid, crossSlots)
        if usedSize <= maxCrossSize then
            best = mid
            low = mid + 1
        else
            high = mid - 1
        end
    end

    return best
end

local function ResolveMissingBuffSpellID(definition)
    if definition.resolvedSpellID ~= nil then
        return definition.resolvedSpellID or nil
    end

    for _, spellID in ipairs(definition.spellIDs or {}) do
        if SafeGetSpellInfo(spellID) then
            definition.resolvedSpellID = spellID
            return spellID
        end
    end

    definition.resolvedSpellID = false
    return nil
end

local function UnitHasBuffFromSpellID(unit, spellID)
    -- Missing-buff checks are separate from OFF/DEF cooldown attribution. Keep this
    -- minimal so future work does not treat old aura-scan fallbacks as a valid model.
    local targetSpellID = tonumber(spellID)
    if not unit or not UnitExists(unit) or not targetSpellID then
        return false
    end

    if C_UnitAuras and C_UnitAuras.GetAuraDataBySpellID then
        local aura = C_UnitAuras.GetAuraDataBySpellID(unit, targetSpellID, "HELPFUL")
        if aura then
            return true
        end
    end

    if AuraUtil and AuraUtil.FindAuraBySpellID then
        local ok, aura = pcall(AuraUtil.FindAuraBySpellID, targetSpellID, unit, "HELPFUL")
        if ok and aura then
            return true
        end
    end

    return false
end

local function UnitHasBuffFromDefinition(unit, definition)
    if not definition then
        return false
    end

    for _, candidateSpellID in ipairs(definition.spellIDs or {}) do
        if UnitHasBuffFromSpellID(unit, candidateSpellID) then
            return true
        end
    end

    return false
end

function PartyOffCD:BuildRoster()
    wipe(self.roster)
    wipe(self.rosterLookup)
    wipe(self.rosterGuidLookup)

    local units = {}
    local excludeSelf = self:IsTrackerExcludeSelfEnabled()

    if IsInRaid() then
        -- Tracker is party-only; leave units empty so the UI hides itself
    elseif self:HasTrackedPartyMembers() then
        if not excludeSelf then
            units[#units + 1] = "player"
        end
        for index = 1, MAX_TRACKED_ROWS - 1 do
            units[#units + 1] = "party" .. index
        end
    end

    for _, unit in ipairs(units) do
        if UnitExists(unit) then
            local fullName = GetUnitFullName(unit)
            local shortName = UnitName(unit)
            local guid = UnitGUID(unit)
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
                    guid = guid,
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
                if entry.guid then
                    self.rosterGuidLookup[entry.guid] = entry
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
    local stamp = GetTime()
    if self.playerKeys.full then
        self.addonUsers[self.playerKeys.full] = stamp
    end
    if self.playerKeys.short then
        self.addonUsers[self.playerKeys.short] = stamp
    end
    if playerSpecID then
        if self.playerKeys.full then
            self.senderSpecIDs[self.playerKeys.full] = playerSpecID
        end
        if self.playerKeys.short then
            self.senderSpecIDs[self.playerKeys.short] = playerSpecID
        end
    end
end

local function DoesAnchorMatchUnit(frame, unit)
    if not frame or not unit or not frame.IsShown or not frame:IsShown() then
        return false
    end

    local frameUnit = frame.unit or frame.displayedUnit
    if not frameUnit and frame.GetAttribute then
        frameUnit = frame:GetAttribute("unit")
    end

    return frameUnit and UnitExists(frameUnit) and UnitIsUnit(frameUnit, unit) or false
end

local function GetCompactPartyAnchor(unit, fallbackIndex)
    if unit and UnitExists(unit) then
        for index = 1, MAX_TRACKED_ROWS do
            local frame = _G["CompactPartyFrameMember" .. index]
            if DoesAnchorMatchUnit(frame, unit) then
                return frame
            end

            local raidFrame = _G["CompactRaidFrame" .. index]
            if DoesAnchorMatchUnit(raidFrame, unit) then
                return raidFrame
            end
        end
    end

    if fallbackIndex then
        local frame = _G["CompactPartyFrameMember" .. fallbackIndex]
        if frame and frame:IsShown() then
            return frame
        end

        local raidFrame = _G["CompactRaidFrame" .. fallbackIndex]
        if raidFrame and raidFrame:IsShown() then
            return raidFrame
        end
    end

    return nil
end

function PartyOffCD:GetRosterAnchor(unit, fallbackIndex)
    return GetCompactPartyAnchor(unit, fallbackIndex)
end

local function CreateCooldownAlertFrame()
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:Hide()

    frame.background = frame:CreateTexture(nil, "BACKGROUND")
    frame.background:SetAllPoints()
    frame.background:SetColorTexture(0, 0, 0, 0.35)

    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetAllPoints()
    frame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    frame.highlight = frame:CreateTexture(nil, "OVERLAY")
    frame.highlight:SetPoint("CENTER")
    frame.highlight:SetBlendMode("ADD")
    frame.highlight:SetTexture([[Interface\SpellActivationOverlay\IconAlert]])
    frame.highlight:SetTexCoord(0.00781250, 0.50781250, 0.27734375, 0.52734375)
    frame.highlight:SetVertexColor(1, 0.85, 0.15, 0.9)

    frame.highlightOver = frame:CreateTexture(nil, "OVERLAY")
    frame.highlightOver:SetPoint("CENTER")
    frame.highlightOver:SetBlendMode("ADD")
    frame.highlightOver:SetTexture([[Interface\SpellActivationOverlay\IconAlert]])
    frame.highlightOver:SetTexCoord(0.00781250, 0.50781250, 0.53515625, 0.78515625)
    frame.highlightOver:SetVertexColor(1, 0.92, 0.35, 0.75)

    frame.animation = frame:CreateAnimationGroup()

    local scaleIn = frame.animation:CreateAnimation("Scale")
    scaleIn:SetOrder(1)
    scaleIn:SetDuration(0.16)
    scaleIn:SetScale(0.18, 0.18)

    local alphaIn = frame.animation:CreateAnimation("Alpha")
    alphaIn:SetOrder(1)
    alphaIn:SetDuration(0.12)
    alphaIn:SetFromAlpha(0)
    alphaIn:SetToAlpha(1)

    local scaleOut = frame.animation:CreateAnimation("Scale")
    scaleOut:SetOrder(2)
    scaleOut:SetDuration(0.28)
    scaleOut:SetStartDelay(COOLDOWN_ALERT_HOLD)
    scaleOut:SetScale(0.18, 0.18)

    local alphaOut = frame.animation:CreateAnimation("Alpha")
    alphaOut:SetOrder(2)
    alphaOut:SetDuration(0.28)
    alphaOut:SetStartDelay(COOLDOWN_ALERT_HOLD)
    alphaOut:SetFromAlpha(1)
    alphaOut:SetToAlpha(0)

    frame.animation:SetScript("OnPlay", function(self)
        local parent = self:GetParent()
        parent:SetAlpha(1)
        parent:SetScale(1)
        parent:Show()
    end)

    frame.animation:SetScript("OnFinished", function(self)
        local parent = self:GetParent()
        parent:SetAlpha(1)
        parent:SetScale(1)
        parent:Hide()
    end)

    return frame
end

function PartyOffCD:ShowCooldownUseAlert(senderKey, spellID)
    if not self:IsEnabledForCurrentContext() then
        return false
    end

    senderKey = self:ResolveSenderKey(senderKey)
    spellID = tonumber(spellID)
    if not senderKey or not spellID then
        return false
    end

    local rosterEntry = self.rosterLookup[senderKey]
    if not rosterEntry then
        return false
    end

    local rosterIndex
    for index, entry in ipairs(self.roster) do
        if entry.key == rosterEntry.key then
            rosterIndex = index
            break
        end
    end

    if not rosterIndex then
        return false
    end

    local anchor = self:GetRosterAnchor(rosterEntry.unit, rosterIndex)
    if not anchor or not anchor:IsShown() then
        return false
    end

    local _, iconTexture = SafeGetSpellInfo(spellID)
    if not iconTexture then
        return false
    end

    local alert = self.cooldownAlerts[senderKey]
    if not alert then
        alert = CreateCooldownAlertFrame()
        self.cooldownAlerts[senderKey] = alert
    end

    local size = math.max(24, math.floor(math.min(anchor:GetWidth(), anchor:GetHeight()) * 0.78))
    local glowSize = math.floor(size * 1.9)

    alert:SetParent(UIParent)
    alert:ClearAllPoints()
    alert:SetPoint("CENTER", anchor, "CENTER", 0, 0)
    alert:SetFrameLevel((anchor:GetFrameLevel() or 1) + 20)
    alert:SetSize(size, size)
    alert.icon:SetTexture(iconTexture)
    alert.highlight:SetSize(glowSize, glowSize)
    alert.highlightOver:SetSize(glowSize, glowSize)

    if alert.animation:IsPlaying() then
        alert.animation:Stop()
    end

    alert:SetAlpha(1)
    alert:SetScale(0.82)
    alert:Show()
    alert.animation:Play()
    return true
end

function PartyOffCD:GetTrackerAttach()
    local dbAttach = self.db and self.db.trackerAttach
    local defaultAttach = (DB_DEFAULTS and DB_DEFAULTS.trackerAttach) or "LEFT"
    return NormalizeTrackerAttach(dbAttach or defaultAttach)
end

function PartyOffCD:GetTrackerOffsetX()
    local value = tonumber(self.db and self.db.trackerOffsetX)
    if value == nil then
        value = tonumber(DB_DEFAULTS and DB_DEFAULTS.trackerOffsetX) or -4
    end
    return math.floor(value)
end

function PartyOffCD:GetTrackerOffsetY()
    local value = tonumber(self.db and self.db.trackerOffsetY)
    if value == nil then
        value = tonumber(DB_DEFAULTS and DB_DEFAULTS.trackerOffsetY) or 0
    end
    return math.floor(value)
end

function PartyOffCD:SetTrackerOffsetX(value)
    if not self.db then
        return false
    end

    value = math.floor(tonumber(value) or 0)
    if value < -250 then
        value = -250
    elseif value > 250 then
        value = 250
    end

    if self.db.trackerOffsetX == value then
        return false
    end

    self.db.trackerOffsetX = value
    return true
end

function PartyOffCD:SetTrackerOffsetY(value)
    if not self.db then
        return false
    end

    value = math.floor(tonumber(value) or 0)
    if value < -250 then
        value = -250
    elseif value > 250 then
        value = 250
    end

    if self.db.trackerOffsetY == value then
        return false
    end

    self.db.trackerOffsetY = value
    return true
end

function PartyOffCD:GetTrackerColumnLimit(attach)
    attach = NormalizeTrackerAttach(attach or self:GetTrackerAttach())
    if attach == "TOP" or attach == "BOTTOM" then
        return math.min(MAX_TRACKER_COLUMNS, MAX_VERTICAL_TRACKER_COLUMNS)
    end
    return MAX_TRACKER_COLUMNS
end

function PartyOffCD:GetTrackerColumns()
    local dbColumns = self.db and self.db.trackerColumns
    local defaultColumns = (DB_DEFAULTS and DB_DEFAULTS.trackerColumns) or 1
    local maxColumns = self:GetTrackerColumnLimit()
    local columns = math.floor(tonumber(dbColumns) or tonumber(defaultColumns) or 1)
    if columns < 1 then
        columns = 1
    elseif columns > maxColumns then
        columns = maxColumns
    end
    return columns
end

function PartyOffCD:GetTrackerRows()
    local value = math.floor(tonumber(self.db and self.db.trackerRows) or tonumber(DB_DEFAULTS and DB_DEFAULTS.trackerRows) or 1)
    if value < 1 then
        value = 1
    elseif value > 3 then
        value = 3
    end
    return value
end

function PartyOffCD:SetTrackerRows(value)
    if not self.db then
        return false
    end

    value = math.floor(tonumber(value) or 1)
    if value < 1 then
        value = 1
    elseif value > 3 then
        value = 3
    end

    if self.db.trackerRows == value then
        return false
    end

    self.db.trackerRows = value
    return true
end

function PartyOffCD:GetTrackerMaxIcons()
    local value = math.floor(tonumber(self.db and self.db.trackerMaxIcons) or tonumber(DB_DEFAULTS and DB_DEFAULTS.trackerMaxIcons) or 10)
    if value < 1 then
        value = 1
    elseif value > 12 then
        value = 12
    end
    return value
end

function PartyOffCD:SetTrackerMaxIcons(value)
    if not self.db then
        return false
    end

    value = math.floor(tonumber(value) or 10)
    if value < 1 then
        value = 1
    elseif value > 12 then
        value = 12
    end

    if self.db.trackerMaxIcons == value then
        return false
    end

    self.db.trackerMaxIcons = value
    return true
end

function PartyOffCD:GetTrackerIconScale()
    local dbScale = self.db and self.db.trackerIconScale
    local defaultScale = (DB_DEFAULTS and DB_DEFAULTS.trackerIconScale) or 100
    local scale = math.floor(tonumber(dbScale) or tonumber(defaultScale) or 100)
    if scale < MIN_TRACKER_ICON_SCALE then
        scale = MIN_TRACKER_ICON_SCALE
    elseif scale > MAX_TRACKER_ICON_SCALE then
        scale = MAX_TRACKER_ICON_SCALE
    end
    return scale
end

function PartyOffCD:GetTrackerConfiguredIconSize()
    return math.max(10, math.floor(ICON_SIZE * (self:GetTrackerIconScale() / 100)))
end

function PartyOffCD:SetTrackerConfiguredIconSize(size)
    size = math.floor(tonumber(size) or ICON_SIZE)
    if size < 10 then
        size = 10
    elseif size > 60 then
        size = 60
    end

    local scale = math.floor((size * 100 / ICON_SIZE) + 0.5)
    return self:SetTrackerIconScale(scale)
end

function PartyOffCD:IsTrackerTooltipsEnabled()
    local value = self.db and self.db.trackerShowTooltips
    if value == nil then
        value = DB_DEFAULTS and DB_DEFAULTS.trackerShowTooltips
    end
    return value ~= false
end

function PartyOffCD:SetTrackerTooltipsEnabled(enabled)
    if not self.db then
        return false
    end

    local value = enabled and true or false
    if self.db.trackerShowTooltips == value then
        return false
    end

    self.db.trackerShowTooltips = value
    return true
end

function PartyOffCD:IsTrackerReverseCooldownEnabled()
    local value = self.db and self.db.trackerReverseCooldown
    if value == nil then
        value = DB_DEFAULTS and DB_DEFAULTS.trackerReverseCooldown
    end
    return value == true
end

function PartyOffCD:SetTrackerReverseCooldownEnabled(enabled)
    if not self.db then
        return false
    end

    local value = enabled and true or false
    if self.db.trackerReverseCooldown == value then
        return false
    end

    self.db.trackerReverseCooldown = value
    return true
end

function PartyOffCD:IsTrackerExcludeSelfEnabled()
    local value = self.db and self.db.trackerExcludeSelf
    if value == nil then
        value = DB_DEFAULTS and DB_DEFAULTS.trackerExcludeSelf
    end
    return value == true
end

function PartyOffCD:SetTrackerExcludeSelfEnabled(enabled)
    if not self.db then
        return false
    end

    local value = enabled and true or false
    if self.db.trackerExcludeSelf == value then
        return false
    end

    self.db.trackerExcludeSelf = value
    return true
end

function PartyOffCD:IsTrackerTypeVisible(spellType)
    local key
    if spellType == "OFF" then
        key = "trackerShowOffensive"
    elseif spellType == "DEF" then
        key = "trackerShowDefensive"
    else
        return true
    end

    local value = self.db and self.db[key]
    if value == nil then
        value = DB_DEFAULTS and DB_DEFAULTS[key]
    end
    return value ~= false
end

function PartyOffCD:SetTrackerTypeVisible(spellType, enabled)
    if not self.db then
        return false
    end

    local key
    if spellType == "OFF" then
        key = "trackerShowOffensive"
    elseif spellType == "DEF" then
        key = "trackerShowDefensive"
    else
        return false
    end

    local value = enabled and true or false
    if self.db[key] == value then
        return false
    end

    self.db[key] = value
    return true
end

function PartyOffCD:SetTrackerAttach(attach)
    if not self.db then
        return false
    end

    local normalized = NormalizeTrackerAttach(attach)
    if self.db.trackerAttach == normalized then
        return false
    end

    self.db.trackerAttach = normalized
    local maxColumns = self:GetTrackerColumnLimit(normalized)
    local currentColumns = math.floor(tonumber(self.db.trackerColumns) or 1)
    if currentColumns > maxColumns then
        self.db.trackerColumns = maxColumns
    elseif currentColumns < 1 then
        self.db.trackerColumns = 1
    end
    return true
end

function PartyOffCD:SetTrackerColumns(columns)
    if not self.db then
        return false
    end

    local maxColumns = self:GetTrackerColumnLimit()
    local value = math.floor(tonumber(columns) or 1)
    if value < 1 then
        value = 1
    elseif value > maxColumns then
        value = maxColumns
    end

    if self.db.trackerColumns == value then
        return false
    end

    self.db.trackerColumns = value
    return true
end

function PartyOffCD:SetTrackerIconScale(scale)
    if not self.db then
        return false
    end

    local value = math.floor(tonumber(scale) or 100)
    if value < MIN_TRACKER_ICON_SCALE then
        value = MIN_TRACKER_ICON_SCALE
    elseif value > MAX_TRACKER_ICON_SCALE then
        value = MAX_TRACKER_ICON_SCALE
    end

    if self.db.trackerIconScale == value then
        return false
    end

    self.db.trackerIconScale = value
    return true
end

function PartyOffCD:GetTrackerIconMetrics(row, attach, crossSlots)
    local iconScale = self:GetTrackerIconScale()
    local iconSize = math.max(8, math.floor(ICON_SIZE * (iconScale / 100)))
    local iconSpacing = GetSpacingForIconSize(iconSize)

    if (attach == "LEFT" or attach == "RIGHT") and crossSlots and crossSlots > 0 then
        local target = row and row:GetParent()
        if target and target ~= self.trackerFrame and target.GetHeight then
            local targetHeight = target:GetHeight() or 0
            if targetHeight > 0 then
                local maxIconSize = GetMaxIconSizeForCrossSlots(targetHeight, crossSlots)
                iconSize = math.floor(maxIconSize * (iconScale / 100))
                if iconSize < 8 then
                    iconSize = 8
                elseif iconSize > maxIconSize then
                    iconSize = maxIconSize
                end
                iconSpacing = GetSpacingForIconSize(iconSize)
            end
        end
    end

    return iconSize, iconSpacing
end

function PartyOffCD:GetTrackerGroupColumns(row, attach, groupCount, iconSize, iconSpacing)
    if not groupCount or groupCount <= 1 then
        return math.max(1, groupCount or 1)
    end

    if attach == "LEFT" or attach == "RIGHT" then
        return groupCount
    end

    local target = row and row:GetParent()
    if target and target ~= self.trackerFrame and target.GetWidth then
        local availableWidth = target:GetWidth() or 0
        if availableWidth > 0 then
            local columns = math.floor((availableWidth + iconSpacing) / (iconSize + iconSpacing))
            if columns < 1 then
                columns = 1
            end
            return math.min(groupCount, columns)
        end
    end

    return math.min(MAX_VERTICAL_TRACKER_COLUMNS, groupCount)
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
    title:SetText("")

    self.trackerFrame = frame
end

function PartyOffCD:AcquireIcon(parent)
    local icon = tremove(self.iconPool)
    if icon then
        icon:SetParent(parent)
        icon:Show()
        return icon
    end

    icon = CreateFrame("Frame", nil, parent)
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:EnableMouse(true)

    icon.texture = icon:CreateTexture(nil, "ARTWORK")
    icon.texture:SetAllPoints()
    icon.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    icon.activeGlow = icon:CreateTexture(nil, "OVERLAY")
    icon.activeGlow:SetPoint("CENTER")
    icon.activeGlow:SetBlendMode("ADD")
    icon.activeGlow:SetTexture([[Interface\SpellActivationOverlay\IconAlert]])
    icon.activeGlow:SetTexCoord(0.00781250, 0.50781250, 0.27734375, 0.52734375)
    icon.activeGlow:SetVertexColor(1, 0.82, 0.12, 0.85)
    icon.activeGlow:Hide()

    icon.activeGlowOver = icon:CreateTexture(nil, "OVERLAY")
    icon.activeGlowOver:SetPoint("CENTER")
    icon.activeGlowOver:SetBlendMode("ADD")
    icon.activeGlowOver:SetTexture([[Interface\SpellActivationOverlay\IconAlert]])
    icon.activeGlowOver:SetTexCoord(0.00781250, 0.50781250, 0.53515625, 0.78515625)
    icon.activeGlowOver:SetVertexColor(1, 0.92, 0.35, 0.72)
    icon.activeGlowOver:Hide()

    icon.cooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
    icon.cooldown:SetAllPoints()
    if icon.cooldown.SetDrawSwipe then
        icon.cooldown:SetDrawSwipe(true)
    end
    if icon.cooldown.SetSwipeColor then
        icon.cooldown:SetSwipeColor(0, 0, 0, 0.8)
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
        if not button.spellID or not PartyOffCD:IsTrackerTooltipsEnabled() then
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

local function CreateActiveAuraFrame()
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetFrameStrata("HIGH")
    frame:Hide()

    frame.background = frame:CreateTexture(nil, "BACKGROUND")
    frame.background:SetAllPoints()
    frame.background:SetColorTexture(0, 0, 0, 0)

    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetAllPoints()
    frame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    frame.cooldown = CreateFrame("Cooldown", nil, frame, "CooldownFrameTemplate")
    frame.cooldown:SetAllPoints()
    if frame.cooldown.SetDrawSwipe then
        frame.cooldown:SetDrawSwipe(false)
    end
    if frame.cooldown.SetSwipeColor then
        frame.cooldown:SetSwipeColor(0, 0, 0, 0)
    end
    if frame.cooldown.SetDrawBling then
        frame.cooldown:SetDrawBling(false)
    end
    if frame.cooldown.SetHideCountdownNumbers then
        frame.cooldown:SetHideCountdownNumbers(true)
    end

    return frame
end

function PartyOffCD:HideRowActiveAura(row)
    if not row or not row.activeAuraFrame then
        return
    end

    row.activeAuraFrame:Hide()
    row.activeAuraFrame:ClearAllPoints()
    row.activeAuraFrame.spellID = nil
    row.activeAuraFrame.icon:SetTexture(nil)
    row.activeAuraFrame.cooldown:SetCooldown(0, 0)
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
        icon.texture:SetVertexColor(1, 1, 1, 1)
        if icon.texture.SetDesaturated then
            icon.texture:SetDesaturated(false)
        end
        if icon.activeGlow then
            icon.activeGlow:Hide()
        end
        if icon.activeGlowOver then
            icon.activeGlowOver:Hide()
        end
        icon.cooldown:SetCooldown(0, 0)
        icon.timeText:SetText("")
        icon.typeText:SetText("")
        tinsert(self.iconPool, icon)
    end

    wipe(row.icons)
    self:HideRowActiveAura(row)
end

function PartyOffCD:CreateRow(index)
    local row = CreateFrame("Frame", nil, self.trackerFrame)
    row:SetSize(ICON_SIZE, ICON_SIZE)
    row.index = index
    row.icons = {}
    row.layoutAttach = "LEFT"

    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.label:SetPoint("RIGHT", row, "LEFT", -6, 0)
    row.label:SetJustifyH("RIGHT")
    row.label:SetWidth(90)
    row.label:Hide()
    row.activeAuraFrame = CreateActiveAuraFrame()

    self.rows[index] = row
    return row
end

function PartyOffCD:GetActiveAuraEntry(senderKey, onlyType)
    local senderClass = self:GetSenderClass(senderKey)
    local senderSpecID = self:GetSenderSpecID(senderKey)
    local senderUnit = self:GetSenderUnit(senderKey)
    local auraTracker = PartyOffCDCore and PartyOffCDCore.AuraTracker or nil
    local activeAuras = senderUnit and auraTracker and auraTracker.GetActiveAuras and auraTracker.GetActiveAuras(senderUnit) or nil
    local bestEntry = nil

    for _, aura in ipairs(activeAuras or {}) do
        local spellID = aura and tonumber(aura.SpellID)
        local meta = spellID and self:GetEffectiveMeta(senderKey, spellID) or nil
        if meta and self:IsSpellEnabled(spellID) and ((not onlyType) or meta.type == onlyType) then
            if self:DoesMetaMatchUnit(meta, senderClass, senderSpecID, senderUnit) then
                local candidate = {
                    spellID = spellID,
                    meta = meta,
                    startTime = tonumber(aura.StartTime) or 0,
                    duration = tonumber(aura.BuffDuration) or 0,
                }
                if not bestEntry or candidate.startTime > bestEntry.startTime then
                    bestEntry = candidate
                end
            end
        end
    end

    return bestEntry
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
    local senderUnit = self:GetSenderUnit(senderKey)
    local candidateSpellIDs = {}
    local seenSpellIDs = {}
    local activeAuraSpellIDSet = {}

    local function AddCandidateSpellID(spellID)
        spellID = tonumber(spellID)
        if not spellID or seenSpellIDs[spellID] or not self:IsSpellEnabled(spellID) then
            return
        end

        seenSpellIDs[spellID] = true
        candidateSpellIDs[#candidateSpellIDs + 1] = spellID
    end

    if onlyType == "INT" then
        for spellID, meta in pairs(SPELLS) do
            if meta.type == "INT" then
                AddCandidateSpellID(spellID)
            end
        end
    else
        local auraTracker = PartyOffCDCore and PartyOffCDCore.AuraTracker or nil
        local staticSpellIDs = senderUnit and auraTracker and auraTracker.GetStaticSpellIDs and auraTracker.GetStaticSpellIDs(senderUnit) or nil
        local activeAuraSpellIDs = senderUnit and auraTracker and auraTracker.GetActiveSpellIDs and auraTracker.GetActiveSpellIDs(senderUnit) or nil

        for _, spellID in ipairs(staticSpellIDs or {}) do
            AddCandidateSpellID(spellID)
        end

        for _, spellID in ipairs(activeAuraSpellIDs or {}) do
            spellID = tonumber(spellID)
            if spellID then
                activeAuraSpellIDSet[spellID] = true
                AddCandidateSpellID(spellID)
            end
        end

        for spellID, cooldownData in pairs(senderCooldowns or {}) do
            local meta = self:GetEffectiveMeta(senderKey, spellID)
            local endTime = cooldownData and (type(cooldownData) == "table" and cooldownData.endTime or cooldownData) or 0
            if meta and meta.type ~= "INT" and endTime > now then
                AddCandidateSpellID(spellID)
            end
        end
    end

    for _, spellID in ipairs(candidateSpellIDs) do
        local meta = self:GetEffectiveMeta(senderKey, spellID)
        local passesType = meta and ((onlyType and meta.type == onlyType) or (not onlyType and meta.type ~= "INT"))
        if passesType and not onlyType and meta and not self:IsTrackerTypeVisible(meta.type) then
            passesType = false
        end
        local passesClassAndSpec = passesType and self:DoesMetaMatchUnit(meta, senderClass, senderSpecID, senderUnit)

        if passesType and passesClassAndSpec then
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
                isAuraActive = (not isActive) and meta.type == "OFF" and activeAuraSpellIDSet[spellID] == true,
            }
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

function PartyOffCD:AnchorRow(row, rosterEntry)
    row:ClearAllPoints()

    local target = GetCompactPartyAnchor(rosterEntry and rosterEntry.unit, row.index)
    local attach = self:GetTrackerAttach()
    local offsetX = self:GetTrackerOffsetX()
    local offsetY = self:GetTrackerOffsetY()
    row:SetParent(self.trackerFrame)
    if target then
        row.layoutAttach = attach
        row:SetFrameStrata(target:GetFrameStrata() or "MEDIUM")
        row:SetFrameLevel((target:GetFrameLevel() or 1) + 8)

        if attach == "RIGHT" then
            row:SetPoint("LEFT", target, "RIGHT", offsetX, offsetY)
        elseif attach == "CENTER" then
            row:SetPoint("CENTER", target, "CENTER", offsetX, offsetY)
        elseif attach == "TOP" then
            row:SetPoint("BOTTOM", target, "TOP", offsetX, offsetY)
        elseif attach == "BOTTOM" then
            row:SetPoint("TOP", target, "BOTTOM", offsetX, offsetY)
        else
            row:SetPoint("RIGHT", target, "LEFT", offsetX, offsetY)
        end
    else
        row.layoutAttach = attach
        row:SetFrameStrata(self.trackerFrame:GetFrameStrata() or "MEDIUM")
        row:SetFrameLevel((self.trackerFrame:GetFrameLevel() or 1) + 1)
        if row.index == 1 then
            row:SetPoint("TOPLEFT", self.trackerFrame, "TOPLEFT", math.max(0, offsetX + 8), -math.max(0, -offsetY))
        else
            row:SetPoint("TOPLEFT", self.rows[row.index - 1], "BOTTOMLEFT", 0, -8)
        end
    end
end

function PartyOffCD:RenderRow(row, rosterEntry)
    row.label:SetText("")
    self:ReleaseRowIcons(row)

    local entries = self:GetSortedCooldowns(rosterEntry.key)
    local maxIcons = self:GetTrackerMaxIcons()
    if maxIcons > 0 and #entries > maxIcons then
        while #entries > maxIcons do
            tremove(entries)
        end
    end

    if not entries or #entries == 0 then
        self:HideRowActiveAura(row)
        row:Hide()
        return
    end

    row:Show()
    self:AnchorRow(row, rosterEntry)
    self:HideRowActiveAura(row)

    local anchor = self:GetRosterAnchor(rosterEntry.unit, row.index)
    local activeDefensive = self:GetActiveAuraEntry(rosterEntry.key, "DEF")
    if activeDefensive and anchor and anchor:IsShown() then
        local activeFrame = row.activeAuraFrame
        local _, activeTexture = SafeGetSpellInfo(activeDefensive.spellID)
        local size = math.max(18, math.floor(math.min(anchor:GetWidth(), anchor:GetHeight()) * 0.56))
        activeFrame:SetParent(UIParent)
        activeFrame:ClearAllPoints()
        activeFrame:SetPoint("CENTER", anchor, "CENTER", 0, 0)
        activeFrame:SetFrameLevel((anchor:GetFrameLevel() or 1) + 12)
        activeFrame:SetSize(size, size)
        activeFrame.spellID = activeDefensive.spellID
        activeFrame.icon:SetTexture(activeTexture or 134400)
        activeFrame.cooldown:SetCooldown(activeDefensive.startTime, math.max(0, activeDefensive.duration))
        activeFrame:Show()
    end

    local attach = row.layoutAttach or self:GetTrackerAttach()
    local horizontalAttach = attach == "LEFT" or attach == "RIGHT" or attach == "CENTER"
    local iconSize, iconSpacing = self:GetTrackerIconMetrics(row, attach, nil)
    local configuredRows = self:GetTrackerRows()
    local rowWidth
    local rowHeight
    local slotColumns
    local slotRows

    if horizontalAttach then
        slotRows = math.min(configuredRows, #entries)
        slotColumns = math.ceil(#entries / slotRows)
        rowWidth = GetSpanSize(slotColumns, iconSize, iconSpacing)
        rowHeight = GetSpanSize(slotRows, iconSize, iconSpacing)
    else
        slotColumns = math.min(configuredRows, #entries)
        slotRows = math.ceil(#entries / slotColumns)
        rowWidth = GetSpanSize(slotColumns, iconSize, iconSpacing)
        rowHeight = GetSpanSize(slotRows, iconSize, iconSpacing)
    end

    row:SetSize(rowWidth, rowHeight)

    for iconIndex, entry in ipairs(entries) do
        local icon = self:AcquireIcon(row)
        local _, texture = SafeGetSpellInfo(entry.spellID)
        local slotX
        local slotY

        if horizontalAttach then
            local rowIndex = math.floor((iconIndex - 1) / slotColumns)
            local columnIndex = (iconIndex - 1) % slotColumns
            slotX = columnIndex * (iconSize + iconSpacing)
            slotY = rowIndex * (iconSize + iconSpacing)
        else
            local columnIndex = (iconIndex - 1) % slotColumns
            local rowIndex = math.floor((iconIndex - 1) / slotColumns)
            slotX = columnIndex * (iconSize + iconSpacing)
            slotY = rowIndex * (iconSize + iconSpacing)
        end

        icon:SetSize(iconSize, iconSize)
        icon.spellID = entry.spellID
        icon.baseCD = entry.meta.cd
        icon.texture:SetTexture(texture or 134400)
        icon.typeText:SetText("")
        if icon.cooldown.SetReverse then
            icon.cooldown:SetReverse(self:IsTrackerReverseCooldownEnabled())
        end
        local showAuraGlow = entry.isAuraActive == true
        local glowSize = math.floor(iconSize * 1.7)
        if entry.isActive then
            icon:SetAlpha(0.95)
            icon.texture:SetVertexColor(0.62, 0.62, 0.62, 1)
            if icon.texture.SetDesaturated then
                icon.texture:SetDesaturated(true)
            end
            icon.timeText:SetText(FormatRemaining(entry.remaining))
            icon.cooldown:SetCooldown(entry.endTime - entry.duration, entry.duration)
        else
            icon:SetAlpha(1)
            icon.texture:SetVertexColor(1, 1, 1, 1)
            if icon.texture.SetDesaturated then
                icon.texture:SetDesaturated(false)
            end
            icon.timeText:SetText("")
            icon.cooldown:SetCooldown(0, 0)
        end
        if icon.activeGlow then
            icon.activeGlow:SetSize(glowSize, glowSize)
            icon.activeGlow:SetShown(showAuraGlow)
        end
        if icon.activeGlowOver then
            icon.activeGlowOver:SetSize(glowSize, glowSize)
            icon.activeGlowOver:SetShown(showAuraGlow)
        end

        local iconX = 0
        local iconTop = 0
        if attach == "RIGHT" then
            iconX = slotX
            iconTop = slotY
        elseif attach == "LEFT" then
            iconX = rowWidth - iconSize - slotX
            iconTop = slotY
        elseif attach == "CENTER" then
            iconX = slotX
            iconTop = slotY
        elseif attach == "TOP" then
            iconX = slotX
            iconTop = rowHeight - iconSize - slotY
        else
            iconX = slotX
            iconTop = slotY
        end
        icon:SetPoint("TOPLEFT", row, "TOPLEFT", iconX, -iconTop)

        row.icons[iconIndex] = icon
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
    frame.bg = bg

    local borderTop = frame:CreateTexture(nil, "BORDER")
    borderTop:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    borderTop:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    borderTop:SetHeight(1)
    borderTop:SetColorTexture(0.95, 0.82, 0.2, 0.9)
    frame.borderTop = borderTop

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOP", frame, "TOP", 0, -6)
    title:SetText("Interrupts")
    title:SetTextColor(1, 0.85, 0.15)
    frame.title = title

    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
    closeButton:SetScript("OnClick", function()
        PartyOffCD:SetInterruptHidden(true)
    end)
    frame.closeButton = closeButton

    local lockButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    lockButton:SetSize(18, 18)
    lockButton:SetPoint("RIGHT", closeButton, "LEFT", -2, 0)
    lockButton:SetText("L")
    lockButton:SetScript("OnClick", function()
        PartyOffCD:SetInterruptLocked(true)
        PartyOffCD:RefreshConfigPanel()
    end)
    frame.lockButton = lockButton

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
    self:UpdateInterruptFrameStyle()
end

function PartyOffCD:SetInterruptHidden(hidden)
    self.db.interruptHidden = hidden and true or false
    self:RefreshInterruptBar()
end

function PartyOffCD:SetInterruptLocked(locked)
    self.db.interruptLocked = locked and true or false
    self:UpdateInterruptFrameStyle()
    self:RefreshInterruptBar()
end

function PartyOffCD:UpdateInterruptFrameStyle()
    if not self.interruptFrame then
        return
    end

    local locked = self.db and self.db.interruptLocked
    self.interruptFrame:SetMovable(not locked)
    self.interruptFrame:EnableMouse(not locked)

    if self.interruptFrame.bg then
        self.interruptFrame.bg:SetShown(not locked)
    end
    if self.interruptFrame.borderTop then
        self.interruptFrame.borderTop:SetShown(not locked)
    end
    if self.interruptFrame.title then
        self.interruptFrame.title:SetShown(not locked)
    end
    if self.interruptFrame.closeButton then
        self.interruptFrame.closeButton:SetShown(not locked)
    end
    if self.interruptFrame.lockButton then
        self.interruptFrame.lockButton:SetShown(not locked)
    end
    if self.interruptFrame.emptyText then
        self.interruptFrame.emptyText:SetShown(not locked)
    end
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
    local fallback = nil
    for _, entry in ipairs(entries) do
        if not fallback then
            fallback = entry
        end
        if entry.isActive then
            return entry
        end
    end

    return fallback
end

function PartyOffCD:RenderInterruptRow(row, rosterEntry, entry)
    local _, texture = SafeGetSpellInfo(entry.spellID)
    local classColor = RAID_CLASS_COLORS and RAID_CLASS_COLORS[rosterEntry.class] or nil
    local remaining = math.max(0, entry.remaining or 0)
    local duration = math.max(1, entry.duration or entry.meta.cd or 1)

    local topOffset = (self.db and self.db.interruptLocked) and -4 or -24
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", self.interruptFrame, "TOPLEFT", 6, topOffset - ((row.index - 1) * (INTERRUPT_ROW_HEIGHT + 2)))
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
    if not self:IsEnabledForCurrentContext() then
        if not self.interruptFrame then
            return
        end
        self.interruptFrame:Hide()
        for _, row in ipairs(self.interruptRows) do
            row:Hide()
        end
        return
    end

    self:CreateInterruptFrame()

    self:UpdateInterruptFrameStyle()

    if self.db and self.db.interruptHidden then
        self.interruptFrame:Hide()
        for _, row in ipairs(self.interruptRows) do
            row:Hide()
        end
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
        if self.db and self.db.interruptLocked then
            self.interruptFrame:Hide()
            return
        end
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
    local headerHeight = (self.db and self.db.interruptLocked) and 8 or 28
    self.interruptFrame:SetHeight(headerHeight + (activeCount * (INTERRUPT_ROW_HEIGHT + 2)))
    self.interruptFrame:Show()
end

function PartyOffCD:GetMissingBuffEntries()
    if not self:HasTrackedPartyMembers() and not IsInRaid() then
        return {}
    end

    local classInRoster = {}
    for _, rosterEntry in ipairs(self.roster) do
        if rosterEntry.class then
            classInRoster[rosterEntry.class] = true
        end
    end

    -- In raid the tracker roster is intentionally empty; scan raid units directly
    if IsInRaid() and not next(classInRoster) then
        for i = 1, GetNumGroupMembers() do
            local _, classToken = UnitClass("raid" .. i)
            if classToken then
                classInRoster[classToken] = true
            end
        end
    end

    local missingEntries = {}
    for _, definition in ipairs(MISSING_BUFFS) do
        if classInRoster[definition.class] then
            local spellID = ResolveMissingBuffSpellID(definition)
            if spellID then
                if not UnitHasBuffFromDefinition("player", definition) then
                    missingEntries[#missingEntries + 1] = {
                        class = definition.class,
                        spellID = spellID,
                    }
                end
            end
        end
    end

    return missingEntries
end

function PartyOffCD:CreateMissingBuffFrame()
    if self.missingBuffFrame then
        return
    end

    local frame = CreateFrame("Frame", "PartyOffCDMissingBuffFrame", UIParent)
    frame:SetSize(140, 64)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(selfFrame)
        selfFrame:StopMovingOrSizing()
        local point, _, relativePoint, x, y = selfFrame:GetPoint(1)
        PartyOffCD.db.missingBuffPoint = point
        PartyOffCD.db.missingBuffRelativePoint = relativePoint
        PartyOffCD.db.missingBuffX = x
        PartyOffCD.db.missingBuffY = y
    end)

    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.08, 0.08, 0.10, 0.90)
    frame.bg = bg

    local borderTop = frame:CreateTexture(nil, "BORDER")
    borderTop:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    borderTop:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    borderTop:SetHeight(1)
    borderTop:SetColorTexture(0.95, 0.82, 0.2, 0.9)
    frame.borderTop = borderTop

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -6)
    title:SetText("Missing Buffs")
    title:SetTextColor(1, 0.85, 0.15)
    frame.title = title

    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
    closeButton:SetScript("OnClick", function()
        PartyOffCD:SetMissingBuffsHidden(true)
    end)
    frame.closeButton = closeButton

    local lockButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    lockButton:SetSize(18, 18)
    lockButton:SetPoint("RIGHT", closeButton, "LEFT", -2, 0)
    lockButton:SetText("L")
    lockButton:SetScript("OnClick", function()
        PartyOffCD:SetMissingBuffsLocked(true)
        PartyOffCD:RefreshConfigPanel()
    end)
    frame.lockButton = lockButton

    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -22)
    content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 8)
    frame.content = content

    local db = self.db or DB_DEFAULTS
    frame:SetPoint(
        db.missingBuffPoint or DB_DEFAULTS.missingBuffPoint,
        UIParent,
        db.missingBuffRelativePoint or DB_DEFAULTS.missingBuffRelativePoint,
        db.missingBuffX or DB_DEFAULTS.missingBuffX,
        db.missingBuffY or DB_DEFAULTS.missingBuffY
    )

    self.missingBuffFrame = frame
    self:UpdateMissingBuffFrameStyle()
end

function PartyOffCD:SetMissingBuffsHidden(hidden)
    self.db.missingBuffsHidden = hidden and true or false
    self:RefreshMissingBuffFrame()
end

function PartyOffCD:SetMissingBuffsLocked(locked)
    self.db.missingBuffsLocked = locked and true or false
    self:UpdateMissingBuffFrameStyle()
    self:RefreshMissingBuffFrame()
end

function PartyOffCD:UpdateMissingBuffFrameStyle()
    if not self.missingBuffFrame then
        return
    end

    local locked = self.db and self.db.missingBuffsLocked
    self.missingBuffFrame:SetMovable(not locked)
    self.missingBuffFrame:EnableMouse(not locked)

    if self.missingBuffFrame.bg then
        self.missingBuffFrame.bg:SetShown(not locked)
    end
    if self.missingBuffFrame.borderTop then
        self.missingBuffFrame.borderTop:SetShown(not locked)
    end
    if self.missingBuffFrame.title then
        self.missingBuffFrame.title:SetShown(not locked)
    end
    if self.missingBuffFrame.closeButton then
        self.missingBuffFrame.closeButton:SetShown(not locked)
    end
    if self.missingBuffFrame.lockButton then
        self.missingBuffFrame.lockButton:SetShown(not locked)
    end

    if self.missingBuffFrame.content then
        self.missingBuffFrame.content:ClearAllPoints()
        if locked then
            self.missingBuffFrame.content:SetPoint("TOPLEFT", self.missingBuffFrame, "TOPLEFT", 4, -4)
            self.missingBuffFrame.content:SetPoint("BOTTOMRIGHT", self.missingBuffFrame, "BOTTOMRIGHT", -4, 4)
        else
            self.missingBuffFrame.content:SetPoint("TOPLEFT", self.missingBuffFrame, "TOPLEFT", 8, -22)
            self.missingBuffFrame.content:SetPoint("BOTTOMRIGHT", self.missingBuffFrame, "BOTTOMRIGHT", -8, 8)
        end
    end
end

function PartyOffCD:AcquireMissingBuffIcon(parent)
    local iconFrame = tremove(self.missingBuffIconPool)
    if iconFrame then
        iconFrame:SetParent(parent)
        iconFrame:Show()
        return iconFrame
    end

    iconFrame = CreateFrame("Frame", nil, parent)
    iconFrame:SetSize(MISSING_BUFF_ICON_SIZE, MISSING_BUFF_ICON_SIZE + 16)
    iconFrame:EnableMouse(true)

    local iconBg = iconFrame:CreateTexture(nil, "BACKGROUND")
    iconBg:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", 0, 0)
    iconBg:SetSize(MISSING_BUFF_ICON_SIZE, MISSING_BUFF_ICON_SIZE)
    iconBg:SetColorTexture(0.04, 0.04, 0.04, 0.95)
    iconFrame.iconBg = iconBg

    local texture = iconFrame:CreateTexture(nil, "ARTWORK")
    texture:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", 2, -2)
    texture:SetSize(MISSING_BUFF_ICON_SIZE - 4, MISSING_BUFF_ICON_SIZE - 4)
    texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    iconFrame.texture = texture

    local missingText = iconFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    missingText:SetPoint("TOP", texture, "BOTTOM", 0, -1)
    missingText:SetText("MISSING")
    iconFrame.missingText = missingText

    iconFrame:SetScript("OnEnter", function(button)
        if not button.spellID then
            return
        end
        GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
        GameTooltip:SetSpellByID(button.spellID)
        GameTooltip:AddLine("Missing in group", 1, 0.25, 0.25)
        GameTooltip:Show()
    end)

    iconFrame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    return iconFrame
end

function PartyOffCD:ReleaseMissingBuffIcons()
    for _, iconFrame in ipairs(self.missingBuffIcons) do
        iconFrame:Hide()
        iconFrame:ClearAllPoints()
        iconFrame:SetParent(UIParent)
        iconFrame.spellID = nil
        iconFrame.texture:SetTexture(nil)
        tinsert(self.missingBuffIconPool, iconFrame)
    end

    wipe(self.missingBuffIcons)
end

function PartyOffCD:HideAllTrackerFrames()
    if self.trackerFrame then
        self.trackerFrame:Hide()
    end
    if self.interruptFrame then
        self.interruptFrame:Hide()
    end
    if self.missingBuffFrame then
        self.missingBuffFrame:Hide()
    end

    for _, row in ipairs(self.interruptRows) do
        row:Hide()
    end

    for _, row in ipairs(self.rows) do
        if row then
            self:ReleaseRowIcons(row)
            self:HideRowActiveAura(row)
            row:Hide()
        end
    end

    self:ReleaseMissingBuffIcons()

    for _, alert in pairs(self.cooldownAlerts or {}) do
        if alert then
            alert:Hide()
        end
    end
end

function PartyOffCD:RefreshMissingBuffFrame()
    if not self:IsEnabledForCurrentContext() then
        if not self.missingBuffFrame then
            return
        end
        self:ReleaseMissingBuffIcons()
        self.missingBuffFrame:Hide()
        return
    end

    self:CreateMissingBuffFrame()

    self:UpdateMissingBuffFrameStyle()

    self:ReleaseMissingBuffIcons()

    if not self.db or self.db.missingBuffsHidden then
        self.missingBuffFrame:Hide()
        return
    end

    local missingEntries = self:GetMissingBuffEntries()
    if #missingEntries == 0 then
        self.missingBuffFrame:Hide()
        return
    end

    for index, entry in ipairs(missingEntries) do
        local iconFrame = self:AcquireMissingBuffIcon(self.missingBuffFrame.content)
        local _, texture = SafeGetSpellInfo(entry.spellID)
        iconFrame.spellID = entry.spellID
        iconFrame.texture:SetTexture(texture or 134400)

        if index == 1 then
            iconFrame:SetPoint("TOPLEFT", self.missingBuffFrame.content, "TOPLEFT", 0, 0)
        else
            iconFrame:SetPoint("LEFT", self.missingBuffIcons[index - 1], "RIGHT", MISSING_BUFF_ICON_SPACING, 0)
        end

        self.missingBuffIcons[index] = iconFrame
    end

    local width = 16 + (#missingEntries * MISSING_BUFF_ICON_SIZE) + ((#missingEntries - 1) * MISSING_BUFF_ICON_SPACING)
    local locked = self.db and self.db.missingBuffsLocked
    self.missingBuffFrame:SetWidth(math.max(locked and 48 or 120, width))
    self.missingBuffFrame:SetHeight(locked and 52 or 64)
    self.missingBuffFrame:Show()
end

function PartyOffCD:RefreshTracker()
    self:PruneState()

    if not self:IsEnabledForCurrentContext() then
        self:HideAllTrackerFrames()
        return
    end

    if not self:HasTrackedPartyMembers() then
        self:HideAllTrackerFrames()
        return
    end

    self:BuildRoster()

    if #self.roster == 0 then
        self:HideAllTrackerFrames()
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

    self:RefreshInterruptBar()
    self:RefreshMissingBuffFrame()
end
