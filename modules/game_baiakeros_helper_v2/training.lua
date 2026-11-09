BaiakHelperTrainingV2 = {}

local window
local syncEvent
local updating = false

local function legacy()
    return modules.game_baiakeros_helper
end

local function bindSlot(widgetId, callback)
    local slot = window:recursiveGetChildById(widgetId)
    slot.onMouseRelease = function(_, position, button)
        return callback(position, button)
    end
    return slot
end

function BaiakHelperTrainingV2.sync()
    if not window then return end
    local module = legacy()
    local state = module and module.getTrainingState and module.getTrainingState()
    if state then
        local exerciseSlot = window:recursiveGetChildById('v2ExerciseWeaponSlot')
        local exerciseIcon = window:recursiveGetChildById('v2ExerciseWeaponIcon')
        local exerciseMode = window:recursiveGetChildById('v2ExerciseModeBox')
        exerciseIcon:setItemId(state.exerciseWeaponId or 0)
        exerciseIcon:setVisible(state.exerciseWeaponId ~= nil)
        local exerciseTooltip = state.exerciseWeaponId and
            'Click to activate. Right-click to change or remove the exercise weapon.' or
            'Right-click to select an exercise weapon.'
        exerciseSlot:setTooltip(exerciseTooltip)
        exerciseIcon:setTooltip(exerciseTooltip)

        local manaSlot = window:recursiveGetChildById('v2ManaTrainingSlot')
        local manaIcon = window:recursiveGetChildById('v2ManaTrainingIcon')
        local manaEnabled = window:recursiveGetChildById('v2ManaTrainingEnabledBox')
        local decrease = window:recursiveGetChildById('v2ManaTrainingDecrease')
        local increase = window:recursiveGetChildById('v2ManaTrainingIncrease')
        local spell = state.manaSpell
        manaIcon:setVisible(spell ~= nil)
        if spell then
            manaIcon:setImageSource(Spells.getIconFileByProfile('Default', spell.clientId))
            manaIcon:setImageClip(Spells.getImageClip(spell.clientId, 'Default'))
        end
        local manaTooltip = spell and
            (spell.name .. '\nClick to activate. Right-click to change or remove.') or
            'Right-click to select a mana training spell.'
        manaSlot:setTooltip(manaTooltip)
        manaIcon:setTooltip(manaTooltip)
        local percentLabel = window:recursiveGetChildById('v2ManaTrainingPercentLabel')
        percentLabel:setText(tostring(state.manaThreshold) .. '%')

        updating = true
        exerciseMode:setEnabled(state.exerciseWeaponId ~= nil)
        exerciseMode:setCurrentOptionByData(state.exerciseEnabled and 'enable' or 'disable', true)
        decrease:setEnabled(spell ~= nil)
        increase:setEnabled(spell ~= nil)
        manaEnabled:setEnabled(spell ~= nil)
        manaEnabled:setChecked(spell ~= nil and state.manaEnabled)
        updating = false
    end
    syncEvent = scheduleEvent(BaiakHelperTrainingV2.sync, 150)
end

function BaiakHelperTrainingV2.init(helperWindow)
    window = helperWindow
    if not window then return end

    local module = legacy()
    local exerciseClick = function(position, button)
        return module.handleExerciseWeaponSlotClick(position, button)
    end
    bindSlot('v2ExerciseWeaponSlot', exerciseClick)
    bindSlot('v2ExerciseWeaponIcon', exerciseClick)

    local exerciseMode = window:recursiveGetChildById('v2ExerciseModeBox')
    exerciseMode:addOption('Disable', 'disable')
    exerciseMode:addOption('Enable', 'enable')
    exerciseMode.onOptionChange = function(_, _, mode)
        if not updating then module.setExerciseTrainingEnabled(mode == 'enable') end
    end

    local manaClick = function(position, button)
        return module.handleManaTrainingSlotClick(position, button)
    end
    bindSlot('v2ManaTrainingSlot', manaClick)
    bindSlot('v2ManaTrainingIcon', manaClick)

    for _, entry in ipairs({
        { id = 'v2ManaTrainingDecrease', delta = -5 },
        { id = 'v2ManaTrainingIncrease', delta = 5 }
    }) do
        local button = window:recursiveGetChildById(entry.id)
        button.onClick = nil
        g_mouse.bindAutoPress(button, function()
            if button:isEnabled() then module.changeManaTrainingThreshold(entry.delta) end
        end, 350, MouseLeftButton, 80)
    end

    window:recursiveGetChildById('v2ManaTrainingEnabledBox').onCheckChange =
        function(_, checked)
            if not updating then module.setManaTrainingEnabled(checked) end
        end

    BaiakHelperTrainingV2.sync()
end

function BaiakHelperTrainingV2.terminate()
    if syncEvent then removeEvent(syncEvent) end
    syncEvent = nil
    window = nil
end
