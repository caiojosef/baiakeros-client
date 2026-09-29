-- Run with: luajit tests/lua/game_walk_detached_keys_spec.lua
North, East, South, West = 0, 1, 2, 3
NorthEast, SouthEast, SouthWest, NorthWest = 4, 5, 6, 7
Controller = { new = function() return {} end }

local gamePanel = {}
local detachedPanel = { setAutoRepeatDelay = function(self, value) self.repeatDelay = value end }
modules = { game_interface = { getRootPanel = function() return gamePanel end } }

local bindings = { down = {}, up = {}, press = {} }
local function bind(kind, key, _, widget)
    local byWidget = bindings[kind][widget]
    if not byWidget then
        byWidget = {}
        bindings[kind][widget] = byWidget
    end
    byWidget[key] = true
end
local function unbind(kind, key, widget)
    if bindings[kind][widget] then bindings[kind][widget][key] = nil end
end
g_keyboard = {
    bindKeyDown = function(key, callback, widget) bind('down', key, callback, widget) end,
    bindKeyUp = function(key, callback, widget) bind('up', key, callback, widget) end,
    bindKeyPress = function(key, callback, widget) bind('press', key, callback, widget) end,
    unbindKeyDown = function(key, widget) unbind('down', key, widget) end,
    unbindKeyUp = function(key, widget) unbind('up', key, widget) end,
    unbindKeyPress = function(key, widget) unbind('press', key, widget) end
}

dofile('modules/game_walk/walk.lua')
bindWalkKey('Up', North)
bindMovementKeysToWidget(detachedPanel)

assert(detachedPanel.repeatDelay == 200)
for _, kind in ipairs({ 'down', 'up', 'press' }) do
    assert(bindings[kind][detachedPanel].Up,
        'arrow keys must work while the detached Cavebot has focus')
    assert(bindings[kind][detachedPanel].Numpad8,
        'numpad movement must work while the detached Cavebot has focus')
    assert(bindings[kind][detachedPanel]['Control+Up'],
        'turn keys must work while the detached Cavebot has focus')
end

unbindMovementKeysFromWidget(detachedPanel)
for _, kind in ipairs({ 'down', 'up', 'press' }) do
    assert(next(bindings[kind][detachedPanel]) == nil,
        'detached movement bindings must be removed when Cavebot closes')
    assert(bindings[kind][gamePanel].Up,
        'normal game movement must remain bound after Cavebot closes')
end

print('Detached Cavebot movement bindings regression passed')
