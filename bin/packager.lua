local __L_as,__L_to,__L_gmt=assert,type,getmetatable;local function __L_t(o)local t=__L_to(o) if t=="table" then local mt = __L_gmt(o)return (mt and mt.__type) or t end return t end;local packager = {  }

local luafier = require("to_lua")


local function packageModuleImportImpl(luafier, libliteral)
	luafier.buf:append("__L_load(")
	luafier:writeNode(libliteral);luafier.buf:append(")")
end


function packager.packageMap(m, entry)
	__L_as(__L_t(m)=="table", "Invalid value for 'm'. Expected a 'table'");__L_as(entry==nil or __L_t(entry)=="string", "Invalid value for 'entry'. Expected a 'string'")
	local outArray = {  }
	table.insert(outArray, [[
local __L_mods = {}
local function __L_define(name, init)
	__L_mods[name] = init
end
local function __L_load(name)
	return __L_mods[name]()
end
]])








	table.insert(outArray, luafier.lunaHeader)
	table.insert(outArray, "\n")

	for path, node in pairs(m) do
		table.insert(outArray, "__L_define(\"" .. path .. "\", function()\n")
		table.insert(outArray, luafier.toLua(node, { matchLinenumbers = false, prettyPrint = false, moduleImportImpl = packageModuleImportImpl, writeHeader = false }))
		table.insert(outArray, " end)")
	end

	if entry then 
	table.insert(outArray, "return __L_load(\"" .. entry .. "\")") end


	return table.concat(outArray, "")
end


return packager