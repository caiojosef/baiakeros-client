rewardWallController = Controller:new()
-- /*=============================================
-- =            To-do                  =
-- =============================================*/
-- - Keep the reward wall on the native anchored layout used by the client.
-- - Improve Ids footerGold2 , footerGold1, "test", "displayGeneralBox3"

local ServerPackets = {
    ShowDialog = 0xED,
    DailyRewardCollectionState = 0xDE,
    OpenRewardWall = 0xE2,
    CloseRewardWall = 0xE3,
    DailyRewardBasic = 0xE4,
    DailyRewardHistory = 0xE5
    -- RestingAreaState = 0xA9
}

local ClientPackets = {
    OpenRewardWall = 0xD8,
    OpenRewardHistory = 0xD9,
    SelectReward = 0xDA,
    CollectionResource = 0x14,
    JokerResource = 0x15
}

-- @ widget
local ButtonRewardWall = nil
local windowsPickWindow = nil
local generalBox = nil
-- @ array
local bonuses = {}
local actualUsed = {}
-- @ variable
local bonusShrine = 0
local rewardClockEvent
local rewardDeadline = 0
local rewardClaimed = false
local rewardRefreshRequested = false
local rewardStreak = 0
-- @ const
local COLORS = {
    BASE_1 = "#484848",
    BASE_2 = "#414141"
}
local ZONE = {
    LAST_ZONE = -99,
    RESTING_AREA_ZONE = 1,
    ICON_ID = "condition_Rewards",
    NUMERIC_ICON_ID = 30
}

local bundleType = {
    ITEMS = 1,
    PREY = 2,
    XPBOOST = 3
}

local STATUS = {
    COLLECTED = 1,
    ACTIVE = 2,
    LOCKED = 3
}

local OPEN_WINDOWS = {
    BUTTON_WIDGET = 0,
    SHRINE = 1 -- itemClientId = 25802
}

local DailyRewardStatus = { -- sendDailyRewardCollectionState 0xDE ?
    DAILY_REWARD_COLLECTED = 0,
    DAILY_REWARD_NOTCOLLECTED = 1,
    DAILY_REWARD_NOTAVAILABLE = 2
}

local CONST_WINDOWS_BOX = {
    ALREADY = 1,
    RELEASE = 2,
    CONFIRMATION_IRA = 3, -- IRA = Instant Reward Access
    NO_IRA = 4
}

local BOX_CONFIGS = {
    [CONST_WINDOWS_BOX.ALREADY] = {
        title = "Warning",
        content = "Sorry, you have already taken your daily reward or you are unable to collect it"
    },
    [CONST_WINDOWS_BOX.CONFIRMATION_IRA] = {
        title = "Confirmation of using Instant Reward Access",
        content = "Remember! You can always collect your daily reward for free by visiting a reward shrine!\n\nYou Currently own 3x Instant Reward Access. Do you really want to use one to claim your daily reward now?",
        okCallback = function()
            -- Canary expects 0 = shrine / 1 = panel (inverse of the OpenRewardWall byte
            -- stored in bonusShrine, where 1 = shrine / 0 = panel)
            g_game.requestGetRewardDaily(bonusShrine == OPEN_WINDOWS.SHRINE and 0 or 1, actualUsed)
            if windowsPickWindow then
                windowsPickWindow:destroy()
                windowsPickWindow = nil
            end
            if generalBox then
                generalBox:destroy()
                generalBox = nil
            end
            show()
        end
    },
    [CONST_WINDOWS_BOX.NO_IRA] = {
        title = "Warning: No Sufficient Instant Reward Access",
        content = "Remember! you can always collect your daily reward for free by visiting a reward shrine!\nyou do not have an Instant Reward Access.\nVisit the store to buy more!"
    }
}

-- /*=============================================
-- =            Local function                  =
-- =============================================*/
local function destroyWindows(windows)
    if type(windows) == "table" then
        for _, window in pairs(windows) do
            if window and not window:isDestroyed() then
                window:destroy()
            end
        end
    else
        if windows and not windows:isDestroyed() then
            windows:destroy()
        end
    end
    return nil
end

local function premiumStatusWindwos(isPremium)
    rewardWallController.ui.premiumStatus.premiumMessage:setText(isPremium and
                                                                     "Great! You benefit from the best possible rewards and bonuses due to your premium status." or
                                                                     "With a Premium account, you would benefit from even better rewards and bonuses.")
    rewardWallController.ui.premiumStatus.premiumButton:setOn(not isPremium)
    rewardWallController.ui.infoPanel.free:setColor(isPremium and "#909090" or "#FFFFFF")
    rewardWallController.ui.infoPanel.premium:setColor(isPremium and "#FFFFFF" or "#909090")
    for i, widget in ipairs(rewardWallController.ui.restingAreaPanel.bonusIcons:getChildren()) do
        local requiredDays = bonuses[i] and bonuses[i].id or i + 1
        local unlocked = rewardStreak >= requiredDays and (isPremium or requiredDays <= 3)
        widget:setOn(unlocked)
        widget:setOpacity(unlocked and 1 or 0.5)
    end
