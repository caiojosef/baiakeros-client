Cyclopedia = {}

trackerButton = nil
trackerMiniWindow = nil
trackerButtonBosstiary = nil
trackerMiniWindowBosstiary = nil
contentContainer = nil

local buttonSelection = nil
local items = nil
local bestiary = nil
local charms = nil
local map = nil
local houses = nil
-- House auctions are intentionally parked. Houses are currently purchased at
-- their doors with !buyhouse and left with !leavehouse.
local houseAuctionsEnabled = false
local character = nil
local CyclopediaButton = nil
local bosstiary = nil
local bossSlot = nil
local ButtonBossSlot = nil
local ButtonBestiary = nil
local tabStack = {}
local previousType = nil
local windowTypes = {}
local magicalArchives = nil
local customPanel = nil
local customModules = { codex = 'game_codex', tasks = 'game_hunting_tasks' }

-- These panels belong to their own modules. Preserve them when changing pages
-- or unloading the Cyclopedia, instead of destroying them with the page host.
local function releaseCustomPanel()
    if customPanel then
        if previousType == 'tasks' then
            modules.game_hunting_tasks.onTabHidden()
        end
        customPanel:hide()
        customPanel:breakAnchors()
        customPanel:setParent(rootWidget)
        customPanel = nil
    end
end

local function showCustomPanel(parent, tab)
    local module = modules[customModules[tab]]
    if not module then return end
    customPanel = module.createPanel(parent)
    if customPanel then
        customPanel:show()
        module.refreshFromServer()
    end
end
local BESTIARY_DISCOVERY_OPCODE = 217
local BOSSTIARY_DISCOVERY_OPCODE = 223
local ECHO_WARDEN_PROGRESS_OPCODE = 221
local pendingBestiaryDiscoveryRaceId = nil
local pendingBosstiaryDiscoveryRaceId = nil
Cyclopedia.EchoWardenProgress = {}
Cyclopedia.BossRaceOverrides = {
    [2595] = { name = "Adlerauge", outfit = { type = 1901 } },
    [2598] = { name = "Clavius", outfit = { type = 1902 } },
    [2602] = { name = "Michael the Stalwart", outfit = { type = 1900, head = 94, body = 31, legs = 19, feet = 38, addons = 3 } },
    [2603] = { name = "Overseer Osverger", outfit = { type = 1902 } },
    [50010] = { name = "Ancient Lion Knight", outfit = { type = 1071, head = 57, body = 78, legs = 76, feet = 76, addons = 1 } },
    [50011] = { name = "The Flaming Orchid", outfit = { type = 150, head = 114, body = 94, legs = 78, feet = 79, addons = 1 } },
}

function Cyclopedia.getBossRaceData(raceId)
    return Cyclopedia.BossRaceOverrides[raceId] or g_things.getRaceData(raceId)
end


local function setBestiaryDiscoveryHighlight(enabled)
    if not CyclopediaButton then
        return
    end

    local highlight = CyclopediaButton:getChildById('highlight')
    if highlight then
        highlight:setVisible(enabled)
    end
end

local function setBosstiaryDiscoveryHighlight(enabled)
    if not ButtonBestiary then
        return
    end
    local highlight = ButtonBestiary:getChildById('highlight')
    if highlight then
        highlight:setVisible(enabled)
    end
end

function Cyclopedia.openDiscoveredBoss(raceId)
    raceId = tonumber(raceId)
    if not raceId then
        return
    end
    pendingBosstiaryDiscoveryRaceId = nil
    setBosstiaryDiscoveryHighlight(false)
    Cyclopedia.pendingBosstiaryRaceId = raceId
    local alreadyOpen = controllerCyclopedia.ui and controllerCyclopedia.ui:isVisible() and previousType == 'bosstiary'
    Cyclopedia.openTab('bosstiary')
    if alreadyOpen then
        g_game.requestBosstiaryInfo()
    end
end

function Cyclopedia.onBosstiaryButtonClick()
    if pendingBosstiaryDiscoveryRaceId then
        Cyclopedia.openDiscoveredBoss(pendingBosstiaryDiscoveryRaceId)
        return
    end
    toggle('bosstiary')
