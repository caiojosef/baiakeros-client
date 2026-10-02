dofile('modules/corelib/json.lua')
local widgets, callbacks, requests = {}, {}, {}
local clock, tick, active = 1000, nil, false
local selfId=1
local personalSettings={}
local selfVocation=2
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
    setAutoAttackEnabled=function(enabled)modules.game_baiakeros_helper.autoAttackEnabled=enabled end,
    setAttackRotationEnabled=function(enabled)modules.game_baiakeros_helper.attackRotationEnabled=enabled end},
 game_baiakeros_helper_v2={showHelperV2Tab=function(tab)assert(tab=='party')end,show=function()helperV2Window:show()end}}
ProtocolGame={registerExtendedOpcode=function(opcode,callback)callbacks[opcode]=callback end,unregisterExtendedOpcode=function(opcode)callbacks[opcode]=nil end}
local function respond()
 callbacks[93](nil,93,json.encode({action='status',remaining=10800,limitSeconds=10800,active=active and selfId==1 or follower,following=follower,canControl=selfId==1 and not tooMany,
  canTeleport=selfId==1 and not tooMany and allPz and serverCooldown==0,tooMany=tooMany,teleportRemaining=serverCooldown,allProtectionZone=allPz,
  settings=settings(),canConfigureMovement=selfVocation~=4,run='1:1',vocation=selfVocation,reason='',leader={id=1,name='Leader'},members={{id=1,name='Leader',leader=true},{id=2,name='Member'}}}))
end
g_game={isOnline=function()return true end,getLocalPlayer=function()return {getId=function()return selfId end}end,
 getProtocolGame=function()return {sendExtendedOpcode=function(_,opcode,buffer)
  local req=json.decode(buffer);requests[#requests+1]=req.action
  if req.action=='options' and selfVocation~=4 then personalSettings[selfId]={runThreshold=req.runThreshold,alwaysRun=req.alwaysRun}end
  if req.action=='start' then active=true elseif req.action=='stop' then active=false elseif req.action=='teleport' then serverCooldown=600 end
  if not silent then respond() end
 end}end,
 walk=function()error('automatic movement is not enabled yet')end,
 setChaseMode=function()error('Party Hunt must not change attack chase mode')end}
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
assert(widget('partyStart').enabled and widget('partyTeleport').enabled)
assert(widget('partyRunThreshold').enabled and widget('partyRunThreshold').option.data==2)
widget('partyRunThreshold'):setCurrentOptionByData(6);widget('partyRunThreshold').onOptionChange()
assert(settings().runThreshold==6)
widget('partyAlwaysRun'):setChecked(true);widget('partyAlwaysRun').onCheckChange()
assert(settings().alwaysRun and widget('partyAlwaysRun').checked)
assert(widgets.partyGuide==nil and widgets.partyFollowDistance==nil and widgets.partyJsonEditor==nil)
widget('partyStart').onClick();assert(PartyHuntV2.isActive())
assert(modules.game_baiakeros_helper.autoAttackEnabled and modules.game_baiakeros_helper.attackRotationEnabled)
assert(widget('BaiakerosPartyHuntFloat').visible and widget('BaiakerosPartyHuntFloat').height==270)
assert(widget('partyFloatRoster').text:find('Leader') and widget('partyFloatRoster').text:find('Member'))
clock=clock+1000;tick();assert(requests[#requests]=='heartbeat')
assert(PartyHuntV2.prepareSpell({words='test'})==true)
widget('partyTeleport').onClick();assert(serverCooldown==600 and not widget('partyTeleport').enabled)
assert(widget('partyTeleport').text:find('10:00'))
clock=clock+1000;tick();assert(not widget('partyTeleport').enabled)
PartyHuntV2.minimize();assert(widget('BaiakerosPartyHuntFloat').height==270)
PartyHuntV2.openHelper();assert(not widget('BaiakerosPartyHuntFloat').visible)
widget('partyStart').onClick();assert(not PartyHuntV2.isActive())
assert(not modules.game_baiakeros_helper.autoAttackEnabled and not modules.game_baiakeros_helper.attackRotationEnabled)
selfId=2;respond();assert(not widget('partyStart').enabled and not widget('partyTeleport').enabled)
local count=#requests;widget('partyStart').onClick();widget('partyTeleport').onClick()
assert(#requests==count and widget('partyRunThreshold').enabled and widget('partyAlwaysRun').enabled,
 'member can configure only personal movement, not Start or teleport')
assert(settings().runThreshold==2 and not settings().alwaysRun,'member does not inherit leader preferences')
widget('partyRunThreshold'):setCurrentOptionByData(1);widget('partyRunThreshold').onOptionChange()
widget('partyAlwaysRun'):setChecked(true);widget('partyAlwaysRun').onCheckChange()
assert(settings().runThreshold==1 and settings().alwaysRun and personalSettings[1].runThreshold==6,
 'editing one character must not change another character')
selfVocation=4;respond()
assert(not widget('partyRunThreshold').visible and not widget('partyAlwaysRun').visible and widget('partyKnightNotice').visible)
count=#requests;widget('partyRunThreshold').onOptionChange();widget('partyAlwaysRun').onCheckChange()
assert(#requests==count,'Knight cannot send movement options even by invoking hidden controls')
selfId=1;respond();assert(widget('partyStart').enabled and not widget('partyAlwaysRun').visible,'Knight leader keeps Start controls')
selfVocation=2;respond();assert(widget('partyRunThreshold').visible and not widget('partyKnightNotice').visible)
selfId=1;tooMany=true;respond();assert(not widget('partyStart').enabled and widget('partyWarning').text:find('4 pessoas'))
tooMany=false;allPz=false;serverCooldown=0;respond();assert(not widget('partyTeleport').enabled)
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
selfId=2;follower=true;respond()
assert(PartyHuntV2.isFollowing() and not widget('partyStart').enabled)
assert(widget('BaiakerosPartyHuntFloat').visible and widget('BaiakerosPartyHuntFloat').height==270)
assert(modules.game_baiakeros_helper.autoAttackEnabled and modules.game_baiakeros_helper.attackRotationEnabled)
clock=clock+1000;tick();assert(followerUpdates==1 and requests[#requests]=='heartbeat')
assert(not PartyHuntV2.prepareSpell({words='exevo tera hur'}))
local beforeRecovery=resets
callbacks[93](nil,93,json.encode({action='status',remaining=3500,active=true,following=true,vocation=2,
 canConfigureMovement=true,settings=settings(),rescueSerial=1,run='1:1',leader={id=1,name='Leader'},members={}}))
assert(resets==beforeRecovery+1,'authoritative rescue clears stale navigation and formation')
respond()
follower=false;respond();assert(not PartyHuntV2.isFollowing() and resets>0)
assert(not widget('BaiakerosPartyHuntFloat').visible and not modules.game_baiakeros_helper.autoAttackEnabled)
PartyHuntV2.terminate()
print('PASS: independent party activation, automatic helpers/minimized roster for leader and members, restoration on Stop, heartbeat, Shooter hook, four-player warning and teleport')
