-- luacheck configuration for xCT+ Classic (WoW addon, Lua 5.1)
--
-- Run:  luacheck $(find . -name '*.lua' -not -path './libs/*')
--       or, from ~/projects/wowaddons:  ./check xCT-Classic
--
-- luacheck knows nothing about the Blizzard UI environment, so without this
-- file every WoW API call reads as an undefined global and the output is
-- unusable. The lists below were built from the globals this addon actually
-- touches. read_globals is read-only on purpose: a typo in an API name still
-- surfaces as a warning rather than being silently accepted, so ADD TO THE LIST
-- when you use a new API instead of widening an ignore pattern.

std = "lua51"
max_line_length = false
codes = true

-- WoW event and combat-log callbacks take fixed positional argument lists where
-- most parameters go unused. Not a defect.
unused_args = false

-- Vendored libraries are upstream code, not ours to lint.
exclude_files = { "libs/**" }

-- Globals this addon writes to or mutates.
globals = {
	"xCT_Plus",           -- the addon namespace, published for other addons
	"xCTSavedDB",         -- SavedVariables, written on logout
	"SlashCmdList", "StaticPopupDialogs",
	-- compat.lua installs these shims when the client lacks them
	"C_Spell", "C_Item", "C_AddOns", "C_CurrencyInfo", "C_CombatText", "Enum",
	"GetSpecializationInfo", "SetDesaturation",
	"SCHOOL_MASK_NONE", "SCHOOL_MASK_PHYSICAL", "SCHOOL_MASK_HOLY", "SCHOOL_MASK_FIRE",
	"SCHOOL_MASK_NATURE", "SCHOOL_MASK_FROST", "SCHOOL_MASK_SHADOW", "SCHOOL_MASK_ARCANE",
	-- x.cvar_update deliberately blanks these to suppress Blizzard's threat text,
	-- restoring the originals captured at load. See modules/options.lua.
	"UISpecialFrames", "GameTooltip",
	-- x.cvar_update deliberately blanks these to suppress Blizzard's threat text,
	-- restoring the values captured at load. See modules/options.lua.
	"COMBAT_THREAT_DECREASE_0", "COMBAT_THREAT_DECREASE_1", "COMBAT_THREAT_DECREASE_2",
	"COMBAT_THREAT_INCREASE_1", "COMBAT_THREAT_INCREASE_3",
}

