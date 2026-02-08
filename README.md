# ElvUI HoldToCastFix

Fixes **Press and Hold Casting** for ElvUI action bar buttons by routing keybinds to Blizzard's native ActionButton frames.

## The Problem

ElvUI uses `SetOverrideBindingClick()` to redirect keybinds to its LibActionButton frames. This creates synthetic clicks which bypass Blizzard's `TryUseActionButton()` engine function — meaning the Press and Hold Casting feature doesn't work on ElvUI action bars.

## The Fix

HoldToCastFix uses `SetOverrideBinding()` with high priority to route keybinds back to Blizzard's native binding commands (e.g. `ACTIONBUTTON1`). This restores the engine's native press-and-hold re-trigger loop while keeping ElvUI's visual action bars intact.

## Supported Bars

| ElvUI Bar | Blizzard Equivalent |
|-----------|-------------------|
| Bar 1 | ActionButton 1-12 |
| Bar 3 | MultiBarBottomRight 1-12 |
| Bar 4 | MultiBarRight 1-12 |
| Bar 5 | MultiBarBottomLeft 1-12 |
| Bar 6 | MultiBarLeft 1-12 |
| Bar 13 | MultiBar5 1-12 |
| Bar 14 | MultiBar6 1-12 |
| Bar 15 | MultiBar7 1-12 |

## Installation

1. Download from [CurseForge](https://www.curseforge.com/wow/addons/elvui-holdtocastfix) or install via the CurseForge app.
2. Ensure ElvUI is installed.
3. Reload your UI (`/reload`).

## Usage

- `/holdtocast` or `/htcf` — Open the configuration panel.
- Select which ElvUI bar to fix, toggle enabled/disabled, and click Apply.

## Requirements

- World of Warcraft: The War Within (12.0.x)
- ElvUI (optional dependency — the addon is designed for use with ElvUI)

## License

MIT License — see [LICENSE](LICENSE) for details.
