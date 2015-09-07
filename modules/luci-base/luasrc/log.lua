local file = io.open("/tmp/debug.txt", "a")
local os = _G.os
local format = string.format
local table = _G.table 
assert(file)
module "luci.log"

function log(...)
	local msg = table.concat(arg, " ") .. "\n"
	if msg then
		file:write(msg)
		file:flush()
	end
end

function logm(msg)
	if msg then 
		file:write(msg)
		file:flush()
	end
end