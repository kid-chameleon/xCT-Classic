--[[ xCT+ TBC Anniversary Classic
     Author: paradosi-Dreamscythe
     MIT License

     Event sources for clients without an addon-readable combat log
     (WoW: Forever, the mainline 12.x engine on vanilla data).

     Loaded on every client, active only when compat.lua set
     addon.useEventSources. It never replaces modules/combattext.lua: it
     builds the same `args` tables the combat log parser used to build and
     hands them to the handlers in x.CombatEventHandlers, and it swaps the
     few x.combat_events entries whose COMBAT_TEXT_UPDATE payload is a
     secret value on this engine. The full accounting of what each source
     can and cannot supply is doc/forever-support.md (sections 4 and 5).

     Sources, and what they feed:
       UNIT_COMBAT("player")          incoming damage, misses, heals, power
                                      (amounts and crit flags are plain)
       COMBAT_TEXT_UPDATE             in-combat buff/debuff and proc lines
                                      (the name is a secret string: printed,
                                      never filtered, cached or compared)
       UNIT_AURA("player")            out-of-combat buff/debuff lines with
                                      names, icons and the name filters
       LowHealthFrame / CombatText    the low health (35% and 20%) and low
                                      mana (20%) edges, as plain signals
       PARTY_KILL                     killing blows, open world only
       UNIT_SPELLCAST_INTERRUPTED     interrupts, correlated with the
                                      player's own cast in the same frame
       CHAT_MSG_COMBAT_*              reputation and honor, parsed from chat

     Rules that keep this file free of secret-value errors:
       1. A value from UNIT_COMBAT, a chat event, the player's own casts or an
          out-of-combat UNIT_AURA payload is plain and may go anywhere.
       2. A value from C_CombatText.GetCurrentEventInfo or a target's cast is
          secret: string.format it and pass it to x:AddMessage, nothing else.
       3. Anything keyed on a GUID or a name is guarded with issecretvalue.
       4. UNIT_AURA payloads are read only while ShouldAurasBeSecret() is
          false; the instance-id map is rebuilt whenever that changes.
]]

local _, addon = ...
if not addon.useEventSources then return end

local x = addon.engine
local issecretvalue, issecrettable = addon.issecretvalue, addon.issecrettable

local sformat, tostring, tonumber, type, ipairs, wipe, setmetatable, GetTime =
  string.format, tostring, tonumber, type, ipairs, wipe, setmetatable, GetTime

local format_gain = "+%s"
local format_fade = "-%s"

-- Settings accessors. Same profile keys as the "Fast Boolean Lookups" block in
-- modules/combattext.lua; duplicated here rather than exported so that block stays
-- the single place to audit for dead settings.
local function ShowBuffs() return x.db.profile.frames.general.showBuffs end
local function ShowDebuffs() return x.db.profile.frames.general.showDebuffs end
local function ShowInterrupts() return x.db.profile.frames.general.showInterrupts end
local function ShowPartyKill() return x.db.profile.frames.general.showPartyKills end
local function ShowLowResources() return x.db.profile.frames.general.showLowManaHealth end
local function ShowReactives() return x.db.profile.frames.procs.enabledFrame end
local function ShowPetDamage() return x.db.profile.frames.outgoing.enablePetDmg end
local function ShowHonor() return x.db.profile.frames.damage.showHonorGains end
local function ShowFaction() return x.db.profile.frames.general.showRepChanges end

local function Active() return x.db ~= nil and x.eventSourcesEnabled end

local function AurasReadable()
  return not (C_Secrets and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret())
end

-- =====================================================
-- The args table the handlers expect
-- =====================================================
-- The combat log parser gave every event a table with source/destination fields and
-- a few flag-derived methods. Here most of those fields are unknown, so the methods
-- answer from explicit fields with conservative defaults: incoming damage from an
-- NPC controller, incoming healing from a player, nothing from a pet or vehicle.
local argsMT = { __index = {
  GetSourceController = function(a) return a.sourceController or "NPC" end,
  GetDestinationController = function(a) return a.destinationController or "PLAYER" end,
  IsSourceMyPet = function(a) return a.sourceIsMyPet or false end,
  IsDestinationMyPet = function() return false end,
  IsSourceMyVehicle = function() return false end,
  IsDestinationMyVehicle = function() return false end,
} }
local args = setmetatable({}, argsMT)
local function NewArgs()
  wipe(args)
  return args
end

-- =====================================================
-- Own casts (interrupt correlation)
-- =====================================================
-- Only the time of the last SUCCEEDED is kept. Its spell id once attributed an incoming
-- heal to the player's own cast by timing; that guess is gone (see the HEAL branch).
local lastOwnCastTime = 0

