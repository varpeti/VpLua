local server = {}
server.LOG = true
server.address, server.port, server.timeout = "*", 3773, 10
server.socket = require("socket")
server.tcp = assert(socket.tcp())


local function split(inp,pat)
    pat = pat and "([^"..pat.."]*)"..pat or "%S+"
    out = {}
    for i in string.gmatch(inp,pat) do
        table.insert(out,i)
    end
    return out
end

local function deep_prety_print(tbl,szint)
    local r = ""
    szint = szint or 0
    for i, v in pairs(tbl) do
        for i=1,szint do r=r.."\t" end
        if type(v) == "table" then 
            r=r..i..": ".."\n"..deep_prety_print(v,szint+1)
        else
            r=r..i..": "..tostring(v).."\n"
        end
    end
    return r
end

function server.log(data)
    if not server.LOG then return end

    file = io.open("VpLua.log", "a+")
    if file==nil then return end
    if type(data)=="table" then
        file:write(deep_prety_print(data).."\n")
    else
        file:write(tostring(data).."\n")
    end
    file:close()
end

function server.fileexists(name)
	name="public/"..name
    name=string.sub(name,1,-2)
    if name=="" then name="index.lua" end
    local f=io.open(name,"r")
    if f~=nil then 
        --azt is nézi hogy nem könyvtár-e
        local ok, err, code = f:read(1) 
        io.close(f) 
        if code==21 then
            return true, name.."/index.lua" --vegpont
        else
            return true, name -- file 
        end
    end 
    return false, name
end

function server.feldolgoz(sdata)
    local dir = "/"
    local params = {}
    local data = split(sdata) -- GET params HTTP/1.1
    if #data<3 then return end
    if string.find(data[2],"%?") then
        local d2 = split(data[2].."?","%?") -- dir ? params
        dir = d2[1]
        d2 = string.gsub(data[2],d2[1].."%?", "") -- params

        local d3 = split(d2.."&","&")
        for i,v in ipairs(d3) do
            local a = split(v.."=","=")
            if a[1]~="" and a[2]~="" and a[2] then 
                a[2] = string.gsub(a[2], '%%(%x%x)', function (hex) return string.char(tonumber(hex, 16)) end) -- kiszedi a url hexákat ("%20" -> " ")
                params[a[1]]=a[2] 
            end 
            
        end
    else
        dir = data[2] -- dir
    end

    if string.sub(dir,-1, -1) ~= "/" then dir=dir.."/" end -- utolsó /
    dir = string.sub(dir,2, -1) -- elso /

    return {data[1],dir,params,data[3]}
end

function server.start()

    if not server.tcp:bind(server.address, server.port) then return end
    server.tcp:listen()

    while true do
        local client = server.tcp:accept()
        if client then
            client:settimeout(server.timeout)
        
            local data, err = client:receive()
            if data then
                server.log(data)
                data = server.feldolgoz(data)
                if data then  
                    data[5] = client:getpeername()
        
                    local ret = ""
                    local van = false
        
                    van, data[2] = server.fileexists(data[2])
                    if van then
                        local status, err = 
                            pcall(
                                function()
                                    if unexpected_condition then error() end
                                    ret = loadfile(data[2])(data)
                                end
                            )
                        if not status then 
                            ret = data[4].." 500 Internal Server Error\n\n"..tostring(err)
                            server.log(ret)
                        end
                    else
                        ret=data[4].." 404 Not Found\n\n".."404 Not Found"
                        server.log(ret)
                    end
            
                    if type(ret)=="string" then client:send(ret) end
                    server.log(data)
                end
            end
            server.log("---\n")
            client:close()
        end
    end

    server.tcp:close()
end

server.start()