end

local function convert_timestamp(timestamp)
    return os.date("%Y-%m-%d, %H:%M:%S", timestamp)
end

local function getBonusStrings(bonuses)
    local result = {}
    for _, bonus in ipairs(bonuses) do
        table.insert(result, bonus["name"])
    end
    return table.concat(result, ", ")
end

local function visibleHistory(visible)
    local ui = rewardWallController.ui
    ui.historyPanel:setVisible(visible)
    for _, id in ipairs({'restingAreaPanel', 'dailyRewardsPanel', 'premiumStatus', 'infoPanel'}) do
        ui[id]:setVisible(not visible)
    end
end

local function clearRewardInfo()
    local info = rewardWallController.ui.infoPanel
    info.message:setText('')
    info.free:setText('')
    info.premium:setText('')
end

local function showRewardMessage(text, colored)
    clearRewardInfo()
    local message = rewardWallController.ui.infoPanel.message
    if colored then
        message:parseColoredText(text)
    else
        message:setText(text or '')
    end
end

local function updateDailyRewards(dayStreakDay, wasDailyRewardTaken, claimCost)
    local panel = rewardWallController.ui.dailyRewardsPanel
    local taken = wasDailyRewardTaken ~= 0
    local collected = taken and dayStreakDay == 0 and 7 or dayStreakDay
    for i = 1, 7 do
        local day = panel:getChildById('reward' .. i)
        local button = day:getChildById('rewardButton' .. i)
        local status = day:getChildById('rewardGold' .. i)
        status:destroyChildren()
        local complete = i <= collected
        local available = not taken and i == collected + 1
        status.status = complete and STATUS.COLLECTED or available and STATUS.ACTIVE or STATUS.LOCKED
        button:setOn(not available)
        button.ditherpattern:setVisible(not available)
        if available then
            local price = g_ui.createWidget('GoldLabel2', status)
            price:fill('parent')
            price:setPhantom(true)
            price.text:setText(claimCost)
            local player = g_game.getLocalPlayer()
            local balance = player and player:getResourceBalance(ResourceTypes.DAILYREWARD_STREAK) or 0
            price.text:setColor(claimCost <= balance and 'white' or 'red')
            price.gold:setImageSource('/game_rewardwall/images/instant-reward-access-icon')
        else
            local badge = g_ui.createWidget('RewardButton', status)
            badge:setOn(complete)
            badge:fill('parent')
            badge:setPhantom(true)
        end
        local arrow = panel:getChildById('arrow' .. i)
        if arrow then arrow:setImageClip(complete and '5 0 5 7' or '0 0 5 7') end
    end
end

local function getDayStreakIcon(dayStreakLevel)
    local IconConsecutiveDays = {
        [24] = "icon-rewardstreak-default",
        [49] = "icon-rewardstreak-bronze",
        [99] = "icon-rewardstreak-silver",
        [100] = "icon-rewardstreak-gold"
    }
    if dayStreakLevel <= 24 then
        return IconConsecutiveDays[24]
    elseif dayStreakLevel <= 49 then
        return IconConsecutiveDays[49]
    elseif dayStreakLevel <= 99 then
        return IconConsecutiveDays[99]
    else
        return IconConsecutiveDays[100]
    end
end

local function getBonusDescription(bonusName, streakCount, activeBonuses)
    local isPremium = g_game.getLocalPlayer():isPremium()

    return string.format(
        "Allow [color=#909090]%s[/color]%s\nThis bonus is active because you are [color=%s]Premium[/color] and reached a reward streak of at least [color=#44AD25]%d[/color].%s",
        bonusName, isPremium and "" or "[color=#ff0000](Locked)[/color]", isPremium and "#44AD25" or "#ff0000",
        streakCount, isPremium and ("\n\nActive bonuses: [color=#909090]%s[/color]."):format(activeBonuses) or "")
end

