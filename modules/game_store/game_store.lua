-- Auxiliar miniWindows
local acceptWindow = nil
local changeNameWindow = nil
local transferPointsWindow = nil
local processingWindow = nil
local messageBox = nil
local purchaseStatusCloseEvent = nil
local purchaseAnimationEvent = nil
local searchEvent = nil


local oldProtocol = false
local a0xF2 = true

local offerDescriptions = {}
local reasonCategory = {}

local homeBanners = {
    'store-banner-arcane-bag',
    'store-banner-addon-doll',
    'store-banner-mount-doll'
}
local homeBannerIndex = 1
local homeBannerEvent = nil

local function renderHomeBanner()
    local banner = controllerShop.ui.HomePanel.HomeContent.HomeBanner
    banner:setImageSource('/game_store/images/' .. homeBanners[homeBannerIndex])
end

function changeHomeBanner(direction)
    homeBannerIndex = (homeBannerIndex - 1 + direction) % #homeBanners + 1
    renderHomeBanner()
end

local function scheduleHomeBanner()
    if homeBannerEvent then
        removeEvent(homeBannerEvent)
    end
    homeBannerEvent = controllerShop:scheduleEvent(function()
        homeBannerEvent = nil
        if controllerShop.ui and controllerShop.ui:isVisible() and controllerShop.ui.HomePanel:isVisible() then
            changeHomeBanner(1)
            scheduleHomeBanner()
        end
    end, 6500)
end
-- /*=============================================
-- =            To-do                  =
-- =============================================*/
-- - Fix filter functionality
-- - Correct HTML string syntax
-- - cache
-- - try on outfit
-- - improve homePanel/hystoryPanel

GameStore = {}
-- == Enums ==--
GameStore.website = {
    WEBSITE_GETCOINS = "https://www.baiakeros.com/index.php/donations",
    --IMAGES_URL =  "http://localhost/images/store/" --./game_store --https://docs.opentibiabr.com/opentibiabr/downloads/website-applications/applications#store-for-client-13-1
}

GameStore.CoinType = {
    Coin = 0,
    Transferable = 1
}

GameStore.ClientOfferTypes = {
	CLIENT_STORE_OFFER_OTHER = 0,
	CLIENT_STORE_OFFER_NAMECHANGE = 1,
	CLIENT_STORE_OFFER_WORLD_TRANSFER = 2,
	CLIENT_STORE_OFFER_HIRELING = 3, --idk
	CLIENT_STORE_OFFER_CHARACTER = 4,--idk
	CLIENT_STORE_OFFER_TOURNAMENT = 5,--idk
	CLIENT_STORE_OFFER_CONFIRM = 6,--idk
}

GameStore.States = {
    STATE_NONE = 0,
    STATE_NEW = 1,
    STATE_SALE = 2,
    STATE_TIMED = 3
}

GameStore.SendingPackets = {
    S_CoinBalance = 0xDF, -- 223
    S_StoreError = 0xE0, -- 224
    S_RequestPurchaseData = 0xE1, -- 225
    S_CoinBalanceUpdating = 0xF2, -- 242
    S_OpenStore = 0xFB, -- 251
    S_StoreOffers = 0xFC, -- 252
    S_OpenTransactionHistory = 0xFD, -- 253
    S_CompletePurchase = 0xFE -- 254
}

GameStore.RecivedPackets = {
    C_StoreEvent = 0xE9, -- 233
    C_TransferCoins = 0xEF, -- 239
    C_ParseHirelingName = 0xEC, -- 236
    C_OpenStore = 0xFA, -- 250
    C_RequestStoreOffers = 0xFB, -- 251
    C_BuyStoreOffer = 0xFC, -- 252
    C_OpenTransactionHistory = 0xFD, -- 253
    C_RequestTransactionHistory = 0xFE -- 254
}

-- /*=============================================
-- =            Local Function auxiliaries      =
-- =============================================*/

local function showPanel(panel)
    if panel == "HomePanel" then
        controllerShop.ui.HomePanel:setVisible(true)
        controllerShop.ui.panelItem:setVisible(false)
        controllerShop.ui.transferHistory:setVisible(false)
    elseif panel == "transferHistory" then
        controllerShop.ui.HomePanel:setVisible(false)
        controllerShop.ui.panelItem:setVisible(false)
        controllerShop.ui.transferHistory:setVisible(true)
    elseif panel == "panelItem" then
        controllerShop.ui.HomePanel:setVisible(false)
        controllerShop.ui.panelItem:setVisible(true)
        controllerShop.ui.transferHistory:setVisible(false)
    end
end

local function destroyWindow(windows)
    if type(windows) == "table" then
        for _, window in ipairs(windows) do
            if window and not window:isDestroyed() then
                window:destroy()
                window = nil
            end
        end
    else
        if windows and not windows:isDestroyed() then
            windows:destroy()
            windows = nil
        end
    end
end

local function getPageLabelHistory()
    local text = controllerShop.ui.transferHistory.lblPage:getText()
    local currentPage, pageCount = text:match("Page (%d+)/(%d+)")
    return tonumber(currentPage), tonumber(pageCount)
end

local function setImagenHttp(widget, url, isIcon)
    local filename = url:match("([^/]+)$")
    local localImage = filename and "/game_store/images/" .. filename
    if localImage and g_resources.fileExists(localImage) then
        if isIcon then
            widget:setIcon(localImage)
        else
            widget:setImageSource(localImage)
        end
        return
    end
    if GameStore.website.IMAGES_URL then
        HTTP.downloadImage(GameStore.website.IMAGES_URL .. url, function(path, err)
            if err then
                g_logger.warning("HTTP error: " .. err .. " - " .. GameStore.website.IMAGES_URL .. url)
                if isIcon then
                    widget:setIcon("/game_store/images/dynamic-image-error")
                else
                    widget:setImageSource("/game_store/images/dynamic-image-error")
                    widget:setImageFixedRatio(false)
                end
                return
            end
            if isIcon then
                widget:setIcon(path)
            else
                widget:setImageSource(path)
            end
        end)
    else
        if not g_resources.fileExists("/game_store/images/" .. url) then
            widget:setImageSource("/game_store/images/dynamic-image-error")
            widget:setImageFixedRatio(false)
        else
            widget:setImageSource("/game_store/images/" .. url)
        end

    end
end

