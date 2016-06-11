
local luafier = {}

function luafier.listToLua(list, opts, buf)
	for i,snode in ipairs(list) do
		if i > 1 then buf:append(", ") end
		luafier.internalToLua(snode, opts, buf)
	end
end

function luafier.processParListFuncBlock(parlist, funcbody)
	local typechecks = {}
	for _,par in ipairs(parlist) do
		local name = par[1]
		local type = par[2]
		if type then
			table.insert(typechecks, {var = name.text, type = type[1].text, nillable = type[2]})
		end
	end

	for i,tc in pairs(typechecks) do
		local tcnode = { type = "funccall" }
		tcnode[1] = { type = "identifier", text = "assert" }
		local args = { type = "explist" }
		tcnode[2] = args

		local typeChecker = {
			type = "binop", "==",
			{ type = "funccall", { type = "identifier", text = "type" }, { type = "identifier", text = tc.var } },
			{ type = "literal", text = "\"" .. tc.type .. "\""}
		}
		if tc.nillable then
			local nilChecker = { type = "unop", "not", { type = "identifier", text = tc.var } }
			args[1] = { type = "binop", "or", nilChecker, typeChecker }
		else
			args[1] = typeChecker
		end

		args[2] = { type = "literal", text = [["Parameter ']] .. tc.var .. [[' must be a ]] .. tc.type .. [["]]}
		
		table.insert(funcbody, i, tcnode)
	end

	return parlist, funcbody
end

local luaBuffer = {}
luaBuffer.__index = luaBuffer

function luaBuffer.new(indentString)
	return setmetatable({buf = {}, indent = 0, indentString = indentString or "\t", line = 1}, luaBuffer)
end
function luaBuffer:appendln(t)
	self:append(t)
	self:nl()
end
function luaBuffer:append(t)
	if not self.hasIndented then
		self.buf[#self.buf + 1] = self.indentString:rep(self.indent)
		self.hasIndented = true
	end
	self.buf[#self.buf + 1] = t
end
function luaBuffer:nl()
	self.buf[#self.buf + 1] = "\n"
	self.line = self.line + 1
	self.hasIndented = false
end
function luaBuffer:nlIndent()
	self:nl()
	self.indent = self.indent + 1
end
function luaBuffer:nlUnindent()
	self:nl()
	self.indent = self.indent - 1
end
function luaBuffer:tostring()
	return table.concat(self.buf, "")
end

function luafier.internalToLua(node, opts, buf)
	local function toLua(lnode)
		luafier.internalToLua(lnode, opts, buf)
	end
	local function listToLua(lnode)
		luafier.listToLua(lnode, opts, buf)
	end

	if node.type == "block" then
		for i,snode in ipairs(node) do
			-- add newlines before all except first node
			if i > 1 then buf:nl() end

			local targLine = snode.line
			local curLine = buf.line

			if targLine and targLine > curLine then
				-- add some nls to reach targLine if needed
				for _ = 1, (targLine - curLine) do
					buf:nl()
				end
			end

			toLua(snode)
		end

	elseif node.type == "local" then
		buf:append("local ")
		toLua(node[1])
		if node[2] then -- has explist
			buf:append(" = ")
			toLua(node[2])
		end

	elseif node.type == "localfunc" then
		buf:append("local function ")
		toLua(node[1])
		toLua(node[2])

	elseif node.type == "globalfunc" then
		buf:append("function ")
		toLua(node[1])
		toLua(node[2])

	elseif node.type == "func" then
		buf:append("function ")
		toLua(node[1])

	elseif node.type == "sfunc" then
		local pl, fb = luafier.processParListFuncBlock(node[1], node[2])
		buf:append("function(")
		listToLua(pl)
		buf:append(") ")
		toLua(fb)
		buf:append(" end")

	elseif node.type == "funcbody" then
		local pl, fb = luafier.processParListFuncBlock(node[1], node[2])
		buf:append("(")
		listToLua(pl)
		buf:append(") ")
		toLua(fb)
		buf:append(" end")

	elseif node.type == "assignment" then
		local op = node[1]

		if op == "=" then
			toLua(node[2]); buf:append(" = "); toLua(node[3])
		else
			assert(#node[3] == 1, "assignment mod only works on 1-long explists currently")

			-- what kind of modification to do
			local modop = op:sub(1, 1)
			
			toLua(node[2]); buf:append(" = "); toLua(node[2]); buf:append(" "); buf:append(modop); buf:append(" ("); toLua(node[3]); buf:append(")")
		end
	elseif node.type == "funccall" then
		toLua(node[1]); buf:append("("); toLua(node[2]); buf:append(")")

	elseif node.type == "args" or node.type == "fieldlist" or node.type == "parlist" or node.type == "typednamelist" or node.type == "varlist" or node.type == "explist" then
		listToLua(node)
		
	elseif node.type == "typedname" then
		toLua(node[1])

	elseif node.type == "return" then
		buf:append("return "); toLua(node[1])

	elseif node.type == "break" then
		buf:append("break")

	elseif node.type == "index" then
		toLua(node[1]); buf:append("."); toLua(node[2])

	elseif node.type == "tableconstructor" then
		buf:append("{"); toLua(node[1]); buf:append("}")
		
	elseif node.type == "field" then
		local key, val = node[1], node[2]
		if key then
			toLua(key); buf:append(" = "); toLua(val)
		else
			toLua(val)
		end

	elseif node.type == "if" then
		buf:append("if "); toLua(node[1]); buf:append(" then"); buf:nlIndent()
		toLua(node[2]); buf:nlUnindent()
		if node[3] then
			toLua(node[3])
		else
			buf:append("end")
		end
	elseif node.type == "ifassign" then
		-- Create a temporary variable name for the variable to be assigned before the if
		local origAssignedVarName = node[1][1][1][1].text -- ohgod
		local varName = "_ifa_" .. origAssignedVarName

		-- Set the assignment variable name to generated name
		node[1][1][1][1].text = varName

		-- Create a new if block that checks if varName is trueish
		local varId = { type = "identifier", text = varName }
		local checkerIf = { type = "if", varId, node[2] }

		-- Create a new local binding to restore the old name within the if scope and set it as the first code within if
		local restoreBinding = { type = "local", { type = "identifier", text = origAssignedVarName }, varId }
		table.insert(checkerIf[2], 1, restoreBinding)

		toLua(node[1]); buf:nl()
		toLua(checkerIf)
	elseif node.type == "elseif" then
		buf:append("elseif "); toLua(node[1]); buf:append(" then"); buf:nlIndent()
		toLua(node[2]); buf:nlUnindent()
		if node[3] then
			toLua(node[3])
		else
			buf:append("end")
		end
	elseif node.type == "else" then
		buf:append("else"); buf:nlIndent()
		toLua(node[2]); buf:nlUnindent()
		buf:append("end")

	elseif node.type == "binop" then
		toLua(node[2]); buf:append(" "); buf:append(node[1]); buf:append(" "); toLua(node[3])
		
	elseif node.type == "unop" then
		buf:append(node[1]); buf:append(" "); toLua(node[2])

	elseif node.type == "identifier" then
		buf:append(node.text)
		
	elseif node.type == "literal" then
		buf:append(node.text)

	elseif node.type == "number" then
		buf:append(node.text)

	else
		error("unhandled ast node " .. node.type)
	end
end

function luafier.toLua(node, opts)
	local buf = luaBuffer.new()
	luafier.internalToLua(node, opts, buf)
	return buf:tostring()
end

return luafier