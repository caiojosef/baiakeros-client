local UI = nil

function showHouse()
    UI = g_ui.loadUI("house", contentContainer)
    UI:show()
    UI.LateralBase.LayerScrollbar.decrementButton:setVisible(false)
    UI.LateralBase.LayerScrollbar.incrementButton:setVisible(false)
    UI.LateralBase.LayerScrollbar.sliderButton:setImageSource("")
    --[[
    g_ui.createWidget("MapLayerSelector", UI.LateralBase.LayerScrollbar.sliderButton)
    function UI.LateralBase.LayerScrollbar:onValueChange(value)
        local rect = {
            width = 14,
            height = 67,
            y = 0,
            x = Cyclopedia.ConvertLayer(value) * 14
        }

        UI.LateralBase.LayerIndicator:setImageClip(rect)
    end
    ]]--

    UI.LateralBase.LayerScrollbar:setValue(150)

    controllerCyclopedia.ui.CharmsBase:setVisible(false)
    controllerCyclopedia.ui.GoldBase:setVisible(true)
    controllerCyclopedia.ui.BestiaryTrackerButton:setVisible(false)
    if g_game.getClientVersion() >= 1410 then
        controllerCyclopedia.ui.CharmsBase1410:setVisible(false)
    end
    if not Cyclopedia.House.Loaded then
        for i = 1, #Cyclopedia.StateList do
            UI.TopBase.StatesOption:addOption(Cyclopedia.StateList[i].Title, i)
            UI.TopBase.StatesOption.onOptionChange = Cyclopedia.houseChangeState
        end

        for i = 0, #Cyclopedia.CityList do
            UI.TopBase.CityOption:addOption(Cyclopedia.CityList[i].Title, i)
            UI.TopBase.CityOption.onOptionChange = Cyclopedia.selectTown
        end

        for i = 1, #Cyclopedia.SortList do
            UI.TopBase.SortOption:addOption(Cyclopedia.SortList[i].Title, i)
            UI.TopBase.SortOption.onOptionChange = Cyclopedia.houseSort
        end

        Cyclopedia.House.Loaded = true
        Cyclopedia.houseFilter(UI.TopBase.HousesCheck)
    end

    UI.bidArea:setVisible(false)
    UI.ListBase:setVisible(true)
    UI.TopBase.StatesOption:setOption("All States", true)
    UI.TopBase.CityOption:setOption("Luna", true)
    UI.TopBase.SortOption:setOption("Sort by name", true)
    Cyclopedia.selectTown(nil, "Luna", 1)
end

Cyclopedia.House = {}
Cyclopedia.StateList = {
    { Title = "All States" },
    { Title = "Auctioned" },
    { Title = "Rented" }
}

Cyclopedia.CityList = {
    [0] = { Title = "Own Houses" },
    { Title = "Luna" }
}

Cyclopedia.House.Definitions = {
    [65024] = { name = "Raven Lodge", sqm = 47 },
    [65025] = { name = "Luna Residence 01", sqm = 16 },
    [65026] = { name = "Luna Residence 02", sqm = 16 },
    [65027] = { name = "Luna Residence 03", sqm = 16 },
    [65028] = { name = "Luna Residence 04", sqm = 16 },
    [65029] = { name = "Luna Residence 05", sqm = 16 },
    [65030] = { name = "Luna Residence 06", sqm = 16 },
    [65031] = { name = "Luna Residence 07", sqm = 31 },
    [65032] = { name = "Luna Residence 08", sqm = 21 },
    [65033] = { name = "Luna Residence 09", sqm = 16 },
    [65034] = { name = "Luna Residence 10", sqm = 16 },
    [65035] = { name = "Luna Residence 11", sqm = 16 },
    [65036] = { name = "Luna Residence 12", sqm = 43 },
    [65037] = { name = "Luna Residence 13", sqm = 22 },
    [65038] = { name = "Luna Residence 14", sqm = 10 },
    [65039] = { name = "Luna Residence 15", sqm = 12 },
    [65040] = { name = "Luna Residence 16", sqm = 12 },
    [65041] = { name = "Luna Residence 17", sqm = 26 },
    [65042] = { name = "Luna Residence 18", sqm = 16 },
    [65043] = { name = "Luna Residence 19", sqm = 13 },
    [65044] = { name = "Luna Residence 20", sqm = 33 },
    [65045] = { name = "Luna Residence 21", sqm = 24 },
    [65046] = { name = "Luna Residence 22", sqm = 25 }
}

for _, house in pairs(Cyclopedia.House.Definitions) do
    house.description = "House located in Luna."
    house.rent = math.max(house.sqm * 10000, 100000)
    house.beds = 0
    house.gh = false
    house.shop = false
end

Cyclopedia.SortList = {
    { Title = "Sort by name" },
    { Title = "Sort by size" },
    { Title = "Sort by rent" },
    { Title = "Sort by bid" },
    { Title = "Sort by auction end" }
}

local function resetButtons()
    if UI.LateralBase:getChildById("bidButton") then
        UI.LateralBase:getChildById("bidButton"):destroy()
    end

    if UI.LateralBase:getChildById("transferButton") then
        UI.LateralBase:getChildById("transferButton"):destroy()
    end

    if UI.LateralBase:getChildById("moveOutButton") then
        UI.LateralBase:getChildById("moveOutButton"):destroy()
    end

    if UI.LateralBase:getChildById("cancelMoveOutButton") then
        UI.LateralBase:getChildById("cancelMoveOutButton"):destroy()
    end

    if UI.LateralBase:getChildById("cancelTransfer") then
        UI.LateralBase:getChildById("cancelTransfer"):destroy()
    end

    if UI.LateralBase:getChildById("acceptTransfer") then
        UI.LateralBase:getChildById("acceptTransfer"):destroy()
    end

    if UI.LateralBase:getChildById("rejectTransfer") then
        UI.LateralBase:getChildById("rejectTransfer"):destroy()
    end
end

local function resetSelectedInfo()
    UI.LateralBase.yourLimitBidGold:setVisible(false)
    UI.LateralBase.yourLimitBid:setVisible(false)
    UI.LateralBase.yourLimitLabel:setVisible(false)
    UI.LateralBase.highestBid:setVisible(false)
    UI.LateralBase.highestBidGold:setVisible(false)
    UI.LateralBase.subAuctionLabel:setVisible(false)
    UI.LateralBase.subAuctionText:setVisible(false)
    UI.LateralBase.transferLabel:setVisible(false)
    UI.LateralBase.transferValue:setVisible(false)
    UI.LateralBase.transferGold:setVisible(false)
end

