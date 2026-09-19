BaiakHelperAttackV2 = {}

function BaiakHelperAttackV2.init(window)
    if not window then return end

    local autoTarget = window:recursiveGetChildById('v2AutoAttackEnabledBox')
    if autoTarget then
        autoTarget.onCheckChange = function(_, checked)
            local legacy = modules.game_baiakeros_helper
            if legacy and legacy.setAutoAttackEnabled then
                legacy.setAutoAttackEnabled(checked)
            end
        end
    end

    local shooter = window:recursiveGetChildById('v2AttackRotationEnabledBox')
    if shooter then
        shooter.onCheckChange = function(_, checked)
            local legacy = modules.game_baiakeros_helper
            if legacy and legacy.setAttackRotationEnabled then
                legacy.setAttackRotationEnabled(checked)
            end
        end
    end

    local mode = window:recursiveGetChildById('v2AutoAttackModeBox')
    if mode then
        for value = string.byte('A'), string.byte('I') do
            local letter = string.char(value)
            mode:addOption(letter, letter)
        end
        mode.onOptionChange = function(_, _, selectedMode)
            local legacy = modules.game_baiakeros_helper
            if legacy and legacy.setAutoAttackMode then
                legacy.setAutoAttackMode(selectedMode)
            end
        end
    end

    for index = 1, 5 do
        local priority = window:recursiveGetChildById('v2SpellPriority' .. index)
        if priority then
            for value = 1, 5 do
                priority:addOption(value .. (value == 1 and 'st' or value == 2 and 'nd' or value == 3 and 'rd' or 'th'), value)
            end
        end
    end

    for index = 1, 2 do
        local priority = window:recursiveGetChildById('v2RunePriority' .. index)
        if priority then
            for value = 1, 5 do
                priority:addOption(value .. (value == 1 and 'st' or value == 2 and 'nd' or value == 3 and 'rd' or 'th'), value)
            end
        end
    end
end
