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
	<table>
		<form class="submit_form" method="post" action="index.lua" autocomplete="off">
			<tr>
				<td>Post:</td>
				<td><input name="s_nev" tabindex="1" type="text"></td>
				<td colspan="2"><input name="s_nev_sub" value="Küld" type="submit"></td>
			</tr>				
		</form>
		<form class="submit_form" method="get" action="index.lua" autocomplete="off">
			<tr>
				<td>Get:</td>
				<td><input name="s_nev" tabindex="1" type="text"></td>
				<td colspan="2"><input name="s_nev_sub" value="Küld" type="submit"></td>
			</tr>
		</form>             
	</table>
</body>
</html>]]

return doc