local STORE_ICON_PATH = "/game_store/images/store-icons-inline"
local STORE_ICON_TAGS = {
    ["{info}"]                    = {clip = "0 0 13 13",   text = ""},
    ["{character}"]               = {clip = "13 0 13 13",  text = "only usable by purchasing character"},
    ["{charactericon}"]           = {clip = "13 0 13 13",  text = ""},
    ["{usablebyall}"]             = {clip = "26 0 13 13",  text = "can be used by all characters that have access to the house"},
    ["{usablebyallicon}"]         = {clip = "26 0 13 13",  text = ""},
    ["{box}"]                     = {clip = "39 0 13 13",  text = "comes in a box which can only be unwrapped by purchasing character"},
    ["{boxicon}"]                 = {clip = "39 0 13 13",  text = ""},
    ["{storeinbox}"]              = {clip = "52 0 13 13",  text = "will be sent to your Store inbox and can only be stored there and in depot box"},
    ["{storeinboxicon}"]          = {clip = "52 0 13 13",  text = ""},
    ["{house}"]                   = {clip = "65 0 13 13",  text = "can only be unwrapped in a house owned by the purchasing character"},
    ["{houseicon}"]               = {clip = "65 0 13 13",  text = ""},
    ["{once}"]                    = {clip = "78 0 13 13",  text = "can only be purchased once"},
    ["{onceicon}"]                = {clip = "78 0 13 13",  text = ""},
    ["{backtoinbox}"]             = {clip = "91 0 13 13",  text = "will be wrapped back and sent to inbox if the purchasing character is no longer the house owner"},
    ["{backtoinboxicon}"]         = {clip = "91 0 13 13",  text = ""},
    ["{vocationlevelcheck}"]      = {clip = "104 0 13 13", text = "only buyable if fitting vocation and level of purchasing character"},
    ["{vocationlevelcheckicon}"]  = {clip = "104 0 13 13", text = ""},
    ["{speedboost}"]              = {clip = "117 0 13 13", text = "provides character with a speed boost"},
    ["{speedboosticon}"]          = {clip = "117 0 13 13", text = ""},
    ["{activated}"]               = {clip = "130 0 13 13", text = "activated at purchase"},
    ["{activatedicon}"]           = {clip = "130 0 13 13", text = ""},
    ["{battlesign}"]              = {clip = "143 0 13 13", text = "cannot be purchased by characters with protection zone block or battle sign"},
    ["{battlesignicon}"]          = {clip = "143 0 13 13", text = ""},
    ["{capacity}"]                = {clip = "156 0 13 13", text = "cannot be purchased if capacity is exceeded"},
    ["{capacityicon}"]            = {clip = "156 0 13 13", text = ""},
    ["{use}"]                     = {clip = "169 0 13 13", text = "can be used"},
    ["{useicon}"]                 = {clip = "169 0 13 13", text = ""},
    ["{transferableprice}"]       = {clip = "182 0 13 13", text = "can be purchased with transferable Tibia Coins"},
    ["{transferablepriceicon}"]   = {clip = "182 0 13 13", text = ""},
    ["{star}"]                    = {localImg = "/game_store/images/icon-star-gold", text = ""},
}

local function matchIconTag(line)
    if line:byte(1) ~= 123 then return nil end -- fast bail if not '{'
    local s, e, cap = line:find("^{limit|(%d+)}")
    if s then
        return {clip = "78 0 13 13", text = "maximum amount that can be owned by character: %s"}, e, cap
    end
    local close = line:find("}", 1, true)
    if close then
        local info = STORE_ICON_TAGS[line:sub(1, close)]
        if info then return info, close, nil end
    end
end

local function addDescriptionLine(container, lineText, color)
    if not lineText:match("%S") then return end
    lineText = lineText:gsub("<[^>]+>", ""):gsub("&nbsp;", " "):gsub("&#8226;", "- ")

    local widget = g_ui.createWidget('DescriptionLine', container)
    if not widget then return end

    local iconWidget = widget:getChildById('icon')
    local textWidget = widget:getChildById('text')
    if not iconWidget or not textWidget then return end
    if color then textWidget:setColor(color) end

    local info, tagEnd, cap = matchIconTag(lineText)
    if info then
        iconWidget:setVisible(true)
        if info.localImg then
            iconWidget:setImageSource(info.localImg)
        else
            iconWidget:setImageSource(STORE_ICON_PATH)
            iconWidget:setImageClip(info.clip)
        end
        local tagText = (cap and info.text:format(cap)) or info.text
        local rest    = lineText:sub(tagEnd + 1):match("^%s*(.-)%s*$")
        textWidget:setMarginLeft(16)
        textWidget:setText(tagText ~= "" and (tagText .. " " .. rest) or rest)
    else
        textWidget:setMarginLeft(0)
        textWidget:setText(lineText:match("^%s*(.-)%s*$"))
    end

    widget:setHeight(math.max(14, textWidget:getTextSize().height + 2))
end

local function renderDescription(panel, text, errorText)
    local descPanel = panel:getChildById('descriptionPanel')
    local container = descPanel and descPanel:getChildById('descriptionScrollArea')
    if not container or container:isDestroyed() then return end
    container:destroyChildren()

    if errorText then
        for line in errorText:gmatch("[^\r\n]+") do
            addDescriptionLine(container, line, "#d33c3c")
        end
    end

    if text and text ~= "" then
        for line in text:gmatch("[^\r\n]+") do
            addDescriptionLine(container, line, nil)
        end
    end
end

local function formatNumberWithCommas(value)
    local sign = value < 0 and "-" or ""
    value = math.abs(value)
    local formattedValue = string.format("%d", value)
    formattedValue = formattedValue:reverse():gsub("(%d%d%d)", "%1,")
    formattedValue = formattedValue:reverse():gsub("^,", "")
    return sign .. formattedValue
end

local function getCoinsBalance()
    local function extractNumber(text)
        if type(text) ~= "string" then 
            return 0 
        end
        local numberStr = text:match("%d[%d,]*")
        if not numberStr then 
            return 0 
        end
        local cleanNumber = numberStr:gsub("[^%d]", "")
        return tonumber(cleanNumber) or 0
    end

    -- get coins: normal (non transferableCoins) | transfer(transferableCoins))
    local lblNormal = controllerShop.ui.lblCoins.lblTibiaCoins
    local lblTransfer = controllerShop.ui.lblCoins.lblTibiaTransfer

    local normalCoins = lblNormal and extractNumber(lblNormal:getText()) or 0
    local transferableCoins = lblTransfer and extractNumber(lblTransfer:getText()) or 0

    return normalCoins, transferableCoins
end

