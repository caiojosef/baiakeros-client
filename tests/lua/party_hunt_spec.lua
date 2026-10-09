dofile('modules/corelib/json.lua')
local widgets, callbacks, requests = {}, {}, {}
local clock, tick, active = 1000, nil, false
local selfId=1
local paused,bossLever=false,false
local leaderOptions={auto=false,shooter=false}
local leaderPz,selfPz=false,false
local leaderTargetId,actualTarget
local attacks,cancels,ackAttack=0,0,true
local targets={}
for _,id in ipairs({101,102})do
 targets[id]={getId=function()return id end,isMonster=function()return true end,
  isDead=function(self)return self.dead==true end,getPosition=function()return {x=103,y=100,z=7}end}
end
g_map={getCreatureById=function(id)return targets[id]end}
local hotkey,editedKey,deletedKey
KEY_DOWN=1
DontChase=0
PlayerStates={Pz=1}
Keybind={chatMode=0,new=function()end,bind=function(_,_,keys)hotkey=keys[1].callback end,delete=function()deletedKey=true end}
local personalSettings={}
local selfVocation=2
local beamMastery=false
local function settings()
    personalSettings[selfId]=personalSettings[selfId] or {runThreshold=2,alwaysRun=false}
    return personalSettings[selfId]
end
local serverCooldown, tooMany, allPz, silent, follower = 0, false, true, false, false
local function widget(id)
    if widgets[id] then return widgets[id] end
    local w = {visible = true}
    for _, name in ipairs({'Text','Enabled','Percent','Height','Checked'}) do w['set'..name] = function(self,value) self[name:lower()] = value end end
    function w:addOption(label,data)self.option=self.option or {text=label,data=data}end
    function w:setCurrentOptionByData(data)self.option={data=data}end
    function w:getCurrentOption()return self.option end
    function w:isChecked()return self.checked end
    function w:getText()return self.text or 'Shared movement help' end
    function w:recursiveGetChildById(child) return widget(child) end
    function w:isVisible()return self.visible end
    function w:show()self.visible=true end
    function w:hide()self.visible=false end
    function w:raise()end
    function w:focus()end
    function w:destroy()end
    widgets[id]=w;return w
end
g_clock={millis=function()return clock end}
g_ui={importStyle=function()end,createWidget=function(style)return widget(style)end}
rootWidget,helperV2Window=widget('root'),widget('helper')
modules={game_walk={bindMovementKeysToWidget=function()end,unbindMovementKeysFromWidget=function()end},
 game_baiakeros_helper={setHelperButtonOn=function()end,
    setAutoAttackEnabled=function(enabled)
     modules.game_baiakeros_helper.autoAttackEnabled=enabled
     if PartyHuntV2 then PartyHuntV2.onCombatOptionChange('auto',enabled) end
    end,
    setAttackRotationEnabled=function(enabled)
     modules.game_baiakeros_helper.attackRotationEnabled=enabled
     if PartyHuntV2 then PartyHuntV2.onCombatOptionChange('shooter',enabled) end
    end},
 client_options={editKeybindActionPrimary=function(category,action)editedKey=category..':'..action end},
 game_baiakeros_helper_v2={showHelperV2Tab=function(tab)assert(tab=='party')end,show=function()helperV2Window:show()end}}
ProtocolGame={registerExtendedOpcode=function(opcode,callback)callbacks[opcode]=callback end,unregisterExtendedOpcode=function(opcode)callbacks[opcode]=nil end}
local function respond()
 callbacks[93](nil,93,json.encode({action='status',remaining=10800,limitSeconds=10800,active=active and selfId==1 or follower,following=follower and not paused,paused=paused,bossLever=bossLever,canControl=selfId==1 and not tooMany,
  canTeleport=selfId==1 and not tooMany and allPz and serverCooldown==0,tooMany=tooMany,teleportRemaining=serverCooldown,allProtectionZone=allPz,
  protectionZone=selfPz,settings=settings(),spellUpgrades={beamMastery=beamMastery},canConfigureMovement=selfVocation~=4,run='1:1',vocation=selfVocation,reason='',leader={id=1,name='Leader',targetId=leaderTargetId,protectionZone=leaderPz,combat=leaderOptions},members={{id=1,name='Leader',leader=true},{id=2,name='Member'}}}))
