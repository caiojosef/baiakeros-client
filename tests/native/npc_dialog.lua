-- Run only in a disposable --user-dir, never a personal profile.
pcall(function()g_window.hide()end)
local report={cases={},rects={}}
local function case(name,fn)local ok,err=xpcall(fn,debug.traceback);report.cases[#report.cases+1]={name=name,passed=ok,error=not ok and tostring(err)or nil}end
local function save()g_resources.writeFileContents('/result.json',json.encode(report))end
scheduleEvent(function()g_app.exit()end,30000)
scheduleEvent(function()
 local ok,err=xpcall(function()
  modules.client_entergame.EnterGame.hide();g_game.setProtocolVersion(1525);g_game.setClientVersion(1525)
  local c=modules.game_npctrade.controllerNpcTrader
  c.legacyMode=false;c.playerMoney=19187881
  c.getSellQuantity=function()return 92 end


  local activeNpc = 'Rashid'
  local outfits = {Rashid={type=146,head=0,body=101,legs=122,feet=115},Galuna={type=138,head=78,body=69,legs=58,feet=76},
    Xodet={type=130,head=95,body=94,legs=95,feet=93},Gnomission={type=493}}
  c.getPlayerMoney=function()return 19187881 end
  local resolve=c.resolveNpcCreature
  c.resolveNpcCreature=function(self,name,creature,position)return resolve(self,name,creature,position or {x=100,y=100,z=7})end
  local creatures = {}
  local function npc(name,id)
   return {getName=function()return name end,getId=function()return id end,isNpc=function()return true end,
    getOutfit=function()return outfits[name]or outfits.Xodet end}
  end
  for i,name in ipairs({'Rashid','Galuna','Xodet','Gnomission'})do creatures[name]=npc(name,500+i)end
  g_map.getSpectators=function()return {creatures.Galuna,creatures.Xodet,creatures.Rashid,creatures.Gnomission}end
  g_map.getCreatureById=function(id)for _,n in pairs(creatures)do if n:getId()==id then return n end end end
  c:initNpcWindow()

  c:onOpenNpcTrade({{Item.create(3031),'gold coin',100,1,1},{Item.create(3035),'platinum coin',100,100,100},{Item.create(3039),'red gem',200,1000,5000}},3031,'Gold Coin','Rashid')
  c:setTradeMode(c.SELL)
  local function widget(s)if s=='#windowTrader'then return c.ui end return assert(c:findWidget(s),'missing '..s)end
  local function rect(s)local r=widget(s):getRect();report.rects[s]=r;return r end
  local function within(s,parent)
   local a,b=rect(s),rect(parent);assert(a.width>0 and a.height>0,'empty '..s)
   assert(a.x>=b.x and a.y>=b.y and a.x+a.width<=b.x+b.width+1 and a.y+a.height<=b.y+b.height+1,'outside parent '..s..' '..json.encode(a)..' '..json.encode(b))
  end
  local function separate(a,b)
   local x,y=rect(a),rect(b)
   assert(x.x+x.width<=y.x or y.x+y.width<=x.x or x.y+x.height<=y.y or y.y+y.height<=x.y,'overlap '..a..' '..b)
  end
  local function textFits(s)
   local w=widget(s);local r,t=w:getSize(),w:getTextSize()
   assert(r.width>=t.width and r.height>=t.height,'text clipped '..s..' '..json.encode(r)..' '..json.encode(t))
  end
  local function click(s)local w=widget(s);signalcall(w.onClick,w)end
  scheduleEvent(function()
   local good,msg=xpcall(function()
    case('window reserves the complete trading panel',function()
     rect('#windowTrader')
     assert(c.ui:getWidth()==720 and c.ui:getHeight()==480,'window size');within('.rightPanel','#windowTrader');within('.tradeFooter','.rightPanel');within('#tradeListScroll','.rightPanel')
    end)
    case('all three tabs fit with complete captions',function()
     for _,s in ipairs({'#tabBuy','#tabSell','#tabBlacklist'})do within(s,'.tradeHeader');textFits(s)end
     separate('#tabBuy','#tabSell');separate('#tabSell','#tabBlacklist');separate('.tradeHeader','#tradeListScroll')
    end)
    case('search and item list have separate clickable areas',function()
     within('.tradeSearchInput','.tradeSearchRow');within('.tradeSearchClear','.tradeSearchRow');separate('.tradeSearchInput','.tradeSearchClear');separate('#tradeListScroll','.tradeSearchRow');separate('.tradeSearchRow','.tradeFooter')
    end)
    case('amount price and gold fit above action buttons',function()
     for _,s in ipairs({'#amountScrollBar','#amountInput','#playerMoneyDisplay','#toggleButton','#rashidSellAllButton'})do within(s,'.tradeFooter')end
     textFits('#playerMoneyDisplay');textFits('#toggleButton');textFits('#rashidSellAllButton')
     separate('.tradeRows','#toggleButton');separate('.tradeRows','#rashidSellAllButton');separate('.tradeRows','.tradePreviewBox');separate('#amountScrollBar','.tradeRows')
    end)
    case('progress cancellation and sell buttons never overlap',function()
     c:updateRashidSellProgressModern(1,3,'Selling 1 / 3',true)
     within('#rashidCancelSellButton','.tradeFooter');textFits('#rashidCancelSellButton')
     separate('#rashidCancelSellButton','#toggleButton');separate('#rashidCancelSellButton','#rashidSellAllButton');separate('#rashidSellProgress','.tradeRows');separate('#rashidSellProgress','#amountScrollBar')
     c:resetRashidSellAllModern()
    end)

    case('shop-only packet resolves both header and real NPC outfit',function()
     assert(c.creatureName=='Rashid' and c.npcCreatureId==creatures.Rashid:getId())
     assert(widget('#npcName'):getText()=='Rashid')
     assert(widget('#creatureOutfit'):isVisible() and widget('#creatureOutfit'):getCreature():getOutfit().type==146)
     assert(widget('#creatureOutfit'):getImageSource()=='')
     assert(not widget('#npcPortraitFallback'):isVisible())
     local header=widget('#consoleBuffer'):getChildByIndex(1)
     assert(header:getText():find('talking to Rashid',1,true) and not header:getText():find('Unknown',1,true))
    end)
    case('portrait and name fit above the transcript',function()
     for _,s in ipairs({'#npcName','#npcPortraitViewport','.podium'})do within(s,'.leftPanel');separate(s,'#consoleBuffer')end
     separate('#npcName','#npcPortraitViewport');textFits('#npcName')
     within('#npcName','#npcBanner');within('#npcPortraitViewport','.podium');within('#npcPortraitViewport','.leftPanel')
    end)
    case('all commands have normal readable centered text',function()
     for _,s in ipairs({'#tabBuy','#tabSell','#tabBlacklist','#toggleButton','#rashidSellAllButton','#rashidCancelSellButton'})do
      local w=widget(s);assert(w:getFont()=='verdana-11px-monochrome',s..' font '..w:getFont());assert(w:getTextAlign()==AlignCenter,s..' alignment');textFits(s)
     end
    end)
    case('currency labels and icon have separate areas',function()
     within('.tradeCurrencyName','.tradeHeader');separate('.currencySection','.tradeCurrencyIcon');textFits('.tradeCurrencyName')
     separate('#currencyCaption','.tradeCurrencyName')
    end)
    case('chat field and button fit with separate click areas',function()
     within('#chatInput','.leftPanel');within('#chatModeButton','.leftPanel');textFits('#chatModeButton');separate('#chatInput','#chatModeButton')
     assert(widget('#chatInput'):getY()==widget('#chatModeButton'):getY(),'chat controls share baseline')
     assert(widget('#chatModeButton'):getText()=='Chat Off' or widget('#chatModeButton'):getText()=='Chat On')
     within('#panelBotons','.leftPanel');separate('#panelBotons','#consoleBuffer');separate('#panelBotons','#chatInput')
    end)
    case('item rows keep their names prices and clickable bounds',function()
     local list=widget('#tradeListScroll')
     report.itemRows={children=list:getChildCount(),model=#c.tradeItems}
     assert(list:getChildCount()>0,'trade list has no rendered rows')
     local row=list:getChildByIndex(1)
     local name=row:recursiveGetChildById('nameLabel');local info=row:recursiveGetChildById('infoLabel')
     assert(name and info,'item text widgets missing')
     assert(name:getTextSize().width<=name:getWidth() and info:getTextSize().width<=info:getWidth(),'item text clipped')
     assert(name:getY()+name:getHeight()<=info:getY(),'name and price overlap')
    end)

    case('tabs retain their original trade actions',function()
     click('#tabBuy');assert(c.tradeMode==c.BUY)
     click('#tabBlacklist');assert(c.tradeMode==c.BLACKLIST)
     click('#tabSell');assert(c.tradeMode==c.SELL)
    end)
    case('sell sell-all and cancel keep separate callbacks',function()
     local calls={};c.executeTrade=function()calls.sell=true end;c.startRashidSellAllModern=function()calls.all=true end;c.cancelRashidSellAllModern=function()calls.cancel=true end
     click('#toggleButton');click('#rashidSellAllButton');c:updateRashidSellProgressModern(1,3,'Selling 1 / 3',true);click('#rashidCancelSellButton')
     assert(calls.sell and calls.all and calls.cancel)
    end)

    case('all NPCs use their own identity on repeated window opening',function()
     for _,name in ipairs({'Galuna','Xodet','Gnomission','Rashid'})do
      c:onCloseNpcTrade()
      c:onOpenNpcTrade({{Item.create(3031),'gold coin',100,1,1}},3031,'Gold Coin',name)
      assert(c.creatureName==name and widget('#npcName'):getText()==name,name..' header')
      assert(widget('#creatureOutfit'):getCreature():getOutfit().type==outfits[name].type,name..' outfit')
      assert(widget('#consoleBuffer'):getChildByIndex(1):getText():find('talking to '..name,1,true),name..' conversation header')
     end
    end)

    case('portrait is compact and safely clipped to its frame',function()
     local portrait=widget('#creatureOutfit')
     assert(portrait:getCreatureSize()>=54 and portrait:getCreatureSize()<=108 and portrait:isCentered(),'sprite not compact/centered')
     assert(widget('#npcPortraitViewport'):getWidth()==64 and widget('.podium'):getWidth()==72)
     within('#npcPortraitViewport','.podium')
    end)
    case('left and right bottom controls share the same baseline',function()
     assert(widget('#chatModeButton'):getY()==widget('#toggleButton'):getY(),'action baseline differs')
     assert(widget('#chatInput'):getY()==widget('#toggleButton'):getY(),'input baseline differs')
    end)
    case('item tooltips preserve full names prices and weights',function()
     c:onOpenNpcTrade({{Item.create(3280),'a remarkably long and elaborate equipment name',5678,123456789,123456789}},3031,'Gold Coin','Rashid')
     local item=c.buyItems[1]
     local text=c:getTradeItemTooltip(item)
     assert(text:find(item.name,1,true) and text:find('123,456,789',1,true) and text:find('56.78',1,true))
    end)
    case('long NPC name is bounded and preserves full tooltip',function()
     local name='An Incredibly Long Named Travelling Equipment Merchant'
     c:updateNpcIdentity(name,npc(name,900))
     local label=widget('#npcName');within('#npcName','.leftPanel');textFits('#npcName')
     assert(label:getTooltip()==name and label:getText()~=name)
    end)
    case('talk-only NPC packet displays its real portrait',function()
     c:onCloseNpcTrade();c:initNpcWindow(creatures.Gnomission)
     assert(not c.isTradeOpen and c.creatureName=='Gnomission')
     assert(widget('#creatureOutfit'):getCreature():getOutfit().type==493)
    end)
    case('unresolved NPC never borrows another NPC portrait',function()
     c:updateNpcIdentity('Unloaded NPC')
     assert(c.creatureName=='Unloaded NPC' and c.outfit==nil and c.npcCreatureId==nil)
     assert(not widget('#creatureOutfit'):isVisible() and widget('#npcPortraitFallback'):isVisible())
    end)
    c:onCloseNpcTrade();c:onOpenNpcTrade({{Item.create(3031),'gold coin',100,1,1},{Item.create(3035),'platinum coin',100,100,100}},3031,'Gold Coin','Galuna')
    c.ui:show()
    report.portraitOutfit=widget('#creatureOutfit'):getCreature():getOutfit()
    scheduleEvent(function()
     report.finalRects={}
     for _,s in ipairs({'#npcBanner','#npcName','#creatureOutfit','.podium','.currencySection','#currencyCaption','.tradeCurrencyName','#chatInput','#chatModeButton','.leftPanel','.rightPanel'})do
      local w=widget(s);report.finalRects[s]={rect=w:getRect(),marginTop=w:getMarginTop(),marginBottom=w:getMarginBottom(),height=w:getHeight(),text=w:getText()}
     end
     save();g_app.doScreenshot('/npc-dialog-preview.png')
    end,600)
   end,debug.traceback)
   if not good then report.setupError=tostring(msg)end
   save();scheduleEvent(function()g_app.exit()end,1000)
  end,600)
 end,debug.traceback)
 if not ok then report.setupError=tostring(err);save();g_app.exit()end
end,5000)
