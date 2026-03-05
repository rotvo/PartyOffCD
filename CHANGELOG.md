# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog, and this project follows Semantic Versioning.

## [Unreleased]

### Added
- Project metadata files: `LICENSE`, `CHANGELOG.md`, and `Core.lua`.
- Shared core defaults moved to `Core.lua` for cleaner modular growth.
- New movable and closable `Missing Buffs` panel that shows missing group buffs with icon + `MISSING`.
- `/pocd buffs` slash command to show/hide the missing buffs panel.
- `/pocd interrupts` slash command to show/hide the interrupts panel.
- Config tabs added: `Cooldowns`, `Interrupts`, and `Missing Buffs`.
- Interrupts and Missing Buffs tabs include Show/Hide and Lock toggles.
- Interrupts and Missing Buffs frames now include an in-frame lock button for quick locking.

### Changed
- Addon code split into modules: `Spells.lua`, `Comms.lua`, `Tracker.lua`, and `ConfigUI.lua`.
- Spell data and class/spec buff metadata moved out of `PartyOffCD.lua` into `Spells.lua`.

## [0.1.1] - 2026-03-05

### Changed
- Current addon version defined in `PartyOffCD.toc`.
