local __L_as,__L_to,__L_gmt=assert,type,getmetatable;local function __L_t(o)local t=__L_to(o) if t=="table" then local mt = __L_gmt(o)return (mt and mt.__type) or t end return t end;local lexer = require("lexer")
local parser = require("parser")
local luafier = require("to_lua")

local compiler = {  }

function compiler.lunaToAST(code)
	__L_as(__L_t(code)=="string", "Invalid value for 'code'. Expected a 'string'")
	local l = lexer.new(code)
	local p = parser.new(l)
	return p:block()
end
function compiler.lunaToLua(code)
	__L_as(__L_t(code)=="string", "Invalid value for 'code'. Expected a 'string'")
	local ast = compiler.lunaToAST(code)
	return luafier.toLua(ast)
end
return compiler