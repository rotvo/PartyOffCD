local _, PartyOffCDCore = ...
PartyOffCDCore = PartyOffCDCore or _G.PartyOffCDCore

local PartyOffCD = _G.PartyOffCD
assert(PartyOffCD, "PartyOffCD: frame missing before loading ConfigUI.lua")
assert(PartyOffCDCore, "PartyOffCD: core missing before loading ConfigUI.lua")

local CLASS_ORDER = PartyOffCDCore.CLASS_ORDER
local SPELLS = PartyOffCDCore.SPELLS
local BASE_SPELLS = PartyOffCDCore.BASE_SPELLS
local DB_DEFAULTS = PartyOffCDCore.DEFAULTS
local PREFIX = PartyOffCDCore.PREFIX
local MINIMAP_RADIUS = PartyOffCDCore.MINIMAP_RADIUS
local MIN_TRACKER_ICON_SCALE = PartyOffCDCore.MIN_TRACKER_ICON_SCALE or 10
local MAX_TRACKER_ICON_SCALE = PartyOffCDCore.MAX_TRACKER_ICON_SCALE or 100
local TRACKER_ATTACH_CYCLE = { "LEFT", "RIGHT", "CENTER", "TOP", "BOTTOM" }
local TRACKER_GROW_CYCLE = { "LEFT", "RIGHT", "CENTER" }
local TRACKER_ATTACH_LABELS = {
    LEFT = "Left",
    RIGHT = "Right",
    CENTER = "Center",
    TOP = "Top",
    BOTTOM = "Bottom",
}
local CONTEXT_OPTIONS = {
    { key = "world", label = "Open World" },
    { key = "arena", label = "Arena" },
    { key = "dungeons", label = "Dungeons" },
    { key = "raid", label = "Raids" },
}

local DebugPrint = PartyOffCDCore.DebugPrint
local SafeGetSpellInfo = PartyOffCDCore.SafeGetSpellInfo
local CreateCheckbox = PartyOffCDCore.CreateCheckbox
local CreateNumericEditBox = PartyOffCDCore.CreateNumericEditBox
local sliderControlId = 1

