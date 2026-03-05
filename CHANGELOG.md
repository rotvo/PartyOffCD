# Changelog

## [Unreleased] (WIP)

### New
- Added a **Missing Buffs** window with spell icon + `MISSING` label.
- Added an **Interrupts** tracker window.
- Added config tabs: **Cooldowns**, **Interrupts**, and **Missing Buffs**.
- Added **Show/Hide** and **Lock** controls for Interrupts and Missing Buffs.
- Added in-frame lock buttons so users can lock those windows without opening config.
- Added cooldown tracker layout options: `LEFT/RIGHT/TOP/BOTTOM` attach plus configurable columns (`1..8`).
- Added a tracker icon size control in Cooldowns settings (`Icon Size %`, min/max clamped).
- Reworked Cooldowns spell configuration UI to a class list (left) + class spell list (right) flow with Add New/Edit/Save.
- Updated Cooldowns spell configuration UI to class dropdown with class icons and cleaner spacing for controls.
- Updated Cooldowns spell configuration UI again to keep the class list always visible on the left and spells on the right.

### Missing Buffs: current tracked buffs
- Mage: **Arcane Intellect**
- Priest: **Power Word: Fortitude**
- Warrior: **Battle Shout**
- Evoker: **Blessing of the Bronze**
- Druid: **Mark of the Wild**
- Shaman: **Skyfury** (with spell ID fallback support)

### Improvements
- Missing Buff checks now evaluate the **player buff state** for display logic.
- Improved aura detection reliability for missing buffs (spell ID + aura name fallback).
- Improved movable window behavior with persistent position and lock state.
- Fixed cooldown layout wrapping for `TOP/BOTTOM` attach so column count behaves consistently.
- Added vertical attach column cap (`4`) to keep party frame layouts compact.
- Fixed an Edit Mode error path caused by `AuraUtil.FindAuraByName` API differences.
- In `LEFT/RIGHT` attach, `Icon Size % = 100%` now means the maximum size that fits the unit frame height.
- Improved missing buff detection with additional aura-name scanning fallbacks.
- Added extra fallback scans (`C_UnitAuras` by index spellID/name + `UnitBuff`) for missing buff detection stability.

### Commands
- `/pocd config` opens the config panel.
- `/pocd buffs` toggles Missing Buffs window.
- `/pocd interrupts` toggles Interrupts window.
- `/pocd test` starts sample cooldowns for testing UI/screenshots.

## [0.1.1] - 2026-03-05

### Initial Public Build
- Base cooldown tracker for offensive/defensive spells.
- Group sync support for cooldown reports.