read_globals = {
	-- Installed into the string table by libs/UTF8 at load time
	"string.utf8len", "string.utf8sub", "string.utf8reverse",
	"string.utf8upper", "string.utf8lower",

	-- Old xCT, checked for at load so the two do not run together
	"xCT", "ct",

	-- Core API / frames
	"CreateFrame", "UIParent", "hooksecurefunc", "LibStub", "random",
	"GetScreenWidth", "GetScreenHeight", "GetTime", "GetLocale", "ReloadUI",
	"InCombatLockdown", "PlaySound", "PlaySoundFile", "Settings",
	"InterfaceOptionsFrame_OpenToCategory", "AceGUIWidgetLSMlists",
	"SCROLLING_MESSAGE_FRAME_INSERT_MODE_TOP", "SCROLLING_MESSAGE_FRAME_INSERT_MODE_BOTTOM",

	-- Blizzard floating combat text (RequiredDeps: Blizzard_CombatText)
	"CombatTextSetActiveUnit", "CombatText_AddMessage", "CombatText_RemoveMessage",
	"GetCurrentCombatTextEventInfo", "COMBAT_TEXT_TO_ANIMATE",
	"CombatText", "CombatTextConstants", "LowHealthFrame",

	-- Mainline engine (WoW: Forever): secret values and their predicates
	"C_Secrets", "C_CombatLog", "C_UnitAuras", "C_CVar", "issecretvalue", "issecrettable",
	"FACTION_STANDING_INCREASED", "FACTION_STANDING_INCREASED_ACH_BONUS",
	"FACTION_STANDING_DECREASED", "COMBATLOG_HONORGAIN", "COMBATLOG_HONORGAIN_NO_RANK",
	"COMBATLOG_HONORAWARD",
	"COMBAT_TEXT_LABEL", "COMBAT_TEXT_HONOR_GAINED", "COMBAT_TEXT_SHOW_FRIENDLY_NAMES",
	"COMBAT_TEXT_LOW_HEALTH_THRESHOLD", "COMBAT_TEXT_LOW_MANA_THRESHOLD",
	"ENTERING_COMBAT", "LEAVING_COMBAT",

	-- Unit / player state
	"UnitName", "UnitClass", "UnitRace", "UnitLevel", "UnitExists", "UnitGUID",
	"UnitHealth", "UnitHealthMax", "UnitPower", "UnitPowerMax", "UnitPowerType",
	"UnitAura", "UnitBuff", "UnitDebuff", "UnitIsPlayer", "UnitIsDeadOrGhost",
	"UnitInParty", "UnitInRaid", "UnitHasVehicleUI", "UnitFactionGroup",
	"GetPlayerInfoByGUID", "GetShapeshiftForm", "GetComboPoints", "GetPetIcon",
	"GetSpecialization", "GetNumSpecializations", "RAID_CLASS_COLORS", "PowerBarColor",

	-- Spells and items
	"GetSpellInfo", "GetSpellTexture", "GetSpellDescription",
	"GetItemInfo", "GetItemCount", "GetItemQualityColor",
	"GetAddOnMetadata", "EnableAddOn", "IsAddOnLoaded", "LoadAddOn",
	"ITEM_QUALITY0_DESC", "ITEM_QUALITY1_DESC", "ITEM_QUALITY2_DESC",
	"ITEM_QUALITY3_DESC", "ITEM_QUALITY4_DESC", "ITEM_QUALITY5_DESC",
	"LOOT_ITEM_SELF", "LOOT_ITEM_PUSHED_SELF", "LOOT_ITEM_CREATED_SELF",
	"CURRENCY_GAINED", "CURRENCY_GAINED_MULTIPLE", "MONEY",

	-- Combat log flags and spell schools
	"CombatLogGetCurrentEventInfo", "CombatLog_Object_IsA",
	"COMBATLOG_OBJECT_AFFILIATION_MINE", "COMBATLOG_OBJECT_REACTION_FRIENDLY",
	"COMBATLOG_OBJECT_CONTROL_PLAYER", "COMBATLOG_OBJECT_TYPE_GUARDIAN",
	"STRING_SCHOOL_ALL", "STRING_SCHOOL_PHYSICAL", "STRING_SCHOOL_HOLY",
	"STRING_SCHOOL_FIRE", "STRING_SCHOOL_NATURE", "STRING_SCHOOL_FROST",
	"STRING_SCHOOL_SHADOW", "STRING_SCHOOL_ARCANE", "STRING_SCHOOL_MAGIC",
	"STRING_SCHOOL_CHROMATIC", "STRING_SCHOOL_DIVINE", "STRING_SCHOOL_ELEMENTAL",
	"STRING_SCHOOL_FLAMESTRIKE", "STRING_SCHOOL_FIRESTORM", "STRING_SCHOOL_FROSTFIRE",
	"STRING_SCHOOL_FROSTSTORM", "STRING_SCHOOL_FROSTSTRIKE", "STRING_SCHOOL_HOLYFIRE",
	"STRING_SCHOOL_HOLYFROST", "STRING_SCHOOL_HOLYSTORM", "STRING_SCHOOL_HOLYSTRIKE",
	"STRING_SCHOOL_SHADOWFLAME", "STRING_SCHOOL_SHADOWFROST", "STRING_SCHOOL_SHADOWHOLY",
	"STRING_SCHOOL_SHADOWSTORM", "STRING_SCHOOL_SHADOWSTRIKE", "STRING_SCHOOL_SPELLFIRE",
	"STRING_SCHOOL_SPELLFROST", "STRING_SCHOOL_SPELLSHADOW", "STRING_SCHOOL_SPELLSTORM",
	"STRING_SCHOOL_SPELLSTRIKE", "STRING_SCHOOL_STORMSTRIKE",

	-- Miss types, damage results and combat strings
	"ABSORB", "BLOCK", "DODGE", "PARRY", "MISS", "RESIST", "REFLECT", "DEFLECT",
	"EVADE", "IMMUNE", "INTERRUPTED", "INTERRUPTS", "KILLING_BLOWS",
	"TEXT_MODE_A_STRING_RESULT_ABSORB", "TEXT_MODE_A_STRING_RESULT_BLOCK",
	"TEXT_MODE_A_STRING_RESULT_RESIST",
	"ACTION_SPELL_STOLEN", "ACTION_SPELL_DISPEL", "ACTION_PARTY_KILL",
	"ACTION_ENVIRONMENTAL_DAMAGE_DROWNING", "ACTION_ENVIRONMENTAL_DAMAGE_FALLING",
	"ACTION_ENVIRONMENTAL_DAMAGE_FATIGUE", "ACTION_ENVIRONMENTAL_DAMAGE_FIRE",
	"ACTION_ENVIRONMENTAL_DAMAGE_LAVA", "ACTION_ENVIRONMENTAL_DAMAGE_SLIME",
	"ERR_SPELL_COOLDOWN", "PET_ATTACK_TEXTURE",

	-- Power types and resource strings
	"MANA", "RAGE", "FOCUS", "ENERGY", "MANA_LOW", "HEALTH_LOW",
	"BALANCE_POSITIVE_ENERGY", "BALANCE_NEGATIVE_ENERGY",
	"HONOR", "HONOR_GAINED",

	-- Threat and option tooltip strings used by the config UI
	"OPTION_TOOLTIP_SHOW_DAMAGE", "OPTION_TOOLTIP_SHOW_TARGET_EFFECTS",
	"OPTION_TOOLTIP_SHOW_OTHER_TARGET_EFFECTS", "OPTION_TOOLTIP_SHOW_PET_MELEE_DAMAGE",
	"OPTION_TOOLTIP_SHOW_COMBAT_HEALING", "OPTION_TOOLTIP_LOG_PERIODIC_EFFECTS",
	"OPTION_TOOLTIP_COMBAT_TEXT_SHOW_AURAS", "OPTION_TOOLTIP_COMBAT_TEXT_SHOW_AURA_FADE",
	"OPTION_TOOLTIP_COMBAT_TEXT_SHOW_COMBAT_STATE",
	"OPTION_TOOLTIP_COMBAT_TEXT_SHOW_COMBO_POINTS",
	"OPTION_TOOLTIP_COMBAT_TEXT_SHOW_DODGE_PARRY_MISS",
	"OPTION_TOOLTIP_COMBAT_TEXT_SHOW_ENERGIZE",
	"OPTION_TOOLTIP_COMBAT_TEXT_SHOW_FRIENDLY_NAMES",
	"OPTION_TOOLTIP_COMBAT_TEXT_SHOW_HONOR_GAINED",
	"OPTION_TOOLTIP_COMBAT_TEXT_SHOW_LOW_HEALTH_MANA",
	"OPTION_TOOLTIP_COMBAT_TEXT_SHOW_PERIODIC_ENERGIZE",
	"OPTION_TOOLTIP_COMBAT_TEXT_SHOW_REACTIVES",
	"OPTION_TOOLTIP_COMBAT_TEXT_SHOW_REPUTATION",
	"OPTION_TOOLTIP_COMBAT_TEXT_SHOW_RESISTANCES",

	-- Generic UI strings
	"OKAY", "CONTINUE", "REVERT", "SAVE_CHANGES", "CANCEL", "UNKNOWN",
	"FIRST_NUMBER_CAP", "SECOND_NUMBER_CAP",
	"GOLD_AMOUNT", "SILVER_AMOUNT", "COPPER_AMOUNT",

	-- Misc API and WoW's Lua extensions
	"GetRealmName", "SetCVar", "GetCVar", "IsShiftKeyDown",
	"StaticPopup_Show", "StaticPopup_Hide",
	"strsplit", "floor", "time", "tremove", "tinsert", "wipe",
}