local function GetNextCycleValue(currentValue, cycle)
    for index, value in ipairs(cycle) do
        if value == currentValue then
            return cycle[(index % #cycle) + 1]
        end
    end
    return cycle[1]
end

local function AddConfigWidget(owner, widget)
    owner.configRows[#owner.configRows + 1] = widget
    return widget
end

local function CreateDivider(parent, width, text)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(width, 18)

    local lineLeft = frame:CreateTexture(nil, "BACKGROUND")
    lineLeft:SetPoint("LEFT", frame, "LEFT", 0, 0)
    lineLeft:SetSize(18, 1)
    lineLeft:SetColorTexture(0.95, 0.82, 0.2, 0.85)

    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", lineLeft, "RIGHT", 6, 0)
    label:SetText(text or "")
    frame.label = label

    local lineRight = frame:CreateTexture(nil, "BACKGROUND")
    lineRight:SetPoint("LEFT", label, "RIGHT", 6, 0)
    lineRight:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
    lineRight:SetHeight(1)
    lineRight:SetColorTexture(0.25, 0.25, 0.28, 0.9)

    return frame
end

local function CreateSliderControl(parent, labelText, minValue, maxValue, step, width, getValue, setValue, formatter)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(width, 52)

    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    label:SetText(labelText)
    frame.label = label

    local valueText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    valueText:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    frame.valueText = valueText

    local sliderName = "PartyOffCDConfigSlider" .. sliderControlId
    sliderControlId = sliderControlId + 1

    local slider = CreateFrame("Slider", sliderName, frame, "OptionsSliderTemplate")
    slider:SetOrientation("HORIZONTAL")
    slider:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -18)
    slider:SetWidth(width)
    slider:SetHeight(20)
    slider:SetMinMaxValues(minValue, maxValue)
    slider:SetValueStep(step or 1)
    if slider.SetObeyStepOnDrag then
        slider:SetObeyStepOnDrag(true)
    end

    local low = _G[sliderName .. "Low"]
    local high = _G[sliderName .. "High"]
    local text = _G[sliderName .. "Text"]
    if low then
        low:SetText(tostring(minValue))
    end
    if high then
        high:SetText(tostring(maxValue))
    end
    if text then
        text:SetText("")
        text:Hide()
    end

    local function ClampValue(value)
        value = tonumber(value) or minValue
        if value < minValue then
            value = minValue
        elseif value > maxValue then
            value = maxValue
        end
        if step and step > 0 then
            value = math.floor((value / step) + 0.5) * step
            if value < minValue then
                value = minValue
            elseif value > maxValue then
                value = maxValue
            end
        end
        return value
    end

    local function RefreshVisual(value)
        value = ClampValue(value)
        valueText:SetText(formatter and formatter(value) or tostring(value))
    end

    slider:SetScript("OnValueChanged", function(_, value, userInput)
        value = ClampValue(value)
        RefreshVisual(value)
        if userInput ~= nil and not userInput then
            return
        end
        if setValue then
            setValue(value)
        end
    end)

    local initialValue = ClampValue(getValue and getValue() or minValue)
    slider:SetValue(initialValue)
    RefreshVisual(initialValue)
    frame.slider = slider

    return frame
end

local function RenderContextSettings(owner, content, y)
    local header = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
    header:SetText("Enable Addon In")
    AddConfigWidget(owner, header)
    y = y - 22

    local currentContext = owner.GetCurrentContextLabel and owner:GetCurrentContextLabel() or "Open World"
    local isEnabled = owner.IsEnabledForCurrentContext and owner:IsEnabledForCurrentContext()

    local status = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    status:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
    status:SetText(string.format("Current context: %s (%s)", currentContext, isEnabled and "enabled" or "disabled"))
    if isEnabled then
        status:SetTextColor(0.55, 1, 0.55)
    else
        status:SetTextColor(1, 0.45, 0.45)
    end
    AddConfigWidget(owner, status)
    y = y - 24

    for index, option in ipairs(CONTEXT_OPTIONS) do
        local checkbox = CreateCheckbox(nil, content, option.label)
        checkbox:SetPoint("TOPLEFT", content, "TOPLEFT", ((index - 1) * 108), y)
        checkbox:SetChecked(owner:IsContextEnabled(option.key))
        checkbox:SetScript("OnClick", function(selfCheck)
            PartyOffCD:SetContextEnabled(option.key, selfCheck:GetChecked())
        end)
        AddConfigWidget(owner, checkbox)
    end
    y = y - 28

    local hint = content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
    hint:SetText("Disabling a context hides cooldowns, interrupts, and missing buffs there.")
    AddConfigWidget(owner, hint)
    y = y - 24

    return y
end

function PartyOffCD:CreateConfigPanel()
    if self.configPanel then
        return
    end

    local frame = CreateFrame("Frame", "PartyOffCDConfigPanel", UIParent)
    frame:SetSize(620, 560)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(selfFrame)
        selfFrame:StopMovingOrSizing()
        local point, _, relativePoint, x, y = selfFrame:GetPoint(1)
        PartyOffCD.db.configPoint = point
        PartyOffCD.db.configRelativePoint = relativePoint
        PartyOffCD.db.configX = x
        PartyOffCD.db.configY = y
    end)

    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.05, 0.05, 0.06, 0.92)

    local borderTop = frame:CreateTexture(nil, "BORDER")
    borderTop:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    borderTop:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    borderTop:SetHeight(2)
    borderTop:SetColorTexture(0.2, 0.7, 0.95, 0.9)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -10)
    title:SetText("PartyOffCD Configuration")

    local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -34)
    subtitle:SetText("MiniCC-style layout controls, cooldown catalog, interrupts, and missing buffs.")

    local tabDefs = {
        { id = "cds", label = "Cooldowns" },
        { id = "interrupts", label = "Interrupts" },
        { id = "buffs", label = "Missing Buffs" },
    }
    frame.tabs = {}
    for index, tabDef in ipairs(tabDefs) do
        local tab = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        tab:SetSize(110, 20)
        tab:SetPoint("TOPLEFT", frame, "TOPLEFT", 12 + ((index - 1) * 114), -56)
        tab:SetText(tabDef.label)
        tab.id = tabDef.id
        tab:SetScript("OnClick", function(selfTab)
            frame.activeTab = selfTab.id
            PartyOffCD:RefreshConfigPanel()
        end)
        frame.tabs[#frame.tabs + 1] = tab
    end

    local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)

    local instructions = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    instructions:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -82)
    instructions:SetText("")
    frame.instructions = instructions

    local scrollFrame = CreateFrame("ScrollFrame", "PartyOffCDConfigScrollFrame", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -104)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -32, 12)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(560, 1)
    scrollFrame:SetScrollChild(content)

    frame.scrollFrame = scrollFrame
    frame.content = content
    frame.activeTab = "cds"
    frame:Hide()

    local db = self.db or DB_DEFAULTS
    frame:SetPoint(db.configPoint or DB_DEFAULTS.configPoint, UIParent, db.configRelativePoint or DB_DEFAULTS.configRelativePoint, db.configX or DB_DEFAULTS.configX, db.configY or DB_DEFAULTS.configY)

    self.configPanel = frame
    self:RefreshConfigPanel()
end

