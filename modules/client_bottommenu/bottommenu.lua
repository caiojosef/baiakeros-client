local bottomMenu
local calendarWindow
local activeScheduleEvent
local upcomingScheduleEvent
local eventSchedulerYears
local calendarCurrentMonth
local calendarPrevButton
local calendarNextButton
local calendarCurrentDate
local showOffWindow
local showOffWidget
local showOffSlideIndex = 1
local showOffSlideEvent
local showOffUsesDefault = true
local SHOW_OFF_INTERVAL = 8000
local scheduleRefreshEvent
local scheduleReceivedAt
local scheduleRefreshTicks = 0

local eventSchedulerTimestamp
local eventSchedulerCalendar
local eventSchedulerCalendarYearIndex
local eventSchedulerCalendarMonth

local boostedWindow
local monsterOutfit
local monsterImage
local bossOutfit
local bossImage

local CREATURE_BONUS_TEXT = "Today's boosted creature: %s\n\n\tBoosted creatures yield more experience\n points, carry more loot than usual\n and respawn at a faster rate."
local BOSS_BONUS_TEXT = "Today's boosted boss: %s\n\n\tBoosted boss contain more loot and\n count more kills for your bosstiary."

local default_info = {
    {
        image = "/images/baiakeros/logo-panel",
        Title = "Market / Mercado Pago",
        description = "Conecte sua conta Mercado Pago.\nVenda itens no Market e receba em dinheiro."
    },
    {
        image = "/images/baiakeros/logo-panel",
        Title = "Helper / Cavebot incluso",
        description = "Rotas, cura e ataques no mesmo cliente.\nConfigure sua caçada e evolua no seu ritmo."
    },
    {
        image = "/images/baiakeros/logo-panel",
        Title = "Party Hunt exclusivo",
        description = "Mais de um personagem, uma equipe coordenada.\nOrganize seu grupo e domine as caçadas."
    },
}

local function stopShowOffSlides()
    if showOffSlideEvent then
        removeEvent(showOffSlideEvent)
        showOffSlideEvent = nil
    end
end

