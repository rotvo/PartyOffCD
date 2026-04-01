local _, PartyOffCDCore = ...

PartyOffCDCore = PartyOffCDCore or _G.PartyOffCDCore or {}
_G.PartyOffCDCore = PartyOffCDCore

local M = PartyOffCDCore.TalentTracker or {}
PartyOffCDCore.TalentTracker = M

local unitTalentRanks = {}
local unitTalentSpecID = {}
local unitPvPTalentIDs = {}
local talentCallbacks = {}
local talentMapCache = {}

local db
local initialized = false

local ClassCooldownModifiers = {
    DEATHKNIGHT = {
        [205727] = { { { SpellID = 48707, Amount = -20 } } },
        [457574] = { { { SpellID = 48707, Amount = 20 } } },
    },
    DEMONHUNTER = {
        -- Vengeance modifiers live in SpecCooldownModifiers.
    },
    HUNTER = {
        [1258485] = { { { SpellID = 186265, Amount = -30 } } },
        [266921] = {
            { { SpellID = 186265, Amount = -15 } },
            { { SpellID = 186265, Amount = -30 } },
        },
    },
    MAGE = {
        [382424] = {
            { { SpellID = 45438, Amount = -30 }, { SpellID = 414659, Amount = -30 } },
            { { SpellID = 45438, Amount = -60 }, { SpellID = 414659, Amount = -60 } },
        },
        [1265517] = { { { SpellID = 45438, Amount = -30 }, { SpellID = 414659, Amount = -30 } } },
        [1255166] = { { { SpellID = 342246, Amount = -10 } } },
    },
    PALADIN = {
        [384909] = { { { SpellID = 1022, Amount = -60 }, { SpellID = 204018, Amount = -60 } } },
        [114154] = {
            {
                { SpellID = 642, Amount = -30, Mult = true },
                { SpellID = 498, Amount = -30, Mult = true },
                { SpellID = 31850, Amount = -30, Mult = true },
                { SpellID = 403876, Amount = -30, Mult = true },
            },
        },
    },
    MONK = {},
    SHAMAN = {
        [381647] = { { { SpellID = 108271, Amount = -30 } } },
    },
    WARLOCK = {
        [386659] = { { { SpellID = 104773, Amount = -45 } } },
    },
    WARRIOR = {
        [391271] = {
            {
                { SpellID = 118038, Amount = -10, Mult = true },
            },
        },
    },
}

local SpecCooldownModifiers = {
    [581] = {
        [389732] = { { { SpellID = 204021, Amount = -12 } } },
    },
    [102] = {
        [468743] = { { { SpellID = 102560, Amount = -60 } } },
        [390378] = { { { SpellID = 102560, Amount = -60 } } },
    },
    [103] = {
        [391174] = { { { SpellID = 102543, Amount = -60 }, { SpellID = 106951, Amount = -60 } } },
        [391548] = { { { SpellID = 102543, Amount = -30 }, { SpellID = 106951, Amount = -30 } } },
    },
    [105] = {
        [382552] = { { { SpellID = 102342, Amount = -20 } } },
    },
    [1468] = {
        [376204] = { { { SpellID = 357170, Amount = -10 } } },
    },
    [1473] = {
        [412713] = { { { SpellID = 363916, Amount = -10, Mult = true } } },
    },
    [254] = {
        [260404] = { { { SpellID = 288613, Amount = -30 } } },
    },
    [255] = {
        [1251790] = {
            { { SpellID = 1250646, Amount = -15 } },
            { { SpellID = 1250646, Amount = -30 } },
        },
    },
    [63] = {
        [1254194] = { { { SpellID = 190319, Amount = -60 } } },
    },
    [268] = {
        [450989] = { { { SpellID = 132578, Amount = -25 } } },
        [388813] = { { { SpellID = 115203, Amount = -120 } } },
    },
    [269] = {
        [388813] = { { { SpellID = 115203, Amount = -30 } } },
    },
    [270] = {
        [202424] = { { { SpellID = 116849, Amount = -45 } } },
        [388813] = { { { SpellID = 115203, Amount = -30 } } },
    },
    [257] = {
        [419110] = { { { SpellID = 64843, Amount = -60 } } },
        [200209] = { { { SpellID = 47788, Amount = -120 } } },
    },
    [65] = {
        [384820] = { { { SpellID = 6940, Amount = -15 } } },
        [1241511] = {
            { { SpellID = 31884, Amount = -15 }, { SpellID = 216331, Amount = -7.5 } },
            { { SpellID = 31884, Amount = -30 }, { SpellID = 216331, Amount = -15 } },
        },
    },
    [66] = {
        [384820] = { { { SpellID = 6940, Amount = -60 } } },
        [378425] = {
            {
                { SpellID = 642, Amount = -15, Mult = true },
                { SpellID = 1022, Amount = -15, Mult = true },
                { SpellID = 204018, Amount = -15, Mult = true },
            },
        },
        [204074] = { { { SpellID = 31884, Amount = -50, Mult = true }, { SpellID = 389539, Amount = -50, Mult = true } } },
    },
    [70] = {
        [384820] = { { { SpellID = 6940, Amount = -60 } } },
    },
    [258] = {
        [288733] = { { { SpellID = 47585, Amount = -30 } } },
    },
    [73] = {
        [397103] = { { { SpellID = 871, Amount = -60 } } },
    },
}