local function checkRewards(data)
    local premium = g_game.getLocalPlayer():isPremium()
    local rewardType = premium and data.premiumRewards or data.freeRewards
    local altType = premium and data.freeRewards or data.premiumRewards

    for index = 1, #rewardType do
        local reward = rewardType[index]
        local altReward = altType[index]

        local hasSelectableItems = reward.selectableItems and next(reward.selectableItems) ~= nil
        local rewardButton = rewardWallController.ui.dailyRewardsPanel:getChildById("reward" .. index):getChildById(
            "rewardButton" .. index)
        local iconWidget = rewardWallController.ui.dailyRewardsPanel:getChildById("reward" .. index):getChildByIndex(1)

        if hasSelectableItems then
            iconWidget:setIcon("game_rewardwall/images/icon-reward-pickitems")
            rewardButton.bundleType = bundleType.ITEMS
            rewardButton.rewardItem = reward.selectableItems
            rewardButton.itemsToSelect = {reward.itemsToSelect or 0, altReward and altReward.itemsToSelect or 0}
        elseif reward.bundleItems[1] and reward.bundleItems[1].bundleType == bundleType.XPBOOST then
            iconWidget:setIcon("game_rewardwall/images/icon-reward-xpboost")
            rewardButton.bundleType = bundleType.XPBOOST
            rewardButton.itemsToSelect = {reward.bundleItems[1].itemId or 0,
                                          altReward and altReward.bundleItems[1].itemId or 0}
        else
            iconWidget:setIcon("game_rewardwall/images/icon-reward-fixeditems")
            rewardButton.bundleType = bundleType.PREY
            rewardButton.itemsToSelect = {reward.bundleItems[1].count or 0,
                                          altReward and altReward.bundleItems[1].count or 0}
        end
    end
end
-- /*=============================================
-- =            onParse                  =
-- =============================================*/
--[[
--  0xDE ??
local function onDailyRewardCollectionState(state)
    if not rewardWallController.ui:isVisible() then
        return
    end

    local text = {
        [DailyRewardStatus.DAILY_REWARD_COLLECTED] = "you did not claim your daily reward in time. too bad, you do not have enough Daily Reward Jokers.",
        [DailyRewardStatus.DAILY_REWARD_NOTCOLLECTED] = "You did not claim your daily reward in time. If you don't claim your reward now, your [color=#D33C3C]streak will be reset.[/color]",
        [DailyRewardStatus.DAILY_REWARD_NOTAVAILABLE] ="idk",
    }
    rewardWallController.ui.restingAreaPanel.streakWarning:parseColoredText(text[state],"#c0c0c0")
end 
]]

local function onRestingAreaState(zone, state, message)
    if ZONE.LAST_ZONE == zone then -- todo move cpp
        return
    end
    ZONE.LAST_ZONE = zone
    local gameInterface = modules.game_interface
    if zone == ZONE.RESTING_AREA_ZONE then
        gameInterface.processIcon(ZONE.NUMERIC_ICON_ID, function(icon)
            icon:setTooltip(message)
        end, true)
    else
        gameInterface.processIcon(ZONE.ICON_ID, function(icon)
            icon:destroy()
        end)
    end
end

local function onDailyReward(data)
    bonuses = data.bonuses
    checkRewards(data)
end

local function onServerError(code, error)
    generalBox = destroyWindows(generalBox)
    local cancelCallback = function()
        generalBox = destroyWindows(generalBox)
        rewardWallController.ui:show()
        rewardWallController.ui:raise()
        rewardWallController.ui:focus()
    end

    local standardButtons = {{
        text = "ok",
        callback = cancelCallback
    }}

    generalBox = displayGeneralBox3(rewardWallController.ui:getText(), error, standardButtons)
end

local function connectOnServerError()
    connect(g_game, {
        onServerError = onServerError
    })
end

local function disconnectOnServerError()
    disconnect(g_game, {
        onServerError = onServerError
    })
end

local function stopRewardClock()
    if rewardClockEvent then removeEvent(rewardClockEvent); rewardClockEvent = nil end
end

local function updateRewardClock()
    stopRewardClock()
    local ui = rewardWallController.ui
    if not ui then return end
    local remaining = math.max(0, rewardDeadline - os.time())
    local clock = ui.restingAreaPanel.restingAreaInfo.timeLeft
    if remaining <= 0 then
        clock:setText('Expired')
    elseif remaining < 60 then
        clock:setText('< 1 min')
    else
        clock:setText(string.format('%02d:%02d', math.floor(remaining / 3600), math.floor(remaining % 3600 / 60)))
    end
    clock:setPercent(math.min(100, remaining / 86400 * 100))
    local warning = ui.restingAreaPanel.streakWarning
    if rewardClaimed and remaining > 0 then
        warning:setText('You have claimed your daily reward.\nYour next reward will be available after server save.')
    elseif remaining > 0 then
        warning:parseColoredText("Claim your daily reward before server save.\nIf you don't claim your reward now, [color=#D33C3C]your streak will be reset.[/color]", '#c0c0c0')
    else
        warning:setText('Claim your daily reward to start a new streak.')
    end
    if ui:isVisible() then
        if remaining <= 0 and not rewardRefreshRequested and g_game.isOnline() then
            rewardRefreshRequested = true
            g_game.sendOpenRewardWall()
        end
        rewardClockEvent = scheduleEvent(updateRewardClock, 1000)
    end
