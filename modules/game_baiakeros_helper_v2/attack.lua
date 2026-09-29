BaiakHelperAttackV2 = {}

local window
local syncEvent
local updating = false

local function legacy()
    return modules.game_baiakeros_helper
end

local function renderSlot(kind, index, state)
    local row = window:recursiveGetChildById(
        (kind == 'spell' and 'v2SpellSlot' or 'v2RuneSlot') .. index)
    local slotId = (kind == 'spell' and 'attackSpellSlot' or 'attackRuneSlot') .. index
    local slot = state.slots[slotId]
    row:setVisible(slot ~= nil and slot.visible)
    if not slot or not slot.visible then return end

    local assign = row:recursiveGetChildById('assignButton')
    local spellIcon = row:recursiveGetChildById('spellIcon')
    local itemIcon = row:recursiveGetChildById('itemIcon')
    local multiple = row:recursiveGetChildById('allowMultipleBox')
    if spellIcon then spellIcon:setVisible(slot.spell ~= nil) end
    itemIcon:setVisible(slot.rune ~= nil)
    if slot.spell then
        spellIcon:setImageSource(Spells.getIconFileByProfile('Default'))
        spellIcon:setImageClip(Spells.getImageClip(slot.spell.clientId, 'Default'))
        assign:setTooltip(string.format('%s\n%s\nLevel %d | Mana %d\nRight-click to change or remove',
            slot.spell.name, slot.spell.words,
            slot.spell.level or 0, slot.spell.mana or 0))
    elseif slot.rune then
        itemIcon:setItemId(slot.rune.id)
        assign:setTooltip(slot.rune.name .. '\nRight-click to change or remove')
    else
        assign:setTooltip(kind == 'spell' and
            'Right-click to assign an attack spell' or
            'Right-click to assign a rune')
    end
    itemIcon:setTooltip(assign:getTooltip())

    if kind == 'spell' then
        row:recursiveGetChildById('manaLabel'):setText(tostring(slot.minMana) .. '%')
    end
    local enemiesLabel = row:recursiveGetChildById('enemiesLabel')
    enemiesLabel:setText(tostring(slot.minEnemies))
    enemiesLabel:setColor(slot.singleTarget and '#777777' or '#eeeeee')
    for _, id in ipairs({ 'enemiesDecrease', 'enemiesIncrease', 'enemiesPanel' }) do
        local widget = row:recursiveGetChildById(id)
        widget:setTooltip(slot.singleTarget and
            'Single-target spells always use exactly 1 creature.' or '')
        if id ~= 'enemiesPanel' then widget:setEnabled(not slot.singleTarget) end
    end
    if multiple then
        multiple:setVisible(slot.singleTarget)
        multiple:setChecked(slot.allowMultiple)
    end
    row:recursiveGetChildById('priorityBox'):setCurrentOptionByData(slot.priority, true)
end

