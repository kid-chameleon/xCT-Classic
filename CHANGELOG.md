# xCT+ Classic Changelog

## Unreleased

### New Features
- **WoW: Forever support** (interface 16001, `xCT+_Mainline.toc`). The mainline engine has no addon-readable combat log and returns secret values for health, power, in-combat auras and every `COMBAT_TEXT_UPDATE` payload, so the combat log parser is never registered there. A new `modules/sources.lua` feeds the existing handlers from what the engine still offers: `UNIT_COMBAT` for incoming damage, misses, heals and power (plain amounts, no attacker or spell name); the `UNIT_AURA` payload out of combat for buff/debuff lines with names, icons and filters, and the secret `COMBAT_TEXT_UPDATE` name in combat (printed as-is, no icon or filter); `LowHealthFrame` and Blizzard's own "Health Low"/"Mana Low" messages for the low-resource lines and sounds; `PARTY_KILL` for killing blows in the open world; the target's `UNIT_SPELLCAST_INTERRUPTED` in the same frame as the player's own cast for interrupt lines; and the reputation/honor chat messages. Outgoing damage and healing lines are not produced on that client: the only attribution left is a timing guess against the player's own casts, and an inexact frame was judged worse than none. Blizzard's own numbers over the target still work. The reasoning, probe results and remaining plan are in `doc/forever-support.md`.
- **Options that cannot apply on the mainline engine are greyed out**, with a short "On this client:" note at the top of each affected section saying why: dispels, proc filters and icons, incoming-damage names, icons and spell filters, overheal/absorb/pet options on the Healing frame, periodic power gains, the merger's outgoing-only options, outgoing thresholds and spell filters, the Blizzard FCT toggles whose cvars no longer exist, the low health/mana sound thresholds (the game's own 35%/20% edges are used) and the Outgoing and Critical frames' content settings. The "Show Low HP/Mana" cvar shows as locked on.
- **"Hide Blizzard's Text"** (Floating Combat Text page, mainline engine only) keeps Blizzard's self text enabled but invisible, since its "Mana Low" message is the only low-mana signal on that client. The Blizzard cvar that gates that message (`floatingCombatTextLowManaHealth_v2`) is kept on there regardless of the profile's toggle.

### Bug Fixes
- **Loot messages errored on the mainline engine** — its item links carry a named colour (`|cnIQ1:`) where classic has `|cff<hex>`, so the loot pattern never matched and the crafted-item fallback ran with a nil pattern. The pattern now accepts either form, and a message with no recognisable link is ignored instead of raising.
- **Incoming heals without a spell id errored** (`table index is nil` in `HealingIncoming`) on the event-source client, where a heal not attributed to the player's own cast has no spell. Guarded; self-heals are now also recognised when the heal lands before the cast's own success event in the same frame.
- **Skill-up lines never showed** — the `CHAT_MSG_SKILL` handler lived in the `COMBAT_TEXT_UPDATE` subtype table, which the event dispatcher never consults for a frame event. Moved to the frame event table; "+ Skill (rank)" lines appear again on every client.

### Code Cleanup
- `x.cvar_update` writes its 24 Blizzard cvars from a list instead of 24 copies of the same five lines, and only writes names the client has (the mainline engine renamed the survivors with a `_v2` suffix and dropped the rest).
- Modules call `C_Spell.GetSpellName/GetSpellTexture` and `C_CombatText.SetActiveUnit/GetCurrentEventInfo`; `compat.lua` shims those, per function, on the classic clients, and shims the `SetDesaturation` global the vendored AceGUI CheckBox widget needs on mainline.
- `libs/xCombatParser-1.0` resolves the auto-attack name through `C_Spell` so it loads on a client without `GetSpellInfo` (it is idle there).

---

## 4.7.4 — 2026-09-02

