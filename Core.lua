local ADDON_NAME, PartyOffCDCore = ...

PartyOffCDCore = PartyOffCDCore or _G.PartyOffCDCore or {}
_G.PartyOffCDCore = PartyOffCDCore

PartyOffCDCore.ADDON_NAME = ADDON_NAME

PartyOffCDCore.DEFAULTS = {
    configPoint = "CENTER",
    configRelativePoint = "CENTER",
    configX = 0,
    configY = 0,
    trackerAnchorSource = "BLIZZARD",
    trackerAttach = "LEFT",
    trackerColumns = 1,
    trackerIconScale = 100,
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
    classEnabled = {},
    spellEnabled = {},
    customSpells = {},
    syncedOverrides = {},
}
