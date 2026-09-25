--[[ xCT+ TBC Anniversary Classic
     Author: paradosi-Dreamscythe
     MIT License

     COMPATIBILITY SHIMS. Loaded FIRST, before libs/ -- see include.xml.

     Fills in APIs that Classic Era and TBC Anniversary lack but the addon (or
     a vendored library) expects. Every shim is guarded so a client that
     provides the real thing keeps it.

     THE RULE THIS FILE EXISTS TO ENFORCE, AND ONCE BROKE:
     because this loads before libs/, anything defined here WINS against a
     library that installs itself only into an empty slot. Until 4.7.4 this
     file installed byte-based string.utf8* stubs, which made libs/UTF8 skip
     its real multi-byte implementations entirely -- silently corrupting every
     non-ASCII locale. Before adding a shim, check no vendored library already
     provides it. When in doubt, shim nothing.
]]

local _, addon = ...

-- =====================================================
-- Client capability flags
-- =====================================================
-- WoW: Forever (interface 16001) runs the mainline 12.x engine on vanilla data: unit
-- health, power, auras in combat and every COMBAT_TEXT_UPDATE payload are secret
-- values, and the combat log is closed to addons. Classic Era and TBC Anniversary have
-- neither restriction. Everything downstream branches on addon.useEventSources rather
-- than on the interface number, so a client that gains or loses a capability is
-- handled by the capability, not by its version. See doc/forever-support.md, section 6.
local hasSecrets = (C_Secrets and C_Secrets.HasSecretRestrictions and C_Secrets.HasSecretRestrictions()) or false
local hasCombatLog = CombatLogGetCurrentEventInfo ~= nil
    or (C_CombatLog ~= nil and C_CombatLog.GetCurrentEventInfo ~= nil)
addon.hasSecrets = hasSecrets
addon.useEventSources = hasSecrets or not hasCombatLog

-- Secret-value predicates: the real globals on Forever, constant false elsewhere, so
-- every guard in the modules reads the same on all three clients.
addon.issecretvalue = issecretvalue or function() return false end
addon.issecrettable = issecrettable or function() return false end

-- TBC Compatibility: Provide C_Spell, C_Item, C_AddOns wrappers.
-- Each function is guarded on its own: Forever has the full C_Spell namespace and none
-- of the old globals (GetSpellInfo, GetSpellTexture are gone), the classic clients have
-- the globals and some or none of C_Spell. The modules call the C_Spell names only.
if not C_Spell then C_Spell = {} end
if not C_Spell.GetSpellName then
    function C_Spell.GetSpellName(spellID)
        local name = GetSpellInfo(spellID)
        return name
    end
end
if not C_Spell.GetSpellTexture then
    function C_Spell.GetSpellTexture(spellID)
        return (GetSpellTexture(spellID))
    end
end
if not C_Spell.GetSpellDescription then
    function C_Spell.GetSpellDescription(spellID)
        return GetSpellDescription and GetSpellDescription(spellID) or ""
    end
end

-- Blizzard combat text accessors: C_CombatText on mainline, free functions on classic.
-- Forever keeps the free functions too while the loadDeprecationFallbacks cvar is on,
-- but nothing here relies on that.
if not C_CombatText then C_CombatText = {} end
if not C_CombatText.SetActiveUnit then
    C_CombatText.SetActiveUnit = CombatTextSetActiveUnit
end
if not C_CombatText.GetCurrentEventInfo then
    C_CombatText.GetCurrentEventInfo = GetCurrentCombatTextEventInfo
end

-- Mainline dropped the SetDesaturation global (classic keeps it in UIParent.lua); the
-- vendored AceGUI-3.0 r41 CheckBox widget still calls it for every disabled checkbox.
-- No vendored library defines it, so a shim here cannot shadow one.
if not SetDesaturation then
    function SetDesaturation(texture, desaturation)
        texture:SetDesaturated(desaturation)
    end
end

if not C_Item then
    C_Item = {}
    function C_Item.GetItemInfo(itemID)
        return GetItemInfo(itemID)
    end
    function C_Item.GetItemCount(itemID)
        return GetItemCount(itemID)
    end
    function C_Item.GetItemQualityColor(quality)
        return GetItemQualityColor(quality)
    end
end

if not C_AddOns then
    C_AddOns = {}
    function C_AddOns.GetAddOnMetadata(name, field)
        return GetAddOnMetadata(name, field)
    end
    -- Required by libs/LibSink-2.0, which upvalues these at load time.
    C_AddOns.EnableAddOn = EnableAddOn
    C_AddOns.IsAddOnLoaded = IsAddOnLoaded
    C_AddOns.LoadAddOn = LoadAddOn
end

-- TBC Compatibility: C_CurrencyInfo
if not C_CurrencyInfo then
    C_CurrencyInfo = {}
    function C_CurrencyInfo.GetCurrencyInfoFromLink(link)
        return nil
    end
    function C_CurrencyInfo.GetCoinTextureString(money)
        local gold = floor(money / 10000)
        local silver = floor((money % 10000) / 100)
        local copper = money % 100
        local str = ""
        if gold > 0 then str = str .. gold .. "g " end
        if silver > 0 then str = str .. silver .. "s " end
        if copper > 0 then str = str .. copper .. "c" end
        return str ~= "" and str or "0c"
    end
end

-- Spell school bitmasks. Some Classic clients do not expose these, and
-- config/profile.lua needs them at load time to key its per-school colours.
-- Values from FrameXML/CombatFeedback.lua. Filled in only where missing, so a
-- client that does define them keeps its own.
SCHOOL_MASK_NONE     = SCHOOL_MASK_NONE     or 0x00
SCHOOL_MASK_PHYSICAL = SCHOOL_MASK_PHYSICAL or 0x01
SCHOOL_MASK_HOLY     = SCHOOL_MASK_HOLY     or 0x02
SCHOOL_MASK_FIRE     = SCHOOL_MASK_FIRE     or 0x04
SCHOOL_MASK_NATURE   = SCHOOL_MASK_NATURE   or 0x08
SCHOOL_MASK_FROST    = SCHOOL_MASK_FROST    or 0x10
SCHOOL_MASK_SHADOW   = SCHOOL_MASK_SHADOW   or 0x20
SCHOOL_MASK_ARCANE   = SCHOOL_MASK_ARCANE   or 0x40

-- TBC Compatibility: Enum.PowerType (TBC resources only)
if not Enum then Enum = {} end
if not Enum.PowerType then
    Enum.PowerType = {
        Mana = 0,
        Rage = 1,
        Focus = 2,
        Energy = 3,
        ComboPoints = 4,
    }
end

-- TBC Compatibility: GetSpecializationInfo (TBC has talent trees, not specs)
if not GetSpecializationInfo then
    function GetSpecializationInfo(spec)
        return nil, "Talents", nil, nil, nil
    end
end

-- NOTE: Do not shim string.utf8* here. libs/UTF8 provides real, multi-byte-aware
-- implementations and installs them only when the slot is empty ("if not
-- string.utf8len"). Because this file loads BEFORE libs/, any stub written here
-- permanently wins and silently disables that library -- which corrupts the
-- non-ASCII locales (zhCN is shipped) that the utf8.sub/upper calls in
-- modules/combattext.lua depend on.
