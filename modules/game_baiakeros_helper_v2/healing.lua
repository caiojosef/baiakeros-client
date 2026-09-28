BaiakHelperHealingV2 = {}

local window
local syncEvent
local updating = false

local function legacy()
    return modules.game_baiakeros_helper
end

local function syncPreset(sourceWindow)
    local source = sourceWindow:recursiveGetChildById('helperPresetBox')
    local target = window:recursiveGetChildById('v2HealingPresetBox')
    if not source or not target then return end

    local sourceOptions = source.options or {}
    local targetOptions = target.options or {}
    local changed = #targetOptions ~= #sourceOptions
    if not changed then
        for index, option in ipairs(sourceOptions) do
            local current = targetOptions[index]
            if not current or current.text ~= option.text or current.data ~= option.data then
                changed = true
                break
            end
        end
    end

    updating = true
    if changed then
        target:clearOptions()
        for _, option in ipairs(sourceOptions) do
            target:addOption(option.text, option.data)
        end
    end
    local selected = source:getCurrentOption()
    if selected then target:setCurrentOptionByData(selected.data, true) end
    updating = false
end

local function bindButton(id, callback)
    local button = window:recursiveGetChildById(id)
    if button then button.onClick = callback end
end

function BaiakHelperHealingV2.sync()
    if not window then return end
    local module = legacy()
    local sourceWindow = module and module.helperWindow
    if sourceWindow then
        if window:isVisible() and sourceWindow:isVisible() then
            sourceWindow:hide()
        end
        syncPreset(sourceWindow)
        BaiakHelperHealingSlotsV2.sync(window, sourceWindow)

        local source = sourceWindow:recursiveGetChildById('healingEnabledBox')
        local target = window:recursiveGetChildById('v2HealingEnabledBox')
        if source and target and source:isChecked() ~= target:isChecked() then
            updating = true
            target:setChecked(source:isChecked())
            updating = false
        end
    end
    syncEvent = scheduleEvent(BaiakHelperHealingV2.sync, 150)
end

function BaiakHelperHealingV2.init(helperWindow)
    window = helperWindow
    local module = legacy()
    if not window or not module then return end

    local preset = window:recursiveGetChildById('v2HealingPresetBox')
    preset.onOptionChange = function(_, _, data)
        if not updating and data then module.setHelperPreset(data) end
    end

    local enabled = window:recursiveGetChildById('v2HealingEnabledBox')
    enabled.onCheckChange = function(_, checked)
        if not updating then module.setHealingEnabled(checked) end
    end

    bindButton('v2HealingPresetAddButton', function()
        module.openPresetNameWindow('helper')
    end)
    bindButton('v2HealingPresetDeleteButton', function()
        module.requestDeletePreset('helper')
    end)
    bindButton('v2HealingPresetHotkeyButton', function()
        module.setHelperHotkey('Next Helper Preset')
    end)
    bindButton('v2HealingToggleHotkeyButton', function()
        module.setHelperHotkey('Toggle Healing')
    end)

    BaiakHelperHealingSlotsV2.bind(window)
    BaiakHelperHealingV2.sync()
end

function BaiakHelperHealingV2.terminate()
    if syncEvent then removeEvent(syncEvent) end
    syncEvent = nil
    window = nil
end
