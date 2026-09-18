BaiakHelperToolsV2 = {}

local TOOL_BINDINGS = {
    v2AutoReconnectBox = 'setAutoReconnectEnabled',
    v2AutoEatFoodBox = 'setAutoEatFoodEnabled',
    v2AutoHasteBox = 'setAutoHasteEnabled',
    v2AutoHasteInPzBox = 'setAutoHasteInProtectionZone',
    v2ChangeGoldBox = 'setChangeGoldEnabled',
    v2FlaskRemoverBox = 'setFlaskRemoverEnabled',
    v2AutolootBox = 'setAutolootEnabled'
}

local function callLegacy(methodName, value)
    local legacy = modules.game_baiakeros_helper
    local callback = legacy and legacy[methodName]
    if callback then callback(value) end
end

function BaiakHelperToolsV2.init(window)
    if not window then return end

    for widgetId, methodName in pairs(TOOL_BINDINGS) do
        local widget = window:recursiveGetChildById(widgetId)
        if widget then
            widget.onCheckChange = function(_, checked)
                callLegacy(methodName, checked)
            end
        end
    end

    local hasteBox = window:recursiveGetChildById('v2AutoHasteSpellBox')
    if hasteBox then
        for _, spellName in ipairs({ 'Haste', 'Strong Haste', 'Charge', 'Swift Foot' }) do
            hasteBox:addOption(spellName, spellName)
        end
        hasteBox.onOptionChange = function(_, _, spellName)
            callLegacy('setAutoHasteSpell', spellName)
        end
    end
end
