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


-- Exercise the real Shooter callback rather than a replacement caster.
vocation, selection, direction = 14, '', South
currentVocation = { baseSpellVocation = 2, promotedSpellVocation = 6, promoted = true }
playerPosition = { x = 100, y = 104, z = 7 }
local earth = { id = 121, name = 'Earth Wave', words = 'exevo tera hur', type = 'Instant',
    mana = 170, level = 38, vocations = {2,6}, group = {[1]=2000}, exhaustion = 4000 }
local ice = { id = 171, name = 'Strong Ice Wave', words = 'exevo gran frigo hur', type = 'Instant',
    mana = 210, level = 70, vocations = {2,6}, group = {[1]=2000}, exhaustion = 8000 }
local slots = {
    attackSpellSlot1 = { assignedAttackSpell = earth, attackEnabled = true, attackPriority = 1, attackMinEnemies = 8 },
    attackSpellSlot2 = { assignedAttackSpell = ice, attackEnabled = true, attackPriority = 2, attackMinEnemies = 8 }
}
helperWindow.recursiveGetChildById = function(_, id) return slots[id] end
spectators = {}
for x=-1,1 do for y=-1,1 do if x~=0 or y~=0 then
    local p = { x = 100+x, y = 100+y, z=7 }
    spectators[#spectators+1] = {
        isMonster=function() return true end, isDead=function() return false end,
        getMasterId=function() return 0 end, getType=function() return 0 end,
        getHealthPercent=function() return 100 end, getPosition=function() return p end
    }
end end end
local casts, positioned = 0, false
modules.game_baiakeros_helper_v2 = { PartyHuntV2 = {
    prepareSpell = function(spell)
        return positioned and spell.words == getPartyHuntSpellPlan().words, North
    end,
    onSpellCast = function() casts = casts + 1 end
} }
local function callback(name)
    for index=1,100 do local key,value=debug.getupvalue(init,index)
        if not key then break end
        if key==name then return value end
    end
    error('Callback unavailable: '..name)
end
local spellCooldown, groupCooldown = callback('onSpellCooldown'), callback('onSpellGroupCooldown')
assert(getPartyHuntSpellPlan().words == earth.words)
rotation()
assert(#spoken==0 and #turns==0, 'Shooter must wait for the ED placement')
positioned=true
rotation()
assert(direction==North and #spoken==0, 'Shooter must confirm box-facing direction before casting')
now=now+300
rotation()
assert(spoken[1]==earth.words and casts==1, 'The actual Shooter must cast the positioned wave')
spellCooldown(earth.id, 4000)
groupCooldown(1, 2000)
assert(getPartyHuntSpellPlan().words==ice.words and not getPartyHuntSpellPlan().ready,
    'ED should prepare the next available spell during shared exhaustion')
rotation()
assert(#spoken==1, 'The attack group cooldown must prevent duplicate casts')
playerPosition = { x=100, y=103, z=7 }
now=now+2001
rotation()
assert(spoken[2]==ice.words and casts==2, 'The next configured wave must cast after its group cooldown')
slots.attackSpellSlot1.attackEnabled=false
slots.attackSpellSlot2.attackMinMana=101
assert(getPartyHuntSpellPlan()==nil, 'Position planning must honor enabled slots and mana thresholds')
print('Party Hunt Shooter passed: real rotation, placement, turn confirmation, individual/group cooldowns, next wave and mana gates')