end

local function onOpenRewardWall(bonusShrines, nextRewardTime, dayStreakDay, wasDailyRewardTaken, errorMessage, tokens,
    timeLeft, dayStreakLevel)
    if bonusShrines == OPEN_WINDOWS.SHRINE then
        rewardWallController.ui:show()
        rewardWallController.ui:raise()
        rewardWallController.ui:focus()
    end
    bonusShrine = bonusShrines
    rewardClaimed = wasDailyRewardTaken ~= 0
    rewardStreak = math.max(0, math.floor(tonumber(dayStreakLevel) or 0))
    local timestamp = rewardClaimed and nextRewardTime or timeLeft
    local nextDeadline = timestamp == 90001 and os.time() + 59 or math.max(0, tonumber(timestamp) or 0)
    if nextDeadline ~= rewardDeadline then rewardRefreshRequested = false end
    rewardDeadline = nextDeadline
    updateDailyRewards(dayStreakDay, wasDailyRewardTaken, bonusShrines == OPEN_WINDOWS.SHRINE and 0 or 1)
    rewardWallController.ui.restingAreaPanel.restingAreaInfo.rewardStreakIcon:setText(rewardStreak)
    rewardWallController.ui.restingAreaPanel.restingAreaInfo.restingAreaGold.text:setText(tokens)
    rewardWallController.ui.footerPanel.footerGold1.text:setText(tokens)
    rewardWallController.ui.restingAreaPanel.restingAreaInfo.rewardStreakIcon:setImageSource(
        "/game_rewardwall/images/" .. getDayStreakIcon(rewardStreak))

    rewardWallController.ui.footerPanel.footerGold2.text:setText(
        g_game.getLocalPlayer():getResourceBalance(ResourceTypes.DAILYREWARD_STREAK))
    premiumStatusWindwos(g_game.getLocalPlayer():isPremium())
    updateRewardClock()
end

local function onRewardHistory(rewardHistory)
    local transferHistory = rewardWallController.ui.historyPanel.historyList.List
    transferHistory:destroyChildren()

    local headerRow = g_ui.createWidget("RewardWallHistoryRow", transferHistory)
    headerRow:setBackgroundColor("#363636")
    headerRow:setBorderColor("#00000077")
    headerRow:setBorderWidth(1)
    headerRow.date:setText("Date")
    headerRow.Balance:setText("Streak")
    headerRow.Description:setText("Event")

    for i, data in ipairs(rewardHistory) do
        local row = g_ui.createWidget("RewardWallHistoryRow", transferHistory)
        row:setHeight(30)
        row.date:setText(convert_timestamp(data[1]))
        row.Balance:setText(data[4])
        row.Description:setText(data[3])
        row.Description:setTextWrap(true)
        local height = math.max(18, row.Description:getTextSize().height)
        row.Description:setHeight(height)
        row:setHeight(height + 12)
        row:setBackgroundColor(i % 2 == 0 and "#ffffff12" or "#00000012")
    end
end

-- /*=============================================
-- =            Windows                  =
-- =============================================*/
function show()
    if not rewardWallController.ui then
        return
    end
    g_game.sendOpenRewardWall()
    rewardWallController.ui:show()
    rewardWallController.ui:raise()
    rewardWallController.ui:focus()
    if ButtonRewardWall then
        ButtonRewardWall:setOn(true)
    end
    connectOnServerError()
    premiumStatusWindwos(g_game.getLocalPlayer():isPremium())
    updateRewardClock()
end

function hide(bool)
    if not rewardWallController.ui then
        return
    end
    stopRewardClock()
    rewardWallController.ui:hide()
    if ButtonRewardWall then
        ButtonRewardWall:setOn(false)
    end
    if bool then
        disconnectOnServerError()
    end
end

function toggle()
    if not rewardWallController.ui then
        return
    end
    if rewardWallController.ui:isVisible() then
        return hide(true)
    end
    show()
end