function PartyOffCD:RefreshConfigPanel()
    if not self.configPanel then
        return
    end

    local frame = self.configPanel
    local content = frame.content

    for _, widget in ipairs(self.configRows) do
        widget:Hide()
        widget:SetParent(UIParent)
    end
    wipe(self.configRows)

    local y = -4
    local activeTab = frame.activeTab or "cds"

    for _, tab in ipairs(frame.tabs or {}) do
        local isActive = tab.id == activeTab
        tab:SetEnabled(not isActive)
        tab:SetAlpha(isActive and 1 or 0.7)
    end

    y = RenderContextSettings(self, content, y)
    y = y - 4

    if activeTab == "interrupts" then
        if frame.instructions then
            frame.instructions:SetText("Choose where the addon runs, then adjust the interrupt window.")
        end

        local header = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        header:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
        header:SetText("Interrupts")
        AddConfigWidget(self, header)
        y = y - 26

        local showHide = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
        showHide:SetSize(78, 20)
        showHide:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
        showHide:SetText((self.db.interruptHidden and "Show") or "Hide")
        showHide:SetScript("OnClick", function()
            PartyOffCD:SetInterruptHidden(not PartyOffCD.db.interruptHidden)
            PartyOffCD:RefreshConfigPanel()
        end)
        AddConfigWidget(self, showHide)

        local lock = CreateCheckbox(nil, content, "Lock")
        lock:SetPoint("LEFT", showHide, "RIGHT", 14, 0)
        lock:SetChecked(self.db.interruptLocked == true)
        lock:SetScript("OnClick", function(selfCheck)
            PartyOffCD:SetInterruptLocked(selfCheck:GetChecked())
        end)
        AddConfigWidget(self, lock)
        y = y - 24

        local hint = content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        hint:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
        hint:SetText("Locked: no frame background/title, only interrupt bars.")
        AddConfigWidget(self, hint)

        content:SetHeight(math.max(1, -y + 34))
        return
    end

    if activeTab == "buffs" then
        if frame.instructions then
            frame.instructions:SetText("Choose where the addon runs, then adjust the missing buffs window.")
        end

        local header = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        header:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
        header:SetText("Missing Buffs")
        AddConfigWidget(self, header)
        y = y - 26

        local showHide = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
        showHide:SetSize(78, 20)
        showHide:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
        showHide:SetText((self.db.missingBuffsHidden and "Show") or "Hide")
        showHide:SetScript("OnClick", function()
            PartyOffCD:SetMissingBuffsHidden(not PartyOffCD.db.missingBuffsHidden)
            PartyOffCD:RefreshConfigPanel()
        end)
        AddConfigWidget(self, showHide)

        local lock = CreateCheckbox(nil, content, "Lock")
        lock:SetPoint("LEFT", showHide, "RIGHT", 14, 0)
        lock:SetChecked(self.db.missingBuffsLocked == true)
        lock:SetScript("OnClick", function(selfCheck)
            PartyOffCD:SetMissingBuffsLocked(selfCheck:GetChecked())
        end)
        AddConfigWidget(self, lock)
        y = y - 24

        local hint = content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        hint:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
        hint:SetText("Locked: no frame background/title, only buff icons + MISSING.")
        AddConfigWidget(self, hint)

        content:SetHeight(math.max(1, -y + 34))
        return
    end

    if frame.instructions then
        frame.instructions:SetText("Configure the tracker like MiniCC: grow direction, rows, offsets, size, visible CD types, then manage the spell catalog below.")
    end

    local layoutDivider = CreateDivider(content, 540, "Tracker Display")
    layoutDivider:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
    AddConfigWidget(self, layoutDivider)
    y = y - 26

    local excludeSelf = CreateCheckbox(nil, content, "Exclude Self")
    excludeSelf:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
    excludeSelf:SetChecked(self:IsTrackerExcludeSelfEnabled())
    excludeSelf:SetScript("OnClick", function(selfCheck)
        if PartyOffCD:SetTrackerExcludeSelfEnabled(selfCheck:GetChecked()) then
            PartyOffCD:RefreshTracker()
        end
    end)
    AddConfigWidget(self, excludeSelf)

    local tooltips = CreateCheckbox(nil, content, "Show Tooltips")
    tooltips:SetPoint("LEFT", excludeSelf, "RIGHT", 120, 0)
    tooltips:SetChecked(self:IsTrackerTooltipsEnabled())
    tooltips:SetScript("OnClick", function(selfCheck)
        if PartyOffCD:SetTrackerTooltipsEnabled(selfCheck:GetChecked()) then
            PartyOffCD:RefreshTracker()
        end
    end)
    AddConfigWidget(self, tooltips)

    local reverseSwipe = CreateCheckbox(nil, content, "Reverse Swipe")
    reverseSwipe:SetPoint("LEFT", tooltips, "RIGHT", 120, 0)
    reverseSwipe:SetChecked(self:IsTrackerReverseCooldownEnabled())
    reverseSwipe:SetScript("OnClick", function(selfCheck)
        if PartyOffCD:SetTrackerReverseCooldownEnabled(selfCheck:GetChecked()) then
            PartyOffCD:RefreshTracker()
        end
    end)
    AddConfigWidget(self, reverseSwipe)
    y = y - 24

    local showOffensive = CreateCheckbox(nil, content, "Offensive CDs")
    showOffensive:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
    showOffensive:SetChecked(self:IsTrackerTypeVisible("OFF"))
    showOffensive:SetScript("OnClick", function(selfCheck)
        if PartyOffCD:SetTrackerTypeVisible("OFF", selfCheck:GetChecked()) then
            PartyOffCD:RefreshTracker()
        end
    end)
    AddConfigWidget(self, showOffensive)

    local showDefensive = CreateCheckbox(nil, content, "Defensive CDs")
    showDefensive:SetPoint("LEFT", showOffensive, "RIGHT", 120, 0)
    showDefensive:SetChecked(self:IsTrackerTypeVisible("DEF"))
    showDefensive:SetScript("OnClick", function(selfCheck)
        if PartyOffCD:SetTrackerTypeVisible("DEF", selfCheck:GetChecked()) then
            PartyOffCD:RefreshTracker()
        end
    end)
    AddConfigWidget(self, showDefensive)
    y = y - 28

    local growButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    growButton:SetSize(150, 22)
    growButton:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
    growButton:SetText("Grow: " .. (TRACKER_ATTACH_LABELS[self:GetTrackerAttach()] or "Left"))
    growButton:SetScript("OnClick", function()
        local nextAttach = GetNextCycleValue(PartyOffCD:GetTrackerAttach(), TRACKER_GROW_CYCLE)
        PartyOffCD:SetTrackerAttach(nextAttach)
        PartyOffCD:RefreshConfigPanel()
        PartyOffCD:RefreshTracker()
    end)
    AddConfigWidget(self, growButton)

    local growHint = content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    growHint:SetPoint("LEFT", growButton, "RIGHT", 12, 0)
    growHint:SetText("Default is Left, matching the MiniCC-style anchor.")
    AddConfigWidget(self, growHint)
    y = y - 36

    local sliderWidth = 250

    local iconSizeSlider = CreateSliderControl(
        content,
        "Icon Size",
        10,
        60,
        1,
        sliderWidth,
        function() return PartyOffCD:GetTrackerConfiguredIconSize() end,
        function(value)
            if PartyOffCD:SetTrackerConfiguredIconSize(value) then
                PartyOffCD:RefreshTracker()
            end
        end,
        function(value) return string.format("%d px", value) end
    )
    iconSizeSlider:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
    AddConfigWidget(self, iconSizeSlider)

    local maxIconsSlider = CreateSliderControl(
        content,
        "Max Icons",
        1,
        12,
        1,
        sliderWidth,
        function() return PartyOffCD:GetTrackerMaxIcons() end,
        function(value)
            if PartyOffCD:SetTrackerMaxIcons(value) then
                PartyOffCD:RefreshTracker()
            end
        end
    )
    maxIconsSlider:SetPoint("TOPLEFT", content, "TOPLEFT", 276, y)
    AddConfigWidget(self, maxIconsSlider)
    y = y - 52

    local rowsSlider = CreateSliderControl(
        content,
        "Rows",
        1,
        3,
        1,
        sliderWidth,
        function() return PartyOffCD:GetTrackerRows() end,
        function(value)
            if PartyOffCD:SetTrackerRows(value) then
                PartyOffCD:RefreshTracker()
            end
        end
    )
    rowsSlider:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
    AddConfigWidget(self, rowsSlider)

    local offsetXSlider = CreateSliderControl(
        content,
        "Offset X",
        -250,
        250,
        1,
        sliderWidth,
        function() return PartyOffCD:GetTrackerOffsetX() end,
        function(value)
            if PartyOffCD:SetTrackerOffsetX(value) then
                PartyOffCD:RefreshTracker()
            end
        end
    )
    offsetXSlider:SetPoint("TOPLEFT", content, "TOPLEFT", 276, y)
    AddConfigWidget(self, offsetXSlider)
    y = y - 52

    local offsetYSlider = CreateSliderControl(
        content,
        "Offset Y",
        -250,
        250,
        1,
        sliderWidth,
        function() return PartyOffCD:GetTrackerOffsetY() end,
        function(value)
            if PartyOffCD:SetTrackerOffsetY(value) then
                PartyOffCD:RefreshTracker()
            end
        end
    )
    offsetYSlider:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
    AddConfigWidget(self, offsetYSlider)
    y = y - 62

    local catalogDivider = CreateDivider(content, 540, "Spell Catalog")
    catalogDivider:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
    AddConfigWidget(self, catalogDivider)
    y = y - 24

    local classBuckets = {}
    local classLookup = {}
    for _, classToken in ipairs(CLASS_ORDER) do
        local spellList = {}
        for spellID, meta in pairs(SPELLS) do
            if meta.class == classToken then
                spellList[#spellList + 1] = spellID
            end
        end

        if #spellList > 0 then
            table.sort(spellList, function(a, b)
                local aName = SafeGetSpellInfo(a)
                local bName = SafeGetSpellInfo(b)
                aName = aName or tostring(a)
                bName = bName or tostring(b)
                return aName < bName
            end)

            local _, classIcon = SafeGetSpellInfo(spellList[1])
            local bucket = { classToken = classToken, spellList = spellList, icon = classIcon or 134400 }
            classBuckets[#classBuckets + 1] = bucket
            classLookup[classToken] = bucket
        end
    end

    if #classBuckets == 0 then
        local empty = content:CreateFontString(nil, "OVERLAY", "GameFontDisable")
        empty:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
        empty:SetText("No spells available.")
        self.configRows[#self.configRows + 1] = empty
        content:SetHeight(math.max(1, -y + 32))
        return
    end

    if not self.selectedClassToken or not classLookup[self.selectedClassToken] then
        self.selectedClassToken = classBuckets[1].classToken
    end

    local selectedClassToken = self.selectedClassToken
    local selectedBucket = classLookup[selectedClassToken]

    local panelTopY = y
    local leftX = 0
    local leftWidth = 124
    local rightX = 138

    local classesHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    classesHeader:SetPoint("TOPLEFT", content, "TOPLEFT", leftX, panelTopY)
    classesHeader:SetText("Classes")
    self.configRows[#self.configRows + 1] = classesHeader

    local leftY = panelTopY - 20
    for _, bucket in ipairs(classBuckets) do
        local isSelected = bucket.classToken == selectedClassToken
        local row = CreateFrame("Button", nil, content)
        row:SetSize(leftWidth, 20)
        row:SetPoint("TOPLEFT", content, "TOPLEFT", leftX, leftY)
        row:SetScript("OnClick", function()
            PartyOffCD.selectedClassToken = bucket.classToken
            PartyOffCD:RefreshConfigPanel()
        end)
        self.configRows[#self.configRows + 1] = row

        local rowBg = row:CreateTexture(nil, "BACKGROUND")
        rowBg:SetAllPoints()
        if isSelected then
            rowBg:SetColorTexture(0.62, 0.05, 0.07, 0.92)
        else
            rowBg:SetColorTexture(0.10, 0.10, 0.10, 0.82)
        end
        self.configRows[#self.configRows + 1] = rowBg

        local rowBorder = row:CreateTexture(nil, "BORDER")
        rowBorder:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
        rowBorder:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
        rowBorder:SetHeight(1)
        if isSelected then
            rowBorder:SetColorTexture(0.95, 0.82, 0.2, 0.9)
        else
            rowBorder:SetColorTexture(0.35, 0.35, 0.35, 0.6)
        end
        self.configRows[#self.configRows + 1] = rowBorder

        local rowIcon = row:CreateTexture(nil, "ARTWORK")
        rowIcon:SetSize(14, 14)
        rowIcon:SetPoint("LEFT", row, "LEFT", 4, 0)
        rowIcon:SetTexture(bucket.icon or 134400)
        self.configRows[#self.configRows + 1] = rowIcon

        local rowLabel = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        rowLabel:SetPoint("LEFT", rowIcon, "RIGHT", 5, 0)
        rowLabel:SetWidth(leftWidth - 26)
        rowLabel:SetJustifyH("LEFT")
        rowLabel:SetText(self:GetClassLabel(bucket.classToken))
        if isSelected then
            rowLabel:SetTextColor(1, 0.96, 0.2)
        else
            rowLabel:SetTextColor(0.85, 0.85, 0.85)
        end
        self.configRows[#self.configRows + 1] = rowLabel

        if not isSelected then
            row:SetScript("OnEnter", function()
                rowBg:SetColorTexture(0.16, 0.16, 0.16, 0.92)
            end)
            row:SetScript("OnLeave", function()
                rowBg:SetColorTexture(0.10, 0.10, 0.10, 0.82)
            end)
        end

        leftY = leftY - 22
    end

    local spellsHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    spellsHeader:SetPoint("TOPLEFT", content, "TOPLEFT", rightX, panelTopY)
    spellsHeader:SetText("Spells: " .. self:GetClassLabel(selectedClassToken))
    self.configRows[#self.configRows + 1] = spellsHeader

    local rightY = panelTopY - 20

    local classCheck = CreateCheckbox(nil, content, "")
    classCheck:SetPoint("TOPLEFT", content, "TOPLEFT", rightX, rightY)
    classCheck:SetChecked(self.db.classEnabled[selectedClassToken] ~= false)
    classCheck:SetScript("OnClick", function(selfCheck)
        PartyOffCD:SetClassEnabled(selectedClassToken, selfCheck:GetChecked())
        PartyOffCD:RefreshConfigPanel()
    end)
    self.configRows[#self.configRows + 1] = classCheck

    local classCheckLabel = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    classCheckLabel:SetPoint("LEFT", classCheck, "RIGHT", 2, 0)
    classCheckLabel:SetText("Enable class")
    self.configRows[#self.configRows + 1] = classCheckLabel

    local addButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    addButton:SetSize(76, 20)
    addButton:SetPoint("TOPLEFT", content, "TOPLEFT", rightX + 158, rightY + 1)
    addButton:SetText(self.classAddEditorState[selectedClassToken] and "Close" or "Add New")
    addButton:SetScript("OnClick", function()
        PartyOffCD.classAddEditorState[selectedClassToken] = not PartyOffCD.classAddEditorState[selectedClassToken]
        PartyOffCD:RefreshConfigPanel()
    end)
    self.configRows[#self.configRows + 1] = addButton
    rightY = rightY - 24

    if self.classAddEditorState[selectedClassToken] then
        local spellIDBox = CreateNumericEditBox(nil, content, 54, 8)
        spellIDBox:SetPoint("TOPLEFT", content, "TOPLEFT", rightX, rightY)
        spellIDBox:SetText("")
        self.configRows[#self.configRows + 1] = spellIDBox

        local spellIDLabel = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        spellIDLabel:SetPoint("LEFT", spellIDBox, "RIGHT", 4, 0)
        spellIDLabel:SetText("ID")
        self.configRows[#self.configRows + 1] = spellIDLabel

        local cdBox = CreateNumericEditBox(nil, content, 40, 5)
        cdBox:SetPoint("TOPLEFT", content, "TOPLEFT", rightX + 106, rightY)
        cdBox:SetText("90")
        self.configRows[#self.configRows + 1] = cdBox

        local cdLabel = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        cdLabel:SetPoint("LEFT", cdBox, "RIGHT", 4, 0)
        cdLabel:SetText("CD")
        self.configRows[#self.configRows + 1] = cdLabel
        rightY = rightY - 24

        local offCheck = CreateCheckbox(nil, content, "Offensive")
        offCheck:SetPoint("TOPLEFT", content, "TOPLEFT", rightX, rightY)
        offCheck:SetChecked(true)
        self.configRows[#self.configRows + 1] = offCheck

        local defCheck = CreateCheckbox(nil, content, "Defensive")
        defCheck:SetPoint("LEFT", offCheck, "RIGHT", 10, 0)
        defCheck:SetChecked(false)
        self.configRows[#self.configRows + 1] = defCheck

        offCheck:SetScript("OnClick", function(selfCheck)
            if selfCheck:GetChecked() then
                defCheck:SetChecked(false)
            else
                selfCheck:SetChecked(true)
            end
        end)

        defCheck:SetScript("OnClick", function(selfCheck)
            if selfCheck:GetChecked() then
                offCheck:SetChecked(false)
            else
                selfCheck:SetChecked(true)
            end
        end)

        local saveNewButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
        saveNewButton:SetSize(50, 18)
        saveNewButton:SetPoint("TOPLEFT", content, "TOPLEFT", rightX + 220, rightY + 2)
        saveNewButton:SetText("Save")
        saveNewButton:SetScript("OnClick", function()
            local spellType = offCheck:GetChecked() and "OFF" or "DEF"
            if PartyOffCD:AddCustomSpell(selectedClassToken, spellIDBox:GetText(), cdBox:GetText(), spellType) then
                PartyOffCD.classAddEditorState[selectedClassToken] = false
                PartyOffCD:RefreshConfigPanel()
            end
        end)
        self.configRows[#self.configRows + 1] = saveNewButton
        rightY = rightY - 24
    end

    for _, spellID in ipairs(selectedBucket.spellList) do
        local spellName, texture = SafeGetSpellInfo(spellID)
        local meta = self:GetDisplayMeta(spellID) or SPELLS[spellID]

        local spellCheck = CreateCheckbox(nil, content, "")
        spellCheck:SetPoint("TOPLEFT", content, "TOPLEFT", rightX, rightY)
        spellCheck:SetChecked(self:IsSpellEnabled(spellID))
        spellCheck:SetEnabled(self.db.classEnabled[selectedClassToken] ~= false)
        spellCheck:SetScript("OnClick", function(selfCheck)
            PartyOffCD:SetSpellEnabled(spellID, selfCheck:GetChecked())
        end)
        self.configRows[#self.configRows + 1] = spellCheck

        local icon = content:CreateTexture(nil, "ARTWORK")
        icon:SetSize(18, 18)
        icon:SetPoint("LEFT", spellCheck, "RIGHT", 2, 0)
        icon:SetTexture(texture or 134400)
        self.configRows[#self.configRows + 1] = icon

        local label = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("LEFT", icon, "RIGHT", 6, 0)
        local playerOverride = self:GetPlayerOverride(spellID, self:GetPlayerCanonical())
        local canDeleteCustom = not BASE_SPELLS[spellID] and self.db.customSpells and self.db.customSpells[spellID]
        local customSuffix = meta.custom and ", custom" or ""
        local overrideSuffix = playerOverride and ", override" or ""
        label:SetWidth(230)
        label:SetJustifyH("LEFT")
        label:SetText(string.format("%s (%ss, id %d%s%s)", spellName or ("Spell " .. spellID), meta.cd, spellID, customSuffix, overrideSuffix))
        if self.db.classEnabled[selectedClassToken] == false then
            label:SetTextColor(0.55, 0.55, 0.55)
        else
            label:SetTextColor(0.9, 0.9, 0.9)
        end
        self.configRows[#self.configRows + 1] = label

        local editButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
        editButton:SetSize(36, 18)
        editButton:SetPoint("TOPLEFT", content, "TOPLEFT", rightX + 286, rightY + 1)
        editButton:SetText("Edit")
        self.configRows[#self.configRows + 1] = editButton

        local editBox = CreateNumericEditBox(nil, content, 30, 5)
        editBox:SetPoint("TOPLEFT", content, "TOPLEFT", rightX + 286, rightY)
        editBox:SetText(tostring(meta.cd))
        editBox:Hide()
        self.configRows[#self.configRows + 1] = editBox

        local saveButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
        saveButton:SetSize(36, 18)
        saveButton:SetPoint("TOPLEFT", content, "TOPLEFT", rightX + 326, rightY + 1)
        saveButton:SetText("Save")
        saveButton:Hide()
        self.configRows[#self.configRows + 1] = saveButton

        local deleteButton
        if canDeleteCustom then
            deleteButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
            deleteButton:SetSize(50, 18)
            deleteButton:SetPoint("TOPLEFT", content, "TOPLEFT", rightX + 368, rightY + 1)
            deleteButton:SetText("Delete")
            deleteButton:SetScript("OnClick", function()
                PartyOffCD:DeleteCustomSpell(spellID)
            end)
            self.configRows[#self.configRows + 1] = deleteButton
        end

        editButton:SetScript("OnClick", function()
            editBox:SetText(tostring((PartyOffCD:GetDisplayMeta(spellID) or meta).cd))
            editButton:Hide()
            editBox:Show()
            saveButton:Show()
            if deleteButton then
                deleteButton:Hide()
            end
        end)

        saveButton:SetScript("OnClick", function()
            local newCooldown = tonumber(editBox:GetText())
            if not newCooldown or newCooldown <= 0 then
                DebugPrint("Enter a valid CD in seconds.")
                return
            end

            if PartyOffCD:AddCustomSpell(meta.class, spellID, newCooldown, meta.type) then
                editBox:Hide()
                saveButton:Hide()
                editButton:Show()
                if deleteButton then
                    deleteButton:Show()
                end
            end
        end)

        rightY = rightY - 22
    end

    rightY = rightY - 8
    y = math.min(leftY, rightY)
    content:SetHeight(math.max(1, -y + 10))
end

function PartyOffCD:ToggleConfigPanel()
    self:CreateConfigPanel()
    if self.configPanel:IsShown() then
        self.configPanel:Hide()
    else
        self:RefreshConfigPanel()
        self.configPanel:Show()
    end
end

function PartyOffCD:UpdateMinimapButtonPosition()
    if not self.minimapButton then
        return
    end

    local angle = self.db.minimap.angle or 220
    local radians = math.rad(angle)
    local x = math.cos(radians) * MINIMAP_RADIUS
    local y = math.sin(radians) * MINIMAP_RADIUS
    self.minimapButton:ClearAllPoints()
    self.minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

function PartyOffCD:RefreshMinimapButton()
    if not self.minimapButton then
        return
    end

    self.minimapButton:Show()
    self:UpdateMinimapButtonPosition()
end

function PartyOffCD:CreateMinimapButton()
    if self.minimapButton then
        return
    end

    local button = CreateFrame("Button", "PartyOffCDMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetMovable(true)
    button:EnableMouse(true)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHitRectInsets(4, 4, 4, 4)

    local bg = button:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture("Interface\\Minimap\\MiniMap-TrackingBackground")
    button.bg = bg

    local texture = button:CreateTexture(nil, "ARTWORK")
    texture:SetSize(20, 20)
    texture:SetPoint("CENTER", button, "CENTER", 0, 1)
    texture:SetTexture(136116)
    if texture.SetMask then
        texture:SetMask("Interface\\CharacterFrame\\TempPortraitAlphaMaskSmallCircle")
    end
    button.icon = texture

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetAllPoints()
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    button.border = border

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    highlight:SetBlendMode("ADD")
    button.highlight = highlight

    button:SetScript("OnClick", function()
        PartyOffCD:ToggleConfigPanel()
    end)

    button:SetScript("OnDragStart", function()
        button.isDragging = true
    end)

    button:SetScript("OnDragStop", function()
        button.isDragging = false
    end)

    button:SetScript("OnUpdate", function(selfButton)
        if not selfButton.isDragging then
            return
        end

        local mx, my = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        local cx, cy = Minimap:GetCenter()
        local dx = (mx / scale) - cx
        local dy = (my / scale) - cy
        local angle = math.deg(math.atan2(dy, dx))
        PartyOffCD.db.minimap.angle = angle
        PartyOffCD:UpdateMinimapButtonPosition()
    end)

    button:SetScript("OnEnter", function(selfButton)
        GameTooltip:SetOwner(selfButton, "ANCHOR_LEFT")
        GameTooltip:AddLine("PartyOffCD")
        GameTooltip:AddLine("Click: configuration", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Drag: move icon", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    self.minimapButton = button
    self:RefreshMinimapButton()
end

function PartyOffCD:RunTest()
    local samples = { 31884, 97462, 190319 }
    for _, spellID in ipairs(samples) do
        if self:IsSpellEnabled(spellID) then
            self:ReportSpellUse(spellID, true)
        end
    end
    DebugPrint("Test triggered with sample local timers.")
end

function PartyOffCD:PrintConfig()
    local channel = self:GetTargetChannel() or "NONE"
    local inGroup = (IsInGroup() or IsInRaid()) and "yes" or "no"
    local configShown = (self.configPanel and self.configPanel:IsShown()) and "shown" or "hidden"
    local minimapShown = "shown"
    local contextLabel = self.GetCurrentContextLabel and self:GetCurrentContextLabel() or "Open World"
    local contextEnabled = (self.IsEnabledForCurrentContext and self:IsEnabledForCurrentContext()) and "enabled" or "disabled"

    DebugPrint("Prefix: " .. PREFIX .. " | Channel: " .. channel .. " | InGroup: " .. inGroup)
    DebugPrint("Context: " .. contextLabel .. " | Addon: " .. contextEnabled)
    DebugPrint("Active spells: " .. tostring(self:GetEnabledSpellCount()) .. "/" .. tostring(self:GetSupportedSpellCount()))
    DebugPrint("Config: " .. configShown .. " | Minimap: " .. minimapShown)
    DebugPrint("Commands: /pocd use <spellID>, /pocd timer <spellID> <sec>, /pocd test, /pocd config, /pocd buffs, /pocd interrupts")
    DebugPrint("UI: Use + per class to add spells, and Edit/Save per row to keep your personal CD.")
end

function PartyOffCD:GetSupportedSpellCount()
    local count = 0
    for _ in pairs(SPELLS) do
        count = count + 1
    end
    return count
end

function PartyOffCD:GetEnabledSpellCount()
    local count = 0
    for spellID in pairs(SPELLS) do
        if self:IsSpellEnabled(spellID) then
            count = count + 1
        end
    end
    return count
end

function PartyOffCD:HandleSlashCommand(input)
    local command, rest = strsplit(" ", (input or ""), 2)
    command = string.lower(command or "")
    rest = rest and strtrim(rest) or ""

    if command == "use" then
        local spellID = tonumber(rest)
        if not spellID then
            DebugPrint("Usage: /pocd use <spellID>")
            return
        end

        self:ReportSpellUse(spellID)
        return
    end

    if command == "test" then
        self:RunTest()
        return
    end

    if command == "timer" then
        local spellIDText, remainingText = strsplit(" ", rest, 2)
        local spellID = tonumber(spellIDText)
        local remaining = tonumber(remainingText)
        if not spellID or remaining == nil then
            DebugPrint("Usage: /pocd timer <spellID> <remainingSeconds>")
            return
        end

        local playerKey = self:GetPlayerCanonical()
        if not playerKey then
            DebugPrint("Could not identify your character.")
            return
        end

        if not self:SetRemainingCooldown(playerKey, spellID, remaining) then
            DebugPrint("Could not adjust that timer.")
        end
        return
    end

    if command == "buffs" then
        self:SetMissingBuffsHidden(not self.db.missingBuffsHidden)
        if self.db.missingBuffsHidden then
            DebugPrint("Missing buffs window hidden.")
        else
            DebugPrint("Missing buffs window shown.")
        end
        return
    end

    if command == "interrupts" then
        self:SetInterruptHidden(not self.db.interruptHidden)
        if self.db.interruptHidden then
            DebugPrint("Interrupts window hidden.")
        else
            DebugPrint("Interrupts window shown.")
        end
        return
    end

    if command == "config" or command == "" then
        self:PrintConfig()
        self:ToggleConfigPanel()
        return
    end

    DebugPrint("Unknown command: " .. tostring(command))
    self:PrintConfig()
end

