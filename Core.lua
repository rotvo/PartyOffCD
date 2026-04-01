local ADDON_NAME, PartyOffCDCore = ...

PartyOffCDCore = PartyOffCDCore or _G.PartyOffCDCore or {}
_G.PartyOffCDCore = PartyOffCDCore

PartyOffCDCore.ADDON_NAME = ADDON_NAME

PartyOffCDCore.DEFAULTS = {
    configPoint = "CENTER",
    configRelativePoint = "CENTER",
    configX = 0,
    configY = 0,
    trackerAttach = "LEFT",
    trackerOffsetX = -4,
    trackerOffsetY = 0,
    trackerColumns = 1,
    trackerIconScale = 100,
    trackerMaxIcons = 10,
    trackerRows = 1,
    trackerShowOffensive = true,
    trackerShowDefensive = true,
    trackerShowTooltips = true,
    trackerReverseCooldown = false,
    trackerExcludeSelf = false,
    interruptPoint = "CENTER",
    interruptRelativePoint = "CENTER",
    interruptX = -260,
    interruptY = 140,
    interruptHidden = false,
    interruptLocked = false,
    missingBuffPoint = "CENTER",
    missingBuffRelativePoint = "CENTER",
    missingBuffX = 230,
    missingBuffY = 140,
    missingBuffsHidden = false,
    missingBuffsLocked = false,
    minimap = {
        angle = 220,
    },
    enabledContexts = {
        world = true,
        arena = true,
        dungeons = true,
        raid = true,
    },
    classEnabled = {},
    spellEnabled = {},
    customSpells = {},
    syncedOverrides = {},
    specCache = {},
    talentCache = {},
    pvpTalentCache = {},
}
