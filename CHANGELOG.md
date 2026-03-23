# ElvUI HoldToCastFix

## [v1.7.0](https://github.com/danielbehrens/ElvUI-HoldToCastFix/tree/v1.7.0) (2026-03-23)
[Full Changelog](https://github.com/danielbehrens/ElvUI-HoldToCastFix/commits/v1.7.0) [Previous Releases](https://github.com/danielbehrens/ElvUI-HoldToCastFix/releases)

- fix: bar 1 modifier-based paging (`[mod:shift]`, `[mod:ctrl]`, etc.) now fires the correct paged spell instead of always firing the unpaged bar 1 action
- note: hold-to-cast is temporarily paused while a modifier key pages bar 1 to a different bar (engine limitation); resumes when the modifier is released

## [v1.6.0](https://github.com/danielbehrens/ElvUI-HoldToCastFix/tree/v1.6.0) (2026-03-23)
[Full Changelog](https://github.com/danielbehrens/ElvUI-HoldToCastFix/commits/v1.6.0) [Previous Releases](https://github.com/danielbehrens/ElvUI-HoldToCastFix/releases)

- fix: automatically disables hold-to-cast bindings on housing plots so housing editor keybinds (1-4) work correctly; re-enables when leaving the plot

## [v1.5.3](https://github.com/danielbehrens/ElvUI-HoldToCastFix/tree/v1.5.3) (2026-03-14)
[Full Changelog](https://github.com/danielbehrens/ElvUI-HoldToCastFix/commits/v1.5.3) [Previous Releases](https://github.com/danielbehrens/ElvUI-HoldToCastFix/releases)

- - fix: resolved ADDON\_ACTION\_BLOCKED error (StanceButton1:SetShown) introduced in v1.5.2  
    - fix: Druid keybindings no longer break when shifting into Bear Form or other forms  
    - fix: improved reliability of keybinding restoration after entering dungeons while flying  
