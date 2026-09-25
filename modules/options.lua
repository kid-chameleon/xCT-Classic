--[[ xCT+ TBC Anniversary Classic
     Author: paradosi-Dreamscythe
     MIT License

     The AceConfig options tree for the whole addon (~7,000 lines, mostly
     declarative). Registered by core.lua.

     Setter/getter naming encodes WHERE in the profile a value lives, by how
     far up the options path it looks:
       get0/set0      x.db.profile[parent][key]
       get0_1/set0_1  x.db.profile[grandparent][key]
       get2/set2      x.db.profile.frames[grandparent][key]
     The *_update variants also call x:UpdateFrames() so the change is visible
     immediately. Pick the one matching your option's nesting depth or it will
     silently read and write the wrong table.

     A nil `set` is legal in AceConfig and is silently ignored at runtime --
     no error, the value simply never gets written. A typo'd setter name
     therefore produces a control that looks fine and does nothing.

     x.cvar_update also blanks Blizzard's COMBAT_THREAT_* strings to suppress
     the default threat text, restoring the values captured at load. That is
     deliberate, and the restore only fires if this addon was the one that
     blanked them.
]]

local _, addon = ...
local L = addon.L
local LSM = LibStub("LibSharedMedia-3.0")
local x, noop = addon.engine, addon.noop
local blankTable, unpack = {}, unpack
local string_gsub, sformat, pairs = string.gsub, string.format, pairs


-- Store Localized Strings
-- To remove: "Changed Target!"
local XCT_CT_DEC_0, XCT_CT_DEC_1, XCT_CT_DEC_2 = COMBAT_THREAT_DECREASE_0, COMBAT_THREAT_DECREASE_1, COMBAT_THREAT_DECREASE_2
local XCT_CT_INC_1, XCT_CT_INC_3 = COMBAT_THREAT_INCREASE_1, COMBAT_THREAT_INCREASE_3

-- Creating an Config
addon.options = {
  -- Add a place for the user to grab
  name = "                                                      " .. "Version: "..(C_AddOns.GetAddOnMetadata("xCT+", "Version") or "Unknown") .. "                                                      ",
  handler = x,
  type = 'group',
  args = {
    xCT_Title = {
      order = 0,
      type = 'description',
      fontSize = 'large',
      name = L["|cff11a34axCT+|r Configuration Tool\n"],
      width = 'double',
    },

    spacer0 = {
      order = 1,
      type = 'description',
      name = L["|cff11a34aHelpful Tips:|r\n\n"],
      width = 'half',
    },

    helpfulTip = {
      order = 2,
      type = 'description',
      fontSize = 'medium',
      name = L["On the left list, under the |cff848482Startup Message|r checkbox, you can click on the |cff11a34a+ Buttons|r (plus) to show more options."],
      width = 'double',
    },

    space1 = {
      order = 10,
      type = 'description',
      name = "\n",
      width = 'full',
    },

    showStartupText = {
      order = 11,
      type = 'toggle',
      name = L["Startup Message"],
      get = function(info) return x.db.profile.showStartupText end,
      set = function(info, value) x.db.profile.showStartupText = value end,
    },
    hideConfig = {
      order = 12,
      type = 'toggle',
      name = L["Hide Config in Combat"],
      desc = L["This option helps prevent UI taints by closing the config when you enter combat.\n\n|cffFF8000Highly Recommended Enabled|r"],
      get = function(info) return x.db.profile.hideConfig end,
      set = function(info, value) x.db.profile.hideConfig = value; if not value then StaticPopup_Show("XCT_PLUS_HIDE_IN_COMBAT") end end,
    },
    showMinimapButton = {
      order = 13,
      type = 'toggle',
      name = L["Minimap Button"],
      desc = L["Show or hide the xCT+ minimap button."],
      get = function() return not x.db.profile.minimap.hide end,
      set = function(_, value)
        x.db.profile.minimap.hide = not value
        x:ToggleMinimapButton()
      end,
    },
    space2 = {
      order = 20,
      type = 'description',
      name = " ",
      width = 'half',
    },
    space3 = {
      order = 30,
      type = 'description',
      name = " ",
      width = 'half',
    },
    space4 = {
      order = 30,
      type = 'description',
      name = " ",
      width = 'half',
    },
    ToggleTestMode = {
      order = 31,
      type = 'execute',
      name = L["Test"],
      func = x.ToggleTestMode,
      desc = L["Allows you to preview xCT+ inorder to tweak settings outside of combat.\n\nYou can also type: '|cffFF0000/xct test|r'"],
      width = 'half',
    },
    ToggleFrames = {
      order = 32,
      type = 'execute',
      name = L["Move"],
      desc = L["Allows you to adjust the position of all the xCT+ frames on your screen.\n\nYou can also type: '|cffFF0000/xct lock|r'"],
      func = x.ToggleConfigMode,
      width = 'half',
    },

    hiddenObjectShhhhhh = {
      order = 9001,
      type = 'description',
      name = function(info) x:OnAddonConfigRefreshed() return "" end,
    },
  },
}

-- A fast C-Var Update routine
local function isCVarsDisabled( ) return x.db.profile.bypassCVars end

-- The Blizzard floating combat text cvars written by x.cvar_update, keyed as in the
-- profile. The mainline engine (WoW: Forever) renamed the survivors with a "_v2"
-- suffix and dropped the rest (doc/forever-support.md, 3.6); each write goes to
-- whichever name the client has, or nowhere.
local BOOLEAN_CVARS = {
  "enableFloatingCombatText",
  "floatingCombatTextAllSpellMechanics",
  "floatingCombatTextAuras",
  "floatingCombatTextAuraFade",
  "floatingCombatTextCombatDamage",
  "floatingCombatTextCombatDamageAllAutos",
  "floatingCombatTextCombatHealing",
  "floatingCombatTextCombatLogPeriodicSpells",
  "floatingCombatTextCombatState",
  "floatingCombatTextComboPoints",
  "floatingCombatTextDamageReduction",
  "floatingCombatTextDodgeParryMiss",
  "floatingCombatTextEnergyGains",
  "floatingCombatTextFloatMode",
  "floatingCombatTextFriendlyHealers",
  "floatingCombatTextHonorGains",
  "floatingCombatTextLowManaHealth",
  "floatingCombatTextPeriodicEnergyGains",
  "floatingCombatTextPetMeleeDamage",
  "floatingCombatTextPetSpellDamage",
  "floatingCombatTextReactives",
  "floatingCombatTextRepChanges",
  "floatingCombatTextSpellMechanics",
  "floatingCombatTextSpellMechanicsOther",
}

local cvarNameCache = {}
local function ResolveCVarName(name)
  local resolved = cvarNameCache[name]
  if resolved ~= nil then return resolved or nil end
  resolved = false
  if C_CVar and C_CVar.GetCVarInfo then
    -- pcall: whether an unknown name returns nothing or raises differs by client
    local ok, info = pcall(C_CVar.GetCVarInfo, name)
    if ok and info ~= nil then
      resolved = name
    else
      ok, info = pcall(C_CVar.GetCVarInfo, name .. "_v2")
      if ok and info ~= nil then resolved = name .. "_v2" end
    end
  else
    resolved = name -- no C_CVar: every name in the list exists on that client
  end
  cvarNameCache[name] = resolved
  return resolved or nil
end

local function SetCVarIfExists(name, value)
  local resolved = ResolveCVarName(name)
  if resolved then SetCVar(resolved, value) end
end