end

function Cyclopedia.onBosstiaryDiscovery(_, _, buffer)
    local idText, bossName = tostring(buffer):match('^(%d+)|(.+)$')
    local raceId = tonumber(idText or buffer)
    if not raceId or raceId <= 0 then
        g_logger.warning('[Cyclopedia] Invalid Bosstiary discovery payload: ' .. tostring(buffer))
        return
    end
    local raceData = Cyclopedia.getBossRaceData(raceId)
    bossName = raceData and raceData.name or bossName or tr('Unknown Boss')
    pendingBosstiaryDiscoveryRaceId = raceId
    setBosstiaryDiscoveryHighlight(true)
    local notifications = modules.game_notifications and modules.game_notifications.notificationsController
    if notifications then
        notifications:show(
            tr('New Bosstiary'),
            tr("You have defeated '%s' for the first time.", bossName),
            '/game_notifications/assets/images/nodo/icon-infobanner-unlock',
            5000,
            { raceId = raceId, bosstiaryRaceId = raceId }
        )
    end
end

function Cyclopedia.onMainButtonClick()
    local raceId = pendingBestiaryDiscoveryRaceId
    if raceId then
        pendingBestiaryDiscoveryRaceId = nil
        setBestiaryDiscoveryHighlight(false)
        Cyclopedia.openTrackedCreature(0, raceId)
        return
    end

    toggle("items")
end

function Cyclopedia.onBestiaryDiscovery(_, _, buffer)
    local raceId = tonumber(buffer)
    if not raceId or raceId <= 0 then
        g_logger.warning('[Cyclopedia] Invalid Bestiary discovery payload: ' .. tostring(buffer))
        return
    end

    pendingBestiaryDiscoveryRaceId = raceId
    setBestiaryDiscoveryHighlight(true)

    local raceData = g_things.getRaceData(raceId)
    local monsterName = raceData and raceData.name or tr('Unknown Creature')
    local notifications = modules.game_notifications and modules.game_notifications.notificationsController
    if notifications then
        notifications:show(
            tr('New Bestiary'),
            tr("You have discovered '%s'.", monsterName),
            '/game_notifications/assets/images/nodo/icon-infobanner-unlock',
            4200,
            { raceId = raceId }
        )
    end
end

function Cyclopedia.onEchoWardenProgress(_, _, buffer)
    local ok, data = pcall(json.decode, buffer)
    if not ok or type(data) ~= "table" or not tonumber(data.raceId) then
        g_logger.warning('[Cyclopedia] Invalid Echo Warden payload: ' .. tostring(buffer))
        return
    end

    data.raceId = tonumber(data.raceId)
    data.charmPoints = tonumber(data.charmPoints) or 0
    data.completed = data.completed == true
    Cyclopedia.EchoWardenProgress[data.raceId] = data

    if Cyclopedia.updateEchoWardenProgress then
        Cyclopedia.updateEchoWardenProgress(data)
    end
end

function toggle(defaultWindow)
    if not controllerCyclopedia.ui then
        return
    end
    if controllerCyclopedia.ui:isVisible() then
        return hide()
    end
    show(defaultWindow)
end

controllerCyclopedia = Controller:new()
controllerCyclopedia:setUI('game_cyclopedia')

function controllerCyclopedia:onInit()
    -- pre m_gameInitialized
    self:registerEvents(g_game, {
        onParseCyclopediaTracker = function(trackerType, data)
            if Cyclopedia.onParseCyclopediaTracker then
                Cyclopedia.onParseCyclopediaTracker(trackerType, data)
            end
        end
    })
    self:registerExtendedOpcode(BESTIARY_DISCOVERY_OPCODE, Cyclopedia.onBestiaryDiscovery)
    self:registerExtendedOpcode(BOSSTIARY_DISCOVERY_OPCODE, Cyclopedia.onBosstiaryDiscovery)
    self:registerExtendedOpcode(ECHO_WARDEN_PROGRESS_OPCODE, Cyclopedia.onEchoWardenProgress)
end