function Cyclopedia.houseChangeState(widget)
    if Cyclopedia.House.Data then
        local onlyGuildHall = UI.TopBase.GuildhallsCheck:isChecked()
        local type = widget:getCurrentOption().data
        for _, data in ipairs(Cyclopedia.House.Data) do
            if onlyGuildHall then
                data.visible = data.gh
            elseif type == 3 then
                data.visible = data.rented or data.inTransfer
            elseif type == 2 then
                data.visible = not data.rented
            else
                data.visible = true
            end
        end

        Cyclopedia.reloadHouseList()
        Cyclopedia.House.lastChangeState = widget
    end
end

function Cyclopedia.houseMessage(houseId, type, message)
    local confirmWindow
    local function refreshHouseList()
        if g_game.isOnline() then
            g_game.sendCyclopediaHouseAuction(0, 0, 0, 0, Cyclopedia.House.lastTown or "Luna")
        end
    end

    local function yesCallback()
        if confirmWindow then
            confirmWindow:destroy()
            confirmWindow = nil
            Cyclopedia.Toggle(true, false, 5)
        end
        refreshHouseList()
    end

    if type == 1 then
        if message == 0 then
            if not confirmWindow then
                confirmWindow = displayGeneralBox(tr("Summary"), tr(
                    "Your bid was successfull. You are currently holding the highest bid."), {
                    {
                        text = tr("Ok"),
                        callback = yesCallback
                    },
                    anchor = AnchorHorizontalCenter
                }, yesCallback)

                UI.ListBase:setVisible(true)
                UI.bidArea:setVisible(false)
                Cyclopedia.Toggle(true, false)
            end
        elseif message == 17 then
            confirmWindow = displayGeneralBox(tr("Summary"), tr(
                "Bid failed.\nYour character's bank acocunt balance is too low to pay the bid and the rent for the first month."),
                {
                    {
                        text = tr("Ok"),
                        callback = yesCallback
                    },
                    anchor = AnchorHorizontalCenter
                }, yesCallback)

            UI.ListBase:setVisible(true)
            UI.bidArea:setVisible(false)
            Cyclopedia.Toggle(true, false)
        elseif message == 26 then
            confirmWindow = displayGeneralBox(tr("Summary"), tr(
                "Bid failed.\nYou need to be at least level 300 to bid on a house."), {{
                    text = tr("Ok"),
                    callback = yesCallback
                }, anchor = AnchorHorizontalCenter}, yesCallback)

            UI.ListBase:setVisible(true)
            UI.bidArea:setVisible(false)
            Cyclopedia.Toggle(true, false)
        else
            confirmWindow = displayGeneralBox(tr("Summary"), tr(
                "The house action failed. Please refresh the list and check the auction requirements."), {{
                    text = tr("Ok"),
                    callback = yesCallback
                }, anchor = AnchorHorizontalCenter}, yesCallback)
            UI.ListBase:setVisible(true)
            UI.bidArea:setVisible(false)
            Cyclopedia.Toggle(true, false)
        end
    elseif type == 2 then
        if message == 0 then
            confirmWindow = displayGeneralBox(tr("Summary"), tr(
                "Your move out was scheduled for the next Server Save."), {
                {
                    text = tr("Ok"),
                    callback = yesCallback
                },
                anchor = AnchorHorizontalCenter
            }, yesCallback)

            UI.moveOutArea:setVisible(false)
            UI.ListBase:setVisible(true)
            Cyclopedia.Toggle(true, false)
        end
    elseif type == 4 then
        if message == 0 then
            confirmWindow = displayGeneralBox(tr("Summary"), tr(
                "Your pending move out was cancelled. You will keep the house."), {{
                    text = tr("Ok"),
                    callback = yesCallback
                }, anchor = AnchorHorizontalCenter}, yesCallback)
            UI.ListBase:setVisible(true)
            Cyclopedia.Toggle(true, false)
        end
    elseif type == 3 then
        if message == 0 then
            confirmWindow = displayGeneralBox(tr("Summary"),
                tr("Your house transfer was scheduled for the next Server Save."), {
                    {
                        text = tr("Ok"),
                        callback = yesCallback
                    },
                    anchor = AnchorHorizontalCenter
                }, yesCallback)

            UI.transferArea:setVisible(false)
            UI.ListBase:setVisible(true)
            Cyclopedia.Toggle(true, false)
        elseif message == 4 then
            confirmWindow = displayGeneralBox(tr("Summary"), tr(
                "Setting up a house transfer failed.\nA character with this name does not exist."), {
                {
                    text = tr("Ok"),
                    callback = yesCallback
                },
                anchor = AnchorHorizontalCenter
            }, yesCallback)

            UI.transferArea:setVisible(false)
            UI.ListBase:setVisible(true)
            Cyclopedia.Toggle(true, false)
        end
    elseif type == 5 then
        if message == 0 then
            confirmWindow = displayGeneralBox(tr("Summary"), tr(
                "You have sucessfully cancelled the transfer. You will keep the house."), {
                {
                    text = tr("Ok"),
                    callback = yesCallback
                },
                anchor = AnchorHorizontalCenter
            }, yesCallback)

            UI.cancelHouseTransferArea:setVisible(false)
            UI.ListBase:setVisible(true)
            Cyclopedia.Toggle(true, false)
        end
    elseif type == 6 then
        if message == 0 then
            confirmWindow = displayGeneralBox(tr("Summary"), tr("You have sucessfully accepted the transfer."), {
                {
                    text = tr("Ok"),
                    callback = yesCallback
                },
                anchor = AnchorHorizontalCenter
            }, yesCallback)

            UI.acceptTransferHouse:setVisible(false)
            UI.ListBase:setVisible(true)
            Cyclopedia.Toggle(true, false)
        end
    elseif type == 7 and message == 0 then
        confirmWindow = displayGeneralBox(tr("Summary"), tr(
            "You rejected the house transfer successfully. The current owner will keep the house."), {
            {
                text = tr("Ok"),
                callback = yesCallback
            },
            anchor = AnchorHorizontalCenter
        }, yesCallback)

        UI.rejectTransferHouse:setVisible(false)
        UI.ListBase:setVisible(true)
        Cyclopedia.Toggle(true, false)
    end

    if not confirmWindow then
        confirmWindow = displayGeneralBox(tr("Summary"), tr(
            "The house action failed. Refresh the list and verify the house requirements."), {{
            text = tr("Ok"),
            callback = yesCallback
        }, anchor = AnchorHorizontalCenter}, yesCallback)
        UI.ListBase:setVisible(true)
        Cyclopedia.Toggle(true, false)
    end
end

function Cyclopedia.cancelMoveOut()
    local house = Cyclopedia.House.lastSelectedHouse.data
    local confirmWindow

    local function closeConfirmation()
        if confirmWindow then
            confirmWindow:destroy()
            confirmWindow = nil
        end
    end

    local function yesCallback()
        closeConfirmation()
        g_game.sendCyclopediaHouseAuction(4, house.id, 0, 0, "")
    end

    if not confirmWindow then
        confirmWindow = displayGeneralBox(tr("Confirm House Action"), tr(
            "Do you want to cancel the pending move out for '%s'?\nYou will keep the house.", house.name), {{
                text = tr("Yes"),
                callback = yesCallback
            }, {
                text = tr("No"),
                callback = closeConfirmation
            }, anchor = AnchorHorizontalCenter}, yesCallback, closeConfirmation)
    end
