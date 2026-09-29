BaiakHelperHealingV2 = {}

local window
local syncEvent
local updating = false

local function legacy()
    return modules.game_baiakeros_helper
end

local function syncPreset(state)
    local target = window:recursiveGetChildById('v2HealingPresetBox')
    local names = state.presetNames or {}
    local options = target.options or {}
    local changed = #options ~= #names
    if not changed then
        for index, name in ipairs(names) do
            if not options[index] or options[index].text ~= name then
                changed = true
                break
            end
        end
    end

    updating = true
    if changed then
        target:clearOptions()
        for _, name in ipairs(names) do
            target:addOption(name, legacy().presetId(name))
        end
    end
    target:setCurrentOptionByData(state.preset, true)
    updating = false
end

local function bindButton(id, callback)
    local button = window:recursiveGetChildById(id)
    if button then button.onClick = callback end
end

function BaiakHelperHealingV2.sync()
    if not window then return end
    local module = legacy()
    if module and module.getHealingState then
        local state = module.getHealingState()
        syncPreset(state)
        BaiakHelperHealingSlotsV2.render(window, state.slots)
        BaiakHelperSioV2.sync()

        local enabled = window:recursiveGetChildById('v2HealingEnabledBox')
        if enabled:isChecked() ~= state.enabled then
            updating = true
            enabled:setChecked(state.enabled)
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
    BaiakHelperSioV2.init(window)
    BaiakHelperHealingV2.sync()
end

function BaiakHelperHealingV2.terminate()
    if syncEvent then removeEvent(syncEvent) end
    syncEvent = nil
    BaiakHelperSioV2.terminate()
    window = nil
end