local function fixServerNoSend0xF2()
    if a0xF2 then
        local player = g_game.getLocalPlayer()
        local coin, transfer = getCoinsBalance()
        local coinBalance = g_game.getLocalPlayer():getResourceBalance(ResourceTypes.COIN_NORMAL)
        local transferBalance = player:getResourceBalance(ResourceTypes.COIN_TRANSFERRABLE)
        if not coin or not transfer or coin ~= coinBalance or transfer ~= transferBalance then
            controllerShop.ui.lblCoins.lblTibiaCoins:setText(formatNumberWithCommas(coinBalance))
    
            if transfer ~= transferBalance then
                controllerShop.ui.lblCoins.lblTibiaTransfer:setText(
                    string.format("(Including: %s", formatNumberWithCommas(transferBalance))
                )
            end
            local packet2 = GameStore.SendingPackets.S_CoinBalanceUpdating
            g_logger.warning(string.format("[game_store BUG] Check 0x%X (%d) on server  onParseStoreGetCoin", packet2, packet2))
        end 
    end
end

local function convert_timestamp(timestamp)
    local fecha_hora = os.date("%Y-%m-%d, %H:%M:%S", timestamp)
    return fecha_hora
end

local function getProductData(product)
    if product.itemId or product.itemType then
        return {
            VALOR = "item",
            ID = product.itemId or product.itemType
        }
    elseif product.icon then
        return {
            VALOR = "icon",
            ID = product.icon
        }
    elseif product.outfitId or product.mountId or product.mountClientId or product.sexId then
        return {
            VALOR = "mountId",
            ID = product.outfitId or product.mountId or product.mountClientId or product.sexId
        }
    elseif product.maleOutfitId then
        return {
            VALOR = "outfitId",
            ID = product.maleOutfitId
        }
    end
end

local function createProductImage(imageParent, data)
    if data.VALOR == "item" then
        local itemWidget = g_ui.createWidget('Item', imageParent)
        itemWidget:setId(data.ID)
        itemWidget:setItemId(data.ID)
        itemWidget:setVirtual(true)
        itemWidget:fill('parent')
    elseif data.VALOR == "icon" then
        local widget = g_ui.createWidget('UIWidget', imageParent)
        setImagenHttp(widget, "/64/" .. data.ID, false)
        widget:fill('parent')
    elseif data.VALOR == "mountId" or data.VALOR:find("outfitId") then
        local creature = g_ui.createWidget('Creature', imageParent)
        creature:setOutfit({
            type = data.ID
        })
        creature:getCreature():setStaticWalking(1000)
        creature:fill('parent')
    end
end

-- /*=============================================
-- =    behavior categories and subcategories    =
-- =============================================*/

local function disableAllButtons()
    local panel = controllerShop.ui.panelItem
    panel:getChildById('StackOffers'):destroyChildren()
    panel:getChildById('image'):destroyChildren()
    for i = 1, controllerShop.ui.listCategory:getChildCount() do
        local widget = controllerShop.ui.listCategory:getChildByIndex(i)
        if widget and widget.Button then
            widget.Button:setEnabled(false)
            if widget.subCategories then
                for subId, _ in ipairs(widget.subCategories) do
                    local subWidget = widget:getChildById(subId)
                    if subWidget and subWidget.Button then
                        subWidget.Button:setEnabled(false)
                    end
                end
            end
        end
    end
    offerDescriptions = {}
end

local function enableAllButtons()
    for i = 1, controllerShop.ui.listCategory:getChildCount() do
        local widget = controllerShop.ui.listCategory:getChildByIndex(i)
        if widget and widget.Button then
            widget.Button:setEnabled(true)
            if widget.subCategories then
                for subId, _ in ipairs(widget.subCategories) do
                    local subWidget = widget:getChildById(subId)
                    if subWidget and subWidget.Button then
                        subWidget.Button:setEnabled(true)
                    end
                end
            end
        end
    end
end

local function toggleSubCategories(parent, isOpen)
    for subId, _ in ipairs(parent.subCategories) do
        local subWidget = parent:getChildById(subId)
        if subWidget then
            subWidget:setVisible(isOpen)
            if subId == 1 then
                subWidget.Button:setChecked(true)
                subWidget.Button.Arrow:setVisible(true)
                subWidget.Button.Arrow:setImageSource("/images/ui/icon-arrow7x7-right")
            end
        end
    end
    parent:setHeight(isOpen and parent.openedSize or parent.closedSize)
    parent.opened = isOpen
    parent.Button.Arrow:setVisible(not isOpen)
end

local function close(parent)
    if parent.subCategories then
        toggleSubCategories(parent, false)
    end
end

local function open(parent)
    local oldOpen = controllerShop.ui.openedCategory
    if oldOpen and oldOpen ~= parent then
        close(oldOpen)
    end
    toggleSubCategories(parent, true)
    controllerShop.ui.openedCategory = parent
end

local function closeCategoryButtons()
    for i = 1, controllerShop.ui.listCategory:getChildCount() do
        local widget = controllerShop.ui.listCategory:getChildByIndex(i)
        if widget and widget.subCategories then
            for subId, _ in ipairs(widget.subCategories) do
                local subWidget = widget:getChildById(subId)
                if subWidget then
                    subWidget.Button:setChecked(false)
                    subWidget.Button.Arrow:setVisible(false)
                end
            end
        end
    end
end

local function createSubWidget(parent, subId, subButton)
    local subWidget = g_ui.createWidget("storeCategory", parent)
    subWidget:setId(subId)
    setImagenHttp(subWidget.Button.Icon, subButton.icon, true)
    subWidget.Button.Title:setText(subButton.text)
    subWidget:setVisible(false)
    subWidget.open = subButton.open
    subWidget:setImageSource("")
    subWidget:setMarginLeft(0)
    subWidget.Button:setSize('178 20')
    function subWidget.Button.onClick()
        disableAllButtons()
        local selectedOption = controllerShop.ui.selectedOption
        closeCategoryButtons()
        parent.Button:setChecked(false)
        parent.Button.Arrow:setVisible(true)
        parent.Button.Arrow:setImageSource("")
        subWidget.Button:setChecked(true)
        subWidget.Button.Arrow:setVisible(true)
        subWidget.Button.Arrow:setImageSource("/images/ui/icon-arrow7x7-right")
        controllerShop.ui.openedSubCategory = subWidget

        if selectedOption then
            selectedOption:hide()
        end
        if subWidget.open == "Home" then
            g_game.sendRequestStoreHome()
        else
            local sortOption = controllerShop.ui.panelItem.comboBoxContainer.MostPopularFirst:getCurrentOption()
            g_game.requestStoreOffers(subButton.text, "", sortOption and tonumber(sortOption.data) or 0, 1)
        end
    end

    subWidget:addAnchor(AnchorLeft, "parent", AnchorLeft)
    if subId == 1 then
        subWidget:addAnchor(AnchorTop, "parent", AnchorTop)
        subWidget:setMarginTop(20)
    else
        subWidget:addAnchor(AnchorTop, "prev", AnchorBottom)
        subWidget:setMarginTop(-1)
    end

    return subWidget
