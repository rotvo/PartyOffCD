local _, PartyOffCDCore = ...

PartyOffCDCore = PartyOffCDCore or _G.PartyOffCDCore or {}
_G.PartyOffCDCore = PartyOffCDCore

local PartyOffCD = _G.PartyOffCD
assert(PartyOffCD, "PartyOffCD: frame missing before loading AuraTracker.lua")

-- Canonical OFF/DEF auto-tracking lives here.
-- Keep this aligned with the MiniCC-style aura/evidence model documented in AI_CONTEXT.md.

local tolerance = 0.5
local castWindow = 0.15
local evidenceTolerance = 0.15

local lastDebuffTime = {}
local lastShieldTime = {}
local lastCastTime = {}
local lastUnitFlagsTime = {}
local lastFeignDeathTime = {}
local lastFeignDeathState = {}

local auraRules = {
    bySpec = {
        [65] = {
            { BuffDuration = 12, Cooldown = 120, Important = true, BigDefensive = false, ExternalDefensive = false, RequiresEvidence = "Cast", SpellID = 31884, MinDuration = true, ExcludeIfTalent = 216331 },
            { BuffDuration = 10, Cooldown = 60, Important = true, BigDefensive = false, ExternalDefensive = false, RequiresEvidence = "Cast", SpellID = 216331, MinDuration = true, RequiresTalent = 216331 },
            { BuffDuration = 8, Cooldown = 300, BigDefensive = true, ExternalDefensive = false, Important = true, RequiresEvidence = { "Cast", "Debuff", "UnitFlags" }, CanCancelEarly = true, SpellID = 642 },
            { BuffDuration = 8, Cooldown = 60, BigDefensive = true, Important = true, ExternalDefensive = false, RequiresEvidence = "Cast", SpellID = 498 },
            { BuffDuration = 10, Cooldown = 300, ExternalDefensive = true, BigDefensive = false, Important = false, CanCancelEarly = true, RequiresEvidence = "Cast", SpellID = 204018, RequiresTalent = 5692 },
            { BuffDuration = 10, Cooldown = 300, ExternalDefensive = true, BigDefensive = false, Important = false, CanCancelEarly = true, RequiresEvidence = "Cast", SpellID = 1022, ExcludeIfTalent = 5692 },
            { BuffDuration = 12, Cooldown = 120, ExternalDefensive = true, BigDefensive = false, Important = false, RequiresEvidence = "Cast", SpellID = 6940 },
        },
        [66] = {
            { BuffDuration = 25, Cooldown = 120, Important = true, ExternalDefensive = false, BigDefensive = false, MinDuration = true, RequiresEvidence = "Cast", SpellID = 31884, ExcludeIfTalent = 389539 },
            { BuffDuration = 20, Cooldown = 120, Important = true, ExternalDefensive = false, BigDefensive = false, MinDuration = true, RequiresEvidence = "Cast", SpellID = 389539, RequiresTalent = 389539, ExcludeIfTalent = 31884 },
            { BuffDuration = 8, Cooldown = 300, BigDefensive = true, ExternalDefensive = false, Important = true, RequiresEvidence = { "Cast", "Debuff", "UnitFlags" }, CanCancelEarly = true, SpellID = 642 },
            { BuffDuration = 8, Cooldown = 90, BigDefensive = true, Important = true, ExternalDefensive = false, SpellID = 31850, RequiresEvidence = "Cast" },
            { BuffDuration = 8, Cooldown = 180, BigDefensive = true, Important = false, ExternalDefensive = false, RequiresEvidence = "Cast", SpellID = 86659 },
            { BuffDuration = 10, Cooldown = 300, ExternalDefensive = true, BigDefensive = false, Important = false, CanCancelEarly = true, RequiresEvidence = "Cast", SpellID = 204018, RequiresTalent = 5692 },
            { BuffDuration = 10, Cooldown = 300, ExternalDefensive = true, BigDefensive = false, Important = false, CanCancelEarly = true, RequiresEvidence = "Cast", SpellID = 1022, ExcludeIfTalent = 5692 },
            { BuffDuration = 12, Cooldown = 120, ExternalDefensive = true, BigDefensive = false, Important = false, RequiresEvidence = "Cast", SpellID = 6940 },
        },
        [70] = {
            { BuffDuration = 24, Cooldown = 60, Important = true, ExternalDefensive = false, BigDefensive = false, RequiresEvidence = "Cast", SpellID = 31884, ExcludeIfTalent = 458359 },
            { BuffDuration = 8, Cooldown = 300, BigDefensive = true, ExternalDefensive = false, Important = true, RequiresEvidence = { "Cast", "Debuff", "UnitFlags" }, CanCancelEarly = true, SpellID = 642 },
            { BuffDuration = 8, Cooldown = 90, Important = true, ExternalDefensive = false, BigDefensive = false, RequiresEvidence = { "Cast", "Shield" }, SpellID = 403876 },
            { BuffDuration = 10, Cooldown = 300, ExternalDefensive = true, BigDefensive = false, Important = false, CanCancelEarly = true, RequiresEvidence = "Cast", SpellID = 204018, RequiresTalent = 5692 },
            { BuffDuration = 10, Cooldown = 300, ExternalDefensive = true, BigDefensive = false, Important = false, CanCancelEarly = true, RequiresEvidence = "Cast", SpellID = 1022, ExcludeIfTalent = 5692 },
            { BuffDuration = 12, Cooldown = 120, ExternalDefensive = true, BigDefensive = false, Important = false, RequiresEvidence = "Cast", SpellID = 6940 },
        },
        [62] = {
            { BuffDuration = 15, Cooldown = 90, Important = true, BigDefensive = false, ExternalDefensive = false, RequiresEvidence = "Cast", MinDuration = true, SpellID = 365350 },
        },
        [63] = {
            { BuffDuration = 10, Cooldown = 120, Important = true, BigDefensive = false, ExternalDefensive = false, RequiresEvidence = "Cast", SpellID = 190319, MinDuration = true },
        },
        [64] = {
            { BuffDuration = 25, Cooldown = 120, Important = true, BigDefensive = false, ExternalDefensive = false, RequiresEvidence = "Cast", SpellID = 12472, MinDuration = true },
        },
        [71] = {
            { BuffDuration = 8, Cooldown = 120, BigDefensive = true, ExternalDefensive = false, Important = true, RequiresEvidence = "Cast", SpellID = 118038 },
            { BuffDuration = 20, Cooldown = 90, Important = true, ExternalDefensive = false, BigDefensive = false, RequiresEvidence = "Cast", SpellID = 107574, MinDuration = true, RequiresTalent = 107574 },
        },
        [72] = {
            { BuffDuration = 8, Cooldown = 120, BigDefensive = true, ExternalDefensive = false, Important = true, RequiresEvidence = "Cast", SpellID = 184364 },
            { BuffDuration = 11, Cooldown = 120, BigDefensive = true, ExternalDefensive = false, Important = true, RequiresEvidence = "Cast", SpellID = 184364 },
            { BuffDuration = 20, Cooldown = 90, Important = true, ExternalDefensive = false, BigDefensive = false, RequiresEvidence = "Cast", SpellID = 107574, MinDuration = true, RequiresTalent = 107574 },
            { BuffDuration = 12, Cooldown = 90, Important = true, ExternalDefensive = false, BigDefensive = false, RequiresEvidence = "Cast", SpellID = 1719, MinDuration = true },
        },
        [73] = {
            { BuffDuration = 8, Cooldown = 180, BigDefensive = true, ExternalDefensive = false, Important = true, RequiresEvidence = "Cast", SpellID = 871 },
            { BuffDuration = 20, Cooldown = 90, Important = true, ExternalDefensive = false, BigDefensive = false, RequiresEvidence = "Cast", SpellID = 107574, MinDuration = true, RequiresTalent = 107574 },
        },
        [251] = {
            { BuffDuration = 12, Cooldown = 45, Important = true, BigDefensive = false, ExternalDefensive = false, RequiresEvidence = "Cast", MinDuration = true, SpellID = 51271 },
        },
        [250] = {
            { BuffDuration = 10, Cooldown = 90, BigDefensive = true, ExternalDefensive = false, Important = true, RequiresEvidence = "Cast", SpellID = 55233 },
            { BuffDuration = 12, Cooldown = 90, BigDefensive = true, ExternalDefensive = false, Important = true, RequiresEvidence = "Cast", SpellID = 55233 },
            { BuffDuration = 14, Cooldown = 90, BigDefensive = true, ExternalDefensive = false, Important = true, RequiresEvidence = "Cast", SpellID = 55233 },
        },
        [256] = {
            { BuffDuration = 8, Cooldown = 180, ExternalDefensive = true, BigDefensive = false, Important = false, RequiresEvidence = "Cast", SpellID = 33206 },
        },
        [257] = {
            { BuffDuration = 10, Cooldown = 180, ExternalDefensive = true, BigDefensive = false, Important = false, CanCancelEarly = true, RequiresEvidence = "Cast", SpellID = 47788 },
            { BuffDuration = 5, Cooldown = 180, Important = true, BigDefensive = false, ExternalDefensive = false, CanCancelEarly = true, RequiresEvidence = "Cast", SpellID = 64843 },
            { BuffDuration = 20, Cooldown = 120, Important = true, BigDefensive = false, ExternalDefensive = false, RequiresEvidence = "Cast", SpellID = 200183, MinDuration = true },
        },
        [258] = {
            { BuffDuration = 6, Cooldown = 120, BigDefensive = true, ExternalDefensive = false, Important = true, CanCancelEarly = true, RequiresEvidence = "Cast", SpellID = 47585 },
            { BuffDuration = 20, Cooldown = 120, Important = true, ExternalDefensive = false, BigDefensive = false, RequiresEvidence = "Cast", SpellID = 228260 },
        },
        [102] = {
            { BuffDuration = 15, Cooldown = 180, Important = true, BigDefensive = false, ExternalDefensive = false, RequiresEvidence = "Cast", SpellID = 194223, MinDuration = true, ExcludeIfTalent = 102560 },
            { BuffDuration = 20, Cooldown = 180, Important = true, BigDefensive = false, ExternalDefensive = false, RequiresEvidence = "Cast", MinDuration = true, SpellID = 102560 },
        },
        [103] = {
            { BuffDuration = 15, Cooldown = 180, Important = true, BigDefensive = false, ExternalDefensive = false, RequiresEvidence = "Cast", MinDuration = true, SpellID = 106951, RequiresTalent = 106951, ExcludeIfTalent = 102543 },
            { BuffDuration = 20, Cooldown = 180, Important = true, BigDefensive = false, ExternalDefensive = false, RequiresEvidence = "Cast", SpellID = 102543, RequiresTalent = 102543 },
        },
        [104] = {
            { BuffDuration = 30, Cooldown = 180, Important = true, BigDefensive = false, ExternalDefensive = false, RequiresEvidence = "Cast", SpellID = 102558 },
        },
        [105] = {
            { BuffDuration = 12, Cooldown = 90, ExternalDefensive = true, BigDefensive = false, Important = false, RequiresEvidence = "Cast", SpellID = 102342 },
        },
        [268] = {
            { BuffDuration = 25, Cooldown = 120, Important = true, BigDefensive = false, ExternalDefensive = false, RequiresEvidence = "Cast", SpellID = 132578 },
            { BuffDuration = 15, Cooldown = 360, BigDefensive = true, Important = false, ExternalDefensive = false, RequiresEvidence = "Cast", SpellID = 115203 },
        },
        [270] = {
            { BuffDuration = 12, Cooldown = 120, ExternalDefensive = true, BigDefensive = false, Important = false, CanCancelEarly = true, RequiresEvidence = "Cast", SpellID = 116849 },
        },
        [577] = {
            { BuffDuration = 10, Cooldown = 60, BigDefensive = true, ExternalDefensive = false, Important = true, RequiresEvidence = "Cast", SpellID = 198589 },
        },
        [581] = {
            { BuffDuration = 12, Cooldown = 60, BigDefensive = true, ExternalDefensive = false, Important = false, MinDuration = true, RequiresEvidence = "Cast", SpellID = 204021 },
        },
        [253] = {
            { BuffDuration = 15, Cooldown = 90, Important = true, BigDefensive = false, ExternalDefensive = false, RequiresEvidence = "Cast", SpellID = 19574, MinDuration = true },
        },
        [254] = {
            { BuffDuration = 15, Cooldown = 120, Important = true, BigDefensive = false, ExternalDefensive = false, RequiresEvidence = "Cast", SpellID = 288613 },
            { BuffDuration = 17, Cooldown = 120, Important = true, BigDefensive = false, ExternalDefensive = false, RequiresEvidence = "Cast", SpellID = 288613 },
        },
        [255] = {
            { BuffDuration = 20, Cooldown = 120, Important = true, BigDefensive = false, ExternalDefensive = false, RequiresEvidence = "Cast", SpellID = 266779, MinDuration = true },
            { BuffDuration = 8, Cooldown = 90, Important = true, BigDefensive = false, ExternalDefensive = false, RequiresEvidence = "Cast", SpellID = 1250646 },
            { BuffDuration = 10, Cooldown = 90, Important = true, BigDefensive = false, ExternalDefensive = false, RequiresEvidence = "Cast", SpellID = 1250646 },
        },
        [260] = {
            { BuffDuration = 20, Cooldown = 180, Important = true, BigDefensive = false, ExternalDefensive = false, RequiresEvidence = "Cast", SpellID = 13750, MinDuration = true },
        },
        [261] = {
            { BuffDuration = 16, Cooldown = 90, Important = true, BigDefensive = false, ExternalDefensive = false, RequiresEvidence = "Cast", SpellID = 121471 },
            { BuffDuration = 18, Cooldown = 90, Important = true, BigDefensive = false, ExternalDefensive = false, RequiresEvidence = "Cast", SpellID = 121471 },
            { BuffDuration = 20, Cooldown = 90, Important = true, BigDefensive = false, ExternalDefensive = false, RequiresEvidence = "Cast", SpellID = 121471 },
        },
        [262] = {
            { BuffDuration = 15, Cooldown = 60, Important = true, BigDefensive = false, ExternalDefensive = false, RequiresEvidence = "Cast", SpellID = 191634, CanCancelEarly = true },
            { BuffDuration = 15, Cooldown = 180, Important = true, BigDefensive = false, ExternalDefensive = false, RequiresEvidence = "Cast", SpellID = 114050, MinDuration = true },
        },
        [265] = {
            { BuffDuration = 20, Cooldown = 120, Important = true, BigDefensive = false, ExternalDefensive = false, RequiresEvidence = "Cast", SpellID = 113860, MinDuration = true },
        },
        [269] = {
            { BuffDuration = 15, Cooldown = 90, Important = true, BigDefensive = false, ExternalDefensive = false, RequiresEvidence = "Cast", SpellID = 137639, CanCancelEarly = true },
        },
        [1467] = {
            { BuffDuration = 18, Cooldown = 120, Important = true, BigDefensive = false, ExternalDefensive = false, RequiresEvidence = "Cast", MinDuration = true, SpellID = 375087 },
        },
        [1468] = {
            { BuffDuration = 8, Cooldown = 60, ExternalDefensive = true, BigDefensive = false, Important = false, RequiresEvidence = "Cast", SpellID = 357170 },
        },
        [1473] = {
            { BuffDuration = 13.4, Cooldown = 90, BigDefensive = true, ExternalDefensive = false, Important = true, RequiresEvidence = "Cast", MinDuration = true, SpellID = 363916 },
        },
    },
    byClass = {
        PALADIN = {
            { BuffDuration = 8, Cooldown = 300, BigDefensive = true, Important = true, ExternalDefensive = false, RequiresEvidence = { "Cast", "Debuff", "UnitFlags" }, CanCancelEarly = true, SpellID = 642 },
            { BuffDuration = 8, Cooldown = 25, Important = true, ExternalDefensive = false, BigDefensive = false, CanCancelEarly = true, RequiresEvidence = "Cast", SpellID = 1044 },
            { BuffDuration = 10, Cooldown = 300, ExternalDefensive = true, Important = false, BigDefensive = false, CanCancelEarly = true, RequiresEvidence = "Cast", SpellID = 204018, RequiresTalent = 5692 },
            { BuffDuration = 10, Cooldown = 300, ExternalDefensive = true, Important = false, BigDefensive = false, CanCancelEarly = true, RequiresEvidence = "Cast", SpellID = 1022, ExcludeIfTalent = 5692 },
        },
        MAGE = {
            { BuffDuration = 10, Cooldown = 240, BigDefensive = true, ExternalDefensive = false, Important = true, CanCancelEarly = true, SpellID = 45438, RequiresEvidence = { "Cast", "Debuff", "UnitFlags" }, ExcludeIfTalent = 414659 },
            { BuffDuration = 6, Cooldown = 240, BigDefensive = true, ExternalDefensive = false, Important = true, SpellID = 414659, RequiresEvidence = "Cast", RequiresTalent = 414659 },
            { BuffDuration = 10, Cooldown = 50, BigDefensive = true, ExternalDefensive = false, Important = true, CanCancelEarly = true, SpellID = 342246, RequiresEvidence = "Cast" },
        },
        HUNTER = {
            { BuffDuration = 8, Cooldown = 180, BigDefensive = true, ExternalDefensive = false, Important = true, CanCancelEarly = true, SpellID = 186265, RequiresEvidence = { "Cast", "UnitFlags" } },
            { BuffDuration = 6, Cooldown = 90, BigDefensive = true, ExternalDefensive = false, Important = true, MinDuration = true, SpellID = 264735, RequiresEvidence = "Cast" },
            { BuffDuration = 8, Cooldown = 90, BigDefensive = true, ExternalDefensive = false, Important = true, MinDuration = true, SpellID = 264735, RequiresEvidence = "Cast" },
        },
        DRUID = {
            { BuffDuration = 8, Cooldown = 60, BigDefensive = true, ExternalDefensive = false, Important = true, RequiresEvidence = "Cast", SpellID = 22812 },
            { BuffDuration = 12, Cooldown = 60, BigDefensive = true, ExternalDefensive = false, Important = true, RequiresEvidence = "Cast", SpellID = 22812 },
        },
        ROGUE = {
            { BuffDuration = 10, Cooldown = 120, Important = true, ExternalDefensive = false, BigDefensive = false, RequiresEvidence = "Cast", SpellID = 5277 },
            { BuffDuration = 5, Cooldown = 120, BigDefensive = true, ExternalDefensive = false, Important = false, RequiresEvidence = "Cast", SpellID = 31224 },
        },
        DEATHKNIGHT = {
            { BuffDuration = 5, Cooldown = 60, BigDefensive = true, Important = true, ExternalDefensive = false, CanCancelEarly = true, SpellID = 48707, RequiresEvidence = { "Cast", "Shield" } },
            { BuffDuration = 7, Cooldown = 60, BigDefensive = true, Important = true, ExternalDefensive = false, CanCancelEarly = true, SpellID = 48707, RequiresEvidence = { "Cast", "Shield" } },
            { BuffDuration = 8, Cooldown = 120, BigDefensive = true, ExternalDefensive = false, Important = true, RequiresEvidence = "Cast", SpellID = 48792 },
            { BuffDuration = 5, Cooldown = 60, BigDefensive = false, Important = true, ExternalDefensive = false, CanCancelEarly = true, SpellID = 48707, RequiresEvidence = { "Cast", "Shield" } },
            { BuffDuration = 7, Cooldown = 60, BigDefensive = false, Important = true, ExternalDefensive = false, CanCancelEarly = true, SpellID = 48707, RequiresEvidence = { "Cast", "Shield" } },
        },
        MONK = {
            { BuffDuration = 15, Cooldown = 120, BigDefensive = true, ExternalDefensive = false, Important = false, RequiresEvidence = "Cast", SpellID = 115203 },
        },
        SHAMAN = {
            { BuffDuration = 12, Cooldown = 120, BigDefensive = true, ExternalDefensive = false, Important = true, RequiresEvidence = "Cast", SpellID = 108271 },
        },
        WARLOCK = {
            { BuffDuration = 8, Cooldown = 180, BigDefensive = true, ExternalDefensive = false, Important = true, RequiresEvidence = "Cast", SpellID = 104773 },
        },
        PRIEST = {
            { BuffDuration = 20, Cooldown = 120, Important = true, BigDefensive = false, ExternalDefensive = false, RequiresEvidence = "Cast", SpellID = 10060, MinDuration = true },
            { BuffDuration = 10, Cooldown = 90, BigDefensive = true, ExternalDefensive = false, Important = true, RequiresEvidence = "Cast", SpellID = 19236 },
        },
        EVOKER = {
            { BuffDuration = 12, Cooldown = 90, BigDefensive = true, ExternalDefensive = false, Important = true, RequiresEvidence = "Cast", MinDuration = true, SpellID = 363916 },
        },
    },
}

