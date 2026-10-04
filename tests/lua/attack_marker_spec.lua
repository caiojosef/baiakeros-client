-- Run with Lua 5.1 from the client root.
UIWidget = {}
function extends() return {} end
PlayerStates = { Pz = 1 }
local attacked, followed
g_game = {
    getAttackingCreature = function() return attacked end,
    getFollowingCreature = function() return followed end,
    isOnline = function() return true end
}
dofile('modules/gamelib/ui/uicreaturebutton.lua')
dofile('modules/game_battle/battle.lua')

local function upvalue(fn, wanted)
    for index = 1, 100 do
        local name, value = debug.getupvalue(fn, index)
        if not name then break end
        if name == wanted then return value end
    end
    error('Missing upvalue: ' .. wanted)
end
local manager = upvalue(upvalue(onAttack, 'updateSelectionSquares'), 'BattleListManager')
local function creature(id)
    local value = { id = id }
    function value:getId() return self.id end
    function value:showStaticSquare(color) self.square = color end
    function value:hideStaticSquare() self.square = nil end
    function value:getPosition() return { x = 100 + self.id, y = 100, z = 7 } end
    function value:isMonster() return true end
    function value:isDead() return false end
    function value:getHealthPercent() return 100 end
    function value:getType() return 0 end
    function value:getMasterId() return 0 end
    return value
end
local function button(value)
    local children = {}
    local widget = setmetatable({ creature = value, isBattleButton = true }, { __index = UICreatureButton })
    function widget:getChildById(id)
        children[id] = children[id] or {
            setBorderWidth = function(self, width) self.width = width end,
            setBorderColor = function() end, setColor = function() end, setImageSource = function() end
        }
        return children[id]
    end
    return widget
end
local first, second = creature(1), creature(2)
local primary, duplicate = button(first), button(first)
manager.instances = {
    { window = { isVisible = function() return true end }, battleButtons = { [1] = primary } },
    { window = { isVisible = function() return false end }, battleButtons = { [1] = duplicate } }
}
local battleAttack, battleFollow = onAttack, onFollow
local function red(message) assert(first.square == '#FF0000', message) end

attacked = first
battleAttack(first)
red('initial target must be red')
duplicate:update()
red('a hidden/duplicate battle entry must not clear the actual attack marker')
duplicate:resetState()
red('filtering or pooling a battle entry must preserve an active target')
battleFollow(nil)
red('an unrelated follow cancellation must not clear the attack marker')
assert(primary.isTarget and duplicate.isTarget, 'all list entries must reflect the actual attack selection')

attacked = second
battleAttack(second)
assert(first.square == nil and second.square == '#FF0000', 'switching targets clears the old marker, even without a new list entry')
assert(not primary.isTarget and not duplicate.isTarget, 'hidden entries must not keep stale target flags')
primary.isTarget = true
primary:update()
assert(first.square == nil, 'a stale widget flag must not resurrect an old attack marker')
attacked = nil
battleAttack(nil)
assert(second.square == nil, 'real attack cancellation must clear the marker')

followed = first
battleFollow(first)
assert(first.square == '#00FF00', 'following keeps its green marker')
duplicate:resetState()
assert(first.square == '#00FF00', 'pooled entries must also preserve following')
followed = nil
battleFollow(nil)
assert(first.square == nil, 'real follow cancellation must clear the marker')
primary.isHovered = true
primary:update()
assert(first.square == '#FFFFFF', 'idle hovering keeps its existing marker')
primary.isHovered = false
primary:update()
assert(first.square == nil, 'leaving an idle entry must clear the hover marker')

-- Exercise the real Helper selection callback: repairing a visual marker must
-- never send attack again, since attacking the same creature toggles it off.
local now, attackPackets = 1000, 0
g_clock = { millis = function() return now end }
g_game.getLocalPlayer = function() return {
    isDead = function() return false end, hasState = function() return false end,
    getPosition = function() return { x = 100, y = 100, z = 7 } end
} end
g_game.attack = function(value)
    attackPackets = attackPackets + 1
    attacked = attacked == value and nil or value
    battleAttack(attacked)
end
modules = { game_interface = { getMapPanel = function() return {
    getSpectators = function() return { first } end
} end } }
dofile('modules/game_baiakeros_helper/helper.lua')
local check = upvalue(init, 'checkAutoAttack')
autoAttackEnabled = true
check()
assert(attacked == first and attackPackets == 1, 'Helper must select a visible monster once')
for index = 1, 20 do
    duplicate:resetState()
    duplicate:update()
    now = now + 50
    check()
    red('Battle List refresh must preserve the Helper target on every tick')
end
assert(attackPackets == 1, 'marker maintenance must not toggle attack or flood the server')
manager.instances = {}
duplicate:resetState()
red('removing every Battle List entry must preserve the current target')
attacked = nil
battleAttack(nil)
assert(first.square == nil, 'cancelling a filtered target must still clear its marker')
print('Attack marker passed: duplicate/hidden lists, pooling, follow, switching/cancelling targets, hover and real Helper ticks')
