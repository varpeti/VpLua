local server = {}
server.LOG = false
server.address, server.port, server.timeout = "*", 3773, 1
server.autoheader = function (http,length) return 
	http.." 200 OK".."\n"..
	"Date: "..os.date().."\n"..
	"Server: VpLua".."\n"..
	"Content-Length: "..length.."\n"..
	"Content-Type: text/html; charset=utf-8".."\n"..
	"\n"
end
server.socket = require("socket")

local function split(inp,pat)
	pat = pat and "([^"..pat.."]*)"..pat or "%S+"
	out = {}
	for i in string.gmatch(inp,pat) do
		table.insert(out,i)
	end
	return out
end

local function parameterkiszed(d,params)
	params = params or {}
	local d = split(d.."&","&")
	for i,v in ipairs(d) do
		local a = split(v.."=","=")
		if a[1]~="" and a[2]~="" and a[2] then 
			a[2] = string.gsub(a[2], '+', " ") -- a "+"" jel "%2B", a " " pedig vagy "+"" vagy "%20", ezért a "+" átalakítjuk " ".
			a[2] = string.gsub(a[2], '%%(%x%x)', function (hex) return string.char(tonumber(hex, 16)) end) -- kiszedi a url hexákat ("%20" -> " ")
			params[a[1]]=a[2] 
		end 
	end
	return params
end

local function deep_prety_print(data,szint)
	szint = szint or 0
	local r = ""

	local t = ""
	for i=1,szint do t = t.."\t" end

	if type(data)=="table" then
		for k,v in pairs(data) do
			r = r..t..tostring(k)..":\n"..deep_prety_print(v,szint+1)
		end
	else
		r = t..tostring(data).."\n"
	end
	return r
end

function server.log(data)
	if not server.LOG then return end

	file = io.open("VpLua.log", "a+")
	if file==nil then return end

	file:write(deep_prety_print(data))

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

function server.feldolgoz_header(header)
	local requesttype,dir,params,http,headers = "","/",{},"",{}
	
	local d0 = split(header,"\n") --soronként
	if not d0[1] then return end
	
	local d1 = split(d0[1]) -- GET params HTTP/1.1
	if #d1<3 then return end

	requesttype = d1[1] -- GET/POST
	http = d1[3] -- HTTP/1.1

	--Paraméterek és a könyvtár/file
	if string.find(d1[2],"%?") then
		local d2 = split(d1[2].."?","%?") -- dir ? params
		dir = d2[1]
		params = parameterkiszed(d2[2])
	else
		dir = d1[2] -- dir/file
	end

	if string.sub(dir,-1, -1) ~= "/" then dir=dir.."/" end -- utolsó / hozzáadás
	dir = string.sub(dir,2, -1) -- elso / elvétel

	--Többi header beolvasása
	for i,line in ipairs(d0) do
		local name,value = string.match(line, "^(.-):%s*(.*)")
		if name and value then
			headers[name]=value
		end
	end

	return {requesttype,dir,params,http,headers}
end

function server.feldolgoz_content(sdata,args)
	if not sdata then return nil end
	parameterkiszed(sdata,args)
	return args
end

function server.start()
	server.tcp, err = server.socket.bind(server.address, server.port)
	if not server.tcp then print(server.tcp,err) return end

	while true do
		local client = server.tcp:accept()
		if client then
			client:settimeout(server.timeout)


			repeat
				local bont = true;

				--Kérés, header beolvasás
				local header = ""
				while true do
					local line, err = client:receive()
					if line==nil or line=="" or err~=nil then break end
					header = header..tostring(line).."\n"
				end
	
				if header and header~="nil\n" then
					--Ha van content, beolvassa
					local content = ""
					local ContentSize = string.match(header,"Content%-Length: (%d+)")
					ContentSize = tonumber(ContentSize)
					if ContentSize~=nil and ContentSize>0 then
						content = client:receive(ContentSize)
					end
	
					local data = server.feldolgoz_header(header) -- requesttype,me,params,http,headers
					if data then
						data[3] = server.feldolgoz_content(content,data[3]) --paraméterek ha vannak a contentben
						data[6] = client:getpeername() --ip
		
						server.log(data) -- A teljes request feldolgozva
				
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
						else -- nincs meg a kért file
							ret=data[4].." 404 Not Found\n\n".."404 Not Found"
							server.log(ret)
						end
					
						if type(ret)=="string" then client:send(server.autoheader(data[4],ret:len())..ret) end
	
					else --nincs data
						bont=false 
					end
				else --nincs header
					bont=false -- nem bontjuk a kapcsolatot ha nil-t küldött, várunk a normális requestre.
				end
			until bont

			server.log("---\n")
			client:close()
		end
	end

	server.tcp:close()
end

server.start()