local function BuildEvidenceSet(unit, detectionTime)
    local evidence = nil

    if lastDebuffTime[unit] and math.abs(lastDebuffTime[unit] - detectionTime) <= evidenceTolerance then
        evidence = evidence or {}
        evidence.Debuff = true
    end
    if lastShieldTime[unit] and math.abs(lastShieldTime[unit] - detectionTime) <= evidenceTolerance then
        evidence = evidence or {}
        evidence.Shield = true
    end
    if lastFeignDeathTime[unit] and math.abs(lastFeignDeathTime[unit] - detectionTime) <= castWindow then
        evidence = evidence or {}
        evidence.FeignDeath = true
    elseif lastUnitFlagsTime[unit] and math.abs(lastUnitFlagsTime[unit] - detectionTime) <= castWindow then
        evidence = evidence or {}
        evidence.UnitFlags = true
    end
    if lastCastTime[unit] and math.abs(lastCastTime[unit] - detectionTime) <= castWindow then
        evidence = evidence or {}
        evidence.Cast = true
    end

    return evidence
end

local function AuraTypeMatchesRule(auraTypes, rule)
    if rule.BigDefensive == true and not auraTypes.BIG_DEFENSIVE then
        return false
    end
    if rule.BigDefensive == false and auraTypes.BIG_DEFENSIVE then
        return false
    end
    if rule.ExternalDefensive == true and not auraTypes.EXTERNAL_DEFENSIVE then
        return false
    end
    if rule.ExternalDefensive == false and auraTypes.EXTERNAL_DEFENSIVE then
        return false
    end
    if rule.Important == true and not auraTypes.IMPORTANT then
        return false
    end
    return true
