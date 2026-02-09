# ElvUI HoldToCastFix

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
