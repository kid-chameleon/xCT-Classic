--[[ xCT+ TBC Anniversary Classic
     Author: paradosi-Dreamscythe
     MIT License

     Intercepts Blizzard's floating combat text.

     Classic clients: hooks CombatText_AddMessage, pulls the message Blizzard
     just queued back out of COMBAT_TEXT_TO_ANIMATE, and re-routes it into
     xCT's General frame -- so output from other addons using the Blizzard FCT
     API is captured too. Requires Blizzard_CombatText, declared as
     RequiredDeps in the TOC.

     Mainline engine (WoW: Forever): Blizzard_CombatText is a mixin frame with
     no free functions and no animation list, and its damage, heal and aura
     messages are secret strings. The method hook below hands every message to
     modules/sources.lua, which keeps only the plain "Health Low" / "Mana Low"
     edges (the one source of a low-mana signal on that client) and ignores the
     rest. Nothing is removed from Blizzard's display; hiding it is the
     profile's hideBlizzardText option, applied in x.cvar_update.
]]


local _, addon = ...
local x = addon.engine
local L = addon.L

if CombatText_AddMessage then
  -- Intercept Messages Sent by other Add-Ons that use CombatText_AddMessage
  hooksecurefunc('CombatText_AddMessage', function(message, scrollFunction, r, g, b, displayType, isStaggered)
    if not x.db.profile.blizzardFCT.enableFloatingCombatText then
      local lastEntry = COMBAT_TEXT_TO_ANIMATE[ #COMBAT_TEXT_TO_ANIMATE ]
      CombatText_RemoveMessage(lastEntry)
      x:AddMessage("general", message, {r, g, b})
    end
  end)
elseif CombatText and CombatText.AddMessage then
  hooksecurefunc(CombatText, "AddMessage", function(_, message, scrollFunction, r, g, b, displayType)
    if x.OnBlizzardCombatTextMessage then
      x.OnBlizzardCombatTextMessage(message, r, g, b, displayType)
    end
  end)
end

-- Interface - Addons (Ace3 Blizzard Options)
x.blizzardOptions = {
  name = L["|cffFFFF00Combat Text - |r|cff60A0FFPowered By |cffFF0000x|r|cff80F000CT|r+|r"],
  handler = x,
  type = 'group',
  args = {
    showConfig = {
      order = 1,
      type = 'execute',
      name = L["Show Config"],
      func = function() x:ShowConfigTool() end,
    },
  },
}