local function renderPostures(kind, state)
    local options = state.postures[kind] or {}
    local title = window:recursiveGetChildById(
        kind == 'stance' and 'v2StanceTitle' or 'v2PassiveTitle')
    title:setVisible(#options > 0)
    for index = 1, kind == 'stance' and 3 or 2 do
        local button = window:recursiveGetChildById(
            (kind == 'stance' and 'v2StanceButton' or 'v2PassiveButton') .. index)
        local option = options[index]
        button:setVisible(option ~= nil)
        if option then
            button:setImageSource(Spells.getIconFileByProfile('Default'))
            button:setImageClip(Spells.getImageClip(option.clientId, 'Default'))
            local remaining = math.max(0, option.cooldownExpiry - g_clock.millis())
            button:setEnabled(not state.shooter and remaining == 0)
            button:recursiveGetChildById('activeSpell'):setVisible(option.selected)
            button:setTooltip(option.name .. '\n' .. option.words ..
                (state.shooter and '\nDisable Shooter Helper to change this selection.' or ''))

            local cooldown = button:recursiveGetChildById('cooldown')
            if remaining > 0 then
                if button.v2CooldownExpiry ~= option.cooldownExpiry then
                    cooldown:showTime(true)
                    cooldown:showProgress(true)
                    cooldown:setDuration(remaining)
                    cooldown:start()
                    button.v2CooldownExpiry = option.cooldownExpiry
                end
            elseif button.v2CooldownExpiry then
                cooldown:stop()
                cooldown:setPercent(100)
                cooldown:setText('')
                button.v2CooldownExpiry = nil
            end
        end
    end
end

local function syncPreset(state)
    local box = window:recursiveGetChildById('v2AttackPresetBox')
    local names = state.presetNames or {}
    local options = box.options or {}
    local changed = #options ~= #names
    if not changed then
        for index, name in ipairs(names) do
            if not options[index] or options[index].text ~= name then
                changed = true
                break
            end
        end
    end
    if changed then
        box:clearOptions()
        for _, name in ipairs(names) do
            box:addOption(name, legacy().presetId(name))
        end
    end
    box:setCurrentOptionByData(state.preset, true)
    box:setEnabled(not state.shooter)
    local addButton = window:recursiveGetChildById('v2AttackPresetAddButton')
    local deleteButton = window:recursiveGetChildById('v2AttackPresetDeleteButton')
    addButton:setEnabled(not state.shooter)
    deleteButton:setEnabled(not state.shooter and state.preset ~= 'default')
end

function BaiakHelperAttackV2.sync()
    if not window then return end
    local module = legacy()
    local state = module and module.getAttackState and module.getAttackState()
    if state then
        updating = true
        syncPreset(state)
        for index = 1, 5 do renderSlot('spell', index, state) end
        for index = 1, 2 do renderSlot('rune', index, state) end
        local showLure = state.lureSlotVisible == true
        local showRunes = state.runeCount > 0 and not showLure
        window:recursiveGetChildById('v2RuneBlock'):setVisible(showRunes or showLure)
        window:recursiveGetChildById('v2RuneDivider'):setVisible(showRunes or showLure)
        for _, id in ipairs({ 'v2RuneColumnLabel', 'v2RuneCreaturesLabel',
            'v2RunePriorityLabel', 'v2RuneRows' }) do
            window:recursiveGetChildById(id):setVisible(showRunes)
        end
        local runeRows = window:recursiveGetChildById('v2RuneRows')
        runeRows:setHeight(math.max(1, state.runeCount) * 36)
        window:recursiveGetChildById('v2LureSpellArea'):setVisible(showLure)
        local lureButton = window:recursiveGetChildById('v2LureSpellButton')
        local lureIcon = window:recursiveGetChildById('v2LureSpellIcon')
        local lureSpell = state.lureSpell
        lureIcon:setVisible(showLure and lureSpell ~= nil)
        if lureSpell then
            lureIcon:setImageSource(Spells.getIconFileByProfile('Default'))
            lureIcon:setImageClip(Spells.getImageClip(lureSpell.clientId, 'Default'))
            lureButton:setTooltip(lureSpell.name .. '\n' .. lureSpell.words ..
                '\nRight-click to change or clear')
        else
            lureButton:setTooltip('Right-click to assign a Lure Spell')
        end
        renderPostures('stance', state)
        renderPostures('passive', state)

        window:recursiveGetChildById('v2AutoAttackEnabledBox'):setChecked(state.autoTarget)
        window:recursiveGetChildById('v2AttackRotationEnabledBox'):setChecked(state.shooter)
        local mode = window:recursiveGetChildById('v2AutoAttackModeBox')
        mode:setCurrentOptionByData(state.autoTargetMode, true)
        local enabled = state.autoTarget or state.shooter
        local status = window:recursiveGetChildById('v2AttackHelperStatusLabel')
        status:setText(enabled and 'Helper Status: Enabled' or 'Helper Status: Disabled')
        status:setColor(enabled and '#78d878' or '#999999')
        local presetName = 'Default'
        for _, name in ipairs(state.presetNames or {}) do
            if module.presetId(name) == state.preset then presetName = name break end
        end
        local presetStatus = window:recursiveGetChildById('v2AttackPresetStatusLabel')
        presetStatus:setText('Attack Preset: ' .. presetName)
        updating = false
    end
    syncEvent = scheduleEvent(BaiakHelperAttackV2.sync, 200)
end

local function bindSlot(kind, index)
    local row = window:recursiveGetChildById(
        (kind == 'spell' and 'v2SpellSlot' or 'v2RuneSlot') .. index)
    local slotId = (kind == 'spell' and 'attackSpellSlot' or 'attackRuneSlot') .. index
    local assign = row:recursiveGetChildById('assignButton')
    local click = function(_, position, button)
        if kind == 'spell' then
            return legacy().showAttackSpellSlotMenu(slotId, position, button)
        end
        return legacy().showAttackRuneSlotMenu(slotId, position, button)
    end
    assign.onMouseRelease = click
    if kind == 'rune' then
        local itemIcon = row:recursiveGetChildById('itemIcon')
        itemIcon:setPhantom(false)
        itemIcon.onMouseRelease = click
    end

    local controls = {
        { id = 'enemiesDecrease', action = 'changeAttackEnemies', delta = -1 },
        { id = 'enemiesIncrease', action = 'changeAttackEnemies', delta = 1 }
    }
    if kind == 'spell' then
        table.insert(controls, { id = 'manaDecrease', action = 'changeAttackMana', delta = -5 })
        table.insert(controls, { id = 'manaIncrease', action = 'changeAttackMana', delta = 5 })
    end
    for _, entry in ipairs(controls) do
        local button = row:recursiveGetChildById(entry.id)
        local applyChange = function()
            if button:isEnabled() then legacy()[entry.action](slotId, entry.delta) end
        end
        if entry.action == 'changeAttackMana' and kind == 'spell' then
            button.onClick = nil
            g_mouse.bindAutoPress(button, applyChange, 350, MouseLeftButton, 80)
        else
            button.onClick = applyChange
        end
    end
    if kind == 'spell' then
        row:recursiveGetChildById('allowMultipleBox').onCheckChange = function(_, checked)
            if not updating then legacy().setAttackAllowMultiple(slotId, checked) end
        end
    end

    local priority = row:recursiveGetChildById('priorityBox')
    for value = 1, 5 do
        priority:addOption(value .. (value == 1 and 'st' or value == 2 and 'nd' or
            value == 3 and 'rd' or 'th'), value)
    end
    priority.onOptionChange = function(_, _, value)
        if not updating then legacy().setAttackPriority(slotId, value) end
    end
end

function BaiakHelperAttackV2.init(helperWindow)
    window = helperWindow
    if not window then return end

    for index = 1, 5 do bindSlot('spell', index) end
    for index = 1, 2 do bindSlot('rune', index) end
    window:recursiveGetChildById('v2LureSpellButton').onMouseRelease = function(_, position, button)
        return legacy().showExplorerLureSpellMenu(position, button)
    end
    for _, kind in ipairs({ 'stance', 'passive' }) do
        for index = 1, kind == 'stance' and 3 or 2 do
            local button = window:recursiveGetChildById(
                (kind == 'stance' and 'v2StanceButton' or 'v2PassiveButton') .. index)
            local selectedKind, selectedIndex = kind, index
            button.onClick = function()
                legacy().selectAttackPosture(selectedKind, selectedIndex)
            end
        end
    end

    local preset = window:recursiveGetChildById('v2AttackPresetBox')
    preset.onOptionChange = function(_, _, value)
        if not updating and value then legacy().setAttackPreset(value) end
    end
    for _, binding in ipairs({
        { id = 'v2AttackPresetAddButton', method = 'openPresetNameWindow', arg = 'attack' },
        { id = 'v2AttackPresetDeleteButton', method = 'requestDeletePreset', arg = 'attack' },
        { id = 'v2AttackPresetHotkeyButton', method = 'setHelperHotkey', arg = 'Next Attack Preset' },
        { id = 'v2AutoTargetHotkeyButton', method = 'setHelperHotkey', arg = 'Toggle Auto Target' },
        { id = 'v2ShooterHotkeyButton', method = 'setHelperHotkey', arg = 'Toggle Shooter' },
        { id = 'v2AttackBothHotkeyButton', method = 'setHelperHotkey', arg = 'Toggle Auto Target + Shooter' }
    }) do
        window:recursiveGetChildById(binding.id).onClick = function()
            legacy()[binding.method](binding.arg)
        end
    end

    window:recursiveGetChildById('v2AutoAttackEnabledBox').onCheckChange =
        function(_, checked)
            if not updating then legacy().setAutoAttackEnabled(checked) end
        end
    window:recursiveGetChildById('v2AttackRotationEnabledBox').onCheckChange =
        function(_, checked)
            if not updating then legacy().setAttackRotationEnabled(checked) end
        end
    local mode = window:recursiveGetChildById('v2AutoAttackModeBox')
    for value = string.byte('A'), string.byte('I') do
        local letter = string.char(value)
        mode:addOption(letter, letter)
    end
    mode.onOptionChange = function(_, _, value)
        if not updating then legacy().setAutoAttackMode(value) end
    end

    BaiakHelperAttackV2.sync()
end

function BaiakHelperAttackV2.terminate()
    if syncEvent then removeEvent(syncEvent) end
    syncEvent = nil
    window = nil
end
