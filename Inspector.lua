local _, PartyOffCDCore = ...

PartyOffCDCore = PartyOffCDCore or _G.PartyOffCDCore or {}
_G.PartyOffCDCore = PartyOffCDCore

local M = PartyOffCDCore.SpecInspector or {}
PartyOffCDCore.SpecInspector = M

local INSPECT_INTERVAL = 0.5
local INSPECT_TIMEOUT = 10
local CACHE_RETRY_DELAY = 60
local CACHE_EXPIRY = 60 * 60 * 24 * 3

local guidToSpec = {}
local callbacks = {}
local priorityUnits = {}
local requestedUnit = nil
local currentInspectUnit = nil
local inspectStarted = nil
local needUpdate = true
local isOurInspect = false
local initialized = false

local function IsSecretValue(value)
    return type(issecretvalue) == "function" and issecretvalue(value)
end

local function Now()
    return (GetTimePreciseSec and GetTimePreciseSec()) or GetTime()
end

local function SafeUnitGUID(unit)
    local guid = UnitGUID(unit)
    if not guid or IsSecretValue(guid) then
        return nil
    end
    return guid
end

local function FireCallbacks()
    for _, callback in ipairs(callbacks) do
        pcall(callback)
    end
end

local tooltipSpecMap = nil

local function GetTooltipSpecMap()
    if tooltipSpecMap then
        return tooltipSpecMap
    end

    tooltipSpecMap = {}

    if not (GetNumClasses and GetClassInfo and GetNumSpecializationsForClassID and GetSpecializationInfoForClassID) then
        return tooltipSpecMap
    end

    for classIndex = 1, GetNumClasses() do
        local className, _, classID = GetClassInfo(classIndex)
        if className and classID then
            for specIndex = 1, GetNumSpecializationsForClassID(classID) do
                local specID, specName = GetSpecializationInfoForClassID(classID, specIndex)
                if specID and specName then
                    tooltipSpecMap[specName .. " " .. className] = specID
                end
            end
        end
    end

    return tooltipSpecMap
end

local function SpecFromTooltip(unit)
    if not (C_TooltipInfo and C_TooltipInfo.GetUnit) then
        return nil
    end

    local tooltipData = C_TooltipInfo.GetUnit(unit)
    if not tooltipData or not tooltipData.lines then
        return nil
    end

    local specMap = GetTooltipSpecMap()

    for _, line in ipairs(tooltipData.lines) do
        local leftText = line and line.leftText
        if leftText and not IsSecretValue(leftText) then
            local specID = specMap[leftText]
            if specID then
                return specID
            end
        end
    end

    return nil
end

local function PurgeOldEntries()
    local now = Now()
    for guid, entry in pairs(guidToSpec) do
        if not entry or type(entry) ~= "table" or not entry.LastSeen or (now - entry.LastSeen) > CACHE_EXPIRY then
            guidToSpec[guid] = nil
        end
    end
end

local function EnsureCacheEntry(unit)
    local guid = SafeUnitGUID(unit)
    if not guid then
        return nil
    end

    if not guidToSpec[guid] then
        guidToSpec[guid] = {}
    end

    return guidToSpec[guid]
end

