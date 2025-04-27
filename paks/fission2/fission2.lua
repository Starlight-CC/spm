sleep(0)
local STATES = {
	READY = 1, -- Reactor is off and can be started with the lever
	RUNNING = 2, -- Reactor is running and all rules are met
	ESTOP = 3, -- Reactor is stopped due to rule(s) being violated
	UNKNOWN = 4, -- Reactor or turbine peripherals are missing
}
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
    if data.reactor.wasteLvl >= 75 then
        return true
    else
        return false
    end
end)

local function addDisplay(name,func)
    display[#display+1]=func
end

addDisplay("REACTOR DAMAGE | ",function()
)