### Bug Fixes
- **UTF8 library was disabled by the compat layer** — `compat.lua` loads before `libs/` and installed byte-based `string.utf8*` stubs. `libs/UTF8` only installs its real, multi-byte-aware implementations when those slots are empty, so it was silently skipped and every `utf8.sub`/`utf8.upper` call fell back to raw byte slicing. This corrupted the first character of the localized "Stole", "Killed" and "Dispelled" labels on every non-ASCII locale (zhCN, ruRU, deDE, frFR). The stub is gone; the real library now installs.
- **Proc Name filter did nothing** — the "Proc Name" input in Filters → Procs referenced an undefined `setProc`, so its setter was `nil`. AceConfig silently ignores a nil setter, so typing a proc name appeared to work but never wrote anything. Now uses `setSpell`, like the other thirteen filter inputs.
- **Outgoing "Show Overhealing" did nothing** — `HealingOutgoing` gated overhealing on the *incoming* Healing frame's `enableOverHeal`, leaving the Outgoing frame's own toggle unread. The two frames are now independent.
- **Outgoing "Show Absorbs" did nothing** — the "target absorbed all damage" case was gated on `enableOutAbsorbs` ("absorbs you apply"). It now uses `enableAbsorbs`, which is the setting written for it.
- **"Merge Ranged Attacks" did nothing** — auto shot was merged under "Merge Melee Swings". Each toggle now governs its own attack type.
- **"Show Periodic Energy Gains" did nothing** — periodic energize was folded into the normal energize handler with no way to distinguish it. It is gated again, on the `SPELL_PERIODIC` prefix.
- **Kill Command was never detected** — `KILLCOMMAND_ID` was `83381`, the Cataclysm-era pet damage spell, which does not exist on TBC or Classic Era. Corrected to `34026`, matching the id already used to resolve the spell name, so the "Show Kill Command" option works and pet Kill Command damage is no longer labelled as auto attack.
- **`C_AddOns` shim was incomplete** — `libs/LibSink-2.0` upvalues `C_AddOns.EnableAddOn`, `IsAddOnLoaded` and `LoadAddOn` at load time; the shim only provided `GetAddOnMetadata`. Added, so the shim is safe on any client that lacks a native `C_AddOns`.

### Performance
- The per-frame alpha worker ran an `OnUpdate` over every frame permanently, from load, even though the default profile leaves every frame at full opacity and the loop therefore produced nothing. It is now shown only while some frame actually uses a custom alpha, and armed from `x:UpdateFrames`.

### Code Cleanup
- Removed the unused table pool (`tpool`/`tnew`/`tdel`) — never called, and `tdel` did not wipe entries before pooling them.
- Removed the battle-pet loot branch: battle pets do not exist on TBC or Classic Era, so `linkType == "battlepet"` was unreachable. This also drops the only `C_PetJournal` call, which had no compat shim, and the `format_pet` string built from the retail-only `BATTLE_PET_CAGE_ITEM_NAME`.
- Deleted `config/merge_race.lua` and `config/merge_item.lua` — both had their entire payload commented out and referenced retail-only races and items.
- Deleted `media/colors.lua` — no content, and never listed in `media/include.xml`, so it shipped without ever being loaded.
- Removed accessors that were defined but never called: `ShowFriendlyNames`, `ShowColoredFriendlyNames` and `ShowHealingRealmNames` (which read profile keys that do not exist), `MergeDontMergeCriticals` (redundant — it is the fall-through of the critical-merge chain) and `IsBearForm`.
- Removed unused option helpers `get1`, `set1`, `set1_update`, `set2_update_force`, `outgoingSpellColorsHidden`, `isFrameEnabled`, `isFrameDisabled` and `GetSoundList`, the never-read `PLAYER_NAME`/`PLAYER_CLASS` block, and `CLASS_LOOKUP`.
- Removed `addon.IsTBC`, which was written once, read nowhere, and hardcoded to `true` even on the Classic Era build.
- `SCHOOL_MASK_*` moved from `config/profile.lua` to `compat.lua` alongside the other shims, and changed from an unconditional overwrite of Blizzard's globals to filling in only what the client is missing.
- Removed duplicate `width` keys in four colour options, dead stores, unread captures and unused upvalues.
- Added `.luacheckrc` describing the addon's WoW API surface. Static analysis now reports 39 warnings, down from 434, with zero undefined globals.

---

## 4.7.3 — 2026-04-15

### New Features
- **Extra Attack Procs** — Passive extra-attack abilities like Sword Specialization and Windfury now display in the Procs frame. Respects existing proc filters, icons, and frame settings.

---

## 4.7.0 — 2026-03-18

### New Features
- **Classic Era Support** — Added `xCT+_Vanilla.toc` for Classic Era (Interface 11508). The existing compat layer handles all API differences automatically. TBC-only spells in merge lists are gracefully skipped on Classic Era.

