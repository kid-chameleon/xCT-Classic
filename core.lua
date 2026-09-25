--[[ xCT+ TBC Anniversary Classic
     Author: paradosi-Dreamscythe
     MIT License

     Entry point: event dispatch, slash commands, options registration and
     the startup sequence.

     Startup order matters. Frames are built on PLAYER_ENTERING_WORLD rather
     than at load, so every other addon has finished moving things first; that
     handler is also what arms the alpha worker in modules/frames.lua, so
     anything depending on x.frames being populated must run after it.

     OnInitialize refuses to load alongside the original xCT (checks the xCT
     and ct globals) -- the two addons cannot coexist.
]]

-- Get Addon's name and Blizzard's Addon Stub
local AddonName, addon = ...
local L = addon.L
local ipairs, pairs, type, string_format, table_insert, table_remove, table_sort, print, tostring, tonumber, select, string_lower, collectgarbage, string_match, string_find =
  ipairs, pairs, type, string.format, table.insert, table.remove, table.sort, print, tostring, tonumber, select, string.lower, collectgarbage, string.match, string.find

-- compares a tables values
local function tableCompare(t1, t2)
  local equal = true

  -- nil check
  if not t1 or not t2 then
    if not t1 and not t2 then
      return true
    else
      return false
    end
  end

  for i,v in pairs(t1) do
    if t2[i] ~= v then
      equal = false
      break;
    end
  end
  return equal
end

-- Local Handle to the Engine
local x = addon.engine

-- Profile Updated, need to refresh important stuff
local function RefreshConfig()
  -- Clean up the Profile
  x:CompatibilityLogic()

  x:UpdateFrames()
  x:UpdateSpamSpells()
  x:UpdateItemTypes()

  -- Will this fix the profile issue?
  x.GenerateSpellSchoolColors()
  x.GenerateColorOptions()

  -- Update combat text engine CVars
  x.cvar_update( true )

  collectgarbage()
end

local function ProfileReset()
  -- Clean up the Profile
  x:CompatibilityLogic()

  x:UpdateFrames()
  x:UpdateSpamSpells()
  x:UpdateItemTypes()

  collectgarbage()
end

-- Handle Addon Initialized
function x:OnInitialize()
  if xCT or ct and ct.myname and ct.myclass then
    print(L["|cffFF0000WARNING:|r xCT+ cannot load. Please disable xCT in order to use xCT+."])
    return
  end

  -- Clean Up Colors in the DB
  addon.LoadDefaultColors()

  -- Load the Data Base
  self.db = LibStub('AceDB-3.0'):New('xCTSavedDB', addon.defaults)

  -- Add the profile options to my dialog config
  addon.options.args['Profiles'] = LibStub('AceDBOptions-3.0'):GetOptionsTable(self.db)

  -- Initialize Minimap Button
  x:InitializeMinimapButton()

  -- Had to pass the explicit method into here, not sure why
  self.db.RegisterCallback(self, 'OnProfileChanged', RefreshConfig)
  self.db.RegisterCallback(self, 'OnProfileCopied', RefreshConfig)
  self.db.RegisterCallback(self, 'OnProfileReset', ProfileReset)

  -- Clean up the Profile
  local success = x:CompatibilityLogic()
  if not success then
    x:UpdateCombatTextEvents(false)
    return
  end

  -- Perform xCT+ Update
  x:UpdatePlayer()

  -- Delay updating frames until all other addons are loaded!

  x:UpdateCombatTextEvents(true)
  x:UpdateSpamSpells()
  x:UpdateItemTypes()
  x:UpdateAuraSpellFilter()
  x.GenerateColorOptions()
  x.GenerateSpellSchoolColors()

  -- Update combat text engine CVars
  x.cvar_update()

  -- Register Slash Commands
  x:RegisterChatCommand('xct', 'OpenxCTCommand')

  -- Everything got Initialized, show Startup Text
  if self.db.profile.showStartupText then
    local version = C_AddOns.GetAddOnMetadata("xCT+", "Version") or "Unknown"
    local playerName = UnitName("player")
    print(string_format("Hello %s. |cff11a34axCT+|r %s is loaded. To configure, type |cff11a34a/xct|r", playerName, version))
  end
end

-- Initialize Minimap Button using LibDBIcon
function x:InitializeMinimapButton()
  local LDB = LibStub("LibDataBroker-1.1", true)
  local LDBIcon = LibStub("LibDBIcon-1.0", true)

  if not LDB or not LDBIcon then return end

  -- Check if already registered (happens on reload)
  if LDBIcon:IsRegistered("xCT+") then return end

  local dataObject = LDB:NewDataObject("xCT+", {
    type = "launcher",
    text = "xCT+",
    icon = [[Interface\AddOns\xCT+\media\Textures\xtc_logo]],
    OnClick = function(_, button)
      if button == "LeftButton" then
        if IsShiftKeyDown() then
          x.ToggleConfigMode()
        else
          x:ToggleConfigTool()
        end
      elseif button == "RightButton" then
        x.ToggleConfigMode()
      end
    end,
    OnTooltipShow = function(tooltip)
      tooltip:AddLine("|cff11a34axCT+|r TBC Classic")
      tooltip:AddLine(" ")
      tooltip:AddLine("|cffFFFFFFLeft-Click:|r Open Options")
      tooltip:AddLine("|cffFFFFFFShift+Left-Click:|r Toggle Frames")
      tooltip:AddLine("|cffFFFFFFRight-Click:|r Toggle Frames")
    end,
  })

  if dataObject then
    LDBIcon:Register("xCT+", dataObject, self.db.profile.minimap)
  end
