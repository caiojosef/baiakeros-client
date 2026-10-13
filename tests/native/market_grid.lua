-- Isolated native UI QA: mock protocol only, no network login or checkout.
scheduleEvent(function()
    local module=modules.game_baiakeros_market
    local oldOnline,oldProtocol,oldPlayer,oldBox=g_game.isOnline,g_game.getProtocolGame,g_game.getLocalPlayer,displayGeneralBox
    local sent,modal,buttons={},nil,nil
    local protocol={sendExtendedOpcode=function(_,_,payload) sent[#sent+1]=json.decode(payload) end}
    local function fromMarket()
        local info=debug.getinfo(3,'S')
        return info and info.source:find('/game_baiakeros_market/',1,true)~=nil
    end
    g_game.isOnline=function() return fromMarket() or oldOnline() end
    g_game.getProtocolGame=function() return protocol end
    g_game.getLocalPlayer=function()
        if fromMarket() then return {getName=function() return 'Market Grid QA' end} end
        return oldPlayer()
    end
    displayGeneralBox=function(title,text,actions,...)
        buttons=actions;modal=oldBox(title,text,actions,...);return modal
    end
    local key='baiakeros-market-'..g_crypt.sha256(tostring(G.host or '')..'\nMarket Grid QA')
    g_settings.set(key..'-signed-out',false)
    modules.client_entergame.EnterGame.hide()
    for _,window in ipairs(rootWidget:getChildren()) do window:unlock() end
    local function restore()
        module.hide()
        g_game.isOnline,g_game.getProtocolGame,g_game.getLocalPlayer,displayGeneralBox=oldOnline,oldProtocol,oldPlayer,oldBox
    end
    local function run(fn)
        local ok,err=pcall(fn)
        if not ok then restore();g_logger.error('[MarketGridQA] FAIL: '..tostring(err));g_app.exit() end
        return ok
    end
    local panel,cards
    local function child(parent,id) return parent:recursiveGetChildById(id) end
    local offers={}
    if not run(function()
        module.toggle()
        ProtocolGame.onExtendedOpcode(protocol,224,json.encode({action='status',available=true,status='connected',environment='test'}))
        panel=rootWidget:recursiveGetChildById('baiakerosMarketWindow')
        assert(sent[#sent].action=='browse','connected status immediately requests items')
        assert(child(panel,'loadingLabel'):isVisible() and child(panel,'loadingTrack'):isVisible(),'loading indicator precedes first response')
        g_game.setClientVersion(1511)
        local ids={16110,3043,3051,3035,3031,16110}
        for i,id in ipairs(ids) do
            offers[i]={id=i,item_id=id,item_count=i==2 and 100 or 1,item_name=({'prismatic armor','crystal coin','energy ring','platinum coin','gold coin','Anúncio expirado'})[i],
                seller_name='NOME_DO_VENDEDOR_NAO_DEVE_APARECER',price_cents=1500+i*100,state='active',own=i==3,
                category=({'armor','currency','rings','currency','currency','armor'})[i],
                expires_at=os.date('!%Y-%m-%d %H:%M:%S',os.time()+(i==6 and -1 or 7200+i*60))}
        end
        ProtocolGame.onExtendedOpcode(protocol,224,json.encode({action='offers',offersJson=json.encode(offers),categoriesJson=json.encode({armor=1,currency=3,rings=1})}))
        cards=child(panel,'offersList'):getChildren()
        assert(#cards==6,'six cards rendered')
        assert(not child(cards[3],'buy'):isEnabled(),'own item cannot be bought')
        assert(not child(cards[6],'buy'):isEnabled(),'expired item cannot be bought')
        assert(child(cards[1],'expiry'):getText():find('Restam 02:'),'UTC countdown shown in local time zone')
        for _,card in ipairs(cards) do assert(not child(card,'details'):getText():find('NOME_DO_VENDEDOR'),'seller name hidden') end
        local helper=rootWidget:recursiveGetChildById('baiakerosHelperButton')
        local adventures=rootWidget:recursiveGetChildById('progressButton')
        assert(helper and helper:getText()=='' and adventures and adventures:getText()=='','shortcuts are icon-only')
        assert(helper:getWidth()==51 and adventures:getWidth()==51 and adventures:getMarginLeft()==53,'equal-width shortcut row')
        assert(helper:getHeight()==20 and child(helper,'highlight'):getWidth()==51 and child(helper,'brightButton'):getHeight()==20,'original effects fit compact shortcut')
        local marketShortcut=rootWidget:recursiveGetChildById('baiakerosMarketButton')
        assert(marketShortcut and marketShortcut:getWidth()==51 and marketShortcut:getHeight()==20 and marketShortcut:getText()=='','market shortcut matches compact icon-only row')
        assert(marketShortcut:getParent()==helper:getParent() and marketShortcut:getMarginLeft()==106,'market is third shortcut in same row')
        assert(not rootWidget:recursiveGetChildById('maininventorypanel'):recursiveGetChildById('marketButton'),'old inventory shortcut removed')
        modules.game_interface.setupOptionsMainButton()
        modules.client_options.setupOptionsMainButton()
        local category=child(panel,'categoryFilter')
        assert(category:isOption('Armor') and category:isOption('Rings') and not category:isOption('Boots'),'only populated categories shown')
        child(panel,'searchName'):setText('CRYSTAL')
        assert(#child(panel,'offersList'):getChildren()==1,'name search ignores case')
        category:setCurrentOptionByData('armor')
        assert(#child(panel,'offersList'):getChildren()==0 and child(panel,'emptyTitle'):getText()=='Nenhum item encontrado','name and category combine')
        child(panel,'searchName'):setText('')
        assert(#child(panel,'offersList'):getChildren()==2,'clearing search retains category')
        category:setCurrentOptionByData('all')
        cards=child(panel,'offersList'):getChildren()
        assert(#cards==6,'all categories restores cards')
        assert(not child(panel,'loadingLabel'):isVisible(),'response clears loading indicator')
        assert(#child(panel,'categoryFilter'):getChildren()==1 and child(panel,'categoryFilter'):getChildById('dropdownArrow'),'single category arrow')
        local duration=child(child(panel,'draft1'),'duration')
        assert(duration:getChildById('dropdownArrow') and #duration:getChildren()==1,'single duration arrow')
        child(panel,'commissionInfo'):onClick()
        local info=rootWidget:getChildById('baiakerosMarketSaleInfo')
        assert(info and info:isVisible() and child(info,'understood'):getText()=='Entendi','sale information opens dismissible modal')
        assert(child(info,'paymentInfo'):getText():find('15%%') and child(info,'reservationInfo'):getText():find('retirado') and not child(info,'paymentInfo'):getText():find('1,50'),'sale rules disclosed without money example')
        child(info,'understood'):onClick()
        category:onMousePress({x=category:getX(),y=category:getY()},MouseLeftButton)
        local menu=rootWidget:getChildById('categoryFilterPopupMenu')
        assert(menu and menu:isVisible() and #menu:getChildren()==4,'custom category dropdown opens its options')
        menu:destroy()
        duration:onMousePress({x=duration:getX(),y=duration:getY()},MouseLeftButton)
        menu=rootWidget:getChildById('durationPopupMenu')
        assert(menu and #menu:getChildren()==3,'custom duration dropdown opens all durations')
        menu:destroy()
    end) then return end
    scheduleEvent(function()
        if not run(function()
            assert(cards[1]:getY()==cards[4]:getY() and cards[5]:getY()>cards[1]:getY(),'four-column compact grid wraps')
            assert(cards[1]:getWidth()==180 and cards[1]:getHeight()==184,'compact offer card dimensions')
            modules.client_entergame.EnterGame.hide()
            local mainPanel=rootWidget:recursiveGetChildById('mainoptionspanel')
            mainPanel:show();mainPanel:getParent():show()
            g_app.doScreenshot('/market-shortcuts.png')
            g_app.doScreenshot('/market-grid.png')
        end) then return end
        scheduleEvent(function()
            if not run(function()
                local count=#sent
                module.confirmBuy(offers[1])
                assert(modal and modal:isVisible() and #sent==count,'modal precedes any purchase request')
                assert(buttons[1].text=='Sim, comprar','explicit confirmation button')
                buttons[2].callback();assert(#sent==count,'cancel never reserves or opens checkout')
                module.confirmBuy(offers[1])
            end) then return end
            scheduleEvent(function()
                if not run(function()
                    g_app.doScreenshot('/market-purchase-confirmation.png')
                end) then return end
                scheduleEvent(function()
                    if not run(function()
                        buttons[1].callback()
                        assert(sent[#sent].action=='buy' and sent[#sent].offer==1,'confirmation sends selected offer only')
                        local count=#sent;module.confirmBuy(offers[6]);assert(#sent==count,'expired offer cannot confirm')
                        module.hide();module.toggle()
                        assert(child(panel,'loadingLabel'):isVisible(),'reopen starts loading rather than empty state')
                        scheduleEvent(function()
                            if not run(function()
                                modules.client_entergame.EnterGame.hide()
                                g_app.doScreenshot('/market-loading.png')
                            end) then return end
                        end,400)
                        scheduleEvent(function()
                            if not run(function()
                                assert(not child(panel,'loadingLabel'):isVisible() and child(panel,'refreshOffers'):isEnabled(),'timeout stops loading and enables retry')
                                assert(child(panel,'emptyTitle'):getText():find('carregar os itens') and child(panel,'emptyDescription'):getText():find('Atualizar'),'timeout explains retry')
                                module.refresh(true)
                                assert(child(panel,'loadingLabel'):isVisible(),'manual retry restarts indicator')
                                ProtocolGame.onExtendedOpcode(protocol,224,json.encode({action='offers',offersJson='[]',categoriesJson='{}'}))
                                assert(not child(panel,'loadingLabel'):isVisible() and child(panel,'emptyTitle'):isVisible(),'empty successful response clears loading')
                                module.showSaleInfo()
                                scheduleEvent(function()
                                    if not run(function()
                                        modules.client_entergame.EnterGame.hide()
                                        g_app.doScreenshot('/market-sale-info.png')
                                        module.hide()
                                        local mainPanel=rootWidget:recursiveGetChildById('mainoptionspanel')
                                        mainPanel:getParent():removeChild(mainPanel);rootWidget:addChild(mainPanel)
                                        mainPanel:breakAnchors();mainPanel:setPosition({x=20,y=60});mainPanel:setWidth(172);mainPanel:setHeight(220)
                                        mainPanel:show();mainPanel:setOn(true)
                                        child(mainPanel,'onPanel'):show()
                                        local helper=child(mainPanel,'baiakerosHelperButton')
                                        helper:show();helper:getParent():show();child(mainPanel,'progressButton'):show()
                                        child(mainPanel,'store'):setHeight(44)
                                        for _,button in ipairs(child(mainPanel,'options'):getChildren()) do button:show() end
                                        scheduleEvent(function()
                                            if not run(function()
                                                local shortcut=child(mainPanel,'baiakerosMarketButton')
                                                local parchment=child(mainPanel,'progressButton')
                                                assert(shortcut:getY()==parchment:getY() and shortcut:getX()==parchment:getX()+53,'market sits beside parchment in top shortcut row')
                                                g_app.doScreenshot('/market-shortcuts.png')
                                                restore();g_logger.info('[MarketGridQA] PASS: compact shortcuts, bounded highlights, market placement, filters, loading/retry, sale modal and purchase guards')
                                                scheduleEvent(function() g_app.exit() end,1000)
                                            end) then return end
                                        end,400)
                                    end) then return end
                                end,400)
                            end) then return end
                        end,12500)
                    end) then return end
                end,1000)
            end,1000)
        end,1000)
    end,1000)
end,2500)