end

-- /*=============================================
-- =            Controller                   =
-- =============================================*/
controllerShop = Controller:new()
g_ui.importStyle("style/ui.otui")
controllerShop:setUI('game_store')
function controllerShop:onInit()
    controllerShop.ui:hide()

    for _, v in ipairs({{'Lowest Price First', 0}, {'Alphabetically', 1},
                        {'Highest Price First', 2}}) do
        controllerShop.ui.panelItem.comboBoxContainer.MostPopularFirst:addOption(v[1], v[2])
    end

    controllerShop.ui.panelItem.comboBoxContainer.MostPopularFirst.onOptionChange = function(_, _, sortOrder)
        local categoryWidget = controllerShop.ui.openedSubCategory or controllerShop.ui.openedCategory
        local categoryName = categoryWidget and categoryWidget.open
        if categoryName and categoryName ~= "Home" then
            g_game.requestStoreOffers(categoryName, "", tonumber(sortOrder) or 0, 1)
        end
    end

    controllerShop.ui.transferPoints.onClick = transferPoints
    controllerShop.ui.panelItem.listProduct.onChildFocusChange = chooseOffert
    controllerShop.ui.HomePanel.HomeContent.HomeRecentlyAdded.HomeProductos.onChildFocusChange = chooseHome
    controllerShop.ui.HomePanel.HomeContent.HomePromotions.PromotionProducts.onChildFocusChange = chooseHome
    -- /*=============================================
    -- =            Parse                         =
    -- =============================================*/

    controllerShop:registerEvents(g_game, {
        onParseStoreGetCoin = onParseStoreGetCoin,
        onParseStoreGetCategories = onParseStoreGetCategories,
        onParseStoreCreateHome = onParseStoreCreateHome,
        onParseStoreCreateProducts = onParseStoreCreateProducts,
        onParseStoreGetHistory = onParseStoreGetHistory,
        onParseStoreGetPurchaseStatus = onParseStoreGetPurchaseStatus,
        onParseStoreOfferDescriptions = onParseStoreOfferDescriptions,
        onParseStoreError = onParseStoreError,
        onStoreInit = onStoreInit
    })
end

function controllerShop:onGameStart()
    oldProtocol = g_game.getClientVersion() < 1310
end

function controllerShop:onGameEnd()
    HirelingStore.close(true)
    if controllerShop.ui:isVisible() then
        controllerShop.ui:hide()
    end

    destroyWindow({transferPointsWindow, changeNameWindow, acceptWindow, processingWindow,messageBox})
    purchaseStatusCloseEvent = nil
    purchaseAnimationEvent = nil
    searchEvent = nil
    if homeBannerEvent then
        removeEvent(homeBannerEvent)
        homeBannerEvent = nil
    end
end

function controllerShop:onTerminate()
    HirelingStore.close(true)
    destroyWindow({transferPointsWindow, changeNameWindow, acceptWindow, processingWindow,messageBox})
    purchaseStatusCloseEvent = nil
    purchaseAnimationEvent = nil
    searchEvent = nil
    if homeBannerEvent then
        removeEvent(homeBannerEvent)
        homeBannerEvent = nil
    end
end

-- /*=============================================
-- =            Parse                           =
-- =============================================*/

function onStoreInit(url, coinsPacketSize)
    if not GameStore.website.IMAGES_URL then
        GameStore.website.IMAGES_URL = url
    end
end

function onParseStoreGetCoin(getTibiaCoins, getTransferableCoins)
    a0xF2 = false
    controllerShop.ui.lblCoins.lblTibiaCoins:setText(formatNumberWithCommas(getTibiaCoins))
    controllerShop.ui.lblCoins.lblTibiaTransfer:setText(string.format("(Including: %s",
        formatNumberWithCommas(getTransferableCoins)))
    HirelingStore.refresh()
end

function onParseStoreOfferDescriptions(offerId, description)
    offerDescriptions[offerId] = {
        id = offerId,
        description = description
    }
end

function onParseStoreGetPurchaseStatus(purchaseStatus)
    HirelingStore.onSuccess()
    destroyWindow({processingWindow, messageBox})
    controllerShop.ui:hide()
    messageBox = g_ui.createWidget('confirmarSHOP', g_ui.getRootWidget())
    messageBox.Box:setText(purchaseStatus)
    messageBox.buttonAnimation.animation:setImageClip("0 0 108 108")

    local phase = 0
    local function closePurchaseStatus()
        if purchaseStatusCloseEvent then
            removeEvent(purchaseStatusCloseEvent)
            purchaseStatusCloseEvent = nil
        end
        if purchaseAnimationEvent then
            removeEvent(purchaseAnimationEvent)
            purchaseAnimationEvent = nil
        end
        if messageBox and not messageBox:isDestroyed() then
            messageBox:ungrabMouse()
            messageBox:destroy()
            messageBox = nil
        end
        controllerShop.ui:show()
        controllerShop.ui:raise()
        controllerShop.ui:focus()
        fixServerNoSend0xF2()
        g_game.sendRequestStorePremiumBoost()
    end

    purchaseAnimationEvent = periodicalEvent(function()
        if messageBox and messageBox.buttonAnimation and messageBox.buttonAnimation.animation then
            messageBox.buttonAnimation.animation:setImageClip((phase % 12 * 108) .. " 0 108 108")
            phase = phase + 1
        end
    end, function()
        return messageBox and messageBox.buttonAnimation and messageBox.buttonAnimation.animation
    end, 80, 80)

    messageBox.onMousePress = function()
        closePurchaseStatus()
        return true
    end
    messageBox:grabMouse()
    purchaseStatusCloseEvent = controllerShop:scheduleEvent(closePurchaseStatus, 1250)
end

function onParseStoreCreateProducts(storeProducts)
    local comboBox = controllerShop.ui.panelItem.comboBoxContainer.showAll
    comboBox:clearOptions()
    comboBox:addOption("Show All", 0)

    if #storeProducts.menuFilter > 0 then
        for k, t in pairs(storeProducts.menuFilter) do
            comboBox:addOption(t, k - 1)
        end