end

function Cyclopedia.rejectTransfer()
    UI.ListBase:setVisible(false)
    UI.rejectTransferHouse:setVisible(true)

    local house = Cyclopedia.House.lastSelectedHouse.data
    local time = os.date("%Y-%m-%d, %H:%M CET", house.paidUntil)
    local transferTime = os.date("%Y-%m-%d, %H:%M CET", house.transferTime)

    function UI.rejectTransferHouse.cancel.onClick()
        UI.rejectTransferHouse:setVisible(false)
        UI.ListBase:setVisible(true)
    end

    function UI.rejectTransferHouse.transfer:onClick()
        local confirmWindow
        local function yesCallback()
            if confirmWindow then
                confirmWindow:destroy()
                confirmWindow = nil
                Cyclopedia.Toggle(true, false, 5)
            end

            g_game.sendCyclopediaHouseAuction(7, house.id, 0, 0, "")
            --[[
            if Cyclopedia.House.lastTown then
                g_game.requestShowHouses(Cyclopedia.House.lastTown)
            else
                g_game.requestShowHouses("")
            end
            ]]--

            UI.TopBase.StatesOption:setOption("All States", true)
            UI.TopBase.SortOption:setOption("Sort by name", true)
        end

        local function noCallback()
            if confirmWindow then
                confirmWindow:destroy()
                confirmWindow = nil
                Cyclopedia.Toggle(true, false, 5)
            end
        end

        if not confirmWindow then
            confirmWindow = displayGeneralBox(tr("Confirm House Action"), tr(
                "Do you really want to reject the transfer for the house '%s' offered by %s?\nYou will not get the house. %s will keep the house and can set up a new transfer anytime.",
                house.name, house.owner, house.owner), {
                {
                    text = tr("Yes"),
                    callback = yesCallback
                },
                {
                    text = tr("No"),
                    callback = noCallback
                },
                anchor = AnchorHorizontalCenter
            }, yesCallback, noCallback)

            Cyclopedia.Toggle(true, false)
        end
    end

    UI.rejectTransferHouse.name:setText(house.name)
    UI.rejectTransferHouse.size:setText(house.sqm .. " sqm")
    UI.rejectTransferHouse.beds:setText(house.beds)
    UI.rejectTransferHouse.rent:setText((house.rent))
    UI.rejectTransferHouse.paid:setText(time)
    UI.rejectTransferHouse.owner:setText(house.transferName)
    UI.rejectTransferHouse.transferDate:setText(transferTime)
    UI.rejectTransferHouse.transferPrice:setText(comma_value(house.transferValue))
end

function Cyclopedia.acceptTransfer()
    UI.ListBase:setVisible(false)
    UI.acceptTransferHouse:setVisible(true)

    local house = Cyclopedia.House.lastSelectedHouse.data
    local time = os.date("%Y-%m-%d, %H:%M CET", house.paidUntil)
    local transferTime = os.date("%Y-%m-%d, %H:%M CET", house.transferTime)

    function UI.acceptTransferHouse.cancel.onClick()
        UI.acceptTransferHouse:setVisible(false)
        UI.ListBase:setVisible(true)
    end

    function UI.acceptTransferHouse.transfer:onClick()
        local confirmWindow

        local function yesCallback()
            if confirmWindow then
                confirmWindow:destroy()
                confirmWindow = nil
                Cyclopedia.Toggle(true, false, 5)
            end

            g_game.sendCyclopediaHouseAuction(6, house.id, 0, 0, "")

            -- g_game.requestShowHouses("")
            UI.TopBase.StatesOption:setOption("All States", true)
            UI.TopBase.SortOption:setOption("Sort by name", true)
        end

        local function noCallback()
            if confirmWindow then
                confirmWindow:destroy()
                confirmWindow = nil
                Cyclopedia.Toggle(true, false, 5)
            end
        end

        if not confirmWindow then
            confirmWindow = displayGeneralBox(tr("Confirm House Action"), tr(
                "Do you want to accept the house transfer offered by %s for the property '%s'?\nThe transfer is scheduled for %s.\nThe transfer price was set to %s.\n\nMake sure to have enough gold in your bank account to pay the costs for this house transfer and the next rent.\nRemember to edit the door rights as only the guest list will be reset after the transfer!",
                house.owner, house.name, transferTime, comma_value(house.transferValue)), {
                {
                    text = tr("Yes"),
                    callback = yesCallback
                },
                {
                    text = tr("No"),
                    callback = noCallback
                },
                anchor = AnchorHorizontalCenter
            }, yesCallback, noCallback)

            Cyclopedia.Toggle(true, false)
        end
    end

    UI.acceptTransferHouse.name:setText(house.name)
    UI.acceptTransferHouse.size:setText(house.sqm .. " sqm")
    UI.acceptTransferHouse.beds:setText(house.beds)
    UI.acceptTransferHouse.rent:setText((house.rent))
    UI.acceptTransferHouse.paid:setText(time)
    UI.acceptTransferHouse.owner:setText(house.transferName)
    UI.acceptTransferHouse.transferDate:setText(transferTime)
    UI.acceptTransferHouse.transferPrice:setText(comma_value(house.transferValue))
end

function Cyclopedia.cancelTransfer()
    UI.ListBase:setVisible(false)
    UI.cancelHouseTransferArea:setVisible(true)

    local house = Cyclopedia.House.lastSelectedHouse.data
    local time = os.date("%Y-%m-%d, %H:%M CET", house.paidUntil)
    local transferTime = os.date("%Y-%m-%d, %H:%M CET", house.transferTime)

    function UI.cancelHouseTransferArea.cancel.onClick()
        UI.cancelHouseTransferArea:setVisible(false)
        UI.ListBase:setVisible(true)
    end

    function UI.cancelHouseTransferArea.transfer:onClick()
        local confirmWindow

        local function yesCallback()
            if confirmWindow then
                confirmWindow:destroy()
                confirmWindow = nil
                Cyclopedia.Toggle(true, false, 5)
            end

            g_game.sendCyclopediaHouseAuction(5, house.id, 0, 0, "")
            --[[
            if Cyclopedia.House.lastTown then
                g_game.requestShowHouses(Cyclopedia.House.lastTown)
            else
                g_game.requestShowHouses("")
            end
            ]]--

            UI.TopBase.StatesOption:setOption("All States", true)
            UI.TopBase.SortOption:setOption("Sort by name", true)
        end

        local function noCallback()
            if confirmWindow then
                confirmWindow:destroy()
                confirmWindow = nil
                Cyclopedia.Toggle(true, false, 5)
            end
        end

        if not confirmWindow then
            confirmWindow = displayGeneralBox(tr("Confirm House Action"),
                tr("Do you really want to keep your house '%s'?\nYou will no longer transfer the house to %s on %s.",
                    house.name, house.transferName, transferTime), {
                    {
                        text = tr("Yes"),
                        callback = yesCallback
                    },
                    {
                        text = tr("No"),
                        callback = noCallback
                    },
                    anchor = AnchorHorizontalCenter
                }, yesCallback, noCallback)

            Cyclopedia.Toggle(true, false)
        end
    end

    UI.cancelHouseTransferArea.name:setText(house.name)
    UI.cancelHouseTransferArea.size:setText(house.sqm .. " sqm")
    UI.cancelHouseTransferArea.beds:setText(house.beds)
    UI.cancelHouseTransferArea.rent:setText((house.rent))
    UI.cancelHouseTransferArea.paid:setText(time)
    UI.cancelHouseTransferArea.owner:setText(house.transferName)
    UI.cancelHouseTransferArea.transferDate:setText(transferTime)
    UI.cancelHouseTransferArea.transferPrice:setText(comma_value(house.transferValue))
