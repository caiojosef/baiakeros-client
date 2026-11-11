EnterGame = {}

function safeDecrypt(text)
    if not text or text == '' then
        return ''
    end
    local success, result = pcall(g_crypt.decrypt, text)
    return success and result or ''
end

-- private variables
local loadBox
local enterGame
local motdWindow
local enterGameButton
local clientBox
local protocolLogin
local motdEnabled = true
local tokenWindow
local authenticatorContext
local loginRequestSequence = 0
local savedAccountsConfig

local SAVED_ACCOUNTS_FILE = '/saved-accounts.otml'
local SAVED_ACCOUNTS_NODE = 'accounts'

local function trim(value)
    return tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', '')
end

local function normalizeCredentialValue(value)
    return trim(value):lower()
end

local function savedAccountId(host, email)
    return g_crypt.sha256(normalizeCredentialValue(host) .. '\n' .. normalizeCredentialValue(email))
end

-- Reload before every write so another open client can add an account without
-- this process replacing its newer copy with stale in-memory data.
local function openSavedAccountsConfig(refresh)
    if refresh and savedAccountsConfig then
        g_configs.unload(SAVED_ACCOUNTS_FILE)
        savedAccountsConfig = nil
    end

    if not savedAccountsConfig then
        savedAccountsConfig = g_configs.create(SAVED_ACCOUNTS_FILE)
    end
    return savedAccountsConfig
end

local function readSavedAccountNodes(refresh)
    local config = openSavedAccountsConfig(refresh)
    if not config then
        return {}, nil
    end

    local accounts = config:getNode(SAVED_ACCOUNTS_NODE)
    if type(accounts) ~= 'table' then
        accounts = {}
    end
    return accounts, config
end

local function getSavedAccountsForHost(host, refresh)
    local hostKey = normalizeCredentialValue(host)
    local accounts = readSavedAccountNodes(refresh)
    local result = {}

    for id, entry in pairs(accounts) do
        if type(entry) == 'table' and normalizeCredentialValue(entry.host) == hostKey then
            local email = safeDecrypt(entry.email)
            if email ~= '' then
                table.insert(result, {
                    id = id,
                    email = email,
                    password = safeDecrypt(entry.password),
                    lastUsed = tonumber(entry.lastUsed) or 0
                })
            end
        end
    end

    table.sort(result, function(left, right)
        return normalizeCredentialValue(left.email) < normalizeCredentialValue(right.email)
    end)
    return result
end

local function saveLocalAccount(host, email, password)
    host = trim(host)
    email = trim(email)
    if host == '' or email == '' then
        return false
    end

    local accounts, config = readSavedAccountNodes(true)
    if not config then
        return false
    end

    accounts[savedAccountId(host, email)] = {
        host = normalizeCredentialValue(host),
        email = g_crypt.encrypt(email),
        password = password ~= '' and g_crypt.encrypt(password) or '',
        lastUsed = os.time()
    }
    config:setNode(SAVED_ACCOUNTS_NODE, accounts)
    return config:save()
end

local function removeLocalAccount(host, email)
    host = trim(host)
    email = trim(email)
    if host == '' or email == '' then
        return false
    end

    local accounts, config = readSavedAccountNodes(true)
    if not config then
        return false
    end

    local id = savedAccountId(host, email)
    if not accounts[id] then
        return false
    end

    accounts[id] = nil
    config:setNode(SAVED_ACCOUNTS_NODE, accounts)
    return config:save()
end

local function refreshSavedAccountsButton()
    if not enterGame then
        return
    end

    local button = enterGame:getChildById('savedAccountsButton')
    if not button then
        return
    end
    local host = enterGame:getChildById('serverHostTextEdit'):getText()
    local count = #getSavedAccountsForHost(host, true)
    if count == 0 then
        button:setTooltip(tr('No accounts saved on this computer'))
    elseif count == 1 then
        button:setTooltip(tr('1 account saved on this computer'))
    else
        button:setTooltip(string.format('%d accounts saved on this computer', count))
    end
end

local function saveAccountAfterSuccessfulLogin()
    local rememberEmail = enterGame:getChildById('rememberEmailBox'):isChecked()
    local rememberPassword = enterGame:getChildById('rememberPasswordBox'):isChecked()

    if rememberEmail then
        saveLocalAccount(G.host, G.account, rememberPassword and G.password or '')
    else
        removeLocalAccount(G.host, G.account)
    end
    refreshSavedAccountsButton()
end

-- private functions
local function onError(protocol, message, errorCode)
    if loadBox then
        loadBox:destroy()
        loadBox = nil
    end

    G.authenticatorToken = nil
    G.sessionKey = nil
    if tonumber(errorCode) == 6 then
        EnterGame.showAuthenticatorInput(message)
        return
    end
    EnterGame.destroyToken()

    if not errorCode then
        EnterGame.clearAccountFields()
    end

    local errorBox = displayErrorBox(tr('Login Error'), message)
    connect(errorBox, {
        onOk = EnterGame.show
    })
end

