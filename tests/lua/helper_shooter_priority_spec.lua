-- Actual Shooter callback and authoritative cooldown handlers; no replacement caster.
North,East,South,West=0,1,2,3
PlayerStates={Pz=1}
table.contains=function(values,expected)
    for _,value in ipairs(values)do if value==expected then return true end end
    return false
end
local now=1000
local pz,following,runesOnly,positioned=false,false,false,true
local spoken,used={},{}
local position={x=100,y=100,z=7}
local target={isDead=function()return false end,isMonster=function()return true end,
    getMasterId=function()return 0 end,getType=function()return 0 end,getHealthPercent=function()return 100 end,
    getPosition=function()return {x=103,y=100,z=7}end}
local player={getName=function()return 'Priority Test'end,getVocation=function()return 13 end,
    getLevel=function()return 1000 end,isPremium=function()return true end,isDead=function()return false end,
    hasState=function()return pz end,getHealthPercent=function()return 100 end,
    getMana=function()return 5000 end,getMaxMana=function()return 5000 end,
    getPosition=function()return position end,getDirection=function()return North end}
g_clock={millis=function()return now end}
g_game={isOnline=function()return true end,getLocalPlayer=function()return player end,
    getAttackingCreature=function()return target end,
    talk=function(words)spoken[#spoken+1]=words end,
    useInventoryItemWith=function(id,creature)assert(creature==target);used[#used+1]=id end,
    turn=function()error('target spells must not turn the caster')end}
g_settings={getString=function()return ''end}
g_map={getTile=function()return {getGround=function()return true end,isWalkable=function()return true end}end}
modules={game_interface={getMapPanel=function()return {getSpectators=function()return {target}end}end}}
Spells={getPrimaryGroup=function()return 1 end}
SpellInfo={Default={}}
local function spell(id,words,cooldown)
    return {id=id,words=words,name=words,type='Instant',level=10,mana=20,vocations={1,5},
        group={[1]=2000},exhaustion=cooldown,needTarget=true,range=7}
end
local first=spell(89,'exori flam',4000)
local second=spell(88,'exori vis',10000)
local third=spell(87,'exori mort',12000)
-- Physical row order and rune priority deliberately differ from spell priority.
local slots={
    attackSpellSlot1={assignedAttackSpell=third,attackEnabled=true,attackPriority=3,attackMinEnemies=1},
    attackSpellSlot2={assignedAttackSpell=first,attackEnabled=true,attackPriority=1,attackMinEnemies=1},
    attackSpellSlot3={assignedAttackSpell=second,attackEnabled=true,attackPriority=2,attackMinEnemies=1},
    attackRuneSlot1={assignedAttackRune={id=3155,area=false},attackEnabled=true,attackPriority=5,attackMinEnemies=1},
    attackRuneSlot2={assignedAttackRune={id=3161,area=true},attackEnabled=true,attackPriority=1,attackMinEnemies=1}
}
dofile('modules/game_baiakeros_helper/helper.lua')
helperWindow={recursiveGetChildById=function(_,id)return slots[id]end}
currentVocation={baseSpellVocation=1,promotedSpellVocation=5,promoted=true}
attackRotationEnabled=true
local function callback(name)
    for index=1,100 do
        local key,value=debug.getupvalue(init,index)
        if not key then break end
        if key==name then return value end
    end
    error('missing real callback '..name)
end
local rotation=callback('checkAttackRotation')
local spellCooldown,groupCooldown=callback('onSpellCooldown'),callback('onSpellGroupCooldown')
modules.game_baiakeros_helper_v2={
    preferAreaExplorerAttack=function()return true end,
    PartyHuntV2={isFollowing=function()return following end,isRunesOnly=function()return runesOnly end,
        prepareSpell=function()return positioned end,onSpellCast=function()end}
}
local function cast(expected)
    local before=#spoken
    assert(getPartyHuntSpellPlan().words==expected.words,'movement must choose the highest ready priority')
    rotation()
    assert(#spoken==before+1 and spoken[#spoken]==expected.words,'wrong priority cast at '..now)
    -- Server responses arrive after the local duplicate guard.
    spellCooldown(expected.id,expected.exhaustion);groupCooldown(1,2000)
    assert(#used==0,'no rune may interrupt the ready spell sequence')
end
cast(first)
now=2999;rotation();assert(#spoken==1 and #used==0,'shared attack cooldown prevents premature spell/rune packets')
now=3000;cast(second)
now=5000;cast(first) -- First recovered before row three: preempt row three.
now=7000;cast(third)
now=9000;cast(first)
now=11000
assert(getPartyHuntSpellPlan()==nil,'all three individual cooldowns block positioning')
rotation();assert(#spoken==5 and #used==1 and used[1]==3161,'only after spells cool down may rune priority one fire')
groupCooldown(1,2000)
now=13000
assert(getPartyHuntSpellPlan().words==first.words,'first wins when two priorities recover together')
rotation();assert(spoken[#spoken]==first.words and #used==1,'recovering spell preempts the next rune')
spellCooldown(first.id,4000);groupCooldown(1,2000)

-- A Party member must position for the selected spell before consuming its
-- group with a lower spell/rune. No rune starvation once all spells cool down.
now=100000;following=true;positioned=false
local oldSpoken,oldUsed=#spoken,#used
rotation();assert(#spoken==oldSpoken and #used==oldUsed,'a ready spell waiting for formation suppresses the rune')
positioned=true;rotation()
assert(spoken[#spoken]==first.words and #used==oldUsed,'confirmed formation casts the selected spell')
for _,s in ipairs({first,second,third})do spellCooldown(s.id,30000)end
groupCooldown(1,2000);now=now+2000
rotation();assert(#used==oldUsed+1,'Party uses a rune when every eligible spell is cooling down')
groupCooldown(1,0)

-- Existing runes-only movement, manual priority and PZ remain respected.
now=200000;runesOnly=true;positioned=false
assert(getPartyHuntSpellPlan()==nil,'Always Run must not position for offensive spells')
oldSpoken,oldUsed=#spoken,#used
rotation();assert(#spoken==oldSpoken and #used==oldUsed+1,'explicit runes-only mode keeps its rune fallback')
groupCooldown(1,0);notifyManualAction('spell')
rotation();assert(#used==oldUsed+1,'manual hotkeys still preempt automatic runes')
now=now+750;pz=true;rotation()
assert(#used==oldUsed+1,'PZ suppresses automatic runes and spells')
print('PASS: strict spell priority restarts at one, real cooldown recovery, runes only as fallback, Party formation, Always Run, manual input and PZ')
