local _, PartyOffCDCore = ...
PartyOffCDCore = PartyOffCDCore or _G.PartyOffCDCore

local PartyOffCD = _G.PartyOffCD
assert(PartyOffCD, "PartyOffCD: frame missing before loading Comms.lua")
assert(PartyOffCDCore, "PartyOffCD: core missing before loading Comms.lua")

local PREFIX = PartyOffCDCore.PREFIX
local MESSAGE_VERSION = PartyOffCDCore.MESSAGE_VERSION
local CLASS_LABELS = PartyOffCDCore.CLASS_LABELS
local SPELL_TYPE_PRIORITY = PartyOffCDCore.SPELL_TYPE_PRIORITY
local SPELLS = PartyOffCDCore.SPELLS
local BASE_SPELLS = PartyOffCDCore.BASE_SPELLS

local NormalizeName = PartyOffCDCore.NormalizeName
local DebugPrint = PartyOffCDCore.DebugPrint
local SafeGetSpellInfo = PartyOffCDCore.SafeGetSpellInfo

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

function PartyOffCD:EncodeDeleteMessage(spellID, specID)
    return table.concat({
        MESSAGE_VERSION,
        "D",
        tostring(spellID),
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

    if action == "D" then
        local spellID = tonumber(a)
        local senderSpecID = tonumber(b)
        if not spellID then
            return nil
        end

        return action, spellID, senderSpecID
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

function PartyOffCD:MarkAddonUser(senderKey)
    senderKey = self:ResolveSenderKey(senderKey)
    if not senderKey then
        return false
    end

    local stamp = GetTime()
    self.addonUsers[senderKey] = stamp

    local rosterEntry = self.rosterLookup[senderKey]
    if rosterEntry then
        if rosterEntry.key then
            self.addonUsers[rosterEntry.key] = stamp
        end
        if rosterEntry.shortKey then
            self.addonUsers[rosterEntry.shortKey] = stamp
        end
    end

    return true
end

function PartyOffCD:HasAddon(senderKey)
    senderKey = self:ResolveSenderKey(senderKey)
    if not senderKey then
        return false
    end

    if senderKey == self.playerKeys.full or senderKey == self.playerKeys.short then
        return true
    end

    local rosterEntry = self.rosterLookup[senderKey]
    if rosterEntry then
        if rosterEntry.key and self.addonUsers[rosterEntry.key] then
            return true
        end
        if rosterEntry.shortKey and self.addonUsers[rosterEntry.shortKey] then
            return true
        end
    end

    return self.addonUsers[senderKey] ~= nil
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

function PartyOffCD:SendDeleteMessage(spellID)
    local channel = self:GetTargetChannel()
    if not channel then
        return false
    end

    local message = self:EncodeDeleteMessage(spellID, self:GetCurrentPlayerSpecID())
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
    local message = string.format("%s updated %s to %ss", senderName, spellName, tostring(meta.cd))
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


function PartyOffCD:SendUseMessage(spellID)
    local channel = self:GetTargetChannel()
    if not channel then
        return false
    end

    local message = self:EncodeUseMessage(spellID, GetTime(), self:GetCurrentPlayerSpecID())
    C_ChatInfo.SendAddonMessage(PREFIX, message, channel)
    return true
end


function PartyOffCD:HandleAddonMessage(prefix, message, _, sender)
    if prefix ~= PREFIX then
        return
    end

    if self:IsSelfSender(sender) then
        return
    end

    local senderKey = self:ResolveSenderKey(sender)
    if not senderKey then
        return
    end
    self:MarkAddonUser(senderKey)

    local action, spellID, valueA, valueB, valueC, valueD = self:DecodeMessage(message)
    if not action then
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

    if action == "D" then
        local senderSpecID = valueA
        self:UpdateSenderSpecID(senderKey, senderSpecID)
        if self:DeleteSenderOverride(senderKey, spellID) then
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


