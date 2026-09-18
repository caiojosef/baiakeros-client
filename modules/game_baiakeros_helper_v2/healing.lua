BaiakHelperHealingV2 = {}

local helperWindow = nil
local syncEvent = nil
local updating = false

local function legacy()
    return modules.game_baiakeros_helper
end

local function legacyWindow()
    local module = legacy()
    return module and module.helperWindow
end

local function copyVisible(target, source)
    if target and source then
        target:setVisible(source:isVisible())
    end
end

local function copySlot(slotId)
    local sourceWindow = legacyWindow()
    if not sourceWindow or not helperWindow then return end
    local source = sourceWindow:recursiveGetChildById(slotId)
    local target = helperWindow:recursiveGetChildById(slotId)
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

    copyVisible(target:recursiveGetChildById('emptyDecoration'),
        source:recursiveGetChildById('emptyDecoration'))

    local sourceLabel = source:recursiveGetChildById('thresholdLabel')
    local targetLabel = target:recursiveGetChildById('thresholdLabel')
    if sourceLabel and targetLabel then
        targetLabel:setText(sourceLabel:getText())
    end

    local sourceResource = source:recursiveGetChildById('resourceButton')
    local targetResource = target:recursiveGetChildById('resourceButton')
    if sourceResource and targetResource then
        targetResource:setText(sourceResource:getText())
        targetResource:setColor(sourceResource:getColor())
        copyVisible(targetResource, sourceResource)
    end

    local sourceAssign = source:recursiveGetChildById('assignButton')
    local targetAssign = target:recursiveGetChildById('assignButton')
    if sourceAssign and targetAssign then
        targetAssign:setTooltip(sourceAssign:getTooltip())
    end
end

local function copyPreset()
    local sourceWindow = legacyWindow()
    if not sourceWindow or not helperWindow then return end
    local source = sourceWindow:recursiveGetChildById('helperPresetBox')
    local target = helperWindow:recursiveGetChildById('v2HealingPresetBox')
    if not source or not target then return end

    local sourceOption = source:getCurrentOption()
    local changed = #target.options ~= #source.options
    if not changed then
        for index, option in ipairs(source.options) do
            local current = target.options[index]
            if not current or current.text ~= option.text or current.data ~= option.data then
                changed = true
                break
            end
        end
    end

    updating = true
    if changed then
        target:clearOptions()
        for _, option in ipairs(source.options) do
            target:addOption(option.text, option.data)
        end
    end
    if sourceOption then
        target:setCurrentOptionByData(sourceOption.data, true)
    end
    updating = false
end

function BaiakHelperHealingV2.sync()
    if not helperWindow then return end
    copyPreset()
    for index = 1, 3 do
        copySlot('spellSlot' .. index)
        copySlot('potionSlot' .. index)
    end

    local sourceWindow = legacyWindow()
    if sourceWindow and helperWindow:isVisible() and sourceWindow:isVisible() then
        sourceWindow:hide()
    end
    local source = sourceWindow and sourceWindow:recursiveGetChildById('healingEnabledBox')
    local target = helperWindow:recursiveGetChildById('v2HealingEnabledBox')
    if source and target and source:isChecked() ~= target:isChecked() then
        updating = true
        target:setChecked(source:isChecked())
        updating = false
    end

    syncEvent = scheduleEvent(BaiakHelperHealingV2.sync, 150)
end

function BaiakHelperHealingV2.init(window)
    helperWindow = window
    local module = legacy()
    if not helperWindow or not module then return end

    local preset = helperWindow:recursiveGetChildById('v2HealingPresetBox')
    preset.onOptionChange = function(_, _, data)
        if not updating and data then module.setHelperPreset(data) end
    end

    local enabled = helperWindow:recursiveGetChildById('v2HealingEnabledBox')
    enabled.onCheckChange = function(_, checked)
        if not updating then module.setHealingEnabled(checked) end
    end

    for index = 1, 3 do
        for _, kind in ipairs({ 'spell', 'potion' }) do
            local slotKind = kind
            local slotId = slotKind .. 'Slot' .. index
            local capturedSlotId = slotId
            local slot = helperWindow:recursiveGetChildById(capturedSlotId)
            local assign = slot:recursiveGetChildById('assignButton')
            local decrease = slot:recursiveGetChildById('decreaseButton')
            local increase = slot:recursiveGetChildById('increaseButton')
            assign.onMouseRelease = function(_, position, button)
                if slotKind == 'spell' then
                    return module.showSpellMenu(capturedSlotId, position, button)
                end
                return module.showPotionMenu(capturedSlotId, position, button)
            end
            decrease.onClick = function()
                module.changeThreshold(capturedSlotId, -1)
            end
            increase.onClick = function()
                module.changeThreshold(capturedSlotId, 1)
            end
        end
    end

    BaiakHelperHealingV2.sync()
end

function BaiakHelperHealingV2.terminate()
    if syncEvent then removeEvent(syncEvent) end
    syncEvent = nil
    helperWindow = nil
end


