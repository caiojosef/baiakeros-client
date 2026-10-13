-- Native preview + lifecycle tests. No account login, payments or live provider calls.
scheduleEvent(function()
    local module = modules.game_baiakeros_market
    local originalOnline, originalProtocol, originalOpen, originalPlayer = g_game.isOnline, g_game.getProtocolGame, g_platform.openUrl, g_game.getLocalPlayer
    local originalMarketService = Services.market
    local originalLoginShow = modules.client_entergame.EnterGame.show
    modules.client_entergame.EnterGame.show = function() end
    Services.market = 'https://www.baiakeros.com'
    g_game.setClientVersion(1511)
    -- No real login is performed: remove unrelated startup modals in this isolated preview.
    modules.client_entergame.EnterGame.hide()
    for _, window in ipairs(rootWidget:getChildren()) do window:unlock() end
    local sent, opened = {}, {}
    local protocol = { sendExtendedOpcode = function(_, opcode, buffer)
        assert(opcode == 224); sent[#sent + 1] = json.decode(buffer)
    end }
    local function fromMarket()
        local source = debug.getinfo(3, 'S').source
        return source:find('/game_baiakeros_market/', 1, true) ~= nil
    end
    g_game.isOnline = function() return fromMarket() or originalOnline() end
    g_game.getProtocolGame = function() return protocol end
    g_game.getLocalPlayer = function()
        if fromMarket() then return { getName = function() return 'Market UI QA' end } end
        return originalPlayer()
    end
    g_platform.openUrl = function(url) opened[#opened + 1] = url end
    local key = 'baiakeros-market-' .. g_crypt.sha256(tostring(G.host or '') .. '\nMarket UI QA')
    g_settings.set(key .. '-signed-out', false)
    g_settings.setNode(key .. '-drafts', {})
    local function restore()
        module.hide()
        g_game.isOnline, g_game.getProtocolGame, g_platform.openUrl, g_game.getLocalPlayer = originalOnline, originalProtocol, originalOpen, originalPlayer
        Services.market = originalMarketService
        modules.client_entergame.EnterGame.show = originalLoginShow
        g_settings.setNode(key .. '-drafts', {})
        g_settings.set(key .. '-signed-out', false)
    end
    local function run(callback)
        local ok, error = pcall(callback)
        if not ok then restore(); g_logger.error('[MarketQA] FAIL: ' .. tostring(error)); g_app.exit() end
        return ok
    end
    local entry, consent, panel
    local function child(window,id) return window:recursiveGetChildById(id) end
    local function receive(status, connectedAt, expiry)
        ProtocolGame.onExtendedOpcode(protocol,224,json.encode({ action='status',available=true,status=status,
            environment='test',provider=status=='connected' and 'DEMONSTRACAO' or '',
            connectedAt=connectedAt,expiry=expiry or '2027-04-09 22:11:11' }))
    end
    local function authorize(url) ProtocolGame.onExtendedOpcode(protocol,224,json.encode({ action='authorize',url=url })) end
    local function capture(name)
        modules.client_entergame.EnterGame.hide()
        g_app.doScreenshot('/' .. name .. '.png')
    end
    if not run(function()
        module.toggle()
        entry=rootWidget:recursiveGetChildById('baiakerosMarketEntry')
        consent=rootWidget:recursiveGetChildById('baiakerosMarketConsent')
        panel=rootWidget:recursiveGetChildById('baiakerosMarketWindow')
        assert(entry:isVisible() and not panel:isVisible(), 'compact entry precedes access')
        assert(entry:getWidth() < 500, 'login remains compact')
        receive('disconnected')
        entry:setText('Baiakeros Market · Prévia')
    end) then return end
    scheduleEvent(function()
        if not run(function()
            capture('market-entry')
            module.showConsent()
            assert(consent:isVisible(), 'dedicated confirmation modal')
            assert(not child(consent,'confirmConnection'):isEnabled(), 'confirmation requires consent')
            child(consent,'connectionConsent'):setChecked(true)
            assert(not child(consent,'connectionConsent'):isEnabled() and child(consent,'confirmConnection'):isEnabled(), 'acceptance locks checkbox')
            consent:setText('Confirmar conexão · Prévia')
        end) then return end
        scheduleEvent(function()
            if not run(function()
                capture('market-consent')
                module.openAccountConnection()
                assert(sent[#sent].action=='connect' and sent[#sent].consent and sent[#sent].account_id==nil, 'authenticated request, no caller identity')
                authorize('https://evil.example/index.php/market/game#' .. string.rep('a',64))
                assert(#opened==0, 'untrusted origin rejected')
                module.openAccountConnection()
                authorize('https://www.baiakeros.com/index.php/market/game#' .. string.rep('a',64))
                assert(#opened==1, 'trusted launch accepted')
                receive('connected','2026-10-11 19:11:11')
                assert(panel:isVisible() and not entry:isVisible(), 'connected account opens tabbed dashboard')
                assert(panel:isEnabled() and child(panel,'signOut'):isEnabled(), 'dashboard controls enabled after consent closes')
                assert(not child(panel,'accountTab') and not child(panel,'accountPage'), 'account page removed; connected status and exit remain')
                panel:setText('Baiakeros Market · Prévia de interface')
            end) then return end
            scheduleEvent(function()
                if not run(function()
                    capture('market-dashboard')
                    module.selectTab('register')
                    assert(child(panel,'registerPage'):isVisible(), 'registration tab')
                    local function item(id,count) return {getId=function() return id end,getCount=function() return count end,
                        getPosition=function() return {x=65535,y=65,z=0} end} end
                    for index,id in ipairs({3031,3043,3051}) do
                        local count=index==3 and 1 or 100
                        assert(module.assignItem(index,item(id,count)))
                        local card=child(panel,'draft' .. index)
                        assert(not child(card,'quantity'), 'quantity cannot be edited')
                        assert(child(card,'lotSummary'):getText():find(tostring(count)), 'entire selected stack displayed')
                        child(card,'price'):setText(index .. '50')
                        assert(child(card,'price'):getText()==index .. ',50', 'integer digits format as reais and cents')
                        child(card,'duration'):setCurrentOptionByData(({6,12,24})[index])
                    end
                    assert(not module.assignItem(4,item(3031,1)), 'maximum of three items')
                    local price=child(child(panel,'draft1'),'price')
                    price:setText(''); price:setCursorPos(-1)
                    price:appendText('1'); price:appendText('5'); price:appendText('0')
                    assert(price:getText()=='1,50', 'typing digits progressively formats currency')
                    price:appendText('A'); price:appendText('.')
                    assert(price:getText()=='1,50', 'typed letters and separators blocked')
                    price:removeCharacter(false)
                    assert(price:getText()=='0,15', 'backspace updates cents')
                    price:appendText('0')
                    assert(price:getText()=='1,50', 'typing resumes after deleting')
                    price:setText('123456789')
                    assert(price:getText()=='1.234.567,89', 'thousands and decimal separators')
                    assert(not module.saveDrafts(), 'oversized price rejected')
                    price:setText('abc')
                    assert(price:getText()=='' and not module.saveDrafts(), 'letters and empty price rejected')
                    price:setText('0')
                    assert(not module.saveDrafts(), 'zero price rejected')
                    price:setText('150')
                    assert(module.saveDrafts(), 'valid drafts saved')
                    local saved=g_settings.getNode(key .. '-drafts')
                    for index=1,3 do
                        local draft=saved[index] or saved[tostring(index)]
                        assert(tonumber(draft.count)==(index==3 and 1 or 100) and tonumber(draft.priceCents)==index*100+50, 'full stack and integer cents persist')
                        assert(tonumber(draft.durationHours)==({6,12,24})[index], 'allowed duration persists')
                    end
                    assert(child(panel,'draftCounter'):getText():find('3 de 3'), 'three-item counter')
                    assert(child(panel,'draftMessage'):getText():find('mochila'), 'draft does not transfer item')
                    module.hide(); module.toggle(); receive('connected','2026-10-11 19:11:11'); module.selectTab('register')
                    assert(child(child(panel,'draft1'),'item'):getItemId()==3031, 'draft survives reopening')
                    assert(child(child(panel,'draft3'),'duration'):getCurrentOption().data==24, 'duration survives reopening')
                    assert(not child(child(panel,'draft1'),'publishItem'):isEnabled(), 'reopened draft requires fresh server selection')
                    assert(module.assignItem(1,item(3031,100)))
                    local quote=sent[#sent]
                    assert(quote.action=='quote' and quote.account_id==nil and quote.y==65, 'selection request uses owned inventory location')
                    ProtocolGame.onExtendedOpcode(protocol,224,json.encode({action='quoted',index='1',token=string.rep('d',64),quoteKey=quote.quoteKey}))
                    assert(child(child(panel,'draft1'),'publishItem'):isEnabled(), 'server quote enables publication')
                    child(child(panel,'draft1'),'price'):setText('1500')
                    module.publishItem(1)
                    local publication=sent[#sent]
                    assert(publication.action=='publish' and publication.cents==1500 and publication.hours==6
                        and publication.token==string.rep('d',64) and publication.account_id==nil, 'server publication receives cents and selected capability')
                    ProtocolGame.onExtendedOpcode(protocol,224,json.encode({action='published',index='1',message='Anúncio publicado.'}))
                    assert(child(child(panel,'draft1'),'item'):getItemId()==0, 'published lot clears the draft')
                    module.hide();module.toggle();receive('connected','2026-10-11 19:11:11');module.selectTab('register')
                    assert(child(child(panel,'draft1'),'item'):getItemId()==0,'published draft stays cleared after reopening')
                    assert(child(child(panel,'draft2'),'item'):getItemId()>0,'publishing one lot preserves the other drafts')
                    assert(child(child(panel,'draft2'),'draftState'):getText():find('Rascunho salvo'),'restored draft is explicitly identified')
                    module.removeItem(2)
                    module.hide();module.toggle();receive('connected','2026-10-11 19:11:11');module.selectTab('register')
                    assert(child(child(panel,'draft2'),'item'):getItemId()==0,'manual clear persists after reopening')
                    assert(child(child(panel,'draft3'),'item'):getItemId()==3051,'clearing one space preserves unrelated draft')
                    ProtocolGame.onExtendedOpcode(protocol,224,json.encode({action='offers',offersJson=json.encode({
                        {id=11,item_id=3043,item_count=100,item_name='crystal coin',seller_name='Vendedor de teste',price_cents=1500,expires_at=os.date('!%Y-%m-%d %H:%M:%S',os.time()+7200),state='active',own=false},
                        {id=12,item_id=3051,item_count=1,item_name='energy ring',seller_name='Market UI QA',price_cents=350,expires_at=os.date('!%Y-%m-%d %H:%M:%S',os.time()+14400),state='reserved',own=true}
                    })}))
                    local rows=child(panel,'offersList'):getChildren()
                    assert(#rows==2 and child(rows[1],'buy'):isEnabled() and not child(rows[2],'buy'):isEnabled(), 'offers render; own and reserved lots cannot be bought')
                    local before=#opened
                    ProtocolGame.onExtendedOpcode(protocol,224,json.encode({action='checkout',url='https://evil.example/index.php/market/checkout#'..string.rep('a',64)}))
                    assert(#opened==before, 'untrusted payment origin blocked')
                    ProtocolGame.onExtendedOpcode(protocol,224,json.encode({action='checkout',url='https://www.baiakeros.com/index.php/market/checkout#'..string.rep('a',64)}))
                    assert(#opened==before+1, 'trusted checkout bridge opens')
                end) then return end
                scheduleEvent(function()
                    if not run(function()
                        capture('market-drafts')
                    end) then return end
                    scheduleEvent(function()
                        if not run(function()
                            local requests=#sent
                            module.signOut()
                            assert(entry:isVisible() and not panel:isVisible(), 'sign out closes access')
                            assert(#sent==requests, 'sign out never sends disconnect or deletes tokens')
                            receive('connected','2026-10-11 19:11:11')
                            assert(not panel:isVisible(), 'polling cannot bypass sign out')
                            module.hide(); module.toggle(); receive('connected','2026-10-11 19:11:11')
                            assert(not panel:isVisible(), 'sign out survives reopening')
                            module.showConsent(); module.openAccountConnection()
                            authorize('https://www.baiakeros.com/index.php/market/game#' .. string.rep('b',64))
                            receive('connected','2026-10-11 19:11:11')
                            assert(not panel:isVisible(), 'old authorization does not reopen dashboard')
                            receive('connected','2026-10-11 20:00:00')
                            assert(panel:isVisible(), 'new authorization restores access')
                            module.signOut(); receive('connected',nil)
                            module.showConsent(); module.openAccountConnection()
                            authorize('https://www.baiakeros.com/index.php/market/game#' .. string.rep('c',64))
                            receive('connected',nil)
                            assert(not panel:isVisible(), 'current production expiry cannot bypass sign out')
                            receive('connected',nil,'2027-04-09 23:00:00')
                            assert(panel:isVisible(), 'production expiry confirms a new authorization')
                            local handlers=type(g_game.onGameEnd)=='table' and g_game.onGameEnd or {g_game.onGameEnd}
                            for _,handler in pairs(handlers) do
                                if type(handler)=='function' and debug.getinfo(handler,'S').source:find('/game_baiakeros_market/',1,true) then handler() end
                            end
                            assert(not panel:isVisible() and not entry:isVisible(), 'game logout clears UI')
                            module.toggle()
                            assert(not panel:isVisible(), 'new character cannot see stale account panel')
                            g_logger.info('[MarketQA] PASS: compact entry, locked consent, two tabs, full-stack lots, currency mask, integer cents, durations, persistent sign out, reauthorization and logout privacy')
                        end) then return end
                        scheduleEvent(function() restore(); g_app.exit() end,350)
                    end,300)
                end,300)
            end,300)
        end,300)
    end,300)
end,2500)