end

-- Toggle minimap button visibility
function x:ToggleMinimapButton()
  local LDBIcon = LibStub("LibDBIcon-1.0", true)
  if not LDBIcon then return end
  if not x.db or not x.db.profile or not x.db.profile.minimap then return end

  local button = _G["LibDBIcon10_xCT+"]

  if x.db.profile.minimap.hide then
    LDBIcon:Hide("xCT+")
    -- Use alpha/mouse as backup for addons that override Hide()
    if button then
      button:SetAlpha(0)
      button:EnableMouse(false)
    end
  else
    LDBIcon:Show("xCT+")
    if button then
      button:SetAlpha(1)
      button:EnableMouse(true)
    end
  end
end

-- Need to create a handle to update frames when every other addon is done.
local frameUpdate = CreateFrame("FRAME")
frameUpdate:RegisterEvent("PLAYER_ENTERING_WORLD")
frameUpdate:SetScript("OnEvent", function(self)
  self:UnregisterEvent("PLAYER_ENTERING_WORLD")
  x:UpdateFrames()
  x.cvar_update()
  -- Apply minimap button visibility state
  x:ToggleMinimapButton()
end)

-- Store the current addon version in the profile
function x:CompatibilityLogic()
    local addonVersionString = C_AddOns.GetAddOnMetadata("xCT+", "Version")
    if not addonVersionString or string_find(addonVersionString, "project%-version") then addonVersionString = "4.7.0" end
    self.db.profile.dbVersion = addonVersionString
    return true
end

local CLASS_NAMES = {
  -- Death Knight removed - not available in TBC
  ["DRUID"] = {
    [102] = 1,   -- Balance
    [103] = 2,   -- Feral
    [105] = 3,   -- Restoration
  },
  ["HUNTER"] = {
    [253] = 1,   -- Beast Mastery
    [254] = 2,   -- Marksmanship
    [255] = 3,   -- Survival
  },
  ["MAGE"] = {
    [62] = 1,    -- Arcane
    [63] = 2,    -- Fire
    [64] = 3,    -- Frost
  },
  ["PALADIN"] = {
    [65] = 1,    -- Holy
    [66] = 2,    -- Protection
    [70] = 3,    -- Retribution
  },
  ["PRIEST"] = {
    [256] = 1,   -- Discipline
    [257] = 2,   -- Holy
    [258] = 3,   -- Shadow
  },
  ["ROGUE"] = {
    [259] = 1,   -- Assassination
    [260] = 2,   -- Combat
    [261] = 3,   -- Subtlety
  },
  ["SHAMAN"] = {
    [262] = 1,   -- Elemental
    [263] = 2,   -- Enhancement
    [264] = 3,   -- Restoration
  },
  ["WARLOCK"] = {
    [265] = 1,   -- Affliction
    [266] = 2,   -- Demonology
    [267] = 3,   -- Destruction
  },
  ["WARRIOR"] = {
    [71] = 1,    -- Arms
    [72] = 2,    -- Fury
    [73] = 3,    -- Protection
  },
}

x.specName = {
   	[62] = L["Arcane"],
   	[63] = L["Fire"],
   	[64] = L["Frost"],
   	[65] = L["Holy"],
   	[66] = L["Protection"],
   	[70] = L["Retribution"],
   	[71] = L["Arms"],
   	[72] = L["Fury"],
   	[73] = L["Protection"],
   	[102] = L["Balance"],
   	[103] = L["Feral"],
   	[105] = L["Restoration"],
   	-- Death Knight specs removed - not available in TBC
   	[253] = L["Beast Mastery"],
   	[254] = L["Marksmanship"],
   	[255] = L["Survival"],
   	[256] = L["Discipline"],
   	[257] = L["Holy"],
   	[258] = L["Shadow"],
   	[259] = L["Assassination"],
   	[260] = L["Combat"],
   	[261] = L["Subtlety"],
   	[262] = L["Elemental"],
   	[263] = L["Enhancement"],
   	[264] = L["Restoration"],
   	[265] = L["Affliction"],
   	[266] = L["Demonology"],
   	[267] = L["Destruction"],
}

local function cleanColors(colorTable)
  for index, color in pairs(colorTable) do
    if color.colors then
      cleanColors(color.colors)
    else
      color.color = { color.default[1], color.default[2], color.default[3] }
    end
  end
end

function addon.LoadDefaultColors()
  for name, settings in pairs(addon.defaults.profile.frames) do
    if settings.colors then
      cleanColors(settings.colors)
    end
  end
  cleanColors(addon.defaults.profile.SpellColors)
end

