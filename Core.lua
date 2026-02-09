local addonName, ns = ...

local HoldToCastFix = CreateFrame("Frame", "HoldToCastFixFrame", UIParent)
ns.HoldToCastFix = HoldToCastFix

-- Binding owner frame: SecureHandlerStateTemplate so we can clear bindings
-- during combat lockdown via the restricted environment's self:ClearBindings().
local stateFrame = CreateFrame("Frame", "HoldToCastFixBindingOwner", UIParent, "SecureHandlerStateTemplate")
HoldToCastFix.stateFrame = stateFrame

-- Mapping: ElvUI bar number -> keybind target prefix (matches ElvUI barDefaults.bindButtons)
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
HoldToCastFix.stateDriverActive = false

-- Build the macro condition string for bar1 paging detection.
-- Matches ElvUI's bar1 conditions from ActionBars.lua lines 100-103.
local function GetPagingConditions()
    local conditions = ""
    if GetOverrideBarIndex then
        conditions = conditions .. "[overridebar] 0; "
    end
    if GetVehicleBarIndex then
        conditions = conditions .. "[vehicleui] 0; [possessbar] 0; "
    end
    conditions = conditions .. "[bonusbar:5] 0; "
    if GetTempShapeshiftBarIndex then
        conditions = conditions .. "[shapeshift] 0; "
    end
    conditions = conditions .. "[bar:2] 0; [bar:3] 0; [bar:4] 0; [bar:5] 0; [bar:6] 0; "
    conditions = conditions .. "1"
    return conditions
end

-- Secure handler snippet: runs in restricted environment (works during combat).
-- When bar1 pages away (state "0"), clears our override bindings.
-- When bar1 returns to default page (state "1"), signals Lua side to re-apply.
stateFrame:SetAttribute("_onstate-htcfpage", [[
    if newstate ~= "1" then
        self:ClearBindings()
    end
    self:CallMethod("OnSecureStateChanged")
]])

-- Lua callback from the secure handler. Re-applies bindings when returning
-- to the default bar page (outside combat) or defers if in combat.
function stateFrame:OnSecureStateChanged()
    local page = self:GetAttribute("state-htcfpage")
    if page == "1" then
        -- Bar returned to default page, re-apply our bindings
        if InCombatLockdown() then
            HoldToCastFix.pendingUpdate = true
        else
            HoldToCastFix:ApplyBindings()
        end
    end
    -- When page ~= "1", the secure handler already cleared bindings
end

function HoldToCastFix:SetBindings()
    local db = HoldToCastFixDB
    if not db or not db.enabled then return end

    local barNum = db.bar
    if not barNum then return end

    local bindPrefix = barToBindTarget[barNum]
    if not bindPrefix then return end

    for i = 1, 12 do
        local bindCommand = bindPrefix .. i
        local keys = {GetBindingKey(bindCommand)}
        for _, key in ipairs(keys) do
            if key and key ~= "" then
                SetOverrideBinding(stateFrame, true, key, bindCommand)
            end
        end
    end
end

function HoldToCastFix:ApplyBindings()
    if InCombatLockdown() then
        self.pendingUpdate = true
        return
    end

    ClearOverrideBindings(stateFrame)

    local db = HoldToCastFixDB
    if not db or not db.enabled then
        self:DisableStateDriver()
        return
    end

    -- Only apply bindings if we're on the default bar page
    local page = stateFrame:GetAttribute("state-htcfpage")
    if page == "1" or page == nil then
        self:SetBindings()
    end

    -- Ensure state driver is registered for the configured bar
    self:EnableStateDriver()
end

function HoldToCastFix:EnableStateDriver()
    local db = HoldToCastFixDB
    if not db or not db.enabled then return end

    -- Only bar 1 needs paging detection; other bars don't page
    if db.bar == 1 then
        if not self.stateDriverActive then
            RegisterStateDriver(stateFrame, "htcfpage", GetPagingConditions())
            self.stateDriverActive = true
        end
    else
        self:DisableStateDriver()
    end
end

function HoldToCastFix:DisableStateDriver()
    if self.stateDriverActive then
        UnregisterStateDriver(stateFrame, "htcfpage")
        self.stateDriverActive = false
    end
end

function HoldToCastFix:Initialize()
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

    self:ApplyBindings()

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
