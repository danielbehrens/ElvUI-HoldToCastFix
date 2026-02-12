# ElvUI HoldToCastFix

## [v1.3.1](https://github.com/danielbehrens/ElvUI-HoldToCastFix/tree/v1.3.1) (2026-02-13)
[Full Changelog](https://github.com/danielbehrens/ElvUI-HoldToCastFix/commits/v1.3.1) [Previous Releases](https://github.com/danielbehrens/ElvUI-HoldToCastFix/releases)

- Fixed state driver values not matching due to type mismatch — state values can arrive as numbers instead of strings, causing the paging check to fail silently. Added `tostring()` conversion to ensure reliable comparison.
- Fixed re-enabling the state driver after toggling bars not correctly re-evaluating the current paging state, which could leave bar 1 bindings in the wrong state.

## [v1.3.0](https://github.com/danielbehrens/ElvUI-HoldToCastFix/tree/v1.3.0) (2026-02-11)
[Full Changelog](https://github.com/danielbehrens/ElvUI-HoldToCastFix/commits/v1.3.0) [Previous Releases](https://github.com/danielbehrens/ElvUI-HoldToCastFix/releases)

- **Multi-bar support**: You can now enable Press and Hold Casting on multiple bars simultaneously instead of just one. The single bar dropdown has been replaced with checkboxes for each supported bar.
- Bar 1 uses a separate binding frame from other bars so that bar 1 paging (vehicles, dragonriding, shapeshift) no longer disrupts bindings on other bars.
- Saved variables automatically migrate from the old single-bar format — no action needed from users.
- Updated config panel layout with two-column checkbox grid.
- Status display now shows all active bars (e.g. "Active - Bars 1, 3, 5") and indicates when bar 1 is paged.
- Minimap tooltip now lists configured bars and paging status.

## [v1.2.1](https://github.com/danielbehrens/ElvUI-HoldToCastFix/tree/v1.2.1) (2026-02-09)
[Full Changelog](https://github.com/danielbehrens/ElvUI-HoldToCastFix/commits/v1.2.1) [Previous Releases](https://github.com/danielbehrens/ElvUI-HoldToCastFix/releases)

- Added optional minimap icon (disabled by default) — click to open config, right-click to toggle on/off. Drag to reposition around the minimap.
- Added a live status indicator showing whether the fix is currently active, visible on both the minimap icon and the config panel.

## [v1.2.0](https://github.com/danielbehrens/ElvUI-HoldToCastFix/tree/v1.2.0) (2026-02-09)
[Full Changelog](https://github.com/danielbehrens/ElvUI-HoldToCastFix/commits/v1.2.0) [Previous Releases](https://github.com/danielbehrens/ElvUI-HoldToCastFix/releases)

- **Fixed keybinds breaking during forced mount encounters** (e.g. Dimensius phase transition in Manaforge Omega). When the encounter forces you to mount up mid-fight, the addon now correctly detects the bar change and temporarily steps aside, then seamlessly restores your keybinds when you dismount — all without needing to leave combat or reload.
- Replaced the previous event-based detection with Blizzard's secure state driver system. This is more reliable and handles all bar paging scenarios (vehicles, dragonriding, shapeshift forms, possess bars) natively, including transitions that happen during combat.
- Removed the timer-based workaround from v1.1.0 which could miss fast transitions.
- Added support for WoW Interface version 12.0.1.

## [v1.1.0](https://github.com/danielbehrens/ElvUI-HoldToCastFix/tree/v1.1.0) (2026-02-08)
[Full Changelog](https://github.com/danielbehrens/ElvUI-HoldToCastFix/commits/v1.1.0) [Previous Releases](https://github.com/danielbehrens/ElvUI-HoldToCastFix/releases)

- Fix bar1 paging conflicts with vehicles, dragonriding, and shapeshift  
    Override bindings now correctly detect when bar1 is paged away (vehicle,  
    dragonriding/skyriding, shapeshift, possess, bonus bar) and temporarily  
    clear our bindings so the paged bar abilities work properly. Adds a  
    delayed recheck timer to handle API state race conditions on dismount.  
