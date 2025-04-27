--authors
--Chris
--Astronand
print("do you want to track? \n Y/N")
local T = io.read()
local On = true
local p = peripheral.search("back")
local Range = 128

while true do
    local players = p.getPlayersInRange(Range)
    local id = 0
    print("who out of this list")
    
    while id ~= table.getn(players) do
        id = id + 1
        print(id , players[id])
    end
    if On then
        local A = tonumber(io.read())
        while T == "y" or T == "Y" do
            local Pos = p.getPlayerPos(players[A])
            print("X", Pos.x)
            print("Y", Pos.y)
            print("Z", Pos.z)
            if X ~= Pos.x or Y ~= Pos.y or Z ~= Pos.z then
                sleep(.1)
                shell.run("clear all")
            end
            local X = Pos.x
            local Y = Pos.y
            local Z = Pos.z
         end
    end
    sleep(3)
    shell.run("clear all")
end
