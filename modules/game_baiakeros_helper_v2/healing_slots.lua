BaiakHelperHealingSlotsV2 = {}

local function copyVisible(target, source)
    if target and source then target:setVisible(source:isVisible()) end
end

local function bindThresholdButton(button, slotId, delta)
    button.onClick = nil
    g_mouse.bindAutoPress(button, function()
        if button:isEnabled() then
            modules.game_baiakeros_helper.changeThreshold(slotId, delta)
        end
    end, 350, MouseLeftButton, 80)
end

local function syncSlot(window, sourceWindow, slotId)
    local source = sourceWindow:recursiveGetChildById(slotId)
    local target = window:recursiveGetChildById(slotId)
    if not source or not target then return end

    target.threshold = source.threshold
    target.resource = source.resource
    target.assignedSpell = source.assignedSpell
    target.assignedPotion = source.assignedPotion

    local sourceSpell = source:recursiveGetChildById('spellIcon')
    local targetSpell = target:recursiveGetChildById('spellIcon')
    if sourceSpell and targetSpell then
        targetSpell:setImageSource(sourceSpell:getImageSource())
        targetSpell:setImageClip(sourceSpell:getImageClip())
        copyVisible(targetSpell, sourceSpell)
    end

    local sourceItem = source:recursiveGetChildById('itemIcon')
    local targetItem = target:recursiveGetChildById('itemIcon')
    if sourceItem and targetItem then
        targetItem:setItemId(sourceItem:getItemId())
        copyVisible(targetItem, sourceItem)
    end

    local sourceLabel = source:recursiveGetChildById('thresholdLabel')
    local targetLabel = target:recursiveGetChildById('thresholdLabel')
    if sourceLabel and targetLabel then targetLabel:setText(sourceLabel:getText()) end

    local sourceResource = source:recursiveGetChildById('resourceButton')
    local targetResource = target:recursiveGetChildById('resourceButton')
    if sourceResource and targetResource then
        targetResource:setText(sourceResource:getText())
        targetResource:setColor(sourceResource:getColor())
        targetResource:setTooltip(sourceResource:getTooltip())
        copyVisible(targetResource, sourceResource)
    end

    local sourceAssign = source:recursiveGetChildById('assignButton')
    local targetAssign = target:recursiveGetChildById('assignButton')
    if sourceAssign and targetAssign then
        targetAssign:setTooltip(sourceAssign:getTooltip())
        targetAssign:setBorderWidth(source.assignedPotion and 1 or 0)
        targetAssign:setBorderColor(source.assignedPotion and
            (source.resource == 'mana' and '#2e7fd0' or '#b83c3c') or 'alpha')
    end
end

function BaiakHelperHealingSlotsV2.sync(window, sourceWindow)
    for index = 1, 3 do
        syncSlot(window, sourceWindow, 'spellSlot' .. index)
        syncSlot(window, sourceWindow, 'potionSlot' .. index)
    end
end

function BaiakHelperHealingSlotsV2.bind(window)
    for index = 1, 3 do
        for _, kind in ipairs({ 'spell', 'potion' }) do
            local slotId = kind .. 'Slot' .. index
            local slot = window:recursiveGetChildById(slotId)
            local assign = slot:recursiveGetChildById('assignButton')
            local decrease = slot:recursiveGetChildById('decreaseButton')
            local increase = slot:recursiveGetChildById('increaseButton')
            local resource = slot:recursiveGetChildById('resourceButton')

            assign.onMouseRelease = function(_, position, button)
                local module = modules.game_baiakeros_helper
                if kind == 'spell' then
                    return module.showSpellMenu(slotId, position, button)
                end
                return module.showPotionMenu(slotId, position, button)
            end
            bindThresholdButton(decrease, slotId, -1)
            bindThresholdButton(increase, slotId, 1)
            if kind == 'potion' then
                resource.onClick = function()
                    modules.game_baiakeros_helper.togglePotionResource(slotId)
                end
            end
        end
    end
end
