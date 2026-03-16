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
local MAX_AURA_SCAN = 255
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
local ResolveSpecValue = PartyOffCDCore.ResolveSpecValue
local FormatRemaining = PartyOffCDCore.FormatRemaining
local GetUnitFullName = PartyOffCDCore.GetUnitFullName
local NormalizeName = PartyOffCDCore.NormalizeName
local ApplyLightOutline = PartyOffCDCore.ApplyLightOutline

local function IsValidTrackerAttach(attach)
    return attach == "LEFT" or attach == "RIGHT" or attach == "TOP" or attach == "BOTTOM"
end

local function NormalizeTrackerAttach(attach)
    attach = string.upper(tostring(attach or ""))
    if not IsValidTrackerAttach(attach) then
        return "LEFT"
    end
    return attach
end

local function IsValidTrackerAnchorSource(source)
    return source == "BLIZZARD" or source == "DANDERS"
end

local function NormalizeTrackerAnchorSource(source)
    source = string.upper(tostring(source or ""))
    if not IsValidTrackerAnchorSource(source) then
        return "BLIZZARD"
    end
    return source
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

local function ToSafeNumber(value)
    if value == nil then
        return nil
    end

    local ok, parsed = pcall(function()
        return tonumber(tostring(value))
    end)
    if ok then
        return parsed
    end

    return nil
end

local function AuraDataMatches(auraData, targetSpellID)
    if not auraData then
        return false
    end

    local auraSpellID = ToSafeNumber(auraData.spellId or auraData.spellID)
    if targetSpellID and auraSpellID and auraSpellID == targetSpellID then
        return true
    end

    return false
end

local function UnitHasBuffFromAuraDataIndex(unit, targetSpellID)
    if not C_UnitAuras then
        return false
    end

    if C_UnitAuras.GetBuffDataByIndex then
        for index = 1, MAX_AURA_SCAN do
            local ok, auraData = pcall(C_UnitAuras.GetBuffDataByIndex, unit, index)
            if not ok then
                break
            end
            if not auraData then
                break
            end
            if AuraDataMatches(auraData, targetSpellID) then
                return true
            end
        end
    end

    if C_UnitAuras.GetAuraDataByIndex then
        for index = 1, MAX_AURA_SCAN do
            local ok, auraData = pcall(C_UnitAuras.GetAuraDataByIndex, unit, index, "HELPFUL")
            if not ok then
                break
            end
            if not auraData then
                break
            end
            if AuraDataMatches(auraData, targetSpellID) then
                return true
            end
        end
    end

    return false
end

