local tests = 0
local playerFile = '/baiakeros-player-minimap.otmm'
local bundledFile = '/data/minimap.otmm'
local function scenario(options)
    local calls, saves, clean, backups, settings = {}, {}, 0, {}, {}
    local files = options.files or {}
    local loaded = options.loaded or {}
    local content = {}
    g_resources = {
        fileExists = function(file) return files[file] == true end,
        readFileContents = function(file) return 'old-player-map' end,
        writeFileContents = function(file, bytes) backups[file] = bytes; return not options.backupFails end,
    }
    g_minimap = {
        clean = function() clean = clean + 1; content = {} end,
        isDirty = function() return true end,
        loadOtmm = function(file)
            calls[#calls + 1] = file
            content[file] = true
            return loaded[file] ~= false
        end,
        saveOtmm = function(file) saves[#saves + 1] = file end,
    }
    g_settings = {
        getString = function(_, default) return options.version or 'baiakeros-2026-08-11-1' end,
        set = function(key, value) settings[key] = value end, save = function() end,
    }
    g_logger = { warning = function() end }
    modules = { game_interface = { getMainRightPanel = function() end } }
    Controller = { new = function() return {
        setUI = function() end, registerEvents = function() return { execute = function() end } end,
        scheduleEvent = function() end,
        ui = { minimapBorder = { minimap = { load = function() end, save = function() end } } },
    } end }
    g_game = { getLocalPlayer = function() return nil end }
    LocalPlayer = {}
    dofile('modules/game_minimap/minimap.lua')
    mapController:onGameStart()
    return { calls = calls, saves = saves, clean = function() return clean end, content = function() return content end,
        backups = backups, settings = settings }
end

local function case(name, fn)
    local ok, err = pcall(fn)
    assert(ok, name .. ': ' .. tostring(err))
    tests = tests + 1
end

case('healthy player map is loaded without replacing exploration', function()
    local r = scenario({files = {[playerFile] = true, [bundledFile] = true}})
    assert(#r.calls == 1 and r.calls[1] == playerFile and #r.saves == 0)
    mapController:onGameEnd(); assert(#r.saves == 1)
end)
case('failed player load restores bundled map and preserves damaged file', function()
    local r = scenario({files = {[playerFile] = true, [bundledFile] = true}, loaded = {[playerFile] = false}})
    assert(r.calls[1] == playerFile and r.calls[2] == bundledFile and #r.saves == 1)
    assert(r.clean() == 2 and not r.content()[playerFile] and r.content()[bundledFile])
    assert(r.backups['/baiakeros-player-minimap.recovery-backup.otmm'] == 'old-player-map')
end)
case('existing recovery backup is never overwritten', function()
    local r = scenario({files = {[playerFile] = true, [bundledFile] = true, ['/baiakeros-player-minimap.recovery-backup.otmm'] = true}, loaded = {[playerFile] = false}})
    assert(not next(r.backups) and #r.saves == 1)
end)
case('backup failure still permits recovery', function()
    local r = scenario({files = {[playerFile] = true, [bundledFile] = true}, loaded = {[playerFile] = false}, backupFails = true})
    assert(#r.saves == 1 and r.calls[2] == bundledFile)
end)
case('failure of both maps never overwrites the player map on logout or terminate', function()
    local r = scenario({files = {[playerFile] = true, [bundledFile] = true}, loaded = {[playerFile] = false, [bundledFile] = false}})
    mapController:onGameEnd(); mapController:onTerminate()
    assert(#r.saves == 0 and not next(r.settings))
end)
case('missing personal map installs the bundle', function()
    local r = scenario({files = {[bundledFile] = true}})
    assert(r.calls[1] == bundledFile and #r.saves == 1)
end)
case('missing bundle does not prevent loading a healthy personal map', function()
    local r = scenario({files = {[playerFile] = true}})
    assert(r.calls[1] == playerFile and #r.saves == 0)
end)
case('missing both maps never saves an empty map', function()
    local r = scenario({})
    mapController:onGameEnd(); assert(#r.calls == 0 and #r.saves == 0)
end)
case('updated bundle installs once', function()
    local r = scenario({files = {[playerFile] = true, [bundledFile] = true}, version = 'older'})
    assert(r.calls[1] == bundledFile and #r.saves == 1)
    assert(r.settings['baiakeros-bundled-minimap-version'] == 'baiakeros-2026-08-11-1')
end)
print('PASS: ' .. tests .. ' minimap recovery cases')