local ClassPvPCooldownModifiers = {}

local SpecPvPCooldownModifiers = {
    [268] = {
        [666] = { { SpellID = 115203, Amount = -50, Mult = true } },
    },
    [250] = {
        [5592] = { { SpellID = 48707, Amount = -10 } },
    },
    [251] = {
        [5591] = { { SpellID = 48707, Amount = -10 } },
    },
    [252] = {
        [5590] = { { SpellID = 48707, Amount = -10 } },
    },
    [261] = {
        [354825] = { { SpellID = 121471, Amount = -20, Mult = true } },
    },
}

local ClassDefaultTalentRanks = {
    DEATHKNIGHT = {
        [205727] = 1,
    },
    HUNTER = {
        [1258485] = 1,
    },
    MAGE = {
        [382424] = 2,
        [1265517] = 1,
    },
    MONK = {
        [388813] = 1,
    },
    PALADIN = {
        [114154] = 1,
    },
    SHAMAN = {
        [381647] = 1,
    },
    WARRIOR = {
        [107574] = 1,
    },
}

local SpecDefaultTalentRanks = {
    [102] = {
        [468743] = 1,
    },
    [254] = {
        [260404] = 1,
    },
    [103] = {
        [102543] = 1,
        [391174] = 1,
        [391548] = 1,
    },
    [63] = {
        [1254194] = 1,
    },
    [257] = {
        [419110] = 1,
    },
    [105] = {
        [382552] = 1,
    },
    [258] = {
        [288733] = 1,
    },
    [270] = {
        [202424] = 1,
    },
    [1468] = {
        [376204] = 1,
    },
    [65] = {
        [384820] = 1,
        [216331] = 1,
    },
    [66] = {
        [384820] = 1,
    },
    [70] = {
        [458359] = 1,
        [384820] = 1,
    },
}

local function IsSecretValue(value)
    return type(issecretvalue) == "function" and issecretvalue(value)
end

local function FireTalentCallbacks(playerName)
    for _, callback in ipairs(talentCallbacks) do
        callback(playerName)
    end
end

