local addonName, ns = ...

local configFrame = nil

local function CreateConfigPanel()
    local frame = CreateFrame("Frame", "HoldToCastFixConfigFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(260, 200)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetFrameStrata("DIALOG")
    frame:Hide()

    frame.TitleBg:SetHeight(30)
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    frame.title:SetPoint("TOP", frame.TitleBg, "TOP", 0, -3)
    frame.title:SetText("ElvUI HoldToCastFix")

    local db = HoldToCastFixDB

    -- Enable checkbox
    local enableCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    enableCheck:SetPoint("TOPLEFT", frame.InsetBg, "TOPLEFT", 10, -10)
    enableCheck.text:SetText("Enabled")
    enableCheck.text:SetFontObject("GameFontNormal")
    enableCheck:SetChecked(db.enabled)
    enableCheck:SetScript("OnClick", function(self)
        db.enabled = self:GetChecked()
        ns.HoldToCastFix:ApplyBindings()
    end)
    frame.enableCheck = enableCheck

    -- Description
    local desc = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    desc:SetPoint("TOPLEFT", enableCheck, "BOTTOMLEFT", 4, -4)
    desc:SetPoint("RIGHT", frame.InsetBg, "RIGHT", -10, 0)
    desc:SetJustifyH("LEFT")
    desc:SetTextColor(0.7, 0.7, 0.7)
    desc:SetText("Routes keybinds for the selected bar to Blizzard's native buttons, enabling Press and Hold Casting.")

    -- Bar label
    local barLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    barLabel:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -14)
    barLabel:SetText("Action Bar:")

    -- Bar dropdown
    local barDropdown = CreateFrame("Frame", "HoldToCastFixBarDropdown", frame, "UIDropDownMenuTemplate")
    barDropdown:SetPoint("LEFT", barLabel, "RIGHT", -4, -2)
    frame.barDropdown = barDropdown

    local function BarDropdown_Initialize(self, level)
        for _, barNum in ipairs(ns.supportedBars) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = "Bar " .. barNum
            info.value = barNum
            info.func = function(self)
                db.bar = self.value
                UIDropDownMenu_SetText(barDropdown, "Bar " .. self.value)
                CloseDropDownMenus()
            end
            info.checked = (db.bar == barNum)
            UIDropDownMenu_AddButton(info, level)
        end
    end

    UIDropDownMenu_SetWidth(barDropdown, 90)
    UIDropDownMenu_SetText(barDropdown, "Bar " .. (db.bar or 1))
    UIDropDownMenu_Initialize(barDropdown, BarDropdown_Initialize)

    -- Status text
    local statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusText:SetPoint("BOTTOMLEFT", frame.InsetBg, "BOTTOMLEFT", 14, 40)
    statusText:SetPoint("BOTTOMRIGHT", frame.InsetBg, "BOTTOMRIGHT", -14, 40)
    statusText:SetJustifyH("CENTER")
    statusText:SetTextColor(0.7, 0.7, 0.7)

    -- Apply button
    local applyBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    applyBtn:SetSize(100, 24)
    applyBtn:SetPoint("BOTTOM", frame, "BOTTOM", 0, 12)
    applyBtn:SetText("Apply")
    applyBtn:SetScript("OnClick", function()
        ns.HoldToCastFix:ApplyBindings()
        print("|cff00ff00HoldToCastFix:|r Settings applied - Bar " .. db.bar .. " routed to Blizzard buttons")
    end)

    frame:SetScript("OnShow", function()
        local barNum = db.bar
        enableCheck:SetChecked(db.enabled)
        UIDropDownMenu_SetText(barDropdown, "Bar " .. (barNum or 1))

        -- Show status
        local blizzPrefix = ns.barToBlizzButton[barNum]
        if blizzPrefix then
            local blizzName = blizzPrefix .. "1-12"
            local bindTarget = ns.barToBindTarget[barNum]
            if bindTarget then
                local key = GetBindingKey(bindTarget .. "1")
                if key then
                    statusText:SetText("All 12 buttons -> " .. blizzPrefix .. "1-12")
                else
                    statusText:SetText("No keybinds found for " .. bindTarget)
                end
            end
        else
            statusText:SetText("Bar " .. barNum .. " is not supported")
        end
    end)

    return frame
end

function ns.ToggleConfig()
    if not configFrame then
        configFrame = CreateConfigPanel()
    end
    if configFrame:IsShown() then
        configFrame:Hide()
    else
        configFrame:Show()
    end
end
