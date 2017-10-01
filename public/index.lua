local data = ...

local requesttype, me, args, http, ip = data[1], data[2], data[3], data[4], data[5]

local doc = [[
<!DOCTYPE HTML>
<html>
<head>
</head>
<body>
	<h1>Args:</h1>
]]
if args then
	for k,v in pairs(args) do
		doc = doc.."\t<p>"..k..": "..v.." </p>\n"
	end
end

doc = doc..[[
	<form class="submit_form" method="get" action="index.lua" autocomplete="off">
		<div style="text-align: left">
			<table>
				<tr>
					<td>Nev:</td>
					<td><input name="s_nev" tabindex="1" type="text"></td>
					<td colspan="2"><input name="s_nev_sub" value="Belepes" type="submit"></td>
				</tr>				
			</table>
		</div>
	</form>
</body>
</html>]]

local header = http.." 200 OK".."\n"..
	"Date: "..os.date().."\n"..
	"Server: VpLua".."\n"..
	"Content-Length: "..doc:len().."\n"..
	"Content-Type: text/html; charset=utf-8".."\n"

return header.."\n"..doc