### Code Cleanup
- Merged duplicate `SPELL_HEAL` / `SPELL_PERIODIC_HEAL` formatters into a single function (-31 lines)
- Removed dead combo points code (`UpdateComboPoints`, `UpdateUnitPower`, `ShowRogueComboPoints`, `ShowFeralComboPoints`) — always returned false
- Removed commented-out `COMBAT_LOG_EVENT_UNFILTERED` block from `OnCombatTextEvent`
- Removed no-op `SPELL_ACTIVATION_OVERLAY_GLOW_SHOW` event handler and registration
- Removed unused `UseStandardSpellColors` function
- Removed non-TBC classes from `CLASS_LOOKUP` (Death Knight, Demon Hunter, Monk)
- Removed empty `XCT_PLUS_SUGGEST_MULTISTRIKE_OFF` popup (Retail leftover)
- Unregistered unused events (`UNIT_AURA`, `PLAYER_TARGET_CHANGED`)
- Total: ~108 lines of dead code removed

---

## 4.6.8 — 2026-02-20

### New Features
- **Skill Ups** — Profession and weapon skill increases now display in the General frame (e.g. `+ Herbalism (301)`). Toggle via General frame options → Show Skill Ups. Enabled by default with a customizable color (General → Font Colors → Skill Up).

---

## 4.6.7 — 2026-02-20

### Bug Fixes
- **Fix: Real combat damage not displaying** — xCombatParser-1.0 uses an internal `playerGUID` upvalue to set `args.isPlayer`. In edge cases (e.g. PLAYER_ENTERING_WORLD timing), this value could remain `nil`, causing every `args.isPlayer` check to return false and silently dropping all outgoing/incoming damage/healing events. Fixed in two ways:
  1. Added lazy-init in xCombatParser: if `playerGUID` is nil when a `COMBAT_LOG_EVENT_UNFILTERED` fires, it immediately fetches `UnitGUID("player")`.
  2. Added fallback in `x.CombatLogEvent`: if `args.isPlayer` or `args.atPlayer` are false, cross-check against `x.player.guid` (which is always kept up-to-date by `UpdatePlayer()`).
- **Fix: Lua error on absorb miss events** — `OutgoingMiss` handler was calling `ShowAbsorbs()` which was renamed to `ShowOutAbsorbs()` in v4.6.6. This caused a Lua error ("attempt to call nil value") whenever an absorb miss event occurred. Fixed by updating the call to use `ShowOutAbsorbs()`.

---

## 4.6.4 — 2026-02-09

### New Features
- **Sound Alerts** — Play sounds on combat events like critical hits, killing blows, incoming crits, and low health/mana warnings. All sounds are disabled by default and can be individually toggled. Uses LibSharedMedia for sound selection (your custom sounds will appear in the dropdown). Access via xCT+ Options > Sound Alerts.
- **Minimap Button** — Added a minimap button for quick access. Left-click opens options, right-click toggles frames. Can be hidden via Frames > Show Minimap Button.

---

## 4.6.3 — 2026-02-09

### New Features
- **Incoming Overheal Formatting** — Incoming healing now supports the same rich overheal display as outgoing healing. Enable "Format Overhealing" under Incoming (Healing) > Misc to show overheal amounts separately (e.g. `+5000 (O: 1200)`). Includes options for subtracting overheal from the total, and customizable prefix/postfix text.
- **Sticky Crits** — Critical hits can now stay on screen longer for extra emphasis. Enable under Outgoing (Criticals) > Frame > Sticky Crits, with a configurable extra duration slider (1-10 seconds).
- **Big Noodle Titling Font** — Added "Big Noodle Titling (xCT+)" as a built-in font option.

### Improvements
- Simplified overheal prefix/postfix defaults to plain text instead of raw color codes.
- Improved tooltip descriptions for prefix/postfix fields with examples, defaults, and a link to the Warcraft Wiki escape sequences reference.

### Code Cleanup
- Removed unused class combo points feature (options UI, core functions, and event handlers).
- Removed all TODO/TEMP/FIXME comments and replaced placeholder descriptions with real text.
- Refactored spell filter UI generation into a data-driven `FILTER_SECTIONS` table, eliminating ~200 lines of duplicate code.

### Developer
- Added `.luarc.json` for Lua Language Server — suppresses false positives for WoW API globals in VS Code.

---

## 4.6.2 — 2026-02-07

### Fixes
- Corrected Interface version to 20505 for TBC Anniversary 2.5.5

---

## 4.6.1 — 2026-02-07

### Initial TBC Fork
- Forked from [xCT_Classic](https://github.com/Witnesscm/xCT_Classic) by Witnesscm
- Added TBC API compatibility layer (`compat.lua`)
- Removed Death Knight, Demon Hunter, Monk class references
- Removed non-TBC power types and resources
- Cleaned up retail-only spell IDs and absorb lists
- Updated spell merge list for TBC spells
- Fixed LibSink channel scanning nil error