local function OnOwnCastSucceeded()
  lastOwnCastTime = GetTime()
end

local function CastThisFrame()
  return lastOwnCastTime == GetTime()
end

-- =====================================================
-- UNIT_COMBAT: incoming damage, misses, heals, power
-- =====================================================
-- Vocabulary from Blizzard's CombatFeedback_OnCombatEvent and the probe (section 4.1):
-- WOUND with amount > 0 is a hit (flags "", CRITICAL, CRUSHING, GLANCING, BLOCK_REDUCED);
-- WOUND with amount 0 is a full absorb/block/resist by flag, else a miss; the named
-- avoidance events carry no amount.
local WOUND_FULL = { ABSORB = "ABSORB", BLOCK = "BLOCK", RESIST = "RESIST" }
local MISS_EVENTS = {
  MISS = true, DODGE = true, PARRY = true, EVADE = true, IMMUNE = true,
  DEFLECT = true, ABSORB = true, REFLECT = true, BLOCK = true, RESIST = true,
}

local function IncomingMiss(missType)
  local a = NewArgs()
  a.missType = missType
  a.suffix = "_MISSED"
  x.CombatEventHandlers.IncomingMiss(a)
end

local function OnUnitCombat(unit, event, flag, amount, school)
  if not Active() then return end
  -- Verified plain on every build so far; the guard costs nothing and turns a future
  -- change into a silent drop instead of an error in the middle of a fight.
  if issecretvalue(event) or issecretvalue(flag) or issecretvalue(amount) or issecretvalue(school) then return end
  amount = tonumber(amount) or 0
  school = tonumber(school) or 1

  if event == "WOUND" then
    if amount > 0 then
      local a = NewArgs()
      a.amount = amount
      a.critical = (flag == "CRITICAL" or flag == "CRUSHING") or nil
      a.spellSchool = school
      a.school = school
      -- No spell attribution here: physical hits are treated as swings for the
      -- auto-attack icon toggle, everything else as a spell.
      a.prefix = school == 1 and "SWING" or "SPELL"
      a.suffix = "_DAMAGE"
      if flag == "BLOCK_REDUCED" then a.reducedBy = "blocked" end
      x.CombatEventHandlers.DamageIncoming(a)
    else
      IncomingMiss(WOUND_FULL[flag] or "MISS")
    end
  elseif event == "HEAL" then
    if amount <= 0 then return end
    local a = NewArgs()
    a.amount = amount
    a.critical = flag == "CRITICAL" or nil
    a.overhealing = 0
    a.absorbed = 0
    a.prefix = "SPELL"
    a.suffix = "_HEAL"
    -- No healer and no spell: the event carries neither. Attributing the heal to the
    -- player's own cast by timing (a SUCCEEDED within 0.3 s, a self-targeted SENT within
    -- 5 s) was dropped on 2026-10-02: it put a Frost Shock icon on a heal that landed just after one and
    -- claimed other healers' heals as the player's own (doc/forever-support.md, 8.1).
    -- The line is the amount alone; "show only my heals" has nothing to test here.
    a.sourceController = "PLAYER"
    x.CombatEventHandlers.HealingIncoming(a)
  elseif event == "ENERGIZE" then
    if amount <= 0 then return end
    -- The event carries no power type; the player's primary power is the only guess.
    local powerType = UnitPowerType(x.player.unit)
    if powerType == nil or issecretvalue(powerType) then return end
    local a = NewArgs()
    a.amount = amount
    a.powerType = powerType
    a.prefix = "SPELL"
    a.suffix = "_ENERGIZE"
    x.CombatEventHandlers.SpellEnergize(a)
  elseif MISS_EVENTS[event] then
    IncomingMiss(event)
  end
end

-- =====================================================
-- COMBAT_TEXT_UPDATE: the secret-payload subtypes
-- =====================================================
-- The subtype is plain, the payload is a secret string on this engine. These
-- replacements print the name as-is with the frame's icon spacer and skip everything
-- that would have to read it (spellCache, name filters, stack counts).
local function SecretAuraLine(spellName, isBuff, isGaining)
  if not Active() or spellName == nil then return end
  -- Out of combat the UNIT_AURA path prints the same line with a name, an icon and
  -- the filters; this one is for the time the aura payload is secret.
  if AurasReadable() then return end
  if isBuff then
    if not ShowBuffs() then return end
  else
    if not ShowDebuffs() then return end
  end
  local message = sformat(isGaining and format_gain or format_fade, spellName)
  local settings = x.db.profile.frames.general
  message = x:GetSpellTextureFormatted(nil, message,
    settings.iconsEnabled and settings.iconsSize or -1,
    settings.spacerIconsEnabled, settings.fontJustify)
  local color
  if isGaining then
    color = isBuff and "buffsGained" or "debuffsGained"
  else
    color = isBuff and "buffsFaded" or "debuffsFaded"
  end
  x:AddMessage("general", message, color)
