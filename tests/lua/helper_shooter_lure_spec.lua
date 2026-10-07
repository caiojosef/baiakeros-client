-- Run with: luajit tests/lua/helper_shooter_lure_spec.lua

North, East, South, West = 0, 1, 2, 3
PlayerStates = { Pz = 1 }

table.contains = function(values, expected)
    for _, value in ipairs(values) do
        if value == expected then return true end
    end
    return false
end

local now = 1000
local vocation = 11
local direction = North
local healthPercent = 100
local selection = 'Chivalrous Challenge'
local walkable = true
local spoken = {}
local turns = {}
local spectators = {}
local playerPosition = { x = 100, y = 100, z = 7 }

local player = {
    getName = function() return 'Shooter Test' end,
    getVocation = function() return vocation end,
    getLevel = function() return 1000 end,
    isPremium = function() return true end,
    isDead = function() return false end,
    hasState = function() return false end,
    getHealthPercent = function() return healthPercent end,
    getMana = function() return 1000 end,
    getMaxMana = function() return 1000 end,
    getPosition = function() return playerPosition end,
    getDirection = function() return direction end
}

local monsterPosition = { x = 103, y = 100, z = 7 }
local monster = {
    isDead = function() return false end,
    isMonster = function() return true end,
    getType = function() return 0 end,
    getMasterId = function() return 0 end,
    getPosition = function() return monsterPosition end,
    getHealthPercent = function() return 100 end
}
spectators[1] = monster

g_clock = { millis = function() return now end }
g_game = {
    isOnline = function() return true end,
    getLocalPlayer = function() return player end,
    getAttackingCreature = function() return nil end,
    talk = function(words) spoken[#spoken + 1] = words end,
    turn = function(value) direction = value; turns[#turns + 1] = value end
}
g_settings = { getString = function(key)
    if key:find('_attack_default_lureSpell', 1, true) then return selection end
    return ''
end }
g_map = { getTile = function()
    if not walkable then return nil end
    return { getGround = function() return true end,
        isWalkable = function() return true end }
end }
modules = { game_interface = { getMapPanel = function()
    return { getSpectators = function() return spectators end }
end } }
Spells = { getPrimaryGroup = function(spell)
    for group in pairs(spell.group or {}) do return group end
end }

local function support(id, name, words, vocationIds, exhaustion)
    return { id = id, name = name, words = words, type = 'Instant',
        level = 150, mana = 80, premium = true, vocations = vocationIds,
        group = { [3] = 2000 }, exhaustion = exhaustion or 2000 }
end
SpellInfo = { Default = {
    ['Chivalrous Challenge'] = support(237, 'Chivalrous Challenge',
        'exeta amp res', { 4, 8 }),
    ['Challenge'] = support(42, 'Challenge', 'exeta res', { 4, 8 }),
    ['Divine Dazzle'] = support(238, 'Divine Dazzle',
        'exana amp res', { 3, 7 }, 16000),
    ['Balanced Brawl'] = support(280, 'Balanced Brawl',
        'exori mas res', { 9, 10 }, 10000),
    ['Levitate'] = support(81, 'Levitate', 'exani hur',
        { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }),
    ['Magic Rope'] = support(76, 'Magic Rope', 'exani tera',
        { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 })
} }

dofile('modules/game_baiakeros_helper/helper.lua')

local rotation
for index = 1, 100 do
    local name, value = debug.getupvalue(init, index)
    if not name then break end
    if name == 'checkAttackRotation' then rotation = value; break end
end
assert(rotation, 'Shooter rotation callback not found')

helperWindow = { recursiveGetChildById = function() return nil end }
attackRotationEnabled = true

rotation()
assert(spoken[1] == 'exeta amp res',
    'Shooter must cast configured lure spell without Cavebot')

now = now + 3000
spoken = {}
walkable = false
rotation()
assert(#spoken == 0,
    'Chivalrous Challenge needs a free adjacent SQM')
walkable = true

healthPercent = 10
now = now + 3000
rotation()
assert(spoken[1] == 'exeta amp res',
    'Shooter must keep casting while potions heal low health')
healthPercent = 100

vocation = 12
selection = 'Divine Dazzle'
spoken = {}
now = now + 3000
rotation()
assert(spoken[1] == 'exana amp res',
    'Paladin lure spell must cast from Shooter')
local paladinState = getAttackState()
assert(paladinState.runeCount == 2 and paladinState.lureSlotVisible,
    'Paladin must retain two rune slots and one lure slot')

vocation = 15
selection = 'Balanced Brawl'
direction = North
now = now + 3000
rotation()
assert(turns[#turns] == East,
    'Monk must face the distant monster before casting')
now = now + 300
rotation()
assert(spoken[#spoken] == 'exori mas res',
    'Monk lure spell must cast from Shooter')
local monkState = getAttackState()
assert(monkState.runeCount == 2 and monkState.lureSlotVisible,
    'Monk must retain two rune slots and one lure slot')

attackRotationEnabled = false
spoken = {}
now = now + 3000
rotation()
assert(#spoken == 0, 'Disabled Shooter must not cast lure spells')

vocation = 11
direction = North
now = now + 3000
assert(not tryCastExplorerLevitate('up', West),
    'Levitate should face the selected direction first')
assert(direction == West)
now = now + 300
assert(tryCastExplorerLevitate('up', West),
    'Levitate should cast after turning')
assert(spoken[#spoken] == 'exani hur "up"')

assert(not tryCastExplorerMagicRope(), 'Magic Rope must respect Levitate support cooldown')
now = now + 2100
assert(tryCastExplorerMagicRope() and spoken[#spoken] == 'exani tera')
assert(not tryCastExplorerMagicRope(), 'Magic Rope must not flood repeated casts')
local originalMana = player.getMana
player.getMana = function() return 0 end
now = now + 2100
assert(not tryCastExplorerMagicRope(), 'Magic Rope requires sufficient mana')
player.getMana = originalMana
local ropeId, usedRope, ropeTarget
g_game.findPlayerItem = function(id)
    if id == ropeId then return { getId = function() return id end } end
end
g_game.useInventoryItemWith = function(id, target) usedRope, ropeTarget = id, target end
local ground = {}
g_map.getTile = function() return { getTopUseThing = function() return ground end } end
assert(tryUseExplorerRope(playerPosition) and usedRope == 3003,
    'closed backpack ropes are resolved through the server inventory hotkey')
assert(not tryUseExplorerRope(playerPosition), 'Rope must not flood item packets while waiting')
now = now + 2300
assert(tryUseExplorerRope(playerPosition) and usedRope == 646,
    'unknown closed backpack contents alternate between the two supported ropes')
now = now + 2300
ropeId = 3003
assert(tryUseExplorerRope(playerPosition) and usedRope == 3003 and ropeTarget == ground)
now = now + 2300
ropeId = 646
assert(tryUseExplorerRope(playerPosition) and usedRope == 646, 'Elvenhair Rope is supported')
now = now + 2300
assert(not tryUseExplorerRope({ x = 103, y = 100, z = 7 }), 'Rope must not be used outside adjacent reach')

print('Helper Shooter lure regression passed')
