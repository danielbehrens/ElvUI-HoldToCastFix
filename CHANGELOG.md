# ElvUI HoldToCastFix

## [v1.5.0](https://github.com/danielbehrens/ElvUI-HoldToCastFix/tree/v1.5.0) (2026-02-17)
[Full Changelog](https://github.com/danielbehrens/ElvUI-HoldToCastFix/commits/v1.5.0) [Previous Releases](https://github.com/danielbehrens/ElvUI-HoldToCastFix/releases)

- Fixed hold-to-cast not working in Druid forms (Cat Form, Bear Form, Moonkin, etc.) and other classes with bar paging (Rogue Shadow Dance, Warrior stances, Evoker)
- Hold-to-cast now stays active when switching forms — no more falling back to normal click-to-cast
- Fixed "Invalid frame handle" error that could occur when entering vehicles or dragonriding
- Bar 1 bindings now correctly restore after exiting a vehicle, even during combat

## [v1.4.0](https://github.com/danielbehrens/ElvUI-HoldToCastFix/tree/v1.4.0) (2026-02-13)
[Full Changelog](https://github.com/danielbehrens/ElvUI-HoldToCastFix/commits/v1.4.0) [Previous Releases](https://github.com/danielbehrens/ElvUI-HoldToCastFix/releases)

- Added ElvUI-styled UI theming to config, debug, and copy panels
- Added debug panel with live state monitoring (accessible via Debug button)
- Added copyable debug output for easier issue reporting
- Improved combat transition handling with "Pending - restoring after combat" status
- Restored full bar 1 paging conditions (vehicle, override, bonusbar, shapeshift)

## [v1.3.1](https://github.com/danielbehrens/ElvUI-HoldToCastFix/tree/v1.3.1) (2026-02-12)
[Full Changelog](https://github.com/danielbehrens/ElvUI-HoldToCastFix/commits/v1.3.1) [Previous Releases](https://github.com/danielbehrens/ElvUI-HoldToCastFix/releases)

- v1.3.1: Fix state driver type mismatch and re-enable paging state check
