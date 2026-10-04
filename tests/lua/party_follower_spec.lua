-- Actual shared controller: manual stairs, accidental floor recovery and all-vocation follow.
North,East,South,West=0,1,2,3
NorthEast,SouthEast,SouthWest,NorthWest=4,5,6,7
DontChase,ChaseOpponent=0,1
PlayerStates={Pz=1}
local time,position,box,chase=1000,{x=100,y=105,z=7},{x=100,y=100,z=7},ChaseOpponent
local moves,spellQueries,direction=0,0,North
local hole,passage,tileExit
local void, failures, casts = nil,0,{}
local directions={{0,-1},{1,0},{0,1},{-1,0},{1,-1},{1,1},{-1,1},{-1,-1}}
local function same(a,b)return a and b and a.x==b.x and a.y==b.y and a.z==b.z end
local player={getPosition=function()return position end,getHealthPercent=function()return 100 end,
 getMana=function()return 1000 end,getMaxMana=function()return 1000 end,
 getStepDuration=function()return 150 end,isWalking=function()return false end,
 isAutoWalking=function()return false end,isDead=function()return false end,
 hasState=function()return true end,getDirection=function()return direction end}
g_clock={millis=function()return time end}
g_game={getLocalPlayer=function()return player end,isOnline=function()return true end,
 getChaseMode=function()return chase end,setChaseMode=function(v)chase=v end,
 walk=function(d)
  local old=position;direction=d;local v=directions[d+1]
  local next={x=old.x+v[1],y=old.y+v[2],z=old.z}
  assert(not same(next,hole),'normal following must avoid the learned/unsafe hole')
  if passage and same(old,passage.entry) and failures>0 then
   failures=failures-1;PartyFollower.onCancelWalk();return false
  end
  if passage and same(old,passage.entry) and d==passage.direction or tileExit and same(old,tileExit.entry) then
   next=passage and passage.exit or tileExit.exit
  end
  position=next;moves=moves+1;PartyFollower.onPositionChange(position,old)
 end,
 turn=function(d)direction=d end,
 talk=function()error('basic Stair following never casts combat or levitation spells')end}
g_map={getCreatureById=function()return {getPosition=function()return box end}end,
 getTile=function(p)return {getGround=function()return not same(p,void)end,
  isWalkable=function()return math.abs(p.x-100)<=10 and math.abs(p.y-100)<=10 and not same(p,box)end,
  hasElevation=function()return tileExit and same(p,tileExit.entry)end}end}
BaiakHelperExplorerV2={isSafeMovementTile=function(p)
 return not same(p,hole) and not (tileExit and same(p,tileExit.entry))
end}
modules={game_baiakeros_helper={getPartyHuntSpellPlan=function()spellQueries=spellQueries+1;return nil end},
 game_interface={getMapPanel=function()return {getSpectators=function()return {} end}end}}
dofile('modules/game_baiakeros_helper_v2/party_hunt_movement.lua')
dofile('modules/game_baiakeros_helper_v2/party_follower.lua')
local F,M=PartyFollower,PartyHuntMovement
local status={leader={id=1,position=box,transitions={}},attackers={}}
local function update()local text=F.update(status,false);time=time+150;return text end
for i=1,8 do update()end
assert(M.distance(position,box)==3 and moves>0 and spellQueries==0,
 'all-vocation members follow inside PZ, without Cavebot or querying the Druid rotation')

-- Leader walks upstairs manually; empty history still uses the current passage.
F.reset();position={x=100,y=103,z=7};box={x=100,y=99,z=6};status.leader.position=box
passage={entry={x=100,y=101,z=7},exit={x=100,y=100,z=6},kind='stair',direction=North}
status.leader.transition=passage
void={x=100,y=100,z=7};failures=2
for i=1,20 do
 update()
 if i==3 then status.leader.transition=nil end -- temporary snapshot loses the passage
