local OPCODE = 224
local entryWindow, consentWindow, marketWindow, refreshEvent, timeoutEvent, statusTimeout, picker
local state = { available = false, status = 'loading' }
local opened, busy, accepted, sessionLocked, awaitingAuthorization = false, false, false, false, false
local authorizationBaseline, activeTab, drafts = nil, 'market', {}
local offers, orders, confirmation, publishing, publishTimeout = {}, {}, nil, nil, nil
local countdownEvent
local filterEvent, rebuildingCategories, selectedCategory = nil, false, 'all'
local availableCategories = {}
local browseLoading, browseFailed, browseQueued, offersLoaded = false, false, false, false
local browseTimeout, loadingEvent, lastOffersUpdate, saleInfo
local renderOffers
local marketButton
local categoryNames = {armor='Armor',helmet='Helmet',legs='Legs',boots='Boots',amulets='Amulets',rings='Rings',
    shields='Shields',weapons='Weapons',containers='Containers',runes='Runes',currency='Gold / Coins',others='Outros'}
local categoryOrder = {'helmet','armor','legs','boots','shields','weapons','amulets','rings','containers','runes','currency','others'}
local function widget(window, id) return window and window:recursiveGetChildById(id) end
local function identityKey()
    local player = g_game.getLocalPlayer()
    return player and 'baiakeros-market-' .. g_crypt.sha256(tostring(G.host or '') .. '\n' .. player:getName())
end
local function saveAccess()
    local key = identityKey()
    if key then g_settings.set(key .. '-signed-out', sessionLocked); g_settings.save() end
end
local function cancelTimers()
    for _, event in ipairs({ refreshEvent or false, timeoutEvent or false, statusTimeout or false, publishTimeout or false, countdownEvent or false, filterEvent or false, browseTimeout or false, loadingEvent or false }) do
        if event then removeEvent(event) end
    end
    refreshEvent, timeoutEvent, statusTimeout, publishTimeout = nil, nil, nil, nil
    countdownEvent = nil
    filterEvent = nil
    browseTimeout, loadingEvent = nil, nil
    browseLoading, browseQueued = false, false
end
local function sendRequest(action, extra)
    if not g_game.isOnline() then return false end
    local protocol = g_game.getProtocolGame()
    if not protocol then return false end
    local request = extra or {}
    request.action = action
    protocol:sendExtendedOpcode(OPCODE, json.encode(request))
    return true
end
local function itemName(id)
    local currencies = { [3031] = 'gold coin', [3035] = 'platinum coin', [3043] = 'crystal coin' }
    if currencies[id] then return currencies[id] end
    local ok, data = pcall(function() return g_things.getThingType(id, ThingCategoryItem):getMarketData() end)
    return ok and data and data.name and data.name ~= '' and data.name or 'Item ' .. tostring(id)
end
local function draftCard(index) return widget(marketWindow, 'draft' .. index) end
local MAX_PRICE_CENTS = 100000000
local function formatMoney(cents)
    local whole = tostring(math.floor(cents / 100))
    whole = whole:reverse():gsub('(%d%d%d)', '%1.'):reverse():gsub('^%.', '')
    return whole .. ',' .. string.format('%02d', cents % 100)
end
local function priceCents(text)
    local digits = tostring(text or ''):gsub('[^0-9]', '')
    if digits == '' then return 0 end
    return tonumber(digits) or MAX_PRICE_CENTS + 1
end
function formatPrice(field, text)
    if field.formatting then return end
    field.formatting = true
    local digits = tostring(text or ''):gsub('[^0-9]', ''):gsub('^0+', '')
    -- Work in integer cents; punctuation is presentation only.
    local formatted = digits == '' and '' or formatMoney(tonumber(digits) or 0)
    if field:getText() ~= formatted then field:setText(formatted); field:setCursorPos(-1) end
    field.formatting = false
end
local function rememberDraftEdits()
    for index = 1, 3 do
        local draft, card = drafts[index], draftCard(index)
        if draft and draft.id and card then
            draft.priceCents = priceCents(widget(card, 'price'):getText())
            draft.durationHours = widget(card, 'duration'):getCurrentOption().data
        end
    end
end
local function persistDrafts()
    local key=identityKey()
    if not key then return end
    local saved={}
    for index,draft in pairs(drafts) do
        if draft.id then saved[index]={id=draft.id,count=draft.count,priceCents=draft.priceCents,durationHours=draft.durationHours} end
    end
    g_settings.setNode(key..'-drafts',saved);g_settings.save()
