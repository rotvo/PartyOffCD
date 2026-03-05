# Changelog

## [Unreleased] (WIP)

### New
- Added a **Missing Buffs** window with spell icon + `MISSING` label.
- Added an **Interrupts** tracker window.
- Added config tabs: **Cooldowns**, **Interrupts**, and **Missing Buffs**.
- Added **Show/Hide** and **Lock** controls for Interrupts and Missing Buffs.
- Added in-frame lock buttons so users can lock those windows without opening config.

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

### Commands
- `/pocd config` opens the config panel.
- `/pocd buffs` toggles Missing Buffs window.
- `/pocd interrupts` toggles Interrupts window.
- `/pocd test` starts sample cooldowns for testing UI/screenshots.

## [0.1.1] - 2026-03-05

### Initial Public Build
- Base cooldown tracker for offensive/defensive spells.
- Group sync support for cooldown reports.