local function setupRewardWallLayout()
    local ui = rewardWallController.ui
    ui.historyPanel.historyList.List:setMarginRight(14)
    local function hover(widget, handler)
        widget.onHoverChange = function(target, hovered)
            rewardWallController[handler](rewardWallController, {target = target, value = hovered})
        end
    end

    local icons = ui.restingAreaPanel.bonusIcons
    for i = 1, 6 do
        local icon = g_ui.createWidget('imgBonuses', icons)
        icon:setId('bonusIcon' .. i)
        icon:setSize({width = 64, height = 64})
        icon:setIconClip({x = (i - 1) * 64, y = 0, width = 64, height = 64})
        hover(icon, 'onhoverBonus')
    end

    local daily = ui.dailyRewardsPanel
    for i = 1, 7 do
        local day = g_ui.createWidget('RewardWallDay', daily)
        day:setId('reward' .. i)
        day:addAnchor(AnchorLeft, 'parent', AnchorLeft)
        day:addAnchor(AnchorTop, 'parent', AnchorTop)
        day:setMarginLeft((i - 1) * 71)
        local button, status = day.rewardButton, day.rewardGold
        button:setId('rewardButton' .. i)
        status:setId('rewardGold' .. i)
        hover(button, 'onhoverRewardType')
        hover(status, 'onhoverStatusReward')
        if i < 7 then
            local arrow = g_ui.createWidget('UIWidget', daily)
            arrow:setId('arrow' .. i)
            arrow:setSize({width = 5, height = 7})
            arrow:setImageSource('/game_rewardwall/images/icon-rewardarrow')
            arrow:setImageClip({x = 0, y = 0, width = 5, height = 7})
            arrow:addAnchor(AnchorLeft, 'parent', AnchorLeft)
            arrow:addAnchor(AnchorTop, 'parent', AnchorTop)
            arrow:setMarginLeft(66 + (i - 1) * 71)
            arrow:setMarginTop(30)
            arrow:setPhantom(true)
        end
    end
    local loop = g_ui.createWidget('UIWidget', daily)
    loop:setId('arrowLoop')
    loop:setSize({width = 435, height = 13})
    loop:setImageSource('/game_rewardwall/images/icon-rewardarrow-loop-inactive')
    loop:addAnchor(AnchorHorizontalCenter, 'parent', AnchorHorizontalCenter)
    loop:addAnchor(AnchorTop, 'parent', AnchorTop)
    loop:setMarginTop(94)
    loop:setPhantom(true)

    local resting = ui.restingAreaPanel.restingAreaInfo
    for _, widget in ipairs({resting.rewardStreakIcon, resting.timeLeft, resting.restingAreaGold}) do
        hover(widget, 'onhoverStatusPlayer')
    end
    resting.restingAreaGold.gold:setImageSource('/game_rewardwall/images/icon-daily-reward-joker')
    ui.footerPanel.footerGold1.gold:setImageSource('/game_rewardwall/images/icon-daily-reward-joker')
    ui.footerPanel.footerGold2.gold:setImageSource('/game_rewardwall/images/instant-reward-access-icon')
end
-- /*=============================================
-- =            Controller                  =
-- =============================================*/
function rewardWallController:onInit()
    g_fonts.importFontWithSize('/fonts/ttf/verdana-bold.ttf', 11)
    g_fonts.importFontWithSize('/fonts/ttf/verdana-bold.ttf', 10)
    g_ui.importStyle('styles/style.otui')
    rewardWallController:loadUI('game_rewardwall')
    rewardWallController.ui:hide()

    rewardWallController:registerEvents(g_game, {
        onOpenRewardWall = onOpenRewardWall,
        onDailyReward = onDailyReward,
        onRewardHistory = onRewardHistory,
        onRestingAreaState = onRestingAreaState
        -- onDailyRewardCollectionState
    })
    setupRewardWallLayout()
end

function rewardWallController:onTerminate()
    stopRewardClock()
    generalBox, windowsPickWindow, ButtonRewardWall = destroyWindows({generalBox, windowsPickWindow, ButtonRewardWall})
end

function rewardWallController:onGameStart()
    if g_game.getClientVersion() > 1140 then -- Summer Update 2017
        if not ButtonRewardWall then
            ButtonRewardWall = modules.game_mainpanel.addToggleButton("rewardWall", tr("Open rewardWall"),
                "/images/options/rewardwall", toggle, false, 21)
        end
    else
        scheduleEvent(function()
            g_modules.getModule("game_rewardwall"):unload()
        end, 100)
    end
end

function rewardWallController:onGameEnd()
    stopRewardClock()
    if rewardWallController.ui:isVisible() then
        rewardWallController.ui:hide()
        ButtonRewardWall:setOn(false)
    end
    generalBox, windowsPickWindow = destroyWindows({generalBox, windowsPickWindow})
end
-- /*=============================================
-- =            Call css onClick                =
-- =============================================*/
function rewardWallController:onClickshowHistory()
    visibleHistory(not rewardWallController.ui.historyPanel:isVisible())
    if rewardWallController.ui.historyPanel:isVisible() then
        g_game.requestOpenRewardHistory()
    end
    rewardWallController.ui.footerPanel.historyButton:setText(
    rewardWallController.ui.historyPanel:isVisible() and "Back" or "History")
end

function rewardWallController:onClickToggle()
    toggle()
end

function rewardWallController:onClickSendStoreRewardWall()
    modules.game_store.toggle()
    g_game.sendRequestStorePremiumBoost()
end