end

function Cyclopedia.transferHouse()
    if UI.moveOutArea:isVisible() then
        UI.moveOutArea:setVisible(false)
    end

    local house = Cyclopedia.House.lastSelectedHouse.data
    local time = os.date("%Y-%m-%d, %H:%M CET", house.paidUntil)

    local function updateTransferButton()
        local owner = UI.transferArea.owner:getText()
        local price = tonumber(UI.transferArea.price:getText())
        UI.transferArea.errorName:setVisible(owner == "")
        UI.transferArea.transfer:setEnabled(owner ~= "" and price ~= nil and price >= 0)
    end

    local function verifyName(widget, text, oldText)
        updateTransferButton()
    end

    UI.ListBase:setVisible(false)
    UI.transferArea:setVisible(true)

    function UI.transferArea.cancel.onClick()
        UI.transferArea:setVisible(false)
        UI.ListBase:setVisible(true)
    end

    function UI.transferArea.transfer:onClick()
        local confirmWindow
        local transfer = UI.transferArea.owner:getText()
        local value = UI.transferArea.price:getText()

        local function yesCallback()
            if confirmWindow then
                confirmWindow:destroy()
                confirmWindow = nil
                Cyclopedia.Toggle(true, false, 5)
            end

            g_game.sendCyclopediaHouseAuction(3, house.id, 0, tonumber(value), transfer)
            --[[
            if Cyclopedia.House.lastTown then
                g_game.requestShowHouses(Cyclopedia.House.lastTown)
            else
                g_game.requestShowHouses("")
            end
            ]]--

            UI.TopBase.StatesOption:setOption("All States", true)
            UI.TopBase.SortOption:setOption("Sort by name", true)
        end

        local function noCallback()
            if confirmWindow then
                confirmWindow:destroy()
                confirmWindow = nil
                Cyclopedia.Toggle(true, false, 5)
            end
        end

        if not confirmWindow then
            confirmWindow = displayGeneralBox(tr("Confirm House Action"), tr(
                "Do you really want to transfer your house '%s' to %s?\nThe transfer is scheduled for the next Server Save.\nYou have set the transfer price to %s.\n\nThe transfer will only take place if %s accepts it.",
                house.name, transfer, comma_value(value), transfer), {
                {
                    text = tr("Yes"),
                    callback = yesCallback
                },
                {
                    text = tr("No"),
                    callback = noCallback
                },
                anchor = AnchorHorizontalCenter
            }, yesCallback, noCallback)

            Cyclopedia.Toggle(true, false)
        end
    end

    UI.transferArea.name:setText(house.name)
    UI.transferArea.size:setText(house.sqm .. " sqm")
    UI.transferArea.beds:setText(house.beds)
    UI.transferArea.rent:setText((house.rent))
    UI.transferArea.paid:setText(time)
    UI.transferArea.serverSave:setText("Next Server Save")
    UI.transferArea.owner.onTextChange = verifyName
    UI.transferArea.owner:setText("")
    UI.transferArea.price:setText(0)

    function UI.transferArea.price:onTextChange(text, oldText)
        local convertedText = tonumber(text)
        if text ~= "" and type(convertedText) ~= "number" then
            self:setText(oldText)
        end

        updateTransferButton()
    end
    updateTransferButton()
end

function Cyclopedia.moveOutHouse()
    if UI.transferArea:isVisible() then
        UI.transferArea:setVisible(false)
    end

    local house = Cyclopedia.House.lastSelectedHouse.data
    local time = os.date("%Y-%m-%d, %H:%M CET", house.paidUntil)

    UI.ListBase:setVisible(false)
    UI.moveOutArea:setVisible(true)

    function UI.moveOutArea.cancel.onClick()
        UI.moveOutArea:setVisible(false)
        UI.ListBase:setVisible(true)
    end

    function UI.moveOutArea.move:onClick()
        local confirmWindow
        local function yesCallback()
            if confirmWindow then
                confirmWindow:destroy()
                confirmWindow = nil
                Cyclopedia.Toggle(true, false, 5)
            end

            g_game.sendCyclopediaHouseAuction(2, house.id, 0, 0, "")
        end

        local function noCallback()
            if confirmWindow then
                confirmWindow:destroy()
                confirmWindow = nil
                Cyclopedia.Toggle(true, false, 5)
            end
        end

        if not confirmWindow then
            confirmWindow = displayGeneralBox(tr("Confirm House Action"),
                tr("Do you really want to move out of the house '%s'?\nThe move out will happen at the next Server Save and all items left in the house will be sent to your depot inbox.", house.name), {
                    {
                        text = tr("Yes"),
                        callback = yesCallback
                    },
                    {
                        text = tr("No"),
                        callback = noCallback
                    },
                    anchor = AnchorHorizontalCenter
                }, yesCallback, noCallback)

            Cyclopedia.Toggle(true, false)
        end
    end

    UI.moveOutArea.name:setText(house.name)
    UI.moveOutArea.size:setText(house.sqm .. " sqm")
    UI.moveOutArea.beds:setText(house.beds)
    UI.moveOutArea.rent:setText((house.rent))
    UI.moveOutArea.paid:setText(time)
    UI.moveOutArea.serverSave:setText("Next Server Save")
end

