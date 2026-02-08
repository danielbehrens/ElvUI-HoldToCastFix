local addonName, ns = ...

local HoldToCastFix = CreateFrame("Frame", "HoldToCastFixFrame", UIParent)
ns.HoldToCastFix = HoldToCastFix

-- Binding owner frame (separate so ClearOverrideBindings only clears ours)
local bindingFrame = CreateFrame("Frame", "HoldToCastFixBindingOwner", UIParent)
HoldToCastFix.bindingFrame = bindingFrame

-- Mapping: ElvUI bar number -> keybind target prefix (matches ElvUI barDefaults.bindButtons)
-- These are the binding command names that the WoW engine uses natively.
-- When a key is bound to e.g. "ACTIONBUTTON2", the engine calls TryUseActionButton()
-- on ActionButton2, which enables the press-and-hold re-trigger loop.
local barToBindTarget = {
    [1]  = "ACTIONBUTTON",
    [3]  = "MULTIACTIONBAR3BUTTON",
    [4]  = "MULTIACTIONBAR4BUTTON",
    [5]  = "MULTIACTIONBAR2BUTTON",
    [6]  = "MULTIACTIONBAR1BUTTON",
    [13] = "MULTIACTIONBAR5BUTTON",
    [14] = "MULTIACTIONBAR6BUTTON",
    [15] = "MULTIACTIONBAR7BUTTON",
}
ns.barToBindTarget = barToBindTarget

-- Supported bar numbers for the config UI
ns.supportedBars = {1, 3, 4, 5, 6, 13, 14, 15}

-- Blizzard button prefix (for display/status only)
ns.barToBlizzButton = {
    [1]  = "ActionButton",
    [3]  = "MultiBarBottomRightButton",
    [4]  = "MultiBarRightButton",
    [5]  = "MultiBarBottomLeftButton",
    [6]  = "MultiBarLeftButton",
    [13] = "MultiBar5Button",
    [14] = "MultiBar6Button",
    [15] = "MultiBar7Button",
}

local defaults = {
    enabled = true,
    bar = 1,
}

HoldToCastFix.pendingUpdate = false

function HoldToCastFix:ApplyBindings()
    if InCombatLockdown() then
        self.pendingUpdate = true
        return
    end

    ClearOverrideBindings(bindingFrame)

    local db = HoldToCastFixDB
    if not db or not db.enabled then return end

    local barNum = db.bar
    if not barNum then return end

    local bindPrefix = barToBindTarget[barNum]
    if not bindPrefix then return end

    -- For each button on this bar, set a high-priority override binding
    -- that binds the key directly to the native action command (e.g. ACTIONBUTTON2).
    --
    -- KEY DIFFERENCE from previous approach:
    -- SetOverrideBindingClick routes to a button's OnClick (synthetic click) which
    -- does NOT trigger the engine's TryUseActionButton / press-and-hold system.
    --
    -- SetOverrideBinding routes the key to the native binding command, which the
    -- engine handles exactly like a default keybind - including TryUseActionButton
    -- and the press-and-hold re-trigger loop.
    --
    -- ElvUI uses SetOverrideBindingClick(bar, false, key, labButtonName) to redirect
    -- keybinds to LAB buttons. Our SetOverrideBinding with priority=true takes
    -- precedence, effectively restoring native binding behavior for this bar.
    for i = 1, 12 do
        local bindCommand = bindPrefix .. i
        local keys = {GetBindingKey(bindCommand)}
        for _, key in ipairs(keys) do
            if key and key ~= "" then
                SetOverrideBinding(bindingFrame, true, key, bindCommand)
            end
        end
    end
end

function HoldToCastFix:Initialize()
    -- Set up saved variables with defaults
    if not HoldToCastFixDB then
        HoldToCastFixDB = {}
    end
    for k, v in pairs(defaults) do
        if HoldToCastFixDB[k] == nil then
            HoldToCastFixDB[k] = v
        end
    end

    -- Hook ElvUI's HandleBinds so we re-apply after ElvUI updates its bindings
    if ElvUI then
        local E = ElvUI[1]
        if E then
            local AB = E:GetModule("ActionBars", true)
            if AB and AB.HandleBinds then
                hooksecurefunc(AB, "HandleBinds", function()
                    HoldToCastFix:ApplyBindings()
                end)
            end
        end
    end

    -- Apply bindings now
    self:ApplyBindings()

    -- Register for combat end to apply deferred updates
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
end

HoldToCastFix:RegisterEvent("PLAYER_LOGIN")
HoldToCastFix:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        self:UnregisterEvent("PLAYER_LOGIN")
        self:Initialize()
    elseif event == "PLAYER_REGEN_ENABLED" then
        if self.pendingUpdate then
            self.pendingUpdate = false
            self:ApplyBindings()
        end
    end
end)

-- Slash command to open config
SLASH_HOLDTOCASTFIX1 = "/holdtocast"
SLASH_HOLDTOCASTFIX2 = "/htcf"
SlashCmdList["HOLDTOCASTFIX"] = function()
    if ns.ToggleConfig then
        ns.ToggleConfig()
    end
end
