-- Exercise the real stats bar and both health-circle callbacks at each boundary.
extends=function()return {}end
dofile('modules/corelib/ui/uistatsbar.lua')
local function widget()
    local w={height=200,y=10}
    for _,property in ipairs({'Width','Height','Y','ImageSource','ImageClip','ImageColor'})do
        w['set'..property]=function(self,value)self[property]=value end
    end
    function w:getY()return self.y end
    return w
end
g_settings={getBoolean=function()return false end,getNode=function()return {}end,getNumber=function()return 0 end}
modules={game_interface={getMapPanel=function()return {}end,getLeftPanel=function()return {}end},
    client_topmenu={getTopMenu=function()return {}end}}
local hp,maxHp=100,100
local player={getHealth=function()return hp end,getMaxHealth=function()return maxHp end}
g_game={isOnline=function()return true end,getLocalPlayer=function()return player end}
dofile('modules/game_healthcircle/game_healthcircle_monk.lua')
dofile('modules/game_healthcircle/game_healthcircle.lua')
healthCircle,healthCircleFront,monkCircleBackground,monkHealthCircle=widget(),widget(),widget(),widget()
imageSizeBroad,imageSizeThin,monkImageSizeBroad,monkImageSizeThin=200,30,200,30
local text={hide=function()end}
local stats={bar=widget(),text=text,statsType='health',statsSize='large',statsOrientation='horizontal',getWidth=function()return 500 end}
local cases={
    {100,'100','#00AF00'}, {93,'100','#00AF00'}, {92.99,'95','#649204'},
    {67.367,'95','#649204'}, {61,'95','#649204'}, {60.99,'60','#B88C08'},
    {31,'60','#B88C08'}, {30.99,'30','#AF2C2C'}, {9,'30','#AF2C2C'},
    {8.99,'10','#AF0000'}, {4,'10','#AF0000'}, {3.99,'4','#570000'},
    {0,'4','#570000'}, {-1,'4','#570000'}, {101,'100','#00AF00'}
}
for _,case in ipairs(cases)do
    hp=case[1]
    UIStatsBar.setValue(stats,hp,maxHp)
    isMonkMode=false;whenHealthChange()
    isMonkMode=true;whenHealthChange()
    assert(stats.bar.ImageSource=='/images/bars/horizontal_health_progressbar_large_'..case[2])
    assert(healthCircleFront.ImageColor==case[3] and monkHealthCircle.ImageColor==case[3],
        'bar/circle mismatch at '..hp..'%')
    assert(healthCircleFront.Height==monkHealthCircle.Height)
    assert(healthCircleFront.Height>=0 and healthCircleFront.Height<=200)
end
hp,maxHp=11028,16370
UIStatsBar.setValue(stats,hp,maxHp);isMonkMode=false;whenHealthChange()
assert(stats.bar.ImageSource:find('_95$') and healthCircleFront.ImageColor=='#649204','67% stays in the green band in both places')
hp,maxHp=3089,3305
UIStatsBar.setValue(stats,hp,maxHp);isMonkMode=false;whenHealthChange()
assert(stats.bar.ImageSource:find('_100$') and healthCircleFront.ImageColor=='#00AF00','the reported 93% screenshot must remain bright green')
maxHp=0;whenHealthChange();isMonkMode=true;whenHealthChange()
assert(healthCircleFront.Height==0 and monkHealthCircle.Height==0,'initial/empty maximum is safe')
print('PASS: real stats bar and both health arcs share all 6 colors, exact boundaries, fractional HP, 93%/67% screenshot regressions and safe empty HP')