-- Gets spammy spells from the database and creates options
function x:UpdateSpamSpells()
    local function SpamMergerGetSpellInterval(info)
        local spellId = tonumber(info[#info])
        if x.db.profile.spells.merge[spellId] ~= nil and x.db.profile.spells.merge[spellId].interval ~= nil then
            return x.db.profile.spells.merge[spellId].interval
        end
        return addon.merges[spellId].interval or 0
    end

    local function SpamMergerSetSpellInterval(info, value)
        local spellId = tonumber(info[#info])
        local db = x.db.profile.spells.merge[spellId] or {}
        db.interval = value
        x.db.profile.spells.merge[spellId] = db
    end

    local spells = addon.options.args.spells.args.classList.args
    local global = addon.options.args.spells.args.globalList.args
    local racetab = addon.options.args.spells.args.raceList.args

    for class, specs in pairs(CLASS_NAMES) do
        spells[class].args = {}
        for spec, index in pairs(specs) do
            local name = "All Specializations"
            if index ~= 0 then
                name = x.specName[spec]
            end

            spells[class].args["specHeader" .. index] = {
                type = "header",
                order = index * 2,
                name = name,
            }
        end
    end

    -- Create a list of the categories (to be sorted)
    local spamMergerGlobalSpellCategories = {}
    local spamMergerRacialSpellCategories = {}
    for _, entry in pairs(addon.merges) do
        if not CLASS_NAMES[entry.category] then
            if entry.racial_spell then
                table.insert(
                    spamMergerRacialSpellCategories,
                    { category = entry.category, order = entry.categoryOrder }
                )
            else
                table.insert(
                    spamMergerGlobalSpellCategories,
                    { category = entry.category, order = entry.categoryOrder }
                )
            end
        end
    end

    -- Show Categories in insert order
    local function sortTableByOrder(a, b)
        return a.order < b.order
    end
    table.sort(spamMergerGlobalSpellCategories, sortTableByOrder)
    table.sort(spamMergerRacialSpellCategories, sortTableByOrder)

    -- Assume less than 1000 entries per category ;)
    local spamMergerGlobalSpellOrders = {}
    for i, category in pairs(spamMergerGlobalSpellCategories) do
        local currentIndex = i * 1000

        -- Create the Category Header
        global[category.category] = {
            type = "header",
            order = currentIndex,
            name = category.category,
        }
        spamMergerGlobalSpellOrders[category.category] = currentIndex + 1
    end

    local spamMergerRacialSpellOrders = {}
    for i, rcategory in pairs(spamMergerRacialSpellCategories) do
        local rcurrentIndex = i * 1000

        -- Create the Category Header
        racetab[rcategory.category] = {
            type = "header",
            order = rcurrentIndex,
            name = rcategory.category,
        }
        spamMergerRacialSpellOrders[rcategory.category] = rcurrentIndex + 1
    end

    -- Update the UI
    for spellID, entry in pairs(addon.merges) do
        local name = C_Spell.GetSpellName(spellID)
        if name then
            -- Create a useful description for the spell
            local spellDesc = C_Spell.GetSpellDescription(spellID)
            if not spellDesc or spellDesc == "" then
                spellDesc = L["No Description"]
            end
            local desc = string.format(
                "%s\n\n|cffFF0000%s|r |cff798BDD%s|r",
                spellDesc,
                L["ID"],
                spellID
            )

            local firstSecondaryIdFound = true
            for originalSpellId, replaceSpellId in pairs(addon.replaceSpellId) do
                if replaceSpellId == spellID then
                    if firstSecondaryIdFound then
                        desc = desc .. "\n|cffFF0000" .. L["Secondary ID(s)"] .. "|r |cff798BDD" .. originalSpellId
                        firstSecondaryIdFound = false
                    else
                        desc = desc .. ", " .. originalSpellId
                    end
                end
            end
            if not firstSecondaryIdFound then
                desc = desc .. "|r"
            end
            -- Add the spell to the UI
            if CLASS_NAMES[entry.category] then
                local index = CLASS_NAMES[entry.category][tonumber(entry.desc) or 0]
                spells[entry.category].args[tostring(spellID)] = {
                    order = index * 2 + 1,
                    name = name,
                    desc = desc,
                    type = "range",
                    min = 0,
                    max = 5,
                    step = 0.1,
                    get = SpamMergerGetSpellInterval,
                    set = SpamMergerSetSpellInterval,
                }
            elseif entry.racial_spell then
                racetab[tostring(spellID)] = {
                    order = spamMergerRacialSpellOrders[entry.category],
                    name = name,
                    desc = desc,
                    type = "range",
                    min = 0,
                    max = 5,
                    step = 0.1,
                    get = SpamMergerGetSpellInterval,
                    set = SpamMergerSetSpellInterval,
                }
                spamMergerRacialSpellOrders[entry.category] = spamMergerRacialSpellOrders[entry.category] + 1
            else
                global[tostring(spellID)] = {
                    order = spamMergerGlobalSpellOrders[entry.category],
                    name = name,
                    desc = desc,
                    type = "range",
                    min = 0,
                    max = 5,
                    step = 0.1,
                    get = SpamMergerGetSpellInterval,
                    set = SpamMergerSetSpellInterval,
                }
                spamMergerGlobalSpellOrders[entry.category] = spamMergerGlobalSpellOrders[entry.category] + 1
            end
        end
    end
end

x.UpdateItemTypes = function() end

-- Get and set methods for the spell filter
local function getSF(info)
  return x.db.profile.spellFilter[info[#info-2]][info[#info]]
end
local function setSF(info, value) x.db.profile.spellFilter[info[#info-2]][info[#info]] = value end

-- Filter section configurations: { filterKey, dbKey, label, mode }
-- mode: "name" = simple name toggle, "spell" = spell ID lookup, "item" = item ID lookup
local FILTER_SECTIONS = {
  { "buffs",   "listBuffs",   L["Filtered Buffs |cff798BDD(Uncheck to Disable)|r"],            "name" },
  { "debuffs", "listDebuffs", L["Filtered Debuffs |cff798BDD(Uncheck to Disable)|r"],           "name" },
  { "procs",   "listProcs",   L["Filtered Procs |cff798BDD(Uncheck to Disable)|r"],             "name" },
  { "spells",  "listSpells",  L["Filtered Spells |cff798BDD(Uncheck to Disable)|r"],            "spell" },
  { "items",   "listItems",   L["Filtered Items |cff798BDD(Uncheck to Disable)|r"],             "item" },
  { "damage",  "listDamage",  L["Filtered Incoming Damage |cff798BDD(Uncheck to Disable)|r"],   "spell" },
  { "healing", "listHealing", L["Filtered Incoming Healing |cff798BDD(Uncheck to Disable)|r"],  "spell" },
}

-- Maps db category key -> filter key for Add/RemoveFilteredSpell
local CATEGORY_TO_FILTER = {}
for _, section in ipairs(FILTER_SECTIONS) do
  CATEGORY_TO_FILTER[section[2]] = section[1]
end

-- Update the Buff, Debuff and Spell filter list
function x:UpdateAuraSpellFilter(specific)
  for _, section in ipairs(FILTER_SECTIONS) do
    local filterKey, dbKey, label, mode = section[1], section[2], section[3], section[4]

    if not specific or specific == filterKey then
      addon.options.args.spellFilter.args[dbKey].args.list = {
        name = label,
        type = 'group',
        guiInline = true,
        order = 11,
        args = { },
      }

      local entries = addon.options.args.spellFilter.args[dbKey].args.list.args
      local dbList = x.db.profile.spellFilter[dbKey]
      local updated = false
      local order = 10

      for id in pairs(dbList) do
        if mode == "name" then
          updated = true
          entries[id] = {
            order = order,
            name = id,
            type = 'toggle',
            get = getSF,
            set = setSF,
          }
        elseif mode == "spell" then
          local spellID = tonumber(string_match(id, "%d+"))
          local spellName = C_Spell.GetSpellName(spellID or id)
          if spellName then
            updated = true
            entries[id] = {
              order = order,
              name = spellName,
              desc = "|cffFF0000ID|r |cff798BDD" .. id .. "|r\n",
              type = 'toggle',
              get = getSF,
              set = setSF,
            }
          else
            dbList[id] = nil
          end
        elseif mode == "item" then
          local itemID = tonumber(string_match(id, "%d+"))
          local itemName, _, _, _, _, _, _, _, _, texture = C_Item.GetItemInfo(itemID or id)
          updated = true
          entries[id] = {
            order = order,
            name = string_format("|T%s:%d:%d:0:0:64:64:5:59:5:59|t %s", texture or x.BLANK_ICON, 16, 16, itemName or "Unknown Item"),
            desc = "|cffFF0000ID|r |cff798BDD" .. id .. "|r\n",
            type = 'toggle',
            get = getSF,
            set = setSF,
          }
        end
        order = order + 1
      end

      if not updated then
        entries["noSpells"] = {
          order = 1,
          name = L["No items have been added to this list yet."],
          type = 'description',
        }
      end
    end
  end
end

-- Add and remove Buffs, debuffs, and spells from the filter
function x.AddFilteredSpell(name, category)
  local filterKey = CATEGORY_TO_FILTER[category]
  if not filterKey then
    print(L["|cff11a34axCT+|r  |cffFF0000Error:|r Unknown filter type '"] .. category .. "'!")
    return
  end

  if category == "listSpells" then
    local spellID = tonumber(string_match(name, "%d+"))
    if not spellID or not C_Spell.GetSpellName(spellID) then
      print(L["|cff11a34axCT+|r  Could not add invalid Spell ID: |cff798BDD"] .. name .. "|r")
      return
    end
  end

  x.db.profile.spellFilter[category][name] = true
  x:UpdateAuraSpellFilter(filterKey)
end

function x.RemoveFilteredSpell(name, category)
  local filterKey = CATEGORY_TO_FILTER[category]
  if not filterKey then
    print(L["|cff11a34axCT+|r  |cffFF0000Error:|r Unknown filter type '"] .. category .. "'!")
    return
  end

  if category == "listSpells" then
    local spellID = tonumber(string_match(name, "%d+"))
    if not spellID or not C_Spell.GetSpellName(spellID) then
      print(L["|cff11a34axCT+|r  Could not remove invalid Spell ID: |cff798BDD"] .. name .. "|r")
      return
    end
  end

  x.db.profile.spellFilter[category][name] = nil
  x:UpdateAuraSpellFilter(filterKey)
end

local colorNameDB = { }

-- Returns the color and if it was enabled
function x.LookupColorByName(name)
  if colorNameDB[name] then
    if colorNameDB[name].enabled then
      return colorNameDB[name].color or colorNameDB[name].default, true
    end
    return colorNameDB[name].default, false
  else
    return
  end
end

local getColorDB = function(info)
  local enabled = string_match(info[#info], "(.*)_enabled")
  local color = string_match(info[#info], "(.*)_color")

  if info[#info-1] == 'fontColors' then
    if enabled then
      return x.db.profile.frames[info[#info-2]].colors[enabled].enabled
    elseif color then
      return unpack(x.db.profile.frames[info[#info-2]].colors[color].color or x.db.profile.frames[info[#info-2]].colors[color].default)
    end
  elseif info[#info-2] == 'fontColors' then
    if enabled then
      return x.db.profile.frames[info[#info-3]].colors[info[#info-1]].colors[enabled].enabled
    elseif color then
      return unpack(x.db.profile.frames[info[#info-3]].colors[info[#info-1]].colors[color].color or x.db.profile.frames[info[#info-3]].colors[info[#info-1]].colors[color].default)
    end
  elseif info[#info-3] == 'fontColors' then
    if enabled then
      return x.db.profile.frames[info[#info-4]].colors[info[#info-2]].colors[info[#info-1]].colors[enabled].enabled
    elseif color then
      return unpack(x.db.profile.frames[info[#info-4]].colors[info[#info-2]].colors[info[#info-1]].colors[color].color or x.db.profile.frames[info[#info-4]].colors[info[#info-2]].colors[info[#info-1]].colors[color].default)
    end
  elseif info[#info-1] == 'SpellSchools' then
    if enabled then
      return x.db.profile.SpellColors[enabled].enabled
    elseif color then
      return unpack(x.db.profile.SpellColors[color].color or x.db.profile.SpellColors[color].default)
    end
  end
end

local setColorDB = function(info, r, g, b)
  local enabled = string_match(info[#info], "(.*)_enabled")
  local color = string_match(info[#info], "(.*)_color")
  if info[#info-1] == 'fontColors' then
    if enabled then
      x.db.profile.frames[info[#info-2]].colors[enabled].enabled = r
    elseif color then
      x.db.profile.frames[info[#info-2]].colors[color].color = { r, g, b }
    end
  elseif info[#info-2] == 'fontColors' then
    if enabled then
      x.db.profile.frames[info[#info-3]].colors[info[#info-1]].colors[enabled].enabled = r
    elseif color then
      x.db.profile.frames[info[#info-3]].colors[info[#info-1]].colors[color].color = { r, g, b }
    end
  elseif info[#info-3] == 'fontColors' then
    if enabled then
      x.db.profile.frames[info[#info-4]].colors[info[#info-2]].colors[info[#info-1]].colors[enabled].enabled = r
    elseif color then
      x.db.profile.frames[info[#info-4]].colors[info[#info-2]].colors[info[#info-1]].colors[color].color = { r, g, b }
    end
  elseif info[#info-1] == 'SpellSchools' then
    if enabled then
      x.db.profile.SpellColors[enabled].enabled = r
    elseif color then
      x.db.profile.SpellColors[color].color = { r, g, b }
    end
  end
end

local funcColorReset = function(info)
  local color = string_match(info[#info], "(.*)_reset")
  if info[#info-1] == 'fontColors' then
    x.db.profile.frames[info[#info-2]].colors[color].color = x.db.profile.frames[info[#info-2]].colors[color].default
  elseif info[#info-2] == 'fontColors' then
    x.db.profile.frames[info[#info-3]].colors[info[#info-1]].colors[color].color = x.db.profile.frames[info[#info-3]].colors[info[#info-1]].colors[color].default
  elseif info[#info-3] == 'fontColors' then
    x.db.profile.frames[info[#info-4]].colors[info[#info-2]].colors[info[#info-1]].colors[color].color = x.db.profile.frames[info[#info-4]].colors[info[#info-2]].colors[info[#info-1]].colors[color].default
  elseif info[#info-1] == 'SpellSchools' then
    x.db.profile.SpellColors[color].color = x.db.profile.SpellColors[color].default
  end
end

local funcColorHidden = function(info)
  local color = string_match(info[#info], "(.*)_color")
  if info[#info-1] == 'fontColors' then
    return not x.db.profile.frames[info[#info-2]].colors[color].enabled
  elseif info[#info-2] == 'fontColors' then
    return not x.db.profile.frames[info[#info-3]].colors[info[#info-1]].colors[color].enabled
  elseif info[#info-3] == 'fontColors' then
    return not x.db.profile.frames[info[#info-4]].colors[info[#info-2]].colors[info[#info-1]].colors[color].enabled
  elseif info[#info-1] == 'SpellSchools' then
    return not x.db.profile.SpellColors[color].enabled
  end
end

local funcColorResetHidden = function(info)
  local color = string_match(info[#info], "(.*)_reset")
  if info[#info-1] == 'fontColors' then
    return not x.db.profile.frames[info[#info-2]].colors[color].enabled or
      tableCompare(x.db.profile.frames[info[#info-2]].colors[color].color, x.db.profile.frames[info[#info-2]].colors[color].default)
  elseif info[#info-2] == 'fontColors' then
    return not x.db.profile.frames[info[#info-3]].colors[info[#info-1]].colors[color].enabled or
      tableCompare(x.db.profile.frames[info[#info-3]].colors[info[#info-1]].colors[color].color, x.db.profile.frames[info[#info-3]].colors[info[#info-1]].colors[color].default)
  elseif info[#info-3] == 'fontColors' then
    return not x.db.profile.frames[info[#info-4]].colors[info[#info-2]].colors[info[#info-1]].colors[color].enabled or
      tableCompare(x.db.profile.frames[info[#info-4]].colors[info[#info-2]].colors[info[#info-1]].colors[color].color, x.db.profile.frames[info[#info-4]].colors[info[#info-2]].colors[info[#info-1]].colors[color].default)
  elseif info[#info-1] == 'SpellSchools' then
    return not x.db.profile.SpellColors[color].enabled or
      tableCompare(x.db.profile.SpellColors[color].color, x.db.profile.SpellColors[color].default)
  end
end

local funcColorDisabled = function(info)
  if info[#info-1] == 'fontColors' then
    return x.db.profile.frames[info[#info-2]].customColor
  elseif info[#info-2] == 'fontColors' then
    return x.db.profile.frames[info[#info-3]].customColor
  elseif info[#info-3] == 'fontColors' then
    return x.db.profile.frames[info[#info-4]].customColor
  end
end

local function GenerateColorOptionsTable_Entry(colorName, settings, options, index)
  -- Clean the DB of any old/removed values
  if not settings.desc or type(settings.desc) ~= "string" then return end

  -- Check for nil colors and set them to the default
  if not settings.color or not unpack(settings.color) then
    -- This needs to be a new table apperently
    settings.color = { unpack(settings.default) }
  end

  -- Cache this color into a quick lookup
  colorNameDB[colorName] = settings
  options[colorName.."_enabled"] = {
    order = index,
    type = 'toggle',
    name = settings.desc,
    get = getColorDB,
    set = setColorDB,
    desc = L["Enable a custom color for |cff798BDD"]..settings.desc.."|r.",
    disabled = funcColorDisabled,
  }
  options[colorName.."_color"] = {
    order = index + 1,
    type = 'color',
    name = L["Color"],
    get = getColorDB,
    set = setColorDB,
    desc = L["Change the color for |cff798BDD"]..settings.desc.."|r.",
    hidden = funcColorHidden,
    disabled = funcColorDisabled,
  }
  options[colorName.."_reset"] = {
    type = 'execute',
    order = index + 2,
    name = "Reset",
    width = 'half',
    func = funcColorReset,
    desc = "Resets |cff798BDD"..settings.desc.."|r back to the default color.",
    hidden = funcColorResetHidden,
    disabled = funcColorDisabled,
  }
  options["spacer"..index] = {
    order = index + 3,
    type = 'description',
    fontSize = 'small',
    width = 'full',
    name = '',
  }
end

local function GenerateColorOptionsTable(colorName, settings, options, index)
  if settings.colors then
    -- Multiple Layers of colors on the inside
    --[[options['spacer'..index] = {
      type = 'description',
      order = index,
      name = '\n',
      fontSize = 'small',
    }]]
    options[colorName] = {
      order = index + 1,
      type = 'group',
      guiInline = true,
      name = settings.desc,
      args = { },
    }
    index = index + 1

    -- Sort the Colors Alphabetical
    local sortedList = { }
    for colorName in pairs(settings.colors) do
      table_insert(sortedList, colorName)
    end

    table_sort(sortedList)

    local currentColorSettings
    for _, currentColorName in ipairs(sortedList) do
      currentColorSettings = settings.colors[currentColorName]
      GenerateColorOptionsTable_Entry(currentColorName, currentColorSettings, options[colorName].args, index)
      index = index + 4
    end
  else
    -- Just this color
    GenerateColorOptionsTable_Entry(colorName, settings, options, index)
    index = index + 4
  end
  return index
end

-- Generate Colors for each Frame
function x.GenerateColorOptions()
  for name, settings in pairs(x.db.profile.frames) do
    local options = addon.options.args.Frames.args[name]
    if settings.colors then
      local index = 10

      -- Sort the Colors Alphabetical
      local sortedList = { }
      for colorName in pairs(settings.colors) do
        table_insert(sortedList, colorName)
      end

      table_sort(sortedList)

      local colorSettings
      -- Do Single Colors First
      for _, colorName in ipairs(sortedList) do
        colorSettings = settings.colors[colorName]
        if not colorSettings.colors then
          index = GenerateColorOptionsTable(colorName, colorSettings, options.args.fontColors.args, index) + 1
        end
      end

      -- Then Do Color Groups with multiple settings
      for _, colorName in ipairs(sortedList) do
        colorSettings = settings.colors[colorName]
        if colorSettings.colors then
          index = GenerateColorOptionsTable(colorName, colorSettings, options.args.fontColors.args, index) + 1
        end
      end
    end
  end
end

function x.GenerateSpellSchoolColors()
  local options = addon.options.args.SpellSchools.args
  local settings = x.db.profile.SpellColors
  local index = 10

  local sortedList = { }
  for n in pairs(settings) do
    sortedList[#sortedList + 1] = tonumber(n)
  end

  table_sort(sortedList)

  local color
  for _, mask in ipairs(sortedList) do
    mask = tostring(mask)
    color = settings[mask]
    index = GenerateColorOptionsTable(mask, color, options, index) + 1
  end
end

do
  local cache = { [1] = "1", [2] = "2", [3] = "3",
    [4] = "4", [5] = "5", [6] = "6", [8] = "8",
    [9] = "9", [10] = "10", [12] = "12", [16] = "16",
    [17] = "17", [18] = "18", [20] = "20",
    [24] = "24", [28] = "28", [32] = "32", [33] = "33",
    [34] = "34", [36] = "36", [40] = "40", [48] = "48",
    [64] = "64", [65] = "65", [66] = "66", [68] = "68",
    [72] = "72", [80] = "80", [96] = "96", [124] = "124",
    [126] = "126", [127] = "127"
  }

  function x.GetSpellSchoolColor(spellSchool, override)
    -- See if the override name is enabled
    if override then
      local newColor, enabled = x.LookupColorByName(override)
      if enabled then return newColor end
    end

    -- Fast String lookup (faster than tostring)
    local stringIndex = cache[spellSchool or 1] or "1"
    local entry = x.db.profile.SpellColors[stringIndex]
    return entry.enabled and entry.color or entry.default
  end
end

-- Add LibSink Support
do
  local frames, color, LibSink = {}, {}, LibStub"LibSink-2.0"

  for name, title in pairs(x.FrameTitles) do
    if name ~= 'class' then
      frames[title] = name
    end
  end

  -- shortName, name, desc, func, scrollAreaFunc, hasSticky
  LibSink:RegisterSink("xCT_Plus", "xCT+", "Created for optimal performance in the toughest fights, this rugged combat text add-on is ready to be put to the test!",

    -- The Sink Function
    function(addon, text, r, g, b, font, size, outline, sticky, location, icon)
      local settings = x.db.profile.frames[location or "general"]
      if settings.iconsEnabled and icon then
        if settings.fontJustify == "LEFT" then
          text = string_format("%s %s", string_format(" |T%s:%d:%d:0:0:64:64:5:59:5:59|t", icon, settings.iconSize, settings.iconSize), text)
        else
          text = string_format("%s%s", text, string_format(" |T%s:%d:%d:0:0:64:64:5:59:5:59|t", icon, settings.iconSize, settings.iconSize))
        end
      end
      color[1] = r; color[2] = g; color[3] = b
      x:AddMessage(location or "general", text, color)
    end,

    -- List Active Scrolling Areas
    function ()
      local tmp = {}
      for name in pairs(frames) do
        table_insert(tmp, name)
      end
      return tmp
    end, false)
end

-- A helpful set of tips
local tips = {
  L["On the left list, under the |cffFFFF00Startup Message|r checkbox, you can click on the |cff798BDD+ Buttons|r (plus) to show more options."],
  L["If you want to |cff798BDDCombine Frame Outputs|r, disable one of the frames and use the |cffFFFF00Secondary Frame|r option on that frame."],
  L["Only the |cffFFFF00General|r, |cffFF8000Outgoing|r, |cffFFFF00Outgoing (Crits)|r, |cffFF8000Incoming Damage|r and |cffFFFF00Healing|r, and |cffFF8000Class Power|r frames can be abbreviated."],
  L["The |cffFFFF00Hide Config in Combat|r option was added to prevent |cffFFFF00xCT+|r from tainting your UI. It is highly recommended left enabled."],
  L["|cffFFFF00xCT+|r has several different ways it will merge critical hits. You can check them out in the |cffFFFF00Spam Merger|r section."],
  L["Each frame has a |cffFFFF00Misc|r section; select a frame and select the drop-down box to find it."],
  L["If there is a certain |cff798BDDSpell|r, |cff798BDDBuff|r, or |cff798BDDDebuff|r that you don't want to see, consider adding it to a |cff798BDDFilter|r."],
  L["You can change how |cffFFFF00xCT+|r shows you names in the |cffFFFF00Names|r section of most frames."],
}

local helpfulList = {}
local function GetNextTip()
  if #helpfulList == 0 then
    local used = {}

    local num
    while #used ~= #tips do
      num = random(1, #tips)
      if not used[num] then
        used[num] = true
        table_insert(helpfulList, tips[num])
      end
    end
  end

  local currentItem = helpfulList[1]
  table_remove(helpfulList, 1)

  return currentItem
end

-- Unused for now
function x:OnEnable() end
function x:OnDisable() end

-- This allows us to create our config dialog
local AceGUI = LibStub("AceGUI-3.0")
local AC = LibStub('AceConfig-3.0')
local ACD = LibStub('AceConfigDialog-3.0')
local ACR = LibStub('AceConfigRegistry-3.0')

-- Register the Options
ACD:SetDefaultSize(AddonName, 803, 560)
AC:RegisterOptionsTable(AddonName, addon.options)


AC:RegisterOptionsTable(AddonName.."Blizzard", x.blizzardOptions)
ACD:AddToBlizOptions(AddonName.."Blizzard", "|cffFF0000x|rCT+")

-- Close Config when entering combat
local lastConfigState, shownWarning = false, false
function x:CombatStateChanged()
  if x.db.profile.hideConfig then
    if self.inCombat then
      if x.myContainer then
        if x.myContainer:IsShown( ) then
          lastConfigState = true
          x:HideConfigTool()
        end
      end
    else
      if lastConfigState then
        x:ShowConfigTool()
      end
      lastConfigState = false
      shownWarning = false
    end
  end

  for framename, settings in pairs(x.db.profile.frames) do
    if settings.enableScrollable and settings.scrollableInCombat then
      if x.inCombat then
        x:DisableFrameScrolling( framename )
      else
        x:EnableFrameScrolling( framename )
      end
    end
  end
end

-- Force Config Page to refresh
function x:RefreshConfig()
  if ACD.OpenFrames[AddonName] then
    ACR:NotifyChange(AddonName)
  end
end

local helpfulLastUpdate = GetTime()
function x:OnAddonConfigRefreshed()
  if GetTime() - helpfulLastUpdate > 15 then
    helpfulLastUpdate = GetTime()
    addon.options.args.helpfulTip.name = GetNextTip()
    x:RefreshConfig()
  end
end

-- Process the slash command ('input' contains whatever follows the slash command)
function x:OpenxCTCommand(input)
  local lock = string_match(string_lower(input), 'lock')
  local save = string_match(string_lower(input), 'save')
  if lock or save then
    if not x.configuring and save then
      return
    elseif x.configuring then
      x:SaveAllFrames()
      x.EndConfigMode()
      print(L["|cff11a34axCT+|r  Frames have been saved. Please fasten your seat belts."])
      StaticPopup_Hide("XCT_PLUS_CONFIGURING")
    else
      x.ToggleConfigMode()

      print(L["|cff11a34axCT+|r  You are now free to move about the cabin."])
      print(L["      |cffFF0000/xct lock|r      - Saves your frames."])
      print(L["      |cffFF0000/xct cancel|r  - Cancels all your recent frame movements."])
    end

    -- return before you can do anything else
    return
  end

  if string_match(string_lower(input),'cancel') then
    if x.configuring then
      x:UpdateFrames();
      x.EndConfigMode()
      print(L["|cff11a34axCT+|r  canceled frame move."])
    else
      print(L["|cff11a34axCT+|r  There is nothing to cancel."])
    end
    return
  end

  if string_lower(input) == 'help' then
    print(L["|cff11a34axCT+|r  Commands:"])
    print(L["      |cffFF0000/xct lock|r - Locks and unlocks the frame movers."])
    print(L["      |cffFF0000/xct test|r - Attempts to emulate combat."])
    return
  end

  if string_lower(input) == 'test' then
    x.ToggleTestMode(true)
    return
  end

  if string_match(string_lower(input), 'track %w+') then
    local unit = string_match(string_lower(input), '%s(%w+)')

    local name = UnitName(unit)

    if not name then
      x.player.unit = ""
    else
      x.player.unit = "custom"
      C_CombatText.SetActiveUnit(unit)
    end

    x:UpdatePlayer()
    print("|cff11a34axCT+|r Tracking Unit:", name or "default")

    return
  end


  if not x.configuring then
    x:ToggleConfigTool()
  end
end

local function myContainer_OnRelease( self )
  AceGUI:Release(x.myContainer)
  x.myContainer = nil

  x.isConfigToolOpen = false
end

function x:ToggleConfigTool()
  if x.isConfigToolOpen then
    x:HideConfigTool()
  else
    x:ShowConfigTool()
  end
end

function x:ShowConfigTool(...)
  if x.isConfigToolOpen then return end
  if x.inCombat and x.db.profile.hideConfig then
    if not shownWarning then
      print(L["|cff11a34axCT+|r will open the |cff798BDDConfiguration Tool|r after combat."])
      shownWarning = true
      lastConfigState = true
    end
    return
  end

  x.isConfigToolOpen = true

  if x.myContainer then
    x.myContainer:Hide()
  end

  -- Register my AddOn for Escape keypresses
  x.myContainer = AceGUI:Create("Frame")
  x.myContainer.frame:SetScript('OnHide', function(self)
      x:HideConfigTool()
    end)
  _G["xCT_PlusConfigFrame"] = x.myContainer.frame
  table_insert( UISpecialFrames, "xCT_PlusConfigFrame" )

  -- Properly dispose of this frame
  x.myContainer:SetCallback("OnClose", myContainer_OnRelease)

  -- Last minute settings and SHOW
  local myContainerParent = x.myContainer.content:GetParent()
  if myContainerParent.SetResizeBounds then
	myContainerParent:SetResizeBounds(803, 300)
  else
	myContainerParent:SetMinResize(803, 300)
  end

  -- Go through and select all the groups that are relevant to the player
  if not x.selectDefaultGroups then
    x.selectDefaultGroups = true

    -- Select the player's class, then go back to home
    ACD:SelectGroup(AddonName, "spells", "classList", x.player.class)
    ACD:SelectGroup(AddonName, "spells", "mergeOptions")
    ACD:SelectGroup(AddonName, "Frames")
  end

  -- If we get a specific path we need to be at
  if select('#', ...) > 0 then
    ACD:SelectGroup(AddonName, ...)
  end

  ACD:Open(AddonName, x.myContainer)
end

local function HideConfigTool_OnUpdate( self, e )
  x.waiterHideConfig:SetScript("OnUpdate", nil)
  x.isConfigToolOpen = false

  if x.myContainer then
    x.myContainer:Hide()
  end
end

function x:HideConfigTool( wait )

  -- If the item that is call needs the frame for another unit of time
  if wait then
    if not x.waiterHideConfig then
      x.waiterHideConfig = CreateFrame("FRAME")
    end

    x.waiterHideConfig:SetScript("OnUpdate", HideConfigTool_OnUpdate)
    return
  end

  -- This is if we don't wait
  x.isConfigToolOpen = false

  if x.myContainer then
    x.myContainer:Hide()
  end

  -- MORE!
  GameTooltip:Hide()
end

-- Register Slash Commands
x:RegisterChatCommand('track', 'TrackxCTCommand')
function x:TrackxCTCommand(input)
  local name = UnitName("target")

  if not name then
    x.player.unit = ""
  else
    x.player.unit = "custom"
    C_CombatText.SetActiveUnit("target")
  end

  x:UpdatePlayer()
  print("|cff11a34axCT+|r Tracking Unit:", name or "default")
end
