local addonName, ns = ...

local configFrame = nil
local minimapButton = nil
local minimapText = nil
local statusIndicator = nil
local barCheckboxes = {}

-- Helper: build comma-separated string of enabled bar numbers
local function GetEnabledBarString()
    local db = HoldToCastFixDB
    local barList = {}
    if db and db.bars then
        for _, barNum in ipairs(ns.supportedBars) do
            if db.bars[barNum] then
                barList[#barList + 1] = tostring(barNum)
            end
        end
    end
    return #barList > 0 and table.concat(barList, ", ") or "none"
end

-- Minimap button positioning
local function UpdateMinimapButtonPosition()
    if not minimapButton then return end
    local db = HoldToCastFixDB
    if not db or not db.minimap then return end
    local angle = math.rad(db.minimap.angle or 220)
    local radius = 80
    local x = math.cos(angle) * radius
    local y = math.sin(angle) * radius
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function CreateMinimapButton()
    local btn = CreateFrame("Button", "HoldToCastFixMinimapButton", Minimap)
    btn:SetSize(31, 31)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local overlay = btn:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(53, 53)
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    overlay:SetPoint("TOPLEFT")

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetSize(21, 21)
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetPoint("CENTER", 0, 1)

    local text = btn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    text:SetPoint("CENTER", 0, 1)
    text:SetText("HC")
    text:SetTextColor(0.5, 0.5, 0.5) -- starts dim, updated by UpdateActiveState
    minimapText = text

    -- Tooltip
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("ElvUI HoldToCastFix")
        local htcf = ns.HoldToCastFix
        local active = htcf and htcf.bindingsActive
        if active then
            GameTooltip:AddLine("Status: Active", 0, 1, 0)
            GameTooltip:AddLine("Bars: " .. GetEnabledBarString(), 0.8, 0.8, 0.8)
            if htcf.bar1Paged then
                GameTooltip:AddLine("(Bar 1 paged)", 1, 0.7, 0)
            end
        else
            GameTooltip:AddLine("Status: Inactive", 1, 0.4, 0)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Left-click to open config", 0.7, 0.7, 0.7)
        GameTooltip:AddLine("Right-click to toggle on/off", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Click handlers
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            ns.ToggleConfig()
        elseif button == "RightButton" then
            local db = HoldToCastFixDB
            if db then
                db.enabled = not db.enabled
                ns.HoldToCastFix:ApplyBindings()
                local state = db.enabled and "|cff00ff00Enabled|r" or "|cffff0000Disabled|r"
                print("|cff00ff00HoldToCastFix:|r " .. state)
                ns.UpdateActiveState()
            end
        end
    end)

    -- Dragging
    btn:RegisterForDrag("LeftButton")
    btn:SetScript("OnDragStart", function(self)
        self.isDragging = true
    end)
    btn:SetScript("OnDragStop", function(self)
        self.isDragging = false
        local mx, my = Minimap:GetCenter()
        local cx, cy = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        cx, cy = cx / scale, cy / scale
        local angle = math.deg(math.atan2(cy - my, cx - mx))
        local db = HoldToCastFixDB
        if db and db.minimap then
            db.minimap.angle = angle
        end
        UpdateMinimapButtonPosition()
    end)
    btn:SetScript("OnUpdate", function(self)
        if self.isDragging then
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            cx, cy = cx / scale, cy / scale
            local angle = math.atan2(cy - my, cx - mx)
            local radius = 80
            local x = math.cos(angle) * radius
            local y = math.sin(angle) * radius
            self:ClearAllPoints()
            self:SetPoint("CENTER", Minimap, "CENTER", x, y)
        end
    end)

    minimapButton = btn
    UpdateMinimapButtonPosition()

    local db = HoldToCastFixDB
    if db and db.minimap and db.minimap.show then
        btn:Show()
    else
        btn:Hide()
    end
end

-- Called from Core.lua Initialize after saved vars are loaded
function ns.InitMinimapButton()
    CreateMinimapButton()
end

function ns.SetMinimapButtonShown(show)
    if not minimapButton then return end
    if show then
        minimapButton:Show()
    else
        minimapButton:Hide()
    end
end

-- Updates both minimap icon and config panel to reflect active binding state
function ns.UpdateActiveState()
    local htcf = ns.HoldToCastFix
    local active = htcf and htcf.bindingsActive
    local bar1Paged = htcf and htcf.bar1Paged

    -- Minimap icon: gold when active, dim grey when inactive
    if minimapText then
        if active then
            minimapText:SetTextColor(1, 0.82, 0)
        else
            minimapText:SetTextColor(0.5, 0.5, 0.5)
        end
    end

    -- Config panel status indicator
    if statusIndicator then
        local db = HoldToCastFixDB
        local barStr = GetEnabledBarString()

        if db and not db.enabled then
            statusIndicator:SetText("|cffff0000Disabled|r")
        elseif active then
            if bar1Paged then
                statusIndicator:SetText("|cff00ff00Active|r - Bars " .. barStr .. "\n|cffffaa00(bar 1 paged)|r")
            else
                statusIndicator:SetText("|cff00ff00Active|r - Bars " .. barStr)
            end
        else
            if bar1Paged then
                statusIndicator:SetText("|cffffaa00Inactive|r (bar 1 paged)")
            else
                statusIndicator:SetText("|cffffaa00Inactive|r")
            end
        end
    end
end

local function CreateConfigPanel()
    local frame = CreateFrame("Frame", "HoldToCastFixConfigFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(260, 330)
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

    -- Minimap icon checkbox
    local minimapCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    minimapCheck:SetPoint("TOPLEFT", enableCheck, "BOTTOMLEFT", 0, 2)
    minimapCheck.text:SetText("Show Minimap Icon")
    minimapCheck.text:SetFontObject("GameFontNormal")
    minimapCheck:SetChecked(db.minimap and db.minimap.show or false)
    minimapCheck:SetScript("OnClick", function(self)
        if not db.minimap then db.minimap = {} end
        db.minimap.show = self:GetChecked()
        ns.SetMinimapButtonShown(db.minimap.show)
    end)
    frame.minimapCheck = minimapCheck

    -- Description
    local desc = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    desc:SetPoint("TOPLEFT", minimapCheck, "BOTTOMLEFT", 4, -4)
    desc:SetPoint("RIGHT", frame.InsetBg, "RIGHT", -10, 0)
    desc:SetJustifyH("LEFT")
    desc:SetTextColor(0.7, 0.7, 0.7)
    desc:SetText("Routes keybinds for the selected bars to Blizzard's native buttons, enabling Press and Hold Casting.")

    -- Bar selection label
    local barsLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    barsLabel:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -10)
    barsLabel:SetText("Fix these bars:")

    -- Bar checkboxes in two-column layout
    for idx, barNum in ipairs(ns.supportedBars) do
        local check = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
        local col = (idx - 1) % 2        -- 0 or 1
        local row = math.floor((idx - 1) / 2)  -- 0, 1, 2, 3

        if col == 0 then
            check:SetPoint("TOPLEFT", barsLabel, "BOTTOMLEFT", 0, -(row * 24) - 2)
        else
            check:SetPoint("TOPLEFT", barsLabel, "BOTTOMLEFT", 120, -(row * 24) - 2)
        end

        check.text:SetText("Bar " .. barNum)
        check.text:SetFontObject("GameFontHighlight")
        check:SetChecked(db.bars and db.bars[barNum] or false)
        check:SetScript("OnClick", function(self)
            if not db.bars then db.bars = {} end
            db.bars[barNum] = self:GetChecked() or nil
        end)
        barCheckboxes[barNum] = check
    end

    -- Status indicator
    statusIndicator = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statusIndicator:SetPoint("BOTTOMLEFT", frame.InsetBg, "BOTTOMLEFT", 14, 46)
    statusIndicator:SetPoint("BOTTOMRIGHT", frame.InsetBg, "BOTTOMRIGHT", -14, 46)
    statusIndicator:SetJustifyH("CENTER")
    statusIndicator:SetWordWrap(true)

    -- Apply button
    local applyBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    applyBtn:SetSize(100, 24)
    applyBtn:SetPoint("BOTTOM", frame, "BOTTOM", 0, 12)
    applyBtn:SetText("Apply")
    applyBtn:SetScript("OnClick", function()
        ns.HoldToCastFix:ApplyBindings()
        print("|cff00ff00HoldToCastFix:|r Settings applied - Bars " .. GetEnabledBarString() .. " routed to Blizzard buttons")
    end)

    frame:SetScript("OnShow", function()
        enableCheck:SetChecked(db.enabled)
        minimapCheck:SetChecked(db.minimap and db.minimap.show or false)
        for barNum, check in pairs(barCheckboxes) do
            check:SetChecked(db.bars and db.bars[barNum] or false)
        end
        ns.UpdateActiveState()
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