end
local function renderDrafts()
    if not marketWindow then return end
    local count = 0
    for index = 1, 3 do
        local card, draft = draftCard(index), drafts[index] or {}
        widget(card, 'item'):setItemId(tonumber(draft.id) or 0)
        widget(card, 'item'):setItemCount(draft.count or 1)
        widget(card, 'itemName'):setText(draft.id and itemName(draft.id) or 'Escolha um item')
        widget(card, 'lotSummary'):setText(draft.id and ('Lote completo: ' .. (draft.count or 1) .. ' unidade(s)') or 'O lote será o item selecionado')
        widget(card, 'price'):setText(draft.priceCents and draft.priceCents > 0 and formatMoney(draft.priceCents) or '')
        widget(card, 'duration'):setCurrentOptionByData(draft.durationHours or 6)
        widget(card, 'removeItem'):setEnabled(draft.id ~= nil)
        widget(card, 'publishItem'):setEnabled(draft.token ~= nil and publishing == nil)
        widget(card,'draftState'):setText(not draft.id and '' or (draft.token and 'Rascunho - ainda não publicado' or 'Rascunho salvo - selecione o item novamente para publicar.'))
        if draft.id then count = count + 1 end
    end
    widget(marketWindow, 'draftCounter'):setText(count .. ' de 3 espaços preenchidos')
end
local function expiryEpoch(value)
    local y, m, d, h, minute, second = tostring(value or ''):match('^(%d%d%d%d)%-(%d%d)%-(%d%d) (%d%d):(%d%d):(%d%d)$')
    if not y then return nil end
    y, m, d, h, minute, second = tonumber(y), tonumber(m), tonumber(d), tonumber(h), tonumber(minute), tonumber(second)
    if m < 1 or m > 12 or d < 1 or d > 31 or h > 23 or minute > 59 or second > 59 then return nil end
    -- Convert the server's UTC date directly; os.time(table) uses local time/DST.
    if m <= 2 then y = y - 1 end
    local era = math.floor(y / 400)
    local year = y - era * 400
    local day = math.floor((153 * (m + (m > 2 and -3 or 9)) + 2) / 5) + d - 1
    local days = era * 146097 + year * 365 + math.floor(year / 4) - math.floor(year / 100) + day - 719468
    return days * 86400 + h * 3600 + minute * 60 + second
end
local function categoryOf(offer)
    if categoryNames[offer.category] then return offer.category end
    local id=tonumber(offer.item_id) or 0
    if id==3031 or id==3035 or id==3043 then return 'currency' end
    local ok,data=pcall(function() return g_things.getThingType(id,ThingCategoryItem):getMarketData() end)
    local map={[1]='armor',[2]='amulets',[3]='boots',[4]='containers',[7]='helmet',[8]='legs',[11]='rings',[12]='runes',[13]='shields',[25]='containers'}
    local category=ok and data and tonumber(data.category)
    if category and (category>=16 and category<=21 or category==27 or category==255) then return 'weapons' end
    return map[category] or 'others'
end
local function matchesFilter(offer)
    local search=tostring(widget(marketWindow,'searchName'):getText() or ''):lower()
    return (selectedCategory=='all' or categoryOf(offer)==selectedCategory)
        and tostring(offer.item_name or ''):lower():find(search,1,true)~=nil
end
local function rebuildCategories()
    local combo=widget(marketWindow,'categoryFilter')
    rebuildingCategories=true
    combo:clearOptions();combo:addOption('Todas as categorias','all')
    for _,category in ipairs(categoryOrder) do
        if availableCategories[category] then combo:addOption(categoryNames[category],category) end
    end
    if not availableCategories[selectedCategory] then selectedCategory='all' end
    combo:setCurrentOptionByData(selectedCategory)
    rebuildingCategories=false
