local startArgs = {...}
local api = {}
local textutils = textutils
local fs = fs
local http = http
local os = os
local json = {}

if include then
    http = require("os.http")
    fs = require("os.fs")
    os = require("os")
    json = require("json")
    textutils = require("cc.textutils")
else
    if fs.exists("/lib/json/init") then
        json = require("/lib/json/init")
    else
        json = nil
    end
end

local function isin(val,tbl,typ)
    if typ == true then
        for i,_ in pairs(tbl) do
            if i == val then
                return true
            end
        end
    else
        for _,v in pairs(tbl) do
            if v == val then
                return true
            end
        end
    end
    return false
end

local cachefile = fs.open("/var/spm/cache.var","r")
local cache = cachefile.readAll()
cachefile.close()
cachefile = nil

local function api.get(url,ignoreCache)
    if ignoreCache then
        local content = http.get(url)
        if content then
            content = content.readAll()
        else
            error("Invaild PAK")
        end
        cache[tostring(url)] = {data=content,time=os.epoch()}
        return content
    else
        if isin(url,cache,true) then
            local content = cache[tostring(url)]
            if content.time+120000 < os.epoch() then
                content = http.get(url)
                if content.readAll then
                    content = content.readAll()
                else
                    error("Invaild PAK")
                end
                cache[tostring(url)] = {data=content,time=os.epoch()}
                return content
            else
                return content.data
            end
        else
            local content = http.get(url)
            if content.readAll then
                content = content.readAll()
            else
                error("Invaild PAK")
            end
            cache[tostring(url)] = {data=content,time=os.epoch()}
            return content
        end
    end
end

local function getManifest(package,ignoreCache)
    local metadata = api.get("https://raw.githubusercontent.com/Starlight-CC/spm/refs/heads/main/paks/"..package.."/manifest.json",ignoreCache)
    if not json then
        metadata = textutils.unserialiseJSON(metadata)
    else
        metadata = json.decode(metadata)
    end
    return metadata
end

local function getDependents(package,ignoreCache)
    local ret = {}
    local metadata = getManifest(package,ignoreCache)
    for _,v in ipairs(metadata.requires) do 
        table.insert(ret,v)
        for _,v in ipairs(getDependents(v,ignoreCache)) do
            if not isin(v,ret) then
                table.insert(ret,v)
            end
        end
    end
    return ret
end
local function download(package,ignoreCache,alwaysTrue)
    local metadata = getManifest(package,ignoreCache)
    local dependents = getDependents(package,ignoreCache)
    print("the following packages will be installed")
    print(table.concat(dependents," | "))
    print("(Y/N)")
    if alwaysTrue then
        print("y")
    end
    os -- WIP


local args = {}
args.flags = {}
for i,v in ipairs(startArgs) do
    if i == 1 then
        args.command = v
    else
        if string.sub(1,1) == "-" then
            args.flags[tostring(v)]=true
        else
            args[i-1]=v
        end
    end
end
        
local regfile = fs.open("/var/spm/reg.var","r")
local reg = regfile.readAll()
regfile.close()
regfile = nil

if args.command ~= "setup" then
    if not json then
        error("Please run \"spm setup\" to install spm")
    end
end
if args.command == "setup" then
    download("json")
    print("spm installed")
elseif args.command == "update" then
    local api.get("https://api.github.com/repos/Starlight-CC/spm/contents/paks",args.flags["-c"])
    json.decode()