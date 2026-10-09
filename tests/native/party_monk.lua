-- Real OTUI layout validation without connecting any character.
scheduleEvent(function()
    local helper=modules.game_baiakeros_helper_v2
    local originalPlayer=g_game.getLocalPlayer
    g_game.getLocalPlayer=function()return {getId=function()return 2 end,getVocation=function()return 0 end,
        getInventoryItem=function()return nil end,getName=function()return 'Monk Controls QA' end,
        isMonk=function()return false end,isPartyMember=function()return false end}end
    local function fail(err)
        g_game.getLocalPlayer=originalPlayer
        g_logger.error('[PartyMonkQA] FAIL: '..tostring(err))
        g_app.exit()
    end
    local function status(vocation,mode)
        ProtocolGame.onExtendedOpcode({},93,json.encode({action='status',active=false,
            remaining=10800,limitSeconds=10800,canControl=false,vocation=vocation,
            canConfigureMovement=vocation~=4,settings={runThreshold=3,alwaysRun=false,monkMode=mode},
            leader={id=1,name='Leader'},members={{id=1,name='Leader',leader=true},{id=2,name='Monk'}}}))
    end
    local ok,err=pcall(function()
        helper.showHelperV2Tab('party')
        helper.helperV2Window:show();helper.helperV2Window:raise()
        modules.client_entergame.EnterGame.hide()
        status(9,'hold')
        scheduleEvent(function()
            local valid,message=pcall(function()
                local page=helper.helperV2Window:recursiveGetChildById('partyHuntPage')
                local mode=page:recursiveGetChildById('partyMonkMode')
                local label=page:recursiveGetChildById('partyMonkModeLabel')
                local help=page:recursiveGetChildById('partyMovementHelp')
                local extras=page:recursiveGetChildById('partyExtrasColumn')
                assert(mode:isVisible() and label:isVisible() and mode:getCurrentOption().data=='hold')
                assert(mode:getPosition().x>=label:getPosition().x+label:getWidth(),'label and combo do not overlap')
                assert(mode:getPosition().x+mode:getWidth()<extras:getPosition().x+extras:getWidth(),'mode fits extras')
                assert(help:getPosition().y>mode:getPosition().y+mode:getHeight(),'help is below the controls')
                assert(help:getPosition().y+help:getHeight()<extras:getPosition().y+extras:getHeight(),'Monk help fits extras')
                assert(not page:recursiveGetChildById('partyPaladinMode'):isVisible())
                assert(not page:recursiveGetChildById('partyAlwaysRun'):isVisible())
                modules.client_entergame.EnterGame.hide()
                helper.helperV2Window:raise()
                scheduleEvent(function()g_app.doScreenshot('/party-monk-hold.png')end,100)
                status(9,'orbit');assert(mode:getCurrentOption().data=='orbit','real combo restores circle mode')
                status(4);assert(not mode:isVisible() and not label:isVisible(),'Knight hides Monk options')
                status(9,'orbit')
                g_game.getLocalPlayer=originalPlayer
                g_logger.info('[PartyMonkQA] PASS: Monk modes, visibility, real combo selection and Extras layout')
                scheduleEvent(function()g_app.exit()end,600)
            end)
            if not valid then fail(message)end
        end,350)
    end)
    if not ok then fail(err)end
end,1200)