--[[         comboBox.onOptionChange = function(a, b, c, d)
            pdump(a:getCurrentOption())
        end ]]
    end
    reasonCategory = storeProducts.disableReasons
    local listProduct = controllerShop.ui.panelItem.listProduct
    listProduct:destroyChildren()
    if not storeProducts then
        return
    end
    for _, product in ipairs(storeProducts.offers) do
        local row = g_ui.createWidget('RowStore', listProduct)
        row.product, row.type = product, product.type

        row.lblName:setText(product.name)
        row.lblName:setTooltip(product.name)

        local subOffers = product.subOffers or { product }
        local offerCount = #subOffers
        -- Reserve separate areas for the full title, offer rows and the New badge.
        local titleHeight = math.max(28, row.lblName:getTextSize().height)
        local offersHeight = offerCount * 20 + math.max(0, offerCount - 1) * 2
        row.lblName:setHeight(titleHeight)
        row.StackOffers:setHeight(offersHeight)
        row:setHeight(math.max(96, 6 + titleHeight + 6 + offersHeight + 5))
        for _, subOffer in ipairs(subOffers) do
            if subOffer.state == GameStore.States.STATE_NEW then
                row.newBadge:setVisible(true)
            end
            local offerI = g_ui.createWidget('stackOfferPanel', row:getChildById('StackOffers'))
            offerI:setId(subOffer.id)
            if subOffer.disabled then
                offerI:disable()
                row:setOpacity(0.5)
            end
            local priceLabel = offerI:getChildById('lblPrice')
            priceLabel:setText(subOffer.price)
            if subOffer.state == GameStore.States.STATE_SALE and subOffer.basePrice and subOffer.basePrice > subOffer.price then
                offerI.lblOriginalPrice:setText(subOffer.basePrice)
                offerI.lblOriginalPrice:setVisible(true)
            end

            if subOffer.count and subOffer.count > 0 then
                offerI:getChildById('count'):setText(subOffer.count .. "x")
            end
            fixServerNoSend0xF2()
            local coinsBalance2, coinsBalance1 = getCoinsBalance()
            local isTransferable = subOffer.coinType == GameStore.CoinType.Transferable
            local price = subOffer.price
            local balance = isTransferable and coinsBalance1 or (coinsBalance1 + coinsBalance2)
            priceLabel:setColor(balance < price and "#d33c3c" or "white")

            if isTransferable then
                priceLabel:setIcon("/game_store/images/icon-tibiacointransferable")
            end
        end
        local data = getProductData(product)
        if data then
            createProductImage(row:getChildById('image'):getChildById('iconContent'), data)
        end
    end

    controllerShop:scheduleEvent(function()
        local redirectId = storeProducts.redirectId
        if redirectId and type(redirectId) == "number" and redirectId ~= 0 then -- home behavior 
            for _, child in ipairs(listProduct:getChildren()) do
                for _, subOffer in ipairs(child.product.subOffers or { child.product }) do
                    if subOffer.id == redirectId then
                        listProduct:focusChild(child)
                        listProduct:ensureChildVisible(child)
                        return
                    end
                end
            end
        else
            local firstChild = listProduct:getFirstChild()
            if firstChild and firstChild:isEnabled() then
                listProduct:focusChild(firstChild)
                listProduct:ensureChildVisible(firstChild)
            end
        end
    end, 300, 'onParseStoreOfferDescriptionsSafeDelay')

    enableAllButtons()
    showPanel("panelItem")
    fixServerNoSend0xF2()
end

function onParseStoreCreateHome(offer)
    local homeProductos = controllerShop.ui.HomePanel.HomeContent.HomeRecentlyAdded.HomeProductos
    local promotionProducts = controllerShop.ui.HomePanel.HomeContent.HomePromotions.PromotionProducts
    homeProductos:destroyChildren()
    promotionProducts:destroyChildren()
    local promotionCount = 0
    local purchasedCount = 0
    for _, product in ipairs(offer.offers) do
        local isPromotion = product.unknownByte2 == GameStore.States.STATE_SALE
        if isPromotion then
            promotionCount = promotionCount + 1
        else
            purchasedCount = purchasedCount + 1
        end
        local row = g_ui.createWidget('HomeOfferRow', isPromotion and promotionProducts or homeProductos)
        row.product, row.type = product, product.type
        row.lblName:setText(product.name)
        row.lblName:setTooltip(product.name)
        row.lblPrice:setText(product.price)
        row.newBadge:setVisible(product.unknownByte2 == GameStore.States.STATE_NEW)
        if isPromotion then
            -- Home carries the regular price in its otherwise unused stateNewUntil field.
            local originalPrice = product.stateNewUntil
            if not originalPrice or originalPrice <= product.price then
                originalPrice = math.floor(product.price / 0.8 + 0.5)
            end
            row.lblOriginalPrice:setText(originalPrice)
            row.lblOriginalPrice:setVisible(true)
        end
        if product.coinType == GameStore.CoinType.Transferable then
            row.lblPrice:setIcon('/game_store/images/icon-tibiacointransferable')
        end
        local data = getProductData(product)
        if data then
            createProductImage(row:getChildById('image'):getChildById('iconContent'), data)
        end
    end

    -- Keep each section as tall as its compact two-column cards; the parent scrolls everything.
    local function sectionHeight(count)
        local rows = math.ceil(count / 2)
        if rows == 0 then
            return 42
        end
        return 31 + rows * 96 + (rows - 1) * 4
    end
    controllerShop.ui.HomePanel.HomeContent.HomePromotions:setHeight(sectionHeight(promotionCount))
    controllerShop.ui.HomePanel.HomeContent.HomeRecentlyAdded:setHeight(sectionHeight(purchasedCount))
    controllerShop.ui.HomePanel.homeScroll:setValue(0)
    homeBannerIndex = 1
    renderHomeBanner()
    scheduleHomeBanner()
    enableAllButtons()
    showPanel('HomePanel')
    fixServerNoSend0xF2()
end
function onParseStoreGetHistory(currentPage, pageCount, historyData)
    local transferHistory = controllerShop.ui.transferHistory.historyPanel
    transferHistory:destroyChildren()
    local headerRow = g_ui.createWidget("historyData2", transferHistory)
    headerRow:setBackgroundColor("#363636")
    headerRow:setBorderColor("#00000077")
    headerRow:setBorderWidth(1)
    headerRow.date:setText("Date")
    headerRow.Balance:setText("Balance")
    headerRow.Description:setText("Description")
    controllerShop.ui.transferHistory.lblPage:setText(string.format("Page %d/%d", currentPage + 1, pageCount))
    for i, data in ipairs(historyData) do
        local row = g_ui.createWidget("historyData2", transferHistory)
        row.date:setText(convert_timestamp(data[1]))
        local balance = data[3]
        row.Balance:setText(formatNumberWithCommas(balance))
        row.Balance:setColor(balance < 0 and "#D33C3C" or "#3CD33C")
        row.Description:setText(data[5])
        row.Balance:setIcon(data[4] == GameStore.CoinType.Transferable and 
                            "/game_store/images/icon-tibiacointransferable" or 
                            "images/ui/tibiaCoin")
        row:setBackgroundColor(i % 2 == 0 and "#ffffff12" or "#00000012")
    end
    showPanel("transferHistory")