function Cyclopedia.bidHouse(widget)
    if UI.transferArea:isVisible() then
        UI.transferArea:setVisible(false)
    end

    if UI.moveOutArea:isVisible() then
        UI.moveOutArea:setVisible(false)
    end

    local house = Cyclopedia.House.lastSelectedHouse.data
    local time = os.date("%Y-%m-%d, %H:%M CET", house.bidEnd)

    UI.ListBase:setVisible(false)
    UI.bidArea:setVisible(true)
    UI.bidArea.name:setText(house.name)
    UI.bidArea.size:setText(house.sqm .. " sqm")
    UI.bidArea.beds:setText(house.beds)
    UI.bidArea.rent:setText((house.rent))

    local labels = {{
        id = "hightestBidder",
        name = "Highest Bidder: ",
        value = house.bidName
    }, {
        id = "endTime",
        name = "End Time: ",
        value = time
    }, {
        id = "highestBid",
        name = "Highest Bid: ",
        value = house.hightestBid
    }}

    for _, value in ipairs(labels) do
        local child = UI.bidArea:getChildById(value.id)
        if child then
            child:destroy()
            UI.bidArea:getChildById(value.id .. "_value"):destroy()

            if UI.bidArea:getChildById("highestBid_gold") then
                UI.bidArea:getChildById("highestBid_gold"):destroy()
            end
        end
    end

    if UI.bidArea:getChildById("yourLimit") then
        UI.bidArea:getChildById("yourLimit"):destroy()
        UI.bidArea:getChildById("yourLimit_value"):destroy()
        UI.bidArea:getChildById("yourLimit_gold"):destroy()
    end

    if house.hasBid then
        for index, data in ipairs(labels) do
            local label = g_ui.createWidget("Label", UI.bidArea)
            label:setId(data.id)
            label:setText(data.name)
            label:setColor("#909090")
            label:setWidth(90)
            label:setHeight(15)
            label:setTextAlign(AlignRight)
            label:setMarginTop(2)

            if index == 1 then
                label:addAnchor(AnchorTop, "prev", AnchorBottom)
                label:addAnchor(AnchorLeft, "parent", AnchorLeft)
            else
                label:addAnchor(AnchorTop, labels[index - 1].id, AnchorBottom)
                label:addAnchor(AnchorLeft, "parent", AnchorLeft)
            end

            label:setMarginLeft(4)

            local value = g_ui.createWidget("Label", UI.bidArea)
            value:setId(data.id .. "_value")
            value:setText(data.value)
            value:setColor("#C0C0C0")
            value:addAnchor(AnchorTop, "prev", AnchorTop)
            value:addAnchor(AnchorLeft, "prev", AnchorRight)
            value:setMarginLeft(5)

            if data.id == "highestBid" then
                value:setWidth(90)
                value:setHeight(15)
                value:setMarginLeft(7)
                value:setTextAlign(AlignRight)

                local gold = g_ui.createWidget("UIWidget", UI.bidArea)
                gold:setId("highestBid_gold")
                gold:setImageSource("/game_cyclopedia/images/icon_gold")
                gold:addAnchor(AnchorTop, "prev", AnchorTop)
                gold:addAnchor(AnchorLeft, "prev", AnchorRight)
                gold:setMarginTop(2)
                gold:setMarginLeft(9)
            end
        end

        if house.bidHolderLimit then
            local label = g_ui.createWidget("Label", UI.bidArea)
            label:setId("yourLimit")
            label:setText("Your Limit: ")
            label:setColor("#909090")
            label:setWidth(90)
            label:setHeight(15)
            label:setTextAlign(AlignRight)
            label:setMarginTop(2)
            label:addAnchor(AnchorTop, "highestBid", AnchorBottom)
            label:addAnchor(AnchorLeft, "parent", AnchorLeft)

            local value = g_ui.createWidget("Label", UI.bidArea)
            value:setWidth(90)
            value:setHeight(15)
            value:setId("yourLimit_value")
            value:setText(comma_value(house.bidHolderLimit))
            value:setColor("#C0C0C0")
            value:addAnchor(AnchorTop, "prev", AnchorTop)
            value:addAnchor(AnchorLeft, "prev", AnchorRight)
            value:setMarginLeft(13)
            value:setTextAlign(AlignRight)

            local gold = g_ui.createWidget("UIWidget", UI.bidArea)
            gold:setId("yourLimit_gold")
            gold:setImageSource("/game_cyclopedia/images/icon_gold")
            gold:addAnchor(AnchorTop, "prev", AnchorTop)
            gold:addAnchor(AnchorLeft, "prev", AnchorRight)
            gold:setMarginTop(2)
            gold:setMarginLeft(7)
        end
    else
        if UI.bidArea:getChildById("soFar") then
            UI.bidArea:getChildById("soFar"):destroy()
        end

        local label = g_ui.createWidget("Label", UI.bidArea)
        label:setId("soFar")
        label:setText("There is not bid so far.")
        label:setColor("#C0C0C0")
        label:addAnchor(AnchorTop, "prev", AnchorBottom)
        label:addAnchor(AnchorLeft, "parent", AnchorLeft)
        label:setMarginTop(2)
    end

    if UI.bidArea:getChildById("bidArea") then
        UI.bidArea:getChildById("bidArea"):destroy()
    end

    local bidArea = g_ui.createWidget("HouseBidArea", UI.bidArea)
    bidArea:setId("bidArea")
    bidArea:addAnchor(AnchorTop, "prev", AnchorBottom)
    bidArea:addAnchor(AnchorLeft, "parent", AnchorLeft)
    bidArea:addAnchor(AnchorRight, "parent", AnchorRight)
    bidArea:setMarginTop(5)

    if house.bidHolderLimit then
        bidArea.textEdit:setText(house.bidHolderLimit)
    else
        bidArea.textEdit:setText(0)
    end

    function bidArea.textEdit:onTextChange(text, oldText)
        local convertedText = tonumber(text)
        if text ~= "" and type(convertedText) ~= "number" then
            self:setText(oldText)
        end

        if text == "" then
            UI.bidArea.bid:setEnabled(false)
        elseif convertedText then
            UI.bidArea.bid:setEnabled(true)
        end
    end

    if house.hasBid then
        bidArea.information:setText(string.format(
            "When the auction ends at %s the\nwinning bid plus the rent for the first month ( %s) will\nbe debited to your bank account.",
            time, (house.rent)))
    else
        bidArea.information:setText("When the auction ends, the winning bid plus the rent for\nthe first month( " ..
                                        (house.rent) .. ") will de debited yo your bank account.")
    end

    function UI.bidArea.cancel.onClick()
        UI.bidArea:setVisible(false)
        UI.ListBase:setVisible(true)
    end

    function UI.bidArea.bid:onClick()
        local value = tonumber(bidArea.textEdit:getText())
        if not value or value <= 0 then
            return
        end

        local confirmWindow
        local function yesCallback()
            if confirmWindow then
                confirmWindow:destroy()
                confirmWindow = nil
                Cyclopedia.Toggle(true, false, 5)
            end

            g_game.sendCyclopediaHouseAuction(1, house.id, 0, value, "")
        end

        local function noCallback()
            if confirmWindow then
                confirmWindow:destroy()
                confirmWindow = nil
                Cyclopedia.Toggle(true, false, 5)
            end
        end

        if not confirmWindow then
            confirmWindow = displayGeneralBox(tr("Confirm House Action"), tr(
                "Do you really want to bid on the house '%s'?\nYour have set your bid limit to %s.\nWhen the auction ends, the winning bid plus the rent of %sfor the first month will be debited from your\nbank account.",
                house.name, comma_value(value), (house.rent)), {
                {
                    text = tr("Yes"),
                    callback = yesCallback
                },
                {
                    text = tr("No"),
                    callback = noCallback
                },
                anchor = AnchorHorizontalCenter
            }, yesCallback, noCallback)

            Cyclopedia.Toggle(true, false)
        end
    end