function rewardWallController:onClickbuyInstantRewardAccess()
    modules.game_store.toggle()
    g_game.sendRequestUsefulThings(StoreConst.InstantRewardAccess)
end

function rewardWallController:onClickDisplayWindowsPickRewardWindow(event)
    if event.target:isOn() then
        return
    end

    if event.target.bundleType == bundleType.ITEMS then
        local isPremium = g_game.getLocalPlayer():isPremium()
        local itemsToSelect = event.target.itemsToSelect
        if not windowsPickWindow then
            if type(itemsToSelect) == "table" then
                itemsToSelect = isPremium and itemsToSelect[1] or itemsToSelect[2]
            else
                itemsToSelect = itemsToSelect or 1
            end
            windowsPickWindow = g_ui.displayUI('styles/pickreward')
            windowsPickWindow:show()
            windowsPickWindow:getChildById('capacity'):setText("Free capacity: " ..
                                                                   g_game:getLocalPlayer():getFreeCapacity() .. " oz")

            local text = string.format("You have selected [color=#D33C3C]0[/color] of %d reward items", itemsToSelect)
            windowsPickWindow:getChildById('rewardLabel'):parseColoredText(text, "#c0c0c0")

            for i, item in pairs(event.target.rewardItem) do
                local getItem = g_ui.createWidget('ItemReward', windowsPickWindow:getChildById('rewardList'))
                getItem:getChildById('item'):setItemId(item.itemId)
                getItem:getChildById('title'):setText(item.name)
                getItem:setBackgroundColor((i % 2 == 0) and COLORS.BASE_1 or COLORS.BASE_2)
                -- The protocol sends item weight in hundredths of an ounce.
                getItem.totalWeight = (item.weight or 0) / 100
                getItem.selectedWeight = 0
                getItem.itemsToSelect = itemsToSelect

            end
            actualUsed = {}
            hide()
        else
            windowsPickWindow:show()
            windowsPickWindow:raise()
            windowsPickWindow:focus()
        end

    elseif event.target.bundleType == bundleType.XPBOOST or event.target.bundleType == bundleType.PREY then
        hide()
        actualUsed = {}
        managerMessageBoxWindow(CONST_WINDOWS_BOX.CONFIRMATION_IRA)
    end
end

-- /*=============================================
-- =            Call onHover css                  =
-- =============================================*/

function rewardWallController:onhoverBonus(event)
    if not event.value then
        clearRewardInfo()
        return
    end

    local id = event.target:getId()
    local index = tonumber(id:match("%d+"))
    local bonus = bonuses[index]

    if not bonus then
        showRewardMessage("Unknown bonus.")
        return
    end

    local isPremium = g_game.getLocalPlayer():isPremium()
    local unlocked = rewardStreak >= bonus.id and (isPremium or bonus.id <= 3)
    local bonusText = string.format('%s\nRequires %d consecutive reward days.\nStatus: [color=%s]%s[/color].%s',
        bonus.name, bonus.id, unlocked and '#44AD25' or '#D33C3C', unlocked and 'Active' or 'Locked',
        bonus.id > 3 and '\nA Premium account is required.' or '')
    showRewardMessage(bonusText, true)
end

function rewardWallController:onhoverStatusPlayer(event)
    if not event.value then
        clearRewardInfo()
        return
    end

    local playerStatus = {
        rewardStreakIcon = "Claim your daily reward once per server day to increase your streak.\nMissing a reward day resets the counter to zero.\nResting area bonuses unlock from day 2; Premium accounts unlock all bonuses by day 7.",
        timeLeft = "Time remaining until the next server save. Claim your reward each day to increase your consecutive streak. Missing a reward day resets the streak to zero.",
        restingAreaGold = "Your Daily Reward Jokers. The consecutive-claim counter always resets after a missed reward day; jokers are not automatically consumed to preserve that counter."
    }

    local DEFAULT_MESSAGE = "Unknown bonus."

    local id = event.target:getId()
    local info = playerStatus[id]
    showRewardMessage(info or DEFAULT_MESSAGE, true)
end