end

local function SecretProcLine(spellName, colorName)
  if not Active() or spellName == nil or not ShowReactives() then return end
  local settings = x.db.profile.frames.procs
  local message = x:GetSpellTextureFormatted(nil, spellName,
    settings.iconsEnabled and settings.iconsSize or -1,
    settings.spacerIconsEnabled, settings.fontJustify)
  x:AddMessage("procs", message, colorName)
end

x.combat_events.SPELL_AURA_START = function(spellName) SecretAuraLine(spellName, true, true) end
x.combat_events.SPELL_AURA_END = function(spellName) SecretAuraLine(spellName, true, false) end
x.combat_events.SPELL_AURA_START_HARMFUL = function(spellName) SecretAuraLine(spellName, false, true) end
x.combat_events.SPELL_AURA_END_HARMFUL = function(spellName) SecretAuraLine(spellName, false, false) end
x.combat_events.SPELL_ACTIVE = function(spellName) SecretProcLine(spellName, "spellProc") end
x.combat_events.SPELL_CAST = function(spellName) SecretProcLine(spellName, "spellReactive") end
-- Reputation and honor come from the chat messages below, with plain numbers.
x.combat_events.FACTION = addon.noop
x.combat_events.HONOR_GAINED = addon.noop

-- =====================================================
-- UNIT_AURA: out-of-combat buff and debuff lines
-- =====================================================
-- The payload is a plain table while auras are not secret (out of combat), so the
-- original AuraIncoming handler runs unchanged, filters and icons included. A removal
-- only carries the aura instance id, hence the id -> name map, refilled from a scan
-- whenever auras become readable again (an aura gained in combat would otherwise fade
-- nameless).
local auraNames = {}

local function RememberAura(data)
  if data and data.auraInstanceID and not issecrettable(data) then
    auraNames[data.auraInstanceID] = { name = data.name, spellId = data.spellId, isHarmful = data.isHarmful }
  end
end

local function RescanAuras()
  wipe(auraNames)
  if not C_UnitAuras or not AurasReadable() then return end
  for _, filter in ipairs({ "HELPFUL", "HARMFUL" }) do
    for i = 1, 255 do
      local data = C_UnitAuras.GetAuraDataByIndex("player", i, filter)
      if not data then break end
      RememberAura(data)
    end
  end
end

local function AuraLine(name, spellId, isHarmful, suffix)
  if name == nil or issecretvalue(name) then return end
  local a = NewArgs()
  a.spellName = name
  a.spellId = spellId
  a.auraType = isHarmful and "DEBUFF" or "BUFF"
  a.suffix = suffix
  x.CombatEventHandlers.AuraIncoming(a)
end

local function OnUnitAura(unit, info)
  if not Active() or unit ~= "player" then return end
  if info == nil or issecrettable(info) or not AurasReadable() then return end
  if info.isFullUpdate then
    RescanAuras()
    return
  end
  if info.addedAuras then
    for _, data in ipairs(info.addedAuras) do
      RememberAura(data)
      AuraLine(data.name, data.spellId, data.isHarmful, "_AURA_APPLIED")
    end
  end
  if info.removedAuraInstanceIDs then
    for _, id in ipairs(info.removedAuraInstanceIDs) do
      local known = auraNames[id]
      if known then
        auraNames[id] = nil
        AuraLine(known.name, known.spellId, known.isHarmful, "_AURA_REMOVED")
      end
    end
  end
end

-- =====================================================
-- Low health and low mana
-- =====================================================
-- Health and power are secret at all times, so the edges come from Blizzard: the
-- LowHealthFrame shows at 35% (its OnShow is a plain hook), and Blizzard's combat text
-- prints the plain HEALTH_LOW / MANA_LOW strings at 20% when enableFloatingCombatText
-- is on (modules/blizzard.lua forwards them). Each signal is an edge already, so no
-- state is kept beyond a one-second dedup between the two health sources. The
-- profile's sound thresholds cannot apply; the sounds follow the same edges.
local lastHealthEdge, lastManaEdge = 0, 0

