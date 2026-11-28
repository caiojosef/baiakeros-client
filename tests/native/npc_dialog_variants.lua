-- Run only in a disposable --user-dir, never a personal profile.
pcall(function()g_window.hide()end)
local result={checks=0,cases={},errors={}}
local function check(ok,message)result.checks=result.checks+1;assert(ok,message)end
local function save()g_resources.writeFileContents('/result.json',json.encode(result))end
scheduleEvent(function()g_app.exit()end,35000)
scheduleEvent(function()
 local ok,err=xpcall(function()
  modules.client_entergame.EnterGame.hide();g_game.setProtocolVersion(1525);g_game.setClientVersion(1525)
  local c=modules.game_npctrade.controllerNpcTrader;c.legacyMode=false
  local balance=123456789012
  c.getPlayerMoney=function()return balance end;c.getSellQuantity=function()return 17 end
  local currentNpc
  g_map.getCreatureById=function(id)if currentNpc and id==987654 then return currentNpc end end
  local scenarios={
   {id='human-addons',name='Rashid',outfit={type=146,head=78,body=94,legs=79,feet=114,addons=3},shop=true},
   {id='gnome',name='Gnomission',outfit={type=493},shop=true},
   {id='large-npc',name='A Friendly Demon',outfit={type=35},shop=true},
   {id='token-shop',name='Boss Token Trader',outfit={type=146,head=78,body=94,legs=79,feet=114,addons=3},shop=true,currency=22723},
   {id='two-keyword-rows',name='A Quest NPC',outfit={type=130},buttons=28},
   {id='three-keyword-rows',name='Another Quest NPC',outfit={type=138},buttons=42},
   {id='scrolling-keywords',name='Quest Options',outfit={type=128},buttons=43},
   {id='long-npc-name',name='WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW',outfit={type=130},buttons=7},
  }
  local function widget(selector)return assert(c:findWidget(selector),'missing '..selector)end
  local function within(a,b)
   local x,y=a:getRect(),b:getRect()
   check(x.width>0 and x.height>0,'empty widget')
   check(x.x>=y.x and x.y>=y.y and x.x+x.width<=y.x+y.width+1 and x.y+x.height<=y.y+y.height+1,'widget outside parent '..json.encode(x)..' '..json.encode(y))
  end
  local function separate(a,b)
   local x,y=a:getRect(),b:getRect()
   check(x.x+x.width<=y.x or y.x+y.width<=x.x or x.y+x.height<=y.y or y.y+y.height<=x.y,'overlapping controls')
  end
  local function fits(w)check(w:getTextSize().width<=w:getWidth() and w:getTextSize().height<=w:getHeight(),'clipped text '..w:getText())end
  local index=0
  local function nextScenario()
   index=index+1
   local spec=scenarios[index]
   if not spec then
    result.passed=#result.errors==0;save();scheduleEvent(function()g_app.exit()end,200);return
   end
   local setupOk,setupError=xpcall(function()
    c:onCloseNpcTrade()
    currentNpc={isNpc=function()return true end,getId=function()return 987654 end,getName=function()return spec.name end,getOutfit=function()return spec.outfit end}
    local buttons={}
    for i=1,spec.buttons or 0 do buttons[i]={id=0,text='Option '..i}end
    c:initNpcWindow(currentNpc,buttons)
    if spec.shop then
     c:onOpenNpcTrade({{Item.create(3280),'a remarkably long and elaborate piece of equipment',1234567,123456789,123456789},
      {Item.create(3366),'magic plate armor',8500,100,100}},spec.currency or 3031,spec.currency and 'boss token'or'Gold Coin',spec.name)
     c.ignoreCapacity=true
     if spec.name=='Rashid'then c:setTradeMode(c.SELL)end
    end
   end,debug.traceback)
   if not setupOk then result.errors[#result.errors+1]=spec.id..': '..tostring(setupError);save();nextScenario();return end
   scheduleEvent(function()
    local passed,message=xpcall(function()
     check(c.ui:getWidth()==(spec.shop and 720 or 395),'wrong window width')
     check(c.ui:getHeight()==480,'wrong window height')
     check(c.ui:getRect().x>0 and c.ui:getRect().y>0,'window not settled')
     within(widget('#npcPortraitViewport'),widget('.podium'));within(widget('.podium'),widget('.leftPanel'))
     within(widget('#npcName'),widget('#npcBanner'));fits(widget('#npcName'))
     check(widget('#npcName'):getTooltip()==spec.name,'full NPC name missing from tooltip')
     separate(widget('#npcPortraitViewport'),widget('#npcName'))
     separate(widget('.podium'),widget('#consoleBuffer'))
     local portrait=widget('#creatureOutfit')
     check(portrait:getCreature():getOutfit().type==spec.outfit.type,'wrong NPC picture')
     check(portrait:getCreatureSize()>=54 and portrait:getCreatureSize()<=108 and portrait:isCentered(),'portrait not compact/centered')
     local console,buttons,input=widget('#consoleBuffer'),widget('#panelBotons'),widget('#chatInput')
     within(console,widget('.leftPanel'));within(buttons,widget('.leftPanel'));within(input,widget('.leftPanel'))
     check(console:getY()+console:getHeight()+6<=buttons:getY(),'conversation has no gap before keyword buttons')
     separate(buttons,input);fits(widget('#chatModeButton'))
     check(input:getY()==widget('#chatModeButton'):getY(),'chat baseline differs')
     if spec.buttons then
      local found={}
      for _,child in ipairs(buttons:getChildren())do
       if child:getTooltip():find('Option ',1,true)then found[#found+1]=child end
      end
      check(#found==spec.buttons,'keyword options were lost')
      check(buttons:getHeight()==math.min(84,math.ceil(spec.buttons/14)*28),'keyword rows have wrong height')
      for i=1,(#found<=42 and #found or 13)do within(found[i],buttons);check(found[i]:getHeight()==24,'keyword button height changed')end
      result.keywordGeometry=result.keywordGeometry or{}
      result.keywordGeometry[spec.id]={count=#found,height=buttons:getHeight(),last=found[#found]:getRect(),viewport=buttons:getRect()}
      if #found>42 then
       result.scrollDetails={class=buttons:getClassName(),hasBar=buttons.verticalScrollBar~=nil,children=buttons:getChildrenRect(),padding=buttons:getPaddingRect(),maximum=buttons.verticalScrollBar and buttons.verticalScrollBar:getMaximum()}
       check(buttons:isClipping(),'keyword overflow is not clipped')
       check(buttons.verticalScrollBar and buttons.verticalScrollBar:getMaximum()>0,'overflow has no working scrollbar')
       buttons.verticalScrollBar:setValue(buttons.verticalScrollBar:getMaximum())
      end
     end
     if spec.shop then
      within(widget('.rightPanel'),c.ui);within(widget('.tradeFooter'),widget('.rightPanel'))
      within(widget('#tradeListScroll'),widget('.rightPanel'))
      separate(widget('.tradeHeader'),widget('#tradeListScroll'));separate(widget('#tradeListScroll'),widget('.tradeSearchRow'))
      separate(widget('.tradeSearchRow'),widget('.tradeFooter'))
      check(widget('#toggleButton'):getY()==input:getY(),'left and right action baselines differ')
      fits(widget('#tabBuy'));fits(widget('#tabSell'));fits(widget('#toggleButton'))
      check(widget('#playerMoneyDisplay'):getText()=='123,456,789,012','balance is not grouped/readable');fits(widget('#playerMoneyDisplay'))
      if spec.currency then
       check(widget('.tradeCurrencyIcon'):getItem():getId()==22723,'token currency icon changed')
       check(widget('.tradeCurrencyName'):getText()=='boss token','token currency label changed')
      end
      for _,row in ipairs(widget('#tradeListScroll'):getChildren())do
       local name=row:recursiveGetChildById('nameLabel');local info=row:recursiveGetChildById('infoLabel')
       if name and info then fits(name);fits(info);separate(name,info);check(#name:getTooltip()>#name:getText(),'item tooltip missing full details')end
      end
      if spec.name=='Rashid'then
       within(widget('#tabBlacklist'),widget('.tradeHeader'));separate(widget('#tabBuy'),widget('#tabSell'));separate(widget('#tabSell'),widget('#tabBlacklist'))
       c:updateRashidSellProgressModern(8,20,'Selling 8 / 20',true)
       within(widget('#rashidCancelSellButton'),widget('.tradeFooter'));separate(widget('#rashidCancelSellButton'),widget('#toggleButton'))
       separate(widget('#rashidSellAllButton'),widget('#rashidCancelSellButton'))
       fits(widget('#rashidSellProgressLabel'));c:resetRashidSellAllModern()
      end
     end
     g_app.doScreenshot('/'..spec.id..'.png')
    end,debug.traceback)
    result.cases[#result.cases+1]={name=spec.id,passed=passed,error=not passed and tostring(message)or nil}
    if not passed then result.errors[#result.errors+1]=spec.id..': '..tostring(message)end
    save();scheduleEvent(function()
     if passed and spec.buttons and spec.buttons>42 then
      local scrollOk,scrollError=xpcall(function()
       local buttons=widget('#panelBotons')
       local last
       for _,child in ipairs(buttons:getChildren())do if child:getTooltip()=='Option '..spec.buttons then last=child end end
       check(last~=nil,'last keyword missing');within(last,buttons)
       separate(buttons,widget('#chatInput'))
       g_app.doScreenshot('/scrolling-keywords-bottom.png')
      end,debug.traceback)
      if not scrollOk then result.cases[#result.cases].passed=false;result.errors[#result.errors+1]=spec.id..': '..tostring(scrollError);save()end
     end
     nextScenario()
    end,200)
   end,250)
  end
  nextScenario()
 end,debug.traceback)
 if not ok then result.errors[#result.errors+1]=tostring(err);result.passed=false;save();g_app.exit()end
end,5000)