-- =====================================================
-- Event-source client (WoW: Forever) gating
-- =====================================================
-- Options that read data this client does not provide are disabled rather than hidden,
-- so the panel keeps its shape, and a ForeverNote at the top of each affected section
-- says why. Outgoing lines are not produced there by decision (doc/forever-support.md,
-- 8.1: the attribution that other events allow is a guess, and an inexact frame is worse
-- than none), so every outgoing option hangs on NoOutgoing; addon.outgoingSources is the
-- one switch that would re-enable them should that ever change. cvarMissing greys a
-- Blizzard FCT toggle whose cvar the client does not have under either name.
local function OnEventSources() return addon.useEventSources end
local function NotEventSources() return not addon.useEventSources end
local function NoOutgoing() return addon.useEventSources and not addon.outgoingSources end
local function cvarMissing(info) return isCVarsDisabled() or ResolveCVarName(info[#info]) == nil end
local function ForeverNote(order, text)
  return {
    type = "description",
    order = order,
    fontSize = "small",
    hidden = NotEventSources,
    name = L["|cffFF8000On this client:|r "] .. text .. "\n",
  }
end


x.cvar_update = function( force )
  -- Floating Combat Text: Threat Changes
  if not x.db.profile.blizzardFCT.CombatThreatChanges then
    COMBAT_THREAT_DECREASE_0, COMBAT_THREAT_DECREASE_1, COMBAT_THREAT_DECREASE_2 = "", "", ""
    COMBAT_THREAT_INCREASE_1, COMBAT_THREAT_INCREASE_3 = "", ""
  elseif COMBAT_THREAT_DECREASE_0 == "" then
    -- only overwrite Blizzard constants if they were previously changed
    COMBAT_THREAT_DECREASE_0, COMBAT_THREAT_DECREASE_1, COMBAT_THREAT_DECREASE_2 = XCT_CT_DEC_0, XCT_CT_DEC_1, XCT_CT_DEC_2
    COMBAT_THREAT_INCREASE_1, COMBAT_THREAT_INCREASE_3 = XCT_CT_INC_1, XCT_CT_INC_3
  end

  if  isCVarsDisabled( ) then
    if force then
      StaticPopup_Show("XCT_PLUS_FORCE_CVAR_UPDATE")
    else
      return
    end
  end

  for _, name in ipairs(BOOLEAN_CVARS) do
    SetCVarIfExists(name, x.db.profile.blizzardFCT[name] and 1 or 0)
  end
  if addon.useEventSources then
    -- Blizzard's "Mana Low" message is the only low-mana signal on this client
    -- (modules/sources.lua reads it through the CombatText hook), and Blizzard only
    -- produces it while this cvar is on: keep it on whatever the profile's toggle says.
    SetCVarIfExists("floatingCombatTextLowManaHealth", 1)
  end
  SetCVarIfExists("floatingCombatTextCombatDamageDirectionalOffset", x.db.profile.blizzardFCT.floatingCombatTextCombatDamageDirectionalOffset)
  SetCVarIfExists("floatingCombatTextCombatDamageDirectionalScale", x.db.profile.blizzardFCT.floatingCombatTextCombatDamageDirectionalScale)

  -- Mainline engine: Blizzard's self text can stay enabled (its events feed the low
  -- mana line, modules/sources.lua) while its own display is hidden.
  if CombatText and CombatText.SetAlpha then
    CombatText:SetAlpha(x.db.profile.blizzardFCT.hideBlizzardText and 0 or 1)
  end
end

-- Generic Get/Set methods
local function get0(info) return x.db.profile[info[#info-1]][info[#info]] end
local function set0(info, value) x.db.profile[info[#info-1]][info[#info]] = value; x.cvar_update() end
local function set0_update(info, value) x.db.profile[info[#info-1]][info[#info]] = value; x:UpdateFrames(); x.cvar_update() end
local function get0_1(info) return x.db.profile[info[#info-2]][info[#info]] end
local function set0_1(info, value) x.db.profile[info[#info-2]][info[#info]] = value; x.cvar_update() end
local function getColor0_1(info) return unpack(x.db.profile[info[#info-2]][info[#info]] or blankTable) end
local function setColor0_1(info, r, g, b) x.db.profile[info[#info-2]][info[#info]] = {r,g,b} end
local function getTextIn0(info) return string_gsub(x.db.profile[info[#info-1]][info[#info]], "|", "||") end
local function setTextIn0(info, value) x.db.profile[info[#info-1]][info[#info]] = string_gsub(value, "||", "|"); x.cvar_update() end
local function get2(info) return x.db.profile.frames[info[#info-2]][info[#info]] end
local function set2(info, value) x.db.profile.frames[info[#info-2]][info[#info]] = value; x.cvar_update() end
local function set2_update(info, value) set2(info, value); x:UpdateFrames(info[#info-2]); x.cvar_update() end
local function getColor2(info) return unpack(x.db.profile.frames[info[#info-2]][info[#info]] or blankTable) end
local function setColor2(info, r, g, b) x.db.profile.frames[info[#info-2]][info[#info]] = {r,g,b} end
local function setColor2_alpha(info, r, g, b, a) x.db.profile.frames[info[#info-2]][info[#info]] = {r,g,b,a} end
local function getTextIn2(info) return string_gsub(x.db.profile.frames[info[#info-2]][info[#info]], "|", "||") end
local function setTextIn2(info, value) x.db.profile.frames[info[#info-2]][info[#info]] = string_gsub(value, "||", "|") end
local function getNumber2(info) return tostring(x.db.profile[info[#info-2]][info[#info]]) end
local function setNumber2(info, value) if tonumber(value) then x.db.profile[info[#info-2]][info[#info]] = tonumber(value) end end


-- Man this is soooo getting out of hand D:
local function getNameFormat(info) return x.db.profile.frames[info[#info-3]].names[info[#info-1]][info[#info]] end
local function setNameFormat(info, value) x.db.profile.frames[info[#info-3]].names[info[#info-1]][info[#info]] = value end
local function getNameFormatColor(info) return unpack(x.db.profile.frames[info[#info-3]].names[info[#info-1]][info[#info]] or blankTable) end
local function setNameFormatColor(info, r, g, b) x.db.profile.frames[info[#info-3]].names[info[#info-1]][info[#info]] = {r,g,b} end
local function getNameFormatText(info) return string_gsub(x.db.profile.frames[info[#info-2]].names[info[#info]], "|", "||") end
local function setNameFormatText(info, value) x.db.profile.frames[info[#info-2]].names[info[#info]] = string_gsub(value, "||", "|") end


local function isFrameItemDisabled(info) return not x.db.profile.frames[info[#info-2]].enabledFrame end
local function isFrameNotScrollable(info) return isFrameItemDisabled(info) or not x.db.profile.frames[info[#info-2]].enableScrollable end
local function isFrameUseCustomFade(info) return not x.db.profile.frames[info[#info-2]].enableCustomFade or isFrameItemDisabled(info) end
local function isFrameFadingDisabled(info) return isFrameUseCustomFade(info) or not x.db.profile.frames[info[#info-2]].enableFade end
local function isFrameIconDisabled(info) return isFrameItemDisabled(info) or not x.db.profile.frames[info[#info-2]].iconsEnabled end
local function isFrameIconSpacerDisabled(info) return x.db.profile.frames[info[#info-2]].iconsEnabled end
local function isFrameFontShadowDisabled(info) return isFrameItemDisabled(info) or not x.db.profile.frames[info[#info-2]].enableFontShadow end
local function isFrameCustomColorDisabled(info) return not x.db.profile.frames[info[#info-2]].customColor end
local function isFrameItemEnabled(info) return x.db.profile.frames[info[#info-2]].enabledFrame end


local function setSpecialCriticalOptions(info, value)
  x.db.profile[info[#info-2]].mergeCriticalsWithOutgoing = false
  x.db.profile[info[#info-2]].mergeCriticalsByThemselves = false
  x.db.profile[info[#info-2]].mergeDontMergeCriticals = false
  x.db.profile[info[#info-2]].mergeHideMergedCriticals = false

  x.db.profile[info[#info-2]][info[#info]] = true
end

local function setFormating(info, value)
  x.db.profile.spells.formatAbbreviate = false
  x.db.profile.spells.formatGroups = false

  x.db.profile.spells[info[#info]] = true
end

local function getDBSpells(info)
  return x.db.profile.spells[info[#info]]
end

-- Apply to All variables
local miscFont, miscFontOutline, miscEnableCustomFade;

-- Spell Filter Methods
local checkAdd = {
  listBuffs = false,
  listDebuffs = false,
  listSpells = false,
  listProcs = false,
}

local function getCheckAdd(info) return checkAdd[info[#info-1]] end
local function setCheckAdd(info, value) checkAdd[info[#info-1]] = value end

local function trim(s)
  return ( s:gsub("^%s*(.-)%s*$", "%1") )
end

-- For each 'comma' separated value in 'input' (string) do 'func(value, ...)'
local function foreach(input, comma, func, ...)
  local pattern = ("[^%s]+"):format(comma)
  local e, s = 0
  while e do
    s, e = input:find(pattern, e + 1)
    if s and e then
      func(trim(input:sub(s, e)), ...)
    end
  end
end

local function setSpell(info, value)
  if not checkAdd[info[#info-1]] then
    -- Add Spell
    foreach(value, ';', x.AddFilteredSpell, info[#info-1])
  else
    -- Remove Spell
    foreach(value, ';', x.RemoveFilteredSpell, info[#info-1])
  end
end

local function IsTrackSpellsDisabled() return not x.db.profile.spellFilter.trackSpells end

-- Lists that will be used to show tracked spells
local buffHistory, debuffHistory, spellHistory, procHistory, itemHistory, damageHistory, healingHistory = { }, { }, { }, { }, { }, { }, { }


-- GetSpellTextureFormatted( spellID, message, multistrike, iconSize, justify, strColor, mergeOverride, forceOff )

local function GetBuffHistory()
  for i in pairs(buffHistory) do
    buffHistory[i] = nil
  end

  for i in pairs(x.spellCache.buffs) do
    buffHistory[i] = x:GetSpellTextureFormatted("", "", 0, 16, nil, nil, nil, true).." "..i
  end

  return buffHistory
end

local function GetDebuffHistory()
  for i in pairs(debuffHistory) do
    debuffHistory[i] = nil
  end

  for i in pairs(x.spellCache.debuffs) do
    debuffHistory[i] = x:GetSpellTextureFormatted("", "", 0, 16, nil, nil, nil, true).." "..i
  end

  return debuffHistory
end

local function GetSpellHistory()
  for i in pairs(spellHistory) do
    spellHistory[i] = nil
  end

  for i in pairs(x.spellCache.spells) do
    local name, icon = C_Spell.GetSpellName(i), C_Spell.GetSpellTexture(i)
    spellHistory[tostring(i)] = sformat("|T%s:%d:%d:0:0:64:64:5:59:5:59|t %s (|cff11a34a%d)", icon or 0, 16, 16, name or UNKNOWN, i)
  end

  return spellHistory
end

local function GetProcHistory()
  for i in pairs(procHistory) do
    procHistory[i] = nil
  end

  for i in pairs(x.spellCache.procs) do
    procHistory[i] = x:GetSpellTextureFormatted(i, "", 0, 16, nil, nil, nil, true).." "..i
  end

  return procHistory
end

local function GetItemHistory()
  for i in pairs(itemHistory) do
    itemHistory[i] = nil
  end

  for i in pairs(x.spellCache.items) do
	local name, _, _, _, _, _, _, _, _, texture = C_Item.GetItemInfo( i )
    itemHistory[i] = sformat("|T%s:%d:%d:0:0:64:64:5:59:5:59|t %s", texture, 16, 16, name)
  end

  return itemHistory
end

local function GetDamageIncomingHistory()
  for i in pairs(damageHistory) do damageHistory[i] = nil end

  for i in pairs(x.spellCache.damage) do
    local name, icon = C_Spell.GetSpellName(i), C_Spell.GetSpellTexture(i)
    damageHistory[tostring(i)] = sformat("|T%s:%d:%d:0:0:64:64:5:59:5:59|t %s (|cff11a34a%d)", icon or 0, 16, 16, name or UNKNOWN, i)
  end

  return damageHistory
end

local function GetHealingIncomingHistory()
  for i in pairs(healingHistory) do healingHistory[i] = nil end

  for i in pairs(x.spellCache.healing) do
    local name, icon = C_Spell.GetSpellName(i), C_Spell.GetSpellTexture(i)
    healingHistory[tostring(i)] = sformat("|T%s:%d:%d:0:0:64:64:5:59:5:59|t %s (|cff11a34a%d)", icon or 0, 16, 16, name or UNKNOWN, i)
  end

  return healingHistory
end


addon.options.args["spells"] = {
  name = L["Spam Merger"],
  type = 'group',
  childGroups = 'tab',
  order = 2,
  args = {

    mergeOptions = {
      name = L["Merge Options"],
      type = 'group',
      order = 11,
      args = {
        foreverNote = ForeverNote(0.5, L["the merger applies to incoming healing only: outgoing lines are not produced on this client (the combat log is closed to addons and the guesses that remain are not exact), so the swing, ranged, pet and critical merge options do nothing."]),

        enableMerger = {
          order = 1,
          type = 'toggle',
          name = L["Enable Merger"],
          get = get0_1,
          set = set0_1,
        },
        enableMergerDebug = {
          order = 2,
          type = 'toggle',
          width = "double",
          name = L["Show Spell IDs"],
          get = get0_1,
          set = set0_1,
        },

        listSpacer1 = {
          type = "description",
          order = 10,
          name = L["\n|cff11a34aMerge Incoming Healing|r:"],
          fontSize = 'large',
        },

        mergeHealing = {
          order = 11,
          type = 'toggle',
          name = L["Merge Healing by Name"],
          desc = L["Merges incoming healing by the name of the person that healed you."],
          get = get0_1,
          set = set0_1,
          width = 'double',
        },

        listSpacer2 = {
          type = "description",
          order = 20,
          name = L["\n|cff11a34aMerge Multiple Dispells|r:"],
          fontSize = 'large',
        },

        mergeDispells = {
          disabled = OnEventSources,
          order = 21,
          type = 'toggle',
          name = L["Merge Dispells by Spell Name"],
          desc = L["Merges multiple dispells that you perform together, if the aura name is the same."],
          get = get0_1,
          set = set0_1,
          width = 'double',
        },

        listSpacer3 = {
          type = "description",
          order = 30,
          name = L["\n|cff11a34aMerge Auto-Attacks|r:"],
          fontSize = 'large',
        },

        mergeSwings = {
          disabled = NoOutgoing,
          order = 31,
          type = 'toggle',
          name = L["Merge Melee Swings"],
          desc = L["|cffFF0000ID|r 6603 |cff11a34a(Player Melee)|r\n|cffFF0000ID|r 0 |cff11a34a(Pet Melee)|r"],
          get = get0_1,
          set = set0_1,
        },

        mergeRanged = {
          disabled = NoOutgoing,
          order = 32,
          type = 'toggle',
          name = L["Merge Ranged Attacks"],
          desc = L["|cffFF0000ID|r 75"],
          get = get0_1,
          set = set0_1,
        },

        listSpacer4 = {
          type = "description",
          order = 34,
          name = L["\n|cff11a34aMerge Pet Attacks|r:"],
          fontSize = 'large',
        },

        mergePet = {
          disabled = NoOutgoing,
          order = 35,
          type = 'toggle',
          name = L["Merge Pet Abilities"],
          desc = L["Merges all pet abilities together and shows your pet's icon as the source."],
          get = get0_1,
          set = set0_1,
        },

        mergePetColor = {
          disabled = NoOutgoing,
          order = 36,
          type = 'color',
          name = L["Pet Color"],
          get = getColor0_1,
          set = setColor0_1,
        },

        listSpacer5 = {
          type = "description",
          order = 40,
          name = L["\n|cff11a34aMerge Critical Hits|r (Choose one):"],
          fontSize = 'large',
        },

        mergeDontMergeCriticals = {
          disabled = NoOutgoing,
          order = 41,
          type = 'toggle',
          name = L["Don't Merge Critical Hits Together"],
          desc = L["Crits will not get merged in the critical frame, but they will be included in the outgoing total. |cff848482(Default)|r"],
          get = get0_1,
          set = setSpecialCriticalOptions,
          width = 'full',
        },

        mergeCriticalsWithOutgoing = {
          disabled = NoOutgoing,
          order = 42,
          type = 'toggle',
          name = L["Merge Critical Hits with Outgoing"],
          desc = L["Crits will be merged, but the total merged amount in the outgoing frame includes crits."],
          get = get0_1,
          set = setSpecialCriticalOptions,
          width = 'full',
        },

        mergeCriticalsByThemselves = {
          disabled = NoOutgoing,
          order = 43,
          type = 'toggle',
          name = L["Merge Critical Hits by Themselves"],
          desc = L["Crits will be merged and the total merged amount in the outgoing frame |cffFF0000DOES NOT|r include crits."],
          get = get0_1,
          set = setSpecialCriticalOptions,
          width = 'full',
        },

        mergeHideMergedCriticals = {
          disabled = NoOutgoing,
          order = 44,
          type = 'toggle',
          name = L["Hide Merged Criticals"],
          desc = L["Criticals that have been merged with the Outgoing frame will not be shown in the Critical frame"],
          get = get0_1,
          set = setSpecialCriticalOptions,
          width = 'full',
        },

      },
    },

    classList = {
      disabled = NoOutgoing,
      name = L["Class Spells"], --"List of Mergeable Spells |cff11a34a(Class Specific)|r",
      type = 'group',
      order = 21,
      childGroups = 'select',
      args = {
        foreverNote = ForeverNote(0.5, L["merge intervals apply to outgoing spells, which are not produced on this client."]),
        title = {
          type = 'description',
          order = 0,
          name = L["List of Mergeable Spells |cff11a34a(Class Specific)|r"],
          fontSize = "large",
          width = "double",
        },

        mergeListDesc = {
          type = "description",
          order = 1,
          fontSize = "small",
          name = L["Uncheck a spell if you do not want it merged. Contact me to add new spells. See |cff11a34aCredits|r for contact info.\n\n"],
        },

        -- Death Knight, Demon Hunter, Monk removed - not in TBC
        ["DRUID"]       = { type = 'group', order = 1,  name = L["|cffFF7D0ADruid|r"] },
        ["HUNTER"]      = { type = 'group', order = 3,  name = L["|cffABD473Hunter|r"] },
        ["MAGE"]        = { type = 'group', order = 4,  name = L["|cff69CCF0Mage|r"] },
        ["PALADIN"]     = { type = 'group', order = 5,  name = L["|cffF58CBAPaladin|r"] },
        ["PRIEST"]      = { type = 'group', order = 6,  name = L["|cffFFFFFFPriest|r"] },
        ["ROGUE"]       = { type = 'group', order = 7,  name = L["|cffFFF569Rogue|r"] },
        ["SHAMAN"]      = { type = 'group', order = 8, name = L["|cff0070DEShaman|r"] },
        ["WARLOCK"]     = { type = 'group', order = 9, name = L["|cff9482C9Warlock|r"] },
        ["WARRIOR"]     = { type = 'group', order = 10, name = L["|cffC79C6EWarrior|r"] },

      },
    },

    globalList = {
      disabled = NoOutgoing,
      name = L["Global Spells"],
      type = 'group',
      order = 22,
      args = {
        foreverNote = ForeverNote(0.5, L["merge intervals apply to outgoing spells, which are not produced on this client."]),
        title = {
          type = 'description',
          order = 0,
          name = L["List of Mergeable Spells |cff11a34a(See Category)|r"],
          fontSize = "large",
          width = "double",
        },
        mergeListDesc = {
          type = "description",
          order = 1,
          fontSize = "small",
          name = L["Uncheck an item if you do not want it merged. Contact me to add new items. See |cff11a34aCredits|r for contact info.\n\n"],
        },
      },
    },

    raceList = {
      disabled = NoOutgoing,
      name = L["Racial Spells"],
      type = 'group',
      order = 23,
      args = {
        foreverNote = ForeverNote(0.5, L["merge intervals apply to outgoing spells, which are not produced on this client."]),
        title = {
          type = 'description',
          order = 0,
          name = L["List of Mergeable Spells |cff11a34a(See Category)|r"],
          fontSize = "large",
          width = "double",
        },
        mergeListDesc = {
          type = "description",
          order = 1,
          fontSize = "small",
          name = L["Uncheck an item if you do not want it merged. Contact me to add new items. See |cff11a34aCredits|r for contact info.\n\n"],
        },
      },
    },

  },
}

addon.options.args["spellFilter"] = {
  name = L["Filters"],
  type = "group",
  order = 3,
  args = {
    filterValues = {
      name = L["Minimal Value Thresholds"],
      type = 'group',
      order = 10,
      guiInline = true,
      args = {
        foreverNote = ForeverNote(0.5, L["the outgoing thresholds do nothing: outgoing lines are not produced on this client."]),
        listSpacer0 = {
          type = "description",
          order = 0,
          name = L["|cff11a34aIncoming Player Power Threshold|r: (Mana, Rage, Energy, etc.)"],
          fontSize = "large",
        },

        filterPowerValue = {
          order = 1,
          type = 'input',
          name = L["Incoming Power"],
          desc = L["The minimal amount of player's power required inorder for it to be displayed."],
          set = setNumber2,
          get = getNumber2,
        },

        listSpacer1 = {
          type = "description",
          order = 10,
          name = L["\n|cff11a34aOutgoing Damage and Healing Threshold|r:"],
          fontSize = "large",
        },

        filterOutgoingDamageValue = {
          disabled = NoOutgoing,
          order = 11,
          type = 'input',
          name = L["Outgoing Damage"],
          desc = L["The minimal amount of damage required inorder for it to be displayed."],
          set = setNumber2,
          get = getNumber2,
        },

        filterOutgoingDamageCritEnabled = {
          disabled = NoOutgoing,
          order = 13,
          type = 'toggle',
          name = L["Use Custom Criticals"],
          desc = L["Enable a different threshold for outgoing damage criticals."],
          set = set0_1,
          get = get0_1,
        },

        filterOutgoingDamageCritValue = {
          disabled = NoOutgoing,
          order = 12,
          type = 'input',
          name = L["Outgoing Damage (Critical)"],
          desc = L["The minimal amount of damage required for a critical inorder for it to be displayed."],
          set = setNumber2,
          get = getNumber2,
          hidden = function(info)
              return not x.db.profile.spellFilter.filterOutgoingDamageCritEnabled
            end,
        },

        listSpacer_DamageHealingOutgoing = {
          type = "description",
          order = 14,
          name = "",
          fontSize = "small",
        },

        filterOutgoingHealingValue = {
          disabled = NoOutgoing,
          order = 15,
          type = 'input',
          name = L["Outgoing Healing"],
          desc = L["The minimal amount of healing required inorder for it to be displayed."],
          set = setNumber2,
          get = getNumber2,
        },

        filterOutgoingHealingCritEnabled = {
          disabled = NoOutgoing,
          order = 17,
          type = 'toggle',
          name = L["Use Custom Criticals"],
          desc = L["Enable a different threshold for outgoing healing criticals."],
          set = set0_1,
          get = get0_1,
        },

        filterOutgoingHealingCritValue = {
          disabled = NoOutgoing,
          order = 16,
          type = 'input',
          name = L["Outgoing Healing (Critical)"],
          desc = L["The minimal amount of healing required for a critical inorder for it to be displayed."],
          set = setNumber2,
          get = getNumber2,
          hidden = function(info)
              return not x.db.profile.spellFilter.filterOutgoingHealingCritEnabled
            end,
        },

        listSpacer2 = {
          type = "description",
          order = 20,
          name = L["\n|cff11a34aIncoming Damage and Healing Threshold|r:"],
          fontSize = "large",
        },

        filterIncomingDamageValue = {
          order = 21,
          type = 'input',
          name = L["Incoming Damage"],
          desc = L["The minimal amount of damage required inorder for it to be displayed."],
          set = setNumber2,
          get = getNumber2,
        },

        filterIncomingDamageCritEnabled = {
          order = 23,
          type = 'toggle',
          name = L["Use Custom Criticals"],
          desc = L["Enable a different threshold for incoming damage criticals."],
          set = set0_1,
          get = get0_1,
        },

        filterIncomingDamageCritValue = {
          order = 22,
          type = 'input',
          name = L["Incoming Damage (Critical)"],
          desc = L["The minimal amount of damage required for a critical inorder for it to be displayed."],
          set = setNumber2,
          get = getNumber2,
          hidden = function(info)
              return not x.db.profile.spellFilter.filterIncomingDamageCritEnabled
            end,
        },

        listSpacer_DamageHealingIncoming = {
          type = "description",
          order = 24,
          name = "",
          fontSize = "small",
        },

        filterIncomingHealingValue = {
          order = 25,
          type = 'input',
          name = L["Incoming Healing"],
          desc = L["The minimal amount of healing required inorder for it to be displayed."],
          set = setNumber2,
          get = getNumber2,
        },

        filterIncomingHealingCritEnabled = {
          order = 27,
          type = 'toggle',
          name = L["Use Custom Criticals"],
          desc = L["Enable a different threshold for incoming healing criticals."],
          set = set0_1,
          get = get0_1,
        },

        filterIncomingHealingCritValue = {
          order = 26,
          type = 'input',
          name = L["Incoming Healing (Critical)"],
          desc = L["The minimal amount of healing required for a critical inorder for it to be displayed."],
          set = setNumber2,
          get = getNumber2,
          hidden = function(info)
              return not x.db.profile.spellFilter.filterIncomingHealingCritEnabled
            end,
        },

      },
    },

    spellFilter = {
      name = L["Track Spell History"],
      type = 'group',
      order = 21,
      guiInline = true,
      args = {
        trackSpells = {
          order = 1,
          type = 'toggle',
          name = L["Enable History"],
          desc = L["Track all the spells that you've seen. This will make filtering them out easier."],
          set = set0_1,
          get = get0_1,
        }
      }
    },


    listBuffs = {
      name = L["|cffFFFFFFFilter:|r |cff11a34aBuffs|r"],
      type = 'group',
      order = 20,
      guiInline = false,
      args = {
        foreverNote = ForeverNote(0.5, L["this filter applies out of combat only. In combat the aura name is a secret value that cannot be compared with the list."]),
        title = {
          order = 0,
          type = "description",
          name = L["These options allow you to filter out |cff1AFF1ABuff|r auras that your player gains or loses.  In order to filter them, you need to type the |cff11a34aexact name of the aura|r (case sensitive)."],
        },
        whitelistBuffs = {
          order = 1,
          type = 'toggle',
          name = L["Whitelist"],
          desc = L["Filtered auras gains and fades that are |cff1AFF1ABuffs|r will be on a whitelist (opposed to a blacklist)."],
          set = set0_1,
          get = get0_1,
          width = "full",
        },
        spellName = {
          order = 6,
          type = 'input',
          name = L["Aura Name"],
          desc = L["The full, case-sensitive name of the |cff1AFF1ABuff|r you want to filter.\n\nYou can add/remove |cff11a34amultiple|r entries by separating them with a |cffFF8000semicolon|r (e.g. 'Shadowform;Power Word: Fortitude')."],
          set = setSpell,
          get = noop,
        },
        checkAdd = {
          order = 7,
          type = 'toggle',
          name = L["Remove"],
          desc = L["Check to remove the aura from the filtered list."],
          get = getCheckAdd,
          set = setCheckAdd,
        },

        -- This is a feature option that I will enable when I get more time D:
        selectTracked = {
          order = 8,
          type = 'select',
          name = L["Buff History:"],
          desc = L["A list of |cff1AFF1ABuff|r names that have been seen. |cffFF0000Requires:|r |cff11a34aTrack Spell History|r"],
          disabled = IsTrackSpellsDisabled,
          values = GetBuffHistory,
          get = noop,
          set = setSpell,
        },
      },
    },

    listDebuffs = {
      name = L["|cffFFFFFFFilter:|r |cff11a34aDebuffs|r"],
      type = 'group',
      order = 30,
      guiInline = false,
      args = {
        foreverNote = ForeverNote(0.5, L["this filter applies out of combat only. In combat the aura name is a secret value that cannot be compared with the list."]),
        title = {
          order = 0,
          type = "description",
          name = L["These options allow you to filter out |cffFF1A1ADebuff|r auras that your player gains or loses. In order to filter them, you need to type the |cff11a34aexact name of the aura|r (case sensitive)."],
        },
        whitelistDebuffs = {
          order = 1,
          type = 'toggle',
          name = L["Whitelist"],
          desc = L["Filtered auras gains and fades that are |cffFF1A1ADebuffs|r will be on a whitelist (opposed to a blacklist)."],
          set = set0_1,
          get = get0_1,
          width = "full",
        },
        spellName = {
          order = 2,
          type = 'input',
          name = L["Aura Name"],
          desc = L["The full, case-sensitive name of the |cffFF1A1ADebuff|r you want to filter."],
          set = setSpell,
          get = noop,
        },
        checkAdd = {
          order = 3,
          type = 'toggle',
          name = L["Remove"],
          desc = L["Check to remove the aura from the filtered list."],
          get = getCheckAdd,
          set = setCheckAdd,
        },

        -- This is a feature option that I will enable when I get more time D:
        selectTracked = {
          order = 4,
          type = 'select',
          name = L["Debuff History:"],
          desc = L["A list of |cffFF1A1ABuff|r names that have been seen. |cffFF0000Requires:|r |cff11a34aTrack Spell History|r"],
          disabled = IsTrackSpellsDisabled,
          values = GetDebuffHistory,
          get = noop,
          set = setSpell,
        },
      },
    },

    listProcs = {
      disabled = OnEventSources,
      name = L["|cffFFFFFFFilter:|r |cff11a34aProcs|r"],
      type = 'group',
      order = 40,
      guiInline = false,
      args = {
        foreverNote = ForeverNote(0.5, L["proc names are secret values on this client and cannot be filtered."]),
        title = {
          order = 0,
          type = "description",
          name = L["These options allow you to filter out spell |cff11a34aProcs|r that your player triggers.  In order to filter them, you need to type the |cff11a34aexact name of the proc|r (case sensitive)."],
        },
        whitelistProcs = {
          order = 1,
          type = 'toggle',
          name = L["Whitelist"],
          desc = L["Check for whitelist, uncheck for blacklist."],
          set = set0_1,
          get = get0_1,
          width = "full",
        },
        spellName = {
          order = 6,
          type = 'input',
          name = L["Proc Name"],
          desc = L["The full, case-sensitive name of the |cff1AFF1AProc|r you want to filter.\n\nYou can add/remove |cff11a34amultiple|r entries by separating them with a |cffFF8000semicolon|r (e.g. 'Shadowform;Power Word: Fortitude')."],
          set = setSpell,
          get = noop,
        },
        checkAdd = {
          order = 7,
          type = 'toggle',
          name = L["Remove"],
          desc = L["Check to remove the item from the filtered list."],
          get = getCheckAdd,
          set = setCheckAdd,
        },

        -- This is a feature option that I will enable when I get more time D:
        selectTracked = {
          order = 8,
          type = 'select',
          name = L["Proc History:"],
          desc = L["A list of |cff1AFF1AProc|r items that have been seen. |cffFF0000Requires:|r |cff11a34aTrack Spell History|r"],
          disabled = IsTrackSpellsDisabled,
          values = GetProcHistory,
          get = noop,
          set = setSpell,
        },
      },
    },

    listSpells = {
      disabled = NoOutgoing,
      name = L["|cffFFFFFFFilter:|r |cff11a34aOutgoing Spells|r"],
      type = 'group',
      order = 50,
      guiInline = false,
      args = {
        foreverNote = ForeverNote(0.5, L["outgoing lines are not produced on this client."]),
        title = {
          order = 0,
          type = "description",
          name = L["These options allow you to filter |cff71d5ffOutgoing Spells|r that your player does. In order to filter them, you need to type the |cff11a34aSpell ID|r of the spell."],
        },
        whitelistSpells = {
          order = 1,
          type = 'toggle',
          name = L["Whitelist"],
          desc = L["Filtered |cff71d5ffOutgoing Spells|r will be on a whitelist (opposed to a blacklist)."],
          set = set0_1,
          get = get0_1,
          width = "full",
        },
        spellName = {
          order = 2,
          type = 'input',
          name = L["Spell ID"],
          desc = L["The spell ID of the |cff71d5ffOutgoing Spell|r you want to filter."],
          set = setSpell,
          get = noop,
        },
        checkAdd = {
          order = 3,
          type = 'toggle',
          name = L["Remove"],
          desc = L["Check to remove the spell from the filtered list."],
          get = getCheckAdd,
          set = setCheckAdd,
        },

        -- This is a feature option that I will enable when I get more time D:
        selectTracked = {
          order = 4,
          type = 'select',
          name = L["Spell History:"],
          desc = L["A list of |cff71d5ffOutgoing Spell|r IDs that have been seen. |cffFF0000Requires:|r |cff11a34aTrack Spell History|r"],
          disabled = IsTrackSpellsDisabled,
          values = GetSpellHistory,
          get = noop,
          set = setSpell,
        },
      },
    },

    listItems = {
      name = L["|cffFFFFFFFilter:|r |cff11a34aItems (Plus)|r"],
      type = 'group',
      order = 60,
      guiInline = false,
      args = {
        title = {
          order = 0,
          type = "description",
          name = L["These options allow you to filter out |cff8020FFItems|r that your player collects.  In order to filter them, you need to type the |cff11a34aexact name of the item|r (case sensitive)."],
        },
        whitelistItems = {
          order = 1,
          type = 'toggle',
          name = L["Whitelist"],
          desc = L["Filtered |cff11a34aItems (Plus)|r will be on a whitelist (opposed to a blacklist)."],
          set = set0_1,
          get = get0_1,
          width = "full",
        },
        spellName = {
          order = 2,
          type = 'input',
          name = L["Item ID"],
          desc = L["The Item ID of the |cff11a34aItem|r you want to filter."],
          set = setSpell,
          get = noop,
        },
        checkAdd = {
          order = 3,
          type = 'toggle',
          name = L["Remove"],
          desc = L["Check to remove the spell from the filtered list."],
          get = getCheckAdd,
          set = setCheckAdd,
        },

        -- This is a feature option that I will enable when I get more time D:
        selectTracked = {
          order = 4,
          type = 'select',
          name = L["Item History:"],
          desc = L["A list of |cff11a34aItem|r IDs that have been seen. |cffFF0000Requires:|r |cff11a34aTrack Spell History|r"],
          disabled = IsTrackSpellsDisabled,
          values = GetItemHistory,
          get = noop,
          set = setSpell,
        },
      },
    },


    listDamage = {
      disabled = OnEventSources,
      name = L["|cffFFFFFFFilter:|r |cff11a34aIncoming Damage|r"],
      type = 'group',
      order = 70,
      guiInline = false,
      args = {
        foreverNote = ForeverNote(0.5, L["incoming damage carries no spell on this client, so there is nothing to filter by."]),
        title = {
          order = 0,
          type = "description",
          name = L["These options allow you to filter out certain |cff11a34aSpell ID|rs from |cff11a34aIncoming Damage|r to your character.  In order to add a new item, you need to type the |cff11a34aSpell ID|r. Checking |cff11a34aRemove|r and typing in a |cff11a34aSpell ID|r will remove it from the list.\n"],
        },
        whitelistDamage = {
          order = 1,
          type = 'toggle',
          name = L["Whitelist"],
          desc = L["When enabled, only spells in the list below will be shown. All other incoming damage will be hidden."],
          set = set0_1,
          get = get0_1,
          width = "full",
        },
        spellName = {
          order = 2,
          type = 'input',
          name = L["Spell ID"],
          desc = L["The Spell ID of the |cff11a34aSpell|r you want to filter."],
          set = setSpell,
          get = noop,
        },
        checkAdd = {
          order = 3,
          type = 'toggle',
          name = L["Remove"],
          desc = L["Check to remove the spell from the filtered list."],
          get = getCheckAdd,
          set = setCheckAdd,
        },

        -- This is a feature option that I will enable when I get more time D:
        selectTracked = {
          order = 4,
          type = 'select',
          name = L["Spell History:"],
          desc = L["A list of |cff11a34aSpell|r IDs that have been seen. |cffFF0000Requires:|r |cff11a34aTrack Spell History|r"],
          disabled = IsTrackSpellsDisabled,
          values = GetDamageIncomingHistory,
          get = noop,
          set = setSpell,
        },
      },
    },

    listHealing = {
      name = L["|cffFFFFFFFilter:|r |cff11a34aIncoming Healing|r"],
      type = 'group',
      order = 80,
      guiInline = false,
      args = {
        foreverNote = ForeverNote(0.5, L["only your own heals carry a spell here; other healers' spells cannot be told apart."]),
        title = {
          order = 0,
          type = "description",
          name = L["These options allow you to filter out certain |cff11a34aSpell ID|rs from |cff11a34aIncoming Healing|r to your character.  In order to add a new item, you need to type the |cff11a34aSpell ID|r. Checking |cff11a34aRemove|r and typing in a |cff11a34aSpell ID|r will remove it from the list.\n"],
        },
        whitelistHealing = {
          order = 1,
          type = 'toggle',
          name = L["Whitelist"],
          desc = L["When enabled, only spells in the list below will be shown. All other incoming healing will be hidden."],
          set = set0_1,
          get = get0_1,
          width = "full",
        },
        spellName = {
          order = 2,
          type = 'input',
          name = L["Spell ID"],
          desc = L["The Spell ID of the |cff11a34aSpell|r you want to filter."],
          set = setSpell,
          get = noop,
        },
        checkAdd = {
          order = 3,
          type = 'toggle',
          name = L["Remove"],
          desc = L["Check to remove the spell from the filtered list."],
          get = getCheckAdd,
          set = setCheckAdd,
        },

        -- This is a feature option that I will enable when I get more time D:
        selectTracked = {
          order = 4,
          type = 'select',
          name = L["Spell History:"],
          desc = L["A list of |cff11a34aSpell|r IDs that have been seen. |cffFF0000Requires:|r |cff11a34aTrack Spell History|r"],
          disabled = IsTrackSpellsDisabled,
          values = GetHealingIncomingHistory,
          get = noop,
          set = setSpell,
        },
      },
    },

  },
}

addon.options.args["Credits"] = {
  name = "Credits",
  type = 'group',
  order = 6,
  args = {
    title = {
      type = "header",
      order = 0,
      name = "Credits",
    },
    specialThanksTitle = {
      type = 'description',
      order = 1,
      name = "|cff11a34aSpecial Thanks|r",
      fontSize = "large",
    },
    specialThanksList = {
      type = 'description',
      order = 2,
      fontSize = "medium",
      name = "  |cffAA0000Tukz|r, |cffAA0000Elv|r, |cff11a34aAffli|r, |cffFF8000BuG|r, |cff8080FFShestak|r, |cffAAAAFFToludin|r, Nidra, gnangnan, NitZo, Naughtia, Derap, sortokk, ckaotik, Cecile.",
    },
    testerTitleSpace1 = {
      type = 'description',
      order = 3,
      name = " ",
    },

    testerTitle = {
      type = 'description',
      order = 10,
      name = "|cff11a34aBeta Testers - Version 3.0.0|r",
      fontSize = "large",
    },
    userName1 = {
      type = 'description',
      order = 11,
      fontSize = "medium",
      name = " |cffAAAAFF Alex|r,|cff8080EE BuG|r,|cffAAAAFF Kkthnxbye|r,|cff8080EE Azilroka|r,|cffAAAAFF Prizma|r,|cff8080EE schmeebs|r,|cffAAAAFF Pat|r,|cff8080EE hgwells|r,|cffAAAAFF Jaron|r,|cff8080EE Fitzbattleaxe|r,|cffAAAAFF Nihan|r,|cff8080EE Jaxo|r,|cffAAAAFF Schaduw|r,|cff8080EE sylenced|r,|cffAAAAFF kaleidoscope|r,|cff8080EE Killatones|r,|cffAAAAFF Trokko|r,|cff8080EE Yperia|r,|cffAAAAFF Edoc|r,|cff8080EE Cazart|r,|cffAAAAFF Nevah|r,|cff8080EE Refrakt|r,|cffAAAAFF Thakah|r,|cff8080EE johnis007|r,|cffAAAAFF Sgt|r,|cff8080EE NitZo|r,|cffAAAAFF cptblackgb|r,|cff8080EE pollyzoid|r.",
    },

    testerTitleSpace2 = {
      type = 'description',
      order = 20,
      name = " ",
    },
    curseTitle = {
      type = 'description',
      order = 21,
      name = "|cff11a34aBeta Testers - Version 4.0.0 (Curse)|r",
      fontSize = "large",
    },
    userName2 = {
      type = 'description',
      order = 22,
      fontSize = "medium",
      name = " |cffAAAAFF CadjieBOOM|r,|cff8080EE Mokal|r,|cffAAAAFF ShadoFall|r,|cff8080EE alloman|r,|cffAAAAFF chhld|r,|cff8080EE chizzlestick|r,|cffAAAAFF egreym|r,|cff8080EE nukme|r,|cffAAAAFF razrwolf|r,|cff8080EE star182|r,|cffAAAAFF zacheklund|r"
    },

    testerTitleSpace3 = {
      type = 'description',
      order = 30,
      name = " ",
    },
    tukuiTitle = {
      type = 'description',
      order = 31,
      name = "|cff11a34aBeta Testers - Version 4.0.0 (Tukui)|r",
      fontSize = "large",
    },
    userName3 = {
      type = 'description',
      order = 32,
      fontSize = "medium",
      name = " |cffAAAAFF Affiniti|r,|cff8080EE Badinfluence|r,|cffAAAAFF Badinfluence|r,|cff8080EE BuG|r,|cffAAAAFF Curdi|r,|cff8080EE Dorkie|r,|cffAAAAFF Galadeon|r,|cff8080EE HarryDotter|r,|cffAAAAFF Joebacsi21|r,|cff8080EE Kuron|r,|cffAAAAFF Mabb22|r,|cff8080EE Narlya|r,|cffAAAAFF Nihan|r,|cff8080EE Verdell|r,|cffAAAAFF arzelia|r,|cff8080EE blessed|r,|cffAAAAFF djouga|r,|cff8080EE fakemessiah|r,|cffAAAAFF faze|r,|cff8080EE firewall|r,|cffAAAAFF jatha86|r,|cff8080EE jaydogg10|r,|cffAAAAFF jlor|r,|cff8080EE lunariongames|r,|cffAAAAFF stoankold|r",
    },

    testerTitleSpace3Legion = {
      type = 'description',
      order = 33,
      name = " ",
    },
    tukuiTitleLegion = {
      type = 'description',
      order = 34,
      name = "|cff11a34aBeta Testers - Version 4.3.0+ (Legion)|r",
      fontSize = "large",
    },
    userName3Legion = {
      type = 'description',
      order = 35,
      fontSize = "medium",
      name = " |cffAAAAFF Azazu|r,|cff8080EE Broni|r,|cffAAAAFF CursedBunny|r,|cff8080EE Daemios|r,|cffAAAAFF Dajova|r,|cff8080EE Delerionn|r,|cffAAAAFF dunger|r,|cff8080EE feetss|r,|cffAAAAFF gesuntight|r,|cff8080EE Homaxz|r,|cffAAAAFF karamei|r,|cff8080EE Merathilis|r,|cffAAAAFF re1jo|r,|cff8080EE sammael666|r,|cffAAAAFF scathee|r,|cff8080EE Tonyleila|r,|cffAAAAFF Torch|r,|cff8080EE WetU|r,|cffAAAAFF Znuff|r,|cff8080EE Zylos|r\n",
    },

    testerTitleSpace3BFA = {
      type = 'description',
      order = 36,
      name = " ",
    },
    tukuiTitleBfA = {
      type = 'description',
      order = 37,
      name = "|cff11a34aBeta Testers - Version 4.4.0+ (Battle for Azeroth)|r",
      fontSize = "large",
    },

    userName3BfA = {
      type = 'description',
      order = 38,
      fontSize = "medium",
      name = " |cffAAAAFF Toludin|r",
    },

    testerTitleSpace_SL = {
      type = 'description',
      order = 40,
      name = " ",
    },
    githubTitleSL = {
      type = 'description',
      order = 41,
      name = "|cff11a34aGitHub Contributors - Version 4.5.0+ (Shadowlands)|r",
      fontSize = "large",
    },
    userNameSL = {
      type = 'description',
      order = 42,
      fontSize = "medium",
      name = " |cff22FF80 oBusk|r,|cff1AAD59 BourgeoisM|r,|cff22FF80 Witnesscm|r",
    },

    testerTitleSpace4 = {
      type = 'description',
      order = 45,
      name = " ",
    },

    githubTitle = {
      type = 'description',
      order = 46,
      name = "|cff11a34aThank You GitHub Contributors!|r",
      fontSize = "large",
    },
    userName4 = {
      type = 'description',
      order = 47,
      fontSize = "medium",
      name = " |cff22FF80 Tonyleila|r,|cff1AAD59 ckaotik|r,|cff22FF80 Stanzilla|r,|cff1AAD59 Torch (behub)|r,|cff22FF80 vforge|r,|cff1AAD59 Toludin (BfA Update!)|r",
    },




    testerTitleSpace5 = {
      type = 'description',
      order = 50,
      name = " ",
    },

    contactTitle = {
      type = 'description',
      order = 51,
      name = "|cff11a34aContact Me|r",
      fontSize = "large",
    },

    contactStep1 = {
      type = 'description',
      order = 52,
      name = "TBC Fork: |cff22FF80https://github.com/paradosi/xCT_TBC_Classic|r\n\nOriginal: |cff22FF80https://github.com/Witnesscm/xCT_Classic|r\n\nMaintained by |cffFF8000paradosi@Dreamscythe US|r",
    }
  }
}

addon.options.args["FloatingCombatText"] = {
  name = L["Floating Combat Text"],
  type = 'group',
  order = 1,
  childGroups = 'tab',
  args = {
    title2 = {
      order = 0,
      type = "description",
      name = L["The following settings allow you to tweak Blizzard's Floating Combat Text."],
    },

    blizzardFCT = {
      name = L["General"],
      type = 'group',
      order = 1,
      disabled = isCVarsDisabled,
      args = {
        listSpacer0 = {
          type = "description",
          order = 0,
          name = L["|cff11a34aFloating Combat Text Options|r:\n"],
          fontSize = 'large',
        },

        enableFloatingCombatText = {
          order = 1,
          name = L["Enable Scrolling Combat Text (Self)"],
          type = 'toggle',
          desc = L["Shows incoming damage and healing done to you. It is also required for a lot of the other events to work (as noted in their descriptions).\n\n|cffFF0000Changing this requires a UI Reload!|r"],
          width = 'double',
          get = get0,
          set = set0_update,
        },

        enableFCT_Header = {
          type = "description",
          order = 2,
          name = L["|CffFF0000Requires:|r |cff00FF33/reload|r after change"],
          fontSize = 'small',
          width = 'normal'
        },

        enableFCT_Spacer = {
          type = "description",
          order = 3,
          name = "\n",
          fontSize = 'small',
          width = 'normal'
        },

        hideBlizzardText = {
          order = 3.1,
          name = L["Hide Blizzard's Text"],
          type = 'toggle',
          desc = L["Keeps Blizzard's scrolling combat text enabled but invisible. On this client its |cffFF0000Mana Low|r message is the only low-mana signal available to xCT+, so enable the option above and hide its display here."],
          width = 'double',
          hidden = function() return not addon.useEventSources end,
          get = get0,
          set = set0,
        },

        foreverNote = {
          type = "description",
          order = 3.2,
          name = L["|cffFF8000This client|r (mainline engine) keeps only some of the settings on this page: the ones it dropped have no effect. Damage and healing over targets, the self text switch, auras, combat state, reactives, reputation, honor, dodge/parry/miss, damage reduction, energy gains, friendly healer names and float mode still apply. Low Mana/Health is kept on regardless: xCT+ needs Blizzard's message for its own low-mana line.\n"],
          fontSize = 'small',
          hidden = function() return not addon.useEventSources end,
        },

        headerAppearance = {
          type = "description",
          order = 4,
          name = L["|cff11a34aFloating Combat Text Appearance:|r"],
          fontSize = 'medium',
        },

        floatingCombatTextCombatDamageDirectionalOffset = {
          disabled = cvarMissing,
          order = 5,
          name = L["Direction Offset"],
          desc = L["The amount to offset the vertical origin of the directional damage numbers when they appear. (e.g. move them up and down)\n\n0 = Default"],
          type = 'range',
          min = -20, max = 20, step = 0.1,
          get = get0,
          set = set0_update,
        },

        floatingCombatTextCombatDamageDirectionalScale = {
          disabled = cvarMissing,
          order = 6,
          name = L["Direction Scale"],
          desc = L["The amount to scale the distance that directional damage numbers will move as they appear. Damage numbers will just scroll up if this is disabled.\n\n0 = Disabled\n1 = Default\n3.6 = Recommended"],
          type = 'range',
          min = -5, max = 5, step = 0.1,
          get = get0,
          set = set0_update,
        },


        -- Damage
        headerDamage = {
          type = "description",
          order = 10,
          name = L["|cff11a34aDamage:|r"],
          fontSize = 'medium',
        },

        floatingCombatTextCombatDamage = {
          disabled = cvarMissing,
          order = 11,
          name = L["Show Damage"],
          type = 'toggle',
          desc = OPTION_TOOLTIP_SHOW_DAMAGE,
          get = get0,
          set = set0_update,
        },

        floatingCombatTextCombatLogPeriodicSpells = {
          disabled = cvarMissing,
          order = 12,
          name = L["Show DoTs"],
          type = 'toggle',
          desc = OPTION_TOOLTIP_LOG_PERIODIC_EFFECTS,
          get = get0,
          set = set0_update,
        },

        floatingCombatTextCombatDamageAllAutos = {
          disabled = cvarMissing,
          order = 13,
          name = L["Show Auto Attacks"],
          type = 'toggle',
          desc = L["Enable this option if you want to see all auto-attacks."],
          get = get0,
          set = set0_update,
        },

        floatingCombatTextPetMeleeDamage = {
          disabled = cvarMissing,
          order = 14,
          name = L["Show Pet Melee"],
          type = 'toggle',
          desc = OPTION_TOOLTIP_SHOW_PET_MELEE_DAMAGE,
          get = get0,
          set = set0_update,
        },

        floatingCombatTextPetSpellDamage = {
          disabled = cvarMissing,
          order = 15,
          name = L["Show Pet Spells"],
          type = 'toggle',
          desc = OPTION_TOOLTIP_SHOW_PET_MELEE_DAMAGE,
          get = get0,
          set = set0_update,
        },

        -- Healing and Absorbs
        headerHealingAbsorbs = {
          type = "description",
          order = 20,
          name = L["\n|cff11a34aHealing and Absorbs:|r"],
          fontSize = 'medium',
        },

        floatingCombatTextCombatHealing = {
          disabled = cvarMissing,
          order = 21,
          name = L["Show Healing"],
          type = 'toggle',
          desc = OPTION_TOOLTIP_SHOW_COMBAT_HEALING,
          get = get0,
          set = set0_update,
        },

        floatingCombatTextFriendlyHealers = {
          disabled = cvarMissing,
          order = 22,
          name = L["Show Friendly Healers"],
          type = 'toggle',
          desc = OPTION_TOOLTIP_COMBAT_TEXT_SHOW_FRIENDLY_NAMES .. L["\n\n|cffFF0000Requires Self Scrolling Combat Text|r"],
          get = get0,
          set = set0_update,
        },

        floatingCombatTextDamageReduction = {
          disabled = cvarMissing,
          order = 23,
          name = L["Show Damage Reduction"],
          type = 'toggle',
          desc = OPTION_TOOLTIP_COMBAT_TEXT_SHOW_RESISTANCES .. L["\n\n|cffFF0000Requires Self Scrolling Combat Text|r"],
          get = get0,
          set = set0_update,
        },

        -- Gains
        headerGains = {
          type = "description",
          order = 30,
          name = L["\n|cff11a34aPlayer Gains:|r"],
          fontSize = 'medium',
        },

        floatingCombatTextEnergyGains = {
          disabled = cvarMissing,
          order = 31,
          name = L["Show Energy"],
          type = 'toggle',
          desc = OPTION_TOOLTIP_COMBAT_TEXT_SHOW_ENERGIZE .. L["\n\n|cffFF0000Requires Self Scrolling Combat Text|r"],
          get = get0,
          set = set0_update,
        },

        floatingCombatTextPeriodicEnergyGains = {
          disabled = cvarMissing,
          order = 32,
          name = L["Show Energy (Periodic)"],
          type = 'toggle',
          desc = OPTION_TOOLTIP_COMBAT_TEXT_SHOW_PERIODIC_ENERGIZE .. L["\n\n|cffFF0000Requires Self Scrolling Combat Text|r"],
          get = get0,
          set = set0_update,
        },

        floatingCombatTextComboPoints = {
          disabled = cvarMissing,
          order = 33,
          name = L["Show Combo Points"],
          type = 'toggle',
          desc = OPTION_TOOLTIP_COMBAT_TEXT_SHOW_COMBO_POINTS .. L["\n\n|cffFF0000Requires Self Scrolling Combat Text|r"],
          get = get0,
          set = set0_update,
        },

        floatingCombatTextHonorGains = {
          disabled = cvarMissing,
          order = 34,
          name = L["Show Honor"],
          type = 'toggle',
          desc = OPTION_TOOLTIP_COMBAT_TEXT_SHOW_HONOR_GAINED .. L["\n\n|cffFF0000Requires Self Scrolling Combat Text|r"],
          get = get0,
          set = set0_update,
        },

        floatingCombatTextRepChanges = {
          disabled = cvarMissing,
          order = 35,
          name = L["Show Rep Changes"],
          type = 'toggle',
          desc = OPTION_TOOLTIP_COMBAT_TEXT_SHOW_REPUTATION .. L["\n\n|cffFF0000Requires Self Scrolling Combat Text|r"],
          get = get0,
          set = set0_update,
        },

        -- Status Effects
        headerStatusEffects = {
          type = "description",
          order = 40,
          name = L["\n|cff11a34aStatus Effects:|r"],
          fontSize = 'medium',
        },

        floatingCombatTextDodgeParryMiss = {
          disabled = cvarMissing,
          order = 41,
          name = L["Show Miss Types"],
          type = 'toggle',
          desc = OPTION_TOOLTIP_COMBAT_TEXT_SHOW_DODGE_PARRY_MISS,
          get = get0,
          set = set0_update,
        },

        floatingCombatTextAuras = {
          disabled = cvarMissing,
          order = 42,
          name = L["Show Auras"],
          type = 'toggle',
          desc = OPTION_TOOLTIP_COMBAT_TEXT_SHOW_AURAS .. L["\n\n|cffFF0000Requires Self Scrolling Combat Text|r"],
          get = get0,
          set = set0_update,
        },

        floatingCombatTextAuraFade = {
          disabled = cvarMissing,
          order = 43,
          name = L["Show Aura Fade"],
          type = 'toggle',
          desc = OPTION_TOOLTIP_COMBAT_TEXT_SHOW_AURA_FADE .. L["\n\n|cffFF0000Requires Self Scrolling Combat Text|r"],
          get = get0,
          set = set0_update,
        },

        floatingCombatTextSpellMechanics = {
          disabled = cvarMissing,
          order = 44,
          name = L["Show Effects (Mine)"],
          type = 'toggle',
          desc = OPTION_TOOLTIP_SHOW_TARGET_EFFECTS,
          get = get0,
          set = set0_update,
        },

        floatingCombatTextSpellMechanicsOther = {
          disabled = cvarMissing,
          order = 45,
          name = L["Show Effects (Group)"],
          type = 'toggle',
          desc = OPTION_TOOLTIP_SHOW_OTHER_TARGET_EFFECTS,
          get = get0,
          set = set0_update,
        },

        floatingCombatTextAllSpellMechanics = {
          disabled = cvarMissing,
          order = 46,
          name = L["Show Effects (All)"],
          type = 'toggle',
          desc = OPTION_TOOLTIP_SHOW_OTHER_TARGET_EFFECTS,
          get = get0,
          set = set0_update,
        },

        CombatThreatChanges = {
          order = 47,
          type = 'toggle',
          name = L["Show Threat Changes"],
          desc = L["Enable this option if you want to see threat changes."],
          get = get0,
          set = set0_update,
        },

        -- Player's Status
        headerPlayerStatus = {
          type = "description",
          order = 50,
          name = L["\n|cff11a34aPlayer Status:|r"],
          fontSize = 'medium',
        },

        floatingCombatTextCombatState = {
          disabled = cvarMissing,
          order = 52,
          name = L["Show Combat State"],
          type = 'toggle',
          desc = OPTION_TOOLTIP_COMBAT_TEXT_SHOW_COMBAT_STATE .. L["\n\n|cffFF0000Requires Self Scrolling Combat Text|r"],
          get = get0,
          set = set0_update,
        },

        floatingCombatTextLowManaHealth = {
          order = 53,
          name = L["Show Low HP/Mana"],
          type = 'toggle',
          desc = OPTION_TOOLTIP_COMBAT_TEXT_SHOW_LOW_HEALTH_MANA .. L["\n\n|cffFF0000Requires Self Scrolling Combat Text|r"],
          -- Kept on by x.cvar_update on the event-source client: Blizzard's "Mana Low"
          -- message is xCT+'s only low-mana signal there (modules/sources.lua).
          disabled = OnEventSources,
          get = function(info) return addon.useEventSources or get0(info) end,
          set = set0_update,
        },

        floatingCombatTextReactives = {
          disabled = cvarMissing,
          order = 54,
          name = L["Show Reactives"],
          type = 'toggle',
          desc = OPTION_TOOLTIP_COMBAT_TEXT_SHOW_REACTIVES .. L["\n\n|cffFF0000Requires Self Scrolling Combat Text|r"],
          get = get0,
          set = set0_update,
        },

      },
    },


    advancedSettings = {
      name = L["Advanced"],
      type = 'group',
      order = 2,
      args = {

        listSpacer1 = {
          type = "description",
          order = 3,
          name = L["|cff11a34aFloating Combat Text|r |cffFF0000Advanced Settings|r:\n"],
          fontSize = 'large',
        },

        bypassCVARUpdates = {
          order = 4,
          type = 'toggle',
          name = L["Bypass CVar Updates (requires |cffFF0000/reload|r)"],
          desc = L["Allows you to bypass xCT+'s CVar engine. This option might help if you have FCT enabled, but it disappears after awhile. Once you set your FCT options, enable this.\n\n|cffFF0000Changing this requires a UI Reload!|r"],
          width = 'double',
          get = function( info ) return x.db.profile.bypassCVars end,
          set = function( info, value ) x.db.profile.bypassCVars = value end,
        },

        enableFCT_Header = {
          type = "description",
          order = 5,
          name = L["|CffFF0000Requires:|r |cff00FF33/reload|r after change"],
          fontSize = 'small',
          width = 'normal'
        },

      },
    },


  },
}

addon.options.args["SpellSchools"] = {
  name = L["Spell School Colors"],
  type = 'group',
  order = 5,
  args = {
    title = {
      type = "description",
      order = 0,
      name = L["|cff11a34aCustomize Spell School Colors|r:\n"],
      fontSize = 'large',
    },
  },
}

-- Helper function to get LSM sound list
-- Helper to play a sound from LSM
local function TestSound(soundName)
  if soundName and soundName ~= "None" then
    local soundFile = LSM:Fetch("sound", soundName)
    if soundFile then
      PlaySoundFile(soundFile, "Master")
    end
  end
end

addon.options.args["SoundAlerts"] = {
  name = L["Sound Alerts"],
  type = 'group',
  order = 6,
  args = {
    foreverNote = ForeverNote(0.5, L["critical-hit sounds need outgoing lines, which are not produced on this client. The low health and low mana sounds follow the game's own thresholds (35% health, 20% mana); the sliders do nothing."]),
    title = {
      type = "description",
      order = 0,
      name = L["|cff11a34aSound Alerts|r:\n\nPlay sounds when certain combat events occur. All sounds are disabled by default.\n"],
      fontSize = 'medium',
    },

    enableSounds = {
      order = 1,
      type = 'toggle',
      width = 'full',
      name = L["Enable Sound Alerts"],
      desc = L["Master toggle for all sound alerts. Individual sounds must also be enabled below."],
      get = function() return x.db.profile.sounds.enabled end,
      set = function(_, value) x.db.profile.sounds.enabled = value end,
    },

    spacer1 = {
      type = "description",
      order = 2,
      name = "\n",
    },

    -- Critical Hit
    criticalHitHeader = {
      type = "description",
      order = 10,
      name = L["|cff11a34aOutgoing Critical Hits|r:"],
      fontSize = 'medium',
    },

    criticalHitEnabled = {
      order = 11,
      type = 'toggle',
      name = L["Enable"],
      desc = L["Play a sound when you land a critical hit."],
      get = function() return x.db.profile.sounds.criticalHit.enabled end,
      set = function(_, value) x.db.profile.sounds.criticalHit.enabled = value end,
      disabled = function() return NoOutgoing() or not x.db.profile.sounds.enabled end,
    },

    criticalHitSound = {
      order = 12,
      type = 'select',
      dialogControl = 'LSM30_Sound',
      name = L["Sound"],
      values = AceGUIWidgetLSMlists.sound,
      get = function() return x.db.profile.sounds.criticalHit.sound end,
      set = function(_, value) x.db.profile.sounds.criticalHit.sound = value end,
      disabled = function() return NoOutgoing() or not x.db.profile.sounds.enabled or not x.db.profile.sounds.criticalHit.enabled end,
    },

    criticalHitTest = {
      order = 13,
      type = 'execute',
      name = L["Test Sound"],
      func = function() TestSound(x.db.profile.sounds.criticalHit.sound) end,
      disabled = function() return not x.db.profile.sounds.enabled or not x.db.profile.sounds.criticalHit.enabled end,
    },

    spacer2 = {
      type = "description",
      order = 19,
      name = "\n",
    },

    -- Killing Blow
    killingBlowHeader = {
      type = "description",
      order = 20,
      name = L["|cff11a34aKilling Blows|r:"],
      fontSize = 'medium',
    },

    killingBlowEnabled = {
      order = 21,
      type = 'toggle',
      name = L["Enable"],
      desc = L["Play a sound when you land a killing blow."],
      get = function() return x.db.profile.sounds.killingBlow.enabled end,
      set = function(_, value) x.db.profile.sounds.killingBlow.enabled = value end,
      disabled = function() return not x.db.profile.sounds.enabled end,
    },

    killingBlowSound = {
      order = 22,
      type = 'select',
      dialogControl = 'LSM30_Sound',
      name = L["Sound"],
      values = AceGUIWidgetLSMlists.sound,
      get = function() return x.db.profile.sounds.killingBlow.sound end,
      set = function(_, value) x.db.profile.sounds.killingBlow.sound = value end,
      disabled = function() return not x.db.profile.sounds.enabled or not x.db.profile.sounds.killingBlow.enabled end,
    },

    killingBlowTest = {
      order = 23,
      type = 'execute',
      name = L["Test Sound"],
      func = function() TestSound(x.db.profile.sounds.killingBlow.sound) end,
      disabled = function() return not x.db.profile.sounds.enabled or not x.db.profile.sounds.killingBlow.enabled end,
    },

    spacer3 = {
      type = "description",
      order = 29,
      name = "\n",
    },

    -- Incoming Crit
    incomingCritHeader = {
      type = "description",
      order = 30,
      name = L["|cff11a34aIncoming Critical Hits|r:"],
      fontSize = 'medium',
    },

    incomingCritEnabled = {
      order = 31,
      type = 'toggle',
      name = L["Enable"],
      desc = L["Play a sound when you are hit by a critical strike."],
      get = function() return x.db.profile.sounds.incomingCrit.enabled end,
      set = function(_, value) x.db.profile.sounds.incomingCrit.enabled = value end,
      disabled = function() return not x.db.profile.sounds.enabled end,
    },

    incomingCritSound = {
      order = 32,
      type = 'select',
      dialogControl = 'LSM30_Sound',
      name = L["Sound"],
      values = AceGUIWidgetLSMlists.sound,
      get = function() return x.db.profile.sounds.incomingCrit.sound end,
      set = function(_, value) x.db.profile.sounds.incomingCrit.sound = value end,
      disabled = function() return not x.db.profile.sounds.enabled or not x.db.profile.sounds.incomingCrit.enabled end,
    },

    incomingCritTest = {
      order = 33,
      type = 'execute',
      name = L["Test Sound"],
      func = function() TestSound(x.db.profile.sounds.incomingCrit.sound) end,
      disabled = function() return not x.db.profile.sounds.enabled or not x.db.profile.sounds.incomingCrit.enabled end,
    },

    spacer4 = {
      type = "description",
      order = 39,
      name = "\n",
    },

    -- Low Health
    lowHealthHeader = {
      type = "description",
      order = 40,
      name = L["|cff11a34aLow Health Warning|r:"],
      fontSize = 'medium',
    },

    lowHealthEnabled = {
      order = 41,
      type = 'toggle',
      name = L["Enable"],
      desc = L["Play a sound when your health drops below the threshold."],
      get = function() return x.db.profile.sounds.lowHealth.enabled end,
      set = function(_, value) x.db.profile.sounds.lowHealth.enabled = value end,
      disabled = function() return not x.db.profile.sounds.enabled end,
    },

    lowHealthSound = {
      order = 42,
      type = 'select',
      dialogControl = 'LSM30_Sound',
      name = L["Sound"],
      values = AceGUIWidgetLSMlists.sound,
      get = function() return x.db.profile.sounds.lowHealth.sound end,
      set = function(_, value) x.db.profile.sounds.lowHealth.sound = value end,
      disabled = function() return not x.db.profile.sounds.enabled or not x.db.profile.sounds.lowHealth.enabled end,
    },

    lowHealthThreshold = {
      order = 43,
      type = 'range',
      name = L["Threshold"],
      desc = L["Health percentage to trigger the warning."],
      min = 10, max = 50, step = 5,
      get = function() return x.db.profile.sounds.lowHealth.threshold end,
      set = function(_, value) x.db.profile.sounds.lowHealth.threshold = value end,
      disabled = function() return OnEventSources() or not x.db.profile.sounds.enabled or not x.db.profile.sounds.lowHealth.enabled end,
    },

    lowHealthTest = {
      order = 44,
      type = 'execute',
      name = L["Test Sound"],
      func = function() TestSound(x.db.profile.sounds.lowHealth.sound) end,
      disabled = function() return not x.db.profile.sounds.enabled or not x.db.profile.sounds.lowHealth.enabled end,
    },

    spacer5 = {
      type = "description",
      order = 49,
      name = "\n",
    },

    -- Low Mana
    lowManaHeader = {
      type = "description",
      order = 50,
      name = L["|cff11a34aLow Mana Warning|r:"],
      fontSize = 'medium',
    },

    lowManaEnabled = {
      order = 51,
      type = 'toggle',
      name = L["Enable"],
      desc = L["Play a sound when your mana drops below the threshold."],
      get = function() return x.db.profile.sounds.lowMana.enabled end,
      set = function(_, value) x.db.profile.sounds.lowMana.enabled = value end,
      disabled = function() return not x.db.profile.sounds.enabled end,
    },

    lowManaSound = {
      order = 52,
      type = 'select',
      dialogControl = 'LSM30_Sound',
      name = L["Sound"],
      values = AceGUIWidgetLSMlists.sound,
      get = function() return x.db.profile.sounds.lowMana.sound end,
      set = function(_, value) x.db.profile.sounds.lowMana.sound = value end,
      disabled = function() return not x.db.profile.sounds.enabled or not x.db.profile.sounds.lowMana.enabled end,
    },

    lowManaThreshold = {
      order = 53,
      type = 'range',
      name = L["Threshold"],
      desc = L["Mana percentage to trigger the warning."],
      min = 5, max = 40, step = 5,
      get = function() return x.db.profile.sounds.lowMana.threshold end,
      set = function(_, value) x.db.profile.sounds.lowMana.threshold = value end,
      disabled = function() return OnEventSources() or not x.db.profile.sounds.enabled or not x.db.profile.sounds.lowMana.enabled end,
    },

    lowManaTest = {
      order = 54,
      type = 'execute',
      name = L["Test Sound"],
      func = function() TestSound(x.db.profile.sounds.lowMana.sound) end,
      disabled = function() return not x.db.profile.sounds.enabled or not x.db.profile.sounds.lowMana.enabled end,
    },
  },
}

addon.options.args["Frames"] = {
  name = L["Frames"],
  type = 'group',
  order = 0,
  args = {


    frameSettings = {
      name = L["Frame Settings "],
      type = 'group',
      order = 1,
      guiInline = true,
      args = {

        listSpacer0 = {
          type = "description",
          order = 1,
          name = L["|cff11a34aWhen Moving the Frames|r:"],
          fontSize = 'large',
        },

        showGrid = {
          order = 2,
          type = 'toggle',
          name = L["Show Align Grid"],
          desc = L["Shows a grid after you |cff11a34aToggle Frames|r to help you align |cff11a34axCT+|r frames better."],
          get = get0,
          set = set0,
        },

        showPositions = {
          order = 3,
          type = 'toggle',
          name = L["Show Positions"],
          desc = L["Shows the locations and sizes of your frames after you |cff11a34aToggle Frames|r to help you align |cff11a34axCT+|r frames better."],
          get = get0,
          set = set0,
        },

        listSpacer1 = {
          type = "description",
          order = 10,
          name = L["\n|cff11a34aWhen Showing the Frames|r:"],
          fontSize = 'large',
        },

        frameStrata = {
          type = 'select',
          order = 11,
          name = L["Frame Strata"],
          desc = L["The Z-Layer to place the |cff11a34axCT+|r frames onto. If you find that another addon is in front of |cff11a34axCT+|r frames, try increasing the Frame Strata."],
          values = {
            --["1PARENT"]             = "Parent |cffFF0000(Lowest)|r",
            ["2BACKGROUND"]         = L["Background |cffFF0000(Lowest)|r"],
            ["3LOW"]                = L["Low"],
            ["4MEDIUM"]             = L["Medium"],
            ["5HIGH"]               = L["High |cff848482(Default)|r"],
            ["6DIALOG"]             = L["Dialog"],
            ["7FULLSCREEN"]         = L["Fullscreen"],
            ["8FULLSCREEN_DIALOG"]  = L["Fullscreen Dialog"],
            ["9TOOLTIP"]            = L["ToolTip |cffAAFF80(Highest)|r"],
          },
          get = get0,
          set = set0_update,
        },

        listSpacer2 = {
          type = "description",
          order = 20,
          name = L["\n|cff11a34aWhen Leaving Combat|r:"],
          fontSize = 'large',
        },

        clearLeavingCombat = {
          order = 21,
          type = 'toggle',
          name = L["Clear Frames"],
          desc = L["Enable this option if you have problems with 'floating' icons."],
          width = "full",
          get = get0,
          set = set0,
        },

      },
    },

    spacer1 = {
      type = 'description',
      name = "\n",
      order = 2,
    },

    megaDamage = {
      name = L["Number Format Settings"],
      type = 'group',
      order = 3,
      guiInline = true,
      args = {
        listSpacer0 = {
          type = "description",
          order = 0,
          name = L["|cff11a34aFormat Numbers in the Frames|r (Choose one):"],
          fontSize = 'large',
        },
        formatAbbreviate = {
          type = 'toggle',
          order = 1,
          name = L["Abbreviate Numbers"],
          set = setFormating,
          get = getDBSpells,
        },
        formatGroups = {
          type = 'toggle',
          order = 2,
          name = L["Decimal Marks"],
          desc = L["Groups decimals and separates them by commas; this allows for better responsiveness when reading numbers.\n\n|cffFF0000EXAMPLE|r |cff11a34a12,890|r"],
          set = setFormating,
          get = getDBSpells,
        },

        abbDesc = {
          type = "description",
          order = 9,
          name = L["\n\n|cff848482Note:|r |cffAAAAAAFormat settings need to be independently enabled on each frame through its respective settings page.|r"],
          fontSize = 'small',
        },

        listSpacer1 = {
          type = "description",
          order = 10,
          name = L["\n|cff11a34aAdditional Abbreviation Settings|r:"],
          fontSize = 'large',
        },
        thousandSymbol = {
          order = 11,
          type = 'input',
          name = L["Thousand"],
          desc = L["Symbol for: |cffFF0000Thousands|r |cff11a34a(10e+3)|r"],
          get = getTextIn0,
          set = setTextIn0,
        },
        millionSymbol = {
          order = 12,
          type = 'input',
          name = L["Million"],
          desc = L["Symbol for: |cffFF0000Millions|r |cff11a34a(10e+6)|r"],
          get = getTextIn0,
          set = setTextIn0,
        },
        billionSymbol = {
          order = 14,
          type = 'input',
          name = L["Billion"],
          desc = L["Symbol for: |cffFF0000Billions|r |cff11a34a(10e+9)|r"],
          get = getTextIn0,
          set = setTextIn0,
        },
        decimalPoint = {
          order = 15,
          type = 'toggle',
          name = L["Single Decimal Precision"],
          desc = L["Shows a single digit of precision when abbreviating the value (e.g. will show |cff11a34a5.9K|r instead of |cff11a34a6K|r)."],
          get = get0,
          set = set0,
        },
      },
    },

    spacer2 = {
      type = 'description',
      name = "\n",
      order = 4,
    },

    miscFonts = {
      order = 5,
      type = 'group',
      guiInline = true,
      name = L["Global Frame Settings"],
      args = {
        miscDesc = {
          type = "description",
          order = 0,
          name = L["The following settings are marked as experimental. They should all work, but they might not be very useful. Expect chanrges or updates to these in the near future.\n\nClick |cff11a34aSet All|r to apply setting to all |cff11a34axCT+|r frames.\n"],
        },


        font = {
          type = 'select', dialogControl = 'LSM30_Font',
          order = 1,
          name = L["Font"],
          desc = L["Set the font of the frame."],
          values = AceGUIWidgetLSMlists.font,
          get = function(info) return miscFont end,
          set = function(info, value) miscFont = value end,
        },

        applyFont = {
          type = 'execute',
          order = 2,
          name = L["Set All"],
          width = "half",
          func = function()
            if miscFont then
              for framename, settings in pairs(x.db.profile.frames) do
                settings.font = miscFont
              end
              x:UpdateFrames()
            end
          end,
        },

        spacer1 = {
          type = 'description',
          order = 3,
          name = "",
        },

        fontOutline = {
          type = 'select',
          order = 4,
          name = L["Font Outline"],
          desc = L["Set the font outline."],
          values = {
            ['1NONE'] = L["None"],
            ['2OUTLINE'] = L['OUTLINE'],
            -- BUG: Setting font to monochrome AND above size 16 will crash WoW
            -- http://us.battle.net/wow/en/forum/topic/6470967362
            ['3MONOCHROME'] = L['MONOCHROME'],
            ['4MONOCHROMEOUTLINE'] = L['MONOCHROMEOUTLINE'],
            ['5THICKOUTLINE'] = L['THICKOUTLINE'],
          },
          get = function(info) return miscFontOutline end,
          set = function(info, value) miscFontOutline = value end,
        },

        applyFontOutline = {
          type = 'execute',
          order = 5,
          name = L["Set All"],
          width = "half",
          func = function()
            if miscFontOutline then
              for framename, settings in pairs(x.db.profile.frames) do
                settings.fontOutline = miscFontOutline
              end
              x:UpdateFrames()
            end
          end,
        },

        spacer2 = {
          type = 'description',
          order = 6,
          name = "",
        },

        customFade = {
          type = 'toggle',
          order = 7,
          name = L["Use Custom Fade"],
          desc = L["Allows you to customize the fade time of each frame."],
          get = function(info) return miscEnableCustomFade end,
          set = function(info, value) miscEnableCustomFade = value end,
        },

        applyCustomFade = {
          type = 'execute',
          order = 8,
          name = L["Set All"],
          width = "half",
          func = function()
            if miscEnableCustomFade ~= nil then
              for framename, settings in pairs(x.db.profile.frames) do
                if settings.enableCustomFade ~= nil then
                  settings.enableCustomFade = miscEnableCustomFade
                end
              end
              x:UpdateFrames()
            end
          end,
        },

      },
    },

    spacer3 = {
      type = 'description',
      name = "\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n",
      order = 6,
    },

--[[ XCT+ The Frames: ]]
    general = {
      name = L["|cffFFFFFFGeneral|r"],
      type = 'group',
      order = 11,
      childGroups = 'tab',
      args = {

        frameSettings = {
          order = 10,
          type = 'group',
          name = L["Frame"],
          args = {
            frameSettings = {
              type = 'description',
              order = 0,
              name = L["|cff11a34aFrame Settings|r:"],
              fontSize = 'large',
            },
            enabledFrame = {
              order = 1,
              type = 'toggle',
              name = L["Enable"],
              width = 'half',
              get = get2,
              set = set2_update,
            },
            secondaryFrame = {
              type = 'select',
              order = 2,
              name = L["Secondary Frame"],
              desc = L["A frame to forward messages to when this frame is disabled."],
              values = {
                [0] = L["None"],
                --[1] = L["General"],
                [2] = L["Outgoing"],
                [3] = L["Outgoing (Criticals)"],
                [4] = L["Incoming (Damage)"],
                [5] = L["Incoming (Healing)"],
                [6] = L["Class Power"],
                [7] = L["Special Effects (Procs)"],
                [8] = L["Loot, Currency & Money"],
              },
              get = get2,
              set = set2,
              disabled = isFrameItemEnabled,
            },
            insertText = {
              type = 'select',
              order = 3,
              name = L["Text Direction"],
              desc = L["Changes the direction that the text travels in the frame."],
              values = {
                ["top"] = L["Down"],
                ["bottom"] = L["Up"],
              },
              get = get2,
              set = set2_update,
              disabled = isFrameItemDisabled,
            },
            alpha = {
              order = 4,
              name = L["Frame Alpha"],
              desc = L["Sets the alpha of the frame."],
              type = 'range',
              min = 0, max = 100, step = 1,
              get = get2,
              set = set2_update,
              disabled = isFrameItemDisabled,
            },
            megaDamage = {
              order = 5,
              type = 'toggle',
              name = L["Number Formatting"],
              desc = L["Enables number formatting. This option can be customized in the main |cff00FF00Frames|r options page to be either |cff11a34aAbbreviation|r or |cff11a34aDecimal Marks|r. "],
              get = get2,
              set = set2,
            },

            frameScrolling = {
              type = 'description',
              order = 10,
              name = L["\n|cff11a34aScrollable Frame Settings|r:"],
              fontSize = 'large',
            },
            enableScrollable = {
              order = 11,
              type = 'toggle',
              name = L["Enabled"],
              get = get2,
              set = set2_update,
              disabled = isFrameItemDisabled,
            },
            scrollableLines = {
              order = 12,
              name = L["Number of Lines"],
              type = 'range',
              min = 10, max = 60, step = 1,
              get = get2,
              set = set2_update,
              disabled = isFrameNotScrollable,
            },
            scrollableInCombat = {
              order = 13,
              type = 'toggle',
              name = L["Disable in Combat"],
              get = get2,
              set = set2_update,
              disabled = isFrameItemDisabled,
            },

            frameFading = {
              type = 'description',
              order = 20,
              name = L["\n|cff11a34aFading Text Settings|r:"],
              fontSize = 'large',
            },
            enableCustomFade = {
              order = 21,
              type = 'toggle',
              name = L["Use Custom Fade"],
              width = 'full',
              get = get2,
              set = set2_update,
              disabled = isFrameItemDisabled,
            },
            enableFade = {
              order = 22,
              type = 'toggle',
              name = L["Enable"],
              desc = L["Turn off to disable fading all together.\n\n|cffFF0000Requires:|r |cff11a34aUse Custom Fade|r"],
              width = 'half',
              get = get2,
              set = set2_update,
              disabled = isFrameUseCustomFade,
            },
            fadeTime = {
              order = 23,
              name = L["Fade Out Duration"],
              desc = L["The duration of the fade out animation. |cff848482(Default: |cff11a34a0.3|r)|r\n\n|cffFF0000Requires:|r |cff11a34aUse Custom Fade|r"],
              type = 'range',
              min = 0, max = 2, step = .1,
              get = get2,
              set = set2_update,
              disabled = isFrameFadingDisabled,
            },
            visibilityTime = {
              order = 24,
              name = L["Visibility Duration"],
              desc = L["The duration that the text is shown in the frame. |cff848482(Default: |cff11a34a5|r)|r\n\n|cffFF0000Requires:|r |cff11a34aUse Custom Fade|r"],
              type = 'range',
              min = 2, max = 15, step = 1,
              get = get2,
              set = set2_update,
              disabled = isFrameFadingDisabled,
            },

          },
        },

        fonts = {
          order = 20,
          type = 'group',
          name = L["Font"],
          args = {
            fontSettings = {
              type = 'description',
              order = 0,
              name = L["|cff11a34aFont Settings|r:"],
              fontSize = 'large',
            },
            font = {
              type = 'select', dialogControl = 'LSM30_Font',
              order = 1,
              name = L["Font"],
              desc = L["Set the font of the frame."],
              values = AceGUIWidgetLSMlists.font,
              get = get2,
              set = set2_update,
              disabled = isFrameItemDisabled,
            },
            fontSize = {
              order = 2,
              name = L["Font Size"],
              desc = L["Set the font size of the frame."],
              type = 'range',
              min = 6, max = 64, step = 1,
              get = get2,
              set = set2_update,
              disabled = isFrameItemDisabled,
            },
            fontOutline = {
              type = 'select',
              order = 3,
              name = L["Font Outline"],
              desc = L["Set the font outline."],
              values = {
                ['1NONE'] = L["None"],
                ['2OUTLINE'] = L['OUTLINE'],
                -- BUG: Setting font to monochrome AND above size 16 will crash WoW
                -- http://us.battle.net/wow/en/forum/topic/6470967362
                ['3MONOCHROME'] = L['MONOCHROME'],
                ['4MONOCHROMEOUTLINE'] = L['MONOCHROMEOUTLINE'],
                ['5THICKOUTLINE'] = L['THICKOUTLINE'],
              },
              get = get2,
              set = set2_update,
              disabled = isFrameItemDisabled,
            },
            fontJustify = {
              type = 'select',
              order = 4,
              name = L["Justification"],
              desc = L["Justifies the output to a side."],
              values = {
                ['RIGHT']  = L["Right"],
                ['LEFT']   = L["Left"],
                ['CENTER'] = L["Center"],
              },
              get = get2,
              set = set2_update,
            },

            fontShadowSettings = {
              type = 'description',
              order = 10,
              name = L["\n|cff11a34aFont Shadow Settings|r:"],
              fontSize = 'large',
            },

            enableFontShadow = {
              order = 11,
              type = 'toggle',
              name = L["Enable Font Shadow"],
              desc = L["Shows a shadow behind the combat text fonts."],
              get = get2,
              set = set2_update,
              disabled = isFrameItemDisabled,
            },

            fontShadowColor = {
              order = 12,
              type = 'color',
              hasAlpha = true,
              name = L["Font Shadow Color"],
              get = getColor2,
              set = setColor2_alpha,
              disabled = isFrameFontShadowDisabled,
            },

            fontShadowOffsetX = {
              order = 13,
              name = L["Horizonal Offset"],
              type = 'range',
              min = -10, max = 10, step = 1,
              get = get2,
              set = set2_update,
              disabled = isFrameFontShadowDisabled,
            },

            fontShadowOffsetY = {
              order = 14,
              name = L["Vertical Offset"],
              type = 'range',
              min = -10, max = 10, step = 1,
              get = get2,
              set = set2_update,
              disabled = isFrameFontShadowDisabled,
            },
          },
        },

        icons = {
          order = 30,
          type = 'group',
          name = L["Icons"],
          args = {
            foreverNote = ForeverNote(0.5, L["icons appear on buff and debuff lines out of combat only. In combat the spell is a secret value and only its name can be shown."]),
            iconSizeSettings = {
              type = 'description',
              order = 1,
              name = L["|cff11a34aIcon Settings|r:"],
              fontSize = 'large',
            },
            iconsEnabled = {
              order = 2,
              type = 'toggle',
              name = L["Enable Icons"],
              desc = L["Show icons next to your damage."],
              get = get2,
              set = set2,
              disabled = isFrameItemDisabled,
            },
            iconsSize = {
              order = 3,
              name = L["Size"],
              desc = L["Set the icon size. (Recommended value: 16)"],
              type = 'range',
              min = 6, max = 22, step = 1,
              get = get2,
              set = set2,
              disabled = isFrameIconDisabled,
            },
            spacerIconsEnabled = {
              order = 4,
              type = 'toggle',
              name = L["Show Invisible Icons"],
              desc = L["When icons are disabled, you can still enable invisible icons to line up text."],
              get = get2,
              set = set2,
              disabled = isFrameIconSpacerDisabled,
            },
          }
        },

        fontColors = {
          order = 40,
          type = 'group',
          name = L["Colors"],
          args = {
            customColors_label = {
              type = 'description',
              order = 0,
              name = L["|cff11a34aCustom Colors|r:"],
              fontSize = 'large',
            },

            customColors_OverrideDesc = {
              type = 'description',
              order = 1,
              name = L["\n|cff11a34aOverride All Frame Color Settings|r:"],
              fontSize = 'small',
            },

            customColor = {
              order = 2,
              type = 'toggle',
              name = L["All Text One Color (Override Color Settings)"],
              width = 'double',
              desc = L["Change all the text in this frame to a specific color."],
              get = get2,
              set = set2,
            },

            fontColor = {
              order = 3,
              type = 'color',
              name = L["Color"],
              get = getColor2,
              set = setColor2,
              hidden = isFrameCustomColorDisabled,
            },

            customColors_Desc = {
              type = 'description',
              order = 4,
              name = L["\n|cff11a34aOther Color Settings|r:"],
              fontSize = 'small',
            },
          },
        },

        specialTweaks = {
          order = 50,
          name = L["Misc"],
          type = 'group',
          args = {
            foreverNote = ForeverNote(0.5, L["dispels and spell steals cannot be detected. Buff and debuff lines in combat ignore the filters. Killing blows show in the open world only (unit identities are secret in dungeons)."]),
            specialTweaks = {
              type = 'description',
              order = 0,
              name = L["|cff11a34aMiscellaneous Settings|r:"],
              fontSize = 'large',
            },
            showInterrupts = {
              order = 1,
              type = 'toggle',
              name = L["Interrupts"],
              desc = L["Display the spell you successfully interrupted."],
              get = get2,
              set = set2,
            },
            showDispells = {
              disabled = OnEventSources,
              order = 2,
              type = 'toggle',
              name = L["Dispell/Steal"],
              desc = L["Show the spell that you dispelled or stole."],
              get = get2,
              set = set2,
            },
            showPartyKills = {
              order = 3,
              type = 'toggle',
              name = L["Unit Killed"],
              desc = L["Display unit that was killed by your final blow."],
              get = get2,
              set = set2,
            },
            showBuffs = {
              order = 4,
              type = 'toggle',
              name = L["Buff Gains/Fades"],
              desc = L["Display the names of helpful auras |cff00FF00(Buffs)|r that you gain and lose."],
              get = get2,
              set = set2,
            },
            showDebuffs = {
              order = 5,
              type = 'toggle',
              name = L["Debuff Gains/Fades"],
              desc = L["Display the names of harmful auras |cffFF0000(Debuffs)|r that you gain and lose."],
              get = get2,
              set = set2,
            },
            showLowManaHealth = {
              order = 6,
              type = 'toggle',
              name = L["Low Mana/Health"],
              desc = L["Displays 'Low Health/Mana' when your health/mana reaches the low threshold."],
              get = get2,
              set = set2,
            },
            showCombatState = {
              order = 7,
              type = 'toggle',
              name = L["Leave/Enter Combat"],
              desc = L["Displays when the player is leaving or entering combat."],
              get = get2,
              set = set2,
            },
            showRepChanges = {
              order = 8,
              type = 'toggle',
              name = L["Show Reputation"],
              desc = L["Displays your player's reputation gains and losses."],
              get = get2,
              set = set2,
            },
            showHonorGains = {
              order = 9,
              type = 'toggle',
              name = L["Show Honor"],
              desc = L["Displays your player's honor gains."],
              get = get2,
              set = set2,
            },
            showSkillUps = {
              order = 10,
              type = 'toggle',
              name = L["Show Skill Ups"],
              desc = L["Displays profession and weapon skill increases in the General frame."],
              get = get2,
              set = set2,
            },
          },
        },

      },
    },

    outgoing = {
      name = L["|cffFFFFFFOutgoing|r"],
      type = 'group',
      order = 12,
      childGroups = 'tab',
      args = {

        frameSettings = {
          order = 10,
          type = 'group',
          name = L["Frame"],
          args = {
            foreverNote = ForeverNote(0.5, L["outgoing damage and healing lines are not produced on this client: the combat log is closed to addons, and the attribution that could be guessed from other events is not exact. Blizzard's own numbers over the target still work (Floating Combat Text page). The icon, name and content settings below are disabled."]),
            frameSettings = {
              type = 'description',
              order = 0,
              name = L["|cff11a34aFrame Settings|r:"],
              fontSize = 'large',
            },
            enabledFrame = {
              order = 1,
              type = 'toggle',
              name = L["Enable"],
              width = 'half',
              get = get2,
              set = set2_update,
            },
            secondaryFrame = {
              type = 'select',
              order = 2,
              name = L["Secondary Frame"],
              desc = L["A frame to forward messages to when this frame is disabled."],
              values = {
                [0] = L["None"],
                [1] = L["General"],
                --[2] = L["Outgoing"],
                [3] = L["Outgoing (Criticals)"],
                [4] = L["Incoming (Damage)"],
                [5] = L["Incoming (Healing)"],
                [6] = L["Class Power"],
                [7] = L["Special Effects (Procs)"],
                [8] = L["Loot, Currency & Money"],
              },
              get = get2,
              set = set2,
              disabled = isFrameItemEnabled,
            },
            insertText = {
              type = 'select',
              order = 3,
              name = L["Text Direction"],
              desc = L["Changes the direction that the text travels in the frame."],
              values = {
                ["top"] = L["Down"],
                ["bottom"] = L["Up"],
              },
              get = get2,
              set = set2_update,
              disabled = isFrameItemDisabled,
            },
            alpha = {
              order = 4,
              name = L["Frame Alpha"],
              desc = L["Sets the alpha of the frame."],
              type = 'range',
              min = 0, max = 100, step = 1,
              get = get2,
              set = set2_update,
              disabled = isFrameItemDisabled,
            },
            megaDamage = {
              order = 5,
              type = 'toggle',
              name = L["Number Formatting"],
              desc = L["Enables number formatting. This option can be customized in the main |cff00FF00Frames|r options page to be either |cff11a34aAbbreviation|r or |cff11a34aDecimal Marks|r. "],
              get = get2,
              set = set2,
            },

            frameScrolling = {
              type = 'description',
              order = 10,
              name = L["\n|cff11a34aScrollable Frame Settings|r:"],
              fontSize = 'large',
            },
            enableScrollable = {
              order = 11,
              type = 'toggle',
              name = L["Enabled"],
              get = get2,
              set = set2_update,
              disabled = isFrameItemDisabled,
            },
            scrollableLines = {
              order = 12,
              name = L["Number of Lines"],
              type = 'range',
              min = 10, max = 60, step = 1,
              get = get2,
              set = set2_update,
              disabled = isFrameNotScrollable,
            },
            scrollableInCombat = {
              order = 13,
              type = 'toggle',
              name = L["Disable in Combat"],
              get = get2,
              set = set2_update,
              disabled = isFrameItemDisabled,
            },

            frameFading = {
              type = 'description',
              order = 30,
              name = L["\n|cff11a34aFading Text Settings|r:"],
              fontSize = 'large',
            },
            enableCustomFade = {
              order = 31,
              type = 'toggle',
              name = L["Use Custom Fade"],
              width = 'full',
              get = get2,
              set = set2_update,
              disabled = isFrameItemDisabled,
            },
            enableFade = {
              order = 32,
              type = 'toggle',
              name = L["Enable"],
              desc = L["Turn off to disable fading all together.\n\n|cffFF0000Requires:|r |cff11a34aUse Custom Fade|r"],
              width = 'half',
              get = get2,
              set = set2_update,
              disabled = isFrameUseCustomFade,
            },
            fadeTime = {
              order = 33,
              name = L["Fade Out Duration"],
              desc = L["The duration of the fade out animation. |cff848482(Default: |cff11a34a0.3|r)|r\n\n|cffFF0000Requires:|r |cff11a34aUse Custom Fade|r"],
              type = 'range',
              min = 0, max = 2, step = .1,
              get = get2,
              set = set2_update,
              disabled = isFrameFadingDisabled,
            },
            visibilityTime = {
              order = 34,
              name = L["Visibility Duration"],
              desc = L["The duration that the text is shown in the frame. |cff848482(Default: |cff11a34a5|r)|r\n\n|cffFF0000Requires:|r |cff11a34aUse Custom Fade|r"],
              type = 'range',
              min = 2, max = 15, step = 1,
              get = get2,
              set = set2_update,
              disabled = isFrameFadingDisabled,
            },

          },
        },

        fonts = {
          order = 20,
          type = 'group',
          name = L["Font"],
          args = {
            fontSettings = {
              type = 'description',
              order = 0,
              name = L["|cff11a34aFont Settings|r:"],
              fontSize = 'large',
            },
            font = {
              type = 'select', dialogControl = 'LSM30_Font',
              order = 1,
              name = L["Font"],
              desc = L["Set the font of the frame."],
              values = AceGUIWidgetLSMlists.font,
              get = get2,
              set = set2_update,
              disabled = isFrameItemDisabled,
            },
            fontSize = {
              order = 2,
              name = L["Font Size"],
              desc = L["Set the font size of the frame."],
              type = 'range',
              min = 6, max = 64, step = 1,
              get = get2,
              set = set2_update,
              disabled = isFrameItemDisabled,
            },
            fontOutline = {
              type = 'select',
              order = 3,
              name = L["Font Outline"],
              desc = L["Set the font outline."],
              values = {
                ['1NONE'] = L["None"],
                ['2OUTLINE'] = L['OUTLINE'],
                -- BUG: Setting font to monochrome AND above size 16 will crash WoW
                -- http://us.battle.net/wow/en/forum/topic/6470967362
                ['3MONOCHROME'] = L['MONOCHROME'],
                ['4MONOCHROMEOUTLINE'] = L['MONOCHROMEOUTLINE'],
                ['5THICKOUTLINE'] = L['THICKOUTLINE'],
              },
              get = get2,
              set = set2_update,
              disabled = isFrameItemDisabled,
            },
            fontJustify = {
              type = 'select',
              order = 4,
              name = L["Justification"],
              desc = L["Justifies the output to a side."],
              values = {
                ['RIGHT']  = L["Right"],
                ['LEFT']   = L["Left"],
                ['CENTER'] = L["Center"],
              },
              get = get2,
              set = set2_update,
            },

            fontShadowSettings = {
              type = 'description',
              order = 10,
              name = L["\n|cff11a34aFont Shadow Settings|r:"],
              fontSize = 'large',
            },

            enableFontShadow = {
              order = 11,
              type = 'toggle',
              name = L["Enable Font Shadow"],
              desc = L["Shows a shadow behind the combat text fonts."],
              get = get2,
              set = set2_update,
              disabled = isFrameItemDisabled,
            },

            fontShadowColor = {
              order = 12,
              type = 'color',
              hasAlpha = true,
              name = L["Font Shadow Color"],
              get = getColor2,
              set = setColor2_alpha,
              disabled = isFrameFontShadowDisabled,
            },

            fontShadowOffsetX = {
              order = 13,
              name = L["Horizonal Offset"],
              type = 'range',
              min = -10, max = 10, step = 1,
              get = get2,
              set = set2_update,
              disabled = isFrameFontShadowDisabled,
            },

            fontShadowOffsetY = {
              order = 14,
              name = L["Vertical Offset"],
              type = 'range',
              min = -10, max = 10, step = 1,
              get = get2,
              set = set2_update,
              disabled = isFrameFontShadowDisabled,
            },
          },
        },

        icons = {
          disabled = NoOutgoing,
          order = 30,
          type = 'group',
          name = L["Icons"],
          args = {
            iconSizeSettings = {
              type = 'description',
              order = 1,
              name = L["|cff11a34aIcon Settings|r:"],
              fontSize = 'large',
            },
            iconsEnabled = {
              order = 2,
              type = 'toggle',
              name = L["Enable Icons"],
              desc = L["Show icons next to your damage."],
              get = get2,
              set = set2,
              disabled = isFrameItemDisabled,
            },
            iconsSize = {
              order = 3,
              name = L["Size"],
              desc = L["Set the icon size. (Recommended value: 16)"],
              type = 'range',
              min = 6, max = 22, step = 1,
              get = get2,
              set = set2,
              disabled = isFrameIconDisabled,
            },
            spacerIconsEnabled = {
              order = 4,
              type = 'toggle',
              name = L["Show Invisible Icons"],
              desc = L["When icons are disabled, you can still enable invisible icons to line up text."],
              get = get2,
              set = set2,
              disabled = isFrameIconSpacerDisabled,
            },
          }
        },

        fontColors = {
          order = 40,
          type = 'group',
          name = L["Colors"],
          args = {
            customColors_label = {
              type = 'description',
              order = 0,
              name = L["|cff11a34aCustom Colors|r:"],
              fontSize = 'large',
            },

            customColors_OverrideDesc = {
              type = 'description',
              order = 1,
              name = L["\n|cff11a34aOverride All Frame Color Settings|r:"],
              fontSize = 'small',
            },

            customColor = {
              order = 2,
              type = 'toggle',
              name = L["All Text One Color (Override Color Settings)"],
              width = 'double',
              desc = L["Change all the text in this frame to a specific color."],
              get = get2,
              set = set2,
            },

            fontColor = {
              order = 3,
              type = 'color',
              name = L["Color"],
              get = getColor2,
              set = setColor2,
              hidden = isFrameCustomColorDisabled,
            },

            customColors_Desc = {
              type = 'description',
              order = 4,
              name = L["\n|cff11a34aOther Color Settings|r:"],
              fontSize = 'small',
            },
          },
        },

        names = {
          disabled = NoOutgoing,
          order = 50,
          type = 'group',
          name = L["Names"],
          childGroups = 'select',
          get = getNameFormat,
          set = setNameFormat,
          args = {
            namesDescription = {
              type = 'description',
              order = 1,
              name = L["The |cff11a34aNames Settings|r allows you to further format and customize your combat text frames. By selecting values from below, you will be able to see the source, destination or spell names of certain events.\n\n|cffFF8040NOTE:|r The |cff11a34aSpam Merger|r will preempt formatting."],
              fontSize = 'small'
            },

            nameAppearance = {
              type = 'description',
              order = 2,
              name = L["|cff11a34aName Appearance|r:\n\n"],
              fontSize = 'large',
              width = 'normal'
            },

            namePrefix = {
              order = 3,
              type = 'input',
              name = L["Prefix"],
              desc = L["Prefix this value to the beginning when displaying the name."],
              get = getNameFormatText,
              set = setNameFormatText,
            },

            namePostfix = {
              order = 4,
              type = 'input',
              name = L["Postfix"],
              desc = L["Postfix this value to the end when displaying the name."],
              get = getNameFormatText,
              set = setNameFormatText,
            },

            PLAYER = {
              order = 10,
              type = 'group',
              name = L["Events to a Player"],
              args = {
                playerNames = {
                  type = 'description',
                  order = 1,
                  name = L["|cff11a34aPlayer Name Format Settings|r:"],
                  fontSize = 'large',
                },

                enableNameColor = {
                  order = 2,
                  type = 'toggle',
                  name = L["Color Player Name"],
                  desc = L["If the player's class is known (e.g. is a raid member), it will be colored."],
                },

                removeRealmName = {
                  order = 3,
                  type = 'toggle',
                  name = L["Remove Realm Name"],
                  desc = L["If the player has a realm name attatched to her name, it will be removed."],
                },

                enableCustomNameColor = {
                  order = 4,
                  type = 'toggle',
                  name = L["Custom"],
                  desc = L["Preempt an automatic color with a custom one."],
                  width = 'half',
                },

                customNameColor = {
                  order = 5,
                  type = 'color',
                  name = L["Color"],
                  get = getNameFormatColor,
                  set = setNameFormatColor,
                  width = 'half',
                },

                playerSpellNames = {
                  type = 'description',
                  order = 10,
                  name = L["\n|cff11a34aSpell Name Format Settings|r:"],
                  fontSize = 'large',
                },

                enableSpellColor = {
                  order = 11,
                  type = 'toggle',
                  name = L["Color Spell Name"],
                  desc = L["The spell name will be colored according to it's spell school."],
                },

                playerNames_Spacer1 = {
                  type = 'description',
                  order = 12,
                  name = "",
                  width = 'normal'
                },

                enableCustomSpellColor = {
                  order = 13,
                  type = 'toggle',
                  name = L["Custom"],
                  desc = L["Preempt an automatic color with a custom one."],
                  width = 'half'
                },

                customSpellColor = {
                  order = 14,
                  type = 'color',
                  name = L["Color"],
                  width = 'half',
                  get = getNameFormatColor,
                  set = setNameFormatColor,
                },

                playerNames_Spacer2 = {
                  type = 'description',
                  order = 20,
                  name = "",
                },

                nameType = {
                  type = 'select',
                  order = 30,
                  name = L["Display Player Name"],
                  desc = L["|cff11a34aNone|r - Disabled\n\n|cff11a34aPlayer Name|r - The name of the player that is affected by the event\n\n|cff11a34aSpell Name|r - The name of the spell that is affecting the player"],
                  width = 'double',
                  style = 'radio',
                  values = {
                    [0] = L["None"],
                    [1] = L["Player Name"],
                    [2] = L["Spell Name"],
                    [3] = L["Both (Player Name - Spell Name)"],
                    [4] = L["Both (Spell Name - Player Name)"]
                  },
                },

              }
            },

            NPC = {
              order = 20,
              type = 'group',
              name = L["Events to a NPC"],
              args = {
                npcNames = {
                  type = 'description',
                  order = 1,
                  name = L["|cff11a34aNPC Name Format Settings|r:"],
                  fontSize = 'large',
                },

                customNameColor = {
                  order = 2,
                  type = 'color',
                  name = L["NPC Name's Color"],
                  get = getNameFormatColor,
                  set = setNameFormatColor,
                },

                npcSpellNames = {
                  type = 'description',
                  order = 10,
                  name = L["\n|cff11a34aSpell Name Format Settings|r:"],
                  fontSize = 'large',
                },

                enableSpellColor = {
                  order = 11,
                  type = 'toggle',
                  name = L["Color Spell Name"],
                  desc = L["The spell name will be colored according to it's spell school."],
                },

                npcNames_Spacer1 = {
                  type = 'description',
                  order = 12,
                  name = "",
                  width = 'normal'
                },

                enableCustomSpellColor = {
                  order = 13,
                  type = 'toggle',
                  name = L["Custom"],
                  desc = L["Preempt an automatic color with a custom one."],
                  width = 'half'
                },

                customSpellColor = {
                  order = 14,
                  type = 'color',
                  name = L["Color"],
                  width = 'half',
                  get = getNameFormatColor,
                  set = setNameFormatColor,
                },

                npcNames_Spacer2 = {
                  type = 'description',
                  order = 20,
                  name = "",
                },

                nameType = {
                  type = 'select',
                  order = 21,
                  name = L["Display NPC Name"],
                  desc = L["|cff11a34aNone|r - Disabled\n\n|cff11a34aNPC's Name|r - The name of the target that is affected by the event\n\n|cff11a34aSpell Name|r - The name of the spell that is affecting the target"],
                  width = 'double',
                  style = 'radio',
                  values = {
                    [0] = L["None"],
                    [1] = L["NPC's Name"],
                    [2] = L["Spell Name"],
                    [3] = L["Both (NPC Name - Spell Name)"],
                    [4] = L["Both (Spell Name - NPC Name)"]
                  },
                },

              },
            },

          }
        },

        specialTweaks = {
          disabled = NoOutgoing,
          order = 60,
          type = 'group',
          name = L["Misc"],
          args = {
            specialTweaks = {
              type = 'description',
              order = 0,
              name = L["|cff11a34aDamage Settings|r:"],
              fontSize = 'large',
            },
            specialTweaks_PlayerDesc = {
              type = 'description',
              order = 1,
              name = L["\n|cff11a34aPlayer Settings|r:"],
              fontSize = 'small',
            },
            enableOutDmg = {
              order = 10,
              type = 'toggle',
              name = L["Show Outgoing Damage"],
              desc = L["Show damage you do."],
              get = get2,
              set = set2,
            },
            enableDotDmg = {
              order = 11,
              type = 'toggle',
              name = L["Show DoTs"],
              desc = L["Show your Damage-Over-Time (DOT) damage. (|cffFF0000Requires:|r Outgoing Damage)"],
              get = get2,
              set = set2,
            },
            enableAutoAttack_Outgoing = {
              order = 12,
              type = 'toggle',
              name = L["Show Auto Attack"],
              desc = L["Show your non-critical, auto attack damage."],
              get = get2,
              set = set2,
            },

            specialTweaks_PetVehicleDesc = {
              type = 'description',
              order = 20,
              name = L["\n|cff11a34aPet and Vehicle Settings|r:"],
              fontSize = 'small',
            },

            enablePetDmg = {
              order = 21,
              type = 'toggle',
              name = L["Show Pet Damage"],
              desc = L["Show your pet's damage. Beast Mastery hunters should also look at vehicle damage."],
              get = get2,
              set = set2,
            },
            enablePetAutoAttack_Outgoing = {
              order = 22,
              type = 'toggle',
              name = L["Pet Auto Attacks"],
              desc = L["Show your pet's non-critical, auto attacks."],
              get = get2,
              set = set2,
            },
            enableKillCommand = {
              order = 23,
              type = 'toggle',
              name = L["Show Kill Command"],
              desc = L["Change the source of |cff11a34aKill Command|r to be the |cffFF8000Player|r. This is helpful when you to turn off |cffFF8000Pet|r damage."],
              get = get2,
              set = set2,
              hidden = function()return x.player.class~='HUNTER'end
            },
            enableVehicleDmg = {
              order = 24,
              type = 'toggle',
              name = L["Show Vehicle Damage"],
              desc = L["Show damage that your vehicle does."],
              get = get2,
              set = set2,
            },

            healingSettings = {
              type = 'description',
              order = 30,
              name = L["\n|cff11a34aHealing Settings|r:"],
              fontSize = 'large',
            },
            enableOutHeal = {
              order = 31,
              type = 'toggle',
              name = L["Show Outgoing Healing"],
              desc = L["Show healing you do."],
              get = get2,
              set = set2,
            },
            enableHots = {
              order = 32,
              type = 'toggle',
              name = L["Show HoTs"],
              desc = L["Show your Heal-Over-Time (HOT) healing. (|cffFF0000Requires:|r Outgoing Healing)"],
              get = get2,
              set = set2,
            },
            enableOutAbsorbs = {
              order = 33,
              type = 'toggle',
              name = L["Show Outgoing Absorbs"],
              desc = L["Show absorbs that you apply."],
              get = get2,
              set = set2,
            },
            enableOverhealing = {
              order = 34,
              type = 'toggle',
              name = L["Show Overhealing"],
              desc = L["Displays overhealing."],
              get = get2,
              set = set2,
              disabled = isFrameItemDisabled,
            },
            enableOverhealingSubtraction  = {
              order = 35,
              type = 'toggle',
              name = L["Subtract Overhealing"],
              desc = L["Subtract the overhealed amount from the Total Amount"],
              get = get2,
              set = set2,
              disabled = function(info)
                return not x.db.profile.frames.outgoing.enabledFrame or
                  not x.db.profile.frames.outgoing.enableOverhealing
              end,
            },

            spacer_Healing1 = {
              type = 'description',
              order = 40,
              name = '',
              fontSize = 'small',
            },
            enableOverhealingFormat = {
              order = 41,
              type = 'toggle',
              name = L["Format Overhealing"],
              desc = L["Splits overhealing into its own section. Example: +43,000 (O: 12,000)"],
              get = get2,
              set = set2,
              disabled = function(info)
                return not x.db.profile.frames.outgoing.enabledFrame or
                  not x.db.profile.frames.outgoing.enableOverhealing
              end,
            },
            overhealingPrefix = {
              order = 45,
              type = 'input',
              name = L["Overhealing Prefix"],
              desc = L["Text placed before the overheal amount.\n\nExample result: +5000 (O: 1200)\nDefault: (O:\n\nColor codes are optional. See warcraft.wiki.gg/wiki/UI_escape_sequences\n\n|cffFF0000Requires:|r |cff11a34aFormat Overhealing|r"],
              get = getTextIn2,
              set = setTextIn2,
              disabled = function(info)
                return not x.db.profile.frames.outgoing.enabledFrame or
                  not x.db.profile.frames.outgoing.enableOverhealing or
                  not x.db.profile.frames.outgoing.enableOverhealingFormat
              end,
            },
            overhealingPostfix = {
              order = 46,
              type = 'input',
              name = L["Overhealing Postfix"],
              desc = L["Text placed after the overheal amount.\n\nExample result: +5000 (O: 1200)\nDefault: )\n\nColor codes are optional. See warcraft.wiki.gg/wiki/UI_escape_sequences\n\n|cffFF0000Requires:|r |cff11a34aFormat Overhealing|r"],
              get = getTextIn2,
              set = setTextIn2,
              disabled = function(info)
                return not x.db.profile.frames.outgoing.enabledFrame or
                  not x.db.profile.frames.outgoing.enableOverhealing or
                  not x.db.profile.frames.outgoing.enableOverhealingFormat
              end,
            },

            missTypeSettings = {
              type = 'description',
              order = 50,
              name = L["\n|cff11a34aMiss Type Settings|r:"],
              fontSize = 'large',
            },
            enableImmunes = {
              order = 51,
              type = 'toggle',
              name = L["Show Immunes"],
              desc = L["Display 'Immune' when your target cannot take damage."],
              get = get2,
              set = set2,
            },
            enableMisses = {
              order = 52,
              type = 'toggle',
              name = L["Show Miss Types"],
              desc = L["Display 'Miss', 'Dodge', 'Parry' when you miss your target."],
              get = get2,
              set = set2,
            },
            enableAbsorbs = {
              order = 53,
              type = 'toggle',
              name = L["Show Absorbs"],
              desc = L["Display 'Absorb' when your target absorbs all damage."],
              get = get2,
              set = set2,
            },
            enablePartialMisses = {
              order = 54,
              type = 'toggle',
              name = L["Show Miss Types (Partials)"],
              desc = L["Show when your target takes only a percentage of your damage because it was partially absorbed, resisted, or blocked.\n\n|cffFF0000PLEASE NOTE:|r Only works if the spell is not merged. Turn off the Spell Merger to see all spells."],
              get = get2,
              set = set2,
            },
            showHighestPartialMiss = {
              order = 55,
              type = 'toggle',
              name = L["Show the Highest Partial Miss"],
              desc = L["Only show the highest partial miss, instead of all the misses. (Rare, but less spammy)\n\n|cffFF0000PLEASE NOTE:|r Only works if the spell is not merged. Turn off the Spell Merger to see all spells."],
              get = get2,
              set = set2,
            },

          },
        },

      },
    },

    critical = {
      name = L["|cffFFFFFFOutgoing|r |cff11a34a(Criticals)|r"],
      type = 'group',
      order = 13,
      childGroups = 'tab',
      args = {


        frameSettings = {
          order = 10,
          type = 'group',
          name = L["Frame"],
          args = {
            foreverNote = ForeverNote(0.5, L["outgoing damage and healing lines are not produced on this client: the combat log is closed to addons, and the attribution that could be guessed from other events is not exact. Blizzard's own numbers over the target still work (Floating Combat Text page). The icon, name and content settings below are disabled."]),
            frameSettings = {
              type = 'description',
              order = 0,
              name = L["|cff11a34aFrame Settings|r:"],
              fontSize = 'large',
            },
            enabledFrame = {
              order = 1,
              type = 'toggle',
              name = L["Enable"],
              width = 'half',
              get = get2,
              set = set2_update,
            },
            secondaryFrame = {
              type = 'select',
              order = 2,
              name = L["Secondary Frame"],
              desc = L["A frame to forward messages to when this frame is disabled."],
              values = {
                [0] = L["None"],
                [1] = L["General"],
                [2] = L["Outgoing"],
                --[3] = L["Outgoing (Criticals)"],
                [4] = L["Incoming (Damage)"],
                [5] = L["Incoming (Healing)"],
                [6] = L["Class Power"],
                [7] = L["Special Effects (Procs)"],
                [8] = L["Loot, Currency & Money"],
              },
              get = get2,
              set = set2,
              disabled = isFrameItemEnabled,
            },
            insertText = {
              type = 'select',
              order = 3,
              name = L["Text Direction"],
              desc = L["Changes the direction that the text travels in the frame."],
              values = {
                ["top"] = L["Down"],
                ["bottom"] = L["Up"],
              },
              get = get2,
              set = set2_update,
              disabled = isFrameItemDisabled,
            },
            alpha = {
              order = 4,
              name = L["Frame Alpha"],
              desc = L["Sets the alpha of the frame."],
              type = 'range',
              min = 0, max = 100, step = 1,
              get = get2,
              set = set2_update,
              disabled = isFrameItemDisabled,
            },
            megaDamage = {
              order = 5,
              type = 'toggle',
              name = L["Number Formatting"],
              desc = L["Enables number formatting. This option can be customized in the main |cff00FF00Frames|r options page to be either |cff11a34aAbbreviation|r or |cff11a34aDecimal Marks|r. "],
              get = get2,
              set = set2,
            },

            frameScrolling = {
              type = 'description',
              order = 10,
              name = L["\n|cff11a34aScrollable Frame Settings|r:"],
              fontSize = 'large',
            },
            enableScrollable = {
              order = 11,
              type = 'toggle',
              name = L["Enabled"],
              get = get2,
              set = set2_update,
              disabled = isFrameItemDisabled,
            },
            scrollableLines = {
              order = 12,
              name = L["Number of Lines"],
              type = 'range',
              min = 10, max = 60, step = 1,
              get = get2,
              set = set2_update,
              disabled = isFrameNotScrollable,
            },
            scrollableInCombat = {
              order = 13,
              type = 'toggle',
              name = L["Disable in Combat"],
              get = get2,
              set = set2_update,
              disabled = isFrameItemDisabled,
            },

            frameFading = {
              type = 'description',
              order = 30,
              name = L["\n|cff11a34aFading Text Settings|r:"],
              fontSize = 'large',
            },
            enableCustomFade = {
              order = 31,
              type = 'toggle',
              name = L["Use Custom Fade"],
              width = 'full',
              get = get2,
              set = set2_update,
              disabled = isFrameItemDisabled,
            },
            enableFade = {
              order = 32,
              type = 'toggle',
              name = L["Enable"],
              desc = L["Turn off to disable fading all together.\n\n|cffFF0000Requires:|r |cff11a34aUse Custom Fade|r"],
              width = 'half',
              get = get2,
              set = set2_update,
              disabled = isFrameUseCustomFade,
            },
            fadeTime = {
              order = 33,
              name = L["Fade Out Duration"],
              desc = L["The duration of the fade out animation. |cff848482(Default: |cff11a34a0.3|r)|r\n\n|cffFF0000Requires:|r |cff11a34aUse Custom Fade|r"],
              type = 'range',
              min = 0, max = 2, step = .1,
              get = get2,
              set = set2_update,
              disabled = isFrameFadingDisabled,
            },
            visibilityTime = {
              order = 34,
              name = L["Visibility Duration"],
              desc = L["The duration that the text is shown in the frame. |cff848482(Default: |cff11a34a5|r)|r\n\n|cffFF0000Requires:|r |cff11a34aUse Custom Fade|r"],
              type = 'range',
              min = 2, max = 15, step = 1,
              get = get2,
              set = set2_update,
              disabled = isFrameFadingDisabled,
            },

            stickyCrits = {
              type = 'description',
              order = 40,
              name = L["\n|cff11a34aSticky Crits|r:"],
              fontSize = 'large',
            },
            enableStickyMode = {
              order = 41,
              type = 'toggle',
              name = L["Enable Sticky Crits"],
              desc = L["Keep critical hits visible on screen longer than normal messages for extra emphasis."],
              get = get2,
              set = set2_update,
              disabled = isFrameItemDisabled,
            },
            stickyDuration = {
              order = 42,
              name = L["Extra Duration"],
              desc = L["Additional seconds to keep critical hits on screen beyond the normal visibility time. |cff848482(Default: |cff11a34a3|r)|r\n\n|cffFF0000Requires:|r |cff11a34aEnable Sticky Crits|r"],
              type = 'range',
              min = 1, max = 10, step = 1,
              get = get2,
              set = set2_update,
              disabled = function(info)
                return not x.db.profile.frames.critical.enabledFrame or
                  not x.db.profile.frames.critical.enableStickyMode
              end,
            },
          },
        },

        fonts = {
          order = 20,
          type = 'group',
          name = L["Font"],
          args = {
            fontSettings = {
              type = 'description',
              order = 0,
              name = L["|cff11a34aFont Settings|r:"],
              fontSize = 'large',
            },
            font = {
              type = 'select', dialogControl = 'LSM30_Font',
              order = 1,
              name = L["Font"],
              desc = L["Set the font of the frame."],
              values = AceGUIWidgetLSMlists.font,
              get = get2,
              set = set2_update,
              disabled = isFrameItemDisabled,
            },
            fontSize = {
              order = 2,
              name = L["Font Size"],
              desc = L["Set the font size of the frame."],
              type = 'range',
              min = 6, max = 64, step = 1,
              get = get2,
              set = set2_update,
              disabled = isFrameItemDisabled,
            },
            fontOutline = {
              type = 'select',
              order = 3,
              name = L["Font Outline"],
              desc = L["Set the font outline."],
              values = {
                ['1NONE'] = L["None"],
                ['2OUTLINE'] = L['OUTLINE'],
                -- BUG: Setting font to monochrome AND above size 16 will crash WoW
                -- http://us.battle.net/wow/en/forum/topic/6470967362
                ['3MONOCHROME'] = L['MONOCHROME'],
                ['4MONOCHROMEOUTLINE'] = L['MONOCHROMEOUTLINE'],
                ['5THICKOUTLINE'] = L['THICKOUTLINE'],
              },
              get = get2,
              set = set2_update,
              disabled = isFrameItemDisabled,
            },
            fontJustify = {
              type = 'select',
              order = 4,
              name = L["Justification"],
              desc = L["Justifies the output to a side."],
              values = {
                ['RIGHT']  = L["Right"],
                ['LEFT']   = L["Left"],
                ['CENTER'] = L["Center"],
              },
              get = get2,
              set = set2_update,
            },

            fontShadowSettings = {
              type = 'description',
              order = 10,
              name = L["\n|cff11a34aFont Shadow Settings|r:"],
              fontSize = 'large',
            },

            enableFontShadow = {
              order = 11,
              type = 'toggle',
              name = L["Enable Font Shadow"],
              desc = L["Shows a shadow behind the combat text fonts."],
              get = get2,
              set = set2_update,
              disabled = isFrameItemDisabled,
            },

            fontShadowColor = {
              order = 12,
              type = 'color',
              hasAlpha = true,
              name = L["Font Shadow Color"],
              get = getColor2,
              set = setColor2_alpha,
              disabled = isFrameFontShadowDisabled,
            },

            fontShadowOffsetX = {
              order = 13,
              name = L["Horizonal Offset"],
              type = 'range',
              min = -10, max = 10, step = 1,
              get = get2,
              set = set2_update,
              disabled = isFrameFontShadowDisabled,
            },

            fontShadowOffsetY = {
              order = 14,
              name = L["Vertical Offset"],
              type = 'range',
              min = -10, max = 10, step = 1,
              get = get2,
              set = set2_update,
              disabled = isFrameFontShadowDisabled,
            },
          },
        },

        icons = {
          disabled = NoOutgoing,
          order = 30,
          type = 'group',
          name = L["Icons"],
          args = {
            iconSizeSettings = {
              type = 'description',
              order = 1,
              name = L["|cff11a34aIcon Settings|r:"],
              fontSize = 'large',
            },
            iconsEnabled = {
              order = 2,
              type = 'toggle',
              name = L["Enable Icons"],
              desc = L["Show icons next to your damage."],
              get = get2,
              set = set2,
              disabled = isFrameItemDisabled,
            },
            iconsSize = {
              order = 3,
              name = L["Size"],
              desc = L["Set the icon size. (Recommended value: 16)"],
              type = 'range',
              min = 6, max = 22, step = 1,
              get = get2,
              set = set2,
              disabled = isFrameIconDisabled,
            },
            spacerIconsEnabled = {
              order = 4,
              type = 'toggle',
              name = L["Show Invisible Icons"],
              desc = L["When icons are disabled, you can still enable invisible icons to line up text."],
              get = get2,
              set = set2,
              disabled = isFrameIconSpacerDisabled,
            },
          }
        },

        fontColors = {
          order = 40,
          type = 'group',
          name = L["Colors"],
          args = {
            customColors_label = {
              type = 'description',
              order = 0,
              name = L["|cff11a34aCustom Colors|r:"],
              fontSize = 'large',
            },

            customColors_OverrideDesc = {
              type = 'description',
              order = 1,
              name = L["\n|cff11a34aOverride All Frame Color Settings|r:"],
              fontSize = 'small',
            },

            customColor = {
              order = 2,
              type = 'toggle',
              name = L["All Text One Color (Override Color Settings)"],
              width = 'double',
              desc = L["Change all the text in this frame to a specific color."],
              get = get2,
              set = set2,
            },

            fontColor = {
              order = 3,
              type = 'color',
              name = L["Color"],
              get = getColor2,
              set = setColor2,
              hidden = isFrameCustomColorDisabled,
            },

            customColors_Desc = {
              type = 'description',
              order = 4,
              name = L["\n|cff11a34aOther Color Settings|r:"],
              fontSize = 'small',
            },
          },
        },

        names = {
          disabled = NoOutgoing,
          order = 50,
          type = 'group',
          name = L["Names"],
          childGroups = 'select',
          get = getNameFormat,
          set = setNameFormat,
          args = {
            namesDescription = {
              type = 'description',
              order = 1,
              name = L["The |cff11a34aNames Settings|r allows you to further format and customize your combat text frames. By selecting values from below, you will be able to see the source, destination or spell names of certain events.\n\n|cffFF8040NOTE:|r The |cff11a34aSpam Merger|r will preempt formatting."],
              fontSize = 'small'
            },

            nameAppearance = {
              type = 'description',
              order = 2,
              name = L["|cff11a34aName Appearance|r:\n\n"],
              fontSize = 'large',
              width = 'normal'
            },

            namePrefix = {
              order = 3,
              type = 'input',
              name = L["Prefix"],
              desc = L["Prefix this value to the beginning when displaying the name."],
              get = getNameFormatText,
              set = setNameFormatText,
            },

            namePostfix = {
              order = 4,
              type = 'input',
              name = L["Postfix"],
              desc = L["Postfix this value to the end when displaying the name."],
              get = getNameFormatText,
              set = setNameFormatText,
            },

            PLAYER = {
              order = 10,
              type = 'group',
              name = L["Events to a Player"],
              args = {
                playerNames = {
                  type = 'description',
                  order = 1,
                  name = L["|cff11a34aPlayer Name Format Settings|r:"],
                  fontSize = 'large',
                },

                enableNameColor = {
                  order = 2,
                  type = 'toggle',
                  name = L["Color Player Name"],
                  desc = L["If the player's class is known (e.g. is a raid member), it will be colored."],
                },

                removeRealmName = {
                  order = 3,
                  type = 'toggle',
                  name = L["Remove Realm Name"],
                  desc = L["If the player has a realm name attatched to her name, it will be removed."],
                },

                enableCustomNameColor = {
                  order = 4,
                  type = 'toggle',
                  name = L["Custom"],
                  desc = L["Preempt an automatic color with a custom one."],
                  width = 'half',
                },

                customNameColor = {
                  order = 5,
                  type = 'color',
                  name = L["Color"],
                  get = getNameFormatColor,
                  set = setNameFormatColor,
                  width = 'half',
                },

                playerSpellNames = {
                  type = 'description',
                  order = 10,
                  name = L["\n|cff11a34aSpell Name Format Settings|r:"],
                  fontSize = 'large',
                },

                enableSpellColor = {
                  order = 11,
                  type = 'toggle',
                  name = L["Color Spell Name"],
                  desc = L["The spell name will be colored according to it's spell school."],
                },

                playerNames_Spacer1 = {
                  type = 'description',
                  order = 12,
                  name = "",
                  width = 'normal'
                },

                enableCustomSpellColor = {
                  order = 13,
                  type = 'toggle',
                  name = L["Custom"],
                  desc = L["Preempt an automatic color with a custom one."],
                  width = 'half'
                },

                customSpellColor = {
                  order = 14,
                  type = 'color',
                  name = L["Color"],
                  width = 'half',
                  get = getNameFormatColor,
                  set = setNameFormatColor,
                },

                playerNames_Spacer2 = {
                  type = 'description',
                  order = 20,
                  name = "",
                },

                nameType = {
                  type = 'select',
                  order = 30,
                  name = L["Display Player Name"],
                  desc = "",
                  width = 'double',
                  style = 'radio',
                  values = {
                    [0] = L["None"],
                    [1] = L["Player Name"],
                    [2] = L["Spell Name"],
                    [3] = L["Both (Player Name - Spell Name)"],
                    [4] = L["Both (Spell Name - Player Name)"]
                  },
                },

              }
            },

            NPC = {
              order = 20,
              type = 'group',
              name = L["Events to a NPC"],
              args = {
                npcNames = {
                  type = 'description',
                  order = 1,
                  name = L["|cff11a34aNPC Name Format Settings|r:"],
                  fontSize = 'large',
                },

                customNameColor = {
                  order = 2,
                  type = 'color',
                  name = L["NPC Name's Color"],
                  get = getNameFormatColor,
                  set = setNameFormatColor,
                },

                npcSpellNames = {
                  type = 'description',
                  order = 10,
                  name = L["\n|cff11a34aSpell Name Format Settings|r:"],
                  fontSize = 'large',
                },

                enableSpellColor = {
                  order = 11,
                  type = 'toggle',
                  name = L["Color Spell Name"],
                  desc = L["The spell name will be colored according to it's spell school."],
                },

                npcNames_Spacer1 = {
                  type = 'description',
                  order = 12,
                  name = "",
                  width = 'normal'
                },

                enableCustomSpellColor = {
                  order = 13,
                  type = 'toggle',
                  name = L["Custom"],
                  desc = L["Preempt an automatic color with a custom one."],
                  width = 'half'
                },

                customSpellColor = {
                  order = 14,
                  type = 'color',
                  name = L["Color"],
                  width = 'half',
                  get = getNameFormatColor,
                  set = setNameFormatColor,
                },

                npcNames_Spacer2 = {
                  type = 'description',
                  order = 20,
                  name = "",
                },

                nameType = {
                  type = 'select',
                  order = 21,
                  name = L["Display NPC Name"],
                  desc = "",
                  width = 'double',
                  style = 'radio',
                  values = {
                    [0] = L["None"],
                    [1] = L["NPC's Name"],
                    [2] = L["Spell Name"],
                    [3] = L["Both (NPC Name - Spell Name)"],
                    [4] = L["Both (Spell Name - NPC Name)"]
                  },
                },

              },
            },

          }
        },

        specialTweaks = {
          disabled = NoOutgoing,
          order = 60,
          type = 'group',
          name = L["Misc"],
          args = {
            specialTweaks = {
              type = 'description',
              order = 0,
              name = L["|cff11a34aMiscellaneous Settings|r:"],
              fontSize = 'large',
            },
            enableAutoAttack_Critical = {
              order = 1,
              type = 'toggle',
              name = L["Show Auto Attacks"],
              desc = L["Show criticals from Auto Attack and Swings. If disabled, they will be displayed as non-critical auto attacks. They will be merged into the Outgoing frame."],
              get = get2,
              set = set2,
            },
            prefixAutoAttack_Critical = {
              order = 2,
              type = 'toggle',
              name = L["Show Auto Attacks (Pre)Postfix"],
              desc = L["Make Auto Attack and Swing criticals more visible by adding the prefix and postfix."],
              get = get2,
              set = set2,
            },
            petCrits = {
              order = 3,
              type = 'toggle',
              name = L["Allow Pet Crits"],
              desc = L["Enable this to see when your pet's abilities critical strike, otherwise disable for less combat text spam."],
              get = get2,
              set = set2,
            },

            criticalAppearance = {
              type = 'description',
              order = 10,
              name = L["\n|cff11a34aCritical Appearance|r:"],
              fontSize = 'large',
            },
            critPrefix = {
              order = 11,
              type = 'input',
              name = L["Prefix"],
              desc = L["Prefix this value to the beginning when displaying a critical amount."],
              get = getTextIn2,
              set = setTextIn2,
              --disabled = isFrameItemDisabled,
            },
            critPostfix = {
              order = 12,
              type = 'input',
              name = L["Postfix"],
              desc = L["Postfix this value to the end when displaying a critical amount."],
              get = getTextIn2,
              set = setTextIn2,
              --disabled = isFrameItemDisabled,
            },
            critPostPreReset = {
              order = 13,
              type = 'execute',
              name = L["Reset"],
              desc = L["Reset Prefix and Postfix to their default setting."],
              func = function()
                  local critical = x.db.profile.frames.critical
                  critical.critPrefix = "|cffFF0000*|r"
                  critical.critPostfix = "|cffFF0000*|r"
                end,
              width = 'half',
              disabled = function()
                  local critical = x.db.profile.frames.critical
                  return critical.critPrefix == "|cffFF0000*|r" and critical.critPostfix == "|cffFF0000*|r"
                end,
            },
          },

        },
      },
    },

    damage = {
      name = L["|cffFFFFFFIncoming|r |cff11a34a(Damage)|r"],
      type = 'group',
      order = 14,
      childGroups = 'tab',
      args = {

        frameSettings = {
          order = 10,
          type = 'group',
          name = L["Frame"],
          args = {
            frameSettings = {
              type = 'description',
              order = 0,
              name = L["|cff11a34aFrame Settings|r:"],
              fontSize = 'large',
            },
            enabledFrame = {
              order = 1,
              type = 'toggle',
              name = L["Enable"],
              width = 'half',
              get = get2,
              set = set2_update,
            },
            secondaryFrame = {
              type = 'select',
              order = 2,
              name = L["Secondary Frame"],
              desc = L["A frame to forward messages to when this frame is disabled."],
              values = {
                [0] = L["None"],
                [1] = L["General"],
                [2] = L["Outgoing"],
                [3] = L["Outgoing (Criticals)"],
                --[4] = L["Incoming (Damage)"],
                [5] = L["Incoming (Healing)"],
                [6] = L["Class Power"],
                [7] = L["Special Effects (Procs)"],
                [8] = L["Loot, Currency & Money"],
              },
              get = get2,
              set = set2,
              disabled = isFrameItemEnabled,
            },
            insertText = {
              type = 'select',
              order = 3,
              name = L["Text Direction"],
              desc = L["Changes the direction that the text travels in the frame."],
              values = {
                ["top"] = L["Down"],
                ["bottom"] = L["Up"],
              },
              get = get2,
              set = set2_update,
              disabled = isFrameItemDisabled,
            },
            alpha = {
              order = 4,
              name = L["Frame Alpha"],
              desc = L["Sets the alpha of the frame."],
              type = 'range',
              min = 0, max = 100, step = 1,
              get = get2,
              set = set2_update,
              disabled = isFrameItemDisabled,
            },
            megaDamage = {
              order = 5,
              type = 'toggle',
              name = L["Number Formatting"],
              desc = L["Enables number formatting. This option can be customized in the main |cff00FF00Frames|r options page to be either |cff11a34aAbbreviation|r or |cff11a34aDecimal Marks|r. "],
              get = get2,
              set = set2,
            },

            frameScrolling = {
              type = 'description',
              order = 10,
              name = L["\n|cff11a34aScrollable Frame Settings|r:"],
              fontSize = 'large',
            },
            enableScrollable = {
              order = 11,
              type = 'toggle',
              name = L["Enabled"],
              get = get2,
              set = set2_update,
              disabled = isFrameItemDisabled,
            },
            scrollableLines = {
              order = 12,
              name = L["Number of Lines"],
              type = 'range',
              min = 10, max = 60, step = 1,
              get = get2,
              set = set2_update,
              disabled = isFrameNotScrollable,
            },
            scrollableInCombat = {
              order = 13,
              type = 'toggle',
              name = L["Disable in Combat"],
              get = get2,
              set = set2_update,
              disabled = isFrameItemDisabled,
            },

            frameFading = {
              type = 'description',
              order = 20,
              name = L["\n|cff11a34aFading Text Settings|r:"],
              fontSize = 'large',
            },
            enableCustomFade = {
              order = 21,
              type = 'toggle',
              name = L["Use Custom Fade"],
              width = 'full',
              get = get2,
              set = set2_update,
              disabled = isFrameItemDisabled,
            },
            enableFade = {
              order = 22,
              type = 'toggle',
              name = L["Enable"],
              desc = L["Turn off to disable fading all together.\n\n|cffFF0000Requires:|r |cff11a34aUse Custom Fade|r"],
              width = 'half',
              get = get2,
              set = set2_update,
              disabled = isFrameUseCustomFade,
            },
            fadeTime = {
              order = 23,
              name = L["Fade Out Duration"],
              desc = L["The duration of the fade out animation. |cff848482(Default: |cff11a34a0.3|r)|r\n\n|cffFF0000Requires:|r |cff11a34aUse Custom Fade|r"],
              type = 'range',
              min = 0, max = 2, step = .1,
              get = get2,
              set = set2_update,
              disabled = isFrameFadingDisabled,
            },
            visibilityTime = {
              order = 24,
              name = L["Visibility Duration"],
              desc = L["The duration that the text is shown in the frame. |cff848482(Default: |cff11a34a5|r)|r\n\n|cffFF0000Requires:|r |cff11a34aUse Custom Fade|r"],
              type = 'range',
              min = 2, max = 15, step = 1,
              get = get2,
              set = set2_update,
              disabled = isFrameFadingDisabled,
            },

          },
        },

        fonts = {
          order = 20,
          type = 'group',
          name = L["Font"],
          args = {
            fontSettings = {
              type = 'description',
              order = 0,
              name = L["|cff11a34aFont Settings|r:"],
              fontSize = 'large',
            },
            font = {
              type = 'select', dialogControl = 'LSM30_Font',
              order = 1,
              name = L["Font"],
              desc = L["Set the font of the frame."],
              values = AceGUIWidgetLSMlists.font,
              get = get2,
              set = set2_update,
              disabled = isFrameItemDisabled,
            },
            fontSize = {
              order = 2,
              name = L["Font Size"],
              desc = L["Set the font size of the frame."],
              type = 'range',
              min = 6, max = 64, step = 1,
              get = get2,
              set = set2_update,
              disabled = isFrameItemDisabled,
            },
            fontOutline = {
              type = 'select',
              order = 3,
              name = L["Font Outline"],
              desc = L["Set the font outline."],
              values = {
                ['1NONE'] = L["None"],
                ['2OUTLINE'] = L['OUTLINE'],
                -- BUG: Setting font to monochrome AND above size 16 will crash WoW
                -- http://us.battle.net/wow/en/forum/topic/6470967362
                ['3MONOCHROME'] = L['MONOCHROME'],
                ['4MONOCHROMEOUTLINE'] = L['MONOCHROMEOUTLINE'],
                ['5THICKOUTLINE'] = L['THICKOUTLINE'],
              },
              get = get2,
              set = set2_update,
              disabled = isFrameItemDisabled,
            },
            fontJustify = {
              type = 'select',
              order = 4,
              name = L["Justification"],
              desc = L["Justifies the output to a side."],
              values = {
                ['RIGHT']  = L["Right"],
                ['LEFT']   = L["Left"],
                ['CENTER'] = L["Center"],
              },
              get = get2,
              set = set2_update,
            },

            fontShadowSettings = {
              type = 'description',
              order = 10,
              name = L["\n|cff11a34aFont Shadow Settings|r:"],
              fontSize = 'large',
            },

            enableFontShadow = {
              order = 11,
              type = 'toggle',
              name = L["Enable Font Shadow"],
              desc = L["Shows a shadow behind the combat text fonts."],
              get = get2,
              set = set2_update,
              disabled = isFrameItemDisabled,
            },

            fontShadowColor = {
              order = 12,
              type = 'color',
              hasAlpha = true,
              name = L["Font Shadow Color"],
              get = getColor2,
              set = setColor2_alpha,
              disabled = isFrameFontShadowDisabled,
            },

            fontShadowOffsetX = {
              order = 13,
              name = L["Horizonal Offset"],
              type = 'range',
              min = -10, max = 10, step = 1,
              get = get2,
              set = set2_update,
              disabled = isFrameFontShadowDisabled,
            },

            fontShadowOffsetY = {
              order = 14,
              name = L["Vertical Offset"],
              type = 'range',
              min = -10, max = 10, step = 1,
              get = get2,
              set = set2_update,
              disabled = isFrameFontShadowDisabled,
            },
          },
        },

        icons = {
          disabled = OnEventSources,
          order = 30,
          type = 'group',
          name = L["Icons"],
          args = {
            foreverNote = ForeverNote(0.5, L["incoming damage carries no spell on this client, so there is nothing to draw an icon for."]),
            iconSizeSettings = {
              type = 'description',
              order = 1,
              name = L["|cff11a34aIcon Settings|r:"],
              fontSize = 'large',
            },
            iconsEnabled = {
              order = 2,
              type = 'toggle',
              name = L["Enable Icons"],
              desc = L["Show icons next to your damage."],
              get = get2,
              set = set2,
              disabled = isFrameItemDisabled,
            },
            iconsSize = {
              order = 3,
              name = L["Size"],
              desc = L["Set the icon size. (Recommended value: 16)"],
              type = 'range',
              min = 6, max = 22, step = 1,
              get = get2,
              set = set2,
              disabled = isFrameIconDisabled,
            },
            spacerIconsEnabled = {
              order = 4,
              type = 'toggle',
              name = L["Show Invisible Icons"],
              desc = L["When icons are disabled, you can still enable invisible icons to line up text."],
              get = get2,
              set = set2,
              disabled = isFrameIconSpacerDisabled,
            },

            iconAdditionalSettings = {
              type = 'description',
              order = 10,
              name = L["\n|cff11a34aAdditional Settings|r:"],
              fontSize = 'large',
            },
            iconsEnabledAutoAttack = {
              order = 11,
              type = 'toggle',
              name = L["Auto Attack"],
              desc = L["Show icons from Auto Attacks."],
              get = get2,
              set = set2,
              disabled = isFrameItemDisabled,
            },
          }
        },

        fontColors = {
          order = 40,
          type = 'group',
          name = L["Colors"],
          args = {
            customColors_label = {
              type = 'description',
              order = 0,
              name = L["|cff11a34aCustom Colors|r:"],
              fontSize = 'large',
            },

            customColors_OverrideDesc = {
              type = 'description',
              order = 1,
              name = L["\n|cff11a34aOverride All Frame Color Settings|r:"],
              fontSize = 'small',
            },

            customColor = {
              order = 2,
              type = 'toggle',
              name = L["All Text One Color (Override Color Settings)"],
              width = 'double',
              desc = L["Change all the text in this frame to a specific color."],
              get = get2,
              set = set2,
            },

            fontColor = {
              order = 3,
              type = 'color',
              name = L["Color"],
              get = getColor2,
              set = setColor2,
              hidden = isFrameCustomColorDisabled,
            },

            customColors_Desc = {
              type = 'description',
              order = 4,
              name = L["\n|cff11a34aOther Color Settings|r:"],
              fontSize = 'small',
            },
          },
        },

        names = {
          disabled = OnEventSources,
          order = 50,
          type = 'group',
          name = L["Names"],
          childGroups = 'select',
          get = getNameFormat,
          set = setNameFormat,
          args = {
            foreverNote = ForeverNote(0.5, L["incoming damage carries no attacker or spell name on this client."]),
            namesDescription = {
              type = 'description',
              order = 1,
              name = L["The |cff11a34aNames Settings|r allows you to further format and customize your combat text frames. By selecting values from below, you will be able to see the source, destination or spell names of certain events.\n\n|cffFF8040NOTE:|r The |cff11a34aSpam Merger|r will preempt formatting."],
              fontSize = 'small'
            },

            nameAppearance = {
              type = 'description',
              order = 2,
              name = L["|cff11a34aName Appearance|r:\n\n"],
              fontSize = 'large',
              width = 'normal'
            },

            namePrefix = {
              order = 3,
              type = 'input',
              name = L["Prefix"],
              desc = L["Prefix this value to the beginning when displaying the name."],
              get = getNameFormatText,
              set = setNameFormatText,
            },

            namePostfix = {
              order = 4,
              type = 'input',
              name = L["Postfix"],
              desc = L["Postfix this value to the end when displaying the name."],
              get = getNameFormatText,
              set = setNameFormatText,
            },

            PLAYER = {
              order = 10,
              type = 'group',
              name = L["Events from a Player"],
              args = {
                playerNames = {
                  type = 'description',
                  order = 1,
                  name = L["|cff11a34aPlayer Name Format Settings|r:"],
                  fontSize = 'large',
                },

                enableNameColor = {
                  order = 2,
                  type = 'toggle',
                  name = L["Color Player Name"],
                  desc = L["If the player's class is known (e.g. is a raid member), it will be colored."],
                },

                removeRealmName = {
                  order = 3,
                  type = 'toggle',
                  name = L["Remove Realm Name"],
                  desc = L["If the player has a realm name attatched to her name, it will be removed."],
                },

                enableCustomNameColor = {
                  order = 4,
                  type = 'toggle',
                  name = L["Custom"],
                  desc = L["Preempt an automatic color with a custom one."],
                  width = 'half',
                },

                customNameColor = {
                  order = 5,
                  type = 'color',
                  name = L["Color"],
                  get = getNameFormatColor,
                  set = setNameFormatColor,
                  width = 'half',
                },

                playerSpellNames = {
                  type = 'description',
                  order = 10,
                  name = L["\n|cff11a34aSpell Name Format Settings|r:"],
                  fontSize = 'large',
                },

                enableSpellColor = {
                  order = 11,
                  type = 'toggle',
                  name = L["Color Spell Name"],
                  desc = L["The spell name will be colored according to it's spell school."],
                },

                playerNames_Spacer1 = {
                  type = 'description',
                  order = 12,
                  name = "",
                  width = 'normal'
                },

                enableCustomSpellColor = {
                  order = 13,
                  type = 'toggle',
                  name = L["Custom"],
                  desc = L["Preempt an automatic color with a custom one."],
                  width = 'half'
                },

                customSpellColor = {
                  order = 14,
                  type = 'color',
                  name = L["Color"],
                  width = 'half',
                  get = getNameFormatColor,
                  set = setNameFormatColor,
                },

                playerNames_Spacer2 = {
                  type = 'description',
                  order = 20,
                  name = "",
                },

                nameType = {
                  type = 'select',
                  order = 30,
                  name = L["Display Player Name"],
                  desc = "",
                  width = 'double',
                  style = 'radio',
                  values = {
                    [0] = L["None"],
                    [1] = L["Player Name"],
                    [2] = L["Spell Name"],
                    [3] = L["Both (Player Name - Spell Name)"],
                    [4] = L["Both (Spell Name - Player Name)"]
                  },
                },

              }
            },

            NPC = {
              order = 20,
              type = 'group',
              name = L["Events from a NPC"],
              args = {
                npcNames = {
                  type = 'description',
                  order = 1,
                  name = L["|cff11a34aNPC Name Format Settings|r:"],
                  fontSize = 'large',
                },

                customNameColor = {
                  order = 2,
                  type = 'color',
                  name = L["NPC Name's Color"],
                  get = getNameFormatColor,
                  set = setNameFormatColor,
                },

                npcSpellNames = {
                  type = 'description',
                  order = 10,
                  name = L["\n|cff11a34aSpell Name Format Settings|r:"],
                  fontSize = 'large',
                },

                enableSpellColor = {
                  order = 11,
                  type = 'toggle',
                  name = L["Color Spell Name"],
                  desc = L["The spell name will be colored according to it's spell school."],
                },

                npcNames_Spacer1 = {
                  type = 'description',
                  order = 12,
                  name = "",
                  width = 'normal'
                },

                enableCustomSpellColor = {
                  order = 13,
                  type = 'toggle',
                  name = L["Custom"],
                  desc = L["Preempt an automatic color with a custom one."],
                  width = 'half'
                },

                customSpellColor = {
                  order = 14,
                  type = 'color',
                  name = L["Color"],
                  width = 'half',
                  get = getNameFormatColor,
                  set = setNameFormatColor,
                },

                npcNames_Spacer2 = {
                  type = 'description',
                  order = 20,
                  name = "",
                },

                nameType = {
                  type = 'select',
                  order = 21,
                  name = L["Display NPC Name"],
                  desc = "",
                  width = 'double',
                  style = 'radio',
                  values = {
                    [0] = L["None"],
                    [1] = L["NPC's Name"],
                    [2] = L["Spell Name"],
                    [3] = L["Both (NPC Name - Spell Name)"],
                    [4] = L["Both (Spell Name - NPC Name)"]
                  },
                },

              },
            },

            ENVIRONMENT = {
              order = 30,
              type = 'group',
              name = L["Events from the Environment"],
              args = {
                environmentNames = {
                  type = 'description',
                  order = 1,
                  name = L["|cff11a34a\"Environment\" Format Settings|r:"],
                  fontSize = 'large',
                },

                enableNameColor = {
                  order = 2,
                  type = 'toggle',
                  name = L["Color \"Environment\""],
                  desc = L["The name will be colored according to it's environmental type."],
                },

                environmentNames_Spacer1 = {
                  type = 'description',
                  order = 3,
                  name = "",
                  width = 'normal',
                },

                enableCustomNameColor = {
                  order = 4,
                  type = 'toggle',
                  name = L["Custom"],
                  width = 'half',
                },

                customNameColor = {
                  order = 5,
                  type = 'color',
                  name = L["Color"],
                  width = 'half',
                  get = getNameFormatColor,
                  set = setNameFormatColor,
                },

                environmentSpellNames = {
                  type = 'description',
                  order = 10,
                  name = L["\n|cff11a34aSpell Name Format Settings|r:"],
                  fontSize = 'large',
                },

                enableSpellColor = {
                  order = 11,
                  type = 'toggle',
                  name = L["Color Type"],
                  desc = L["The type will be colored according to it's environmental type."],
                },

                environmentNames_Spacer2 = {
                  type = 'description',
                  order = 12,
                  name = "",
                  width = 'normal',
                },

                enableCustomSpellColor = {
                  order = 13,
                  type = 'toggle',
                  name = L["Custom"],
                  width = 'half',
                },

                customSpellColor = {
                  order = 14,
                  type = 'color',
                  name = L["Color"],
                  width = 'half',
                  get = getNameFormatColor,
                  set = setNameFormatColor,
                },

                environmentNames_Spacer3 = {
                  type = 'description',
                  order = 20,
                  name = "",
                },

                nameType = {
                  type = 'select',
                  order = 21,
                  name = L["Display Environment Name"],
                  desc = L["Environment Damage Types:"]..
                    "\n|cffFFFF00"..ACTION_ENVIRONMENTAL_DAMAGE_DROWNING.."|r,"..
                    " |cffFFFF00"..ACTION_ENVIRONMENTAL_DAMAGE_FALLING.."|r,"..
                    " |cffFFFF00"..ACTION_ENVIRONMENTAL_DAMAGE_FATIGUE.."|r,"..
                    "\n|cffFF8000"..ACTION_ENVIRONMENTAL_DAMAGE_FIRE.."|r,"..
                    " |cffFF8000"..ACTION_ENVIRONMENTAL_DAMAGE_LAVA.."|r,"..
                    " |cff4DFF4D"..ACTION_ENVIRONMENTAL_DAMAGE_SLIME.."|r",
                  width = 'double',
                  style = 'radio',
                  values = {
                    [0] = L["None"],
                    [1] = L["\"Environment\""],
                    [2] = L["Environmental Damage Type"],
                    [3] = L["Both (\"Environment\" - Type)"],
                    [4] = L["Both (Type - \"Environment\")"]
                  },
                },
              },
            },




          }
        },

        specialTweaks = {
          order = 60,
          name = L["Misc"],
          type = 'group',
          args = {
            foreverNote = ForeverNote(0.5, L["a reduced hit shows the reduction type without the amount taken off; a fully absorbed, blocked or resisted hit shows as a miss type."]),
            specialTweaks = {
              type = 'description',
              order = 0,
              name = L["|cff11a34aMiscellaneous Settings|r:"],
              fontSize = 'large',
            },
            showDodgeParryMiss = {
              order = 1,
              type = 'toggle',
              name = L["Show Miss Types"],
              desc = L["Displays Dodge, Parry, or Miss when you miss incoming damage."],
              get = get2,
              set = set2,
            },
            showDamageReduction = {
              order = 2,
              type = 'toggle',
              name = L["Show Reductions"],
              desc = L["Formats incoming damage to show how much was absorbed."],
              get = get2,
              set = set2,
            },

            criticalAppearance = {
              type = 'description',
              order = 10,
              name = L["\n|cff11a34aCritical Appearance|r:"],
              fontSize = 'large',
            },
            critPrefix = {
              order = 11,
              type = 'input',
              name = L["Prefix"],
              desc = L["Prefix this value to the beginning when displaying a critical amount."],
              get = getTextIn2,
              set = setTextIn2,
              disabled = isFrameItemDisabled,
            },
            critPostfix = {
              order = 12,
              type = 'input',
              name = L["Postfix"],
              desc = L["Postfix this value to the end when displaying a critical amount."],
              get = getTextIn2,
              set = setTextIn2,
              disabled = isFrameItemDisabled,
            },
          },
        },
      },
    },

    healing = {
      name = L["|cffFFFFFFIncoming|r |cff11a34a(Healing)|r"],
      type = 'group',
      order = 15,
      childGroups = 'tab',
      args = {

        frameSettings = {
          order = 10,
          type = 'group',
          name = L["Frame"],
          args = {
            frameSettings = {
              type = 'description',
              order = 0,
              name = L["|cff11a34aFrame Settings|r:"],
              fontSize = 'large',
            },
            enabledFrame = {
              order = 1,
              type = 'toggle',
              name = L["Enable"],
              width = 'half',
              get = get2,
              set = set2_update,
            },
            secondaryFrame = {
              type = 'select',
              order = 2,
              name = L["Secondary Frame"],
              desc = L["A frame to forward messages to when this frame is disabled."],
              values = {
                [0] = L["None"],
                [1] = L["General"],
                [2] = L["Outgoing"],
                [3] = L["Outgoing (Criticals)"],
                [4] = L["Incoming (Damage)"],
                --[5] = L["Incoming (Healing)"],
                [6] = L["Class Power"],
                [7] = L["Special Effects (Procs)"],
                [8] = L["Loot, Currency & Money"],
              },
              get = get2,
              set = set2,
              disabled = isFrameItemEnabled,
            },
            insertText = {
              type = 'select',
              order = 3,
              name = L["Text Direction"],
              desc = L["Changes the direction that the text travels in the frame."],
              values = {
                ["top"] = L["Down"],
                ["bottom"] = L["Up"],
              },
              get = get2,
              set = set2_update,
              disabled = isFrameItemDisabled,
            },
            alpha = {
              order = 4,
              name = L["Frame Alpha"],
              desc = L["Sets the alpha of the frame."],
              type = 'range',
              min = 0, max = 100, step = 1,
              get = get2,
              set = set2_update,
              disabled = isFrameItemDisabled,
            },
            megaDamage = {
              order = 5,
              type = 'toggle',
              name = L["Number Formatting"],
              desc = L["Enables number formatting. This option can be customized in the main |cff00FF00Frames|r options page to be either |cff11a34aAbbreviation|r or |cff11a34aDecimal Marks|r. "],
              get = get2,
              set = set2,
            },

            frameScrolling = {
              type = 'description',
              order = 10,
              name = L["\n|cff11a34aScrollable Frame Settings|r:"],
              fontSize = 'large',
            },
            enableScrollable = {
              order = 11,
              type = 'toggle',
              name = L["Enabled"],
              get = get2,
              set = set2_update,
              disabled = isFrameItemDisabled,
            },
            scrollableLines = {
              order = 12,
              name = L["Number of Lines"],
              type = 'range',
              min = 10, max = 60, step = 1,
              get = get2,
              set = set2_update,
              disabled = isFrameNotScrollable,
            },
            scrollableInCombat = {
              order = 13,
              type = 'toggle',
              name = L["Disable in Combat"],
              get = get2,
              set = set2_update,
              disabled = isFrameItemDisabled,
            },

            frameFading = {
              type = 'description',
              order = 20,
              name = L["\n|cff11a34aFading Text Settings|r:"],
              fontSize = 'large',
            },
            enableCustomFade = {
              order = 21,
              type = 'toggle',
              name = L["Use Custom Fade"],
              width = 'full',
              get = get2,
              set = set2_update,
              disabled = isFrameItemDisabled,
            },
            enableFade = {
              order = 22,
              type = 'toggle',
              name = L["Enable"],
              desc = L["Turn off to disable fading all together.\n\n|cffFF0000Requires:|r |cff11a34aUse Custom Fade|r"],
              width = 'half',
              get = get2,
              set = set2_update,
              disabled = isFrameUseCustomFade,
            },
            fadeTime = {
              order = 23,
              name = L["Fade Out Duration"],
              desc = L["The duration of the fade out animation. |cff848482(Default: |cff11a34a0.3|r)|r\n\n|cffFF0000Requires:|r |cff11a34aUse Custom Fade|r"],
              type = 'range',
              min = 0, max = 2, step = .1,
              get = get2,
              set = set2_update,
              disabled = isFrameFadingDisabled,
            },
            visibilityTime = {
              order = 24,
              name = L["Visibility Duration"],
              desc = L["The duration that the text is shown in the frame. |cff848482(Default: |cff11a34a5|r)|r\n\n|cffFF0000Requires:|r |cff11a34aUse Custom Fade|r"],
              type = 'range',
              min = 2, max = 15, step = 1,
              get = get2,
              set = set2_update,
              disabled = isFrameFadingDisabled,
            },

          },
        },

        fonts = {
          order = 20,
          type = 'group',
          name = L["Font"],
          args = {
            fontSettings = {
              type = 'description',
              order = 0,
              name = L["|cff11a34aFont Settings|r:"],
              fontSize = 'large',
            },
            font = {
              type = 'select', dialogControl = 'LSM30_Font',
              order = 1,
              name = L["Font"],
              desc = L["Set the font of the frame."],
              values = AceGUIWidgetLSMlists.font,
              get = get2,
              set = set2_update,
              disabled = isFrameItemDisabled,
            },
            fontSize = {
              order = 2,
              name = L["Font Size"],
              desc = L["Set the font size of the frame."],
              type = 'range',
              min = 6, max = 64, step = 1,
              get = get2,
              set = set2_update,
              disabled = isFrameItemDisabled,
            },
            fontOutline = {
              type = 'select',
              order = 3,
              name = L["Font Outline"],
              desc = L["Set the font outline."],
              values = {
                ['1NONE'] = L["None"],
                ['2OUTLINE'] = L['OUTLINE'],
                -- BUG: Setting font to monochrome AND above size 16 will crash WoW
                -- http://us.battle.net/wow/en/forum/topic/6470967362
                ['3MONOCHROME'] = L['MONOCHROME'],
                ['4MONOCHROMEOUTLINE'] = L['MONOCHROMEOUTLINE'],
                ['5THICKOUTLINE'] = L['THICKOUTLINE'],
              },
              get = get2,
              set = set2_update,
              disabled = isFrameItemDisabled,
            },
            fontJustify = {
              type = 'select',
              order = 4,
              name = L["Justification"],
              desc = L["Justifies the output to a side."],
              values = {
                ['RIGHT']  = L["Right"],
                ['LEFT']   = L["Left"],
                ['CENTER'] = L["Center"],
              },
              get = get2,
              set = set2_update,
            },

            fontShadowSettings = {
              type = 'description',
              order = 10,
              name = L["\n|cff11a34aFont Shadow Settings|r:"],
              fontSize = 'large',
            },

            enableFontShadow = {
              order = 11,
              type = 'toggle',
              name = L["Enable Font Shadow"],
              desc = L["Shows a shadow behind the combat text fonts."],
              get = get2,
              set = set2_update,
              disabled = isFrameItemDisabled,
            },

            fontShadowColor = {
              order = 12,
              type = 'color',
              hasAlpha = true,
              name = L["Font Shadow Color"],
              get = getColor2,
              set = setColor2_alpha,
              disabled = isFrameFontShadowDisabled,
            },

            fontShadowOffsetX = {
              order = 13,
              name = L["Horizonal Offset"],
              type = 'range',
              min = -10, max = 10, step = 1,
              get = get2,
              set = set2_update,
              disabled = isFrameFontShadowDisabled,
            },

            fontShadowOffsetY = {
              order = 14,
              name = L["Vertical Offset"],
              type = 'range',
              min = -10, max = 10, step = 1,
              get = get2,
              set = set2_update,
              disabled = isFrameFontShadowDisabled,
            },
          },
        },

        icons = {
          order = 30,
          type = 'group',
          name = L["Icons"],
          args = {
            foreverNote = ForeverNote(0.5, L["only your own heals carry a spell; other heals get the invisible spacer at most."]),
            iconSizeSettings = {
              type = 'description',
              order = 1,
              name = L["|cff11a34aIcon Settings|r:"],
              fontSize = 'large',
            },
            iconsEnabled = {
              order = 2,
              type = 'toggle',
              name = L["Enable Icons"],
              desc = L["Show icons next to your damage."],
              get = get2,
              set = set2,
              disabled = isFrameItemDisabled,
            },
            iconsSize = {
              order = 3,
              name = L["Size"],
              desc = L["Set the icon size. (Recommended value: 16)"],
              type = 'range',
              min = 6, max = 22, step = 1,
              get = get2,
              set = set2,
              disabled = isFrameIconDisabled,
            },
            spacerIconsEnabled = {
              order = 4,
              type = 'toggle',
              name = L["Show Invisible Icons"],
              desc = L["When icons are disabled, you can still enable invisible icons to line up text."],
              get = get2,
              set = set2,
              disabled = isFrameIconSpacerDisabled,
            },
          }
        },

        fontColors = {
          order = 40,
          type = 'group',
          name = L["Colors"],
          args = {
            customColors_label = {
              type = 'description',
              order = 0,
              name = L["|cff11a34aCustom Colors|r:"],
              fontSize = 'large',
            },

            customColors_OverrideDesc = {
              type = 'description',
              order = 1,
              name = L["\n|cff11a34aOverride All Frame Color Settings|r:"],
              fontSize = 'small',
            },

            customColor = {
              order = 2,
              type = 'toggle',
              name = L["All Text One Color (Override Color Settings)"],
              width = 'double',
              desc = L["Change all the text in this frame to a specific color."],
              get = get2,
              set = set2,
            },

            fontColor = {
              order = 3,
              type = 'color',
              name = L["Color"],
              get = getColor2,
              set = setColor2,
              hidden = isFrameCustomColorDisabled,
            },

            customColors_Desc = {
              type = 'description',
              order = 4,
              name = L["\n|cff11a34aOther Color Settings|r:"],
              fontSize = 'small',
            },
          },
        },

        names = {
          order = 50,
          type = 'group',
          name = L["Names"],
          childGroups = 'select',
          get = getNameFormat,
          set = setNameFormat,
          args = {
            foreverNote = ForeverNote(0.5, L["only your own heals can be named on this client."]),
            namesDescription = {
              type = 'description',
              order = 1,
              name = L["The |cff11a34aNames Settings|r allows you to further format and customize your combat text frames. By selecting values from below, you will be able to see the source, destination or spell names of certain events.\n\n|cffFF8040NOTE:|r The |cff11a34aSpam Merger|r will preempt formatting."],
              fontSize = 'small'
            },

            nameAppearance = {
              type = 'description',
              order = 2,
              name = L["|cff11a34aName Appearance|r:\n\n"],
              fontSize = 'large',
              width = 'normal'
            },

            namePrefix = {
              order = 3,
              type = 'input',
              name = L["Prefix"],
              desc = L["Prefix this value to the beginning when displaying the name."],
              get = getNameFormatText,
              set = setNameFormatText,
            },

            namePostfix = {
              order = 4,
              type = 'input',
              name = L["Postfix"],
              desc = L["Postfix this value to the end when displaying the name."],
              get = getNameFormatText,
              set = setNameFormatText,
            },

            PLAYER = {
              order = 10,
              type = 'group',
              name = L["Events from a Player"],
              args = {
                playerNames = {
                  type = 'description',
                  order = 1,
                  name = L["|cff11a34aPlayer Name Format Settings|r:"],
                  fontSize = 'large',
                },

                enableNameColor = {
                  order = 2,
                  type = 'toggle',
                  name = L["Color Player Name"],
                  desc = L["If the player's class is known (e.g. is a raid member), it will be colored."],
                },

                removeRealmName = {
                  order = 3,
                  type = 'toggle',
                  name = L["Remove Realm Name"],
                  desc = L["If the player has a realm name attatched to her name, it will be removed."],
                },

                enableCustomNameColor = {
                  order = 4,
                  type = 'toggle',
                  name = L["Custom"],
                  desc = L["Preempt an automatic color with a custom one."],
                  width = 'half',
                },

                customNameColor = {
                  order = 5,
                  type = 'color',
                  name = L["Color"],
                  get = getNameFormatColor,
                  set = setNameFormatColor,
                  width = 'half',
                },

                playerSpellNames = {
                  type = 'description',
                  order = 10,
                  name = L["\n|cff11a34aSpell Name Format Settings|r:"],
                  fontSize = 'large',
                },

                enableSpellColor = {
                  order = 11,
                  type = 'toggle',
                  name = L["Color Spell Name"],
                  desc = L["The spell name will be colored according to it's spell school."],
                },

                playerNames_Spacer1 = {
                  type = 'description',
                  order = 12,
                  name = "",
                  width = 'normal'
                },

                enableCustomSpellColor = {
                  order = 13,
                  type = 'toggle',
                  name = L["Custom"],
                  desc = L["Preempt an automatic color with a custom one."],
                  width = 'half'
                },

                customSpellColor = {
                  order = 14,
                  type = 'color',
                  name = L["Color"],
                  width = 'half',
                  get = getNameFormatColor,
                  set = setNameFormatColor,
                },

                playerNames_Spacer2 = {
                  type = 'description',
                  order = 20,
                  name = "",
                },

                nameType = {
                  type = 'select',
                  order = 30,
                  name = L["Display Player Name"],
                  desc = "",
                  width = 'double',
                  style = 'radio',
                  values = {
                    [0] = L["None"],
                    [1] = L["Player Name"],
                    [2] = L["Spell Name"],
                    [3] = L["Both (Player Name - Spell Name)"],
                    [4] = L["Both (Spell Name - Player Name)"]
                  },
                },

              }
            },

            NPC = {
              disabled = OnEventSources,
              order = 20,
              type = 'group',
              name = L["Events from a NPC"],
              args = {
                npcNames = {
                  type = 'description',
                  order = 1,
                  name = L["|cff11a34aNPC Name Format Settings|r:"],
                  fontSize = 'large',
                },

                customNameColor = {
                  order = 2,
                  type = 'color',
                  name = L["NPC Name's Color"],
                  get = getNameFormatColor,
                  set = setNameFormatColor,
                },

                npcSpellNames = {
                  type = 'description',
                  order = 10,
                  name = L["\n|cff11a34aSpell Name Format Settings|r:"],
                  fontSize = 'large',
                },

                enableSpellColor = {
                  order = 11,
                  type = 'toggle',
                  name = L["Color Spell Name"],
                  desc = L["The spell name will be colored according to it's spell school."],
                },

                npcNames_Spacer1 = {
                  type = 'description',
                  order = 12,
                  name = "",
                  width = 'normal'
                },

                enableCustomSpellColor = {
                  order = 13,
                  type = 'toggle',
                  name = L["Custom"],
                  desc = L["Preempt an automatic color with a custom one."],
                  width = 'half'
                },

                customSpellColor = {
                  order = 14,
                  type = 'color',
                  name = L["Color"],
                  width = 'half',
                  get = getNameFormatColor,
                  set = setNameFormatColor,
                },

                npcNames_Spacer2 = {
                  type = 'description',
                  order = 20,
                  name = "",
                },

                nameType = {
                  type = 'select',
                  order = 21,
                  name = L["Display NPC Name"],
                  desc = "",
                  width = 'double',
                  style = 'radio',
                  values = {
                    [0] = L["None"],
                    [1] = L["NPC's Name"],
                    [2] = L["Spell Name"],
                    [3] = L["Both (NPC Name - Spell Name)"],
                    [4] = L["Both (Spell Name - NPC Name)"]
                  },
                },

              },
            },

          }
        },

        specialTweaks = {
          order = 60,
          name = L["Misc"],
          type = 'group',
          args = {
            foreverNote = ForeverNote(0.5, L["overhealing, absorbed healing and pet heals are not reported on this client. \"My heals only\" relies on matching your own casts and can miss a heal that lands late."]),
            specialTweaks = {
              type = 'description',
              order = 0,
              name = L["|cff11a34aMiscellaneous Settings|r:"],
              fontSize = 'large',
            },
            enableOverHeal = {
              disabled = OnEventSources,
              order = 4,
              type = 'toggle',
              name = L["Show Overheals"],
              desc = L["Show the overhealing you receive from other players."],
              get = get2,
              set = set2,
            },
            enableOverHealSubtraction = {
              order = 5,
              type = 'toggle',
              name = L["Subtract Overhealing"],
              desc = L["Subtract the overhealed amount from the Total Amount.\n\n|cffFF0000Requires:|r |cff11a34aShow Overheals|r"],
              get = get2,
              set = set2,
              disabled = function(info)
                if OnEventSources() then return true end
                return not x.db.profile.frames.healing.enabledFrame or
                  not x.db.profile.frames.healing.enableOverHeal
              end,
            },
            enableOverHealFormat = {
              order = 6,
              type = 'toggle',
              name = L["Format Overhealing"],
              desc = L["Splits overhealing into its own section. Example: +43,000 (O: 12,000)\n\n|cffFF0000Requires:|r |cff11a34aShow Overheals|r"],
              get = get2,
              set = set2,
              disabled = function(info)
                if OnEventSources() then return true end
                return not x.db.profile.frames.healing.enabledFrame or
                  not x.db.profile.frames.healing.enableOverHeal
              end,
            },
            overhealingPrefix = {
              order = 7,
              type = 'input',
              name = L["Overhealing Prefix"],
              desc = L["Text placed before the overheal amount.\n\nExample result: +5000 (O: 1200)\nDefault: (O:\n\nColor codes are optional. See warcraft.wiki.gg/wiki/UI_escape_sequences\n\n|cffFF0000Requires:|r |cff11a34aFormat Overhealing|r"],
              get = getTextIn2,
              set = setTextIn2,
              disabled = function(info)
                if OnEventSources() then return true end
                return not x.db.profile.frames.healing.enabledFrame or
                  not x.db.profile.frames.healing.enableOverHeal or
                  not x.db.profile.frames.healing.enableOverHealFormat
              end,
            },
            overhealingPostfix = {
              order = 8,
              type = 'input',
              name = L["Overhealing Postfix"],
              desc = L["Text placed after the overheal amount.\n\nExample result: +5000 (O: 1200)\nDefault: )\n\nColor codes are optional. See warcraft.wiki.gg/wiki/UI_escape_sequences\n\n|cffFF0000Requires:|r |cff11a34aFormat Overhealing|r"],
              get = getTextIn2,
              set = setTextIn2,
              disabled = function(info)
                if OnEventSources() then return true end
                return not x.db.profile.frames.healing.enabledFrame or
                  not x.db.profile.frames.healing.enableOverHeal or
                  not x.db.profile.frames.healing.enableOverHealFormat
              end,
            },
            hideAbsorbedHeals = {
              disabled = OnEventSources,
              order = 10,
              type = 'toggle',
              name = L["Hide Absorbed Heals"],
              desc = L["If enabled, subtract any healing that was absorbed by a |cffFF0000debuff|r from the total."],
              get = get2,
              set = set2,
            },
            enableSelfAbsorbs = {
              disabled = OnEventSources,
              order = 11,
              type = 'toggle',
              name = L["Show Absorbs"],
              desc = L["Shows absorbs you gain from other players."],
              get = get2,
              set = set2,
            },
            showOnlyMyHeals = {
              order = 12,
              type = 'toggle',
              name = L["Show My Heals Only"],
              desc = L["Shows only the player's healing done to himself or herself."],
              get = get2,
              set = set2,
            },
            showOnlyPetHeals = {
              order = 13,
              type = 'toggle',
              name = L["Show Pet Heals Too"],
              desc = L["Will also attempt to show the player pet's healing."],
              get = get2,
              set = set2,
              disabled = function() return OnEventSources() or not x.db.profile.frames.healing.showOnlyMyHeals end
            },
          },
        },
      },
    },

    power = {
      name = L["|cffFFFFFFClass Power|r"],
      type = 'group',
      order = 17,
      childGroups = 'tab',
      args = {

        frameSettings = {
          order = 10,
          type = 'group',
          name = L["Frame"],
          args = {
            frameSettings = {
              type = 'description',
              order = 0,
              name = L["|cff11a34aFrame Settings|r:"],
              fontSize = 'large',
            },
            enabledFrame = {
              order = 1,
              type = 'toggle',
              name = L["Enable"],
              width = 'half',
              get = get2,
              set = set2_update,
            },
            secondaryFrame = {
              type = 'select',
              order = 2,
              name = L["Secondary Frame"],
              desc = L["A frame to forward messages to when this frame is disabled."],
              values = {
                [0] = L["None"],
                [1] = L["General"],
                [2] = L["Outgoing"],
                [3] = L["Outgoing (Criticals)"],
                [4] = L["Incoming (Damage)"],
                [5] = L["Incoming (Healing)"],
                --[6] = L["Class Power"],
                [7] = L["Special Effects (Procs)"],
                [8] = L["Loot, Currency & Money"],
              },
              get = get2,
              set = set2,
              disabled = isFrameItemEnabled,
            },
            insertText = {
              type = 'select',
              order = 3,
              name = L["Text Direction"],
              desc = L["Changes the direction that the text travels in the frame."],
              values = {
                ["top"] = L["Down"],
                ["bottom"] = L["Up"],
              },
              get = get2,
              set = set2_update,
              disabled = isFrameItemDisabled,
            },
            alpha = {
              order = 4,
              name = L["Frame Alpha"],
              desc = L["Sets the alpha of the frame."],
              type = 'range',
              min = 0, max = 100, step = 1,
              get = get2,
              set = set2_update,
              disabled = isFrameItemDisabled,
            },
            megaDamage = {
              order = 5,
              type = 'toggle',
              name = L["Number Formatting"],
              desc = L["Enables number formatting. This option can be customized in the main |cff00FF00Frames|r options page to be either |cff11a34aAbbreviation|r or |cff11a34aDecimal Marks|r. "],
              get = get2,
              set = set2,
            },

            frameScrolling = {
              type = 'description',
              order = 10,
              name = L["\n|cff11a34aScrollable Frame Settings|r:"],
              fontSize = 'large',
            },
            enableScrollable = {
              order = 11,
              type = 'toggle',
              name = L["Enabled"],
              get = get2,
              set = set2_update,
              disabled = isFrameItemDisabled,
            },
            scrollableLines = {
              order = 12,
              name = L["Number of Lines"],
              type = 'range',
              min = 10, max = 60, step = 1,
              get = get2,
              set = set2_update,
              disabled = isFrameNotScrollable,
            },
            scrollableInCombat = {
              order = 13,
              type = 'toggle',
              name = L["Disable in Combat"],
              get = get2,
              set = set2_update,
              disabled = isFrameItemDisabled,
            },

            frameFading = {
              type = 'description',
              order = 20,
              name = L["\n|cff11a34aFading Text Settings|r:"],
              fontSize = 'large',
            },
            enableCustomFade = {
              order = 21,
              type = 'toggle',
              name = L["Use Custom Fade"],
              width = 'full',
              get = get2,
              set = set2_update,
              disabled = isFrameItemDisabled,
            },
            enableFade = {
              order = 22,
              type = 'toggle',
              name = L["Enable"],
              desc = L["Turn off to disable fading all together.\n\n|cffFF0000Requires:|r |cff11a34aUse Custom Fade|r"],
              width = 'half',
              get = get2,
              set = set2_update,
              disabled = isFrameUseCustomFade,
            },
            fadeTime = {
              order = 23,
              name = L["Fade Out Duration"],
              desc = L["The duration of the fade out animation. |cff848482(Default: |cff11a34a0.3|r)|r\n\n|cffFF0000Requires:|r |cff11a34aUse Custom Fade|r"],
              type = 'range',
              min = 0, max = 2, step = .1,
              get = get2,
              set = set2_update,
              disabled = isFrameFadingDisabled,
            },
            visibilityTime = {
              order = 24,
              name = L["Visibility Duration"],
              desc = L["The duration that the text is shown in the frame. |cff848482(Default: |cff11a34a5|r)|r\n\n|cffFF0000Requires:|r |cff11a34aUse Custom Fade|r"],
              type = 'range',
              min = 2, max = 15, step = 1,
              get = get2,
              set = set2_update,
              disabled = isFrameFadingDisabled,
            },

          },
        },

        fonts = {
          order = 20,
          type = 'group',
          name = L["Font"],
          args = {
            fontSettings = {
              type = 'description',
              order = 0,
              name = L["|cff11a34aFont Settings|r:"],
              fontSize = 'large',
            },
            font = {
              type = 'select', dialogControl = 'LSM30_Font',
              order = 1,
              name = L["Font"],
              desc = L["Set the font of the frame."],
              values = AceGUIWidgetLSMlists.font,
              get = get2,
              set = set2_update,
              disabled = isFrameItemDisabled,
            },
            fontSize = {
              order = 2,
              name = L["Font Size"],
              desc = L["Set the font size of the frame."],
              type = 'range',
              min = 6, max = 64, step = 1,
              get = get2,
              set = set2_update,
              disabled = isFrameItemDisabled,
            },
            fontOutline = {
              type = 'select',
              order = 3,
              name = L["Font Outline"],
              desc = L["Set the font outline."],
              values = {
                ['1NONE'] = L["None"],
                ['2OUTLINE'] = L['OUTLINE'],
                -- BUG: Setting font to monochrome AND above size 16 will crash WoW
                -- http://us.battle.net/wow/en/forum/topic/6470967362
                ['3MONOCHROME'] = L['MONOCHROME'],
                ['4MONOCHROMEOUTLINE'] = L['MONOCHROMEOUTLINE'],
                ['5THICKOUTLINE'] = L['THICKOUTLINE'],
              },
              get = get2,
              set = set2_update,
              disabled = isFrameItemDisabled,
            },
            fontJustify = {
              type = 'select',
              order = 4,
              name = L["Justification"],
              desc = L["Justifies the output to a side."],
              values = {
                ['RIGHT']  = L["Right"],
                ['LEFT']   = L["Left"],
                ['CENTER'] = L["Center"],
              },
              get = get2,
              set = set2_update,
            },

            fontShadowSettings = {
              type = 'description',
              order = 10,
              name = L["\n|cff11a34aFont Shadow Settings|r:"],
              fontSize = 'large',
            },

            enableFontShadow = {
              order = 11,
              type = 'toggle',
              name = L["Enable Font Shadow"],
              desc = L["Shows a shadow behind the combat text fonts."],
              get = get2,
              set = set2_update,
              disabled = isFrameItemDisabled,
            },

            fontShadowColor = {
              order = 12,
              type = 'color',
              hasAlpha = true,
              name = L["Font Shadow Color"],
              get = getColor2,
              set = setColor2_alpha,
              disabled = isFrameFontShadowDisabled,
            },

            fontShadowOffsetX = {
              order = 13,
              name = L["Horizonal Offset"],
              type = 'range',
              min = -10, max = 10, step = 1,
              get = get2,
              set = set2_update,
              disabled = isFrameFontShadowDisabled,
            },

            fontShadowOffsetY = {
              order = 14,
              name = L["Vertical Offset"],
              type = 'range',
              min = -10, max = 10, step = 1,
              get = get2,
              set = set2_update,
              disabled = isFrameFontShadowDisabled,
            },

          },
        },

        fontColors = {
          order = 40,
          type = 'group',
          name = L["Colors"],
          args = {
            customColors_label = {
              type = 'description',
              order = 0,
              name = L["|cff11a34aCustom Colors|r:"],
              fontSize = 'large',
            },

            customColors_OverrideDesc = {
              type = 'description',
              order = 1,
              name = L["\n|cff11a34aOverride All Frame Color Settings|r:"],
              fontSize = 'small',
            },

            customColor = {
              order = 2,
              type = 'toggle',
              name = L["All Text One Color (Override Color Settings)"],
              width = 'double',
              desc = L["Change all the text in this frame to a specific color."],
              get = get2,
              set = set2,
            },

            fontColor = {
              order = 3,
              type = 'color',
              name = L["Color"],
              get = getColor2,
              set = setColor2,
              hidden = isFrameCustomColorDisabled,
            },

            customColors_Desc = {
              type = 'description',
              order = 4,
              name = L["\n|cff11a34aOther Color Settings|r:"],
              fontSize = 'small',
            },
          },
        },

        specialTweaks = {
          order = 50,
          name = L["Misc"],
          type = 'group',
          args = {
            foreverNote = ForeverNote(0.5, L["power gains carry no power type on this client; your primary power is assumed, and periodic gains cannot be told apart."]),
            specialTweaks = {
              type = 'description',
              order = 0,
              name = L["|cff11a34aMiscellaneous Settings|r:"],
              fontSize = 'large',
            },
            showEnergyGains = {
              order = 1,
              type = 'toggle',
              name = L["Show Energy Gains"],
              desc = L["Show instant energy gains."],
              get = get2,
              set = set2,
            },
            showPeriodicEnergyGains = {
              disabled = OnEventSources,
              order = 2,
              type = 'toggle',
              name = L["Show Periodic Energy Gains"],
              desc = L["Show energy gained over time."],
              get = get2,
              set = set2,
            },
            showEnergyType = {
              order = 3,
              type = 'toggle',
              name = L["Show Energy Type"],
              desc = L["Show the type of energy that you are gaining."],
              get = get2,
              set = set2,
            },

            title1 = {
              type = 'description',
              order = 10,
              name = L["\n|cff11a34aFilter Resources|r:"],
              fontSize = 'large',
            },
            title2 = {
              type = 'description',
              order = 11,
              name = L["Check the energies that you do not wish to be displayed for your character:"],
              fontSize = 'small',
            },


            -- Disable Powers
            disableResource_MANA = {
              order = 100,
              type = 'toggle',
              name = L["Disable |cff11a34a"]..MANA,
              get = get2,
              set = set2,
              width = "normal",
            },
            disableResource_RAGE = {
              order = 101,
              type = 'toggle',
              name = L["Disable |cff11a34a"]..RAGE,
              get = get2,
              set = set2,
              width = "normal",
            },
            disableResource_FOCUS = {
              order = 102,
              type = 'toggle',
              name = L["Disable |cff11a34a"]..FOCUS,
              get = get2,
              set = set2,
              width = "normal",
            },
            disableResource_ENERGY = {
              order = 103,
              type = 'toggle',
              name = L["Disable |cff11a34a"]..(ENERGY or "Energy"),
              get = get2,
              set = set2,
              width = "normal",
            },
            -- Non-TBC resources removed (Runes, Runic Power, Chi, Holy Power, etc.)
          },
        },
      },
    },

    procs = {
      name = L["|cffFFFFFFSpecial Effects|r |cff11a34a(Procs)|r"],
      type = 'group',
      order = 18,
      childGroups = 'tab',
      args = {

        frameSettings = {
          order = 10,
          type = 'group',
          name = L["Frame"],
          args = {
            frameSettings = {
              type = 'description',
              order = 0,
              name = L["|cff11a34aFrame Settings|r:"],
              fontSize = 'large',
            },
            enabledFrame = {
              order = 1,
              type = 'toggle',
              name = L["Enable"],
              width = 'half',
              get = get2,
              set = set2_update,
            },
            secondaryFrame = {
              type = 'select',
              order = 2,
              name = L["Secondary Frame"],
              desc = L["A frame to forward messages to when this frame is disabled."],
              values = {
                [0] = L["None"],
                [1] = L["General"],
                [2] = L["Outgoing"],
                [3] = L["Outgoing (Criticals)"],
                [4] = L["Incoming (Damage)"],
                [5] = L["Incoming (Healing)"],
                [6] = L["Class Power"],
                --[7] = L["Special Effects (Procs)"],
                [8] = L["Loot, Currency & Money"],
              },
              get = get2,
              set = set2,
              disabled = isFrameItemEnabled,
            },
            insertText = {
              type = 'select',
              order = 3,
              name = L["Text Direction"],
              desc = L["Changes the direction that the text travels in the frame."],
              values = {
                ["top"] = L["Down"],
                ["bottom"] = L["Up"],
              },
              get = get2,
              set = set2_update,
              disabled = isFrameItemDisabled,
            },
            alpha = {
              order = 4,
              name = L["Frame Alpha"],
              desc = L["Sets the alpha of the frame."],
              type = 'range',
              min = 0, max = 100, step = 1,
              get = get2,
              set = set2_update,
              disabled = isFrameItemDisabled,
            },

            frameScrolling = {
              type = 'description',
              order = 10,
              name = L["\n|cff11a34aScrollable Frame Settings|r:"],
              fontSize = 'large',
            },
            enableScrollable = {
              order = 11,
              type = 'toggle',
              name = L["Enabled"],
              get = get2,
              set = set2_update,
              disabled = isFrameItemDisabled,
            },
            scrollableLines = {
              order = 12,
              name = L["Number of Lines"],
              type = 'range',
              min = 10, max = 60, step = 1,
              get = get2,
              set = set2_update,
              disabled = isFrameNotScrollable,
            },
            scrollableInCombat = {
              order = 13,
              type = 'toggle',
              name = L["Disable in Combat"],
              get = get2,
              set = set2_update,
              disabled = isFrameItemDisabled,
            },

            frameFading = {
              type = 'description',
              order = 20,
              name = L["\n|cff11a34aFading Text Settings|r:"],
              fontSize = 'large',
            },
            enableCustomFade = {
              order = 21,
              type = 'toggle',
              name = L["Use Custom Fade"],
              width = 'full',
              get = get2,
              set = set2_update,
              disabled = isFrameItemDisabled,
            },
            enableFade = {
              order = 22,
              type = 'toggle',
              name = L["Enable"],
              desc = L["Turn off to disable fading all together.\n\n|cffFF0000Requires:|r |cff11a34aUse Custom Fade|r"],
              width = 'half',
              get = get2,
              set = set2_update,
              disabled = isFrameUseCustomFade,
            },
            fadeTime = {
              order = 23,
              name = L["Fade Out Duration"],
              desc = L["The duration of the fade out animation. |cff848482(Default: |cff11a34a0.3|r)|r\n\n|cffFF0000Requires:|r |cff11a34aUse Custom Fade|r"],
              type = 'range',
              min = 0, max = 2, step = .1,
              get = get2,
              set = set2_update,
              disabled = isFrameFadingDisabled,
            },
            visibilityTime = {
              order = 24,
              name = L["Visibility Duration"],
              desc = L["The duration that the text is shown in the frame. |cff848482(Default: |cff11a34a5|r)|r\n\n|cffFF0000Requires:|r |cff11a34aUse Custom Fade|r"],
              type = 'range',
              min = 2, max = 15, step = 1,
              get = get2,
              set = set2_update,
              disabled = isFrameFadingDisabled,
            },
          },
        },

        fonts = {
          order = 20,
          type = 'group',
          name = L["Font"],
          args = {
            fontSettings = {
              type = 'description',
              order = 0,
              name = L["|cff11a34aFont Settings|r:"],
              fontSize = 'large',
            },
            font = {
              type = 'select', dialogControl = 'LSM30_Font',
              order = 1,
              name = L["Font"],
              desc = L["Set the font of the frame."],
              values = AceGUIWidgetLSMlists.font,
              get = get2,
              set = set2_update,
              disabled = isFrameItemDisabled,
            },
            fontSize = {
              order = 2,
              name = L["Font Size"],
              desc = L["Set the font size of the frame."],
              type = 'range',
              min = 6, max = 64, step = 1,
              get = get2,
              set = set2_update,
              disabled = isFrameItemDisabled,
            },
            fontOutline = {
              type = 'select',
              order = 3,
              name = L["Font Outline"],
              desc = L["Set the font outline."],
              values = {
                ['1NONE'] = L["None"],
                ['2OUTLINE'] = L['OUTLINE'],
                -- BUG: Setting font to monochrome AND above size 16 will crash WoW
                -- http://us.battle.net/wow/en/forum/topic/6470967362
                ['3MONOCHROME'] = L['MONOCHROME'],
                ['4MONOCHROMEOUTLINE'] = L['MONOCHROMEOUTLINE'],
                ['5THICKOUTLINE'] = L['THICKOUTLINE'],
              },
              get = get2,
              set = set2_update,
              disabled = isFrameItemDisabled,
            },
            fontJustify = {
              type = 'select',
              order = 4,
              name = L["Justification"],
              desc = L["Justifies the output to a side."],
              values = {
                ['RIGHT']  = L["Right"],
                ['LEFT']   = L["Left"],
                ['CENTER'] = L["Center"],
              },
              get = get2,
              set = set2_update,
            },

            fontShadowSettings = {
              type = 'description',
              order = 10,
              name = L["\n|cff11a34aFont Shadow Settings|r:"],
              fontSize = 'large',
            },

            enableFontShadow = {
              order = 11,
              type = 'toggle',
              name = L["Enable Font Shadow"],
              desc = L["Shows a shadow behind the combat text fonts."],
              get = get2,
              set = set2_update,
              disabled = isFrameItemDisabled,
            },

            fontShadowColor = {
              order = 12,
              type = 'color',
              hasAlpha = true,
              name = L["Font Shadow Color"],
              get = getColor2,
              set = setColor2_alpha,
              disabled = isFrameFontShadowDisabled,
            },

            fontShadowOffsetX = {
              order = 13,
              name = L["Horizonal Offset"],
              type = 'range',
              min = -10, max = 10, step = 1,
              get = get2,
              set = set2_update,
              disabled = isFrameFontShadowDisabled,
            },

            fontShadowOffsetY = {
              order = 14,
              name = L["Vertical Offset"],
              type = 'range',
              min = -10, max = 10, step = 1,
              get = get2,
              set = set2_update,
              disabled = isFrameFontShadowDisabled,
            },
          },
        },

        icons = {
          disabled = OnEventSources,
          order = 30,
          type = 'group',
          name = L["Icons"],
          args = {
            foreverNote = ForeverNote(0.5, L["proc names are secret values on this client; no icon can be looked up for them."]),
            iconSizeSettings = {
              type = 'description',
              order = 1,
              name = L["|cff11a34aIcon Settings|r:"],
              fontSize = 'large',
            },
            iconsEnabled = {
              order = 2,
              type = 'toggle',
              name = L["Enable Icons"],
              desc = L["Show icons next to your damage."],
              get = get2,
              set = set2,
              disabled = isFrameItemDisabled,
            },
            iconsSize = {
              order = 3,
              name = L["Size"],
              desc = L["Set the icon size. (Recommended value: 16)"],
              type = 'range',
              min = 6, max = 22, step = 1,
              get = get2,
              set = set2,
              disabled = isFrameIconDisabled,
            },
            spacerIconsEnabled = {
              order = 4,
              type = 'toggle',
              name = L["Show Invisible Icons"],
              desc = L["When icons are disabled, you can still enable invisible icons to line up text."],
              get = get2,
              set = set2,
              disabled = isFrameIconSpacerDisabled,
            },
          }
        },

        fontColors = {
          order = 40,
          type = 'group',
          name = L["Colors"],
          args = {
            customColors_label = {
              type = 'description',
              order = 0,
              name = L["|cff11a34aCustom Colors|r:"],
              fontSize = 'large',
            },

            customColors_OverrideDesc = {
              type = 'description',
              order = 1,
              name = L["\n|cff11a34aOverride All Frame Color Settings|r:"],
              fontSize = 'small',
            },

            customColor = {
              order = 2,
              type = 'toggle',
              name = L["All Text One Color (Override Color Settings)"],
              width = 'double',
              desc = L["Change all the text in this frame to a specific color."],
              get = get2,
              set = set2,
            },

            fontColor = {
              order = 3,
              type = 'color',
              name = L["Color"],
              get = getColor2,
              set = setColor2,
              hidden = isFrameCustomColorDisabled,
            },

            customColors_Desc = {
              type = 'description',
              order = 4,
              name = L["\n|cff11a34aOther Color Settings|r:"],
              fontSize = 'small',
            },
          },
        },

      },
    },

    loot = {
      name = L["|cffFFFFFFLoot, Currency & Money|r"],
      type = 'group',
      order = 19,
      childGroups = 'tab',
      args = {

        frameSettings = {
          order = 10,
          type = 'group',
          name = L["Frame"],
          args = {
            frameSettings = {
              type = 'description',
              order = 0,
              name = L["|cff11a34aFrame Settings|r:"],
              fontSize = 'large',
            },
            enabledFrame = {
              order = 1,
              type = 'toggle',
              name = L["Enable"],
              width = 'half',
              get = get2,
              set = set2_update,
            },
            secondaryFrame = {
              type = 'select',
              order = 2,
              name = L["Secondary Frame"],
              desc = L["A frame to forward messages to when this frame is disabled."],
              values = {
                [0] = L["None"],
                [1] = L["General"],
                [2] = L["Outgoing"],
                [3] = L["Outgoing (Criticals)"],
                [4] = L["Incoming (Damage)"],
                [5] = L["Incoming (Healing)"],
                [6] = L["Class Power"],
                [7] = L["Special Effects (Procs)"],
                --[8] = L["Loot, Currency & Money"],
              },
              get = get2,
              set = set2,
              disabled = isFrameItemEnabled,
            },
            insertText = {
              type = 'select',
              order = 3,
              name = L["Text Direction"],
              desc = L["Changes the direction that the text travels in the frame."],
              values = {
                ["top"] = L["Down"],
                ["bottom"] = L["Up"],
              },
              get = get2,
              set = set2_update,
              disabled = isFrameItemDisabled,
            },
            alpha = {
              order = 4,
              name = L["Frame Alpha"],
              desc = L["Sets the alpha of the frame."],
              type = 'range',
              min = 0, max = 100, step = 1,
              get = get2,
              set = set2_update,
              disabled = isFrameItemDisabled,
            },

            frameScrolling = {
              type = 'description',
              order = 10,
              name = L["\n|cff11a34aScrollable Frame Settings|r:"],
              fontSize = 'large',
            },
            enableScrollable = {
              order = 11,
              type = 'toggle',
              name = L["Enabled"],
              get = get2,
              set = set2_update,
              disabled = isFrameItemDisabled,
            },
            scrollableLines = {
              order = 12,
              name = L["Number of Lines"],
              type = 'range',
              min = 10, max = 60, step = 1,
              get = get2,
              set = set2_update,
              disabled = isFrameNotScrollable,
            },
            scrollableInCombat = {
              order = 13,
              type = 'toggle',
              name = L["Disable in Combat"],
              get = get2,
              set = set2_update,
              disabled = isFrameItemDisabled,
            },

            frameFading = {
              type = 'description',
              order = 30,
              name = L["\n|cff11a34aFading Text Settings|r:"],
              fontSize = 'large',
            },
            enableCustomFade = {
              order = 31,
              type = 'toggle',
              name = L["Use Custom Fade"],
              width = 'full',
              get = get2,
              set = set2_update,
              disabled = isFrameItemDisabled,
            },
            enableFade = {
              order = 32,
              type = 'toggle',
              name = L["Enable"],
              desc = L["Turn off to disable fading all together.\n\n|cffFF0000Requires:|r |cff11a34aUse Custom Fade|r"],
              width = 'half',
              get = get2,
              set = set2_update,
              disabled = isFrameUseCustomFade,
            },
            fadeTime = {
              order = 33,
              name = L["Fade Out Duration"],
              desc = L["The duration of the fade out animation. |cff848482(Default: |cff11a34a0.3|r)|r\n\n|cffFF0000Requires:|r |cff11a34aUse Custom Fade|r"],
              type = 'range',
              min = 0, max = 2, step = .1,
              get = get2,
              set = set2_update,
              disabled = isFrameFadingDisabled,
            },
            visibilityTime = {
              order = 34,
              name = L["Visibility Duration"],
              desc = L["The duration that the text is shown in the frame. |cff848482(Default: |cff11a34a5|r)|r\n\n|cffFF0000Requires:|r |cff11a34aUse Custom Fade|r"],
              type = 'range',
              min = 2, max = 15, step = 1,
              get = get2,
              set = set2_update,
              disabled = isFrameFadingDisabled,
            },

          },
        },

        fonts = {
          order = 20,
          type = 'group',
          name = L["Font"],
          args = {
            fontSettings = {
              type = 'description',
              order = 0,
              name = L["|cff11a34aFont Settings|r:"],
              fontSize = 'large',
            },
            font = {
              type = 'select', dialogControl = 'LSM30_Font',
              order = 1,
              name = L["Font"],
              desc = L["Set the font of the frame."],
              values = AceGUIWidgetLSMlists.font,
              get = get2,
              set = set2_update,
              disabled = isFrameItemDisabled,
            },
            fontSize = {
              order = 2,
              name = L["Font Size"],
              desc = L["Set the font size of the frame."],
              type = 'range',
              min = 6, max = 64, step = 1,
              get = get2,
              set = set2_update,
              disabled = isFrameItemDisabled,
            },
            fontOutline = {
              type = 'select',
              order = 3,
              name = L["Font Outline"],
              desc = L["Set the font outline."],
              values = {
                ['1NONE'] = L["None"],
                ['2OUTLINE'] = L['OUTLINE'],
                -- BUG: Setting font to monochrome AND above size 16 will crash WoW
                -- http://us.battle.net/wow/en/forum/topic/6470967362
                ['3MONOCHROME'] = L['MONOCHROME'],
                ['4MONOCHROMEOUTLINE'] = L['MONOCHROMEOUTLINE'],
                ['5THICKOUTLINE'] = L['THICKOUTLINE'],
              },
              get = get2,
              set = set2_update,
              disabled = isFrameItemDisabled,
            },
            fontJustify = {
              type = 'select',
              order = 4,
              name = L["Justification"],
              desc = L["Justifies the output to a side."],
              values = {
                ['RIGHT']  = L["Right"],
                ['LEFT']   = L["Left"],
                ['CENTER'] = L["Center"],
              },
              get = get2,
              set = set2_update,
            },

            fontShadowSettings = {
              type = 'description',
              order = 10,
              name = L["\n|cff11a34aFont Shadow Settings|r:"],
              fontSize = 'large',
            },

            enableFontShadow = {
              order = 11,
              type = 'toggle',
              name = L["Enable Font Shadow"],
              desc = L["Shows a shadow behind the combat text fonts."],
              get = get2,
              set = set2_update,
              disabled = isFrameItemDisabled,
            },

            fontShadowColor = {
              order = 12,
              type = 'color',
              hasAlpha = true,
              name = L["Font Shadow Color"],
              get = getColor2,
              set = setColor2_alpha,
              disabled = isFrameFontShadowDisabled,
            },

            fontShadowOffsetX = {
              order = 13,
              name = L["Horizonal Offset"],
              type = 'range',
              min = -10, max = 10, step = 1,
              get = get2,
              set = set2_update,
              disabled = isFrameFontShadowDisabled,
            },

            fontShadowOffsetY = {
              order = 14,
              name = L["Vertical Offset"],
              type = 'range',
              min = -10, max = 10, step = 1,
              get = get2,
              set = set2_update,
              disabled = isFrameFontShadowDisabled,
            },
          },
        },

        icons = {
          order = 30,
          type = 'group',
          name = L["Icons"],
          args = {
            iconSizeSettings = {
              type = 'description',
              order = 1,
              name = L["|cff11a34aIcon Settings|r:"],
              fontSize = 'large',
            },
            iconsEnabled = {
              order = 2,
              type = 'toggle',
              name = L["Enable Icons"],
              desc = L["Show icons next to your damage."],
              get = get2,
              set = set2,
              disabled = isFrameItemDisabled,
            },
            iconsSize = {
              order = 3,
              name = L["Size"],
              desc = L["Set the icon size. (Recommended value: 16)"],
              type = 'range',
              min = 6, max = 22, step = 1,
              get = get2,
              set = set2,
              disabled = isFrameIconDisabled,
            },
            spacerIconsEnabled = {
              order = 4,
              type = 'toggle',
              name = L["Show Invisible Icons"],
              desc = L["When icons are disabled, you can still enable invisible icons to line up text."],
              get = get2,
              set = set2,
              disabled = isFrameIconSpacerDisabled,
            },
          }
        },

        fontColors = {
          order = 40,
          type = 'group',
          name = L["Colors"],
          args = {
            customColors_label = {
              type = 'description',
              order = 0,
              name = L["|cff11a34aCustom Colors|r:"],
              fontSize = 'large',
            },

            customColors_OverrideDesc = {
              type = 'description',
              order = 1,
              name = L["\n|cff11a34aOverride All Frame Color Settings|r:"],
              fontSize = 'small',
            },

            customColor = {
              order = 2,
              type = 'toggle',
              name = L["All Text One Color (Override Color Settings)"],
              width = 'double',
              desc = L["Change all the text in this frame to a specific color."],
              get = get2,
              set = set2,
            },

            fontColor = {
              order = 3,
              type = 'color',
              name = L["Color"],
              get = getColor2,
              set = setColor2,
              hidden = isFrameCustomColorDisabled,
            },

          },
        },

        specialTweaks = {
          order = 50,
          type = 'group',
          name = L["Misc"],
          args = {
            specialTweaks = {
              type = 'description',
              order = 0,
              name = L["|cff11a34aMiscellaneous Settings|r:"],
              fontSize = 'large',
            },
            showMoney = {
              order = 1,
              type = 'toggle',
              name = L["Looted Money"],
              desc = L["Displays money that you pick up."],
              get = get2,
              set = set2,
            },
            showItems = {
              order = 2,
              type = 'toggle',
              name = L["Looted Items"],
              desc = L["Displays items that you pick up."],
              get = get2,
              set = set2,
            },
            showCurrency = {
              order = 3,
              type = 'toggle',
              name = L["Gained Currency"],
              desc = L["Displays currecy that you gain."],
              get = get2,
              set = set2,
            },
            showItemTypes = {
              order = 4,
              type = 'toggle',
              name = L["Show Item Types"],
              desc = L["Formats the looted message to also include the type of item (e.g. Trade Goods, Armor, Junk, etc.)."],
              get = get2,
              set = set2,
            },
            showItemTotal = {
              order = 5,
              type = 'toggle',
              name = L["Total Items"],
              desc = L["Displays how many items you have in your bag."],
              get = get2,
              set = set2,
            },
            showCrafted = {
              order = 6,
              type = 'toggle',
              name = L["Crafted Items"],
              desc = L["Displays items that you crafted."],
              get = get2,
              set = set2,
            },
            showQuest = {
              order = 7,
              type = 'toggle',
              name = L["Quest Items"],
              desc = L["Displays items that pertain to a quest."],
              get = get2,
              set = set2,
            },
            showPurchased = {
              order = 8,
              type = 'toggle',
              name = L["Purchased Items"],
              desc = L["Displays items that were purchased from a vendor."],
              get = get2,
              set = set2,
            },
            colorBlindMoney = {
              order = 9,
              type = 'toggle',
              name = L["Color Blind Mode"],
              desc = L["Displays money using letters G, S, and C instead of icons."],
              get = get2,
              set = set2,
            },
            filterItemQuality = {
              order = 10,
              type = 'select',
              name = L["Filter Item Quality"],
              desc = L["Will not display any items that are below this quality (does not filter Quest or Crafted items)."],
              values = {
                [0] = '1. |cff9d9d9d'..(ITEM_QUALITY0_DESC or "Poor")..'|r',   -- Poor
                [1] = '2. |cffffffff'..(ITEM_QUALITY1_DESC or "Common")..'|r',   -- Common
                [2] = '3. |cff1eff00'..(ITEM_QUALITY2_DESC or "Uncommon")..'|r',   -- Uncommon
                [3] = '4. |cff0070dd'..(ITEM_QUALITY3_DESC or "Rare")..'|r',   -- Rare
                [4] = '5. |cffa335ee'..(ITEM_QUALITY4_DESC or "Epic")..'|r',   -- Epic
                [5] = '6. |cffff8000'..(ITEM_QUALITY5_DESC or "Legendary")..'|r',   -- Legendary
              },
              get = get2,
              set = set2,
            },
          },
        },

      },
    },
  },
}