end

function onParseStoreGetCategories(buttons)
    if controllerShop.ui.listCategory:getChildCount() > 0 then
        -- Categories are kept between Store openings. A category request can
        -- finish after the window was closed, so never retain its temporary
        -- disabled state when the already-created menu is reused.
        enableAllButtons()
        return
    end
    controllerShop.ui.listCategory:destroyChildren()

    local categories = {}
    if not oldProtocol then
        categories = {
            ["Home"] = {
                ["subCategories"] = {},
                ["name"] = "Home",
                ["icons"] = {
                    [1] = "icon-store-home.png"
                },
                ["state"] = 0
            }
        }
    end

    local subcategories = {}

    for _, button in ipairs(buttons) do
        if not button.parent then
            categories[button.name] = button
            categories[button.name].subCategories = {}
        else
            table.insert(subcategories, button)
        end
    end

    for _, subcat in ipairs(subcategories) do
        if categories[subcat.parent] then
            table.insert(categories[subcat.parent].subCategories, subcat)
        end
    end

    local orderedCategoryNames = {"Home", "VIP Time", "Consumables", "Cosmetics", "Houses", "Boosts", "Extras",
                                 "Tournament"}

    local priority = {}
    for index, name in ipairs(orderedCategoryNames) do
        priority[name] = index
    end

    local categoryArray = {}
    for name, data in pairs(categories) do
        table.insert(categoryArray, data)
    end

    -- Ordenar el array
    table.sort(categoryArray, function(a, b)
        local prioA = priority[a.name] or math.huge
        local prioB = priority[b.name] or math.huge
        return prioA < prioB
    end)

    for _, category in ipairs(categoryArray) do
        local widget = g_ui.createWidget("storeCategory", controllerShop.ui.listCategory)
        widget:setId(category.name)
            -- widget.Button.Icon:setIcon("/game_store/images/13/" .. category.icons[1])
            if category.icons[1] == "icon-store-home.png" then
                widget.Button.Icon:setIcon("/game_store/images/icon-store-home")
            else
                setImagenHttp(widget.Button.Icon, "/13/" .. category.icons[1], true)
            end

            widget.Button.Title:setText(category.name)
            widget.open = category.name

            if #category.subCategories > 0 then
                widget.subCategories = category.subCategories
                widget.subCategoriesSize = #category.subCategories
                widget.Button.Arrow:setVisible(true)

                for subId, subButton in ipairs(category.subCategories) do
                    local subWidget = createSubWidget(widget, subId, {
                        text = subButton.name,
                        icon = "/13/" .. subButton.icons[1],
                        open = subButton.name
                    })
                end
            end

            widget:setMarginTop(10)

            widget.Button.onClick = function()
                disableAllButtons()
                local parent = widget
                local oldOpen = controllerShop.ui.openedCategory
                local panel = controllerShop.ui.panelItem
                local btnBuy = panel:getChildById('btnBuy')
                local image = panel:getChildById('image')
                local lblPrice = panel:getChildById('lblPrice')
                local btnBuy = panel:getChildById('StackOffers')

                image:setImageSource("")
                btnBuy:destroyChildren()

                local firstChild = image:getFirstChild()
                if image:getChildCount() ~= 0 and firstChild then
                    local styleClass = firstChild:getStyle().__class
                    if styleClass == "UIItem" then
                        firstChild:setItemId(nil)
                    elseif styleClass == "UICreature" then
                        firstChild:setOutfit({
                            type = nil
                        })
                    else
                        firstChild:setImageSource("")
                    end
                end

                if oldOpen and oldOpen ~= parent then
                    if oldOpen.Button then
                        oldOpen.Button:setChecked(false)
                        oldOpen.Button.Arrow:setImageSource("/images/ui/icon-arrow7x7-down")
                    end
                    close(oldOpen)
                end

                if parent.subCategoriesSize then
                    parent.closedSize = parent.closedSize or parent:getHeight() / (parent.subCategoriesSize + 1) + 15
                    parent.openedSize = parent.openedSize or parent:getHeight() * (parent.subCategoriesSize + 1) - 6

                    open(parent)

                else
                    widget.Button:setChecked(true)
                end

                widget.Button.Arrow:setImageSource("/images/ui/icon-arrow7x7-right")
                widget.Button.Arrow:setVisible(true)

                if controllerShop.ui.selectedOption then
                    controllerShop.ui.selectedOption:hide()
                end
                if category.name == "Home" then
                    controllerShop.ui.HomePanel.HomeContent.HomeRecentlyAdded.HomeProductos:destroyChildren()
                    g_game.sendRequestStoreHome()
                else
                    local sortOption = controllerShop.ui.panelItem.comboBoxContainer.MostPopularFirst:getCurrentOption()
                    g_game.requestStoreOffers(category.name, "", sortOption and tonumber(sortOption.data) or 0, 1)
                end
                controllerShop.ui.openedCategory = parent
            end
        end
        local firstCategory = controllerShop.ui.listCategory:getChildByIndex(1)
        if controllerShop.ui.openedCategory == nil and firstCategory then
            controllerShop.ui.openedCategory = firstCategory
            firstCategory.Button:onClick()
        end

end

function onParseStoreError(errorMessage)
    destroyWindow(processingWindow)
    -- A failed request must not leave the category menu locked forever.
    enableAllButtons()
    if not HirelingStore.onError(errorMessage) then
        displayErrorBox(controllerShop.ui:getText(), errorMessage)
    end
end

-- /*=============================================
-- =            buttons                          =
-- =============================================*/

function hide()
    if not controllerShop.ui then
        return
    end

    -- Category navigation is disabled only while an offer request is pending.
    -- Closing with Esc/Close must cancel that visual lock because the Store
    -- keeps its category widgets alive for the next opening.
    enableAllButtons()
    controllerShop.ui:hide()
end

function toggle()
    if not controllerShop.ui then
        return
    end

    if controllerShop.ui:isVisible() then
        return hide()
    end
    show()
