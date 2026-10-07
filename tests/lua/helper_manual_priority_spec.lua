-- Real manual dispatchers must reserve the Helper before sending/throttling.
tr=function(s)return s end
local now=1000
g_clock={millis=function()return now end}
g_settings={}
g_game={isOnline=function()return true end}
modules={}
dofile('modules/game_baiakeros_helper/helper.lua')
modules.game_baiakeros_helper={notifyManualAction=notifyManualAction}
local sent=0
g_game.talk=function()
 assert(isManualActionPending(),'manual spell packet must be preceded by its priority reservation')
 sent=sent+1
end
local panel={isFocusable=function()return false end}
modules.game_interface={getMainRightPanel=function()return panel end,getLeftPanel=function()return panel end}
modules.game_console={isChatEnabled=function()return false end,getConsole=function()return {setText=function()end}end,
 sendMessage=function(words)if words=='exura sio "friend' then g_game.talk() end end}
scheduleEvent=function()end
modules.client_options={getOption=function()return 500 end}
UseTypes={chatText=1,Use=2,UseOnYourself=3,UseOnTarget=4,SelectUseTarget=5,UseAtCursorPosition=6,Equip=7,specialAction=8}
spellGroupPressed={}
dofile('modules/game_actionbar/logics/ActionButtonLogic.lua')
local button={cache={lastClick=0,nextDownKey=0,actionType=1,isSpell=true,sendAutomatic=true,param='exevo vis hur',primaryGroup=1}}
onExecuteAction(button,false);assert(sent==1)
now=now+100;onExecuteAction(button,true);now=now+700
assert(isManualActionPending(),'throttled held keys still preserve priority')
now=now+50;assert(not isManualActionPending(),'automatic magic resumes after manual input ends')
panel.isFocusable=function()return true end
onExecuteAction(button,false);assert(not isManualActionPending(),'editing/focused panels do not reserve combat')
panel.isFocusable=function()return false end
button.cache.isSpell=false;button.cache.param='hello'
onExecuteAction(button,false);assert(not isManualActionPending(),'chat-only buttons do not suspend the Helper')
dofile('modules/game_hotkeys/hotkeys_manager.lua')
Spells={getSpellDataByParamWords=function(words)return words=='exura sio "friend' and {} or nil end}
hotkeyList={F1={value='exura sio "friend',autoSend=true},F2={value='hello',autoSend=false}}
now=now+1000;doKeyCombo('F1');assert(sent==2 and isManualActionPending())
now=now+100;doKeyCombo('F1');now=now+700
assert(isManualActionPending(),'legacy key repeats renew priority before the hotkey delay gate')
now=now+50;doKeyCombo('F2');assert(not isManualActionPending(),'editing a legacy text hotkey does not block spells')
local manualItems=0
g_game.getFeature=function()return true end
player={}
g_game.useInventoryItemWith=function()
 assert(isManualActionPending(),'manual item use must reserve priority before its packet')
 manualItems=manualItems+1
end
button.cache.actionType=UseTypes.UseOnYourself
button.item={getItemId=function()return 3160 end,getItemSubType=function()return -1 end}
now=now+1000;onExecuteAction(button,false);assert(manualItems==1)
now=now+750;assert(not isManualActionPending())
print('PASS: real Action Bar and legacy hotkeys prioritize manual spells before packets and throttles, without blocking chat/editing')
