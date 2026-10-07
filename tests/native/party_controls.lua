-- Offline UI validation with the real OTUI widgets and keybind registry.
scheduleEvent(function()
    local originalPlayer=g_game.getLocalPlayer
    local id=1
    local fake={getId=function()return id end,getVocation=function()return 0 end,
        getInventoryItem=function()return nil end,getName=function()return 'Party Controls QA' end,
        isMonk=function()return false end,isPartyMember=function()return false end}
    g_game.getLocalPlayer=function()return fake end
    local ok,err=pcall(function()
        local helper=modules.game_baiakeros_helper_v2
        local hunt=helper.PartyHuntV2
        local page=helper.helperV2Window:recursiveGetChildById('partyHuntPage')
        assert(not page:recursiveGetChildById('partyTeleport'),'manual teleport is removed')
        assert(Keybind.getAction('Baiakeros Party Hunt','Boss lever formation'),'formation hotkey is registered')
        local function status()
            ProtocolGame.onExtendedOpcode({},93,json.encode({action='status',active=false,
                remaining=10800,limitSeconds=10800,canControl=id==1,vocation=2,
                canConfigureMovement=true,settings={runThreshold=2,alwaysRun=false},
                leader={id=1,name='Leader'},members={{id=1,name='Leader',leader=true},
                    {id=2,name='Member 2'},{id=3,name='Member 3'},{id=4,name='Member 4'}}}))
        end
        status();hunt.minimize();hunt.showFloating()
        local float
        for _,child in ipairs(rootWidget:getChildren())do
            if child:recursiveGetChildById('partyFloatRoster')then float=child;break end
        end
        assert(float,'floating window exists')
        hunt.setLeverHotkey()
        local editor
        for _,child in ipairs(rootWidget:getChildren())do
            if child.keybind and child.keybind.category=='Baiakeros Party Hunt' then editor=child;break end
        end
        assert(editor and editor:isVisible(),'Set hotkey opens the real key editor')
        editor:hide();editor:ungrabKeyboard()
        scheduleEvent(function()
            local controls=float:recursiveGetChildById('partyFloatLeverControls')
            local roster=float:recursiveGetChildById('partyFloatRoster')
            local checkbox=float:recursiveGetChildById('partyFloatBossLever')
            local hotkey=float:recursiveGetChildById('partyFloatLeverHotkey')
            assert(controls:isVisible() and float:getHeight()==318)
            assert(checkbox:getPosition().x+checkbox:getWidth()<=hotkey:getPosition().x,'checkbox and hotkey do not overlap')
            assert(roster:getPosition().y>=controls:getPosition().y+controls:getHeight(),'roster is below lever controls')
            assert(roster:getPosition().y+roster:getHeight()<float:getPosition().y+float:getHeight()-10,'leader roster fits')
            g_app.doScreenshot('/party-lever-leader.png')
            id=2;status();hunt.minimize();float:show()
            scheduleEvent(function()
                assert(not controls:isVisible() and float:getHeight()==270)
                assert(roster:getPosition().y+roster:getHeight()<float:getPosition().y+float:getHeight()-10,'member roster fits')
                g_app.doScreenshot('/party-lever-member.png')
                g_game.getLocalPlayer=originalPlayer
                g_logger.info('[PartyControlsQA] PASS: real panel, keybind registry, leader controls and both minimized rosters fit')
                scheduleEvent(function()g_app.exit()end,600)
            end,300)
        end,300)
    end)
    if not ok then
        g_game.getLocalPlayer=originalPlayer
        g_logger.error('[PartyControlsQA] FAIL: '..tostring(err))
        g_app.exit()
    end
end,1200)
