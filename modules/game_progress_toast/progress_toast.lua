progressToastController = Controller:new()

local knownValues = {}
local pendingAdvances = {}
local pendingEvents = {}

-- Advances received close together are consolidated into one parchment.
-- This prevents a server-side jump from level 1 to 50 from producing 49 banners.
local CONSOLIDATE_TIME = 450
local DISPLAY_TIME = 3200

local skillInfo = {
    [0] = { name = 'Fist Fighting', icon = 'fist' },
    [1] = { name = 'Club Fighting', icon = 'club' },
    [2] = { name = 'Sword Fighting', icon = 'sword' },
    [3] = { name = 'Axe Fighting', icon = 'axe' },
    [4] = { name = 'Distance Fighting', icon = 'distance' },
    [5] = { name = 'Shielding', icon = 'shielding' },
    [6] = { name = 'Fishing', icon = 'fishing' }
}

local function cancelPendingEvent(key)
    local event = pendingEvents[key]
    if event then
        event:cancel()
        pendingEvents[key] = nil
    end
end

local function resetState()
    for key in pairs(pendingEvents) do
        cancelPendingEvent(key)
    end
    pendingAdvances = {}
end

local function showParchment(advance)
    if not g_game.isOnline() then
        return
    end

    local notifications = modules.game_notifications and modules.game_notifications.notificationsController
    if not notifications then
        g_logger.error('[ProgressToast] game notifications controller is unavailable')
        return
    end

    local description
    if advance.from == advance.to - 1 then
        description = tr('You have advanced to level %d.', advance.to)
    else
        description = tr('You have advanced from level %d to level %d.', advance.from, advance.to)
    end

    notifications:show(advance.title, description, advance.icon, DISPLAY_TIME)
end

local function flushAdvance(key)
    pendingEvents[key] = nil
    local advance = pendingAdvances[key]
    pendingAdvances[key] = nil
    if advance then
        showParchment(advance)
    end
end

local function consolidateAdvance(key, fromValue, toValue, title, icon)
    fromValue = tonumber(fromValue)
    toValue = tonumber(toValue)
    if not fromValue or not toValue or toValue <= fromValue then
        return
    end

    local advance = pendingAdvances[key]
    if advance then
        advance.from = math.min(advance.from, fromValue)
        advance.to = math.max(advance.to, toValue)
    else
        pendingAdvances[key] = {
            from = fromValue,
            to = toValue,
            title = title,
            icon = icon
        }
    end

    cancelPendingEvent(key)
    pendingEvents[key] = scheduleEvent(function()
        flushAdvance(key)
    end, CONSOLIDATE_TIME)
end

local function captureCurrentValues(player)
    knownValues = {}
    if not player then
        return
    end

    knownValues.level = player:getLevel()
    -- Advancement cards must use the permanent base values. The visible
    -- values include temporary buffs and debuffs, so recovering from a
    -- monster's skill reduction must not look like a real advancement.
    knownValues.magic = player:getBaseMagicLevel()
    for id = 0, 6 do
        knownValues['skill:' .. id] = player:getSkillBaseLevel(id)
    end
end

local function trackIncrease(key, value, oldValue, title, icon)
    local previous = tonumber(oldValue) or knownValues[key]
    knownValues[key] = value

    -- The first update after login establishes the baseline and is not an advance.
    if not previous or value <= previous then
        return
    end

    consolidateAdvance(key, previous, value, title, icon)
end

function progressToastController:onInit()
    progressToastController:registerEvents(LocalPlayer, {
        onLevelChange = function(_, level, _, oldLevel)
            trackIncrease(
                'level',
                level,
                oldLevel,
                tr('Level Up!'),
                '/game_notifications/assets/images/nodo/icon-infobanner-levelup'
            )
        end,
        onBaseMagicLevelChange = function(_, level, oldLevel)
            trackIncrease(
                'magic',
                level,
                oldLevel,
                tr('Magic Level'),
                '/game_notifications/assets/images/nodo/icon-infobanner-skill-magic'
            )
        end,
        onBaseSkillChange = function(_, id, level, oldLevel)
            local info = skillInfo[id]
            if not info then
                return
            end

            trackIncrease(
                'skill:' .. id,
                level,
                oldLevel,
                tr(info.name),
                '/game_notifications/assets/images/nodo/icon-infobanner-skill-' .. info.icon
            )
        end
    })
end

function progressToastController:onGameStart()
    resetState()
    captureCurrentValues(g_game.getLocalPlayer())
end

function progressToastController:onGameEnd()
    resetState()
    knownValues = {}
end

function progressToastController:onTerminate()
    resetState()
    knownValues = {}
end
