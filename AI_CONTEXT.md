# PartyOffCD AI Context

This addon's OFF/DEF auto-tracking must follow the MiniCC-style aura/evidence model only.

Rules:
- `AuraTracker.lua` is the only source of truth for automatic `OFF` and `DEF` detection.
- Auto-detection starts from watched aura instance changes on party units, not from combat log, spellcasts alone, name scans, or guessed cooldowns.
- Evidence may only be the MiniCC-style set already in code: `Cast`, `Debuff`, `Shield`, `UnitFlags`, `FeignDeath`, plus the deferred backfill window.
- A cooldown is committed when the tracked aura ends, using the original aura start time.
- `INT` is the only exception: it still uses combat log because interrupts do not leave a tracked friendly aura.

How to add support:
- Add or update the spell metadata in `Spells.lua`.
- Add an explicit rule in `AuraTracker.lua`.
- Only add spells that leave a reliable friendly aura/evidence pattern.

Do not do this:
- Do not revive the old PartyOffCD tracking approach.
- Do not add fallback aura-name/index scans or generic "try everything" heuristics for OFF/DEF attribution.
- Do not auto-start OFF/DEF cooldowns from combat log, local cooldown APIs, or `UNIT_SPELLCAST_SUCCEEDED` alone.
- If a spell has no reliable aura/evidence path after Blizzard API changes, leave it unsupported or build a clearly separate system.

UI conventions:
- `OFF` = glow alert and cooldown icon in the HP-bar tracker. While the aura is active, the tracker icon may glow before the cooldown starts.
- `DEF` = cooldown icon in the HP-bar tracker, plus one small center-frame icon while the defensive aura is active. Do not use glow alerts for `DEF`.
