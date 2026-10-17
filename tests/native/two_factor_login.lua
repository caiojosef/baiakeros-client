-- Isolated native UI/login contract test. Synthetic credentials and codes only.
scheduleEvent(function()
    local login = modules.client_entergame.EnterGame
    local panel = rootWidget:getChildById('enterGame')
    local originalCreate = LoginHttp.create
    local originalCreateList, originalShowList = CharacterList.create, CharacterList.show
    local sent, lists = {}, 0
    LoginHttp.create = function()
        return { httpLogin = function(_, host, path, port, account, password, request, useHttp, token)
            sent[#sent+1] = { request=request, account=account, token=token }
        end }
    end
    CharacterList.create = function() lists=lists+1 end
    CharacterList.show = function() end
    panel:getChildById('rememberEmailBox'):setChecked(false)
    panel:getChildById('rememberPasswordBox'):setChecked(false)
    panel:getChildById('accountNameTextEdit'):setText('twofactor-qa@example.invalid')
    panel:getChildById('accountPasswordTextEdit'):setText('synthetic-password')
    local function modal() return rootWidget:getChildById('authenticatorWindow') end
    local function start()
        login.doLogin()
        assert(sent[#sent].token == nil, 'A fresh login reused a one-time code')
        return sent[#sent].request
    end
    local function challenge(request, message)
        login.loginFailed(request, message or 'Digite o codigo do autenticador.', 6)
        assert(modal() and modal():isVisible())
    end
    local function submit(code)
        modal():getChildById('tokenEdit'):setText(code)
        login.submitAuthenticator()
    end
    local function success(request, key)
        login.loginSuccess(request, json.encode({premiumuntil=0,sessionkey=key}),
            json.encode({{id=0,name='QA',externaladdressprotected='127.0.0.1',externalportprotected=7172,previewstate=0}}), '[]')
    end
    local ok, err = pcall(function()
        -- Account without 2FA follows the normal character-list path.
        success(start(), 'qa-normal-session')
        assert(lists==1 and not modal())

        local first = start()
        challenge(first)
        local count=#sent
        submit('12345')
        assert(#sent==count and modal(), 'Invalid TOTP must not consume a server attempt')
        submit('012345')
        assert(not modal() and sent[#sent].token=='012345' and sent[#sent].request~=first)
        -- Delayed response from an earlier request must not replace this attempt.
        login.loginFailed(first, 'old failure', 6)
        assert(not modal())
        local request=sent[#sent].request
        local blocked='Muitas tentativas. Aguarde 5 minutos e tente novamente.'
        challenge(request,blocked)
        assert(G.authenticatorToken==nil and modal():getChildById('errorLabel'):getText()==blocked)
        assert(modal():getChildById('tokenEdit'):getText()=='')

        -- The production backend accepts 20 hex digits, optionally grouped by hyphens.
        local recovery='ABCD-1234-EFAB-5678-90AB'
        submit(recovery)
        assert(sent[#sent].token==recovery and not modal())
        success(sent[#sent].request,'@2fa:synthetic-ticket\n@session')
        assert(lists==2 and G.sessionKey=='@2fa:synthetic-ticket\n@session' and G.authenticatorToken==nil)

        request=start()
        challenge(request,'Codigo invalido, expirado ou ja utilizado.')
        submit('ABC')
        assert(modal())
        login.cancelAuthenticator()
        assert(not modal() and G.authenticatorToken==nil and G.sessionKey==nil and G.requestId==0)
        login.loginFailed(request,'late challenge after cancel',6)
        assert(not modal())

        challenge(start())
        panel:getChildById('accountNameTextEdit'):setText('different-qa@example.invalid')
        count=#sent
        submit('123456')
        assert(#sent==count and not modal(), 'A challenge must not transfer to another account')

        challenge(start())
        assert(modal():getWidth()==390 and modal():getHeight()==260)
        login.show()
        assert(not panel:isVisible(), 'Login window must not cover the authenticator challenge')
        modal():getChildById('tokenEdit'):setText('012345')
        g_logger.info('[TwoFactorQA] PASS: automatic challenge, normal account, TOTP, recovery, server errors, cancellation, stale responses and account isolation')
    end)
    LoginHttp.create = originalCreate
    CharacterList.create, CharacterList.show = originalCreateList, originalShowList
    if not ok then g_logger.error('[TwoFactorQA] FAIL: '..tostring(err)) end
    scheduleEvent(function()
        if ok then g_app.doScreenshot('/two-factor-login.png') end
        scheduleEvent(function() login.destroyToken(); g_app.exit() end,1000)
    end,700)
end,3000)