end
local function requestOffers()
    if browseLoading then browseQueued=true; return end
    local search=widget(marketWindow,'searchName'):getText()
    local hex=search:gsub('.',function(char) return string.format('%02x',string.byte(char)) end)
    local categoryHex=selectedCategory:gsub('.',function(char) return string.format('%02x',string.byte(char)) end)
    browseLoading, browseFailed = true, false
    renderOffers()
    local frame=0
    local function animate()
        loadingEvent=nil
        if not opened or not browseLoading then return end
        frame=frame+1
        widget(marketWindow,'loadingSegment'):setMarginLeft((frame%9)*15)
        widget(marketWindow,'loadingLabel'):setText('Carregando itens'..string.rep('.',frame%4))
        loadingEvent=scheduleEvent(animate,150)
    end
    animate()
    browseTimeout=scheduleEvent(function()
        browseTimeout=nil; browseLoading=false; browseFailed=true; browseQueued=false
        if loadingEvent then removeEvent(loadingEvent);loadingEvent=nil end
        renderOffers()
    end,12000)
    if not sendRequest('browse',{searchHex=hex,categoryHex=categoryHex}) then
        removeEvent(browseTimeout);browseTimeout=nil
        removeEvent(loadingEvent);loadingEvent=nil
        browseLoading=false;browseFailed=true;renderOffers()
    end
end
local function updateCountdowns()
    if not opened or not marketWindow or not marketWindow:isVisible() then return end
    local list = widget(marketWindow, 'offersList')
    for _, card in ipairs(list:getChildren()) do
        if card.marketExpiry then
            local remaining = math.max(0, card.marketExpiry - os.time())
            widget(card, 'expiry'):setText(remaining > 0 and string.format('Restam %02d:%02d:%02d',
                math.floor(remaining / 3600), math.floor(remaining / 60) % 60, remaining % 60) or 'Prazo encerrado')
            if remaining == 0 then widget(card, 'buy'):setEnabled(false) end
        end
    end
end
local function tickCountdowns()
    countdownEvent = nil
    if not opened then return end
    updateCountdowns()
    countdownEvent = scheduleEvent(tickCountdowns, 1000)