local function UnitHasBuffFromSpellID(unit, spellID)
    local targetSpellID = ToSafeNumber(spellID)
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

    if UnitHasBuffFromAuraDataIndex(unit, targetSpellID) then
        return true
    end

    if UnitAura then
        for index = 1, MAX_AURA_SCAN do
            local auraName, _, _, _, _, _, _, _, _, auraSpellID = UnitAura(unit, index, "HELPFUL")
            if not auraName then
                break
            end
            auraSpellID = ToSafeNumber(auraSpellID)
            if auraSpellID and auraSpellID == targetSpellID then
                return true
            end
        end
    end

    if UnitBuff then
        for index = 1, MAX_AURA_SCAN do
            local auraName, _, _, _, _, _, _, _, _, auraSpellID = UnitBuff(unit, index)
            if not auraName then
                break
            end
            auraSpellID = ToSafeNumber(auraSpellID)
            if auraSpellID and auraSpellID == targetSpellID then
                return true
            end
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
    else
        units[#units + 1] = "player"
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

local function GetDandersFramesTrackerAnchor()
    local dandersFrames = rawget(_G, "DandersFrames")
    if not dandersFrames then
        return nil
    end

    local partyAnchor = dandersFrames.partyContainer or dandersFrames.container
    local raidAnchor = dandersFrames.raidContainer

    -- Match DandersFrames usage: prefer party/header container, then legacy container, then raid.
    if partyAnchor and (not partyAnchor.IsShown or partyAnchor:IsShown()) then
        return partyAnchor
    end

    if raidAnchor and (not raidAnchor.IsShown or raidAnchor:IsShown()) then
        return raidAnchor
    end

    if partyAnchor then
        return partyAnchor
    end

    if raidAnchor then
        return raidAnchor
    end

    return nil
end

local function GetDandersFramesUnitAnchor(unit)
    local dandersFrames = rawget(_G, "DandersFrames")
    if not dandersFrames or not unit then
        return nil
    end

    if unit == "player" and dandersFrames.GetPlayerFrame then
        local ok, frame = pcall(dandersFrames.GetPlayerFrame, dandersFrames)
        if ok and frame and (not frame.IsShown or frame:IsShown()) then
            return frame
        end
    end

    local partyIndex = tonumber(unit:match("^party(%d+)$"))
    if partyIndex and dandersFrames.GetPartyFrame then
        local ok, frame = pcall(dandersFrames.GetPartyFrame, dandersFrames, partyIndex)
        if ok and frame and (not frame.IsShown or frame:IsShown()) then
            return frame
        end
    end

    local raidIndex = tonumber(unit:match("^raid(%d+)$"))
    if raidIndex then
        if dandersFrames.GetRaidFrame then
            local ok, frame = pcall(dandersFrames.GetRaidFrame, dandersFrames, raidIndex)
            if ok and frame and (not frame.IsShown or frame:IsShown()) then
                return frame
            end
        end
        if type(dandersFrames.raidFrames) == "table" then
            local frame = dandersFrames.raidFrames[raidIndex]
            if frame and (not frame.IsShown or frame:IsShown()) then
                return frame
            end
        end
    end

    if partyIndex and type(dandersFrames.partyFrames) == "table" then
        local frame = dandersFrames.partyFrames[partyIndex]
        if frame and (not frame.IsShown or frame:IsShown()) then
            return frame
        end
    end

    return nil
end

local function GetDandersFramesTrackedWidth(unit)
    local unitFrame = GetDandersFramesUnitAnchor(unit)
    if unitFrame and unitFrame.GetWidth then
        local width = unitFrame:GetWidth() or 0
        if width > 0 then
            return width
        end
    end

    local dandersFrames = rawget(_G, "DandersFrames")
    if not dandersFrames then
        return nil
    end

    if dandersFrames.GetDB then
        local ok, partyDB = pcall(dandersFrames.GetDB, dandersFrames)
        if ok and type(partyDB) == "table" then
            local width = tonumber(partyDB.frameWidth)
            if width and width > 0 then
                return width
            end
        end
    end

    local dbWidth = dandersFrames.db
        and dandersFrames.db.party
        and tonumber(dandersFrames.db.party.frameWidth)
    if dbWidth and dbWidth > 0 then
        return dbWidth
    end

    local defaultWidth = dandersFrames.PartyDefaults and tonumber(dandersFrames.PartyDefaults.frameWidth)
    if defaultWidth and defaultWidth > 0 then
        return defaultWidth
    end

    return 125
end

local function SetFramePointForTrackerAttach(frame, target, attach, gap)
    attach = NormalizeTrackerAttach(attach)
    gap = gap or 8

    if attach == "RIGHT" then
        frame:SetPoint("TOPLEFT", target, "TOPRIGHT", gap, 0)
    elseif attach == "TOP" then
        frame:SetPoint("BOTTOMLEFT", target, "TOPLEFT", 0, gap)
    elseif attach == "BOTTOM" then
        frame:SetPoint("TOPLEFT", target, "BOTTOMLEFT", 0, -gap)
    else
        frame:SetPoint("TOPRIGHT", target, "TOPLEFT", -gap, 0)
    end
end

function PartyOffCD:GetTrackerAttach()
    local dbAttach = self.db and self.db.trackerAttach
    local defaultAttach = (DB_DEFAULTS and DB_DEFAULTS.trackerAttach) or "LEFT"
    return NormalizeTrackerAttach(dbAttach or defaultAttach)
end

function PartyOffCD:GetTrackerAnchorSource()
    local dbSource = self.db and self.db.trackerAnchorSource
    local defaultSource = (DB_DEFAULTS and DB_DEFAULTS.trackerAnchorSource) or "BLIZZARD"
    return NormalizeTrackerAnchorSource(dbSource or defaultSource)
end

function PartyOffCD:ShouldUseDandersFramesTracker()
    if self:GetTrackerAnchorSource() ~= "DANDERS" then
        return false
    end

    return GetDandersFramesTrackerAnchor() ~= nil
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

function PartyOffCD:SetTrackerAnchorSource(source)
    if not self.db then
        return false
    end

    local normalized = NormalizeTrackerAnchorSource(source)
    if self.db.trackerAnchorSource == normalized then
        return false
    end

    self.db.trackerAnchorSource = normalized
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

function PartyOffCD:UpdateTrackerFrameAnchor()
    if not self.trackerFrame then
        return false
    end

    self.trackerFrame:ClearAllPoints()

    local externalAnchor = self:ShouldUseDandersFramesTracker() and GetDandersFramesTrackerAnchor() or nil
    if externalAnchor then
        SetFramePointForTrackerAttach(self.trackerFrame, externalAnchor, self:GetTrackerAttach(), 8)
        return true
    end

    self.trackerFrame:SetPoint("LEFT", UIParent, "LEFT", FALLBACK_X, FALLBACK_Y)
    return false
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
    row:SetSize(ICON_SIZE, ICON_SIZE)
    row.index = index
    row.icons = {}
    row.layoutAttach = "LEFT"

    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.label:SetPoint("RIGHT", row, "LEFT", -6, 0)
    row.label:SetJustifyH("RIGHT")
    row.label:SetWidth(90)
    row.label:Hide()

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

function PartyOffCD:AnchorRow(row, rosterEntry)
    local index = row.index or 1
    row:ClearAllPoints()

    if self:ShouldUseDandersFramesTracker() then
        local attach = self:GetTrackerAttach()
        row.layoutAttach = attach

        local unitTarget = rosterEntry and GetDandersFramesUnitAnchor(rosterEntry.unit) or nil
        if unitTarget then
            row:SetParent(unitTarget)
            if attach == "RIGHT" then
                row:SetPoint("TOPLEFT", unitTarget, "TOPRIGHT", 4, 0)
            elseif attach == "TOP" then
                row:SetPoint("BOTTOMLEFT", unitTarget, "TOPLEFT", 0, 4)
            elseif attach == "BOTTOM" then
                row:SetPoint("TOPLEFT", unitTarget, "BOTTOMLEFT", 0, -4)
            else
                row:SetPoint("TOPRIGHT", unitTarget, "TOPLEFT", -4, 0)
            end
        else
            row:SetParent(self.trackerFrame)
            if attach == "LEFT" then
                if index == 1 then
                    row:SetPoint("TOPRIGHT", self.trackerFrame, "TOPRIGHT", 0, 0)
                else
                    row:SetPoint("TOPRIGHT", self.rows[index - 1], "BOTTOMRIGHT", 0, -8)
                end
            else
                if index == 1 then
                    row:SetPoint("TOPLEFT", self.trackerFrame, "TOPLEFT", 0, 0)
                else
                    row:SetPoint("TOPLEFT", self.rows[index - 1], "BOTTOMLEFT", 0, -8)
                end
            end
        end
        return
    end

    local target = GetCompactPartyAnchor(index)
    if target then
        local attach = self:GetTrackerAttach()
        row.layoutAttach = attach
        row:SetParent(target)

        if attach == "RIGHT" then
            row:SetPoint("TOPLEFT", target, "TOPRIGHT", 4, 0)
        elseif attach == "TOP" then
            row:SetPoint("BOTTOMLEFT", target, "TOPLEFT", 0, 4)
        elseif attach == "BOTTOM" then
            row:SetPoint("TOPLEFT", target, "BOTTOMLEFT", 0, -4)
        else
            row:SetPoint("TOPRIGHT", target, "TOPLEFT", -4, 0)
        end
    else
        row.layoutAttach = "LEFT"
        row:SetParent(self.trackerFrame)
        if index == 1 then
            row:SetPoint("TOPLEFT", self.trackerFrame, "TOPLEFT", 0, 0)
        else
            row:SetPoint("TOPLEFT", self.rows[index - 1], "BOTTOMLEFT", 0, -8)
        end
    end
end

function PartyOffCD:RenderRow(row, rosterEntry)
    row.label:SetText("")
    self:ReleaseRowIcons(row)

    local entries = self:GetSortedCooldowns(rosterEntry.key)
    if not entries or #entries == 0 then
        row:Hide()
        return
    end

    row:Show()
    self:AnchorRow(row, rosterEntry)

    local attach = row.layoutAttach or self:GetTrackerAttach()
    local horizontalAttach = attach == "LEFT" or attach == "RIGHT"
    local iconSize, iconSpacing = self:GetTrackerIconMetrics(row, attach, horizontalAttach and 1 or nil)
    local fillWidthBeforeWrap = self:ShouldUseDandersFramesTracker() and (not horizontalAttach)

    local groupedEntries = {}
    if fillWidthBeforeWrap then
        groupedEntries[1] = {
            type = "ALL",
            entries = entries,
        }
    else
        local currentGroup = nil
        for _, entry in ipairs(entries) do
            local entryType = entry.meta and entry.meta.type or "OFF"
            if not currentGroup or currentGroup.type ~= entryType then
                currentGroup = {
                    type = entryType,
                    entries = {},
                }
                groupedEntries[#groupedEntries + 1] = currentGroup
            end
            currentGroup.entries[#currentGroup.entries + 1] = entry
        end
    end

    local slots = {}
    local awayOffset = 0
    local maxCrossSize = iconSize
    for groupIndex, group in ipairs(groupedEntries) do
        local groupCount = #group.entries
        local columns = self:GetTrackerGroupColumns(row, attach, groupCount, iconSize, iconSpacing)
        local sectionAwaySize
        local sectionCrossSize

        if horizontalAttach then
            local awaySlots = math.min(columns, groupCount)
            local crossSlots = math.ceil(groupCount / columns)
            sectionAwaySize = GetSpanSize(awaySlots, iconSize, iconSpacing)
            sectionCrossSize = GetSpanSize(crossSlots, iconSize, iconSpacing)

            for entryIndex, entry in ipairs(group.entries) do
                local awayIndex = (entryIndex - 1) % columns
                local crossIndex = math.floor((entryIndex - 1) / columns)
                slots[#slots + 1] = {
                    entry = entry,
                    away = awayOffset + (awayIndex * (iconSize + iconSpacing)),
                    cross = crossIndex * (iconSize + iconSpacing),
                }
            end
        else
            local crossSlots = math.min(columns, groupCount)
            local awaySlots = math.ceil(groupCount / columns)
            sectionCrossSize = GetSpanSize(crossSlots, iconSize, iconSpacing)
            sectionAwaySize = GetSpanSize(awaySlots, iconSize, iconSpacing)

            for entryIndex, entry in ipairs(group.entries) do
                local crossIndex = (entryIndex - 1) % columns
                local awayIndex = math.floor((entryIndex - 1) / columns)
                slots[#slots + 1] = {
                    entry = entry,
                    away = awayOffset + (awayIndex * (iconSize + iconSpacing)),
                    cross = crossIndex * (iconSize + iconSpacing),
                }
            end
        end

        if sectionCrossSize > maxCrossSize then
            maxCrossSize = sectionCrossSize
        end

        awayOffset = awayOffset + sectionAwaySize
        if (not fillWidthBeforeWrap) and groupIndex < #groupedEntries then
            awayOffset = awayOffset + TRACKER_TYPE_GAP
        end
    end

    local totalAwaySize = math.max(iconSize, awayOffset)
    local totalCrossSize = math.max(iconSize, maxCrossSize)
    local rowWidth, rowHeight
    if horizontalAttach then
        rowWidth = totalAwaySize
        rowHeight = totalCrossSize
    else
        rowWidth = totalCrossSize
        rowHeight = totalAwaySize
    end

    if self:ShouldUseDandersFramesTracker() then
        local parentFrame = row:GetParent()
        local trackedWidth = nil

        if parentFrame and parentFrame ~= self.trackerFrame and parentFrame.GetWidth then
            local width = parentFrame:GetWidth() or 0
            if width > 0 then
                trackedWidth = width
            end
        end

        if not trackedWidth then
            trackedWidth = GetDandersFramesTrackedWidth(rosterEntry and rosterEntry.unit)
        end

        if trackedWidth and trackedWidth > 0 then
            rowWidth = trackedWidth
        end
    end

    row:SetSize(rowWidth, rowHeight)

    for iconIndex, slot in ipairs(slots) do
        local entry = slot.entry
        local icon = self:AcquireIcon(row)
        local _, texture = SafeGetSpellInfo(entry.spellID)

        icon:SetSize(iconSize, iconSize)
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

        local iconX = 0
        local iconTop = 0
        if attach == "RIGHT" then
            iconX = slot.away
            iconTop = slot.cross
        elseif attach == "LEFT" then
            iconX = rowWidth - iconSize - slot.away
            iconTop = slot.cross
        elseif attach == "TOP" then
            iconX = slot.cross
            iconTop = rowHeight - iconSize - slot.away
        else
            iconX = slot.cross
            iconTop = slot.away
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
    if not self.interruptFrame then
        return
    end

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
        if self:HasAddon(rosterEntry.key) then
            local entry = self:GetActiveInterruptEntry(rosterEntry.key)
            if entry then
                activeCount = activeCount + 1
                local row = self:GetInterruptRow(activeCount)
                self:RenderInterruptRow(row, rosterEntry, entry)
            end
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
    if not IsInGroup() and not IsInRaid() then
        return {}
    end

    local classInRoster = {}
    for _, rosterEntry in ipairs(self.roster) do
        if rosterEntry.class then
            classInRoster[rosterEntry.class] = true
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

    iconFrame = CreateFrame("Button", nil, parent)
    iconFrame:SetSize(MISSING_BUFF_ICON_SIZE, MISSING_BUFF_ICON_SIZE + 16)

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

function PartyOffCD:RefreshMissingBuffFrame()
    if not self.missingBuffFrame then
        return
    end

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

    self:BuildRoster()

    if #self.roster == 0 then
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
        self:ReleaseMissingBuffIcons()
        return
    end

    self:CreateTrackerFrame()
    self:CreateInterruptFrame()
    self:CreateMissingBuffFrame()
    self:UpdateTrackerFrameAnchor()
    self.trackerFrame:Show()

    for index, entry in ipairs(self.roster) do
        local row = self:GetRow(index)
        if self:HasAddon(entry.key) then
            self:RenderRow(row, entry)
        else
            self:ReleaseRowIcons(row)
            row:Hide()
        end
    end

    for index = (#self.roster + 1), #self.rows do
        local row = self.rows[index]
        self:ReleaseRowIcons(row)
        row:Hide()
    end

    self:RefreshInterruptBar()
    self:RefreshMissingBuffFrame()
end