local function LowHealthEdge()
  if not Active() then return end
  local now = GetTime()
  if now - lastHealthEdge < 1 then return end
  lastHealthEdge = now
  if ShowLowResources() then
    x:AddMessage("general", HEALTH_LOW, "lowResourcesHealth")
  end
  x.PlaySoundAlert("lowHealth")
end

local function LowManaEdge()
  if not Active() then return end
  local now = GetTime()
  if now - lastManaEdge < 1 then return end
  lastManaEdge = now
  if ShowLowResources() then
    x:AddMessage("general", MANA_LOW, "lowResourcesMana")
  end
  x.PlaySoundAlert("lowMana")
end

if LowHealthFrame and LowHealthFrame.HookScript then
  LowHealthFrame:HookScript("OnShow", LowHealthEdge)
end

function x.OnBlizzardCombatTextMessage(message)
  if not Active() or message == nil or issecretvalue(message) then return end
  if message == HEALTH_LOW then
    LowHealthEdge()
  elseif message == MANA_LOW then
    LowManaEdge()
  end
end

-- =====================================================
-- PARTY_KILL: killing blows (open world only)
-- =====================================================
-- Both GUIDs are secret on restricted maps (dungeons, raids), where the line is
-- dropped. The victim's name comes from the current target or from a small GUID -> name
-- cache filled from nameplates and targets, all plain in the open world.
local guidNames, guidNameCount = {}, 0

local function RememberUnit(unit)
  local guid = UnitGUID(unit)
  if guid == nil or issecretvalue(guid) or guidNames[guid] then return end
  local name = UnitName(unit)
  if name == nil or issecretvalue(name) then return end
  if guidNameCount >= 200 then
    wipe(guidNames)
    guidNameCount = 0
  end
  guidNames[guid] = name
  guidNameCount = guidNameCount + 1
end

local function OnPartyKill(attacker, victim)
  if not Active() or not ShowPartyKill() then return end
  if attacker == nil or victim == nil or issecretvalue(attacker) or issecretvalue(victim) then return end
  local mine = attacker == x.player.guid
  if not mine and ShowPetDamage() then
    local pet = UnitGUID("pet")
    mine = pet ~= nil and not issecretvalue(pet) and pet == attacker
  end
  if not mine then return end

  local name = guidNames[victim]
  if not name then
    local targetGUID = UnitGUID("target")
    if targetGUID ~= nil and not issecretvalue(targetGUID) and targetGUID == victim then
      name = UnitName("target")
      if issecretvalue(name) then name = nil end
    end
  end

  local a = NewArgs()
  a.event = "PARTY_KILL"
  a.destGUID = victim
  a.destName = name or UNKNOWN
  x.CombatEventHandlers.KilledUnit(a)
end

-- =====================================================
-- Interrupts
-- =====================================================
-- The target's UNIT_SPELLCAST_INTERRUPTED arrives with a secret spell id and a secret
-- interrupter, in the same frame as the player's own interrupt cast's SUCCEEDED
-- (section 4.4). Same frame is the whole test; the spell id still resolves to a
-- (secret) name and icon for the line.
local function OnTargetInterrupted(unit, castGUID, spellID)
  if not Active() or not ShowInterrupts() or not CastThisFrame() then return end
  local a = NewArgs()
  a.event = "SPELL_INTERRUPT"
  a.extraSpellId = spellID
  a.extraSpellName = spellID ~= nil and C_Spell.GetSpellName(spellID) or nil
  if a.extraSpellName == nil then a.extraSpellName = UNKNOWN end
  x.CombatEventHandlers.InterruptedUnit(a)
end

-- =====================================================
-- Reputation and honor from chat
-- =====================================================
-- COMBAT_TEXT_UPDATE FACTION / HONOR_GAINED carry secret amounts; the chat messages
-- carry the same information in plain text. Patterns are built from Blizzard's own
-- format strings so they follow the client's locale; the numeric capture is the
-- amount whichever position the locale puts it in.
local function FormatToPattern(fmt)
  if type(fmt) ~= "string" or fmt == "" then return nil end
  -- Escape the pattern magic characters except '%', so the specifiers survive as
  -- "%s", "%d", "%1%$s" (positional, the '$' got escaped) and "%%.1f" (the '.' did).
  local pat = fmt:gsub("([%^%$%(%)%.%[%]%*%+%-%?])", "%%%1")
  pat = pat:gsub("%%%d?%%?%$?s", "(.+)")
  pat = pat:gsub("%%%d?%%?%$?d", "(%%d+)")
  pat = pat:gsub("%%%%%.%df", "([%%d%%.]+)")
  return "^" .. pat .. "$"
end

local factionPatterns, honorPatterns