end

local function EvidenceMatchesRequirement(requirement, evidence)
    if requirement == nil then
        return true
    end
    if requirement == false then
        return not evidence or not next(evidence)
    end
    if type(requirement) == "string" then
        return evidence ~= nil and evidence[requirement] == true
    end
    if type(requirement) == "table" then
        if not evidence then
            return false
        end
        for _, key in ipairs(requirement) do
            if not evidence[key] then
                return false
            end
        end
        return true
    end
    return false
end

local function GetCandidateActiveCooldowns(candidateUnit)
    local sender = PartyOffCDCore.GetUnitFullName(candidateUnit) or UnitName(candidateUnit)
    local senderKey = sender and PartyOffCD:ResolveSenderKey(sender) or nil
    if not senderKey then
        return nil
    end
    return PartyOffCD.cooldowns[senderKey]
end

local function RuleTalentStatePasses(candidateUnit, rule, specID)
    local talentTracker = PartyOffCDCore and PartyOffCDCore.TalentTracker
    if not talentTracker or not talentTracker.UnitHasTalent then
        return true
    end

    if rule.ExcludeIfTalent and talentTracker:UnitHasTalent(candidateUnit, rule.ExcludeIfTalent, specID) then
        return false
    end
    if rule.RequiresTalent and not talentTracker:UnitHasTalent(candidateUnit, rule.RequiresTalent, specID) then
        return false
    end
    return true