function controllerCyclopedia:onGameStart()
    local versionClient = g_game.getClientVersion()
    if versionClient < 1310 then
        controllerCyclopedia:scheduleEvent(function()
            g_modules.getModule("game_cyclopedia"):unload()
        end, 100, "unloadModule")
        return
    else
        CyclopediaButton = modules.game_mainpanel.addToggleButton('CyclopediaButton', tr('Cyclopedia'),
            '/images/options/cooldowns', Cyclopedia.onMainButtonClick, false, 7)
        ButtonBossSlot = modules.game_mainpanel.addToggleButton("bossSlot", tr("Open Boss Slots dialog"),
            "/images/options/ButtonBossSlot", function() toggle("bossSlot") end, false, 20)
        CyclopediaButton:setOn(false)
        ButtonBestiary = modules.game_mainpanel.addToggleButton("bosstiary", tr("Open Bosstiary dialog"),
            "/images/options/ButtonBosstiary", Cyclopedia.onBosstiaryButtonClick, false, 17)

        contentContainer = controllerCyclopedia.ui:recursiveGetChildById('contentContainer')
        buttonSelection = controllerCyclopedia.ui:recursiveGetChildById('buttonSelection')
        buttonSelection.onGeometryChange = Cyclopedia.layoutTabs
        items = buttonSelection:recursiveGetChildById('items')
        bestiary = buttonSelection:recursiveGetChildById('bestiary')
        charms = buttonSelection:recursiveGetChildById('charms')
        map = buttonSelection:recursiveGetChildById('map')
        houses = buttonSelection:recursiveGetChildById('houses')
        houses:setVisible(houseAuctionsEnabled)
        character = buttonSelection:recursiveGetChildById('character')
        bosstiary = buttonSelection:recursiveGetChildById('bosstiary')
        bossSlot = buttonSelection:recursiveGetChildById('bossSlot')
        magicalArchives = buttonSelection:recursiveGetChildById('magicalArchives')

        windowTypes = {
            items = { obj = items, func = showItems },
            bestiary = { obj = bestiary, func = showBestiary },
            charms = { obj = charms, func = showCharms },
            map = { obj = map, func = showMap },
            houses = houseAuctionsEnabled and { obj = houses, func = showHouse } or nil,
            character = { obj = character, func = showCharacter },
            bosstiary = { obj = bosstiary, func = showBosstiary },
            bossSlot = { obj = bossSlot, func = showBossSlot },
            magicalArchives = { obj = magicalArchives, func = showMagicalArchives },
            codex = { obj = buttonSelection:getChildById('codex'), func = function(parent) showCustomPanel(parent, 'codex') end },
            tasks = { obj = buttonSelection:getChildById('tasks'), func = function(parent) showCustomPanel(parent, 'tasks') end },
        }

        g_ui.importStyle("cyclopedia_widgets")
        g_ui.importStyle("cyclopedia_pages")

        controllerCyclopedia:registerEvents(g_game, {
            onResourcesBalanceChange = Cyclopedia.onResourcesBalanceChange,
            -- bestiary
            onParseBestiaryRaces = Cyclopedia.loadBestiaryCategories,
            onParseBestiaryOverview = Cyclopedia.loadBestiaryOverview,
            onUpdateBestiaryMonsterData = Cyclopedia.loadBestiarySelectedCreature,
            -- bosstiary
            onParseSendBosstiary = Cyclopedia.LoadBosstiaryCreatures,
            -- boss_slot
            onParseBosstiarySlots = Cyclopedia.loadBossSlots,
            -- character
            onParseCyclopediaCharacterGeneralStats = Cyclopedia.loadCharacterGeneralStats,
            onParseCyclopediaCharacterCombatStats = Cyclopedia.loadCharacterCombatStats,
            onParseCyclopediaCharacterBadges = Cyclopedia.loadCharacterBadges,
            onCyclopediaCharacterRecentDeaths = Cyclopedia.loadCharacterRecentDeaths,
            onCyclopediaCharacterRecentKills = Cyclopedia.loadCharacterRecentKills,
            onUpdateCyclopediaCharacterItemSummary = Cyclopedia.loadCharacterItems,
            onParseCyclopediaCharacterAppearances = Cyclopedia.loadCharacterAppearances,
            onParseCyclopediaStoreSummary = Cyclopedia.onParseCyclopediaStoreSummary,
            -- House auction callbacks remain implemented but disconnected
            -- while the feature is parked in favour of !buyhouse.
            onCyclopediaHouseAuctionMessage = houseAuctionsEnabled and Cyclopedia.houseMessage or nil,
            onCyclopediaHouseList = houseAuctionsEnabled and Cyclopedia.loadHouseList or nil,
            -- character 14.10
            onCyclopediaCharacterOffenceStats = Cyclopedia.onCyclopediaCharacterOffenceStats,
            onCyclopediaCharacterDefenceStats = Cyclopedia.onCyclopediaCharacterDefenceStats,
            onCyclopediaCharacterMiscStats = Cyclopedia.onCyclopediaCharacterMiscStats,


            -- charms
            onUpdateBestiaryCharmsData = Cyclopedia.loadCharms,
            -- items
            onParseItemDetail = Cyclopedia.loadItemDetail
        })

        --[[===================================================
    =               Tracker Bestiary                      =
    =================================================== ]] --

        -- Only create if it doesn't exist
        if not trackerButton then
            trackerButton = modules.game_mainpanel.addToggleButton("trackerButton", tr("Bestiary Tracker"),
                "/images/options/bestiaryTracker", Cyclopedia.toggleBestiaryTracker, false, 17)
        end
        
        trackerButton:setOn(false)
        
        -- Only create if it doesn't exist
        if not trackerMiniWindow then
            trackerMiniWindow = g_ui.createWidget('BestiaryTracker', modules.game_interface.getRightPanel())

            -- Set the title with length limit like in containers
            local titleWidget = trackerMiniWindow:getChildById('miniwindowTitle')
            if titleWidget then
                local title = tr('Bestiary Tracker')
                if title:len() > 12 then
                    title = title:sub(1, 12) .. "..."
                end
                titleWidget:setText(title)
            end

            -- Set up contextMenuButton positioning and click handler
            local contextMenuButton = trackerMiniWindow:recursiveGetChildById('contextMenuButton')
            local newWindowButton = trackerMiniWindow:recursiveGetChildById('newWindowButton')
            local minimizeButton = trackerMiniWindow:recursiveGetChildById('minimizeButton')
            
            if contextMenuButton then
                contextMenuButton:setVisible(true)
                
                -- Position contextMenuButton like in ImbuementTracker
                if minimizeButton then
                    contextMenuButton:breakAnchors()
                    contextMenuButton:addAnchor(AnchorTop, minimizeButton:getId(), AnchorTop)
                    contextMenuButton:addAnchor(AnchorRight, minimizeButton:getId(), AnchorLeft)
                    contextMenuButton:setMarginRight(7)
                    contextMenuButton:setMarginTop(0)
                end
                
                contextMenuButton.onClick = function(widget, mousePos, mouseButton)
                    return Cyclopedia.createTrackerContextMenu("bestiary", mousePos)
                end
            end

            if newWindowButton then
                newWindowButton:setVisible(true)
                newWindowButton.onClick = function(widget, mousePos, mouseButton)
                    toggle("bestiary")
                    return true
                end
            end

            trackerMiniWindow.onOpen = function()
                trackerButton:setOn(true)
                Cyclopedia.refreshBestiaryTracker()
            end

            trackerMiniWindow.onClose = function()
                trackerButton:setOn(false)
            end

            trackerMiniWindow:setup()
            trackerMiniWindow:hide()
        end

        --[[===================================================
    =               Tracker Bosstiary                     =
    =================================================== ]] --

        -- Only create if it doesn't exist
        if not trackerButtonBosstiary then
            trackerButtonBosstiary = modules.game_mainpanel.addToggleButton("bosstiarytrackerButton",
                tr("Bosstiary Tracker"), "/images/options/bosstiaryTracker", Cyclopedia.toggleBosstiaryTracker, false, 17)
        end
        
        trackerButtonBosstiary:setOn(false)
        
        -- Only create if it doesn't exist
        if not trackerMiniWindowBosstiary then
            trackerMiniWindowBosstiary = g_ui.createWidget('BestiaryTracker', modules.game_interface.getRightPanel())
            
            -- Set the title with length limit like in containers
            local titleWidgetBosstiary = trackerMiniWindowBosstiary:getChildById('miniwindowTitle')
            if titleWidgetBosstiary then
                local title = tr('Bosstiary Tracker')
                if title:len() > 12 then
                    title = title:sub(1, 12) .. "..."
                end
                titleWidgetBosstiary:setText(title)
            end

            -- Set the icon for Bosstiary Tracker
            local iconWidgetBosstiary = trackerMiniWindowBosstiary:getChildById('miniwindowIcon')
            if iconWidgetBosstiary then
                iconWidgetBosstiary:setImageSource('/images/icons/icon-bosstracker-widget')
            end

            -- Set up contextMenuButton positioning and click handler for Bosstiary
            local contextMenuButtonBosstiary = trackerMiniWindowBosstiary:recursiveGetChildById('contextMenuButton')
            local newWindowButtonBosstiary = trackerMiniWindowBosstiary:recursiveGetChildById('newWindowButton')
            local minimizeButtonBosstiary = trackerMiniWindowBosstiary:recursiveGetChildById('minimizeButton')
            
            if contextMenuButtonBosstiary then
                contextMenuButtonBosstiary:setVisible(true)
                
                -- Position contextMenuButton like in ImbuementTracker
                if minimizeButtonBosstiary then
                    contextMenuButtonBosstiary:breakAnchors()
                    contextMenuButtonBosstiary:addAnchor(AnchorTop, minimizeButtonBosstiary:getId(), AnchorTop)
                    contextMenuButtonBosstiary:addAnchor(AnchorRight, minimizeButtonBosstiary:getId(), AnchorLeft)
                    contextMenuButtonBosstiary:setMarginRight(7)
                    contextMenuButtonBosstiary:setMarginTop(0)
                end
                
                contextMenuButtonBosstiary.onClick = function(widget, mousePos, mouseButton)
                    return Cyclopedia.createTrackerContextMenu("bosstiary", mousePos)
                end
            end

            if newWindowButtonBosstiary then
                newWindowButtonBosstiary:setVisible(true)
                newWindowButtonBosstiary.onClick = function(widget, mousePos, mouseButton)
                    toggle("bosstiary")
                    return true
                end
            end

            trackerMiniWindowBosstiary.onOpen = function()
                trackerButtonBosstiary:setOn(true)
                if not Cyclopedia.BosstiaryTrackerPending then
                    if trackerMiniWindowBosstiary.contentsPanel then
                        trackerMiniWindowBosstiary.contentsPanel:destroyChildren()
                    end
                    Cyclopedia.refreshBosstiaryTracker()
                end
                Cyclopedia.scheduleBosstiaryTrackerRetry(1000)
            end

            trackerMiniWindowBosstiary.onClose = function()
                trackerButtonBosstiary:setOn(false)
            end

            trackerMiniWindowBosstiary:setup()
            trackerMiniWindowBosstiary:hide()
        end
        trackerMiniWindow:setupOnStart()
        trackerMiniWindowBosstiary:setupOnStart()
        Cyclopedia.loadTrackerFilters("bestiary")
        Cyclopedia.loadTrackerFilters("bosstiary")

        if trackerMiniWindow:isVisible() then
            trackerButton:setOn(true)
        end
        if trackerMiniWindowBosstiary:isVisible() then
            trackerButtonBosstiary:setOn(true)
        end
        
        Cyclopedia.BossSlots.UnlockBosses = {}
        Keybind.new("Windows", "Show/hide Bosstiary Tracker", "", "")

        Keybind.bind("Windows", "Show/hide Bosstiary Tracker", {{
            type = KEY_DOWN,
            callback = Cyclopedia.toggleBosstiaryTracker
        }})

        Keybind.new("Windows", "Show/hide Bestiary Tracker", "", "")
        Keybind.bind("Windows", "Show/hide Bestiary Tracker", {{
            type = KEY_DOWN,
            callback = Cyclopedia.toggleBestiaryTracker
        }})
    end
    if versionClient >= 1410 then
        controllerCyclopedia.ui.CharmsBase.Icon:setImageSource("/game_cyclopedia/images/monster-icon-bonuspoints")
    end
