BaiakHelperHealingSlotsV2 = {}

local function bindThresholdButton(button, slotId, delta)
    button.onClick = nil
    g_mouse.bindAutoPress(button, function()
        if button:isEnabled() then
            modules.game_baiakeros_helper.changeThreshold(slotId, delta)
        end
    end, 350, MouseLeftButton, 80)
end

local function renderSlot(slot, state)
    if not slot or not state then return end

    local assign = slot:recursiveGetChildById('assignButton')
    local spellIcon = slot:recursiveGetChildById('spellIcon')
    local itemIcon = slot:recursiveGetChildById('itemIcon')
    local resourceButton = slot:recursiveGetChildById('resourceButton')
    local thresholdLabel = slot:recursiveGetChildById('thresholdLabel')
    local spell, potion = state.spell, state.potion

    thresholdLabel:setText(tostring(state.threshold) .. '%')
    assign:setEnabled(state.available)
    spellIcon:setVisible(spell ~= nil)
    itemIcon:setVisible(potion ~= nil)

    if spell then
        spellIcon:setImageSource(Spells.getIconFileByProfile('Default', spell.clientId))
        spellIcon:setImageClip(Spells.getImageClip(spell.clientId, 'Default'))
        assign:setTooltip(string.format('%s\n%s\nLevel %d | Mana %d',
            spell.name, spell.words, spell.level or 0, spell.mana or 0))
    elseif potion then
        itemIcon:setItemId(potion.id)
        assign:setTooltip(potion.name .. '\nRight-click to change or clear')
    else
        assign:setTooltip(slot:getId():sub(1, 6) == 'potion' and
            'Right-click to assign a healing potion' or
            'Right-click to assign a healing spell')
    end

    local resource = state.resource or 'health'
    assign:setBorderWidth(potion and 1 or 0)
    assign:setBorderColor(potion and
        (resource == 'mana' and '#2e7fd0' or '#b83c3c') or 'alpha')
    if potion then
        resourceButton:setText(resource == 'mana' and 'M' or 'H')
        resourceButton:setColor(resource == 'mana' and '#57a8ff' or '#ed6464')
        resourceButton:setBorderColor(resource == 'mana' and '#2e7fd0' or '#b83c3c')
        resourceButton:setTooltip(resource == 'mana' and
            'Mana mode: trigger using mana percentage' or
            'Health mode: trigger using health percentage')
    end
    resourceButton:setVisible(potion ~= nil and
        potion.resources.health and potion.resources.mana or false)
end

function BaiakHelperHealingSlotsV2.render(window, states)
    for index = 1, 3 do
        for _, kind in ipairs({ 'spell', 'potion' }) do
            local slotId = kind .. 'Slot' .. index
            renderSlot(window:recursiveGetChildById(slotId), states[slotId])
        end
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
                local helper = modules.game_baiakeros_helper
                if kind == 'spell' then
                    return helper.showSpellMenu(slotId, position, button)
                end
                return helper.showPotionMenu(slotId, position, button)
            end
            if kind == 'potion' then
                local itemIcon = slot:recursiveGetChildById('itemIcon')
                itemIcon:setPhantom(false)
                itemIcon.onMouseRelease = assign.onMouseRelease
                resource.onClick = function()
                    modules.game_baiakeros_helper.togglePotionResource(slotId)
                end
            end
            bindThresholdButton(decrease, slotId, -1)
            bindThresholdButton(increase, slotId, 1)
        end
    end
end
