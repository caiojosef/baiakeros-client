BaiakHelperToolsV2 = {}

local TOOL_BINDINGS = {
    v2AutoReconnectBox = 'setAutoReconnectEnabled',
    v2AutoEatFoodBox = 'setAutoEatFoodEnabled',
    v2AutoHasteInPzBox = 'setAutoHasteInProtectionZone',
    v2ChangeGoldBox = 'setChangeGoldEnabled',
    v2FlaskRemoverBox = 'setFlaskRemoverEnabled',
    v2AutolootBox = 'setAutolootEnabled'
}

local TOOL_STATE_FIELDS = {
    v2AutoReconnectBox = 'autoReconnect',
    v2AutoEatFoodBox = 'autoEatFood',
    v2AutoHasteInPzBox = 'autoHasteInPz',
    v2ChangeGoldBox = 'changeGold',
    v2FlaskRemoverBox = 'flaskRemover',
    v2AutolootBox = 'autoloot'
}

local window
local syncEvent
local updating = false

local function callLegacy(methodName, value)
    local legacy = modules.game_baiakeros_helper
    local callback = legacy and legacy[methodName]
    if callback then callback(value) end
end

function BaiakHelperToolsV2.sync()
    if not window then return end
    local legacy = modules.game_baiakeros_helper
    local state = legacy and legacy.getToolsState and legacy.getToolsState()
    if state then
        updating = true
        for widgetId, stateField in pairs(TOOL_STATE_FIELDS) do
            local widget = window:recursiveGetChildById(widgetId)
            local checked = state[stateField] == true
            if widget:isChecked() ~= checked then widget:setChecked(checked) end
        end

        local hasteSlot = window:recursiveGetChildById('v2AutoHasteSpellSlot')
        local hasteIcon = window:recursiveGetChildById('v2AutoHasteSpellIcon')
        local hasteSpells = state.hasteSpells or {}
        local selectedSpell
        for _, spell in ipairs(hasteSpells) do
            if spell.name == state.autoHasteSpell then
                selectedSpell = spell
                break
            end
        end

        hasteSlot:setEnabled(#hasteSpells > 0 or state.autoHasteSpell ~= '')
        hasteIcon:setVisible(selectedSpell ~= nil)
        if selectedSpell then
            hasteIcon:setImageSource(Spells.getIconFileByProfile('Default'))
            hasteIcon:setImageClip(Spells.getImageClip(selectedSpell.clientId, 'Default'))
            hasteSlot:setTooltip(string.format('%s\n%s\nLevel %d | Mana %d\nRight-click: Assign Haste or Clear. Cast in PZ allows casting in a protection zone.',
                selectedSpell.name, selectedSpell.words,
                selectedSpell.level or 0, selectedSpell.mana or 0))
        else
            hasteSlot:setTooltip('Right-click to Assign Haste. Cast in PZ allows casting in a protection zone.')
        end
        local hasteMode = window:recursiveGetChildById('v2AutoHasteModeBox')
        hasteMode:setEnabled(selectedSpell ~= nil)
        hasteMode:setCurrentOptionByData(state.autoHaste and 'enable' or 'disable', true)
        window:recursiveGetChildById('v2AutoHasteInPzBox'):setEnabled(selectedSpell ~= nil)
        local autolootBox = window:recursiveGetChildById('v2AutolootBox')
        autolootBox:setEnabled(state.hasLootPouch)
        autolootBox:setOpacity(state.hasLootPouch and 1 or 0.45)
        updating = false
    end
    syncEvent = scheduleEvent(BaiakHelperToolsV2.sync, 250)
end

function BaiakHelperToolsV2.init(helperWindow)
    window = helperWindow
    if not window then return end

    for widgetId, methodName in pairs(TOOL_BINDINGS) do
        local widget = window:recursiveGetChildById(widgetId)
        if widget then
            widget.onCheckChange = function(_, checked)
                if not updating then callLegacy(methodName, checked) end
            end
        end
    end

    local hasteMode = window:recursiveGetChildById('v2AutoHasteModeBox')
    hasteMode:addOption('Disable', 'disable')
    hasteMode:addOption('Enable', 'enable')
    hasteMode.onOptionChange = function(_, _, mode)
        if not updating then callLegacy('setAutoHasteEnabled', mode == 'enable') end
    end

    local function openHasteSelector()
        local legacy = modules.game_baiakeros_helper
        local actionbar = modules.game_actionbar
        local helperV2 = modules.game_baiakeros_helper_v2
        if not legacy or not legacy.getAvailableHasteSpells or
            not actionbar or not actionbar.openFilteredSpellSelector then
            return
        end

        local spells = legacy.getAvailableHasteSpells()
        if #spells == 0 then return end

        local selectedName = legacy.getToolsState().autoHasteSpell
        local preselected
        for _, spell in ipairs(spells) do
            if spell.name == selectedName then
                preselected = spell
                break
            end
        end

        helperV2.hideForHealingAssignment()
        actionbar.openFilteredSpellSelector({
            title = 'Select Haste Spell',
            emptyText = 'Select a haste spell',
            spells = spells,
            preselected = preselected,
            onConfirm = function(spell)
                if spell then legacy.setAutoHasteSpell(spell.name) end
                helperV2.restoreAfterHealingAssignment()
            end,
            onCancel = function()
                helperV2.restoreAfterHealingAssignment()
            end
        })
    end

    local hasteSlot = window:recursiveGetChildById('v2AutoHasteSpellSlot')
    hasteSlot.onMouseRelease = function(_, position, button)
        if button ~= MouseRightButton then return false end
        if not g_game.isOnline() then return true end

        local legacy = modules.game_baiakeros_helper
        local state = legacy and legacy.getToolsState and legacy.getToolsState()
        if not state then return true end

        local menu = g_ui.createWidget('PopupMenu')
        menu:setGameMenu(true)
        if #(state.hasteSpells or {}) > 0 then
            menu:addOption('Assign Haste', openHasteSelector)
        end
        if state.autoHasteSpell ~= '' then
            if #(state.hasteSpells or {}) > 0 then menu:addSeparator() end
            menu:addOption('Clear', function() legacy.clearAutoHasteSpell() end)
        end
        menu:display(position)
        return true
    end

    local storeButton = window:recursiveGetChildById('v2LootPouchStoreButton')
    if storeButton then
        storeButton.onClick = function()
            local legacy = modules.game_baiakeros_helper
            if legacy and legacy.openLootPouchStore then legacy.openLootPouchStore() end
        end
    end

    BaiakHelperToolsV2.sync()
end

function BaiakHelperToolsV2.terminate()
    if syncEvent then removeEvent(syncEvent) end
    syncEvent = nil
    window = nil
end