local function BuildTalentToSpellMap(specID)
    if talentMapCache[specID] then
        return talentMapCache[specID]
    end

    if not (C_ClassTalents and C_Traits and Constants and Constants.TraitConsts) then
        return nil
    end

    local configID = Constants.TraitConsts.VIEW_TRAIT_CONFIG_ID
    C_ClassTalents.InitializeViewLoadout(specID, 100)
    C_ClassTalents.ViewLoadout({})
    local configInfo = C_Traits.GetConfigInfo(configID)
    if not configInfo then
        return nil
    end

    local talentMap = {}
    for _, treeID in ipairs(configInfo.treeIDs) do
        for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID)) do
            local nodeInfo = C_Traits.GetNodeInfo(configID, nodeID)
            if nodeInfo and nodeInfo.ID ~= 0 then
                for choiceIndex, entryID in ipairs(nodeInfo.entryIDs) do
                    local entryInfo = C_Traits.GetEntryInfo(configID, entryID)
                    if nodeInfo.type == Enum.TraitNodeType.SubTreeSelection then
                        talentMap[nodeInfo.ID .. "_" .. choiceIndex] = {
                            spellID = -1,
                            maxRank = -1,
                            type = nodeInfo.type,
                            subTreeID = entryInfo and entryInfo.subTreeID or nil,
                        }
                    end

                    if entryInfo and entryInfo.definitionID then
                        local definitionInfo = C_Traits.GetDefinitionInfo(entryInfo.definitionID)
                        if definitionInfo and definitionInfo.spellID then
                            talentMap[nodeInfo.ID .. "_" .. choiceIndex] = {
                                spellID = definitionInfo.spellID,
                                maxRank = nodeInfo.maxRanks,
                                type = nodeInfo.type,
                                subTreeID = nodeInfo.subTreeID,
                            }
                        end
                    end
                end
            end
        end
    end

    talentMapCache[specID] = talentMap
    return talentMap
end

local function DecodeTalent(stream)
    local function ReadBool(input)
        return input:ExtractValue(1) == 1
    end

    local selected = ReadBool(stream)
    local purchased
    local rank
    local choiceIndex = 1
    local notMaxRank = true

    if selected then
        purchased = ReadBool(stream)
        if purchased then
            notMaxRank = ReadBool(stream)
            if notMaxRank then
                rank = stream:ExtractValue(6)
            end

            local choiceNode = ReadBool(stream)
            if choiceNode then
                choiceIndex = stream:ExtractValue(2) + 1
            end
        end
    end

    return selected, purchased, notMaxRank, rank, choiceIndex
end

