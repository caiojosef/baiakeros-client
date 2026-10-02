-- Run with: luajit tests/lua/party_hunt_shooter_spec.lua

North, East, South, West = 0, 1, 2, 3
NorthEast, SouthEast, SouthWest, NorthWest = 4, 5, 6, 7
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
    if spell.group and spell.group[1] then return 1 end
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
        local plan=getPartyHuntSpellPlan()
        return positioned and plan and spell.words == plan.words, North
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
assert(getPartyHuntSpellPlan()==nil,'shared exhaustion must not reposition the ED for an unavailable spell')
rotation()
assert(#spoken==1, 'The attack group cooldown must prevent duplicate casts')
playerPosition = { x=100, y=103, z=7 }
now=now+2001
rotation()
assert(spoken[2]==ice.words and casts==2, 'The next configured wave must cast after its group cooldown')
spellCooldown(earth.id,4000);spellCooldown(ice.id,8000)
local upcoming=getPartyHuntSpellPlan()
assert(upcoming==nil,'no cooled-down spell may produce a movement destination')
slots.attackSpellSlot1.attackEnabled=false
slots.attackSpellSlot2.attackMinMana=101
assert(getPartyHuntSpellPlan()==nil, 'Position planning must honor enabled slots and mana thresholds')
-- Circular spells must retain their real area even if the Party sends a facing.
local winter={id=43,name='Eternal Winter',words='exevo gran mas frigo',type='Instant',mana=100,
 level=100,vocations={2,6},group={[1]=4000,[7]=40000},exhaustion=40000}
local wrath={id=56,name='Wrath of Nature',words='exevo gran mas tera',type='Instant',mana=100,
 level=100,vocations={2,6},group={[1]=4000,[7]=40000},exhaustion=40000}
local burst={id=262,name='Ice Burst',words='exevo ulus frigo',type='Instant',mana=100,
 level=300,vocations={2,6},group={[1]=2000,[9]=22000},exhaustion=22000}
slots.attackSpellSlot2.attackEnabled=false
slots.attackSpellSlot3={assignedAttackSpell=winter,attackEnabled=true,attackPriority=3,attackMinEnemies=8}
now=now+10000;playerPosition={x=100,y=102,z=7};direction=South
local before=#spoken
rotation()
assert(#spoken==before+1 and spoken[#spoken]==winter.words,'real Shooter casts Gran Mas Frigo from the two-SQM slot')
spellCooldown(winter.id,40000);groupCooldown(1,4000);groupCooldown(7,40000)
slots.attackSpellSlot3.assignedAttackSpell=wrath
now=now+4001
assert(getPartyHuntSpellPlan()==nil,'secondary ultimate group prevents approaching for Gran Mas Tera too')
slots.attackSpellSlot4={assignedAttackSpell=burst,attackEnabled=true,attackPriority=4,attackMinEnemies=8}
assert(getPartyHuntSpellPlan().words==burst.words,'Ulus remains eligible while the ultimate group is cooling down')
playerPosition={x=100,y=103,z=7};before=#spoken
rotation()
assert(#spoken==before+1 and spoken[#spoken]==burst.words,'real Shooter keeps Ulus ring coverage at three SQMs')
spellCooldown(burst.id,22000);groupCooldown(9,22000)
slots.attackSpellSlot4.assignedAttackSpell={id=263,name='Terra Burst',words='exevo ulus tera',type='Instant',mana=100,
 level=300,vocations={2,6},group={[1]=2000,[9]=22000},exhaustion=22000}
now=now+2001
assert(getPartyHuntSpellPlan()==nil,'secondary burst group blocks the other Ulus spell')
now=now+40000;playerPosition={x=100,y=102,z=7};before=#spoken
rotation()
assert(#spoken==before+1 and spoken[#spoken]==wrath.words,'real Shooter casts Gran Mas Tera with circular coverage')
slots.attackSpellSlot3.attackEnabled=false
now=now+2001;playerPosition={x=100,y=103,z=7};before=#spoken
rotation()
assert(#spoken==before+1 and spoken[#spoken]=='exevo ulus tera','real Shooter casts Ulus Tera using its ring area')
slots.attackSpellSlot3=nil;slots.attackSpellSlot4=nil
-- Auto Attack follows the actual visible leader target, even with a closer monster.
local autoAttack=callback('checkAutoAttack')
local leaderTarget=spectators[8]
for index,creature in ipairs(spectators)do
    creature.getId=function()return index end
end
local actualTarget
g_game.attack=function(creature)actualTarget=creature end
g_game.getAttackingCreature=function()return actualTarget end
g_game.cancelAttack=function()actualTarget=nil end
local party=modules.game_baiakeros_helper_v2.PartyHuntV2
party.isActive=function()return true end
party.getLeaderTarget=function()return leaderTarget end
g_ui={getInputIdleMillis=function()error('active Party Hunt must bypass the manual-input AFK timer')end}
autoAttackEnabled,attackRotationEnabled,autoAttackMode=true,true,'A'
autoAttack()
assert(actualTarget==leaderTarget,'Helper must prefer the leader target over distance priority')
-- Blocking offensive spells in Always Run must still reach the rune branch.
slots.attackSpellSlot1.attackEnabled=true
slots.attackSpellSlot2.attackMinMana=0
slots.attackRuneSlot1={assignedAttackRune={id=3161,area=true},attackEnabled=true,attackMinEnemies=1}
party.prepareSpell=function()return false end
local runeUses=0
g_game.useInventoryItemWith=function(id,target)
    assert(id==3161 and target==leaderTarget)
    runeUses=runeUses+1
end
now=now+10000
local previousCasts=#spoken
rotation()
assert(runeUses==1 and #spoken==previousCasts,'Always Run skips waves and casts the configured Avalanche through the real Shooter')
now=now+180000
assert(not checkAttackAfkTimeout() and autoAttackEnabled and attackRotationEnabled,
    'one-hour Party Hunt must not disable combat after two idle minutes')
-- Entering PZ suppresses combat without forgetting the active party settings.
player.hasState=function()return true end
callback('onLocalPlayerStatesChange')(player,1,0)
assert(autoAttackEnabled and attackRotationEnabled,'PZ transition must preserve automatic Party Hunt helpers')
-- Drive the real Shooter and real follower together with asynchronous steps
-- and delayed server cooldown packets. A moving player cannot cast mid-step.
player.hasState=function()return false end
now=now+100000
playerPosition={x=100,y=104,z=7};direction=South
slots={
 attackSpellSlot1={assignedAttackSpell=earth,attackEnabled=true,attackPriority=1,attackMinEnemies=8},
 attackSpellSlot2={assignedAttackSpell=ice,attackEnabled=true,attackPriority=2,attackMinEnemies=8},
 attackSpellSlot3={assignedAttackSpell=winter,attackEnabled=true,attackPriority=3,attackMinEnemies=8},
 attackSpellSlot4={assignedAttackSpell=burst,attackEnabled=true,attackPriority=4,attackMinEnemies=8},
 attackSpellSlot5={assignedAttackSpell=wrath,attackEnabled=true,attackPriority=5,attackMinEnemies=8}
}
local box={x=100,y=100,z=7}
local walkTo,walkDoneAt=nil,0
local steps,pressureSteps,pressureCasts=0,0,0
local packets,castByWords,lastCastAt={}, {}, {}
local chasing=false
local chaserPosition
local incoming={vocation=2,leader={id=1,position=box},settings={runThreshold=3,alwaysRun=false},attackers={}}
player.getStepDuration=function()return 200 end
player.isWalking=function()return walkTo~=nil end
player.isAutoWalking=function()return false end
g_game.getChaseMode=function()return 0 end
g_game.setChaseMode=function()end
g_game.walk=function(d)
 assert(not walkTo,'must wait for the previous step confirmation')
 local offsets={{0,-1},{1,0},{0,1},{-1,0},{1,-1},{1,1},{-1,1},{-1,-1}}
 local o=offsets[d+1]
 walkTo={x=playerPosition.x+o[1],y=playerPosition.y+o[2],z=7}
 walkDoneAt=now+200;steps=steps+1
end
g_map.getCreatureById=function()return {getPosition=function()return box end}end
g_map.isSightClear=function()return true end
g_map.getTile=function(p)
 local occupied=p.x==box.x and p.y==box.y
 for _,m in ipairs(spectators)do
  local q=m:getPosition();if p.x==q.x and p.y==q.y then occupied=true end
 end
 return {getGround=function()return true end,isWalkable=function(_,ignoreCreatures)return ignoreCreatures or not occupied end}
end
BaiakHelperExplorerV2={isSafeMovementTile=function()return true end}
modules.game_baiakeros_helper={getPartyHuntSpellPlan=getPartyHuntSpellPlan}
dofile('modules/game_baiakeros_helper_v2/party_hunt_movement.lua')
dofile('modules/game_baiakeros_helper_v2/party_follower.lua')
party.prepareSpell=function(spell)return PartyFollower.prepareSpell(spell)end
party.onSpellCast=function()PartyFollower.onSpellCast()end
g_game.talk=function(words)
 assert(not walkTo,'Shooter casts only after the step is confirmed')
 local selected=getPartyHuntSpellPlan()
 assert(selected and selected.ready and selected.words==words,'movement and Shooter must select the same ready spell')
 local spell
 for _,slot in pairs(slots)do if slot.assignedAttackSpell.words==words then spell=slot.assignedAttackSpell;break end end
 assert(spell and (not lastCastAt[words] or now-lastCastAt[words]>=spell.exhaustion), 'respect each real spell cooldown')
 lastCastAt[words]=now;castByWords[words]=(castByWords[words] or 0)+1
 if chasing then pressureCasts=pressureCasts+1 end
 if not chasing and (words==winter.words or words==wrath.words) then
  assert(PartyHuntMovement.distance(playerPosition,box)==2,'stationary ultimate is two SQMs behind the leader')
 end
 packets[#packets+1]={at=now+50,spell=spell}
end
local function simulate(count)
 for i=1,count do
  now=now+50
  if walkTo and now>=walkDoneAt then
   if chasing then chaserPosition=playerPosition end
   playerPosition=walkTo;walkTo=nil
  end
  for index=#packets,1,-1 do
   local packet=packets[index]
   if now>=packet.at then
    spellCooldown(packet.spell.id,packet.spell.exhaustion)
    for group,seconds in pairs(packet.spell.group)do groupCooldown(group,seconds)end
    table.remove(packets,index)
   end
  end
  PartyFollower.update(incoming,true);rotation()
  assert(PartyHuntMovement.distance(playerPosition,box)<=5,'do not flee beyond the box')
 end
end
simulate(600)
assert(castByWords[earth.words] and castByWords[ice.words] and (castByWords[winter.words] or castByWords[wrath.words]) and castByWords[burst.words],
 'stationary casts: earth='..tostring(castByWords[earth.words])..', ice='..tostring(castByWords[ice.words])..
 ', winter='..tostring(castByWords[winter.words])..', Ulus='..tostring(castByWords[burst.words]))
chasing=true;incoming.attackers={{id=11},{id=12},{id=13}}
chaserPosition={x=playerPosition.x+1,y=playerPosition.y,z=7}
spectators[#spectators+1]={isMonster=function()return true end,isDead=function()return false end,
 getMasterId=function()return 0 end,getType=function()return 0 end,getHealthPercent=function()return 100 end,
 getPosition=function()return chaserPosition end}
pressureSteps=steps
simulate(800)
assert(steps>pressureSteps+30 and pressureCasts>=5,'adjacent damage must keep circling and using the actual Shooter repeatedly: steps='..
 (steps-pressureSteps)..', casts='..pressureCasts)
print('Party Hunt Shooter passed: '..pressureCasts..' casts while pursued, '..(steps-pressureSteps)..' confirmed steps; real waves/ultimates/Ulus, individual and shared cooldowns, leader target and AFK/PZ persistence')
