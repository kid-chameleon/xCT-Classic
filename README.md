# xCT+ Classic

![xCT+ Logo](https://raw.githubusercontent.com/paradosi/xCT-Classic/main/logo.png)

Highly customizable floating combat text for **WoW Classic Era** and **TBC Classic Anniversary**, with in-progress support for the **WoW: Forever** beta (see `doc/forever-support.md` for what that client can and cannot show).

![Classic Era: 11508](https://img.shields.io/badge/Classic_Era-11508-yellow) ![TBC Anniversary: 20505](https://img.shields.io/badge/TBC_Anniversary-20505-blue)

## Features

- **Customizable Frames** - Separate frames for outgoing damage, crits, incoming damage, healing, loot, class power, and procs
- **Spam Merger** - Combine rapid hits from the same spell into single messages
- **Spell School Colors** - Color-code damage by school (fire, frost, shadow, etc.)
- **Icon Support** - Show spell icons alongside combat text
- **Filters** - Hide specific spells, buffs, debuffs, or items
- **Abbreviation** - Shorten large numbers (1.5k, 2.3M)
- **Profiles** - Save and switch between configurations

## Installation

### CurseForge
Search for "xCT+ TBC Classic" or install via your addon manager.

### Manual Install
1. Download the latest release from [GitHub Releases](https://github.com/paradosi/xCT-Classic/releases)
2. Extract the `xCT+` folder to your AddOns directory:
   - Classic Era: `_classic_era_/Interface/AddOns/`
   - TBC Anniversary: `_anniversary_/Interface/AddOns/`
   - WoW: Forever beta: `_classic_beta_/Interface/AddOns/` (loads `xCT+_Mainline.toc`)
3. Type `/reload` in game

## Usage

Type `/xct` to open the configuration panel.

## About This Fork

This is a **Classic port** of [xCT_Classic](https://github.com/Witnesscm/xCT_Classic) by Witnesscm, supporting both Classic Era and TBC Anniversary.

**Changes from the original:**
- Added Classic Era support (Interface 11508)
- Added API compatibility shims (C_Spell, C_Item, C_AddOns, C_CurrencyInfo, Enum.PowerType)
- Fixed LibSink channel scanning
- Removed non-Classic class references (Death Knight, Demon Hunter, Monk)

## Credits

- **Original Author:** Dandruff-Stormreaver US
- **Classic Port:** [Witnesscm/xCT_Classic](https://github.com/Witnesscm/xCT_Classic)
- **TBC Fork:** paradosi@Dreamscythe US

## License

[MIT License](LICENSE)

---

[![Buy Me A Coffee](https://img.buymeacoffee.com/button-api/?text=Buy%20me%20a%20coffee&emoji=&slug=paradosi&button_colour=5F7FFF&font_colour=ffffff&font_family=Cookie&outline_colour=000000&coffee_colour=FFDD00)](https://www.buymeacoffee.com/paradosi)