end


function controllerCyclopedia:onGameEnd()
    pendingBestiaryDiscoveryRaceId = nil
    pendingBosstiaryDiscoveryRaceId = nil
    Cyclopedia.pendingBosstiaryRaceId = nil
    setBestiaryDiscoveryHighlight(false)
    setBosstiaryDiscoveryHighlight(false)
    hide()
    
    if Cyclopedia.saveTrackerFilters then
        Cyclopedia.saveTrackerFilters("bestiary")
        Cyclopedia.saveTrackerFilters("bosstiary")
    end

    if Cyclopedia.clearTrackerDataForCharacterChange then
        Cyclopedia.clearTrackerDataForCharacterChange()
    end

    Keybind.delete("Windows", "Show/hide Bosstiary Tracker")
    Keybind.delete("Windows", "Show/hide Bestiary Tracker")
end

function controllerCyclopedia:onTerminate()
    hide()
    if trackerButton then
        trackerButton:destroy()
        trackerButton = nil
    end

    if trackerMiniWindow then
        trackerMiniWindow:destroy()
        trackerMiniWindow = nil
    end

    if trackerButtonBosstiary then
        trackerButtonBosstiary:destroy()
        trackerButtonBosstiary = nil
    end

    if trackerMiniWindowBosstiary then
        trackerMiniWindowBosstiary:destroy()
        trackerMiniWindowBosstiary = nil
    end

    if CyclopediaButton then
        CyclopediaButton:destroy()
        CyclopediaButton = nil
    end
    if ButtonBossSlot then
        ButtonBossSlot:destroy()
        ButtonBossSlot = nil
    end
    if ButtonBestiary then
        ButtonBestiary:destroy()
        ButtonBestiary = nil
    end
    
    -- Save items data if available
    if Cyclopedia and Cyclopedia.Items and Cyclopedia.Items.terminate then
        Cyclopedia.Items.terminate()
    end
    
    onTerminateCharm()