end
g_game={isOnline=function()return true end,getLocalPlayer=function()return {
 getId=function()return selfId end,hasState=function()return selfPz end,isDead=function()return false end,
 getPosition=function()return {x=100,y=100,z=7}end}end,
 getAttackingCreature=function()return actualTarget end,
 attack=function(target)attacks=attacks+1;if ackAttack then actualTarget=target end;PartyHuntV2.onAttackingCreatureChange()end,
 cancelAttack=function()cancels=cancels+1;actualTarget=nil;PartyHuntV2.onAttackingCreatureChange()end,
 getProtocolGame=function()return {sendExtendedOpcode=function(_,opcode,buffer)
  local req=json.decode(buffer);requests[#requests+1]=req.action
  if selfId==1 and (req.action=='start' or req.action=='heartbeat') then
   leaderOptions={auto=req.autoAttack==true,shooter=req.shooter==true}
   leaderTargetId=actualTarget and actualTarget:getId() or nil
  end
  if req.action=='options' and selfVocation~=4 then personalSettings[selfId]={runThreshold=req.runThreshold,alwaysRun=req.alwaysRun,paladinMode=req.paladinMode,monkMode=req.monkMode}end
  if req.action=='start' then active=true elseif req.action=='stop' then if selfId==1 then active=false else paused=true end
  elseif req.action=='resume' then paused=false elseif req.action=='boss_lever' then bossLever=req.enabled end
  if not silent then respond() end
 end}end,
 walk=function()error('automatic movement is not enabled yet')end,
 setChaseMode=function(mode)assert(mode==DontChase,'member pause must not chase targets')end}
scheduleEvent=function(fn)tick=fn;return fn end
removeEvent=function()end
connect=function()end
disconnect=function()end
dofile('modules/game_baiakeros_helper_v2/party_hunt.lua')
PartyHuntV2.init(widget('window'))
assert(widget('partyStatus').text:find('Aguardando dados'))
PartyHuntV2.onGameStart()
assert(widget('partyTime').text=='03:00:00' and widget('partyProgress').percent==100,'three-hour server quota fills the timer and progress bar')
assert(widget('partyMember1').text=='1. Leader [Leader]' and widget('partyMember2').text=='2. Member')
assert(widget('partyStart').enabled )
assert(widget('partyRunThreshold').enabled and widget('partyRunThreshold').option.data==2)
widget('partyRunThreshold'):setCurrentOptionByData(6);widget('partyRunThreshold').onOptionChange()
assert(settings().runThreshold==6)
widget('partyAlwaysRun'):setChecked(true);widget('partyAlwaysRun').onCheckChange()
assert(settings().alwaysRun and widget('partyAlwaysRun').checked)
assert(widgets.partyGuide==nil and widgets.partyFollowDistance==nil and widgets.partyJsonEditor==nil)
widget('partyStart').onClick();assert(PartyHuntV2.isActive())
assert(widgets.partyTeleport==nil,'manual teleport widget is absent')
assert(widget('partyFloatLeverControls').visible and widget('partyFloatBossLever').enabled)
hotkey();assert(bossLever and widget('partyFloatBossLever').checked)
widget('partyFloatLeverHotkey').onClick();assert(editedKey=='Baiakeros Party Hunt:Boss lever formation')
assert(not PartyHuntV2.prepareSpell({words='exevo tera hur'}),'lineup suppresses offensive formation casting')
hotkey();assert(not bossLever)
assert(not modules.game_baiakeros_helper.autoAttackEnabled and not modules.game_baiakeros_helper.attackRotationEnabled,
 'Start does not silently turn on options the leader left disabled')
local combat=modules.game_baiakeros_helper
g_game.attack(targets[101]);local manualRequests=#requests
assert(actualTarget==targets[101] and not combat.autoAttackEnabled,'manual leader attack stays selected with Auto Attack off')
clock=clock+200;tick()
assert(#requests>manualRequests and leaderTargetId==101 and actualTarget==targets[101],
 'manual target publication occurs after the real attack packet; combat sync must not cancel it')
manualRequests=#requests
g_game.attack(targets[102]);clock=clock+50;tick()
assert(#requests==manualRequests,'rapid manual target changes do not flood party heartbeats')
clock=clock+100;tick();assert(leaderTargetId==102)
g_game.cancelAttack();clock=clock+200;tick();assert(leaderTargetId==nil)
combat.setAutoAttackEnabled(true)
assert(leaderOptions.auto and not leaderOptions.shooter and combat.autoAttackEnabled and not combat.attackRotationEnabled)
combat.setAttackRotationEnabled(true)
assert(leaderOptions.auto and leaderOptions.shooter)
leaderPz,selfPz=true,true;PartyHuntV2.onProtectionZoneChange()
assert(not combat.autoAttackEnabled and not combat.attackRotationEnabled,'leader combat is disabled inside PZ')
assert(leaderOptions.auto and leaderOptions.shooter,'PZ suppression must preserve requested options')
local zoneRequests=#requests;PartyHuntV2.onProtectionZoneChange();PartyHuntV2.onProtectionZoneChange()
assert(#requests==zoneRequests,'unrelated state changes cannot flood party heartbeats')
clock=clock+500;tick();assert(leaderOptions.auto and leaderOptions.shooter,'heartbeat reports choices, not suppressed booleans')
assert(not PartyHuntV2.prepareSpell({words='test'}))
leaderPz,selfPz=false,false;respond()
assert(combat.autoAttackEnabled and combat.attackRotationEnabled,'both choices resume outside PZ')
combat.setAutoAttackEnabled(false);combat.setAttackRotationEnabled(false)
assert(widget('BaiakerosPartyHuntFloat').visible and widget('BaiakerosPartyHuntFloat').height==318)
assert(widget('partyFloatRoster').text:find('Leader') and widget('partyFloatRoster').text:find('Member'))
clock=clock+1000;tick();assert(requests[#requests]=='heartbeat')
assert(PartyHuntV2.prepareSpell({words='test'})==true)
PartyHuntV2.minimize();assert(widget('BaiakerosPartyHuntFloat').height==318)
PartyHuntV2.openHelper();assert(not widget('BaiakerosPartyHuntFloat').visible)
widget('partyStart').onClick();assert(not PartyHuntV2.isActive())
assert(not modules.game_baiakeros_helper.autoAttackEnabled and not modules.game_baiakeros_helper.attackRotationEnabled)
selfId=2;respond();assert(not widget('partyStart').enabled)
local count=#requests;widget('partyStart').onClick()
assert(#requests==count and widget('partyRunThreshold').enabled and widget('partyAlwaysRun').enabled,
 'member can configure only personal movement, not leader Start')
assert(settings().runThreshold==2 and not settings().alwaysRun,'member does not inherit leader preferences')
widget('partyRunThreshold'):setCurrentOptionByData(1);widget('partyRunThreshold').onOptionChange()
widget('partyAlwaysRun'):setChecked(true);widget('partyAlwaysRun').onCheckChange()
assert(settings().runThreshold==1 and settings().alwaysRun and personalSettings[1].runThreshold==6,
 'editing one character must not change another character')
assert(not PartyHuntV2.isRunesOnly(),'stopped Party Hunt does not restrict independent Shooter spells')
selfVocation=4;respond()
assert(not widget('partyRunThreshold').visible and not widget('partyAlwaysRun').visible and widget('partyKnightNotice').visible)
count=#requests;widget('partyRunThreshold').onOptionChange();widget('partyAlwaysRun').onCheckChange()
assert(#requests==count,'Knight cannot send movement options even by invoking hidden controls')
selfId=1;respond();assert(widget('partyStart').enabled and not widget('partyAlwaysRun').visible,'Knight leader keeps Start controls')
selfVocation=2;respond();assert(widget('partyRunThreshold').visible and not widget('partyKnightNotice').visible)
assert(not widget('partyPaladinMode').visible,'other vocations do not see Paladin options')
selfId=2;selfVocation=3;respond()
assert(not PartyHuntV2.isRunesOnly(),'Paladin orbit keeps spells enabled instead of becoming rune-only')
assert(widget('partyPaladinMode').visible and widget('partyPaladinMode').enabled and
 not widget('partyAlwaysRun').visible and not widget('partyStart').enabled,
 'Paladin members choose only their own positioning; orbit is distinct from runes-only')
for _,mode in ipairs({'close','distance','orbit'})do
 widget('partyPaladinMode'):setCurrentOptionByData(mode);widget('partyPaladinMode').onOptionChange()
 assert(settings().paladinMode==mode and not settings().alwaysRun)
end
assert(widget('partyMovementHelp').text:find('exevo mas san'))
selfVocation=9;respond()
assert(widget('partyMonkMode').visible and widget('partyMonkMode').enabled and
 not widget('partyPaladinMode').visible and not widget('partyAlwaysRun').visible and not widget('partyStart').enabled,
 'Monk members configure their own two movement modes without controlling the leader')
assert(widget('partyMonkMode').option.data=='hold','Monk defaults to holding two SQMs')
for _,mode in ipairs({'hold','orbit'})do
 widget('partyMonkMode'):setCurrentOptionByData(mode);widget('partyMonkMode').onOptionChange()
 assert(settings().monkMode==mode and not settings().alwaysRun)
end
assert(widget('partyMovementHelp').text:find('Monk / Exalted Monk'))
selfVocation=2;respond()
assert(not widget('partyPaladinMode').visible and not widget('partyMonkMode').visible and widget('partyAlwaysRun').visible and
 widget('partyMovementHelp').text=='Shared movement help','changing vocation restores shared help and controls')
selfId=1;tooMany=true;respond();assert(not widget('partyStart').enabled and widget('partyWarning').text:find('4 pessoas'))
tooMany=false
-- A missing response is not mistaken for an absent party. Controls fail closed.
silent=true;clock=clock+9000;tick()
assert(widget('partyStatus').text:find('Sem resposta') and not widget('partyStart').enabled)
silent=false;respond()
assert(widget('partyMember1').text=='1. Leader [Leader]' and widget('partyStart').enabled)
callbacks[93](nil,93,json.encode({action='status',remaining=3600,active=false,canControl=false,members={}}))
assert(widget('partyStatus').text=='Entre em uma party para comecar' and widget('partyWarning').text=='')
local followerUpdates,resets=0,0
PartyFollower={update=function()followerUpdates=followerUpdates+1;return 'Following' end,
    reset=function()resets=resets+1 end,prepareSpell=function()return false end,onSpellCast=function()end,
    onPositionChange=function()end,onCancelWalk=function()end}
helperV2Window:hide()
selfId=2;follower=true;leaderOptions={auto=true,shooter=true};respond()
assert(PartyHuntV2.isFollowing() and not widget('partyStart').enabled)
selfVocation=9;settings().alwaysRun=true;respond()
assert(not PartyHuntV2.isRunesOnly(),'stale rune-only preference cannot suppress Monk spells while circling')
selfVocation=2;respond()
widget('partyAlwaysRun'):setChecked(true);widget('partyAlwaysRun').onCheckChange()
assert(PartyHuntV2.isRunesOnly(),'following Druid Always Run exposes the explicit rune-only mode to the Shooter')
widget('partyAlwaysRun'):setChecked(false);widget('partyAlwaysRun').onCheckChange()
assert(not PartyHuntV2.isRunesOnly(),'turning Always Run off restores offensive spell positioning')
assert(not widget('partyFloatLeverControls').visible)
assert(widget('partyFloatStop').enabled)
widget('partyFloatStop').onClick()
assert(paused and PartyHuntV2.isActive() and not PartyHuntV2.isFollowing())
assert(widget('BaiakerosPartyHuntFloat').visible and widget('partyFloatStop').text=='Resume Party Hunt')
assert(not modules.game_baiakeros_helper.autoAttackEnabled)
local calls=followerUpdates;clock=clock+500;tick();assert(calls==followerUpdates,'paused member does not send any follow steps')
respond();assert(not PartyHuntV2.isFollowing(),'status refresh preserves pause')
widget('partyFloatStop').onClick();assert(not paused and PartyHuntV2.isFollowing())
assert(modules.game_baiakeros_helper.autoAttackEnabled)
assert(widget('BaiakerosPartyHuntFloat').visible and widget('BaiakerosPartyHuntFloat').height==270)
assert(modules.game_baiakeros_helper.autoAttackEnabled and modules.game_baiakeros_helper.attackRotationEnabled)
for _,choices in ipairs({{auto=true,shooter=false},{auto=false,shooter=true},{auto=false,shooter=false},{auto=true,shooter=true}})do
 leaderOptions=choices;respond()
 assert(combat.autoAttackEnabled==choices.auto and combat.attackRotationEnabled==choices.shooter,
  'followers mirror Auto Attack and Shooter separately')
end
leaderPz=true;respond()
assert(not combat.autoAttackEnabled and not combat.attackRotationEnabled,'leader PZ suppresses follower combat even outside PZ')
leaderPz=false;respond();selfPz=true;PartyHuntV2.onProtectionZoneChange()
assert(not combat.autoAttackEnabled and not combat.attackRotationEnabled,'member stays disabled until it also leaves PZ')
selfPz=false;respond();assert(combat.autoAttackEnabled and combat.attackRotationEnabled)
combat.setAutoAttackEnabled(false)
assert(combat.autoAttackEnabled,'an active member cannot override the leader combat options')
clock=clock+1000;tick();assert(followerUpdates==1 and requests[#requests]=='heartbeat')
assert(not PartyHuntV2.prepareSpell({words='exevo tera hur'}))
-- Shared target is independent of both combat checkboxes and never falls back to another monster.
leaderOptions={auto=false,shooter=false};leaderTargetId=101;respond()
assert(actualTarget==targets[101] and not combat.autoAttackEnabled and not combat.attackRotationEnabled)
local targetPackets=attacks
for i=1,8 do clock=clock+50;tick()end
assert(attacks==targetPackets,'confirmed shared target does not send repeated attack packets')
leaderTargetId=102;clock=clock+150;respond();assert(actualTarget==targets[102],'members immediately change to the new leader target')
leaderTargetId=nil;respond();assert(actualTarget==nil,'leader cancellation clears the member target')
leaderTargetId=999;respond();assert(actualTarget==nil,'unseen target is not replaced by a local monster')
targets[999]={isMonster=function()return false end};respond()
assert(actualTarget==nil,'player and non-monster targets are never replicated')
targets[999]=nil
targets[101].getPosition=function()return {x=103,y=100,z=6}end
leaderTargetId=101;respond();assert(actualTarget==nil,'target on another floor is ignored')
targets[101].getPosition=function()return {x=103,y=100,z=7}end
leaderTargetId=101;targets[101].dead=true;respond();assert(actualTarget==nil,'dead targets are ignored')
targets[101].dead=false;clock=clock+150;respond();assert(actualTarget==targets[101])
leaderPz=true;respond();assert(actualTarget==nil,'shared targeting still respects leader PZ')
leaderPz=false;respond();bossLever=true;respond();assert(actualTarget==nil,'lever lineup suppresses shared targeting')
bossLever=false;respond()
widget('partyFloatStop').onClick();actualTarget=targets[102];respond()
assert(actualTarget==targets[102] and not PartyHuntV2.syncLeaderTarget(),'paused member retains manual targeting')
widget('partyFloatStop').onClick();clock=clock+150;respond();assert(actualTarget==targets[101])
ackAttack=false;actualTarget=nil;clock=clock+500;PartyHuntV2.syncLeaderTarget();targetPackets=attacks
for i=1,9 do clock=clock+50;PartyHuntV2.syncLeaderTarget()end
assert(attacks==targetPackets,'rejected/unconfirmed target retries are throttled')
clock=clock+50;PartyHuntV2.syncLeaderTarget();assert(attacks==targetPackets+1)
ackAttack=true;leaderTargetId=nil;respond();leaderOptions={auto=true,shooter=true};respond()
local beforeRecovery=resets
callbacks[93](nil,93,json.encode({action='status',remaining=3500,active=true,following=true,vocation=2,
 canConfigureMovement=true,settings=settings(),rescueSerial=1,run='1:1',leader={id=1,name='Leader'},members={}}))
assert(resets==beforeRecovery+1,'authoritative rescue clears stale navigation and formation')
respond()
follower=false;respond();assert(not PartyHuntV2.isFollowing() and resets>0)
assert(not widget('BaiakerosPartyHuntFloat').visible and not modules.game_baiakeros_helper.autoAttackEnabled)
selfVocation=1;beamMastery=true;respond()
assert(PartyHuntV2.hasBeamMastery(),'MS exposes the server-confirmed Wheel bonus to the Shooter')
clock=clock+8001
assert(not PartyHuntV2.hasBeamMastery(),'expired snapshots cannot leave a stale wide beam enabled')
respond();assert(PartyHuntV2.hasBeamMastery())
beamMastery=false;respond();assert(not PartyHuntV2.hasBeamMastery(),'Wheel removal updates immediately')
selfVocation=2;beamMastery=true;respond()
assert(not PartyHuntV2.hasBeamMastery(),'other vocations cannot enable Sorcerer Beam Mastery')
PartyHuntV2.terminate();assert(deletedKey,'hotkey binding is removed on module unload')
print('PASS: manual/shared targets independent of Auto Attack, bounded target packets, leader combat mirroring, PZ, pause/resume, lever controls and hotkey')