end
renderOffers = function()
    local list = widget(marketWindow, 'offersList')
    local offset = list:getVirtualOffset()
    list:destroyChildren()
    for _,order in ipairs(orders) do if matchesFilter(order) then
        local row=g_ui.createWidget('BaiakerosMarketOfferRow',list)
        widget(row,'item'):setItemId(tonumber(order.item_id) or 0)
        widget(row,'item'):setItemCount(tonumber(order.item_count) or 1)
        widget(row,'name'):setText(tostring(order.item_name or 'Item'))
        local labels={created='Aguardando pagamento',creating='Preparando pagamento',pending='Aguardando aprovação',paid='Pago · entrega no Inbox',expired='Reserva encerrada',refunded='Reembolsado',refund_pending='Reembolso em processamento',review_required='Em análise'}
        local status=order.delivery_state=='delivered' and 'Entregue no Your Inbox' or (labels[order.state] or 'Em processamento')
        widget(row,'details'):setText('Sua compra · '..status)
        widget(row,'price'):setText('R$ '..formatMoney(tonumber(order.price_cents) or 0))
        widget(row,'expiry'):setText('')
        local button=widget(row,'buy')
        button:setText(order.delivery_state=='delivered' and 'Entregue' or 'Continuar')
        button:setEnabled((order.state=='created' or order.state=='pending') and not sessionLocked)
        button.onClick=function() sendRequest('resume',{order=order.id}) end
    end end
    local filteredCount=0
    for _, offer in ipairs(offers) do if matchesFilter(offer) then
        filteredCount=filteredCount+1
        local row = g_ui.createWidget('BaiakerosMarketOfferRow', list)
        widget(row, 'item'):setItemId(tonumber(offer.item_id) or 0)
        widget(row, 'item'):setItemCount(tonumber(offer.item_count) or 1)
        widget(row, 'name'):setText(tostring(offer.item_name or 'Item'))
        widget(row, 'details'):setText(offer.own and 'Seu anúncio' or ('Lote: ' .. tostring(offer.item_count or 1) .. ' unidade(s)'))
        widget(row, 'price'):setText('R$ ' .. formatMoney(tonumber(offer.price_cents) or 0))
        row.marketExpiry = expiryEpoch(offer.expires_at)
        widget(row, 'expiry'):setText(row.marketExpiry and '' or 'Prazo indisponível')
        local button = widget(row, 'buy')
        local labels = { reserved='Reservado', paid='Pago', returning='Devolvendo' }
        button:setText(labels[offer.state] or (offer.own and 'Seu anúncio' or 'Comprar'))
        button:setEnabled(not offer.own and offer.state == 'active' and not sessionLocked and row.marketExpiry ~= nil and row.marketExpiry > os.time())
        button.onClick = function() confirmBuy(offer) end
    end end
    local empty = #list:getChildren()==0
    local filtered=selectedCategory~='all' or widget(marketWindow,'searchName'):getText()~=''
    widget(marketWindow,'emptyTitle'):setText(browseFailed and 'Não foi possível carregar os itens' or (filtered and 'Nenhum item encontrado' or 'Nenhum anúncio ativo'))
    widget(marketWindow,'emptyDescription'):setText(browseFailed and 'Clique em Atualizar para tentar novamente.' or (filtered and 'Tente outro nome ou categoria.' or 'Anúncios vencidos retornam ao Your Inbox. Rascunhos precisam ser publicados.'))
    for _, id in ipairs({'emptyIcon', 'emptyTitle', 'emptyDescription', 'prepareItems'}) do widget(marketWindow,id):setVisible(empty and not browseLoading and (offersLoaded or browseFailed)) end
    local initialLoading=browseLoading and empty
    widget(marketWindow,'loadingLabel'):setVisible(initialLoading)
    widget(marketWindow,'loadingTrack'):setVisible(initialLoading)
    widget(marketWindow,'refreshOffers'):setText(browseLoading and 'Buscando...' or 'Atualizar')
    widget(marketWindow,'refreshOffers'):setEnabled(not browseLoading)
    list:setVisible(not empty)
    widget(marketWindow,'offersScroll'):setVisible(not empty)
    if filtered or browseFailed then widget(marketWindow,'prepareItems'):hide() end
    list:setVirtualOffset(offset)
    updateCountdowns()
    widget(marketWindow, 'offerCount'):setText(browseLoading and not offersLoaded and 'Buscando anúncios...' or (empty and 'Nenhum anúncio encontrado' or (filteredCount .. ' anúncio(s) · '..#orders..' compra(s)')))
    widget(marketWindow, 'lastUpdate'):setText(browseLoading and 'Atualizando itens...' or (browseFailed and 'Falha na consulta · tente atualizar' or (lastOffersUpdate and 'Atualizado às '..lastOffersUpdate or '')))
end
function showSaleInfo()
    if saleInfo then saleInfo:raise(); return end
    saleInfo=g_ui.createWidget('BaiakerosMarketSaleInfo',rootWidget)
    saleInfo:show();saleInfo:raise();saleInfo:focus();saleInfo:lock()
end
function closeSaleInfo()
    if saleInfo then saleInfo:unlock();saleInfo:destroy();saleInfo=nil end
end
function searchChanged()
    if not marketWindow or not opened then return end
    if filterEvent then removeEvent(filterEvent) end
    filterEvent=scheduleEvent(function()
        filterEvent=nil
        if opened and not sessionLocked then requestOffers() end
    end,350)
    renderOffers()
end
function categoryChanged()
    if rebuildingCategories or not marketWindow or not opened then return end
    local option=widget(marketWindow,'categoryFilter'):getCurrentOption()
    selectedCategory=option and option.data or 'all'
    renderOffers();requestOffers()
end
function confirmBuy(offer)
    local expiry = expiryEpoch(offer.expires_at)
    if confirmation or sessionLocked or offer.own or offer.state ~= 'active' or not expiry or expiry <= os.time() then return end
    local cancel = function() if confirmation then confirmation:destroy(); confirmation=nil end end
    local buy = function()
        cancel()
        if sessionLocked or not opened or expiry <= os.time() then return end
        sendRequest('buy', { offer=tonumber(offer.id) })
    end
    confirmation = displayGeneralBox('Confirmar compra', tostring(offer.item_name) .. '\nPreço total: R$ ' .. formatMoney(offer.price_cents)
        .. '\nTem certeza de que deseja comprar?\nVocê será levado ao Mercado Pago. Após a aprovação, o lote irá para o seu Your Inbox.',
        {{text='Sim, comprar',callback=buy},{text='Cancelar',callback=cancel}},buy,cancel)
end
function selectTab(tab)
    if tab ~= 'market' and tab ~= 'register' then return end
    activeTab = tab
    for _, name in ipairs({ 'market', 'register' }) do
        widget(marketWindow, name .. 'Page'):setVisible(name == tab)
        widget(marketWindow, name .. 'Tab'):setOn(name == tab)
    end
end
local function render()
    if not entryWindow or not opened or picker and g_ui.isMouseGrabbed() then return end
    local authorized = state.available and state.status == 'connected' and not sessionLocked
    if authorized then
        entryWindow:hide(); consentWindow:unlock(); consentWindow:hide()
        if not marketWindow:isVisible() then marketWindow:show(); marketWindow:raise(); marketWindow:focus() end
        widget(marketWindow, 'accountStatus'):setText(state.environment == 'test' and 'TESTE · Conta conectada' or 'Conta conectada')
        selectTab(activeTab)
    else
        marketWindow:hide()
        if not entryWindow:isVisible() then entryWindow:show(); entryWindow:raise(); entryWindow:focus() end
        local title, description = 'Conecte sua conta', 'Vincule seu Mercado Pago para acessar o Market do Baiakeros.'
        if state.status == 'loading' then title, description = 'Consultando sua conta', 'Só um instante. Estamos verificando sua conexão.'
        elseif sessionLocked then title, description = 'Bem-vindo de volta', 'Sua conta continua vinculada. Entre no Mercado Pago para acessar o painel.'
        elseif state.status == 'expired' then title, description = 'Entre novamente', 'Renove a autorização do Mercado Pago para acessar seu Market.'
        elseif not state.available then title, description = 'Conexão indisponível', 'Não foi possível consultar sua conta. Use Atualizar para tentar novamente.' end
        widget(entryWindow, 'entryTitle'):setText(title)
        widget(entryWindow, 'entryDescription'):setText(description)
        local message = state.message or (awaitingAuthorization and 'Conclua a autorização no navegador e volte ao jogo.' or '')
        widget(entryWindow, 'entryMessage'):setText(message)
        widget(entryWindow, 'entryMessage'):setHeight(message ~= '' and 34 or 0)
        entryWindow:setHeight(message ~= '' and 270 or 230)
        widget(entryWindow, 'connectAccount'):setText(sessionLocked and 'Entrar com Mercado Pago' or 'Conectar agora')
        widget(entryWindow, 'connectAccount'):setEnabled(state.available == true and not busy)
    end
    widget(consentWindow, 'connectionConsent'):setChecked(accepted)
    widget(consentWindow, 'connectionConsent'):setEnabled(not accepted)
    widget(consentWindow, 'confirmConnection'):setEnabled(accepted and not busy and state.available == true)
end
function refresh(manual)
    if not opened then return end
    sendRequest('status')
    if manual then browseFailed=false end
    if state.status == 'connected' and not sessionLocked and not browseFailed then requestOffers() end
    if state.status == 'loading' and not statusTimeout then
        statusTimeout = scheduleEvent(function()
            statusTimeout = nil
            state = { available = false, status = 'unavailable', message = 'O servidor não respondeu. Tente atualizar.' }
            render()
        end, 10000)
    end
    if refreshEvent then removeEvent(refreshEvent) end
    refreshEvent = scheduleEvent(refresh, 5000)
    if marketWindow then renderOffers() end
end
function showConsent()
    if busy or not state.available then return end
    consentWindow:show(); consentWindow:raise(); consentWindow:focus(); consentWindow:lock()
    render()
end
function closeConsent() if consentWindow then consentWindow:unlock(); consentWindow:hide() end end
function consentChanged()
    local check = widget(consentWindow, 'connectionConsent')
    if check:isChecked() then accepted = true; check:setEnabled(false) end
    widget(consentWindow, 'confirmConnection'):setEnabled(accepted and not busy and state.available == true)
end
function openAccountConnection()
    if not opened or busy or not state.available or not accepted then return end
    busy = true; awaitingAuthorization = false
    authorizationBaseline = state.connectedAt or state.expiry or ''
    state.message = 'Preparando sua conexão segura...'
    closeConsent(); render()
    if not sendRequest('connect', { consent = true }) then busy = false; render(); return end
    if timeoutEvent then removeEvent(timeoutEvent) end
    timeoutEvent = scheduleEvent(function()
        timeoutEvent = nil; busy = false
        state.message = 'Não houve resposta. Aguarde e tente novamente.'
        render()
    end, 12000)
end
function signOut()
    sessionLocked = true; accepted = true; awaitingAuthorization = false; busy = false
    saveAccess()
    state.message = 'Você saiu do Market. O vínculo da sua conta foi mantido.'
    activeTab = 'market'; render()
end
local function cancelPicker()
    if picker and g_ui.isMouseGrabbed() then picker:ungrabMouse(); g_mouse.popCursor('target') end
    if picker then picker:hide() end
    render()
end
function assignItem(index, item)
    if index < 1 or index > 3 or state.status ~= 'connected' or sessionLocked then return false end
    local position = item and item:getPosition()
    if not item or not position or position.x ~= 65535 then return false, 'Escolha um item da sua mochila ou equipamento.' end
    local id = item:getId()
    if type(id) ~= 'number' or id <= 0 then return false, 'Escolha um item válido.' end
    rememberDraftEdits()
    drafts[index] = { id = id, count = math.max(1, item:getCount()), priceCents = 0, durationHours = 6,
        quoteKey=g_crypt.sha256(tostring(g_clock.millis())..':'..index..':'..id..':'..tostring(item)) }
    sendRequest('quote', {index=index,y=position.y,z=position.z,itemId=id,count=drafts[index].count,quoteKey=drafts[index].quoteKey})
    renderDrafts(); return true
end
function chooseItem(index)
    if g_ui.isMouseGrabbed() or not opened or state.status ~= 'connected' or sessionLocked then return end
    if not picker then picker = g_ui.createWidget('UIWidget'); picker:setVisible(false); picker:setFocusable(false) end
    marketWindow:hide()
    picker.onMousePress = function(_, position, button)
        if button == MouseRightButton then cancelPicker(); return true end
        if button ~= MouseLeftButton then return true end
        local root = modules.game_interface.getRootPanel()
        local target = root and root:recursiveGetChildByPos(position, false)
        local item
        while target do
            if target:getClassName() == 'UIItem' then item = target:getItem(); break end
            target = target:getParent()
        end
        local ok, message = assignItem(index, item)
        if ok then cancelPicker()
        else modules.game_textmessage.displayFailureMessage(message or 'Escolha um item da mochila.') end
        return true
    end
    -- Consume the release belonging to the selection, so it cannot use the inventory item.
    picker.onMouseRelease = function() return true end
    picker:grabMouse(); g_mouse.pushCursor('target')
    modules.game_textmessage.displayStatusMessage('Clique no item da mochila. Botão direito cancela.')
end
function removeItem(index)
    if index < 1 or index > 3 then return end
    rememberDraftEdits()
    drafts[index] = {}; persistDrafts(); renderDrafts()
end
function saveDrafts()
    if not opened or state.status ~= 'connected' or sessionLocked then return false end
    local prepared = {}
    for index = 1, 3 do
        local draft, card = drafts[index] or {}, draftCard(index)
        if draft.id then
            local cents = priceCents(widget(card, 'price'):getText())
            local hours = widget(card, 'duration'):getCurrentOption().data
            if cents <= 0 or cents > MAX_PRICE_CENTS or cents % 1 ~= 0
                or (hours ~= 6 and hours ~= 12 and hours ~= 24) then
                widget(marketWindow, 'draftMessage'):setText('Informe um preço entre R$ 0,01 e R$ 1.000.000,00 e escolha 6, 12 ou 24 horas.')
                return false
            end
            prepared[index] = { id = draft.id, count = draft.count, priceCents = cents, durationHours = hours, token=draft.token,quoteKey=draft.quoteKey }
        end
    end
    drafts = prepared
    persistDrafts()
    widget(marketWindow, 'draftMessage'):setText('Rascunhos guardados. Os itens continuam na sua mochila.')
    renderDrafts(); return true
end
function publishItem(index)
    if publishing or not saveDrafts() then return end
    local draft = drafts[index]
    local token = draft and draft.token
    if not draft or not token then
        widget(marketWindow,'draftMessage'):setText('Selecione novamente o item da mochila para publicar.'); return
    end
    local operation = g_crypt.sha256(identityKey() .. ':' .. token .. ':' .. draft.priceCents .. ':' .. draft.durationHours)
    publishing = index
    sendRequest('publish', {index=index,cents=draft.priceCents,hours=draft.durationHours,token=token,operation=operation})
    publishTimeout = scheduleEvent(function()
        publishTimeout=nil; publishing=nil
        widget(marketWindow,'draftMessage'):setText('Sem confirmação. Confira o Market antes de selecionar outro item. Tentar novamente repete a mesma operação.')
        renderDrafts(); sendRequest('browse')
    end,15000)
    renderDrafts()
end
local function receive(protocol, opcode, buffer)
    if opcode ~= OPCODE or not g_game.isOnline() or type(buffer) ~= 'string' or #buffer > 32768 then return end
    local ok, data = pcall(json.decode, buffer)
    if not ok or type(data) ~= 'table' then return end
    if data.action == 'status' then
        local wasAuthorized=state.status=='connected' and not sessionLocked
        if statusTimeout then removeEvent(statusTimeout); statusTimeout = nil end
        if awaitingAuthorization and data.status == 'connected' then
            local signature = data.connectedAt or data.expiry or ''
            if signature ~= '' and signature ~= authorizationBaseline then
                sessionLocked = false; awaitingAuthorization = false; accepted = true; saveAccess()
            end
        end
        if data.status == 'connected' then accepted = true end
        state = data; render()
        if opened and data.status=='connected' and not sessionLocked and not wasAuthorized then requestOffers() end
    elseif data.action == 'offers' and marketWindow and opened and not sessionLocked then
        local parsedOk, parsed = pcall(json.decode, data.offersJson or '')
        local ordersOk, parsedOrders=pcall(json.decode,data.ordersJson or '[]')
        if ordersOk and type(parsedOrders)=='table' and #parsedOrders<=10 then orders=parsedOrders end
        if parsedOk and type(parsed)=='table' and #parsed<=50 then
            if browseTimeout then removeEvent(browseTimeout);browseTimeout=nil end
            if loadingEvent then removeEvent(loadingEvent);loadingEvent=nil end
            browseLoading,browseFailed,offersLoaded=false,false,true
            lastOffersUpdate=os.date('%H:%M')
            offers=parsed;availableCategories={}
            local categoriesOk,categories=pcall(json.decode,data.categoriesJson or '')
            if categoriesOk and type(categories)=='table' then
                for category,count in pairs(categories) do if categoryNames[category] and tonumber(count) and tonumber(count)>0 then availableCategories[category]=true end end
            else
                for _,offer in ipairs(offers) do if offer.state=='active' and (expiryEpoch(offer.expires_at) or 0)>os.time() then availableCategories[categoryOf(offer)]=true end end
            end
            rebuildCategories();renderOffers()
            if browseQueued then browseQueued=false;requestOffers() end
        end
    elseif data.action == 'quoted' and marketWindow then
        local index=tonumber(data.index)
        if index and index>=1 and index<=3 and drafts[index] and drafts[index].quoteKey==data.quoteKey and type(data.token)=='string'
            and #data.token==64 and data.token:match('^[a-f0-9]+$') then
            drafts[index].token=data.token
            renderDrafts()
        end
    elseif data.action == 'published' and marketWindow then
        if publishTimeout then removeEvent(publishTimeout); publishTimeout=nil end
        local index=tonumber(data.index)
        if index and index>=1 and index<=3 then
            rememberDraftEdits()
            drafts[index]={}
            persistDrafts()
        end
        publishing=nil; widget(marketWindow,'draftMessage'):setText(data.message or 'Anúncio publicado.'); renderDrafts()
    elseif data.action == 'trade_error' and marketWindow then
        if publishTimeout then removeEvent(publishTimeout); publishTimeout=nil end
        publishing=nil; widget(marketWindow,'draftMessage'):setText(data.message or 'Não foi possível concluir a operação.')
        modules.game_textmessage.displayFailureMessage(data.message or 'Operação indisponível.'); renderDrafts()
    elseif data.action == 'checkout' and opened and not sessionLocked then
        local base=Services and (Services.market or Services.websites) or ''
        local prefix=base:gsub('/+$','')..'/index.php/market/checkout#'
        if type(data.url)=='string' and prefix:match('^https://') and data.url:sub(1,#prefix)==prefix
            and #data.url==#prefix+64 and data.url:sub(#prefix+1):match('^[a-f0-9]+$') then
            g_platform.openUrl(data.url)
        else modules.game_textmessage.displayFailureMessage('Não foi possível validar o link do pagamento.') end
    elseif data.action == 'authorize' and busy then
        local base = Services and (Services.market or Services.websites)
        if type(base) ~= 'string' or not base:match('^https://') then base = 'https://www.baiakeros.com' end
        local prefix = base:gsub('/+$', '') .. '/index.php/market/game#'
        local url = data.url
        if type(url) ~= 'string' or url:sub(1, #prefix) ~= prefix or #url ~= #prefix + 64
            or not url:sub(#prefix + 1):match('^[a-f0-9]+$') then
            state.message = 'Não foi possível validar o link de conexão. Tente novamente.'
        else
            g_platform.openUrl(url); awaitingAuthorization = true
            state.message = 'Autorize no navegador e volte ao jogo.'
        end
        busy = false
        if timeoutEvent then removeEvent(timeoutEvent); timeoutEvent = nil end
        render()
    elseif data.action == 'error' then
        busy = false
        if timeoutEvent then removeEvent(timeoutEvent); timeoutEvent = nil end
        state.message = type(data.message) == 'string' and data.message or 'Não foi possível conectar.'
        render()
    end
end
function hide()
    if marketButton then marketButton:setOn(false) end
    closeSaleInfo()
    if confirmation then confirmation:destroy(); confirmation=nil end
    opened = false; cancelTimers(); cancelPicker(); closeConsent(); busy = false
    for _, window in ipairs({ entryWindow or false, consentWindow or false, marketWindow or false }) do
        if window then window:hide() end
    end
end
local function createWindows()
    if entryWindow then return end
    g_ui.importStyle('market')
    entryWindow = g_ui.createWidget('BaiakerosMarketEntry', rootWidget)
    consentWindow = g_ui.createWidget('BaiakerosMarketConsent', rootWidget)
    marketWindow = g_ui.createWidget('BaiakerosMarketWindow', rootWidget)
    rebuildCategories()
    for index = 1, 3 do
        local card = g_ui.createWidget('BaiakerosMarketDraftCard', widget(marketWindow, 'draftsContainer'))
        card:setId('draft' .. index); card:setMarginLeft((index - 1) * 260)
        widget(card, 'cardTitle'):setText('ITEM ' .. string.format('%02d', index))
        widget(card, 'item').onMouseRelease = function(_, _, button)
            if button == MouseLeftButton or button == MouseRightButton then chooseItem(index); return true end
        end
        widget(card, 'selectItem').onClick = function() chooseItem(index) end
        widget(card, 'removeItem').onClick = function() removeItem(index) end
        widget(card, 'publishItem').onClick = function() publishItem(index) end
        local price = widget(card, 'price')
        price:setValidCharacters('0123456789')
        price.onTextChange = formatPrice
        local duration = widget(card, 'duration')
        for _, hours in ipairs({ 6, 12, 24 }) do duration:addOption(hours .. ' horas', hours) end
    end
end
function toggle()
    if not g_game.isOnline() then return end
    if opened then hide(); return end
    createWindows(); opened = true; activeTab = 'market'
    if marketButton then marketButton:setOn(true) end
    offers={}; orders={}; publishing=nil
    browseLoading,browseFailed,browseQueued,offersLoaded=false,false,false,false
    lastOffersUpdate=nil
    local key = identityKey()
    sessionLocked = key and g_settings.getBoolean(key .. '-signed-out') or sessionLocked
    local saved = key and g_settings.getNode(key .. '-drafts') or {}
    drafts = {}
    for index = 1, 3 do
        local draft = saved and (saved[index] or saved[tostring(index)])
        if type(draft) == 'table' and tonumber(draft.id) and tonumber(draft.id) > 0 then
            local legacyPrice = tonumber((tostring(draft.price or ''):gsub(',', '.'))) or 0
            local hours = tonumber(draft.durationHours)
            drafts[index] = { id = tonumber(draft.id), count = tonumber(draft.count or draft.maximum) or 1,
                priceCents = tonumber(draft.priceCents) or math.floor(legacyPrice * 100 + 0.5),
                durationHours = (hours == 12 or hours == 24) and hours or 6 }
        end
    end
    renderDrafts(); renderOffers(); render(); refresh()
    tickCountdowns()
end
local function offline()
    hide(); state = { available = false, status = 'loading' }
    accepted, sessionLocked, awaitingAuthorization = false, false, false
    authorizationBaseline, drafts = nil, {}
    offers, orders, publishing = {}, {}, nil
end
function init()
    marketButton=modules.game_mainpanel.addCompactStoreButton('baiakerosMarketButton',
        'Market - conectar conta Mercado Pago','/images/options/blue_large',toggle,3)
    modules.game_mainpanel.reloadMainPanelSizes()
    ProtocolGame.registerExtendedOpcode(OPCODE, receive)
    connect(g_game, { onGameEnd = offline })
end
function terminate()
    if marketButton then marketButton:destroy();marketButton=nil;modules.game_mainpanel.reloadMainPanelSizes() end
    disconnect(g_game, { onGameEnd = offline })
    ProtocolGame.unregisterExtendedOpcode(OPCODE); hide()
    for _, window in ipairs({ entryWindow or false, consentWindow or false, marketWindow or false, picker or false }) do
        if window then window:destroy() end
    end
    entryWindow, consentWindow, marketWindow, picker = nil, nil, nil, nil
end