end
assert(position.z==6 and M.distance(position,box)==3,'member must use the reported manual staircase')
assert(failures==0,'cancelled staircase steps must be retried until the floor actually changes')
passage,void=nil,nil

-- The leader goes down; the member follows the descending passage too.
F.reset();position={x=102,y=100,z=6};box={x=100,y=103,z=7};status.leader.position=box
passage={entry={x=100,y=100,z=6},exit={x=100,y=102,z=7},kind='stair',direction=South}
status.leader.transitions={passage};status.leader.transition=nil
for i=1,8 do update()end
assert(position.z==7 and M.distance(position,box)==3,'member must also follow downstairs')
passage=nil

-- A follower fell while the leader stayed upstairs. Only the known return tile is allowed.
F.reset();box={x=100,y=99,z=7};status.leader.position=box;status.leader.transitions={}
local before={x=101,y=101,z=7}
position={x=101,y=101,z=8};F.onPositionChange(position,before)
tileExit={entry={x=100,y=101,z=8},exit={x=100,y=100,z=7},kind='stair',tile=true}
status.returnPassage=tileExit
for i=1,8 do update()end
assert(position.z==7,'accidental descent must return via the server-confirmed staircase')
tileExit=nil;status.returnPassage=nil

-- Navigation magic retries with support cooldown, faces correctly, and keeps the passage pinned.
g_game.talk=function(words)
 casts[#casts+1]=words
 if failures>0 then failures=failures-1;return end
 local old=position;position=passage.exit;F.onPositionChange(position,old)
end
for _,kind in ipairs({'hur_down','hur_up','rope'}) do
 F.reset();position={x=100,y=101,z=kind=='hur_up' and 8 or 7}
 box={x=100,y=99,z=kind=='hur_down' and 8 or kind=='hur_up' and 7 or 6};status.leader.position=box
 passage={entry=position,exit={x=100,y=100,z=box.z},kind=kind,direction=East,authoritative=true}
 status.leader.transitions={passage};direction=North;failures=2;casts={}
 for i=1,50 do update();if i==2 then status.leader.transitions={}end end
 local expected=kind=='rope' and 'exani tera' or kind=='hur_down' and 'exani hur "down' or 'exani hur "up'
 assert(position.z==box.z and #casts==3 and casts[1]==expected,
  kind..' must retry the exact magic until the server confirms the transition')
 if kind~='rope' then assert(direction==East,'levitation must turn before casting')end
end
passage=nil;status.leader.transitions={}

-- A ladder can be blocked for walking and still usable from an adjacent SQM.
F.reset();position={x=101,y=101,z=7};box={x=100,y=99,z=6};status.leader.position=box
local ladder={entry={x=100,y=101,z=7},exit={x=100,y=100,z=6},kind='use',itemId=435,authoritative=true}
status.leader.transitions={ladder}
local originalTile=g_map.getTile
g_map.getTile=function(p)
 if same(p,ladder.entry)then return {getGround=function()return true end,isWalkable=function()return false end,
  getTopUseThing=function()return {isItem=function()return true end,getId=function()return 435 end}end}end
 return originalTile(p)
end
local uses=0
g_game.use=function(item)
 assert(item:getId()==435);uses=uses+1
 local old=position;position=ladder.exit;F.onPositionChange(position,old)
end
for i=1,8 do update()end
assert(uses==1 and position.z==6,'blocked ladder must be used from the recorded adjacent position')
g_map.getTile=originalTile;status.leader.transitions={}

-- Unknown floor changes do not choose arbitrary holes or cast anything.
F.reset();position={x=100,y=100,z=9}
local previousMoves=moves
assert(update():find('outro andar') and moves==previousMoves)
F.reset();assert(chase==ChaseOpponent,'Stop restores the member chase preference')
print('PASS: shared follow, three-SQM radius, PZ, persistent void stairs/cancel retries, exact up/down/rope magic, adjacent ladder, accidental return and unknown-floor safety')
