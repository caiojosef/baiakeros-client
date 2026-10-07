-- @docclass
UIStatsBar = extends(UIWidget, 'UIStatsBar')

-- Keep the original arc's bands (floor(percent) > 92/60/30/8/3) in both
-- displays. Texture suffixes name the assets, not the new HP thresholds.
-- Colors match their base fill, without the texture's gradient highlights.
local healthAppearances = {
    {minimum = 93, suffix = '100', color = '#00AF00'},
    {minimum = 61, suffix = '95', color = '#649204'},
    {minimum = 31, suffix = '60', color = '#B88C08'},
    {minimum = 9, suffix = '30', color = '#AF2C2C'},
    {minimum = 4, suffix = '10', color = '#AF0000'},
    {minimum = 0, suffix = '4', color = '#570000'}
}

function UIStatsBar.getHealthAppearance(value, total)
    local percent = total and total > 0 and math.min(100, math.max(0, (value or 0) * 100 / total)) or 0
    for _, appearance in ipairs(healthAppearances) do
        if percent >= appearance.minimum then return appearance, percent end
    end
end

function UIStatsBar.create()
    local stats = UIStatsBar.internalCreate()
    stats.bar = stats:getChildById('bar')
    stats.text = stats:getChildById('text')
    stats.onGeometryChange = function()
        stats:setValue(stats.currentValue, stats.currentTotal)
        stats:reloadBorder()
    end
    return stats
end

function UIStatsBar:reloadBorder()
    if not self.grade then
        if self.statsOrientation == 'horizontal' then
            self.grade = self:getChildById('horizontalGrade')
        elseif self.statsOrientation == 'vertical' then
            self.grade = self:getChildById('verticalGrade')
        end
    end

    for _, child in ipairs(self.grade:getChildren()) do
        if string.len(tostring(child:getId())) >= 6 and string.sub(tostring(child:getId()), 1, 6) == "grade_" then
            child:hide()
        end
    end

    if not self.statsGradeColor then
        self.grade:hide()
        return
    end

    self.grade:show()

    -- Borders
    for _, child in ipairs(self.grade:getChildren()) do
        if string.len(child:getId()) >= 13 and string.sub(child:getId(), 1, 13) == 'grade_border_' then
            child:show()
            child:setBackgroundColor(self.statsGradeColor)
        end
    end

    -- Markers
    local markerOffset = 3
    for _, child in ipairs(self.grade:getChildren()) do
        if self.statsGrade == 3 then
            if child:getId() == 'grade_left_1' then
                child:show()
                if self.statsOrientation == 'horizontal' then
                    child:setMarginLeft(((self:getWidth() - 2) * 0.33) - markerOffset)
                else
                    child:setMarginTop(((self:getHeight() - 2) * 0.33) - markerOffset)
                end
            elseif child:getId() == 'grade_right_1' then
                child:show()
                if self.statsOrientation == 'horizontal' then
                    child:setMarginRight(((self:getWidth() - 2) * 0.33) - markerOffset)
                else
                    child:setMarginBottom(((self:getHeight() - 2) * 0.33) - markerOffset)
                end
            end
        elseif self.statsGrade == 4 then
            if child:getId() == 'grade_left_1' then
                child:show()
                if self.statsOrientation == 'horizontal' then
                    child:setMarginLeft(((self:getWidth() - 2) * 0.25) - markerOffset)
                else
                    child:setMarginTop(((self:getHeight() - 2) * 0.25) - markerOffset)
                end
            elseif child:getId() == 'grade_left_2' then
                child:show()
                if self.statsOrientation == 'horizontal' then
                    child:setMarginLeft(((self:getWidth() - 2) * 0.5) - markerOffset)
                else
                    child:setMarginTop(((self:getHeight() - 2) * 0.5) - markerOffset)
                end
            elseif child:getId() == 'grade_right_1' then
                child:show()
                if self.statsOrientation == 'horizontal' then
                    child:setMarginRight(((self:getWidth() - 2) * 0.25) - markerOffset)
                else
                    child:setMarginBottom(((self:getHeight() - 2) * 0.25) - markerOffset)
                end
            end
        end
    end
end

function UIStatsBar:onStyleApply(styleName, styleNode)
    for name, value in pairs(styleNode) do
        if name == 'statsbar-type' then
            self.statsType = value
        elseif name == 'statsbar-size' then
            self.statsSize = value
        elseif name == 'statsbar-text' then
            self.showText = value
        elseif name == 'statsbar-orientation' then
            self.statsOrientation = value
        elseif name == 'statsbar-grade' then
            self.statsGrade = value
        elseif name == 'statsbar-gradecolor' then
            self.statsGradeColor = value
        end
    end
end

function UIStatsBar:setValue(value, total)
    if not (value) or not (total) or total == 0 or not (self.statsType) or not (self.statsSize) or not (self.statsOrientation) then
        return
    end

    value = math.min(total, math.max(0, value))
    self.currentValue = value
    self.currentTotal = total

    -- Bar dimension
    if self.statsOrientation == 'horizontal' then
        self.bar:setWidth(((self:getWidth() - 2) * value) / total)
    elseif self.statsOrientation == 'vertical' then
        self.bar:setHeight(((self:getHeight() - 2) * value) / total)
    else
        return
    end

    -- Bar color
    if self.statsType == 'health' then
        local appearance = UIStatsBar.getHealthAppearance(value, total)
        self.bar:setImageSource('/images/bars/' .. self.statsOrientation ..
            '_health_progressbar_' .. self.statsSize .. '_' .. appearance.suffix)
    elseif self.statsType == 'mana' then
        self.bar:setImageSource('/images/bars/' .. self.statsOrientation .. '_mana_progressbar_' .. self.statsSize)
    elseif self.statsType == 'manashield' then
        self.bar:setImageSource('/images/bars/' .. self.statsOrientation .. '_manashield_progressbar_' .. self.statsSize)
    elseif self.statsType == 'experience' then
        self.bar:setImageSource('/images/bars/' .. self.statsOrientation .. '_experience_progressbar_' .. self.statsSize)
    elseif self.statsType == 'skill' then
        self.bar:setImageSource('/images/bars/' .. self.statsOrientation .. '_skill_progressbar_' .. self.statsSize)
    end

    -- Text
    if self.showText then
        self.text:show()
        if self.manaShieldText then
            self.text:setText(self.manaShieldText)
        else
            self.text:setText(value .. '/' .. total)
        end
    else
        self.text:hide()
    end
end