local function GetTalentRanks(specID, talentExportString)
    if not (C_Traits and C_Traits.GetLoadoutSerializationVersion and ImportDataStreamMixin and C_ClassTalents) then
        return nil
    end

    local talentIDToSpellMap = BuildTalentToSpellMap(specID)
    if not talentIDToSpellMap then
        return nil
    end

    local stream = CreateAndInitFromMixin(ImportDataStreamMixin, talentExportString)
    local version = stream:ExtractValue(8)
    local encodedSpec = stream:ExtractValue(16)
    stream:ExtractValue(128)

    if C_Traits.GetLoadoutSerializationVersion() ~= 2 or version ~= 2 then
        return nil
    end

    if encodedSpec ~= specID then
        return nil
    end

    local traitTree = C_ClassTalents.GetTraitTreeForSpec(specID)
    if not traitTree then
        return nil
    end

    local fullRecords = {}
    local heroChoice

    for _, talentID in ipairs(C_Traits.GetTreeNodes(traitTree)) do
        local selected, purchased, _, rank, choiceIndex = DecodeTalent(stream)
        local spellInfo = talentIDToSpellMap[talentID .. "_" .. choiceIndex]
        local record = {
            spellID = spellInfo and spellInfo.spellID or -1,
            selected = selected,
            purchased = purchased,
            rank = rank,
            maxRank = spellInfo and spellInfo.maxRank or nil,
            subTreeID = spellInfo and spellInfo.subTreeID or nil,
            type = spellInfo and spellInfo.type or nil,
        }
        fullRecords[#fullRecords + 1] = record
        if record.type == Enum.TraitNodeType.SubTreeSelection then
            heroChoice = record.subTreeID
        end
    end

    local talentRanks = {}
    for _, record in ipairs(fullRecords) do
        if record.subTreeID == nil or record.subTreeID == heroChoice then
            talentRanks[record.spellID] = (not record.selected and 0) or record.rank or record.maxRank
        end
    end

    return talentRanks
end

local function GetEffectiveTalentRanks(playerName, classToken, specID)
    local ranks = unitTalentRanks[playerName]
    if ranks then
        return ranks
    end

    local classDefaults = ClassDefaultTalentRanks[classToken]
    local specDefaults = specID and SpecDefaultTalentRanks[specID] or nil
    if not classDefaults and not specDefaults then
        return nil
    end

    local merged = {}
    if classDefaults then
        for talentSpellID, rank in pairs(classDefaults) do
            merged[talentSpellID] = rank
        end
    end
    if specDefaults then
        for talentSpellID, rank in pairs(specDefaults) do
            merged[talentSpellID] = rank
        end
    end

    return merged
end

function M:GetUnitCooldown(unit, specID, classToken, abilityID, baseCooldown)
    local playerName = UnitNameUnmodified(unit)
    if not playerName or IsSecretValue(playerName) then
        return baseCooldown
    end

    local talentRanks = GetEffectiveTalentRanks(playerName, classToken, specID)
    if not talentRanks then
        return baseCooldown
    end

    local addAmount = 0
    local multAmount = 0
    local resolvedSpecID = unitTalentSpecID[playerName] or specID

    local function ApplyModifierTable(modifierTable)
        if not modifierTable then
            return
        end

        for talentSpellID, rankList in pairs(modifierTable) do
            local rank = talentRanks[talentSpellID]
            if rank and rank > 0 then
                local modifiers = rankList[rank]
                if modifiers then
                    for _, modifier in ipairs(modifiers) do
                        if modifier.SpellID == abilityID then
                            if modifier.Mult then
                                multAmount = multAmount + modifier.Amount
                            else
                                addAmount = addAmount + modifier.Amount
                            end
                        end
                    end
                end
            end
        end
    end

    ApplyModifierTable(ClassCooldownModifiers[classToken])
    ApplyModifierTable(resolvedSpecID and SpecCooldownModifiers[resolvedSpecID])

    local cooldown = baseCooldown + addAmount + (baseCooldown * multAmount / 100)
    local pvpTalentSet = unitPvPTalentIDs[playerName]
    local pvpAddAmount = 0
    local pvpMultAmount = 0

    local function ApplyPvPModifierTable(modifierTable)
        if not modifierTable or not pvpTalentSet then
            return
        end

        for pvpTalentID, modifiers in pairs(modifierTable) do
            if pvpTalentSet[pvpTalentID] then
                for _, modifier in ipairs(modifiers) do
                    if modifier.SpellID == abilityID then
                        if modifier.Mult then
                            pvpMultAmount = pvpMultAmount + modifier.Amount
                        else
                            pvpAddAmount = pvpAddAmount + modifier.Amount
                        end
                    end
                end
            end
        end
    end

    ApplyPvPModifierTable(ClassPvPCooldownModifiers[classToken])
    ApplyPvPModifierTable(resolvedSpecID and SpecPvPCooldownModifiers[resolvedSpecID])

    cooldown = cooldown + pvpAddAmount + (cooldown * pvpMultAmount / 100)
    return math.max(cooldown, 0)
end

function M:UnitHasTalent(unit, talentSpellID, callerSpecID)
    local playerName = UnitNameUnmodified(unit)
    if not playerName or IsSecretValue(playerName) then
        return false
    end

    local talentRanks = unitTalentRanks[playerName]
    if talentRanks ~= nil and (talentRanks[talentSpellID] or 0) > 0 then
        return true
    end

    local pvpTalentSet = unitPvPTalentIDs[playerName]
    if pvpTalentSet ~= nil and pvpTalentSet[talentSpellID] == true then
        return true
    end

    if talentRanks == nil then
        local _, classToken = UnitClass(unit)
        local specID = unitTalentSpecID[playerName] or callerSpecID
        local effectiveRanks = GetEffectiveTalentRanks(playerName, classToken, specID)
        if effectiveRanks and (effectiveRanks[talentSpellID] or 0) > 0 then
            return true
        end
    end

    return false
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

    local playerName = UnitNameUnmodified(unit)
    if not playerName or IsSecretValue(playerName) then
        return nil
    end

    return unitTalentSpecID[playerName]
end

function M:RegisterCallback(callback)
    if type(callback) == "function" then
        talentCallbacks[#talentCallbacks + 1] = callback
    end
end

local function OnLibSpecUpdate(specID, playerName, talentString)
    if not talentString then
        return
    end

    local ranks = GetTalentRanks(specID, talentString)
    if ranks then
        local name = playerName:match("^([^%-]+)") or playerName
        unitTalentRanks[name] = ranks
        unitTalentSpecID[name] = specID
        if db then
            db.talentCache[name] = {
                SpecID = specID,
                TalentString = talentString,
                Time = time(),
            }
        end
        FireTalentCallbacks(name)
    end
end

local function UpdateLocalPlayer()
    if not (GetSpecialization and GetSpecializationInfo) then
        return
    end

    local specIndex = GetSpecialization()
    if not specIndex then
        return
    end

    local specID = GetSpecializationInfo(specIndex)
    if not specID then
        return
    end

    local configID = C_ClassTalents and C_ClassTalents.GetActiveConfigID and C_ClassTalents.GetActiveConfigID()
    if not configID then
        return
    end

    local talentString = C_Traits and C_Traits.GenerateImportString and C_Traits.GenerateImportString(configID)
    if not talentString then
        return
    end

    local player = UnitNameUnmodified("player")
    local ranks = GetTalentRanks(specID, talentString)
    if ranks then
        unitTalentRanks[player] = ranks
        unitTalentSpecID[player] = specID
        if db then
            db.talentCache[player] = {
                SpecID = specID,
                TalentString = talentString,
                Time = time(),
            }
        end
        FireTalentCallbacks(player)
    end
end

function M:Init(savedVars)
    if initialized then
        return
    end

    initialized = true
    db = type(savedVars) == "table" and savedVars or {}
    db.talentCache = db.talentCache or {}
    db.pvpTalentCache = db.pvpTalentCache or {}

    local now = time()
    local maxAge = 86400

    for name, entry in pairs(db.talentCache) do
        if not entry.Time or (now - entry.Time) > maxAge then
            db.talentCache[name] = nil
        else
            local ranks = GetTalentRanks(entry.SpecID, entry.TalentString)
            if ranks then
                unitTalentRanks[name] = ranks
                unitTalentSpecID[name] = entry.SpecID
            else
                db.talentCache[name] = nil
            end
        end
    end

    for name, entry in pairs(db.pvpTalentCache) do
        if not entry.Time or (now - entry.Time) > maxAge then
            db.pvpTalentCache[name] = nil
        else
            local set = {}
            for _, talentID in ipairs(entry.IDs or {}) do
                set[talentID] = true
            end
            unitPvPTalentIDs[name] = set
        end
    end

    local libSpec = LibStub and LibStub("LibSpecialization", true)
    if libSpec and libSpec.RegisterGroup then
        libSpec.RegisterGroup(PartyOffCDCore, function(specID, _, _, playerName, talentString)
            OnLibSpecUpdate(specID, playerName, talentString)
        end)
    end

    local frame = CreateFrame("Frame")
    frame:SetScript("OnEvent", UpdateLocalPlayer)
    frame:RegisterEvent("ACTIVE_COMBAT_CONFIG_CHANGED")
    frame:RegisterEvent("TRAIT_CONFIG_UPDATED")
    frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    frame:RegisterEvent("PLAYER_LOGIN")

    local pvpTalentSync = PartyOffCDCore.PvPTalentSync
    if pvpTalentSync and pvpTalentSync.RegisterCallback then
        pvpTalentSync:RegisterCallback(function(playerName, pvpTalentIDs)
            local name = playerName:match("^([^%-]+)") or playerName
            if pvpTalentIDs then
                local ids = {}
                for _, talentID in ipairs(pvpTalentIDs) do
                    ids[#ids + 1] = talentID
                end
                db.pvpTalentCache[name] = {
                    IDs = ids,
                    Time = time(),
                }
                local set = {}
                for _, talentID in ipairs(ids) do
                    set[talentID] = true
                end
                unitPvPTalentIDs[name] = set
            else
                db.pvpTalentCache[name] = nil
                unitPvPTalentIDs[name] = nil
            end
            FireTalentCallbacks(name)
        end)
    end
end
