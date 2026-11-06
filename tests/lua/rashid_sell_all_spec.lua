-- Run with LuaJIT from the client root. Exercise the real queue and goods counts.
Controller={new=function()return {}end}
GameDoubleShopSellAmount=1
local queue,now,counts,requests,status,finished,server,active
local function timer(fn,delay)
 local event={fn=fn,time=now+delay};queue[#queue+1]=event;return event
end
scheduleEvent=timer
removeEvent=function(event)event.cancelled=true end
modules={game_textmessage={displayStatusMessage=function(message)status=message end}}
local function item(id,tier)
 return {getId=function()return id end,getSubType=function()return 0 end,getTier=function()return tier or 0 end,getCount=function()return 1 end}
end
local function setup(legacy,double)
 queue={};now=0;counts={};requests={};status=nil;finished=nil;active=true
 g_game={isOnline=function()return true end,getFeature=function()return double end}
 g_game.sellItem=function(ptr,amount,ignore)
  requests[#requests+1]={id=ptr:getId(),amount=amount,ignore=ignore};server(ptr,amount,#requests)
 end
 dofile('modules/game_npctrade/game_npctrader.lua')
 local c=controllerNpcTrader
 c.rashidTrade=true;c.shopNpcName='Rashid';c.isTradeOpen=true;c.ui={isVisible=function()return active end}
 c.refreshPlayerGoods=function()end
 isTradingLegacy=function()return active end;refreshPlayerGoods=function()end
 return c
end
local function ack(id,amount,delay)
 timer(function()counts[id]=math.max(0,(counts[id] or 0)-amount);controllerNpcTrader.rashidGoodsVersion=controllerNpcTrader.rashidGoodsVersion+1 end,delay or 50)
end
local function start(c,ids,legacy)
 local entries={};for _,id in ipairs(ids)do entries[#entries+1]={ptr=item(id)}end
 return c:startRashidSellQueue(entries,legacy,function(ptr)return counts[ptr:getId()] or 0 end,function()return true end,function()end,
  function(ok,_,message)finished={ok=ok,message=message}end)
end
local function run(limit)
 local iterations=0
 while #queue>0 do
  table.sort(queue,function(a,b)return a.time<b.time end);local event=table.remove(queue,1);now=event.time
  if not event.cancelled then event.fn()end
  iterations=iterations+1;assert(iterations<(limit or 500),'queue failed to terminate')
 end
end
for _,legacy in ipairs({false,true})do
 local c=setup(legacy,false);counts[10]=100
 server=function(ptr,amount,n)ack(ptr:getId(),n==1 and 0 or amount)end
 assert(start(c,{10},legacy));run();assert(counts[10]==0 and #requests==2 and finished.ok,'rejected request must retry actual leftovers')
 c=setup(legacy,false);counts[10]=100
 server=function(ptr,amount)ack(ptr:getId(),math.min(amount,7),400)end
 assert(start(c,{10},legacy));run();assert(counts[10]==0 and #requests==15 and finished.ok,'partial confirmations must finish all 100 items')
 c=setup(legacy,false);counts[10]=250
 server=function(ptr,amount)ack(ptr:getId(),amount)end
 assert(start(c,{10},legacy));run();assert(#requests==3 and requests[1].amount==100 and requests[2].amount==100 and requests[3].amount==50 and finished.ok)
 c=setup(legacy,true);counts[10]=250
 server=function(ptr,amount)ack(ptr:getId(),amount)end
 assert(start(c,{10},legacy));run();assert(#requests==1 and requests[1].amount==250 and finished.ok)
 c=setup(legacy,false);counts[10]=100
 server=function(ptr)ack(ptr:getId(),0)end
 assert(start(c,{10},legacy));run();assert(#requests==3 and counts[10]==100 and not finished.ok and status:find('100 item',1,true),'no-progress must stop with truthful leftover status')
 c=setup(legacy,false);counts[10]=100
 server=function()end
 assert(start(c,{10},legacy));run();assert(#requests==3 and not finished.ok,'missing server confirmations must not loop forever')
 c=setup(legacy,false);counts[10]=100;counts[20]=20;c.rashidBlacklist[20]=true
 server=function(ptr,amount)ack(ptr:getId(),amount)end
 assert(start(c,{10,20},legacy));run();assert(counts[20]==20 and counts[10]==0 and #requests==1 and requests[1].ignore and finished.ok)
 c=setup(legacy,false);counts[10]=100
 server=function(ptr,amount)ack(ptr:getId(),amount,700);timer(function()active=false end,20)end
 assert(start(c,{10},legacy));run();assert(#requests==1 and not c.rashidSellActive,'closing trade cancels unsent work')
 c=setup(legacy,false);counts[10]=100
 server=function()timer(function()c:cancelRashidSellQueue('cancelled',true)end,20)end
 assert(start(c,{10},legacy));run();assert(#requests==1 and not c.rashidSellActive,'manual cancellation invalidates delayed callbacks')
end
-- The server excludes tiered equipment from its count, so it must not be subtracted twice.
local c=setup(false,false)
dofile('modules/game_npctrade/controllers/npc_trader.lua')
c.ignoreEquipped=true;c.playerItems={['10_0']=100};c.equippedImbuedCounts={}
g_game.getLocalPlayer=function()return {getInventoryItem=function(_,slot)return slot==1 and item(10,1) or nil end}end
assert(c:getSellQuantity(item(10))==100,'equipped Forge item is absent from server goods')
g_game.getLocalPlayer=function()return {getInventoryItem=function(_,slot)return slot==1 and item(10,0) or nil end}end
assert(c:getSellQuantity(item(10))==99,'ordinary equipped copies remain ignored')
c.equippedImbuedCounts[10]=1
assert(c:getSellQuantity(item(10))==100,'imbued equipment is not subtracted twice')
print('PASS: Rashid queue confirms actual removals, retries partial/rejected/missing acknowledgements, verifies leftovers, bounds retries, preserves blacklist/cancellation/equipped rules in modern and legacy flows')