local function GetFriendlyUnits()
    if IsInRaid() then
        return {}
    end

    local units = {}
    local numGroupMembers = GetNumGroupMembers()
    if numGroupMembers <= 1 then
        return units
    end

    for index = 1, math.max(0, numGroupMembers - 1) do
        units[#units + 1] = "party" .. index
    end

    return units
end

local function FinishInspect(clearRequest)
    if isOurInspect then
        ClearInspectPlayer()
    end

    currentInspectUnit = nil
    isOurInspect = false

    if clearRequest then
        requestedUnit = nil
    end
end

local function Inspect(unit)
    local specID = GetInspectSpecialization and GetInspectSpecialization(unit)
    if specID and specID > 0 then
        local cacheEntry = EnsureCacheEntry(unit)
        if cacheEntry then
            local previous = cacheEntry.SpecID
            cacheEntry.SpecID = specID
            cacheEntry.LastSeen = Now()
            if previous ~= specID then
                FireCallbacks()
            end
        end
    end

    FinishInspect(true)
end

local function InvalidateEntry(unit)
    local guid = SafeUnitGUID(unit)
    if not guid then
        return
    end

    guidToSpec[guid] = nil
    needUpdate = true
end

local function OnClearInspect()
    requestedUnit = nil
end

local function OnNotifyInspect(unit)
    if currentInspectUnit and unit ~= currentInspectUnit then
        currentInspectUnit = nil
    end

    requestedUnit = unit
    inspectStarted = Now()
    isOurInspect = false
end

local function GetNextTarget()
    while #priorityUnits > 0 do
        local unit = table.remove(priorityUnits)
        if UnitExists(unit) and SafeUnitGUID(unit) then
            return unit
        end
    end

    local now = Now()

    for _, unit in ipairs(GetFriendlyUnits()) do
        if CanInspect(unit) and UnitIsConnected(unit) then
            local guid = SafeUnitGUID(unit)
            local cacheEntry = guid and guidToSpec[guid]
            if not cacheEntry then
                return unit
            end
            if (not cacheEntry.SpecID or cacheEntry.SpecID <= 0)
                and (not cacheEntry.LastAttempt or (now - cacheEntry.LastAttempt) > CACHE_RETRY_DELAY)
            then
                return unit
            end
        end
    end

    return nil
end

local function RunLoop()
    C_Timer.After(INSPECT_INTERVAL, RunLoop)

    local now = Now()
    local timeSinceLastInspect = inspectStarted and (now - inspectStarted) or nil

    if requestedUnit and timeSinceLastInspect and timeSinceLastInspect < INSPECT_TIMEOUT then
        return
    end

    if requestedUnit then
        FinishInspect(true)
    end

    if not needUpdate then
        return
    end

    local unit = GetNextTarget()
    if not unit then
        needUpdate = false
        return
    end

    local cacheEntry = EnsureCacheEntry(unit)
    if not cacheEntry then
        return
    end

    cacheEntry.LastAttempt = now
    ClearInspectPlayer()
    NotifyInspect(unit)
    inspectStarted = now
    requestedUnit = unit
    currentInspectUnit = unit
    isOurInspect = true
end

function M:RegisterCallback(callback)
    if type(callback) == "function" then
        callbacks[#callbacks + 1] = callback
    end
end

function M:GetUnitSpecID(unit)
    if not unit then
        return nil
    end

    if UnitIsUnit(unit, "player") then
        if GetSpecialization and GetSpecializationInfo then
            local specIndex = GetSpecialization()
            if specIndex then
                return GetSpecializationInfo(specIndex)
            end
        end
        return nil
    end

    local guid = SafeUnitGUID(unit)
    if not guid then
        return nil
    end

    local cacheEntry = guidToSpec[guid]
    if cacheEntry and cacheEntry.SpecID and cacheEntry.SpecID > 0 then
        return cacheEntry.SpecID
    end

    local tooltipSpecID = SpecFromTooltip(unit)
    if tooltipSpecID then
        cacheEntry = EnsureCacheEntry(unit)
        if cacheEntry then
            cacheEntry.SpecID = tooltipSpecID
            cacheEntry.LastSeen = Now()
        end
        return tooltipSpecID
    end

    if not cacheEntry then
        priorityUnits[#priorityUnits + 1] = unit
        needUpdate = true
    end

    return cacheEntry and cacheEntry.SpecID or nil
end

function M:Init(db)
    if initialized then
        return
    end

    if not (CanInspect and NotifyInspect and ClearInspectPlayer and GetInspectSpecialization) then
        return
    end

    initialized = true

    db = type(db) == "table" and db or {}
    db.specCache = db.specCache or {}
    guidToSpec = db.specCache

    PurgeOldEntries()

    hooksecurefunc("NotifyInspect", OnNotifyInspect)
    hooksecurefunc("ClearInspectPlayer", OnClearInspect)

    local frame = CreateFrame("Frame")
    frame:SetScript("OnEvent", function(_, event, ...)
        if event == "INSPECT_READY" then
            if requestedUnit then
                Inspect(requestedUnit)
            end
        elseif event == "GROUP_ROSTER_UPDATE" then
            needUpdate = true
        elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
            local unit = ...
            InvalidateEntry(unit)
        elseif event == "PLAYER_ENTERING_WORLD" then
            priorityUnits = {}
            needUpdate = true
        end
    end)
    frame:RegisterEvent("INSPECT_READY")
    frame:RegisterEvent("GROUP_ROSTER_UPDATE")
    frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")

    RunLoop()
end
