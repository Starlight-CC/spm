sleep(0)
local settings = registry.get("Fission2.settings")

------------------------------------------------

local display = {}
local rules = {}
local data = {}
local function addRule(name,func)
    rules[name]=func
end

addRule("REACTOR DAMAGE",function()
    if data.reactor.damage >= settings.maxDmg then
        return true
    else
        return false
    end
end)

addRule("TURBINE SHUTDOWN",function()
    local count = 0
    for i,_ in pairs(settings.turbines)
        if data.turbines[i].energy >= 95 then
            count=count+1
        end
    end
    if count >= settings.turbineNum=1 then
        return true
    else
        return false
    end
end)

addRule("REACTOR COOLANT",function()
    if data.reactor.coolantLvl <= 25 then
        return true
    else
        return false
    end
end)

addRule("REACTOR WASTE",function()
    if data.reactor.wasteLvl >= 95 then
        return true
    else
        return false
    end
end)

local function checkRules()
    for i,v in pairs(rules) do
        if v() then
            return true,i
        end
    end
    return false
end

local function addDisplay(name,func)
    display[#display+1]=func
end

addDisplay("REACTOR DAMAGE | ",function()
    if data.reactor.damage >= 20 then
        return data.reactor.damage,colors.red
    elseif data.reactor.damage >= 10 then
        return data.reactor.damage,colors.orange
    else
        return data.reactor.damage,colors.green
    end
end)

addDisplay("REACTOR COOLANT | ",function()
    if data.reactor.coolantLvl <= 50 then
        return data.reactor.coolantLvl,colors.red
    elseif data.reactor.coolantLvl <= 75 then
        return data.reactor.coolantLvl,colors.orange
    else
        return data.reactor.coolantLvl,colors.green
    end
end)

addDisplay("REACTOR WASTE | ",function()
    if data.reactor.wasteLvl >= 75 then
        return data.reactor.wasteLvl,colors.red
    elseif data.reactor.wasteLvl >= 50 then
        return data.reactor.wasteLvl,colors.orange
    else
        return data.reactor.wasteLvl,colors.green
    end
end)

for i,_ in pairs(settings.turbines) do
    addDisplay("TURBINE "..i.."ENERGY | ",function()
        if data.reactor.wasteLvl >= 75 then
            return data.turbine[i].energy,colors.red
        elseif data.reactor.wasteLvl >= 50 then
            return data.turbine[i].energy,colors.orange
        else
            return data.turbine[i].energy,colors.green
        end
    end)
end

local function updateData()
    data = {
        reactor = {
            damage = reactor.getDamagePercent()*100,
            coolantLvl = reactor.getCoolantFilledPercentage()*100,
            wasteLvl = reactor.getWasteFilledPercentage()*100
        },
        turbine = {}
    }
    for i,v in pairs(settings.turbines) do
        data.turbine[i] = {
            energy = turbines[i].getEnergyFilledPercentage()*100
        }
    end
end

local reactor = peripheral.get(settings.reactor)
local turbines = {}
for i,v in pairs(settings.turbines) do
    turbines[i]=peripheral.get(v)
end

updateData()

local trigger,exeption = false,""
while true do
    updateData()
    trigger,exeption = checkRules()
    if trigger then
        scram(exeption)
    end
    

