local OPCODE = 218
local EFFECT_DURATION = 1120
local EFFECT_NATIVE_SIZE = 64

local SQUARE_3X3_OFFSETS = {
    { x = -1, y = -1 }, { x = 0, y = -1 }, { x = 1, y = -1 },
    { x = -1, y =  0 }, { x = 0, y =  0 }, { x = 1, y =  0 },
    { x = -1, y =  1 }, { x = 0, y =  1 }, { x = 1, y =  1 }
}

local effectWidgets = {}
local updateEvent = nil

local function getMapPositionPoint(mapPanel, position)
    local visible = mapPanel:getVisibleDimension()
    if not visible or visible.width <= 0 or visible.height <= 0 then
        return { x = -1, y = -1 }, 32
    end

    local tileSize = math.min(mapPanel:getWidth() / visible.width, mapPanel:getHeight() / visible.height)

    -- Newer binaries expose the exact renderer transform. Keep a Lua fallback so
    -- the development client can display the effect before the next compilation.
    if mapPanel.getPositionPoint then
        return mapPanel:getPositionPoint(position), tileSize
    end

    local camera = mapPanel:getCameraPosition()
    if not camera or not camera.x or not camera.y or not camera.z or
        position.z ~= camera.z then
        return { x = -1, y = -1 }, tileSize
    end

    return {
        x = mapPanel:getX() + mapPanel:getWidth() / 2 + (position.x - camera.x) * tileSize,
        y = mapPanel:getY() + mapPanel:getHeight() / 2 + (position.y - camera.y) * tileSize
    }, tileSize
end

local function clearEffects()
    if updateEvent then
        removeEvent(updateEvent)
        updateEvent = nil
    end

    for widget in pairs(effectWidgets) do
        if widget and not widget:isDestroyed() then
            widget:destroy()
        end
    end
    effectWidgets = {}
end

local function updateEffects()
    updateEvent = nil
    local mapPanel = modules.game_interface.getMapPanel()
    if not mapPanel then
        clearEffects()
        return
    end

    local now = g_clock.millis()
    local hasEffects = false
    for widget, effect in pairs(effectWidgets) do
        if now >= effect.expiresAt or widget:isDestroyed() then
            if not widget:isDestroyed() then
                widget:destroy()
            end
            effectWidgets[widget] = nil
        else
            local point, tileSize = getMapPositionPoint(mapPanel, effect.position)
            if point.x < 0 or point.y < 0 then
                widget:hide()
            else
                -- The source is a 64x64 effect made for a 32px tile, therefore it
                -- must occupy two rendered tiles and follow the current map zoom.
                local effectSize = math.max(EFFECT_NATIVE_SIZE, math.floor(tileSize * 2 + 0.5))
                if effect.imageSize ~= effectSize then
                    widget:setSize({ width = effectSize, height = effectSize })
                    widget:setImageSize({ width = effectSize, height = effectSize })
                    effect.imageSize = effectSize
                end
                widget:setPosition({ x = point.x - effectSize / 2, y = point.y - effectSize / 2 })
                widget:show()
            end
            hasEffects = true
        end
    end

    if hasEffects then
        updateEvent = scheduleEvent(updateEffects, 16)
    end
end

local function createShieldEffect(mapPanel, position)
    local widget = g_ui.createWidget('EKShieldEffect', mapPanel)
    widget:setSize({ width = EFFECT_NATIVE_SIZE, height = EFFECT_NATIVE_SIZE })
    widget:setImageSize({ width = EFFECT_NATIVE_SIZE, height = EFFECT_NATIVE_SIZE })
    widget:setImageSource('/images/game/effects/shield-bash')
    widget:setPhantom(true)
    widget:setFocusable(false)
    widget:raise()

    effectWidgets[widget] = {
        position = position,
        expiresAt = g_clock.millis() + EFFECT_DURATION,
        imageSize = EFFECT_NATIVE_SIZE
    }
end

local function showShieldEffect(data)
    local mapPanel = modules.game_interface.getMapPanel()
    if not mapPanel then
        return
    end

    local position = {
        x = tonumber(data.x) or 0,
        y = tonumber(data.y) or 0,
        z = tonumber(data.z) or 0
    }
    if data.area == 'square3x3' then
        for _, offset in ipairs(SQUARE_3X3_OFFSETS) do
            createShieldEffect(mapPanel, {
                x = position.x + offset.x,
                y = position.y + offset.y,
                z = position.z
            })
        end
    else
        createShieldEffect(mapPanel, position)
    end

    if not updateEvent then
        updateEffects()
    end
end

local function setStance(spellId)
    if modules.game_actionbar and modules.game_actionbar.setActiveStanceSpellId then
        modules.game_actionbar.setActiveStanceSpellId(spellId)
    end
end

local function onExtendedOpcode(_protocol, _opcode, buffer)
    local ok, data = pcall(json.decode, buffer)
    if not ok or type(data) ~= 'table' then
        return
    end

    if data.action == 'stance' then
        if type(data.spellIds) == 'table' and modules.game_actionbar and modules.game_actionbar.setActiveStanceSpellIds then
            modules.game_actionbar.setActiveStanceSpellIds(data.spellIds)
        else
            setStance(tonumber(data.spellId) or 0)
        end
    elseif data.action == 'shieldEffect' then
        showShieldEffect(data)
    end
end

local function offline()
    clearEffects()
    setStance(0)
end

function init()
    g_ui.importStyle('shield_effect')
    ProtocolGame.registerExtendedOpcode(OPCODE, onExtendedOpcode)
    connect(g_game, { onGameEnd = offline })
end

function terminate()
    disconnect(g_game, { onGameEnd = offline })
    ProtocolGame.unregisterExtendedOpcode(OPCODE)
    offline()
end
