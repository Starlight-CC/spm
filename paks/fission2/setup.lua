local settings = {}
print("#Turbines ?")
settings.turbineNum=tonumber(read())
local i = 0
settings.turbines = {}
while i < settings.turbineNum do
    print("id for turbine ",i)
    settings.turbines[tostring(i)]="turbineValve_"..read()
    i=i+1
end
print("reactor id ?")
settings.reactor="fissionReactorLogicAdapter_"..read()
print("Boiler ? y/n")
local tmp = read()
if tmp == "y" then
    settings.boiler=true
elseif tmp == "n" then
    settings.boiler=false
else
    error("invalid input")
end
print("auto overclock ? y/n")
local tmp = read()
if tmp == "y" then
    settings.overclock=true
elseif tmp == "n" then
    settings.overclock=false
else
    error("invalid input")
end
print("max reactor damage ?")
settings.maxDmg=tonumber(read())
print("done")
registry.set("Fission2.settings",settings)
registry.save()