end

local function GetExpectedBuffDuration(candidateUnit, rule, specID, classToken)
    local talentTracker = PartyOffCDCore and PartyOffCDCore.TalentTracker
    if talentTracker and talentTracker.GetUnitBuffDuration and rule.SpellID then
        return talentTracker:GetUnitBuffDuration(candidateUnit, specID, classToken, rule.SpellID, rule.BuffDuration)
    end
    return rule.BuffDuration
end

local function MatchRule(candidateUnit, auraTypes, measuredDuration, context)
    local _, classToken = UnitClass(candidateUnit)
    if not classToken then
        return nil
    end

    local specID = PartyOffCDCore.GetUnitSpecID and PartyOffCDCore.GetUnitSpecID(candidateUnit) or nil
    local evidence = context and context.Evidence or nil
    local activeCooldowns = context and context.ActiveCooldowns or nil

    local function TryRuleList(ruleList)
        if not ruleList then
            return nil
        end

        local fallback = nil
        for _, rule in ipairs(ruleList) do
            if RuleTalentStatePasses(candidateUnit, rule, specID) and AuraTypeMatchesRule(auraTypes, rule) then
                local expectedDuration = GetExpectedBuffDuration(candidateUnit, rule, specID, classToken)
                if EvidenceMatchesRequirement(rule.RequiresEvidence, evidence) then
                    local durationOk
                    if rule.MinDuration then
                        durationOk = measuredDuration >= (expectedDuration - tolerance)
                    elseif rule.CanCancelEarly then
                        durationOk = measuredDuration <= (expectedDuration + tolerance)
                    else
                        durationOk = math.abs(measuredDuration - expectedDuration) <= tolerance
                    end

                    if durationOk then
                        local alreadyOnCooldown = activeCooldowns and rule.SpellID and activeCooldowns[rule.SpellID]
                        if not alreadyOnCooldown then
                            return rule
                        elseif not fallback then
                            fallback = rule
                        end
                    end
                end
            end
        end

        return fallback
    end

    return TryRuleList(specID and auraRules.bySpec[specID]) or TryRuleList(auraRules.byClass[classToken])
