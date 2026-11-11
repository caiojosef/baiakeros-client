HirelingStore = {}

local window
local confirmation
local purchase
local pending = false

local function formatNumberWithCommas(value)
    local text = tostring(math.floor(tonumber(value) or 0))
    local formatted = text:reverse():gsub('(%d%d%d)', '%1,'):reverse()
    return formatted:gsub('^,', '')
end

local function destroyConfirmation()
    if confirmation and not confirmation:isDestroyed() then
        confirmation:destroy()
    end
    confirmation = nil
end

local function normalizedName(text)
    return (text or ''):match('^%s*(.-)%s*$')
end

local function readConfiguration()
    local name = normalizedName(window.nameEdit:getText())
    if #name < 3 or #name > 18 then
        return nil, nil, tr('The name must contain 3 to 18 letters.')
    end
    if name:find('[^A-Za-z ]') then
        return nil, nil, tr('Use letters and at most one space in the name.')
    end
    local _, spaces = name:gsub(' ', '')
    if spaces > 1 then
        return nil, nil, tr('Use at most one space in the name.')
    end
    local option = window.gender:getCurrentOption()
    local sex = option and tonumber(option.data)
    if sex ~= 1 and sex ~= 2 then
        return nil, nil, tr('Choose Male or Female.')
    end
    return name, sex
end

-- The local server sends total coins and the transferable subset separately.
-- Regular-only offers use the remainder; transferable offers accept both balances.
function HirelingStore.spendableBalance(offer, total, transferable)
    total, transferable = tonumber(total) or 0, tonumber(transferable) or 0
    if offer.coinType == GameStore.CoinType.Coin then
        return math.max(0, total - transferable)
    end
    return math.max(0, total)
end

function HirelingStore.isHireling(product)
    return product and (product.type == 4 or product.name == 'Hireling Apprentice')
end

function HirelingStore.refresh()
    if not purchase or not window or window:isDestroyed() then
        return
    end
    local name, sex, message = readConfiguration()
    local balance = purchase.balance()
    window.balance:setText(tr('Available: %s coins', formatNumberWithCommas(balance)))
    window.buy:setEnabled(not pending and name ~= nil and balance >= purchase.offer.price)
    if pending then
        message = tr('Purchase sent. Waiting for the server...')
    elseif balance < purchase.offer.price then
        message = tr('You need %s coins to buy this hireling.', formatNumberWithCommas(purchase.offer.price))
    elseif purchase.serverError then
        message = purchase.serverError
    elseif not purchase.edited then
        message = nil
    end
    window.message:setText(message or tr('Use 3 to 18 letters and at most one space. The server checks restricted names.'))
    window.message:setColor(message and not pending and '#e69a91' or '#c0c0c0')
    local female = sex == 2 or (window.gender:getCurrentOption() and window.gender:getCurrentOption().data == 2)
    local product = purchase.product
    window.preview:setOutfit({
        type = female and (product.femaleOutfitId or 136) or (product.maleOutfitId or 128),
        head = product.outfitHead or 0, body = product.outfitBody or 0,
        legs = product.outfitLegs or 0, feet = product.outfitFeet or 0
    })
    window.previewCaption:setText(female and tr('Female') or tr('Male'))
end

function HirelingStore.onChange()
    if purchase and not purchase.initializing and not pending then
        purchase.edited = true
        purchase.serverError = nil
        HirelingStore.refresh()
    end
end

function HirelingStore.close(force)
    destroyConfirmation()
    if window and not window:isDestroyed() then
        window:destroy()
    end
    window = nil
    if purchase and purchase.parent and not purchase.parent:isDestroyed() and purchase.parent:isVisible() and not force then
        purchase.parent:raise()
        purchase.parent:focus()
    end
    purchase = nil
    if force then
        pending = false
    end
end

function HirelingStore.open(offer, product, parent, balanceProvider)
    if pending then
        displayErrorBox(tr('Hireling'), tr('A hireling purchase is still pending. Wait for the server response.'))
        return false
    end
    if not offer or not tonumber(offer.id) or not tonumber(offer.price) or offer.price < 0 or offer.disabled then
        return false
    end
    HirelingStore.close(true)
    purchase = {
        offer = {id = offer.id, price = offer.price, coinType = offer.coinType},
        product = product or {}, parent = parent, balance = balanceProvider,
        initializing = true, edited = false
    }
    window = g_ui.displayUI('style/hireling')
    window.gender:addOption(tr('Male'), 1)
    window.gender:addOption(tr('Female'), 2)
    window.gender:setCurrentOption((product and product.sex == 2) and tr('Female') or tr('Male'))
    window.price:setText(tr('Price: %s coins', formatNumberWithCommas(offer.price)))
    purchase.initializing = false
    HirelingStore.refresh()
    window:lock()
    window:raise()
    window.nameEdit:focus()
    return true
end

function HirelingStore.confirm()
    if pending or confirmation or not purchase or not window then
        return
    end
    purchase.edited = true
    HirelingStore.refresh()
    local name, sex = readConfiguration()
    if not name or purchase.balance() < purchase.offer.price then
        return
    end
    local current = purchase
    local function cancel()
        destroyConfirmation()
        if window and not window:isDestroyed() then
            window:raise()
            window.nameEdit:focus()
        end
    end
    local function submit()
        if pending or purchase ~= current then
            return
        end
        destroyConfirmation()
        if not g_game.isOnline() or not g_game.getLocalPlayer() then
            current.serverError = tr('Log in again before completing this purchase.')
            HirelingStore.refresh()
            return
        end
        if current.balance() < current.offer.price then
            current.serverError = tr('Your balance changed. You do not have enough coins.')
            HirelingStore.refresh()
            return
        end
        pending = true
        window.nameEdit:disable()
        window.gender:disable()
        window.cancel:setText(tr('Close'))
        HirelingStore.refresh()
        local ok = pcall(function()
            g_game.buyStoreOffer(current.offer.id, GameStore.ClientOfferTypes.CLIENT_STORE_OFFER_HIRELING, name, sex, '')
        end)
        if not ok then
            HirelingStore.onError(tr('The purchase could not be sent. Reopen the Store and try again.'))
        end
    end
    confirmation = displayGeneralBox(tr('Confirm Hireling'),
        tr('Hire %s (%s) for %s coins?\nThe magic lamp will be delivered to your Store Inbox.',
            name, sex == 2 and tr('Female') or tr('Male'), formatNumberWithCommas(current.offer.price)),
        {{text = tr('Buy'), callback = submit}, {text = tr('Cancel'), callback = cancel}}, submit, cancel)
    rootWidget:lockChild(confirmation)
    confirmation:raise()
    confirmation:focus()
end

function HirelingStore.onError(message)
    if not pending then
        return false
    end
    pending = false
    if purchase and window and not window:isDestroyed() then
        purchase.serverError = message
        window.nameEdit:enable()
        window.gender:enable()
        window.cancel:setText(tr('Cancel'))
        HirelingStore.refresh()
        window:raise()
        window.nameEdit:focus()
        return true
    end
    return false
end

function HirelingStore.onSuccess()
    if pending then
        HirelingStore.close(true)
    end
end

function HirelingStore.getWindow()
    return window
end
