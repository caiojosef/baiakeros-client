-- Repeated loot updates must not rescan bags or rewrite the same setting.
local known, saves, scans = false, 0, 0
g_game = {
    getLocalPlayer = function() return nil end,
    isOnline = function() return false end,
    getContainers = function()
        scans = scans + 1
        return {{ getItems = function() return {{getId = function() return 23721 end}} end }}
    end
}
g_settings = {
    getBoolean = function() return known end,
    getString = function() return '' end,
    set = function(_, value) known = value end,
    save = function() saves = saves + 1 end
}
dofile('modules/game_baiakeros_helper/helper.lua')
helperWindow = {recursiveGetChildById = function() return nil end}
updateExtrasControls()
assert(known and saves == 1 and scans == 1, 'discovering a new Loot Pouch must persist it once')
for index=1,100 do updateExtrasControls() end
assert(saves == 1 and scans == 1, 'repeated loot changes must not rewrite settings or rescan bags after discovery')
print('Helper loot refresh passed: pouch discovery saves once; 100 updates do not rescan bags or rewrite settings')