end

function show()
    if not controllerShop.ui then
        return
    end

    -- Restore navigation before showing cached categories again. This covers
    -- a Store closed before the previous category request completed.
    enableAllButtons()
    controllerShop.ui:show()
    controllerShop.ui:raise()
    controllerShop.ui:focus()

    g_game.openStore()
    controllerShop:scheduleEvent(function()
        if controllerShop.ui.listCategory:getChildCount() == 0 then
            g_game.sendRequestStoreHome() -- fix 13.10
            local packet1 = GameStore.RecivedPackets.C_OpenStore
            g_logger.warning(string.format("[game_store BUG] Check 0x%X (%d) L827", packet1, packet1))
        end
    end, 1000, function() return 'serverNoSendPackets0xF20xFA' end)
end



function getUI()
    return controllerShop.ui
end

function getCoinsWebsite()
    if GameStore.website.WEBSITE_GETCOINS ~= "" then
        g_platform.openUrl(GameStore.website.WEBSITE_GETCOINS)
    else
        sendMessageBox("Error", "No data for store URL.")
    end
end
-- /*=============================================
-- =            History                         =
-- =============================================*/

function toggleTransferHistory()
    if controllerShop.ui.transferHistory:isVisible() then
        if controllerShop.ui.openedCategory and controllerShop.ui.openedCategory:getId() == "Home" then
            showPanel("HomePanel")
        else
            showPanel("panelItem")
        end
    else
        g_game.requestTransactionHistory()
    end
end

function requestTransactionHistory(widget)
    local currentPage, pageCount = getPageLabelHistory()
    local newPage = currentPage + (widget:getId() == "btnNextPage" and 1 or -1)
    
    if newPage > 0 and newPage <= pageCount then
        g_game.requestTransactionHistory(newPage - 1)
    end
end

-- /*=============================================
-- =            focusedChild                     =
-- =============================================*/

