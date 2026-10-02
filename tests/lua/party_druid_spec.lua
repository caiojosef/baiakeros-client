-- Execute the actual movement controller without a live character.
North,East,South,West=0,1,2,3
NorthEast,SouthEast,SouthWest,NorthWest=4,5,6,7
DontChase,ChaseOpponent=0,1
PlayerStates={Pz=1}
local time,position,health,mana,chase=1000,{x=100,y=102,z=7},100,1000,ChaseOpponent
local walking,autoWalking,pz,plan=false,false,false,nil
local turns,moves,talks={},0,{}
local facing=South
local confirmTurns=true
local monsters,holes,walls={},{},{}
local box={x=100,y=100,z=7}
for x=-1,1 do for y=-1,1 do if x~=0 or y~=0 then
    monsters[#monsters+1]={x=100+x,y=100+y,z=7}
end end end
local player={getPosition=function()return position end,getHealthPercent=function()return health end,
    getMana=function()return mana end,getMaxMana=function()return 1000 end,
    getStepDuration=function()return 200 end,isWalking=function()return walking end,
    isAutoWalking=function()return autoWalking end,isDead=function()return false end,
    hasState=function()return pz end,getDirection=function()return facing end}
local directions={{0,-1},{1,0},{0,1},{-1,0},{1,-1},{1,1},{-1,1},{-1,-1}}
g_clock={millis=function()return time end}
g_game={getLocalPlayer=function()return player end,isOnline=function()return true end,
    getChaseMode=function()return chase end,setChaseMode=function(v)chase=v end,
    walk=function(direction)
        local d=directions[direction+1]
        position={x=position.x+d[1],y=position.y+d[2],z=position.z};moves=moves+1
        assert(not holes[position.x..':'..position.y], 'never enter a hole')
    end,turn=function(d)turns[#turns+1]=d;if confirmTurns then facing=d end end,talk=function(words)talks[#talks+1]=words end}
g_map={getCreatureById=function()return {getPosition=function()return box end}end,
    getTile=function(p)
        local occupied=p.x==box.x and p.y==box.y
        for _,m in ipairs(monsters)do if p.x==m.x and p.y==m.y then occupied=true end end
        return {getGround=function()return true end,
            isWalkable=function(_,ignoreCreatures)return not walls[p.x..':'..p.y] and
                (ignoreCreatures or not occupied) and math.abs(p.x-100)<=7 and math.abs(p.y-100)<=7 end}
    end}
BaiakHelperExplorerV2={isSafeMovementTile=function(p)return not holes[p.x..':'..p.y]end}
modules={game_baiakeros_helper={getPartyHuntSpellPlan=function()return plan end},
    game_interface={getMapPanel=function()return {getSpectators=function()
        local result={}
        for _,p in ipairs(monsters)do
            result[#result+1]={getPosition=function()return p end,isMonster=function()return true end,
                isDead=function()return false end,getMasterId=function()return 0 end}
        end
        return result
    end}end}}
dofile('modules/game_baiakeros_helper_v2/party_hunt_movement.lua')
dofile('modules/game_baiakeros_helper_v2/party_follower.lua')
dofile('modules/game_baiakeros_helper_v2/party_druid.lua')
local M,D=PartyHuntMovement,PartyDruid
local status={leader={id=1,position=box,phase='fight'},attackers={},settings={runThreshold=3,alwaysRun=false}}
local earth={words='exevo tera hur',ready=true,minEnemies=1,profile={shape='directional'},offsets={
    {0,-1},{0,-2},{-1,-3},{0,-3},{1,-3},{-1,-4},{0,-4},{1,-4},{-1,-5},{0,-5},{1,-5}}}
local ice={words='exevo gran frigo hur',ready=true,minEnemies=1,profile={shape='directional'},offsets={
    {0,-1},{-1,-2},{0,-2},{1,-2},{-1,-3},{0,-3},{1,-3},{-1,-4},{0,-4},{1,-4}}}
local ue={words='exevo gran mas frigo',ready=true,minEnemies=1,profile={shape='circle',radius=5,manhattan=5}}
local function update() D.update(status);time=time+250 end
assert(not D.prepareSpell(earth), 'wait for the first authoritative follower update')
plan=earth
for i=1,10 do update()end
assert(position.x==100 and position.y==104,'Earth Wave holds the nearest cardinal position at four SQMs')
local ready,direction=D.prepareSpell(earth)
assert(ready and direction==North and #talks==0,'movement positions; only Shooter casts combat spells')
D.onSpellCast()
plan=ice;plan.ready=false
for i=1,5 do update()end
local oldMoves=moves;for i=1,8 do update()end
assert(moves==oldMoves and position.y==104 and facing==North,'cooling-down ice wave must not move the Druid out of the last position')
plan.ready=true
for i=1,5 do update()end
assert(position.y==103 and D.prepareSpell(ice),'next ice wave advances one SQM')
plan=ue
for i=1,3 do update()end
assert(position.y==102 and D.prepareSpell(ue),'Gran Mas Frigo holds two SQMs and remains castable')
D.reset();position={x=100,y=103,z=7}
holes={['100:102']=true,['100:98']=true,['102:100']=true,['98:100']=true}
for i=1,5 do update()end
assert(position.y==103,'all occupied two-SQM slots fall back to a free cardinal slot')
holes['100:102']=nil
for i=1,5 do update()end
assert(position.y==102 and facing==North,'UE takes its two-SQM slot as soon as it becomes free, never adjacent to EK')
holes={}
for _,case in ipairs({
    {words='exevo gran mas tera',radius=2,profile={shape='circle',radius=6,manhattan=6}},
    {words='exevo ulus frigo',radius=3,profile={shape='ring',radius=4,manhattan=5,innerRadius=1}},
    {words='exevo ulus tera',radius=3,profile={shape='ring',radius=4,manhattan=5,innerRadius=1}}
}) do
    D.reset();position={x=100,y=104,z=7}
    plan={words=case.words,ready=true,minEnemies=8,profile=case.profile}
    for i=1,12 do update()end
    local permitted,turn=D.prepareSpell(plan)
    assert(position.x==100 and position.y==100+case.radius and permitted and turn==nil,
        case.words..' must use its own formation and full circular/ring coverage, without a wave direction')
end
-- Tolerate two actual attackers even with low HP/mana and lost health.
D.reset();position={x=100,y=104,z=7};plan=earth;plan.ready=false
status.attackers={{id=10},{id=11}};health=30;mana=100
for i=1,8 do update()end
local heldMoves=moves
for i=1,8 do update()end
assert(moves==heldMoves and position.y==104,'two attackers do not override the configured standing tolerance')
plan.ready=true;update();assert(D.prepareSpell(earth),'a tolerated attack does not prevent the configured wave')
status.attackers={{id=10},{id=11},{id=12}}
for i=1,8 do update();assert(M.distance(position,box)<=5)end
assert(moves>heldMoves,'setting three starts circling at exactly three actual attackers')
status.attackers={{id=10},{id=11}};health,mana=100,1000
for i=1,18 do update()end
heldMoves=moves;for i=1,6 do update()end
assert(moves==heldMoves and D.prepareSpell(earth),'resume and hold formation when pressure drops to the limit')
status.settings.runThreshold=6
status.attackers={};for i=1,5 do status.attackers[i]={id=i}end
for i=1,6 do update()end
heldMoves=moves;for i=1,6 do update()end
assert(moves==heldMoves,'setting six holds against five attackers')
status.attackers[6]={id=6};for i=1,6 do update()end
assert(moves>heldMoves,'setting six starts circling at exactly six attackers')
status.settings.runThreshold=3;status.settings.alwaysRun=true;status.attackers={}
heldMoves=moves
for i=1,10 do update();assert(M.distance(position,box)<=5)end
assert(moves>heldMoves and not D.prepareSpell(earth) and not D.prepareSpell({words='exori frigo'}),
 'Always Run moves without stopping for attack spells; runes remain owned by the Shooter')
status.settings.alwaysRun=false
-- A newly blocked destination must replan instead of pursuing the occupied tile.
D.reset();position={x=100,y=104,z=7};plan=ice;plan.ready=true
holes['100:103']=true
for i=1,16 do update()end
heldMoves=moves;for i=1,6 do update()end
assert(moves==heldMoves and not (position.x==100 and position.y==103),'blocked formation switches to another safe side')
holes={}
-- Persistent ranged targeting must still leave brief, safe Shooter cast windows.
status.settings.runThreshold=1
D.reset();position={x=100,y=104,z=7};plan=earth;status.attackers={{id=10}}
local castWindow=false
local previousMoves=moves
for i=1,14 do
    plan.ready=(i%8==1) -- Shooter's shared attack cooldown, not a cast every tick.
    update()
    if plan.ready and D.prepareSpell(earth) then castWindow=true;D.onSpellCast() end
end
plan.ready=true
assert(castWindow and moves>previousMoves,'escape must keep moving and still allow safe casts: window='..tostring(castWindow)..', steps='..(moves-previousMoves))
-- Three monsters actually targeting the Druid trigger a wider escape.
status.settings.runThreshold=3
status.attackers={{id=10},{id=11},{id=12}}
health=30;mana=100
for i=1,8 do update();assert(M.distance(position,box)<=5 and M.distance(position,box)>=1)end
assert(M.distance(position,box)>=3 and moves>previousMoves,'heavy pressure keeps circling outside the box')
holes['100:104']=true
for i=1,6 do update()end
-- Default tolerance holds against two damagers, then runs against a third.
D.reset();status.settings={runThreshold=3,alwaysRun=false};position={x=100,y=103,z=7}
health,mana=100,1000;holes={};plan=earth;status.attackers={{id=1}}
for i=1,8 do update()end
heldMoves=moves;for i=1,5 do update()end
assert(moves==heldMoves,'one damager keeps the default formation')
status.attackers[2]={id=2};for i=1,8 do update()end
assert(moves==heldMoves,'two damagers remain within the default tolerance')
status.attackers[3]={id=3};for i=1,8 do update()end
assert(moves>heldMoves,'three damagers reach the configured trigger')
-- Delayed direction packets must not turn the 50 ms planner into packet spam.
D.reset();status.attackers={};position={x=100,y=104,z=7};plan=earth
for i=1,8 do update()end
facing=South;confirmTurns=false
local oldTurns=#turns;heldMoves=moves
for i=1,20 do D.update(status);time=time+50 end
assert(#turns>oldTurns and #turns-oldTurns<=4 and moves==heldMoves,
    'retry an unconfirmed facing at most four times per second without leaving formation')
confirmTurns=true;facing=North;oldTurns=#turns
for i=1,20 do D.update(status);time=time+50 end
assert(#turns==oldTurns,'confirmed facing stops turn retries')
-- Same distance is not enough: the stationary slot must see the leader.
D.reset();position={x=100,y=104,z=7};status.attackers={};plan=earth
g_map.isSightClear=function(a,b)
    local p=M.same(a,box) and b or a
    return not (p.x>=98 and p.x<=102 and p.y>=102)
end
for i=1,24 do update()end
assert(g_map.isSightClear(position,box) and M.distance(position,box)==4 and D.prepareSpell(earth),
    'an occluded wave slot replans to another reachable cardinal side')
status.attackers={{id=1},{id=2},{id=3}}
heldMoves=moves
for i=1,20 do
    update()
    assert(g_map.isSightClear(position,box) and M.distance(position,box)<=5,
        'pressure must circle visible box tiles rather than hiding behind the wall')
end
assert(moves>heldMoves,'visible pressure orbit keeps moving')
g_map.isSightClear=nil
-- Three attackers close the cardinal exits beside a wall. The free diagonal
-- can pass between creatures, then continue below the leader's box.
D.reset();position={x=103,y=100,z=7};plan=nil
status.settings={runThreshold=3,alwaysRun=false};status.attackers={{id=1},{id=2},{id=3}}
local boxMonsters=monsters
monsters={{x=104,y=100,z=7},{x=103,y=101,z=7},{x=102,y=100,z=7}}
holes={}
for x=93,107 do for y=93,99 do holes[x..':'..y]=true end end
update()
assert(position.x==104 and position.y==101,
 'the third attacker must trigger the free southeast diagonal despite occupied flanking tiles')
local passedBelow=false
for i=1,24 do
 update()
 assert(M.distance(position,box)>=3 and M.distance(position,box)<=5)
 if position.y>=103 and position.x<=box.x then passedBelow=true end
end
assert(passedBelow,'continue around the box underneath instead of stopping beside its blocked eastern side')
-- Ignoring creatures on the flanks must never ignore their terrain. Close the
-- only diagonal with a solid wall, then a floor-transition tile.
monsters={{x=103,y=101,z=7},{x=102,y=100,z=7},{x=105,y=104,z=7}}
D.reset();position={x=103,y=100,z=7};walls['104:100']=true;heldMoves=moves
update()
assert(moves==heldMoves,'a solid wall on the flank still forbids cutting the diagonal corner')
walls={};holes['104:100']=true;D.reset();position={x=103,y=100,z=7}
update()
assert(moves==heldMoves,'a hole or staircase flank still forbids the diagonal')
monsters=boxMonsters;holes={}
-- Sorcerers use the closest cardinal slot at three SQMs and face the box.
D.reset();status.vocation=1;status.attackers={};position={x=104,y=102,z=7};plan=ice
for i=1,12 do PartyFollower.update(status,false);time=time+250 end
assert(position.x==103 and position.y==100 and facing==West,'MS chooses the closest eastern cardinal slot at three SQMs')
heldMoves=moves;plan=nil
for i=1,8 do PartyFollower.update(status,false);time=time+250 end
assert(moves==heldMoves and facing==West,'MS holds and faces the box without a ready spell')
plan=earth
-- Knight must never inherit ranged movement options, even from a stale payload.
D.reset();position={x=100,y=103,z=7};status.vocation=4
status.settings.alwaysRun=true;status.attackers={{id=10},{id=11},{id=12},{id=13}}
heldMoves=moves;for i=1,8 do PartyFollower.update(status,false);time=time+250 end
assert(moves==heldMoves and PartyFollower.prepareSpell({words='exori'}),'Knight has no distance/running options')
status.vocation=2;status.settings.alwaysRun=false
-- A failed/stale state cannot face and cast a wave on another floor.
box={x=100,y=100,z=6};status.leader.position=box
assert(D.update(status):find('outro andar') and not D.prepareSpell(earth))
box={x=100,y=100,z=7};status.leader.position=box
status.leader.phase='travel';status.attackers={};health,mana=100,1000;monsters={};plan=nil;D.reset()
position={x=100,y=106,z=7};holes={}
for i=1,8 do update()end
assert(M.distance(position,box)==3,'follow prefers the three-SQM orbit radius')
assert(chase==DontChase)
D.reset();assert(chase==ChaseOpponent,'stop restores the player chase mode')
assert(#talks==0,'no combat spell or healing outside Shooter/Helper')
print('PASS: actual Druid controller, Druid formation 4/3/2 and MS/default 3, no cooldown repositioning, pressure cast windows, thresholds 1/2/6, always-run, occupied formation recovery, visible clockwise retreat, bounded radius and floor safety')
