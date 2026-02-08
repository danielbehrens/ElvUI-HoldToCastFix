# Changelog

## [1.1.0] - 2026-02-08

### Fixed
- Bar 1 keybinds now correctly use flight abilities when mounted (dragonriding/skyriding)
- Bar 1 keybinds now correctly use vehicle, override, possess, and shapeshift bar abilities
- Fixed buttons not working after dismounting due to API state race condition

### Added
- Comprehensive bar paging detection (vehicle, override, possess, shapeshift, bonus bar, page changes)
- Delayed recheck timer to handle event/API timing mismatches on dismount
- Registered for all bar state change events (vehicle, bonus bar, shapeshift, page changes)

## [1.0.0] - 2025-02-08

### Added
- Initial release
- Routes keybinds for a selected ElvUI bar to Blizzard's native ActionButton frames
- Restores Press and Hold Casting functionality with ElvUI
- Configuration panel (`/holdtocast` or `/htcf`)
- Support for bars 1, 3, 4, 5, 6, 13, 14, 15
- Combat lockdown protection with deferred updates
- Hooks into ElvUI's `HandleBinds` to re-apply after ElvUI binding changes