function rewardWallController:onhoverRewardType(event)
    if not event.value then
        clearRewardInfo()
        return
    end

    local itemsToSelect = event.target.itemsToSelect or {1, 1}
    local freeAmount = 0
    local premiumAmount = 0

    if type(itemsToSelect) == "table" then
        freeAmount = itemsToSelect[2] or 0
        premiumAmount = itemsToSelect[1] or 0
    else
        freeAmount = itemsToSelect
        premiumAmount = itemsToSelect
    end

    local rewardType = event.target.bundleType
    local rewardTexts = {}

    if rewardType == bundleType.ITEMS then
        rewardTexts = {
            free = string.format(
                "Reward for Free Accounts:\nPick %d items from the list. Among\nother items it contains: health\npotion, a fire bomb rune, a\nthundestorm rune.",
                freeAmount),
            premium = string.format(
                "Reward for Premium Accounts:\nPick %d items from the list. Among\nother items it contains: health\npotion, a fire bomb rune, a\nthundestorm rune.",
                premiumAmount)
        }
    elseif rewardType == bundleType.PREY then
        rewardTexts = {
            free = string.format("Reward for Free Accounts:\n * %d x Prey Wildcard", freeAmount),
            premium = string.format("Reward for Premium Accounts:\n * %d x Prey Wildcard", premiumAmount)
        }
    elseif rewardType == bundleType.XPBOOST then
        rewardTexts = {
            free = string.format("Reward for Free Accounts:\n * %d minutes 50%% XP Boost", freeAmount),
            premium = string.format("Reward for Premium Accounts:\n * %d minutes 50%% XP Boost", premiumAmount)
        }
    else
        print("WARNING: Unknown rewardType:", rewardType)
        return
    end

    clearRewardInfo()
    rewardWallController.ui.infoPanel.free:setText(rewardTexts.free)
    rewardWallController.ui.infoPanel.premium:setText(rewardTexts.premium)
end

function rewardWallController:onhoverStatusReward(event)
    local statusReward = {
        [STATUS.COLLECTED] = "You have already collected this daily reward.\nThe reward cycle advances when you claim a reward and repeats after seven rewards.\nYour consecutive-day counter continues across cycles.",
        [STATUS.ACTIVE] = "This reward can be claimed now.\nCollect at a reward shrine for free, or use one Instant Reward Access from this panel.\nClaim daily to maintain your consecutive streak.",
        [STATUS.LOCKED] = "This daily reward is still locked.\nFirst collect the previous daily rewards of this cycle."
    }
    if not event.value then
        clearRewardInfo()
        return
    end
    showRewardMessage(statusReward[event.target.status])
end

-- /*=============================================
-- =            Auxiliar Windows pickReward      =
-- =============================================*/

function onClickBtnOk()
    if table.empty(actualUsed) then
        return
    end
    if bonusShrine == OPEN_WINDOWS.SHRINE then
        -- Collecting at a reward shrine is free: no Instant Reward Access confirmation.
        -- Canary expects 0 = shrine on the collect packet.
        g_game.requestGetRewardDaily(0, actualUsed)
        if windowsPickWindow then
            windowsPickWindow:destroy()
            windowsPickWindow = nil
        end
        show()
        return
    end
    managerMessageBoxWindow(CONST_WINDOWS_BOX.CONFIRMATION_IRA)
end

function destroyPickReward(bool)
    windowsPickWindow = destroyWindows(windowsPickWindow)

    if bool then
        rewardWallController.ui:show()
        rewardWallController.ui:raise()
        rewardWallController.ui:focus()
    end
end

function onTextChangeChangeNumber(getPanel)
    if not getPanel.itemsToSelect then
        return
    end

    local alreadyUsed = 0
    local itemId = getPanel:getChildById('item'):getItemId()
    local thisPanelUsed = actualUsed[itemId] or 0

    for _, count in pairs(actualUsed) do
        alreadyUsed = alreadyUsed + (count or 0)
    end

    local numberField = getPanel:getChildById('number')
    local currentValue = tonumber(numberField:getText()) or 0
    local maxAllowed = getPanel.itemsToSelect - (alreadyUsed - thisPanelUsed)

    if currentValue > maxAllowed then
        numberField:setText(maxAllowed)
    end
    actualUsed[itemId] = tonumber(numberField:getText()) or 0
    alreadyUsed = 0
    for _, count in pairs(actualUsed) do
        alreadyUsed = alreadyUsed + (count or 0)
    end
    getPanel.selectedWeight = actualUsed[itemId] * getPanel.totalWeight
    getPanel:getChildById('weight'):setText(string.format("%.2f oz", getPanel.selectedWeight))
    local totalWeight = 0
    for _, widget in pairs(getPanel:getParent():getChildren()) do
        totalWeight = totalWeight + (widget.selectedWeight or 0)
    end
    local freeCapacity = g_game:getLocalPlayer():getFreeCapacity()
    local hasCapacity = totalWeight <= freeCapacity
    local selectionComplete = alreadyUsed == getPanel.itemsToSelect
    local color = selectionComplete and hasCapacity and "#00FF00" or "#D33C3C"
    windowsPickWindow:getChildById('btnOk'):setEnabled(selectionComplete and hasCapacity)

    local text = string.format("You have selected [color=%s]%d[/color] of %d reward items", color, alreadyUsed,
        getPanel.itemsToSelect)
    windowsPickWindow:getChildById('rewardLabel'):parseColoredText(text)
    local totalWeightLabel = windowsPickWindow:getChildById("weight")
    totalWeightLabel:setText(string.format("Total weight: %.2f oz", totalWeight))
    totalWeightLabel:setColor(hasCapacity and "#c0c0c0" or "#D33C3C")
    totalWeightLabel:resizeToText()
