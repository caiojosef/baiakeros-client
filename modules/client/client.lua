function setMusic(filename)
    -- BaiakEros is distributed without audio.
    if g_sounds then
        g_sounds.stopAll()
        g_sounds.disableAudio()
    end
end

function startup()
    if g_sounds then
        g_sounds.stopAll()
        g_sounds.disableAudio()
        g_settings.set('enableAudio', false)
        g_settings.set('enableMusicSound', false)
        g_settings.set('musicSoundVolume', 0)
    end

    -- Check for startup errors
    local errtitle = nil
    local errmsg = nil

    if g_graphics.getRenderer():lower():match('gdi generic') then
        errtitle = tr('Graphics card driver not detected')
        errmsg = tr(
            'No graphics card detected, everything will be drawn using the CPU,\nthus the performance will be really bad.\nPlease update your graphics driver to have a better performance.')
    end

    -- Show entergame
    if errmsg or errtitle then
        local msgbox = displayErrorBox(errtitle, errmsg)
        msgbox.onOk = function()
            EnterGame.firstShow()
        end
    else
        EnterGame.firstShow()
    end
end

function init()
    if g_app.hasUpdater() then
        connect(g_app, {
            onUpdateFinished = startup,
        })
    else
        connect(g_app, {
            onRun = startup,
        })
    end

end

function terminate()
    if g_app.hasUpdater() then
        disconnect(g_app, {
            onUpdateFinished = startup,
        })
    else
        disconnect(g_app, {
            onRun = startup,
        })
    end
end
