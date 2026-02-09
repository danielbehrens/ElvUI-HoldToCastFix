local addonName, ns = ...

local HoldToCastFix = CreateFrame("Frame", "HoldToCastFixFrame", UIParent)
ns.HoldToCastFix = HoldToCastFix

-- Plain frame for binding ownership (critical for hold-to-cast)
local bindingFrame = CreateFrame("Frame", "HoldToCastFixBindingOwner", UIParent)
HoldToCastFix.bindingFrame = bindingFrame

-- Secure handler frame for combat-safe paging detection (bar1 only)
local stateFrame = CreateFrame("Frame", "HoldToCastFixStateDriver", UIParent, "SecureHandlerStateTemplate")
stateFrame:SetFrameRef("bindingFrame", bindingFrame)
HoldToCastFix.stateFrame = stateFrame

-- Mapping: ElvUI bar number -> keybind target prefix
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

ns.supportedBars = {1, 3, 4, 5, 6, 13, 14, 15}

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
    minimap = { show = false, angle = 220 },
}

HoldToCastFix.pendingUpdate = false
HoldToCastFix.bindingsActive = false
HoldToCastFix.stateDriverActive = false

-- Paging condition string for bar1 state driver
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

-- Secure handler: clears bindings on the plain bindingFrame when bar1 pages away.
-- Runs in restricted environment so it works during combat lockdown.
stateFrame:SetAttribute("_onstate-htcfpage", [[
    if newstate ~= "1" then
        local bf = self:GetFrameRef("bindingFrame")
        if bf then
            bf:ClearBindings()
        end
    end
    self:CallMethod("OnSecureStateChanged")
]])

-- Lua callback: re-applies bindings when bar1 returns to default page.
-- Note: GetAttribute returns numbers for numeric state values, so we
-- use tostring() to ensure consistent comparison.
function stateFrame:OnSecureStateChanged()
    local page = tostring(self:GetAttribute("state-htcfpage"))
    if page ~= "1" then
        HoldToCastFix.bindingsActive = false
        if ns.UpdateActiveState then ns.UpdateActiveState() end
    else
        if InCombatLockdown() then
            HoldToCastFix.pendingUpdate = true
        else
            ClearOverrideBindings(bindingFrame)
            HoldToCastFix:SetBindings()
        end
    end
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
                SetOverrideBinding(bindingFrame, true, key, bindCommand)
            end
        end
    end
    self.bindingsActive = true
    if ns.UpdateActiveState then ns.UpdateActiveState() end
end

function HoldToCastFix:ApplyBindings()
    if InCombatLockdown() then
        self.pendingUpdate = true
        return
    end

    ClearOverrideBindings(bindingFrame)
    self.bindingsActive = false

    local db = HoldToCastFixDB
    if not db or not db.enabled then
        self:DisableStateDriver()
        if ns.UpdateActiveState then ns.UpdateActiveState() end
        return
    end

    self:SetBindings()
    self:EnableStateDriver()
end

function HoldToCastFix:EnableStateDriver()
    local db = HoldToCastFixDB
    if not db or not db.enabled then return end

    if db.bar == 1 then
        if not self.stateDriverActive then
            self.stateDriverActive = true
            RegisterStateDriver(stateFrame, "htcfpage", GetPagingConditions())
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

    if ns.InitMinimapButton then
        ns.InitMinimapButton()
    end
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

SLASH_HOLDTOCASTFIX1 = "/holdtocast"
SLASH_HOLDTOCASTFIX2 = "/htcf"
SlashCmdList["HOLDTOCASTFIX"] = function()
    if ns.ToggleConfig then
        ns.ToggleConfig()
    end
end