end

function Cyclopedia.houseRefresh()
    if Cyclopedia.House.lastTown then
        g_game.sendCyclopediaHouseAuction(0, 0, 0, 0, Cyclopedia.House.lastTown)

        if Cyclopedia.House.lastChangeState then
            if Cyclopedia.House.refreshEvent then
                return
            end

            Cyclopedia.House.refreshEvent = scheduleEvent(function()
                Cyclopedia.houseChangeState(Cyclopedia.House.lastChangeState)
                Cyclopedia.House.refreshEvent = nil
            end, 100)
        end
    end
end

function Cyclopedia.houseSort(widget, text, type)
    if Cyclopedia.House.Data then
        if type == 1 then
            table.sort(Cyclopedia.House.Data, function(a, b)
                return a.name < b.name
            end)
        elseif type == 2 then
            table.sort(Cyclopedia.House.Data, function(a, b)
                return a.sqm < b.sqm
            end)
        elseif type == 3 then
            -- block empty
        elseif type == 4 then
            table.sort(Cyclopedia.House.Data, function(a, b)
                if a.hasBid and not b.hasBid then
                    return true
                elseif not a.hasBid and b.hasBid then
                    return false
                else
                    return false
                end
            end)
        elseif type == 5 then
            table.sort(Cyclopedia.House.Data, function(a, b)
                if a.hasBid and not b.hasBid then
                    return true
                elseif not a.hasBid and b.hasBid then
                    return false
                else
                    return false
                end
            end)
        end

        Cyclopedia.reloadHouseList()
    end
end

function Cyclopedia.houseFilter(widget)
    local id = widget:getId()
    local brother

    if id == "HousesCheck" then
        brother = UI.TopBase.GuildhallsCheck
    else
        brother = UI.TopBase.HousesCheck
    end

    brother:setChecked(false)
    widget:setChecked(true)

    if not table.empty(Cyclopedia.House.Data) then
        local onlyGuildHall = UI.TopBase.GuildhallsCheck:isChecked()
        for _, data in ipairs(Cyclopedia.House.Data) do
            if onlyGuildHall then
                data.visible = data.gh
            else
                data.visible = not data.gh
            end
        end

        Cyclopedia.reloadHouseList()
    end
end

function Cyclopedia.reloadHouseList()
    if not table.empty(Cyclopedia.House.Data) then
        UI.LateralBase.MapViewbase.noHouse:setVisible(false)
        UI.LateralBase.MapViewbase.houseImage:setVisible(false)
        UI.LateralBase.MapViewbase.reload:setVisible(true)
        UI.LateralBase.AuctionLabel:setVisible(true)
        UI.LateralBase.AuctionText:setVisible(true)
        UI.ListBase.AuctionList:destroyChildren()

        for _, data in ipairs(Cyclopedia.House.Data) do
            if data.visible then
                local widget = g_ui.createWidget("House", UI.ListBase.AuctionList)
                widget.data = data
                widget:setId(data.id)
                widget:setText(data.name)
                widget.size:setColoredText("{Size:     , #909090}" .. data.sqm .. " sqm")
                widget.beds:setColoredText("{Max. Beds: ,#909090} " .. data.beds)
                widget.rent:setColoredText(data.rent)

                if data.description ~= "" then
                    local icon = g_ui.createWidget("HouseIcon", widget.icons)
                    -- icon:setImageSource("/game_cyclopedia/images/house-description")
                    icon:setTooltip(data.description)
                end

                if data.state == 0 then
                    if data.hasBid then
                        local function format(timestamp)
                            local difference = timestamp - os.time()
                            local hour = math.floor(difference / 3600)
                            local minutes = math.floor(difference % 3600 / 60)
                            return string.format("%02dh %02dmin", hour, minutes)
                        end

                        widget.status:setColoredText("{Status:  , #909090}{auctioned, #00F000} (Bid: " ..
                                                         data.hightestBid .. " Ends in: " .. format(data.bidEnd) .. ")")
                    else
                        widget.status:setColoredText("{Status:  , #909090}{auctioned, #00F000} (no bid yet)")
                    end
                elseif data.state == 2 then
                    widget.status:setColoredText("{Status:  , #909090}rented by " .. data.owner)
                elseif data.state == 3 then
                    widget.status:setColoredText("{Status:  , #909090}{pending transfer, #FFD060} (owner: " ..
                                                     data.owner .. ")")
                elseif data.state == 4 then
                    widget.status:setColoredText("{Status:  , #909090}{move out scheduled, #FFD060} (owner: " ..
                                                     data.owner .. ")")
                end

                widget.onClick = Cyclopedia.selectHouse

                if data.isYourOwner then
                    local icon = g_ui.createWidget("HouseIcon", widget.icons)
                    -- icon:setImageSource("/game_cyclopedia/images/house-owner-icon")
                end

                if widget.data.isTransferOwner then
                    local icon = g_ui.createWidget("HouseIcon", widget.icons)
                    icon:setImageSource("/game_cyclopedia/images/pending-transfer-house")
                end

                if data.isYourOwner and data.inTransfer then
                    local icon = g_ui.createWidget("HouseIcon", widget.icons)
                    icon:setImageSource("/game_cyclopedia/images/transfer-house")
                end

                if data.shop then
                    local icon = g_ui.createWidget("HouseIcon", widget.icons)
                    -- icon:setImageSource("/game_cyclopedia/images/house-shop")
                    icon:setTooltip("This house is a shop.")
                end
            end
        end

        if Cyclopedia.House.lastSelectedHouse then
            local last = UI.ListBase.AuctionList:getChildById(Cyclopedia.House.lastSelectedHouse:getId())
            last = last or UI.ListBase.AuctionList:getChildByIndex(1)
            Cyclopedia.selectHouse(last)
        else
            Cyclopedia.selectHouse(UI.ListBase.AuctionList:getChildByIndex(1))
        end
    else
        UI.LateralBase.MapViewbase.noHouse:setVisible(true)
        UI.LateralBase.MapViewbase.reload:setVisible(false)
        UI.LateralBase.MapViewbase.houseImage:setVisible(false)
        UI.LateralBase.AuctionLabel:setVisible(false)
        UI.LateralBase.AuctionText:setVisible(false)
        UI.LateralBase.icons:destroyChildren()
        UI.LateralBase.yourLimitBidGold:setVisible(false)
        UI.LateralBase.yourLimitBid:setVisible(false)
        UI.LateralBase.yourLimitLabel:setVisible(false)
        UI.LateralBase.highestBid:setVisible(false)
        UI.LateralBase.highestBidGold:setVisible(false)
        UI.LateralBase.subAuctionLabel:setVisible(false)
        UI.LateralBase.subAuctionText:setVisible(false)
        UI.LateralBase.transferLabel:setVisible(false)
        UI.LateralBase.transferValue:setVisible(false)
        UI.LateralBase.transferGold:setVisible(false)
        resetButtons()
    end
