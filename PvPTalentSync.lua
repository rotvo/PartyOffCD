local _, PartyOffCDCore = ...

PartyOffCDCore = PartyOffCDCore or _G.PartyOffCDCore or {}
_G.PartyOffCDCore = PartyOffCDCore

local M = PartyOffCDCore.PvPTalentSync or {}
PartyOffCDCore.PvPTalentSync = M

local PREFIX = "POCD:Talents"
local THROTTLE_TIMER = 3

local callbacks = {}
local frame = CreateFrame("Frame")
local playerName = UnitNameUnmodified("player")
local currentMessage = ""

local SendAddonMessage = C_ChatInfo and C_ChatInfo.SendAddonMessage
local HOME_PARTY_CATEGORY = LE_PARTY_CATEGORY_HOME
    or (Enum and Enum.PartyCategory and Enum.PartyCategory.Home)
    or 1
local INSTANCE_PARTY_CATEGORY = LE_PARTY_CATEGORY_INSTANCE
    or (Enum and Enum.PartyCategory and Enum.PartyCategory.Instance)
    or 2

local function GetGroupMemberCount(category)
    if type(GetNumGroupMembers) ~= "function" then
        return 0
    end

    local ok, count = pcall(GetNumGroupMembers, category)
    if ok and type(count) == "number" then
        return count
    end

    ok, count = pcall(GetNumGroupMembers)
    if ok and type(count) == "number" then
        return count
    end

    return 0
end

local function HasHomeGroupChannel()
    if UnitExists and UnitExists("party1") then
        return true
    end

    return GetGroupMemberCount(HOME_PARTY_CATEGORY) > 1
end

local function HasInstanceGroupChannel()
    return GetGroupMemberCount(INSTANCE_PARTY_CATEGORY) > 1
end

if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
    local result = C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
    if type(result) == "number" and result > 1 then
        -- Failed to register; PvP talent sync remains disabled.
    end
end

local function GetLocalPvPTalentIDs()
    if not (C_SpecializationInfo and C_SpecializationInfo.GetAllSelectedPvpTalentIDs) then
        return nil
    end

    local ids = C_SpecializationInfo.GetAllSelectedPvpTalentIDs()
    return (ids and #ids > 0) and ids or nil
end

local function IDsToMessage(ids)
    if not ids then
        return ""
    end

    local parts = {}
    for index, talentID in ipairs(ids) do
        parts[index] = tostring(talentID)
    end

    return table.concat(parts, ",")
end

local function MessageToIDs(message)
    if not message or message == "" then
        return nil
    end

    local ids = {}
    for part in message:gmatch("[^,]+") do
        local talentID = tonumber(part)
        if talentID then
            ids[#ids + 1] = talentID
        end
    end

    return #ids > 0 and ids or nil
end

local function FireCallbacks(name, pvpTalentIDs)
    for _, callback in ipairs(callbacks) do
        securecallfunction(callback, name, pvpTalentIDs)
    end
end

local prepareForGroup
do
    local timerGroup = nil

    local function SendToGroup()
        timerGroup = nil
        if SendAddonMessage and HasHomeGroupChannel() then
            local result = SendAddonMessage(PREFIX, currentMessage, "RAID")
            if result == 9 then
                timerGroup = C_Timer.NewTimer(THROTTLE_TIMER, SendToGroup)
            end
        end
    end

    function prepareForGroup()
        currentMessage = IDsToMessage(GetLocalPvPTalentIDs())
        if not timerGroup then
            timerGroup = C_Timer.NewTimer(THROTTLE_TIMER, SendToGroup)
        end
    end
end

local prepareForInstance
do
    local timerInstance = nil

    local function SendToInstance()
        timerInstance = nil
        if SendAddonMessage and HasInstanceGroupChannel() then
            local result = SendAddonMessage(PREFIX, currentMessage, "INSTANCE_CHAT")
            if result == 9 then
                timerInstance = C_Timer.NewTimer(THROTTLE_TIMER, SendToInstance)
            end
        end
    end

    function prepareForInstance()
        currentMessage = IDsToMessage(GetLocalPvPTalentIDs())
        if not timerInstance then
            timerInstance = C_Timer.NewTimer(THROTTLE_TIMER, SendToInstance)
        end
    end
end

function M:RegisterCallback(callback)
    if type(callback) == "function" then
        callbacks[#callbacks + 1] = callback
    end
end

function M:RequestSync()
    FireCallbacks(playerName, GetLocalPvPTalentIDs())

    if SendAddonMessage then
        if HasInstanceGroupChannel() then
            SendAddonMessage(PREFIX, "R", "INSTANCE_CHAT")
        end
        if HasHomeGroupChannel() then
            SendAddonMessage(PREFIX, "R", "RAID")
        end
    end
end

frame:SetScript("OnEvent", function(_, event, prefix, message, channel, sender)
    if event == "CHAT_MSG_ADDON" then
        if prefix == PREFIX and (channel == "RAID" or channel == "PARTY" or channel == "INSTANCE_CHAT") then
            if message == "R" then
                if channel == "INSTANCE_CHAT" then
                    prepareForInstance()
                else
                    prepareForGroup()
                end
                return
            end

            local name = Ambiguate and Ambiguate(sender, "none") or sender
            FireCallbacks(name, MessageToIDs(message))
        end
    elseif event == "GROUP_FORMED" then
        M:RequestSync()
    elseif event == "PLAYER_PVP_TALENT_UPDATE" then
        FireCallbacks(playerName, GetLocalPvPTalentIDs())
        if HasInstanceGroupChannel() then
            prepareForInstance()
        end
        if HasHomeGroupChannel() then
            prepareForGroup()
        end
    elseif event == "PLAYER_LOGIN" then
        M:RequestSync()
    end
end)

frame:RegisterEvent("CHAT_MSG_ADDON")
frame:RegisterEvent("GROUP_FORMED")
frame:RegisterEvent("PLAYER_PVP_TALENT_UPDATE")
frame:RegisterEvent("PLAYER_LOGIN")