end

-- /*=============================================
-- =            Auxiliar GeneralBox             =
-- =============================================*/
function displayGeneralBox3(title, message, buttons, onEnterCallback, onEscapeCallback)
    if generalBox then
        generalBox = destroyWindows(generalBox)
    end

    generalBox = g_ui.createWidget('MessageBoxWindow', rootWidget)
    if not generalBox then
        return nil
    end

    local titleWidget = generalBox:getChildById('title')
    if titleWidget then
        titleWidget:setText(title)
    end

    local holder = generalBox:getChildById('holder')
    if holder and buttons then
        for i = 1, #buttons do
            local button = g_ui.createWidget('Button', holder)
            local buttonId = buttons[i].text:lower():gsub(" ", "_")

            button:setId(buttonId)
            button:setText(buttons[i].text)
            button:setWidth(math.max(86, 10 + (string.len(buttons[i].text) * 8)))
            button:setHeight(20)
            button:setMarginTop(-5)

            if i == 1 then
                button:addAnchor(AnchorTop, 'parent', AnchorTop)
                button:addAnchor(AnchorRight, 'parent', AnchorRight)
            else
                button:addAnchor(AnchorTop, 'parent', AnchorTop)
                button:addAnchor(AnchorRight, 'prev', AnchorLeft)
                button:setMarginRight(5)
            end
            button.onClick = buttons[i].callback
        end
    end
    if onEnterCallback then
        generalBox.onEnter = onEnterCallback
    end
    if onEscapeCallback then
        generalBox.onEscape = onEscapeCallback
    end

    local content = generalBox:getChildById('content')
    if not content then
        generalBox = destroyWindows(generalBox)

        return nil
    end

    content:setText(message)
    content:resizeToText()

    local contentWidth = content:getWidth() + 32
    local contentHeight = content:getHeight() + 42 + (holder and holder:getHeight() or 0)
    generalBox:setWidth(math.min(916, math.max(300, contentWidth)))
    generalBox:setHeight(math.min(616, math.max(119, contentHeight)))

    generalBox.setContent = function(self, newMessage)
        local content = generalBox:getChildById('content')
        if not content then
            return
        end

        content:setText(newMessage)
        content:resizeToText()
        content:setTextWrap(false)
        content:setTextAutoResize(false)

        local holder = generalBox:getChildById('holder')
        if not holder then
            return
        end

        local contentWidth = content:getWidth() + 32
        local contentHeight = content:getHeight() + 50 + holder:getHeight()
        generalBox:setWidth(math.min(736, math.max(300, contentWidth)))
        generalBox:setHeight(math.min(300, math.max(89, contentHeight)))
    end

    generalBox.setTitle = function(self, newTitle)
        local titleWidget = generalBox:getChildById('title')
        if not titleWidget then
            return
        end

        titleWidget:setText(newTitle)
    end
    generalBox.modifyButton = function(self, buttonId, newText, newCallback)
        local holder = generalBox:getChildById('holder')
        if not holder then
            return nil
        end

        local button = holder:getChildById(buttonId)
        if button then
            if newText then
                button:setText(newText)
                button:setWidth(math.max(86, 10 + (string.len(newText) * 8)))
            end
            if newCallback then
                disconnect(button, {
                    onClick = button.onClick
                })
                connect(button, {
                    onClick = newCallback
                })
                button.onClick = newCallback
            end
        end
        return button
    end
    generalBox:show()
    generalBox:raise()
    generalBox:focus()
    return generalBox
end

function managerMessageBoxWindow(id)
    local config = BOX_CONFIGS[id]
    if not config then
        return
    end

    local cancelCallback = function()
        generalBox, windowsPickWindow = destroyWindows({generalBox, windowsPickWindow})
        rewardWallController.ui:show()
        rewardWallController.ui:raise()
        rewardWallController.ui:focus()
    end

    local okCallback = config.okCallback or function()
        generalBox, windowsPickWindow = destroyWindows({generalBox, windowsPickWindow})
        rewardWallController.ui:show()
        rewardWallController.ui:raise()
        rewardWallController.ui:focus()
    end

    local standardButtons = {{
        text = "cancel",
        callback = cancelCallback
    }, {
        text = "ok",
        callback = okCallback
    }}

    generalBox = displayGeneralBox3(config.title, config.content, standardButtons)

    rewardWallController.ui:hide()

    if windowsPickWindow then
        windowsPickWindow = destroyWindows(windowsPickWindow)
    end
end