end

function Cyclopedia.loadHouseList(data)
    local houses = {}

    if not table.empty(data) then
        for _, value in ipairs(data) do
            local houseId = value[1]
            local house = Cyclopedia.House.Definitions[houseId]
            if house then
                local state = value[2]
                local data_t = {
                    id = houseId,
                    name = house.name,
                    description = house.description,
                    rent = house.rent,
                    beds = house.beds,
                    sqm = house.sqm,
                    gh = house.gh,
                    shop = house.shop,
                    visible = not house.gh,
                    state = state,
                    owner = value[9] ~= "" and value[9] or "?",
                    isYourBid = value[4],
                    hasBid = value[6] > 0,
                    bidEnd = value[6] > 0 and value[6] or nil,
                    hightestBid = value[7] > 0 and value[7] or nil,
                    bidName = value[3] ~= "" and value[3] or nil,
                    bidHolderLimit = value[8] > 0 and value[8] or nil,
                    canBid = value[5],
                    rented = state == 2 or state == 4,
                    paidUntil = value[10] > 0 and value[10] or nil,
                    isYourOwner = value[11],
                    inTransfer = state == 3,
                    movingOut = state == 4,
                    transferName = value[13] ~= "" and value[13] or nil,
                    transferTime = value[12] or 0,
                    transferValue = value[14] or 0,
                    isTransferOwner = value[15],
                    canAcceptTransfer = value[16] or 0,
                    canCancelTransfer = value[18] or 0
                }

                table.insert(houses, data_t)
            end
        end
    else
        UI.ListBase.AuctionList:destroyChildren()
    end

    table.sort(houses, function(a, b)
        return a.name < b.name
    end)

    Cyclopedia.House.Data = houses
    Cyclopedia.reloadHouseList()
end

function Cyclopedia.selectTown(widget, text, type)
    local name = text or ""
    if type ~= 0 then
        Cyclopedia.House.lastTown = name
    else
        Cyclopedia.House.lastTown = ""
    end
    g_game.sendCyclopediaHouseAuction(0, 0, 0, 0, Cyclopedia.House.lastTown)
end

