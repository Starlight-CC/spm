local startArgs = {...}
local api = {}
local textutils = textutils
local fs = fs
local http = http
local os = os
local shell = shell
local json = {}

if _ARCH then
    http = require("os.http")
    fs = require("os.fs")
    os = require("os")
    shell = require("shell")
    json = require("json")
    textutils = require("cc.textutils")
else
    if fs.exists("/lib/json/init") then
        json = require("/lib/json/init")
    else
        json = nil
    end
end

local decode,encode = {},{}
if json then
    decode = json.decode
    encode = json.encode
else
    decode = textutils.unserialiseJSON
    encode = textutils.serialiseJSON
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

local cachefile = fs.open("/var/spm/cache.json","r")
local cache = decode(cachefile.readAll())
cachefile.close()
cachefile = nil
if cache == nil then
    cache = {}
end

local regfile = fs.open("/var/spm/reg.json","r")
local reg = decode(regfile.readAll())
regfile.close()
regfile = nil
if reg == nil then
    reg = {}
end

local pakfile = fs.open("/var/spm/paks.json","r")
local pak = decode(pakfile.readAll())
pakfile.close()
pakfile = nil
if pak == nil then
    pak = {}
end

function api.get(url,ignoreCache)
    if ignoreCache then
        local handle = http.get(url)
        local content = ""
        if handle then
            content = handle.readAll()
            handle.close()
        else
            error("Invaild PAK")
        end
        cache[tostring(url)] = {data=content,time=os.epoch()}
        return content
    else
        if isin(url,cache,true) then
            local content = cache[tostring(url)]
            if content.time+120000 < os.epoch() then
                local handle = http.get(url)
                local content = ""
                if handle then
                    content = handle.readAll()
                    handle.close()
                else
                    error("Invaild PAK")
                end
                cache[tostring(url)] = {data=content,time=os.epoch()}
                return content
            else
                return content.data
            end
        else
            local handle = http.get(url)
            local content = ""
            if handle then
                content = handle.readAll()
                handle.close()
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
    metadata = decode(metadata)
    return metadata
end

local function getDependents(package,ignoreCache,update)
    local ret = {}
    local metadata = getManifest(package,ignoreCache)
    metadata = metadata.metadata
    if metadata.requires == nil then
        metadata.requires = {}
    end
    for _,v in ipairs(metadata.requires) do 
        table.insert(ret,v)
        for _,v in ipairs(getDependents(v,ignoreCache,update)) do
            if not isin(v,ret) or isin(v,reg) then
                table.insert(ret,v)
            end
        end
    end
    return ret
end

local function save()
    local regfile = fs.open("/var/spm/reg.json","w")
    local pakfile = fs.open("/var/spm/reg.json","w")
    local cachefile = fs.open("/var/spm/cache.json","w")
    regfile.write(encode(reg))
    pakfile.write(encode(pak))
    cachefile.write(encode(cache))
    regfile.close()
    pakfile.close()
    cachefile.close()
    regfile = nil
    pakfile = nil
    cachefile = nil
end

local function processManifest(manifest,ignoreCache)
    pak[tostring(manifest.metadata.name)]={}
    pak[tostring(manifest.metadata.name)].version=manifest.metadata.version
    pak[tostring(manifest.metadata.name)].authors=manifest.metadata.authors
    pak[tostring(manifest.metadata.name)].license=manifest.metadata.license
    for i,v in pairs(manifest.fs) do
        if string.sub(i,1,1) == "~" then
            if not _ARCH then
                local file = fs.open(string.sub(i,2),"w")
                local content = api.get("https://raw.githubusercontent.com/Starlight-CC/spm/refs/heads/main/paks/"..tostring(manifest.metadata.name)..v,ignoreCache)
                file.write(content)
                file.close()
            else
                --WIP
            end
        elseif string.sub(i,1,1) == "/" then
            local file = fs.open(i,"w")
            local content = api.get("https://raw.githubusercontent.com/Starlight-CC/spm/refs/heads/main/paks/"..tostring(manifest.metadata.name)..v,ignoreCache)
            file.write(content)
            file.close()
        else
            local file = fs.open(shell.dir().."/"..i,"w")
            local content = api.get("https://raw.githubusercontent.com/Starlight-CC/spm/refs/heads/main/paks/"..tostring(manifest.metadata.name)..v,ignoreCache)
            file.write(content)
            file.close()
        end
    end
end

local function downloadPackage(package,ignoreCache,update)
    local metadata = getManifest(package,ignoreCache)
    local dependents = getDependents(package,ignoreCache,update)
    for _,v in ipairs(dependents) do
        local dependent = getManifest(v,ignoreCache)
        processManifest(dependent,ignoreCache)
    end
    processManifest(metadata,ignoreCache)
end

local function download(package,ignoreCache,update,alwaysTrue)
    local metadata = getManifest(package,ignoreCache)
    local dependents = getDependents(package,ignoreCache,update)
    print("the following packages will be installed")
    print(table.concat(dependents," | "))
    print("(Y/N)")
    if alwaysTrue then
        print("y")
    end

    local ret = ""
    while true do
        if alwaysTrue then
            ret = "y"
            break
        end
        local event, param = os.pullEvent()
        if event == "key" then
            if param == keys.y then
                ret = "y"
                print("y")
                break
            elseif param == keys.n then
                ret = "n"
                print("n")
                break
            end
        end
    end

    if ret == "y" then
        downloadPackage(package,ignoreCache,update)
    end
end

local args = {}
args.flags = {}
for i,v in ipairs(startArgs) do
    if i == 1 then
        args.command = v
    else
        if string.sub(v,1,1) == "-" then
            args.flags[tostring(v)]=true
        else
            args[i-1]=v
        end
    end
end

if args.command ~= "setup" and not args.flags["-j"] then
    if not json then
        error("Please run \"spm setup\" to install spm")
    end
end

local function updateRegistry()
    local data = api.get("https://api.github.com/repos/Starlight-CC/spm/contents/paks",args.flags["-c"])
    data = decode(data)
    reg = {}
    for i,v in ipairs(data) do
        reg[i]=v.name
    end
end
if args.flags["-j"] then
    encode = textutils.serialiseJSON
    decode = textutils.unserialiseJSON
end
if args.command == "setup" then
    download("json",true,true,true)
    updateRegistry()
    print("spm installed")
elseif args.command == "update" then
    updateRegistry()
elseif args.command == "install" then
    download(args[1])
elseif args.command == "list" then
    for i,v in ipairs(reg) do
        print(v)
    end
end
save()