end

function hide()
    if not controllerCyclopedia.ui then
        return
    end
    resetCyclopediaTabs()
    if modules.game_progress and modules.game_progress.setCyclopediaTab then
        modules.game_progress.setCyclopediaTab(nil)
    end
    controllerCyclopedia.ui:hide()
    if CyclopediaButton then
        CyclopediaButton:setOn(false)
    end
    if ButtonBossSlot then
        ButtonBossSlot:setOn(false)
    end
    if ButtonBestiary then
        ButtonBestiary:setOn(false)
    end
end

function resetCyclopediaTabs()
    releaseCustomPanel()
    tabStack = {}
    controllerCyclopedia.ui.BackButton:setEnabled(false)
    if previousType then
        local previousWindow = windowTypes[previousType]
        previousWindow.obj:enable()
        previousWindow.obj:setOn(false)
        previousType = nil;
    end
end

function show(defaultWindow)
    if not controllerCyclopedia.ui then
        return
    end

    controllerCyclopedia.ui:show()
    controllerCyclopedia.ui:raise()
    controllerCyclopedia.ui:focus()
    SelectWindow(defaultWindow, false)
    controllerCyclopedia.ui.GoldBase.Value:setText(Cyclopedia.formatGold(g_game.getLocalPlayer():getTotalMoney()))