function Cyclopedia.selectHouse(widget)
    if not widget then
        return
    end

    local parent = widget:getParent()
    for i = 1, parent:getChildCount() do
        local child = parent:getChildByIndex(i)
        child:setChecked(false)
    end

    UI.LateralBase.icons:destroyChildren()

    if widget.data.isYourOwner then
        local icon = g_ui.createWidget("HouseIcon", UI.LateralBase.icons)
        -- icon:setImageSource("/game_cyclopedia/images/house-owner-icon")
    end

    if widget.data.isYourOwner and widget.data.inTransfer then
        local icon = g_ui.createWidget("HouseIcon", UI.LateralBase.icons)
        icon:setImageSource("/game_cyclopedia/images/transfer-house")
    end

    if widget.data.isTransferOwner then
        local icon = g_ui.createWidget("HouseIcon", UI.LateralBase.icons)
        icon:setImageSource("/game_cyclopedia/images/pending-transfer-house")
    end

    if widget.data.shop then
        local icon = g_ui.createWidget("HouseIcon", UI.LateralBase.icons)
        -- icon:setImageSource("/game_cyclopedia/images/house-shop")
        icon:setTooltip("This house is a shop.")
    end

    if widget.data.description ~= "" then
        local icon = g_ui.createWidget("HouseIcon", UI.LateralBase.icons)
        -- icon:setImageSource("/game_cyclopedia/images/house-description")
        icon:setTooltip(widget.data.description)
    end

    resetButtons()
    resetSelectedInfo()

    if widget.data.hasBid then
        UI.LateralBase.AuctionLabel:setText("Auction")

        local formattedDate = os.date("%b %d, %H:%M", widget.data.bidEnd)
        local date = string.format("%s %s", formattedDate, "CET")

        UI.LateralBase.AuctionText:setColoredText("{Hightest Bidder: , #909090}" .. widget.data.bidName ..
                                                      "\n{      End Time: , #909090}" .. date ..
                                                      "\n{   Highest Bid: , #909090}")
        UI.LateralBase.highestBid:setVisible(true)
        UI.LateralBase.highestBidGold:setVisible(true)
        UI.LateralBase.highestBid:setText(comma_value(widget.data.hightestBid))

        if widget.data.isYourBid then
            UI.LateralBase.yourLimitLabel:setVisible(true)
            UI.LateralBase.yourLimitBid:setVisible(true)
            UI.LateralBase.yourLimitBid:setText(comma_value(widget.data.bidHolderLimit))
            UI.LateralBase.yourLimitBidGold:setVisible(true)
        end
    elseif widget.data.rented or widget.data.inTransfer then
        local formattedDate = widget.data.paidUntil and os.date("%b %d, %H:%M", widget.data.paidUntil) or "not set"
        local date = widget.data.paidUntil and string.format("%s %s", formattedDate, "server time") or formattedDate

        UI.LateralBase.AuctionLabel:setText("Rental Details")
        UI.LateralBase.AuctionText:setColoredText("{            Tenant: , #909090}" .. widget.data.owner ..
                                                      "\n{         Paid Until: , #909090}" .. date)

        if widget.data.inTransfer then
            formattedDate = os.date("%b %d, %H:%M", widget.data.transferTime)
            date = string.format("%s %s", formattedDate, "server time")

            UI.LateralBase.subAuctionLabel:setVisible(true)
            UI.LateralBase.subAuctionLabel:setText("Pending Transfer")
            UI.LateralBase.subAuctionText:setVisible(true)
            UI.LateralBase.subAuctionText:setColoredText("{      New Owner:  , #909090}" .. widget.data.transferName ..
                                                             "\n{                Date:  , #909090}" .. date)
            UI.LateralBase.transferLabel:setVisible(true)
            UI.LateralBase.transferValue:setVisible(true)
            UI.LateralBase.transferGold:setVisible(true)
            UI.LateralBase.transferValue:setText(comma_value(widget.data.transferValue))
        elseif widget.data.movingOut then
            formattedDate = os.date("%b %d, %H:%M", widget.data.transferTime)
            date = string.format("%s %s", formattedDate, "server time")
            UI.LateralBase.subAuctionLabel:setVisible(true)
            UI.LateralBase.subAuctionLabel:setText("Move Out")
            UI.LateralBase.subAuctionText:setVisible(true)
            UI.LateralBase.subAuctionText:setColoredText("{Server Save:  , #909090}" .. date)
        end
    else
        UI.LateralBase.AuctionLabel:setText("Auction")
        UI.LateralBase.AuctionText:setText("There is no bid so far.\nBe the first to bid on this house.")
    end

    if widget.data.movingOut and widget.data.isYourOwner then
        local button = g_ui.createWidget("Button", UI.LateralBase)
        button:setId("cancelMoveOutButton")
        button:setText("Cancel Move Out")
        button:setColor("#C0C0C0")
        button:setWidth(96)
        button:setHeight(20)
        button:addAnchor(AnchorBottom, "parent", AnchorBottom)
        button:addAnchor(AnchorRight, "parent", AnchorRight)
        button:setMarginRight(7)
        button:setMarginBottom(7)
        button.onClick = Cyclopedia.cancelMoveOut
    elseif widget.data.rented then
        if widget.data.isYourOwner then
            local button = g_ui.createWidget("Button", UI.LateralBase)
            button:setId("transferButton")
            button:setText("Transfer")
            button:setColor("#C0C0C0")
            -- button:setFont("verdana-bold-8px-antialiased")
            button:setWidth(64)
            button:setHeight(20)
            button:addAnchor(AnchorBottom, "parent", AnchorBottom)
            button:addAnchor(AnchorRight, "parent", AnchorRight)
            button:setMarginRight(7)
            button:setMarginBottom(7)
            button.onClick = Cyclopedia.transferHouse
            button = g_ui.createWidget("Button", UI.LateralBase)
            button:setId("moveOutButton")
            button:setText("Move Out")
            button:setColor("#C0C0C0")
            -- button:setFont("verdana-bold-8px-antialiased")
            button:setWidth(64)
            button:setHeight(20)
            button:addAnchor(AnchorTop, "prev", AnchorTop)
            button:addAnchor(AnchorRight, "prev", AnchorLeft)
            button:setMarginRight(5)
            button.onClick = Cyclopedia.moveOutHouse
        end
    elseif widget.data.inTransfer and not widget.data.isTransferOwner then
        local button = g_ui.createWidget("Button", UI.LateralBase)
        button:setId("cancelTransfer")
        button:setText("Cancel Transfer")
        button:setColor("#C0C0C0")
        -- button:setFont("verdana-bold-8px-antialiased")
        button:setWidth(86)
        button:setHeight(20)
        button:addAnchor(AnchorBottom, "parent", AnchorBottom)
        button:addAnchor(AnchorRight, "parent", AnchorRight)
        button:setMarginRight(7)
        button:setMarginBottom(7)
        button.onClick = Cyclopedia.cancelTransfer
    elseif widget.data.isTransferOwner then
        local button = g_ui.createWidget("Button", UI.LateralBase)
        button:setId("rejectTransfer")
        button:setText("Reject Transfer")
        button:setColor("#C0C0C0")
        -- button:setFont("verdana-bold-8px-antialiased")
        button:setWidth(86)
        button:setHeight(20)
        button:addAnchor(AnchorBottom, "parent", AnchorBottom)
        button:addAnchor(AnchorRight, "parent", AnchorRight)
        button:setMarginRight(7)
        button:setMarginBottom(7)
        button:setTextOffset(topoint(0 .. " " .. 0))
        button.onClick = Cyclopedia.rejectTransfer

        local transferButton = g_ui.createWidget("Button", UI.LateralBase)
        transferButton:setId("acceptTransfer")
        transferButton:setText("Accept Transfer")
        transferButton:setColor("#C0C0C0")
        -- transferButton:setFont("verdana-bold-8px-antialiased")
        transferButton:setWidth(86)
        transferButton:setHeight(20)
        transferButton:addAnchor(AnchorTop, "prev", AnchorTop)
        transferButton:addAnchor(AnchorRight, "prev", AnchorLeft)
        transferButton:setMarginRight(5)
        transferButton:setTextOffset(topoint(0 .. " " .. 0))
        transferButton.onClick = Cyclopedia.acceptTransfer

        if widget.data.canAcceptTransfer ~= 0 then
            transferButton:setEnabled(false)
        else
            transferButton:setEnabled(true)
        end
    else
        local button = g_ui.createWidget("Button", UI.LateralBase)
        button:setId("bidButton")
        button:setText("Bid")
        button:setColor("#C0C0C0")
        -- button:setFont("verdana-bold-8px-antialiased")
        button:setWidth(64)
        button:setHeight(20)
        button:addAnchor(AnchorBottom, "parent", AnchorBottom)
        button:addAnchor(AnchorRight, "parent", AnchorRight)
        button:setMarginRight(7)
        button:setMarginBottom(7)
        button.onClick = Cyclopedia.bidHouse

        if widget.data.canBid == 0 then
            button:setEnabled(true)
            button:setTooltip("")
        elseif widget.data.canBid == 11 then
            button:setTooltip(
                "A character of your account already holds the highest bid for \nanother house. You may olny bid for one house at the same time.")
            button:setTooltipAlign(AlignTopLeft)
            button:setEnabled(false)
        elseif widget.data.canBid == 26 then
            button:setTooltip("You need to be at least level 300 to bid on a house.")
            button:setTooltipAlign(AlignTopLeft)
            button:setEnabled(false)
        else
            button:setEnabled(false)
            button:setTooltip("")
        end
    end

    widget:setChecked(true)
    UI.LateralBase.MapViewbase.noHouse:setVisible(false)
    UI.LateralBase.MapViewbase.reload:setVisible(true)
    UI.LateralBase.MapViewbase.houseImage:setVisible(false)

    local imagePath = string.format("/game_cyclopedia/images/houses/%s.png", widget.data.id)
    if g_resources.fileExists(imagePath) then
        UI.LateralBase.MapViewbase.noHouse:setVisible(false)
        UI.LateralBase.MapViewbase.reload:setVisible(false)
        UI.LateralBase.MapViewbase.houseImage:setVisible(true)
        UI.LateralBase.MapViewbase.houseImage:setImageSource(imagePath)
    end

    --[[
    UI.LateralBase.MapViewbase.houseImage:setVisible(true)
    HTTP.downloadImage("https://next-stage.pl/images/houses/A%20Horse%20farm.jpeg", function(path, err)
        if err then g_logger.warning("HTTP error: " .. err .. " - ") return end
        UI.LateralBase.MapViewbase.houseImage:setImageSource(path)
      end)
    ]]--

    Cyclopedia.House.lastSelectedHouse = widget
end