function chooseOffert(self, focusedChild)
    if not focusedChild then
        return
    end

    local product = focusedChild.product
    local panel = controllerShop.ui.panelItem
    panel:getChildById('lblName'):setText(product.name)
    local description = product.description or ""
    local subOffers = product.subOffers or {}
    if not table.empty(subOffers) then
        local descriptionInfo = offerDescriptions[subOffers[1].id] or { id = 0xFFFF, description = "" }
        description = descriptionInfo.description
    end

    renderDescription(panel, description)

    local data = getProductData(product)
    local imagePanel = panel:getChildById('image')
    imagePanel:destroyChildren()
    if data then
        createProductImage(imagePanel, data)
    end
    fixServerNoSend0xF2()

    -- example use getCoinsBalance
    local normalCoins, transferableCoins = getCoinsBalance()
    local offerStackPanel = panel:getChildById('StackOffers')
    offerStackPanel:destroyChildren()

    local offers = not table.empty(subOffers) and subOffers or { product }
    -- Descriptions start below every buy option, including three-quantity offers.
    local columns = math.max(1, math.floor((offerStackPanel:getWidth() + 3) / 148))
    local offersHeight = math.ceil(#offers / columns) * 53 - 3
    panel.previewSpacer:setHeight(math.max(imagePanel:getHeight(), offersHeight))
    for _, offer in ipairs(offers) do
        local offerPanel = g_ui.createWidget('OfferPanel2', offerStackPanel)

        local priceLabel = offerPanel:getChildById('lblPrice')
        priceLabel:setText(offer.price)

        local itemCount = (offer.count and offer.count > 0) and offer.count or 1
        if itemCount > 1 then
            offerPanel:getChildById('btnBuy'):setText("Buy " .. itemCount .. "x")
        end

        if product.configurable then
            offerPanel:getChildById('btnBuy'):setText(HirelingStore.isHireling(product) and "Configure" or "Configurable")
        end

        local isTransferable = offer.coinType == GameStore.CoinType.Transferable
        local currentBalance = isTransferable and transferableCoins or (normalCoins + transferableCoins)
        if HirelingStore.isHireling(product) then
            currentBalance = HirelingStore.spendableBalance(offer, normalCoins, transferableCoins)
        end

        if isTransferable then
            priceLabel:setIcon("/game_store/images/icon-tibiacointransferable")
        else
            priceLabel:setIcon("images/ui/tibiaCoin")
        end

        if currentBalance < offer.price then
            priceLabel:setColor("#d33c3c")
            offerPanel:getChildById('btnBuy'):disable()
        else
            priceLabel:setColor("white")
            offerPanel:getChildById('btnBuy'):enable()
        end

        if offer.disabled then
            local btnBuy = offerPanel:getChildById('btnBuy')
            btnBuy:disable()
            btnBuy:setOpacity(0.8)
            renderDescription(panel, description,
                "The product is currently not available for this character. See the buy button tooltip for details.")
            if offer.reasonIdDisable then
                local tooltipOverlay = g_ui.createWidget('UIWidget', offerPanel)
                tooltipOverlay:setId('tooltipOverlay')
                tooltipOverlay:setFocusable(false)
                tooltipOverlay:setSize(btnBuy:getSize())
                tooltipOverlay:setPosition(btnBuy:getPosition())
                local reasonText = oldProtocol and offer.reasonIdDisable or reasonCategory[offer.reasonIdDisable + 1]
                tooltipOverlay:parseColoreDisplayToolTip(string.format(
                    "[color=#ff0000]The product is not available for this character:\n\n- %s[/color]",
                    reasonText
                ))
                tooltipOverlay:setOpacity(0)
                tooltipOverlay:addAnchor(AnchorLeft, btnBuy:getId(), AnchorLeft)
                tooltipOverlay:addAnchor(AnchorTop, btnBuy:getId(), AnchorTop)
            end
        end

        -- 👇 Confirmação corrigida
        offerPanel:getChildById('btnBuy').onClick = function(widget)
            if acceptWindow then
                destroyWindow(acceptWindow)
            end

            if HirelingStore.isHireling(product) then
                return HirelingStore.open(offer, product, controllerShop.ui, function()
                    local total, transferable = getCoinsBalance()
                    return HirelingStore.spendableBalance(offer, total, transferable)
                end)
            end

            if product.configurable or product.name == "Character Name Change" then
                return displayChangeName(offer)
            end

            local function acceptFunc()
                fixServerNoSend0xF2()
                local latestNormal, latestTransferable = getCoinsBalance()
                local latestCurrentBalance = isTransferable and latestTransferable or (latestNormal + latestTransferable)

                if latestCurrentBalance >= offer.price then
                    g_game.buyStoreOffer(offer.id, GameStore.ClientOfferTypes.CLIENT_STORE_OFFER_OTHER)
                    local closeWindow = function() destroyWindow(processingWindow) end
                    controllerShop.ui:hide()
                    processingWindow = displayGeneralBox(
                        'Processing purchase.', 
                        'Your purchase is being processed',
                        {
                          { text = tr('ok'),  callback = closeWindow },
                          anchor = 50
                        }, 
                        closeWindow, 
                        closeWindow
                    )
                else
                    displayErrorBox(controllerShop.ui:getText(), tr("You don't have enough coins"))
                end
                destroyWindow(acceptWindow)
            end

            local function cancelFunc()
                destroyWindow(acceptWindow)
            end

            local coinType = isTransferable and "transferable coins" or "regular coins"
            local confirmationMessage = string.format(
                'Do you want to buy the product "%s" for %d %s?', 
                product.name, 
                offer.price, 
                coinType
            )

            local itemCountConfirm = (offer.count and offer.count > 0) and offer.count or 1
            local detailsMessage = string.format(
                "%dx %s\nPrice: %d %s",
                itemCountConfirm,
                product.name,
                offer.price,
                coinType
            )

            acceptWindow = displayGeneralSHOPBox(
                tr('Confirmation of Purchase'),
                confirmationMessage,
                detailsMessage,
                {
                    { text = tr('Buy'), callback = acceptFunc },
                    { text = tr('Cancel'), callback = cancelFunc },
                    anchor = AnchorHorizontalCenter
                },
                acceptFunc,
                cancelFunc
            )
            if data then
                createProductImage(acceptWindow.Box, data)
            end
        end
    end
end


-- /*=============================================
-- =            Home                             =
-- =============================================*/

function chooseHome(self, focusedChild)
    if not focusedChild then
        return
    end
    local product = focusedChild.product
    g_game.sendRequestStoreOfferById(product.id)
end

-- /*=============================================
-- =            Behavior  Change Name            =
-- =============================================*/

function displayChangeName(offer)
    controllerShop.ui:hide()
    g_game.buyStoreOffer(offer.id, GameStore.ClientOfferTypes.CLIENT_STORE_OFFER_OTHER) -- canary send this packets?
    destroyWindow(changeNameWindow)
    changeNameWindow = g_ui.displayUI('style/changename')
    changeNameWindow:show()
    local newName = changeNameWindow:getChildById('transferPointsText')
    newName:setText('')
    local function closeWindow()
        newName:setText('')
        changeNameWindow:setVisible(false)
    end
    changeNameWindow.closeButton.onClick = closeWindow
    changeNameWindow.buttonOk.onClick = function()
        g_game.buyStoreOffer(offer.id, GameStore.ClientOfferTypes.CLIENT_STORE_OFFER_NAMECHANGE,newName:getText() )
        closeWindow()
    end
    changeNameWindow.onEscape = function()
        destroyWindow(changeNameWindow)
    end
end

-- /*=============================================
-- =            Button TransferPoints            =
-- =============================================*/

function transferPoints()
    destroyWindow(transferPointsWindow)
    transferPointsWindow = g_ui.displayUI('style/transferpoints')
    transferPointsWindow:show()

    local playerBalance = g_game.getLocalPlayer():getResourceBalance(ResourceTypes.COIN_TRANSFERRABLE)
    fixServerNoSend0xF2()

    local normalCoins, transferableCoins = getCoinsBalance()

    if playerBalance == 0 then
        playerBalance = transferableCoins -- temp fix canary 1340
    end

    transferPointsWindow.giftable:setText(formatNumberWithCommas(playerBalance))

    local initialValue, minimumValue = 0, 0
    if playerBalance >= 25 then
        initialValue = 25
        minimumValue = 25
    end

    transferPointsWindow.amountBar:setStep(25)
    transferPointsWindow.amountBar:setMinimum(minimumValue)
    local maxStep = math.floor(playerBalance / 25) * 25 -- coins multiple 25
    transferPointsWindow.amountBar:setMaximum(maxStep)
    transferPointsWindow.amountBar:setValue(initialValue)
    transferPointsWindow.amount:setText(formatNumberWithCommas(initialValue))

    local sliderButton = transferPointsWindow.amountBar:getChildById('sliderButton')
    if sliderButton then
        sliderButton:setEnabled(true)
        sliderButton:setVisible(true)
    end

    transferPointsWindow.onEscape = function()
        destroyWindow(transferPointsWindow)
    end

    local lastDisplayedValue = initialValue
    transferPointsWindow.amountBar.onValueChange = function(scrollbar, value)
        -- Round to the nearest multiple of 25
        local val = math.floor((value + 12) / 25) * 25
        
        -- Only update the display if the value has changed
        if val ~= lastDisplayedValue then
            lastDisplayedValue = val
            transferPointsWindow.amount:setText(formatNumberWithCommas(val))
        end
    end

    transferPointsWindow.closeButton.onClick = function()
        destroyWindow(transferPointsWindow)
    end

    transferPointsWindow.buttonOk.onClick = function()
        local receipient = transferPointsWindow.transferPointsText:getText():trim()
        local amount = transferPointsWindow.amountBar:getValue()

        if receipient:len() < 3 then
            return
        end
        if amount < 1 or playerBalance < amount then
            return
        end

        g_game.transferCoins(receipient, amount)
        destroyWindow(transferPointsWindow)
    end
end




-- /*=============================================
-- =            Search Button            =
-- =============================================*/

function search(searchText)
    searchText = (searchText or controllerShop.ui.SearchEdit:getText()):trim()
    if searchText == "" then
        g_game.sendRequestStoreHome()
        return
    end
    if  controllerShop.ui.openedCategory ~= nil then
        close(controllerShop.ui.openedCategory)
    end
    local sortOption = controllerShop.ui.panelItem.comboBoxContainer.MostPopularFirst:getCurrentOption()
    g_game.sendRequestStoreSearch(searchText, sortOption and tonumber(sortOption.data) or 0, 1)
end

function scheduleSearch(searchText)
    if searchEvent then
        removeEvent(searchEvent)
        searchEvent = nil
    end

    searchText = (searchText or ""):trim()
    if #searchText < 2 then
        return
    end

    searchEvent = controllerShop:scheduleEvent(function()
        searchEvent = nil
        search(searchText)
    end, 450)
end

function clearSearch()
    if searchEvent then
        removeEvent(searchEvent)
        searchEvent = nil
    end
    controllerShop.ui.SearchEdit:setText("")
    g_game.sendRequestStoreHome()
end
