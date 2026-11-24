-- Run from the client root: luajit tests/lua/npc_dialog_identity_spec.lua

Controller={new=function()return {}end}
MessageModes={NpcFrom=1,NpcFromStartBlock=2,NpcTo=3}
local nearby={}
g_game={getLocalPlayer=function()return {getPosition=function()return {x=1,y=1,z=7}end}end}
g_map={getCreatureById=function()return nil end,getSpectators=function()return nearby end}
dofile('modules/game_npctrade/game_npctrader.lua')
dofile('modules/game_npctrade/controllers/npc_dialog.lua')
local c=controllerNpcTrader
c.findWidget=function()return nil end
function npc(name,id,outfit)
 return {getName=function()return name end,isNpc=function()return true end,getId=function()return id end,getOutfit=function()return outfit end}
end
local checks=0
local function check(value)assert(value);checks=checks+1 end
for i,name in ipairs({'Rashid','Galuna','Xodet','Gnomission','Eremo','A Sweaty Cyclops','The Blind Prophet'})do
 local outfit={type=100+i,head=i,body=i,legs=i,feet=i}
 local correct=npc(name,i,outfit)
 nearby={npc('Other NPC',999,{type=1}),correct}
 c:updateNpcIdentity(name)
 check(c.creatureName==name)
 check(c.npcCreatureId==i)
 check(c.outfit==outfit)
 c:updateNpcIdentity('Unknown NPC')
 check(c.outfit==nil and c.npcCreatureId==nil)
end
local outfit={type=493};nearby={npc('Gnomission',500,outfit)}
c.ui=nil
onNpcTalk('Gnomission',0,MessageModes.NpcFrom,'Hello',nil,{x=1,y=1,z=7})
check(c.creatureName=='Gnomission' and c.outfit==outfit)
onNpcTalk('Player Name',0,MessageModes.NpcTo,'trade')
check(c.creatureName=='Gnomission')
nearby={npc('Rashid',2,{type=146})};nearby[1].isNpc=function()return false end
c:updateNpcIdentity('Rashid')
check(c.outfit==nil and c.npcCreatureId==nil)
print('PASS: '..checks..' NPC identity checks')
return checks