local function onMotd(protocol, motd)
    G.motdNumber = tonumber(motd:sub(0, motd:find('\n')))
    G.motdMessage = motd:sub(motd:find('\n') + 1, #motd)
end

local function onSessionKey(protocol, sessionKey)
    G.sessionKey = sessionKey
end

local function onCharacterList(protocol, characters, account, otui)
    local httpLogin = enterGame:getChildById('httpLoginBox'):isChecked()

    -- Try add server to the server list
    ServerList.add(G.host, G.port, g_game.getClientVersion(), httpLogin)

    -- Save 'Stay logged in' setting
    g_settings.set('staylogged', enterGame:getChildById('stayLoggedBox'):isChecked())
    g_settings.set('httpLogin', httpLogin)

    local rememberEmail = enterGame:getChildById('rememberEmailBox'):isChecked()
    local rememberPassword = enterGame:getChildById('rememberPasswordBox'):isChecked()

    if rememberEmail then
        g_settings.set('account', g_crypt.encrypt(G.account))
    else
        g_settings.remove('account')
    end

    if rememberPassword then
        g_settings.set('password', g_crypt.encrypt(G.password))
    else
        g_settings.remove('password')
    end

    ServerList.setServerAccount(G.host, rememberEmail and G.account or '')
    ServerList.setServerPassword(G.host, rememberPassword and G.password or '')
    ServerList.setServerAutologin(G.host, false)
    g_settings.set('autologin', false)
    ServerList.save()
    saveAccountAfterSuccessfulLogin()

    if loadBox then
        loadBox:destroy()
        loadBox = nil
    end

    for _, characterInfo in pairs(characters) do
        if characterInfo.previewState and characterInfo.previewState ~= PreviewState.Default then
            characterInfo.worldName = characterInfo.worldName .. ', Preview'
        end
    end

    CharacterList.create(characters, account, otui)
    CharacterList.show()

    if motdEnabled then
        local lastMotdNumber = g_settings.getNumber('motd')
        if G.motdNumber and G.motdNumber ~= lastMotdNumber then
            g_settings.set('motd', G.motdNumber)
            motdWindow = displayInfoBox(tr('Message of the day'), G.motdMessage)
            connect(motdWindow, {
                onOk = function()
                    CharacterList.show()
                    motdWindow = nil
                end
            })
            CharacterList.hide()
        end
    end
end

local function onUpdateNeeded(protocol, signature)
    if loadBox then
        loadBox:destroy()
        loadBox = nil
    end

    if EnterGame.updateFunc then
        local continueFunc = EnterGame.show
        local cancelFunc = EnterGame.show
        EnterGame.updateFunc(signature, continueFunc, cancelFunc)
    else
        local errorBox = displayErrorBox(tr('Update needed'), tr('Your client needs updating, try redownloading it.'))
        connect(errorBox, {
            onOk = EnterGame.show
        })
    end
end

local function updateLabelText()
    if enterGame:getChildById('clientComboBox') and tonumber(enterGame:getChildById('clientComboBox'):getText()) > 1080 then
        enterGame:setText("Journey Onwards")
        enterGame:getChildById('emailLabel'):setText("Email:")
        enterGame:getChildById('rememberEmailBox'):setText("Remember Email")
        enterGame:getChildById('rememberPasswordBox'):setText("Remember Password")
    else
        enterGame:setText("Enter Game")
        enterGame:getChildById('emailLabel'):setText("Acc Name:")
        enterGame:getChildById('rememberEmailBox'):setText("Remember Account")
        enterGame:getChildById('rememberPasswordBox'):setText("Remember Password")
    end
end

local function loadServerListModule()
    local module = g_modules.getModule('client_serverlist')

    if module and not module:isLoaded() then
        module:load()
    end
end

function EnterGame.selectSavedAccount(account)
    if not enterGame or not account then
        return
    end

    local accountEdit = enterGame:getChildById('accountNameTextEdit')
    local savedAccountsButton = enterGame:getChildById('savedAccountsButton')
    local passwordEdit = enterGame:getChildById('accountPasswordTextEdit')
    local rememberEmailBox = enterGame:getChildById('rememberEmailBox')
    local rememberPasswordBox = enterGame:getChildById('rememberPasswordBox')

    accountEdit:setText(account.email)
    accountEdit:setCursorPos(-1)
    passwordEdit:setText(account.password or '')
    rememberEmailBox:setChecked(true)
    rememberPasswordBox:setChecked(account.password ~= nil and account.password ~= '')

    local host = enterGame:getChildById('serverHostTextEdit'):getText()
    ServerList.setServerAccount(host, account.email)
    ServerList.setServerPassword(host, account.password or '')
    ServerList.setServerAutologin(host, false)
    ServerList.save()

    if account.password == nil or account.password == '' then
        passwordEdit:focus()
    end
end

function EnterGame.removeSavedAccount(email)
    if not enterGame then
        return
    end

    local host = enterGame:getChildById('serverHostTextEdit'):getText()
    removeLocalAccount(host, email)

    local currentEmail = enterGame:getChildById('accountNameTextEdit'):getText()
    if normalizeCredentialValue(currentEmail) == normalizeCredentialValue(email) then
        enterGame:getChildById('rememberEmailBox'):setChecked(false)
        enterGame:getChildById('rememberPasswordBox'):setChecked(false)
        ServerList.setServerAccount(host, '')
        ServerList.setServerPassword(host, '')
        ServerList.setServerAutologin(host, false)
        ServerList.save()
        g_settings.remove('account')
        g_settings.remove('password')
    end

    refreshSavedAccountsButton()
end

function EnterGame.showSavedAccounts()
    if not enterGame then
        return
    end

    local accountEdit = enterGame:getChildById('accountNameTextEdit')
    local host = enterGame:getChildById('serverHostTextEdit'):getText()
    local accounts = getSavedAccountsForHost(host, true)
    local menu = g_ui.createWidget('PopupMenu')
    local rowWidth = math.max(184, accountEdit:getWidth())

    if #accounts == 0 then
        menu:addOption(tr('No saved accounts'), function() end, nil, true)
    else
        for _, account in ipairs(accounts) do
            local selectedAccount = account
            local row = g_ui.createWidget('SavedAccountMenuEntry', menu)
            row:setWidth(rowWidth)

            local emailButton = row:getChildById('emailButton')
            emailButton:setText(selectedAccount.email)
            emailButton.onClick = function()
                menu:destroy()
                EnterGame.selectSavedAccount(selectedAccount)
            end

            local removeButton = row:getChildById('removeButton')
            removeButton:setTooltip(string.format('Remove %s from this computer', selectedAccount.email))
            removeButton.onClick = function()
                EnterGame.removeSavedAccount(selectedAccount.email)
                row:destroy()
                if menu:getChildCount() == 0 then
                    menu:destroy()
                end
            end
        end
    end

    menu:setWidth(rowWidth + 6)
    menu:display({
        x = accountEdit:getX(),
        y = accountEdit:getY() + accountEdit:getHeight()
    })
    connect(menu, {
        onDestroy = function()
            if enterGame and savedAccountsButton then
                savedAccountsButton:setOn(false)
            end
        end
    })
    if savedAccountsButton then
        savedAccountsButton:setOn(true)
    end
end

-- public functions
function EnterGame.init()
    enterGame = g_ui.displayUI('entergame')
    openSavedAccountsConfig(false)
    Keybind.new("Misc.", "Change Character", "Ctrl+G", "")
    Keybind.bind("Misc.", "Change Character", {
      {
        type = KEY_DOWN,
        callback = EnterGame.openWindow,
      }
    })

    local host = g_settings.get('host')
    local port = g_settings.get('port')
    local stayLogged = g_settings.getBoolean('staylogged')
    local httpLogin = g_settings.getBoolean('httpLogin')
    local clientVersion = g_settings.getInteger('client-version')

    if not clientVersion or clientVersion == 0 then
        clientVersion = 860
    end

    if not port or port == 0 then
        port = 7171
    end

    local servers = g_settings.getNode("ServerList") or {}
    local serverData = servers[host] or {}
    EnterGame.setAccountName(serverData.account or '')
    EnterGame.setPassword(serverData.password or '')
    if ServerList and host and #host > 0 then
        ServerList.setServerAutologin(host, false)
    end
    g_settings.set('autologin', false)
    enterGame:getChildById('serverHostTextEdit'):setText(host)
    enterGame:getChildById('serverPortTextEdit'):setText(port)
    enterGame:getChildById('stayLoggedBox'):setChecked(stayLogged)
    enterGame:getChildById('httpLoginBox'):setChecked(httpLogin)

    local installedClients = {}
    if modules.client_assets and modules.client_assets.getInstalledClientVersions then
        installedClients = modules.client_assets.getInstalledClientVersions()
    else
        for _, dirItem in ipairs(g_resources.listDirectoryFiles('/data/things/')) do
            if tonumber(dirItem) then
                installedClients[dirItem] = true
            end
        end
    end

    local amountInstalledClients = 0
    for _ in pairs(installedClients) do
        amountInstalledClients = amountInstalledClients + 1
    end
    local canDownloadAssets = modules.client_assets and modules.client_assets.isEnabled and modules.client_assets.isEnabled()

    clientBox = enterGame:getChildById('clientComboBox')

    for _, proto in pairs(g_game.getSupportedClients()) do
        local protoStr = tostring(proto)
        if installedClients[protoStr] or amountInstalledClients == 0 or (canDownloadAssets and proto >= 1281) then
            installedClients[protoStr] = nil
            clientBox:addOption(proto)
        end
    end

    for protoStr, status in pairs(installedClients) do
        if status then
            print(string.format('Warning: %s recognized as an installed client, but not supported.', protoStr))
        end
    end

    clientBox:setCurrentOption(clientVersion)

    connect(clientBox, {
        onOptionChange = EnterGame.onClientVersionChange
    })

    local function saveRememberedCredentials()
        local selectedHost = enterGame:getChildById('serverHostTextEdit'):getText()
        local account = enterGame:getChildById('accountNameTextEdit'):getText()
        local password = enterGame:getChildById('accountPasswordTextEdit'):getText()
        local rememberEmail = enterGame:getChildById('rememberEmailBox'):isChecked()
        local rememberPassword = enterGame:getChildById('rememberPasswordBox'):isChecked()

        ServerList.setServerAccount(selectedHost, rememberEmail and account or '')
        ServerList.setServerPassword(selectedHost, rememberPassword and password or '')
        ServerList.setServerAutologin(selectedHost, false)
        g_settings.set('host', selectedHost)
        g_settings.set('autologin', false)
        ServerList.save()
        g_configs.saveSettings()
    end

    connect(enterGame:getChildById('rememberEmailBox'), {
        onCheckChange = saveRememberedCredentials
    })
    connect(enterGame:getChildById('rememberPasswordBox'), {
        onCheckChange = saveRememberedCredentials
    })

    if Servers_init and next(Servers_init) ~= nil then
        local server = Servers_init[host]
        enterGame.disableToken = not (server and server.useAuthenticator)
        if table.size(Servers_init) == 1 then
            local hostInit, valuesInit = next(Servers_init)
            EnterGame.setUniqueServer(hostInit, valuesInit.port, valuesInit.protocol)
            EnterGame.setHttpLogin(valuesInit.httpLogin)
        elseif not host or host == "" then
            local hostInit, valuesInit = next(Servers_init)
            EnterGame.setDefaultServer(hostInit, valuesInit.port, valuesInit.protocol)
            EnterGame.setHttpLogin(valuesInit.httpLogin)
        end
    else
        EnterGame.toggleStayLoggedBox(clientVersion, true)
    end

    refreshSavedAccountsButton()

    updateLabelText()

    enterGame:hide()

    connect(g_game, {
        onGameStart = EnterGame.hidePanels
    })

    connect(g_game, {
        onGameEnd = EnterGame.showPanels
    })

    if g_app.isRunning() and not g_game.isOnline() then
        enterGame:show()
    end
end

function EnterGame.hidePanels()
    if g_modules.getModule("client_bottommenu"):isLoaded()  then
        modules.client_bottommenu.hide()
    end
    modules.client_topmenu.hide()
end

function EnterGame.showPanels()
    if g_modules.getModule("client_bottommenu"):isLoaded()  then
        modules.client_bottommenu.show()
    end
    modules.client_topmenu.show()
end

function EnterGame.showServerList()
    loadServerListModule()

    if ServerList then
        ServerList.show()
    end
end

function EnterGame.firstShow()
    EnterGame.show()

    if Services and Services.status then
        if g_modules.getModule("client_bottommenu"):isLoaded()  then
            EnterGame.postCacheInfo()
            EnterGame.postEventScheduler()
            -- EnterGame.postShowOff() -- myacc/znote no send login.php
            EnterGame.postShowCreatureBoost()
        end
    end
end

function EnterGame.terminate()
    EnterGame.destroyToken()
    Keybind.delete("Misc.", "Change Character")

    disconnect(clientBox, {
        onOptionChange = EnterGame.onClientVersionChange
    })
    disconnect(g_game, {
        onGameStart = EnterGame.hidePanels
    })
    disconnect(g_game, {
        onGameEnd = EnterGame.showPanels
    })

    if enterGame then
        enterGame:destroy()
        enterGame = nil
    end

    if clientBox then
        clientBox = nil
    end

    if motdWindow then
        motdWindow:destroy()
        motdWindow = nil
    end

    if loadBox then
        loadBox:destroy()
        loadBox = nil
    end

    if protocolLogin then
        protocolLogin:cancelLogin()
        protocolLogin = nil
    end

    if savedAccountsConfig then
        savedAccountsConfig:save()
        g_configs.unload(SAVED_ACCOUNTS_FILE)
        savedAccountsConfig = nil
    end

    EnterGame = nil
end

local function reportRequestWarning(requestType, msg, errorCode)
    g_logger.warning(("[Webscraping - %s] %s"):format(requestType, msg), errorCode)
end

function EnterGame.postCacheInfo()
    local requestType = 'cacheinfo'

    local onRecvInfo = function(message, err)

        if err then
            -- onError(nil, 'Bad Request. Game_entergame postCacheInfo1 ', 400)
            reportRequestWarning(requestType, "Bad Request. Game_entergame postCacheInfo1")
            return
        end

        local jsonString = message:match("{.*}")
        if not jsonString then
            reportRequestWarning(requestType, "Invalid JSON response format")
            return
        end

        local success, response = pcall(function() return json.decode(jsonString) end)
        if not success or not response then
            reportRequestWarning(requestType, "Failed to parse JSON response")
            return
        end

        if response.errorMessage then
            reportRequestWarning(requestType, response.errorMessage, response.errorCode)
            return
        end

        modules.client_topmenu.setPlayersOnline(response.playersonline)
        modules.client_topmenu.setDiscordStreams(response.discord_online)
        modules.client_topmenu.setYoutubeStreams(response.gamingyoutubestreams)
        modules.client_topmenu.setYoutubeViewers(response.gamingyoutubeviewer)
        modules.client_topmenu.setLinkYoutube(response.youtube_link)
        modules.client_topmenu.setLinkDiscord(response.discord_link)

    end

    HTTP.post(Services.status, json.encode({
        type = requestType
    }), onRecvInfo, false)
end

function EnterGame.postEventScheduler()
    local requestType = 'eventschedule'
    local onRecvInfo = function(message, err)
        if err then
            reportRequestWarning(requestType, "Bad Request.Game_entergame postEventScheduler1")
            return
        end

        local jsonString = message:match("{.*}")
        if not jsonString then
            reportRequestWarning(requestType, "Invalid JSON response format")
            return
        end

        local success, response = pcall(function() return json.decode(jsonString) end)
        if not success or not response then
            reportRequestWarning(requestType, "Failed to parse JSON response")
            return
        end

        if response.errorMessage then
            reportRequestWarning(requestType, response.errorMessage, response.errorCode)
            return
        end
        modules.client_bottommenu.setEventsSchedulerTimestamp(response.lastupdatetimestamp)
        modules.client_bottommenu.setEventsSchedulerCalender(response.eventlist)
    end

    HTTP.post(Services.status, json.encode({
        type = requestType
    }), onRecvInfo, false)
end

function EnterGame.postShowOff()
    local requestType = 'showoff'
    local onRecvInfo = function(message, err)
        if err then
            reportRequestWarning(requestType, "Bad Request.Game_entergame postShowOff")
            return
        end

        local jsonString = message:match("{.*}")
        if not jsonString then
            reportRequestWarning(requestType, "Invalid JSON response format")
            return
        end

        local success, response = pcall(function() return json.decode(jsonString) end)
        if not success or not response then
            reportRequestWarning(requestType, "Failed to parse JSON response")
            return
        end

        if response.errorMessage then
            reportRequestWarning(requestType, response.errorMessage, response.errorCode)
            return
        end

        modules.client_bottommenu.setShowOffData(response)
    end

    HTTP.post(Services.status, json.encode({
        type = requestType
    }), onRecvInfo, false)
end

function EnterGame.postShowCreatureBoost()
    local requestType = 'boostedcreature'
    local onRecvInfo = function(message, err)
        if err then
            -- onError(nil, 'Bad Request. 1 Game_entergame postShowCreatureBoost', 400)
            reportRequestWarning(requestType, "Bad Request.Game_entergame postShowCreatureBoost1")
            return
        end

        local jsonString = message:match("{.*}")
        if not jsonString then
            reportRequestWarning(requestType, "Invalid JSON response format")
            return
        end

        local success, response = pcall(function() return json.decode(jsonString) end)
        if not success or not response then
            reportRequestWarning(requestType, "Failed to parse JSON response")
            return
        end

        if response.errorMessage then
            reportRequestWarning(requestType, response.errorMessage, response.errorCode)
            return
        end

        modules.client_bottommenu.setBoostedCreatureAndBoss(response)
    end

    HTTP.post(Services.status, json.encode({
        type = requestType
    }), onRecvInfo, false)
end

function EnterGame.show()
    if tokenWindow then
        tokenWindow:raise()
        tokenWindow:getChildById('tokenEdit'):focus()
        return
    end
    if g_game.isOnline() or CharacterList.isVisible() then -- fix login quickly error (http post)
        return
    end

    if loadBox then
        return
    end

    enterGame:show()
    enterGame:raise()
    enterGame:focus()
end

function EnterGame.hide()
    enterGame:hide()
end

function EnterGame.openWindow()
    if g_game.isOnline() then
        CharacterList.show()
    elseif not g_game.isLogging() and not CharacterList.isVisible() then
        EnterGame.show()
    end
end

function EnterGame.setAccountName(account)
    local decrypted = safeDecrypt(account or '')
    enterGame:getChildById('accountNameTextEdit'):setText(decrypted)
    enterGame:getChildById('accountNameTextEdit'):setCursorPos(-1)
    enterGame:getChildById('rememberEmailBox'):setChecked(#decrypted > 0)
end

function EnterGame.setPassword(password)
    local decrypted = safeDecrypt(password or '')
    enterGame:getChildById('accountPasswordTextEdit'):setText(decrypted)
    enterGame:getChildById('rememberPasswordBox'):setChecked(#decrypted > 0)
end

function EnterGame.setHttpLogin(httpLogin)
    if type(httpLogin) == "boolean" then
        enterGame:getChildById('httpLoginBox'):setChecked(httpLogin)
    else
        enterGame:getChildById('httpLoginBox'):setChecked(#httpLogin > 0)
    end
end

function EnterGame.clearAccountFields()
    enterGame:getChildById('accountNameTextEdit'):clearText()
    enterGame:getChildById('accountPasswordTextEdit'):clearText()
    enterGame:getChildById('rememberEmailBox'):setChecked(false)
    enterGame:getChildById('rememberPasswordBox'):setChecked(false)
    enterGame:getChildById('accountNameTextEdit'):focus()
    g_settings.remove('account')
    g_settings.remove('password')
end

function EnterGame.toggleStayLoggedBox(clientVersion, init)
    local enabled = (clientVersion >= 1074)
    if enabled == enterGame.stayLoggedBoxEnabled then
        return
    end

    enterGame:getChildById('stayLoggedBox'):setOn(enabled)

    local newHeight = enterGame:getHeight()
    local newY = enterGame:getY()
    if enabled then
        newY = newY - enterGame.stayLoggedBoxHeight
        newHeight = newHeight + enterGame.stayLoggedBoxHeight
    else
        newY = newY + enterGame.stayLoggedBoxHeight
        newHeight = newHeight - enterGame.stayLoggedBoxHeight
    end

    if not init then
        enterGame:setY(newY)
        enterGame:bindRectToParent()
    end

    enterGame:setHeight(newHeight)
    enterGame.stayLoggedBoxEnabled = enabled
end

function EnterGame.onClientVersionChange(comboBox, text, data)
    local clientVersion = tonumber(text)
    EnterGame.toggleStayLoggedBox(clientVersion)
    updateLabelText()
end

function EnterGame.tryHttpLogin(clientVersion, httpLogin)
    g_game.setClientVersion(clientVersion)
    g_game.setProtocolVersion(g_game.getClientProtocolVersion(clientVersion))
    g_game.chooseRsa(G.host)
    if not modules.game_things.isLoaded() then
        if loadBox then
            loadBox:destroy()
            loadBox = nil
        end

        local errorBox = displayErrorBox(tr("Login Error"), string.format("Things are not loaded, please put assets in things/%d/<assets>.", clientVersion))
        connect(errorBox, {
            onOk = EnterGame.show
        })
        return
    end

    -- Show connecting message immediately
    loadBox = displayCancelBox(tr('Connecting'), tr('Your character list is being loaded. Please wait.'))
    connect(loadBox, {
        onCancel = function(msgbox)
            loadBox = nil
            EnterGame.destroyToken()
            EnterGame.show()
        end
    })

    local host, path = G.host, "/"
    if G.host:find("https?://") then
        local url = G.host:gsub("https?://", "")
        host, path = url:match("([^/]+)(/.*)")
        if not host then
            host = url
            path = "/"
        elseif not path or path == "" then
            path = "/"
        end
        local hostPort = host:match(":(%d+)$")
        if hostPort then
            host = host:gsub(":%d+$", "")
            G.port = tonumber(hostPort)
        end
    end

    if not G.port then
        if G.host:find("https") then
            G.port = 443
        else
            G.port = 80
        end
    end

    loginRequestSequence = loginRequestSequence + 1
    G.requestId = loginRequestSequence

    local http = LoginHttp.create()
    http:httpLogin(host, path, G.port, G.account, G.password, G.requestId, httpLogin, G.authenticatorToken)
end

function printTable(t)
    for k, v in pairs(t) do
        if type(v) == "table" then
            print(string.format("%q: {", k))
            printTable(v)
            print("}")
        else
            print(string.format("%q:", k) .. tostring(v) .. ",")
        end
    end
end

function EnterGame.loginSuccess(requestId, jsonSession, jsonWorlds, jsonCharacters)
    if G.requestId ~= requestId then
        return
    end

    -- Update the existing loadBox message or create new one if it doesn't exist
    if loadBox then
        loadBox:destroy()
    end
    loadBox = displayCancelBox(tr('Connecting'), tr('Your character list is being loaded. Please wait.'))

    connect(loadBox, {
        onCancel = function(msgbox)
            loadBox = nil
            EnterGame.destroyToken()
            EnterGame.show()
        end
    })

    if tokenWindow then
        tokenWindow:destroy()
        tokenWindow = nil
    end

    local worlds = {}
    for _, world in ipairs(json.decode(jsonWorlds)) do
        worlds[world.id] = {
            name = world.name,
            ip = world.externaladdressprotected,
            port = world.externalportprotected,
            previewState = world.previewstate == 1,
            pvptype = world.pvptype,
        }
    end

    local characters = {}
    for index, character in ipairs(json.decode(jsonCharacters)) do
        local world = worlds[character.worldid]
        characters[index] = {
            name = character.name,
            level = character.level,
            main = character.ismaincharacter,
            dailyreward = character.dailyrewardstate,
            hidden = character.ishidden,
            vocation = character.vocation,
            outfitid = character.outfitid,
            headcolor = character.headcolor,
            torsocolor = character.torsocolor,
            legscolor = character.legscolor,
            detailcolor = character.detailcolor,
            addonsflags = character.addonsflags,
            worldName = world.name,
            worldIp = world.ip,
            worldPort = world.port,
            previewState = world.previewstate,
            pvptype = world.pvptype,
        }
    end

    local session = json.decode(jsonSession)

    local premiumUntil = tonumber(session.premiumuntil)
    local premiumSeconds = math.max(premiumUntil - os.time(), 0)

    local account = {
        status = '',
        premDays = math.ceil(premiumSeconds / 86400),
        subStatus = premiumUntil > os.time() and SubscriptionStatus.Premium or SubscriptionStatus.Free
    }

    -- The server validates 2FA and returns its game ticket; never retain the submitted code.
    EnterGame.destroyToken()
    G.requestId = 0
    G.sessionKey = session.sessionkey

    onCharacterList(nil, characters, account)
end

function EnterGame.loginFailed(requestId, msg, result)
    if G.requestId ~= requestId then
        return
    end
    G.requestId = 0
    onError(nil, msg, result)
end

function EnterGame.doLogin(authenticatorRetry)
    if not authenticatorRetry then
        EnterGame.destroyToken()
        G.sessionKey = nil
    end
    G.account = enterGame:getChildById('accountNameTextEdit'):getText()
    G.password = enterGame:getChildById('accountPasswordTextEdit'):getText()
    G.stayLogged = enterGame:getChildById('stayLoggedBox'):isChecked()
    G.host = enterGame:getChildById('serverHostTextEdit'):getText()
    G.port = tonumber(enterGame:getChildById('serverPortTextEdit'):getText())
    local clientVersion = tonumber(clientBox:getText())
    G.clientVersion = clientVersion
    local httpLogin = enterGame:getChildById('httpLoginBox'):isChecked()

    if g_game.isOnline() then
        local errorBox = displayErrorBox(tr('Login Error'), tr('Cannot login while already in game.'))
        connect(errorBox, {
            onOk = EnterGame.show
        })
        return
    end

    g_settings.set('host', G.host)
    g_settings.set('port', G.port)
    g_settings.set('client-version', clientVersion)

    if clientVersion >= 1281 and modules.client_assets and modules.client_assets.ensureClientVersion and
        (not modules.client_assets.isEnabled or modules.client_assets.isEnabled()) and
        not modules.client_assets.isClientVersionInstalled(clientVersion) then
        modules.client_assets.ensureClientVersion(clientVersion, function(success, message)
            if success then
                EnterGame.doLogin()
                return
            end

            local errorBox = displayErrorBox(tr('Login Error'), message or tr('Unable to download client assets.'))
            connect(errorBox, {
                onOk = EnterGame.show
            })
        end)
        return
    end

    EnterGame.hide()

    if clientVersion >= 1281 and G.port ~= 7171 then
        EnterGame.tryHttpLogin(clientVersion, httpLogin)
    else
        protocolLogin = ProtocolLogin.create()
        protocolLogin.onLoginError = onError
        protocolLogin.onMotd = onMotd
        protocolLogin.onSessionKey = onSessionKey
        protocolLogin.onCharacterList = onCharacterList
        protocolLogin.onUpdateNeeded = onUpdateNeeded

        loadBox = displayCancelBox(tr('Please wait'), tr('Connecting to login server...'))

        connect(loadBox, {
            onCancel = function(msgbox)
                loadBox = nil
                protocolLogin:cancelLogin()
                EnterGame.show()
            end
        })

        g_game.setClientVersion(clientVersion)
        g_game.setProtocolVersion(g_game.getClientProtocolVersion(clientVersion))
        g_game.chooseRsa(G.host)

        if modules.game_things.isLoaded() then
            protocolLogin:login(G.host, G.port, G.account, G.password, G.authenticatorToken, G.stayLogged)
        else
            if loadBox then
                loadBox:destroy()
                loadBox = nil
            end

            local errorBox = displayErrorBox(tr("Login Error"), string.format("Things are not loaded, please put spr and dat in things/%d/<here>.", clientVersion))
            connect(errorBox, {
               onOk = EnterGame.show
            })
            return
        end
    end
end

function EnterGame.displayMotd()
    if not motdWindow then
        motdWindow = displayInfoBox(tr('Message of the day'), G.motdMessage)
        motdWindow.onOk = function()
            motdWindow = nil
        end
    end
end

function EnterGame.setDefaultServer(host, port, protocol)
    local hostTextEdit = enterGame:getChildById('serverHostTextEdit')
    local portTextEdit = enterGame:getChildById('serverPortTextEdit')
    local clientLabel = enterGame:getChildById('clientLabel')
    local accountTextEdit = enterGame:getChildById('accountNameTextEdit')
    local passwordTextEdit = enterGame:getChildById('accountPasswordTextEdit')

    if hostTextEdit:getText() ~= host then
        hostTextEdit:setText(host)
        portTextEdit:setText(port)
        clientBox:setCurrentOption(protocol)
        accountTextEdit:setText('')
        passwordTextEdit:setText('')
    end
    refreshSavedAccountsButton()
end

function EnterGame.setUniqueServer(host, port, protocol, windowWidth, windowHeight)
    local hostTextEdit = enterGame:getChildById('serverHostTextEdit')
    hostTextEdit:setText(host)
    hostTextEdit:setVisible(false)
    hostTextEdit:setHeight(0)

    local portTextEdit = enterGame:getChildById('serverPortTextEdit')
    portTextEdit:setText(port)
    portTextEdit:setVisible(false)
    portTextEdit:setHeight(0)

    local stayLoggedBox = enterGame:getChildById('stayLoggedBox')
    stayLoggedBox:setChecked(false)
    stayLoggedBox:setOn(false)

    local clientVersion = tonumber(protocol)
    clientBox:setCurrentOption(clientVersion)
    clientBox:setVisible(false)
    clientBox:setHeight(0)

    local serverLabel = enterGame:getChildById('serverLabel')
    serverLabel:setVisible(false)
    serverLabel:setHeight(0)

    local portLabel = enterGame:getChildById('portLabel')
    portLabel:setVisible(false)
    portLabel:setHeight(0)

    local clientLabel = enterGame:getChildById('clientLabel')
    clientLabel:setVisible(false)
    clientLabel:setHeight(0)

    local httpLoginBox = enterGame:getChildById('httpLoginBox')
    httpLoginBox:setVisible(false)
    httpLoginBox:setHeight(0)

    local serverListButton = enterGame:getChildById('serverListButton')
    serverListButton:setVisible(false)
    serverListButton:setHeight(0)
    serverListButton:setWidth(0)

    local rememberEmailBox = enterGame:getChildById('rememberEmailBox')
    rememberEmailBox:setMarginTop(5)

    if not windowWidth then
        windowWidth = 280
    end
    enterGame:setWidth(windowWidth)
    if not windowHeight then
        windowHeight = 221
    end

    enterGame:setHeight(windowHeight)
    enterGame.disableToken = true
    local server = Servers_init[host]
    enterGame.disableToken = not (server and server.useAuthenticator)

    -- preload the assets
    -- this is for the client_bottommenu module
    -- it needs images of outfits
    -- so it can display the boosted creature
    g_game.setClientVersion(clientVersion)
    g_game.setProtocolVersion(g_game.getClientProtocolVersion(clientVersion))
    refreshSavedAccountsButton()
end

function EnterGame.setServerInfo(message)
    local label = enterGame:getChildById('serverInfoLabel')
    label:setText(message)
end

function EnterGame.disableMotd()
    motdEnabled = false
end

-- Only the authenticated login endpoint decides whether this account requires 2FA.
-- No secrets, recovery codes or account-security flags are fetched from the database by the client.
local function setAuthenticatorMessage(message)
    -- The initial production challenge repeats the instructions already above the input.
    if message == 'Digite o código do Google Authenticator ou um código de recuperação.' then
        message = nil
    end
    local label = tokenWindow:getChildById('errorLabel')
    label:setText(message or '')
    local hasMessage = message and message ~= ''
    local height = hasMessage and math.max(14, label:getTextSize().height) or 0
    label:setHeight(height)
    label:setVisible(hasMessage and true or false)
    tokenWindow:setHeight(150 + (hasMessage and height + 8 or 0))
end

function EnterGame.showAuthenticatorInput(message)
    EnterGame.destroyToken()
    EnterGame.hide()
    authenticatorContext = {
        account = G.account, password = G.password, host = G.host, port = G.port,
        clientVersion = G.clientVersion
    }
    tokenWindow = g_ui.displayUI('authenticator')
    tokenWindow:lock()
    setAuthenticatorMessage(message)
    tokenWindow:raise()
    tokenWindow:focus()
    tokenWindow:getChildById('tokenEdit'):focus()
end

function EnterGame.submitAuthenticator()
    if not tokenWindow or not authenticatorContext then return end
    local tokenEdit = tokenWindow:getChildById('tokenEdit')
    local token = trim(tokenEdit:getText())
    local recovery = token:gsub('[%s%-]', '')
    local validTotp = #token == 6 and token:match('^%d+$')
    local validRecovery = #recovery == 20 and recovery:match('^[%x]+$')
    if not validTotp and not validRecovery then
        setAuthenticatorMessage('Digite 6 números ou um código de recuperação completo.')
        tokenEdit:focus()
        return
    end

    local context = authenticatorContext
    if context.account ~= enterGame:getChildById('accountNameTextEdit'):getText()
        or context.password ~= enterGame:getChildById('accountPasswordTextEdit'):getText()
        or context.host ~= enterGame:getChildById('serverHostTextEdit'):getText()
        or context.port ~= tonumber(enterGame:getChildById('serverPortTextEdit'):getText())
        or context.clientVersion ~= tonumber(clientBox:getText()) then
        EnterGame.cancelAuthenticator()
        return
    end

    -- Destroying the modal clears its text; the submitted code exists only for this request.
    EnterGame.destroyToken()
    G.authenticatorToken = token
    EnterGame.doLogin(true)
end

function EnterGame.cancelAuthenticator()
    EnterGame.destroyToken()
    G.sessionKey = nil
    if protocolLogin then protocolLogin:cancelLogin() end
    EnterGame.show()
end

function EnterGame.doLoginWithToken()
    -- A manual prompt is optional; automatic challenges do not depend on useAuthenticator.
    EnterGame.showAuthenticatorInput()
end

function EnterGame.destroyToken()
    if tokenWindow then
        tokenWindow:getChildById('tokenEdit'):clearText()
        tokenWindow:unlock()
        tokenWindow:destroy()
        tokenWindow = nil
    end
    authenticatorContext = nil
    G.authenticatorToken = nil
    G.requestId = 0
end

function ensableBtnCreateNewAccount()
    enterGame.btnCreateNewAccount:enable()
end