end

local function GetStaticSpellIDs(unit)
    if not unit or not UnitExists(unit) then
        return {}
    end

    local _, classToken = UnitClass(unit)
    if not classToken then
        return {}
    end

    local specID = PartyOffCDCore.GetUnitSpecID and PartyOffCDCore.GetUnitSpecID(unit) or nil
    local seen = {}
    local result = {}

    local function AddRules(ruleList)
        if not ruleList then
            return
        end

        for _, rule in ipairs(ruleList) do
            local spellID = rule.SpellID
            if spellID and not seen[spellID] and RuleTalentStatePasses(unit, rule, specID) then
                seen[spellID] = true
                result[#result + 1] = spellID
            end
        end
    end

    AddRules(specID and auraRules.bySpec[specID])
    AddRules(auraRules.byClass[classToken])

    return result
end

local function AuraTypesSignature(auraTypes)
    local signature = ""
    if auraTypes.BIG_DEFENSIVE then
        signature = signature .. "B"
    end
    if auraTypes.EXTERNAL_DEFENSIVE then
        signature = signature .. "E"
    end
    if auraTypes.IMPORTANT then
        signature = signature .. "I"
    end
    return signature
end

local function ResolveAuraDuration(auraData)
    if not auraData then
        return nil
    end

    local duration = tonumber(auraData.duration or auraData.Duration or auraData.durationSeconds)
    if duration and duration > 0 then
        return duration
    end

    return nil
end

local function BuildCurrentAuraIDs(unit)
    local currentIDs = {}
    if not (C_UnitAuras and C_UnitAuras.GetUnitAuras and C_UnitAuras.IsAuraFilteredOutByInstanceID) then
        return currentIDs
    end

    local function AddAuras(filter, auraKey)
        local auras = C_UnitAuras.GetUnitAuras(unit, filter)
        for _, auraData in ipairs(auras or {}) do
            local id = auraData and auraData.auraInstanceID
            if id then
                currentIDs[id] = currentIDs[id] or { AuraTypes = {} }
                currentIDs[id].AuraTypes[auraKey] = true
                currentIDs[id].BuffDuration = currentIDs[id].BuffDuration or ResolveAuraDuration(auraData)
                if not C_UnitAuras.IsAuraFilteredOutByInstanceID(unit, id, "HELPFUL|IMPORTANT") then
                    currentIDs[id].AuraTypes.IMPORTANT = true
                end
            end
        end
    end

    AddAuras("HELPFUL|BIG_DEFENSIVE", "BIG_DEFENSIVE")
    AddAuras("HELPFUL|EXTERNAL_DEFENSIVE", "EXTERNAL_DEFENSIVE")

    local importantAuras = C_UnitAuras.GetUnitAuras(unit, "HELPFUL|IMPORTANT")
    for _, auraData in ipairs(importantAuras or {}) do
        local id = auraData and auraData.auraInstanceID
        if id then
            currentIDs[id] = currentIDs[id] or { AuraTypes = {} }
            currentIDs[id].AuraTypes.IMPORTANT = true
            currentIDs[id].BuffDuration = currentIDs[id].BuffDuration or ResolveAuraDuration(auraData)
        end
    end

    return currentIDs
end

local function TrackNewAura(unit, trackedAuras, id, info, now)
    local evidence = BuildEvidenceSet(unit, now)
    local castSnapshot = {}
    for snapshotUnit, snapshotTime in pairs(lastCastTime) do
        castSnapshot[snapshotUnit] = snapshotTime
    end

    trackedAuras[id] = {
        StartTime = now,
        AuraTypes = info.AuraTypes,
        BuffDuration = info.BuffDuration,
        Evidence = evidence,
        CastSnapshot = castSnapshot,
    }

    C_Timer.After(evidenceTolerance, function()
        local tracked = trackedAuras[id]
        if not tracked then
            return
        end

        local lateEvidence = BuildEvidenceSet(unit, now)
        if lateEvidence then
            tracked.Evidence = tracked.Evidence or {}
            for key in pairs(lateEvidence) do
                tracked.Evidence[key] = true
            end
        end

        for snapshotUnit, snapshotTime in pairs(lastCastTime) do
            if math.abs(snapshotTime - now) <= castWindow and not tracked.CastSnapshot[snapshotUnit] then
                tracked.CastSnapshot[snapshotUnit] = snapshotTime
            end
        end
    end)
end

local function FindBestCandidate(entryUnit, tracked, measuredDuration)
    local bestRule = nil
    local bestUnit = entryUnit
    local bestCastTime = nil
    local isExternal = tracked.AuraTypes.EXTERNAL_DEFENSIVE

    local function Consider(candidateUnit, isTarget)
        if not candidateUnit or not UnitExists(candidateUnit) or UnitCanAttack("player", candidateUnit) then
            return
        end

        local candidateEvidence = nil
        if tracked.Evidence then
            for key in pairs(tracked.Evidence) do
                if key ~= "Cast" then
                    candidateEvidence = candidateEvidence or {}
                    candidateEvidence[key] = true
                end
            end
        end

        local castTime = tracked.CastSnapshot[candidateUnit]
        if castTime and math.abs(castTime - tracked.StartTime) <= castWindow then
            candidateEvidence = candidateEvidence or {}
            candidateEvidence.Cast = true
        end

        local candidateRule = MatchRule(candidateUnit, tracked.AuraTypes, measuredDuration, {
            Evidence = candidateEvidence,
            ActiveCooldowns = GetCandidateActiveCooldowns(candidateUnit),
        })
        if not candidateRule then
            return
        end

        local isBetter = not bestRule
            or (castTime and (not bestCastTime or castTime > bestCastTime))
            or (not castTime and not bestCastTime and isExternal and not isTarget)

        if isBetter then
            bestRule = candidateRule
            bestUnit = candidateUnit
            bestCastTime = castTime
        end
    end

    Consider(entryUnit, true)
    for _, rosterEntry in ipairs(PartyOffCD.roster or {}) do
        if rosterEntry.unit and rosterEntry.unit ~= entryUnit then
            Consider(rosterEntry.unit, false)
        end
    end

    return bestRule, bestUnit
end

local function GetActiveAuras(unit)
    if not unit or not UnitExists(unit) or UnitCanAttack("player", unit) then
        return {}
    end

    local results = {}
    local seen = {}
    local observedAuraState = PartyOffCD.observedAuraState or nil
    if not observedAuraState then
        return results
    end

    for observedUnit, unitState in pairs(observedAuraState) do
        local trackedAuras = unitState and unitState.trackedAuras or nil
        if trackedAuras then
            for _, tracked in pairs(trackedAuras) do
                local measuredDuration = tracked and tracked.BuffDuration or nil
                if measuredDuration and measuredDuration > 0 then
                    local rule, ruleUnit = FindBestCandidate(observedUnit, tracked, measuredDuration)
                    if rule and ruleUnit == unit and rule.SpellID and not seen[rule.SpellID] then
                        seen[rule.SpellID] = true
                        results[#results + 1] = {
                            SpellID = rule.SpellID,
                            StartTime = tracked.StartTime,
                            BuffDuration = measuredDuration,
                        }
                    end
                end
            end
        end
    end

    table.sort(results, function(a, b)
        return (a.StartTime or 0) > (b.StartTime or 0)
    end)

    return results
end

local function GetActiveSpellIDs(unit)
    local results = {}
    for _, aura in ipairs(GetActiveAuras(unit)) do
        if aura and aura.SpellID then
            results[#results + 1] = aura.SpellID
        end
    end
    return results
end

local function CommitRule(tracked, rule, ruleUnit)
    local sender = PartyOffCDCore.GetUnitFullName(ruleUnit) or UnitName(ruleUnit)
    if not sender then
        return false
    end

    return PartyOffCD:HandleObservedSenderSpellcast(sender, rule.SpellID, tracked.StartTime, ruleUnit)
end

function PartyOffCD:HandleObservedUnitSpellcastEvidence(unit)
    if unit and UnitExists(unit) and not UnitCanAttack("player", unit) then
        lastCastTime[unit] = GetTime()
    end
end

function PartyOffCD:HandleObservedUnitFlagsChanged(unit)
    if not unit or not UnitExists(unit) or UnitCanAttack("player", unit) then
        return
    end

    local now = GetTime()
    local isFeign = UnitIsFeignDeath(unit)
    if isFeign and not lastFeignDeathState[unit] then
        lastFeignDeathTime[unit] = now
    end
    lastFeignDeathState[unit] = isFeign
    if not isFeign then
        lastUnitFlagsTime[unit] = now
    end
end

function PartyOffCD:HandleObservedAbsorbAmountChanged(unit)
    if unit and UnitExists(unit) and not UnitCanAttack("player", unit) then
        lastShieldTime[unit] = GetTime()
    end
end

function PartyOffCD:HandleObservedUnitAuraEvidence(unit, updateInfo)
    if not updateInfo or updateInfo.isFullUpdate or not updateInfo.addedAuras or not C_UnitAuras or not C_UnitAuras.IsAuraFilteredOutByInstanceID then
        return
    end

    for _, aura in ipairs(updateInfo.addedAuras) do
        local id = aura and aura.auraInstanceID
        if id and not C_UnitAuras.IsAuraFilteredOutByInstanceID(unit, id, "HARMFUL") then
            lastDebuffTime[unit] = GetTime()
            break
        end
    end
end

function PartyOffCD:HandleObservedUnitAuraChanged(unit, updateInfo)
    if not self:IsEnabledForCurrentContext() or not unit or not UnitExists(unit) or UnitCanAttack("player", unit) then
        return
    end

    self:HandleObservedUnitAuraEvidence(unit, updateInfo)

    self.observedAuraState = self.observedAuraState or {}
    local unitState = self.observedAuraState[unit]
    if not unitState then
        unitState = { trackedAuras = {} }
        self.observedAuraState[unit] = unitState
    end

    local trackedAuras = unitState.trackedAuras
    local now = GetTime()
    local currentIDs = BuildCurrentAuraIDs(unit)

    local unmatchedNewIDs = {}
    for id in pairs(currentIDs) do
        if not trackedAuras[id] then
            unmatchedNewIDs[#unmatchedNewIDs + 1] = id
        end
    end

    local newIDsBySignature = {}
    for _, id in ipairs(unmatchedNewIDs) do
        local signature = AuraTypesSignature(currentIDs[id].AuraTypes)
        newIDsBySignature[signature] = newIDsBySignature[signature] or {}
        table.insert(newIDsBySignature[signature], id)
    end

    for id, tracked in pairs(trackedAuras) do
        if not currentIDs[id] then
            local signature = AuraTypesSignature(tracked.AuraTypes)
            local candidates = newIDsBySignature[signature]
            if candidates and #candidates > 0 then
                local reassignedID = table.remove(candidates, 1)
                trackedAuras[reassignedID] = tracked
            else
                local measuredDuration = now - tracked.StartTime
                local rule, ruleUnit = FindBestCandidate(unit, tracked, measuredDuration)
                if rule and ruleUnit then
                    CommitRule(tracked, rule, ruleUnit)
                end
            end
            trackedAuras[id] = nil
        end
    end

    for id, info in pairs(currentIDs) do
        if not trackedAuras[id] then
            TrackNewAura(unit, trackedAuras, id, info, now)
        end
    end
end

PartyOffCDCore.AuraTracker = PartyOffCDCore.AuraTracker or {}
PartyOffCDCore.AuraTracker.GetActiveAuras = GetActiveAuras
PartyOffCDCore.AuraTracker.GetStaticSpellIDs = GetStaticSpellIDs
PartyOffCDCore.AuraTracker.GetActiveSpellIDs = GetActiveSpellIDs