end

function Cyclopedia.openTab(tabName)
    if not controllerCyclopedia.ui then
        return false
    end

    if not controllerCyclopedia.ui:isVisible() then
        show(tabName)
        return true
    end

    if previousType ~= tabName then
        SelectWindow(tabName, false)
    end

    return true
end

function Cyclopedia.getCurrentTab()
    return previousType
end

function toggleBack()
    local previousTab = table.remove(tabStack, #tabStack)
    if #tabStack < 1 then
        controllerCyclopedia.ui.BackButton:setEnabled(false)
    end
    SelectWindow(previousTab, true)
end

-- Match the RubinOT reference: compact inactive icons, a fixed-width active
-- page and an unused trailing area. Parked pages do not reserve a tab cell.
function Cyclopedia.layoutTabs()
    if not buttonSelection then return end
    local order = { 'items', 'bestiary', 'charms', 'map', 'houses', 'character',
        'bosstiary', 'bossSlot', 'magicalArchives', 'codex', 'tasks' }
    local visible = {}
    for _, id in ipairs(order) do
        local tab = buttonSelection:getChildById(id)
        if tab and tab:isExplicitlyVisible() then visible[#visible + 1] = tab end
    end
    local activeWidth = 200
    local offset = 1
    for _, tab in ipairs(visible) do
        tab:breakAnchors()
        tab:addAnchor(AnchorLeft, 'parent', AnchorLeft)
        tab:addAnchor(AnchorTop, 'parent', AnchorTop)
        tab:setMarginLeft(offset)
        tab:setMarginTop(1)
        tab:setWidth(tab:isOn() and activeWidth or 34)
        offset = offset + tab:getWidth() + 1
    end
end

function SelectWindow(type, isBackButtonPress)
    if not windowTypes[type] then return end
    releaseCustomPanel()
    if previousType then
        local previousWindow = windowTypes[previousType]
        previousWindow.obj:enable()
        previousWindow.obj:setOn(false)
        if not isBackButtonPress then
            table.insert(tabStack, previousType)
            controllerCyclopedia.ui.BackButton:setEnabled(true)
        end
    end
    contentContainer:destroyChildren()
    -- Custom pages have the same working area as the existing Adventures hub.
    -- Leave the regular Cyclopedia pages at their original dimensions.
    if modules.game_progress and modules.game_progress.setCyclopediaTab then
        modules.game_progress.setCyclopediaTab(type)
    end
    local custom = customModules[type] ~= nil
    controllerCyclopedia.ui:setSize(custom and { width = 900, height = 610 } or { width = 700, height = 560 })
    contentContainer:setMarginBottom(custom and 52 or 0)
    if custom then
        controllerCyclopedia.ui.GoldBase:show()
        controllerCyclopedia.ui.CharmsBase:hide()
        controllerCyclopedia.ui.CharmsBase1410:hide()
        controllerCyclopedia.ui.BestiaryTrackerButton:hide()
    end

    local window = windowTypes[type]
    if window then
        window.obj:setOn(true)
        window.obj:disable()
        previousType = type
        if window.func then
            window.func(contentContainer)
        end
    end
    Cyclopedia.layoutTabs()
    if CyclopediaButton then
        CyclopediaButton:setOn(type == "items" or type == "charms" or type == "map" or type == "houses" or type == "character" or type == "magicalArchives" or custom)
    end
    if ButtonBossSlot then
        ButtonBossSlot:setOn(type == "bossSlot")
    end
    if ButtonBestiary then
        ButtonBestiary:setOn(type == "bosstiary" or type == "bestiary")
    end
end

function Cyclopedia.onResourcesBalanceChange()
    if not controllerCyclopedia.ui or not controllerCyclopedia.ui:isVisible() then
        return
    end

    local player = g_game.getLocalPlayer()
    if not player then
        return
    end

    controllerCyclopedia.ui.GoldBase.Value:setText(Cyclopedia.formatGold(player:getTotalMoney()))

    local formatResourceBalance = function(resourceType, maxResourceType)
        return string.format("%d/%d", player:getResourceBalance(resourceType),
            player:getResourceBalance(maxResourceType))
    end

    controllerCyclopedia.ui.CharmsBase.Value:setText(formatResourceBalance(ResourceTypes.CHARM,
        ResourceTypes.MAX_CHARM))

    if controllerCyclopedia.ui.CharmsBase1410:isVisible() then
        controllerCyclopedia.ui.CharmsBase1410.Value:setText(formatResourceBalance(
            ResourceTypes.MINOR_CHARM, ResourceTypes.MAX_MINOR_CHARM))
    end
end

function isVisible()
    return controllerCyclopedia and controllerCyclopedia.ui and controllerCyclopedia.ui:isVisible()
end
