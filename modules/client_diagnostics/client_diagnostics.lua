local markerPath = '/diagnostics/session.active'
local heartbeatEvent
local startedAt

local function safeValue(callback, fallback)
    local ok, value = pcall(callback)
    if ok then
        return value
    end
    return fallback
end

local function buildSessionState()
    local online = safeValue(function() return g_game.isOnline() end, false)
    local character = safeValue(function() return g_game.getCharacterName() end, '')
    local world = safeValue(function() return g_game.getWorldName() end, '')

    return table.concat({
        'status=running',
        'pid=' .. tostring(g_platform.getProcessId()),
        'started=' .. startedAt,
        'heartbeat=' .. os.date('%Y-%m-%d %H:%M:%S'),
        'build=' .. g_app.getVersion() .. ' rev ' .. g_app.getBuildRevision() .. ' (' .. g_app.getBuildCommit() .. ')',
        'arch=' .. g_app.getBuildArch(),
        'online=' .. tostring(online),
        'character=' .. tostring(character or ''),
        'world=' .. tostring(world or ''),
        'windowVisible=' .. tostring(safeValue(function() return g_window.isVisible() end, false)),
        'windowFocused=' .. tostring(safeValue(function() return g_window.hasFocus() end, false)),
        'fps=' .. tostring(safeValue(function() return g_app.getFps() end, 0)),
    }, '\n') .. '\n'
end

local function writeHeartbeat()
    local ok, errorMessage = pcall(function()
        g_resources.writeFileContents(markerPath, buildSessionState())
    end)
    if not ok then
        g_logger.warning('[Diagnostics] Unable to update session marker: ' .. tostring(errorMessage))
    end
    heartbeatEvent = scheduleEvent(writeHeartbeat, 10000)
end

function init()
    g_resources.makeDir('/diagnostics')

    if g_resources.fileExists(markerPath) then
        local previousState = safeValue(function()
            return g_resources.readFileContents(markerPath)
        end, 'Previous session state could not be read.')

        g_resources.writeFileContents('/diagnostics/last-unclean-session.log',
            'Detected at ' .. os.date('%Y-%m-%d %H:%M:%S') .. '\n' .. previousState)
        g_logger.warning('[Diagnostics] The previous client session did not finish cleanly. ' ..
            'Details saved to diagnostics/last-unclean-session.log')
    end

    startedAt = os.date('%Y-%m-%d %H:%M:%S')
    g_logger.info('[Diagnostics] Session started. PID=' .. tostring(g_platform.getProcessId()) ..
        ', directory=' .. g_resources.getWriteDir() .. '/diagnostics')
    writeHeartbeat()
end

function terminate()
    if heartbeatEvent then
        removeEvent(heartbeatEvent)
        heartbeatEvent = nil
    end
    g_logger.info('[Diagnostics] Lua modules finished cleanly; waiting for native shutdown.')
end