local function displayShowOffSlide()
    local slide = default_info[showOffSlideIndex]
    showOffWindow.title:setText(slide.Title .. "  (" .. showOffSlideIndex .. "/" .. #default_info .. ")")
    showOffWidget:recursiveGetChildById('image'):setImageSource(slide.image)
    showOffWidget:recursiveGetChildById('description'):setText(slide.description)
end

local function startShowOffSlides()
    stopShowOffSlides()
    if not showOffUsesDefault or bottomMenu:isHidden() then
        return
    end
    showOffSlideEvent = scheduleEvent(function()
        showOffSlideEvent = nil
        showOffSlideIndex = (showOffSlideIndex % #default_info) + 1
        displayShowOffSlide()
        startShowOffSlides()
    end, SHOW_OFF_INTERVAL)
end

local function stopScheduleRefresh()
    if scheduleRefreshEvent then
        removeEvent(scheduleRefreshEvent)
        scheduleRefreshEvent = nil
    end
end

local function startScheduleRefresh()
    stopScheduleRefresh()
    if bottomMenu:isHidden() then return end
    scheduleRefreshEvent = scheduleEvent(function()
        scheduleRefreshEvent = nil
        refreshScheduleSummary()
        scheduleRefreshTicks = scheduleRefreshTicks + 1
        if scheduleRefreshTicks % 5 == 0 then
            modules.client_entergame.EnterGame.postEventScheduler()
        end
        startScheduleRefresh()
    end, 60000)
end

function init()
    g_ui.importStyle('calendar')
    bottomMenu = g_ui.displayUI('bottommenu')

    calendarWindow = g_ui.createWidget('CalendarGrid', rootWidget)
    calendarCurrentMonth = calendarWindow:recursiveGetChildById('calendarCurrentMonth')
    calendarCurrentDate = calendarWindow:recursiveGetChildById('calendarCurrentDate')
    calendarPrevButton = calendarWindow:recursiveGetChildById('calendarPrevButton')
    calendarNextButton = calendarWindow:recursiveGetChildById('calendarNextButton')
    calendarWindow:hide()

    showOffWindow = bottomMenu:recursiveGetChildById('showOffWindow')
    showOffWindow.title = showOffWindow:recursiveGetChildById('showOffWindowText')
    showOffWidget = g_ui.createWidget('ShowOffWidget', showOffWindow:recursiveGetChildById('contentsPanel'))
    showOffSlideIndex = 1
    showOffUsesDefault = true
    displayShowOffSlide()
    activeScheduleEvent = bottomMenu:recursiveGetChildById('activeScheduleEvent')
    upcomingScheduleEvent = bottomMenu:recursiveGetChildById('upcomingScheduleEvent')
    upcomingScheduleEvent:recursiveGetChildById('fill'):setOn(false)
    startScheduleRefresh()
    eventSchedulerCalendarYearIndex = 1
    eventSchedulerCalendarMonth = tonumber(os.date("%m"))

    boostedWindow = bottomMenu:recursiveGetChildById('boostedWindow')
    monsterOutfit = boostedWindow:recursiveGetChildById('creature')
    bossOutfit = boostedWindow:recursiveGetChildById('boss')

    monsterOutfit:setVisible(false)
    bossOutfit:setVisible(false)

    monsterImage = boostedWindow:recursiveGetChildById('monsterImage')
    bossImage = boostedWindow:recursiveGetChildById('bossImage')

    monsterImage:setImageSource("images/icon-questionmark")
    monsterImage:setVisible(true)
    bossImage:setImageSource("images/icon-questionmark")
    bossImage:setVisible(true)
    if g_game.isOnline() then
        hide()
    else
        startShowOffSlides()
    end
end

function terminate()
    stopShowOffSlides()
    stopScheduleRefresh()
    g_keyboard.unbindKeyPress('Escape', onClickCloseCalendar)
    bottomMenu:destroy()
    calendarWindow:destroy()
end

function hide()
    stopShowOffSlides()
    stopScheduleRefresh()
    bottomMenu:hide()
    bottomMenu:lower()

    if not calendarWindow:isHidden() then
        onClickCloseCalendar()
    end
end

function show()
    bottomMenu:show()
    bottomMenu:raise()
    bottomMenu:focus()
    startShowOffSlides()
    refreshScheduleSummary()
    startScheduleRefresh()
end

-- @ Store showoff
function setShowOffData(data)
    if type(data) ~= 'table' or not data.image or not data.title or not data.description then
        return
    end
    showOffUsesDefault = false
    stopShowOffSlides()
    local widget = showOffWidget
    local image = widget:recursiveGetChildById('image')

    if data.image and data.image:sub(1, 4):lower() == "http" then
        HTTP.downloadImage(data.image, function(path, err)
            if err then
                g_logger.warning("HTTP error: " .. err .. " - " .. data.image)
                return
            end
            image:setImageSource(path)
        end)
    else
        image:setImageSource(data.image)
    end

    local description = widget:recursiveGetChildById('description')

    showOffWindow.title:setText(tr(data.title))
    description:setText(tr(data.description))
end

-- @ Calendar/Events scheduler
function onClickOnCalendar()
    if eventSchedulerYears == nil or #eventSchedulerYears == 0 then
        return
    end

    calendarWindow:show()
    calendarWindow:raise()
    calendarWindow:centerIn('parent')
    calendarWindow:removeAnchor(AnchorHorizontalCenter)
    calendarWindow:removeAnchor(AnchorVerticalCenter)
    reloadEventsSchedulerCurrentPage()

    g_keyboard.bindKeyPress('Escape', onClickCloseCalendar)
end

function onClickCloseCalendar()
    calendarWindow:hide()
    calendarWindow:lower()

    g_keyboard.unbindKeyPress('Escape', onClickCloseCalendar)
end

function setEventsSchedulerTimestamp(time)
    if not tonumber(time) then return end
    eventSchedulerTimestamp = tonumber(time)
    scheduleReceivedAt = g_clock.millis()
    calendarCurrentDate:setText(os.date("!%d/%m/%Y, %H:%M", eventSchedulerTimestamp - 10800) .. ' Brasília')
end

local function upcomingAnnouncementStart(startdate)
    -- Wednesday 00:00 before this occurrence, always in Brasilia (UTC-03).
    local localStart = os.date('!*t', startdate - 10800)
    local daysSinceWednesday = (localStart.wday - 4 + 7) % 7
    return startdate - daysSinceWednesday * 86400 -
        localStart.hour * 3600 - localStart.min * 60 - localStart.sec
end

local function addSummaryEvent(widget, info, active)
    widget:addScheduleEvent({name = info.shortname or info.name,
        description = info.description, active = '#484848ff',
        inactive = '#414141ff', season = false}, active, onClickOnCalendar)
    for _, row in ipairs(widget:getChildById('content'):getChildren()) do
        row:getChildById('text'):setColor('#ffffffff')
        row:getChildById('text'):setOpacity(1)
    end
end

function refreshScheduleSummary()
    if not activeScheduleEvent or not eventSchedulerCalendar then return end
    local now = (eventSchedulerTimestamp or os.time()) +
        (scheduleReceivedAt and math.floor((g_clock.millis() - scheduleReceivedAt) / 1000) or 0)
    activeScheduleEvent:clearEvents()
    upcomingScheduleEvent:clearEvents()
    local nextStart
    for _, info in ipairs(eventSchedulerCalendar) do
        local active = info.startdate <= now and now < info.enddate
        local upcoming = info.startdate > now and now >= upcomingAnnouncementStart(info.startdate)
        if upcoming and (not nextStart or info.startdate < nextStart) then
            nextStart = info.startdate
        end
        if active then
            addSummaryEvent(activeScheduleEvent, info, true)
        end
    end
    for _, info in ipairs(eventSchedulerCalendar) do
        if info.startdate == nextStart then
            addSummaryEvent(upcomingScheduleEvent, info, false)
        end
    end
end

function getCalendarEventWidgetByDay(day, month, year, weekOffset, forceLine)
    local weekIndex = getDayOfWeek(day, month, year)
    local row = calendarWindow:recursiveGetChildById('row' .. weekIndex)
    if not row then
        return nil
    end

    local lineIndex = nil
    if forceLine ~= nil then
        lineIndex = forceLine
    else
        lineIndex = (math.floor(((weekOffset + day) - 1) / 7))
    end
    local line = row:recursiveGetChildById('line' .. lineIndex)
    if not line then
        return nil
    end

    return line
end

function reloadEventsSchedulerCurrentPage()
    local firstDayOffset = getDayOfWeek(1)
    if firstDayOffset == 0 then
        firstDayOffset = 7
    end
    local weekOffset = firstDayOffset - 1

    -- Days before the day 1 of this month
    if weekOffset > 0 then
        local previousYearIndex = eventSchedulerCalendarYearIndex
        local previousMonth = eventSchedulerCalendarMonth
        if previousMonth == 1 then
            previousYearIndex = previousYearIndex - 1
            previousMonth = 12
        else
            previousMonth = previousMonth - 1
        end
        if previousYearIndex >= 1 then
            local previousDays = eventSchedulerYears[previousYearIndex][previousMonth]
            local amountsLeft = weekOffset
            local i = #previousDays
            while (amountsLeft > 0) do
                local widget = getCalendarEventWidgetByDay(i, previousMonth, tonumber(os.date("%Y", os.time())) +
                    (previousYearIndex - 1), weekOffset, 0)
                if widget then
                    widget:clearEvents()
                    widget.dayOfTheWeek = i
                    widget:recursiveGetChildById('dayAndSeason'):setOn(true)
                    widget:recursiveGetChildById('day'):setText(i)
                    widget:recursiveGetChildById('day'):setWidth(string.len(
                        widget:recursiveGetChildById('day'):getText()) * 10)
                    widget:recursiveGetChildById('fill'):setOn(false)
                    for _, event in ipairs(previousDays[i]) do
                        widget:addScheduleEvent(event, false, nil)
                    end
                end
                amountsLeft = amountsLeft - 1
                i = i - 1
            end
        end
    end

    -- Days after the last day of this month
    local days = eventSchedulerYears[eventSchedulerCalendarYearIndex][eventSchedulerCalendarMonth]
    local lastDayOffset = getDayOfWeek(#days)
    if lastDayOffset == 0 then
        lastDayOffset = 7
    end
    local nextWeekOffset = 7 - lastDayOffset
    local nextYearIndex = eventSchedulerCalendarYearIndex
    local nextMonth = eventSchedulerCalendarMonth
    if nextMonth == 12 then
        nextYearIndex = nextYearIndex + 1
        nextMonth = 1
    else
        nextMonth = nextMonth + 1
    end
    if nextYearIndex <= 2 then
        local nextDays = eventSchedulerYears[nextYearIndex][nextMonth]
        local amountsLeft = nextWeekOffset
        local i = 1
        local forceLine = 4
        if firstDayOffset >= 5 then
            forceLine = 5
        end
        if firstDayOffset <= 5 then
            amountsLeft = amountsLeft + 7
        end
        while (amountsLeft > 0) do
            if forceLine == 4 and amountsLeft == 7 then
                forceLine = 5
            end
            local widget = getCalendarEventWidgetByDay(i, nextMonth,
                tonumber(os.date("%Y", os.time())) + (nextYearIndex - 1), nextWeekOffset, forceLine)
            if widget then
                widget:clearEvents()
                widget.dayOfTheWeek = i
                widget:recursiveGetChildById('dayAndSeason'):setOn(true)
                widget:recursiveGetChildById('day'):setText(i)
                widget:recursiveGetChildById('day'):setWidth(
                    string.len(widget:recursiveGetChildById('day'):getText()) * 10)
                widget:recursiveGetChildById('fill'):setOn(false)
                for _, event in ipairs(nextDays[i]) do
                    widget:addScheduleEvent(event, false, nil)
                end
            end
            amountsLeft = amountsLeft - 1
            i = i + 1
        end
    end

    for day, events in ipairs(days) do
        local widget = getCalendarEventWidgetByDay(day, nil, nil, weekOffset, nil)
        if widget then
            widget:clearEvents()
            widget.dayOfTheWeek = day
            widget:recursiveGetChildById('dayAndSeason'):setOn(true)
            widget:recursiveGetChildById('day'):setText(tr(day))
            widget:recursiveGetChildById('day'):setWidth(string.len(widget:recursiveGetChildById('day'):getText()) * 10)
            widget:recursiveGetChildById('fill'):setOn(true)
            for _, event in ipairs(events) do
                widget:addScheduleEvent(event, true, nil)
            end
        end
    end

    calendarCurrentMonth:setText(os.date("%B", os.time {
        year = 2023,
        month = eventSchedulerCalendarMonth,
        day = 1
    }) .. " " .. (tonumber(os.date("%Y", os.time())) + (eventSchedulerCalendarYearIndex - 1)))
end

function reloadEventsSchedulerCalender()
    eventSchedulerYears = {}
    table.insert(eventSchedulerYears, createCalendar(tonumber(os.date("%Y", os.time()))))
    table.insert(eventSchedulerYears, createCalendar(tonumber(os.date("%Y", os.time())) + 1))
    refreshScheduleSummary()

    if eventSchedulerCalendar == nil or #eventSchedulerCalendar == 0 then
        return
    end

    for _, info in ipairs(eventSchedulerCalendar) do
        local days = getCalendarDays(info.startdate, info.enddate - 1)
        for index, day in ipairs(days) do
            table.insert(day, {
                active = (info.colorlight .. "ff"),
                inactive = (info.colordark .. "ff"),
                description = info.description,
                priority = info.displaypriority,
                season = info.isseasonal,
                name = info.name,
                special = info.specialevent,
                firstDay = index == 1,
                lastDay = index == #days
            })
        end
    end

    refreshScheduleSummary()
end

function setEventsSchedulerCalender(calender)
    eventSchedulerCalendar = type(calender) == 'table' and calender or {}
    reloadEventsSchedulerCalender()
end

function createCalendar(year)
    local calendar = {}

    for month = 1, 12 do
        calendar[month] = {}
        local daysInMonth = 31
        if month == 2 then
            if (year % 4 == 0 and year % 100 ~= 0) or (year % 400 == 0) then
                daysInMonth = 29
            else
                daysInMonth = 28
            end
        elseif month == 4 or month == 6 or month == 9 or month == 11 then
            daysInMonth = 30
        end

        for day = 1, daysInMonth do
            calendar[month][day] = {}
        end
    end

    return calendar
end

function getCalendarDays(startTimestamp, endTimestamp)
    local currentYear = tonumber(os.date("%Y"))
    local daysInRange = {}
    local date = os.date("*t", startTimestamp)
    date.hour, date.min, date.sec = 0, 0, 0
    local cursor = os.time(date)
    while cursor <= endTimestamp do
        local day = os.date("*t", cursor)
        local yearIndex = day.year - currentYear + 1
        local year = eventSchedulerYears[yearIndex]
        if year and year[day.month] and year[day.month][day.day] then
            table.insert(daysInRange, year[day.month][day.day])
        end
        day.day = day.day + 1
        cursor = os.time(day)
    end
    return daysInRange
end

function getDayOfWeek(day, month, year)
    if not year then
        year = tonumber(os.date("%Y", os.time())) + (eventSchedulerCalendarYearIndex - 1)
    end
    if not month then
        month = eventSchedulerCalendarMonth
    end
    local timestamp = os.time {
        year = year,
        month = month,
        day = day
    }
    local weekday = tonumber(os.date("%w", timestamp))
    -- 0: Sunday
    -- 6: Saturday
    return weekday
end

function onClickOnPreviousCalendar()
    if eventSchedulerCalendarMonth == 1 then
        if eventSchedulerCalendarYearIndex == 1 then
            return
        end
        eventSchedulerCalendarMonth = 12
        eventSchedulerCalendarYearIndex = eventSchedulerCalendarYearIndex - 1
    else
        eventSchedulerCalendarMonth = eventSchedulerCalendarMonth - 1
    end

    calendarNextButton:setEnabled(true)
    if eventSchedulerCalendarYearIndex == 1 and eventSchedulerCalendarMonth == (tonumber(os.date("%m", os.time())) - 1) then
        calendarPrevButton:setEnabled(false)
    else
        calendarPrevButton:setEnabled(true)
    end

    reloadEventsSchedulerCurrentPage()
end

function onClickOnNextCalendar()
    if eventSchedulerCalendarMonth == 12 then
        if eventSchedulerCalendarYearIndex == 2 then
            return
        end
        eventSchedulerCalendarMonth = 1
        eventSchedulerCalendarYearIndex = eventSchedulerCalendarYearIndex + 1
    else
        eventSchedulerCalendarMonth = eventSchedulerCalendarMonth + 1
    end

    calendarPrevButton:setEnabled(true)
    if eventSchedulerCalendarYearIndex == 2 and eventSchedulerCalendarMonth == (tonumber(os.date("%m", os.time())) - 1) then
        calendarNextButton:setEnabled(false)
    else
        calendarNextButton:setEnabled(true)
    end

    reloadEventsSchedulerCurrentPage()
end

-- (internal)
-- set creature/boss to boosted slot
local function applyToBoostedSlot(raceId, outfitWidget, imageWidget, fileName, tooltipText)
    -- check if raceId was provided in the JSON response
    if not raceId then
        return
    end

    -- fetch race data
    local raceData = g_things.getRaceData(raceId)

    -- check if race id is present in the staticdata
    if raceData.raceId == 0 then
        local msg = string.format("[%s] Creature with race id %s was not found.", fileName,tostring(raceId))
        g_logger.warning(msg)
        return
    end

    -- apply to selected widget
    outfitWidget:setOutfit(raceData.outfit)
    outfitWidget:getCreature():setStaticWalking(1000)
    outfitWidget:setVisible(true)
    imageWidget:setVisible(false)
    outfitWidget:setTooltip(tr(tooltipText, raceData.name or "Unknown"))
end

function setBoostedCreatureAndBoss(data)
    if not modules.game_things.isLoaded() then
        return
    end

    -- file name for error reporting
    local fileName = debug.getinfo(1, "S").source -- current file name - bottommenu.lua

    -- boosted creature
    -- before bosstiary was introduced, the webservice was sending creature race in 'raceid' field
    -- after bosstiary was added, it was changed to 'creatureraceid'
    -- this 'or' statement ensures backwards compatibility
    applyToBoostedSlot(data.creatureraceid or data.raceid, monsterOutfit, monsterImage, fileName, CREATURE_BONUS_TEXT)

    -- boosted boss
    applyToBoostedSlot(data.bossraceid, bossOutfit, bossImage, fileName, BOSS_BONUS_TEXT)
end