local function AddPattern(list, fmt, sign)
  local pat = FormatToPattern(fmt)
  if pat then list[#list + 1] = { pat = pat, sign = sign } end
end

local function BuildChatPatterns()
  factionPatterns, honorPatterns = {}, {}
  AddPattern(factionPatterns, FACTION_STANDING_INCREASED, 1)
  AddPattern(factionPatterns, FACTION_STANDING_INCREASED_ACH_BONUS, 1)
  AddPattern(factionPatterns, FACTION_STANDING_DECREASED, -1)
  AddPattern(honorPatterns, COMBATLOG_HONORGAIN, 1)
  AddPattern(honorPatterns, COMBATLOG_HONORGAIN_NO_RANK, 1)
  AddPattern(honorPatterns, COMBATLOG_HONORAWARD, 1)
end

-- Returns amount (number) and the text capture, whichever order the locale used
local function MatchAmount(list, msg)
  for _, entry in ipairs(list) do
    local c1, c2, c3 = msg:match(entry.pat)
    if c1 then
      local amount, text
      for _, capture in ipairs({ c1, c2, c3 }) do
        local n = tonumber((tostring(capture):gsub(",", "")))
        if n and not amount then
          amount = n
        elseif not n and not text then
          text = capture
        end
      end
      if amount then return entry.sign * amount, text end
    end
  end
end

local function OnFactionChange(msg)
  if not Active() or not ShowFaction() or msg == nil or issecretvalue(msg) then return end
  if not factionPatterns then BuildChatPatterns() end
  local amount, faction = MatchAmount(factionPatterns, msg)
  if amount and faction then
    x.AddFactionMessage(faction, amount)
  end
end

local function OnHonorGain(msg)
  if not Active() or not ShowHonor() or msg == nil or issecretvalue(msg) then return end
  if not honorPatterns then BuildChatPatterns() end
  local amount = MatchAmount(honorPatterns, msg)
  if not amount then
    -- Unknown wording: the last number in the line is the honor amount in every
    -- Blizzard variant so far.
    amount = tonumber(msg:match("(%d+)%D*$"))
  end
  if amount then x.AddHonorMessage(amount) end
end

-- =====================================================
-- Wiring
-- =====================================================
x.events.UNIT_COMBAT = OnUnitCombat
x.events.UNIT_AURA = OnUnitAura
x.events.UNIT_SPELLCAST_SUCCEEDED = OnOwnCastSucceeded
x.events.UNIT_SPELLCAST_INTERRUPTED = OnTargetInterrupted
x.events.PARTY_KILL = OnPartyKill
x.events.NAME_PLATE_UNIT_ADDED = function(unit) RememberUnit(unit) end
x.events.PLAYER_TARGET_CHANGED = function() RememberUnit("target") end
x.events.CHAT_MSG_COMBAT_FACTION_CHANGE = OnFactionChange
x.events.CHAT_MSG_COMBAT_HONOR_GAIN = OnHonorGain
x.events.ADDON_RESTRICTION_STATE_CHANGED = function() RescanAuras() end

-- Keep the handlers combattext.lua already installed, and add the rescans they imply
do
  local onRegenEnabled = x.events.PLAYER_REGEN_ENABLED
  x.events.PLAYER_REGEN_ENABLED = function(...)
    onRegenEnabled(...)
    RescanAuras()
  end

  local onEnteringWorld = x.events.PLAYER_ENTERING_WORLD
  x.events.PLAYER_ENTERING_WORLD = function(...)
    onEnteringWorld(...)
    wipe(guidNames)
    guidNameCount = 0
    RescanAuras()
  end
end

-- Called by x:UpdateCombatTextEvents on the shared event frame in place of the
-- combat log registration. RegisterUnitEvent matters: UNIT_COMBAT is delivered once
-- per unit token that resolves to the unit (player, targettarget, nameplates), and
-- only the player's own copy is wanted.
function x.RegisterEventSources(f)
  f:RegisterUnitEvent("UNIT_COMBAT", "player")
  f:RegisterUnitEvent("UNIT_AURA", "player")
  f:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
  f:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "target")
  f:RegisterEvent("PARTY_KILL")
  f:RegisterEvent("NAME_PLATE_UNIT_ADDED")
  f:RegisterEvent("PLAYER_TARGET_CHANGED")
  f:RegisterEvent("CHAT_MSG_COMBAT_FACTION_CHANGE")
  f:RegisterEvent("CHAT_MSG_COMBAT_HONOR_GAIN")
  f:RegisterEvent("ADDON_RESTRICTION_STATE_CHANGED")
  RescanAuras()
end
