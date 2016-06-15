local __L_as,__L_to,__L_gmt=assert,type,getmetatable;local function __L_t(o)local t=__L_to(o) if t=="table" then local mt = __L_gmt(o)return (mt and mt.__type) or t end return t end;
local to_lua = {  }

local LUAFN_ASSERT = "__L_as"
local LUAFN_TYPE = "__L_t"

function to_lua.isNode(o)
	return type(o) == "table" and not not o.type
end


function to_lua.getNodeLastLine(n)
	local s = n.line
	if not s then return -1 end

	local l = s
	for k, v in ipairs(n) do
		if to_lua.isNode(v) then 
		l = math.max(l, to_lua.getNodeLastLine(v)) end
	end

	return l
end

function to_lua.isParentOf(par, node)
	if par == node then return true end
	for k, v in ipairs(par) do
		if v == node or (to_lua.isNode(v) and to_lua.isParentOf(v, node)) then return true end
	end
	return false
end



function to_lua.getLinenoDiff(node1, node2)
	local line1, line2

	if type(node1) == "number" then 
	line1 = node1 else 

	line1 = to_lua.getNodeLastLine(node1) end


	line2 = node2.line

	if not line1 or not line2 then 
	return nil end


	return line2 - line1
end


function to_lua.processParListFuncBlock(parlist, funcbody)
	__L_as(__L_t(parlist) == "lunanode", "Parameter 'parlist' must be a lunanode");__L_as(__L_t(funcbody) == "lunanode", "Parameter 'funcbody' must be a lunanode")
	local paramextras = {  }
	for _, par in ipairs(parlist) do
		local name, type, value
		if par.type == "paramwithvalue" then name, type = par[1][1], par[1][2]
		value = par[2] else 

		name, type = par[1], par[2] end


		if type or value then 
		local pex = { var = name.text }

		if type then 
		pex.type = type[1].text
		pex.nillable = type.isOptional end

		if value then 
		pex.value = value end


		table.insert(paramextras, pex) end
	end


	for i, tc in pairs(paramextras) do
		__L_as(tc, "cannot destructure nil");local var, type, nillable, value = tc.var, tc.type, tc.nillable, tc.value

		if type then 
		local tcnode = parlist:cloneMeta("funccall")
		tcnode[1] = tcnode:cloneMeta("identifier", { text = LUAFN_ASSERT })
		local args = tcnode:cloneMeta("explist")
		tcnode[2] = args

		local typeChecker = parlist:cloneMeta("binop", {
			parlist:cloneMeta("t_binop", { text = "==" }), 
			parlist:cloneMeta("funccall", { parlist:cloneMeta("identifier", { text = LUAFN_TYPE }), parlist:cloneMeta("identifier", { text = var }) }), 
			parlist:cloneMeta("literal", { text = "\"" .. type .. "\"" })
		})
		if nillable then 
		local nilChecker = parlist:cloneMeta("binop", {
			parlist:cloneMeta("t_binop", { text = "==" }), 
			parlist:cloneMeta("identifier", { text = var }), 
			parlist:cloneMeta("keyword", { text = "nil" })
		})
		args[1] = parlist:cloneMeta("binop", { parlist:cloneMeta("t_binop", { text = "or" }), nilChecker, typeChecker }) else 

		args[1] = typeChecker end


		args[2] = parlist:cloneMeta("literal", { text = [["Parameter ']] .. var .. [[' must be a ]] .. type .. [["]] })

		table.insert(funcbody, i, tcnode) end


		if value then 
		local as = parlist:cloneMeta("assignment")


		value.line = nil

		as[1] = as:cloneMeta("t_assignop", { text = "=" })
		as[2] = as:cloneMeta("identifier", { text = var })
		as[3] = as:cloneMeta("binop", { as:cloneMeta("t_binop", { text = "or" }), as[2], value })

		table.insert(funcbody, i, as) end
	end


	return parlist, funcbody
end

local luaBuffer = {  }
luaBuffer.__index = luaBuffer
luaBuffer.__type = "luabuf"

function luaBuffer.new(indentString, nlString, noExtraSpace)
	return setmetatable({
		buf = {  }, 
		indent = 0, 
		indentString = indentString, 
		nlString = nlString, 
		noExtraSpace = noExtraSpace, 

		line = 1
	}, 
	luaBuffer)
end
function luaBuffer:appendln(t)
	self:append(t)
	self:nl()
end
function luaBuffer:append(t)
	if not self.hasIndented then self.buf[#self.buf + 1] = self.indentString:rep(self.indent)
	self.hasIndented = true end

	self.buf[#self.buf + 1] = t
end
function luaBuffer:nl()
	self.buf[#self.buf + 1] = self.nlString
	self.line = self.line + (1)
	self.hasIndented = false
end
function luaBuffer:nlIndent()
	self:nl()
	self.indent = self.indent + (1)
end
function luaBuffer:nlUnindent()
	self:nl()
	self.indent = self.indent - (1)
end

function luaBuffer:getTmpIndexAndIncrement()
	self._tmpIndex = (self._tmpIndex or -1) + 1
	return self._tmpIndex
end


function luaBuffer:appendSpace(t)
	__L_as(__L_t(t) == "string", "Parameter 't' must be a string")
	if not self.noExtraSpace then self:append(t) end
end



function luaBuffer:checkLastNode(pattern)
	__L_as(__L_t(pattern) == "string", "Parameter 'pattern' must be a string")
	local __ifa0_ln = self.buf[#self.buf]; if __ifa0_ln then local ln = __ifa0_ln
	return not not ln:match(pattern) end
end

function luaBuffer:tostring()
	return table.concat(self.buf, "")
end

local luafier = {  }
luafier.__index = luafier
luafier.__type = "luafier"

function luafier.new(buf, opts)
	__L_as(__L_t(buf) == "luabuf", "Parameter 'buf' must be a luabuf");__L_as(__L_t(opts) == "table", "Parameter 'opts' must be a table")
	return setmetatable({
		buf = buf, 
		opts = opts
	}, 
	luafier)
end
function luafier:getLinenoDiff(node1, node2)
	if self.opts.matchLinenumbers then return to_lua.getLinenoDiff(node1, node2) end
end






function luafier:wrapIndent(n1, n2, fn, alsoIfPrettyPrint)
	local lndiff = self:getLinenoDiff(n1, n2)
	local addNl = lndiff or ((alsoIfPrettyPrint and self.opts.prettyPrint) and 1) or 0

	if addNl > 0 then 
	self.buf:nlIndent()
	for i = 1, addNl - 1 do self.buf:nl() end else 

	self.buf:appendSpace(" ") end


	fn()

	if addNl > 0 then 
	self.buf:nlUnindent() else 

	self.buf:append(" ") end
end


function luafier:writeList(list)
	__L_as(__L_t(list) == "lunanode", "Parameter 'list' must be a lunanode")
	local lastnode
	for i, snode in ipairs(list) do
		if i > 1 then self.buf:append(", ") end
		local lndiff = self.opts.matchLinenumbers and lastnode and to_lua.getLinenoDiff(lastnode, snode)
		lastnode = snode
		if lndiff and lndiff > 0 then 
		for i = 1, lndiff do self.buf:nl() end end


		self:writeNode(snode)
	end
end

function luafier:writeNode(node)
	__L_as(__L_t(node) == "lunanode", "Parameter 'node' must be a lunanode")
	__L_as(self, "cannot destructure nil");local opts, buf = self.opts, self.buf

	local toLua = (function(...) return self:writeNode(...) end)
	local listToLua = (function(...) return self:writeList(...) end)
	local getLinenoDiff = (function(...) return self:getLinenoDiff(...) end)
	local wrapIndent = (function(...) return self:wrapIndent(...) end)


	if node.type == "block" then 
	local prevnode
	for i, snode in ipairs(node) do

		local lndiff = getLinenoDiff(buf.line, snode)
		if lndiff then 
		if lndiff > 0 then 
		for i = 1, lndiff do buf:nl() end elseif lndiff == 0 then 


		if i > 1 then buf:nl() end end elseif opts.prettyPrint then 



		if i > 1 then buf:nl() end end



		if buf.hasIndented and buf:checkLastNode("[^%s;]$") then 
		buf:append(";") end


		toLua(snode)

		prevnode = snode
	end elseif node.type == "local" then 


	buf:append("local ")
	toLua(node[1])
	if node[2] then 
	buf:append(" = ")
	toLua(node[2]) end elseif node.type == "localdestructor" then 



	self:writeLocalDestructorNode(node) elseif node.type == "funcname" then 


	local methodOffset = node.isMethod and -1 or 0
	for i = 1, #node + methodOffset do
		if i > 1 then buf:append(".") end
		toLua(node[i])
	end

	if node.isMethod then 
	buf:append(":")
	toLua(node[#node]) end elseif node.type == "localfunc" then 


	buf:append("local function ")
	toLua(node[1])
	toLua(node[2]) elseif node.type == "globalfunc" then 


	buf:append("function ")
	toLua(node[1])
	toLua(node[2]) elseif node.type == "func" then 


	buf:append("function ")
	toLua(node[1]) elseif node.type == "sfunc" or node.type == "funcbody" then 


	local pl, fb = to_lua.processParListFuncBlock(node[1], node[2])

	if node.type == "sfunc" then 
	buf:append("function(") else 

	buf:append("(") end

	listToLua(pl)
	buf:append(")")

	wrapIndent(pl, fb, function () toLua(fb) end, true)

	buf:append("end") elseif node.type == "assignment" then 

	local op = node[1].text

	if op == "=" then 
	toLua(node[2])
	buf:append(" = ");toLua(node[3]) elseif op == "||=" then 
	assert(#node[3] == 1, "falsey assignment only works on 1-long explists currently")
	toLua(node[2])
	buf:append(" = ");toLua(node[2]);buf:append(" or (");toLua(node[3]);buf:append(")") else 
	assert(#node[3] == 1, "mod assignment only works on 1-long explists currently")


	local modop = op:sub(1, 1)

	toLua(node[2])
	buf:append(" = ");toLua(node[2]);buf:append(" ");buf:append(modop);buf:append(" (");toLua(node[3]);buf:append(")") end elseif node.type == "funccall" then 

	toLua(node[1])
	buf:append("(");toLua(node[2]);buf:append(")") elseif node.type == "methodcall" then 
	toLua(node[1])
	buf:append(":");toLua(node[2]);buf:append("(");toLua(node[3]);buf:append(")") elseif node.type == "args" or node.type == "fieldlist" or node.type == "parlist" or node.type == "typednamelist" or node.type == "varlist" or node.type == "explist" then 

	listToLua(node) elseif node.type == "typedname" then 


	toLua(node[1]) elseif node.type == "paramwithvalue" then 

	toLua(node[1]) elseif node.type == "return" then 


	buf:append("return")
	local __ifa1_stat = node[1]; if __ifa1_stat then local stat = __ifa1_stat
	buf:append(" ")
	toLua(stat) end elseif node.type == "returnif" then 



	local nif = node:cloneMeta("if")


	nif[1] = node[2]


	local ncond = node:cloneMeta("return")
	ncond[1] = node[1]
	nif[2] = ncond

	toLua(nif) elseif node.type == "break" then 


	buf:append("break") elseif node.type == "index" then 


	toLua(node[1])
	buf:append(".");toLua(node[2]) elseif node.type == "indexsafe" then 
	buf:append("(")
	toLua(node[1]);buf:append(" and ");toLua(node[1]);buf:append(".");toLua(node[2]);buf:append(")") elseif node.type == "indexb" then 
	toLua(node[1])
	buf:append("[");toLua(node[2]);buf:append("]") elseif node.type == "tableconstructor" then 

	buf:append("{")


	local firstField = node[1][1] or node[1]


	wrapIndent(node.line, firstField, function () toLua(node[1]) end)

	buf:append("}") elseif node.type == "field" then 


	__L_as(node, "cannot destructure nil");local key, val = node[1], node[2]
	if key then 
	if key.type == "identifier" then 
	toLua(key) else 

	buf:append("[")
	toLua(key);buf:append("]") end
	buf:appendSpace(" ")
	buf:append("=");buf:appendSpace(" ");toLua(val) else 
	toLua(val) end elseif node.type == "ifassign" then 




	local origAssignedVarName = node[1][1][1][1].text
	local varName = "__ifa" .. buf:getTmpIndexAndIncrement() .. "_" .. origAssignedVarName


	node[1][1][1][1].text = varName


	local varId = node:cloneMeta("identifier", { text = varName })
	local checkerIf = node:cloneMeta("if", { varId, node[2], node[3] })


	local restoreBinding = node:cloneMeta("local", { node:cloneMeta("identifier", { text = origAssignedVarName }), varId })
	table.insert(checkerIf[2], 1, restoreBinding)

	toLua(node[1])
	buf:append("; ");toLua(checkerIf) elseif node.type == "if" or node.type == "elseif" then 

	buf:append(node.type)
	buf:append(" ");toLua(node[1]);buf:append(" then")
	wrapIndent(node, node[2], function ()
		toLua(node[2])
	end, 
	true)
	if node[3] then 
	toLua(node[3]) else 

	buf:append("end") end elseif node.type == "else" then 


	buf:append("else")
	wrapIndent(node, node[1], function ()
		toLua(node[1])
	end, 
	true)
	buf:append("end") elseif node.type == "while" then 

	buf:append("while ")
	toLua(node[1]);buf:append(" do")
	wrapIndent(node, node[2], function ()
		toLua(node[2])
	end, 
	true);buf:append("end") elseif node.type == "repeat" then 
	buf:append("repeat")
	wrapIndent(node, node[1], function ()
		toLua(node[1])
	end, 
	true)
	buf:append("until ");toLua(node[2]) elseif node.type == "fornum" then 

	__L_as(node, "cannot destructure nil");local var, low, high, step, b = node[1], node[2], node[3], node[4], node[5]
	buf:append("for ")
	toLua(var);buf:appendSpace(" ");buf:append("=");buf:appendSpace(" ");toLua(low);buf:append(",");buf:appendSpace(" ");toLua(high)
	if step then buf:append(",")
	buf:appendSpace(" ")
	toLua(step) end
	buf:append(" do")
	wrapIndent(var, b, function ()
		toLua(b)
	end, 
	true)
	buf:append("end") elseif node.type == "forgen" then 
	__L_as(node, "cannot destructure nil");local names, iter, b = node[1], node[2], node[3]
	buf:append("for ")
	toLua(names);buf:append(" in ");toLua(iter);buf:append(" do")
	wrapIndent(iter, b, function ()
		toLua(b)
	end, 
	true);buf:append("end") elseif node.type == "forof" then 
	self:writeForOfNode(node) elseif node.type == "methodref" then 


	buf:append("(function(...) return ")
	toLua(node[1])
	buf:append(":");toLua(node[2]);buf:append("(...)")
	buf:append(" end)") elseif node.type == "match" then 

	self:writeMatchNode(node) elseif node.type == "binop" then 


	toLua(node[2])
	buf:appendSpace(" ");buf:append(node[1].text)
	local lndiff = getLinenoDiff(node[2], node[3])

	if lndiff and lndiff > 0 then 
	for i = 1, lndiff do buf:nl() end else 

	buf:appendSpace(" ") end

	toLua(node[3]) elseif node.type == "unop" then 


	local op = node[1].text
	buf:append(op)
	if op == "not" then 
	buf:append(" ") end

	toLua(node[2]) elseif node.type == "typecheck" then 


	buf:append(LUAFN_TYPE)
	buf:append("(");toLua(node[1]);buf:append(")==\"");buf:append(node[2][1].text);buf:append("\"") elseif node.type == "parexp" then 

	buf:append("(")
	toLua(node[1]);buf:append(")") elseif node.type == "identifier" or node.type == "keyword" then 

	buf:append(node.text) elseif node.type == "literal" then 


	buf:append(node.text) elseif node.type == "number" then 


	buf:append(node.text) elseif node.type == "varargs" then 


	buf:append("...") else 


	error("unhandled ast node " .. node.type) end
end


function luafier:writeForOfNode(node)
	__L_as(__L_t(node) == "lunanode", "Parameter 'node' must be a lunanode")
	assert(node.type == "forof")
	__L_as(self, "cannot destructure nil");local buf = self.buf
	__L_as(node, "cannot destructure nil");local var, iter, b = node[1], node[2], node[3]


	if node.nillableColl then 
	local nc = node:newCreator()


	local varName = "__lcoll" .. buf:getTmpIndexAndIncrement()
	self:writeNode(nc["local"](nc.varlist(nc.typedname(varName)), nc.explist(iter)))
	buf:append(";")

	local node2 = node:clone()
	node2.nillableColl = false


	node2[2] = nc.identifier({ text = varName })

	local nif = nc["if"](varName, 
	node2)


	self:writeNode(nif)

	return  end


	__L_as(var, "cannot destructure nil");local vark, varv = var[1], var[2]

	local destr
	if varv.type == "tabledestructor" or varv.type == "arraydestructor" then 
	local varName = "__ldestr" .. buf:getTmpIndexAndIncrement()


	local newVarv = varv:cloneMeta("identifier")
	newVarv.text = varName


	destr = varv:cloneMeta("localdestructor")
	destr[1] = varv
	destr[2] = newVarv

	varv = newVarv end


	buf:append("for ")
	if vark then 
	self:writeNode(vark) else 

	buf:append("_") end

	buf:append(",")
	buf:appendSpace(" ");self:writeNode(varv);buf:append(" in ")
	if node.iterArray then buf:append("ipairs") else 

	buf:append("pairs") end

	buf:append("(")
	self:writeNode(iter);buf:append(") do")
	self:wrapIndent(iter, b, function ()
		if destr then self:writeNode(destr) end
		self:writeNode(b)
	end, 
	true)
	buf:append("end")
end
function luafier:writeLocalDestructorNode(node)
	__L_as(__L_t(node) == "lunanode", "Parameter 'node' must be a lunanode")
	assert(node.type == "localdestructor")
	__L_as(self, "cannot destructure nil");local buf = self.buf
	__L_as(node, "cannot destructure nil");local destructor, target = node[1], node[2]
	local names = destructor[1]


	local varName
	if target.type == "identifier" then 
	varName = target.text else 

	varName = "__ldestr" .. buf:getTmpIndexAndIncrement()
	buf:append("local ")
	buf:append(varName);buf:append("=");self:writeNode(target);buf:append(";") end


	buf:append(LUAFN_ASSERT)
	buf:append("(");buf:append(varName);buf:append(", \"cannot destructure nil\");")
	buf:append("local ")
	for i, name in ipairs(names) do
		if i > 1 then buf:append(", ") end
		self:writeNode(name)
	end
	buf:append(" = ")

	if destructor.type == "arraydestructor" then 
	for i = 1, #names do
		if i > 1 then buf:append(", ") end
		buf:append(varName)
		buf:append("[");buf:append(tostring(i));buf:append("]")
	end elseif destructor.type == "tabledestructor" then 
	for i, member in ipairs(names) do
		if i > 1 then buf:append(", ") end
		buf:append(varName)
		buf:append(".");self:writeNode(member)
	end end
end

function luafier:writeMatchNode(node)
	__L_as(__L_t(node) == "lunanode", "Parameter 'node' must be a lunanode")
	assert(node.type == "match")
	__L_as(self, "cannot destructure nil");local buf = self.buf
	local nc = node:newCreator()

	local varName = "__lmatch" .. buf:getTmpIndexAndIncrement()
	self:writeNode(nc["local"](nc.varlist(nc.typedname(varName)), nc.explist(node[1])))
	buf:append(";")
	local mainif
	local curif

	local mapCond = function(cond) 
	if cond.type == "identifier" and cond.text == "_" then 
	return nc.keyword({ text = "true" }) elseif cond.type == "typedname" then 

	__L_as(cond, "cannot destructure nil");local name, type = cond[1], cond[2]
	if type then 
	return nc.typecheck(cond[1].text, nc.type(cond[2][1].text)) else 


	return nc.keyword({ text = "true" }) end elseif cond.type == "range" then 



	__L_as(cond, "cannot destructure nil");local low, high = cond[1], cond[2]
	low = low and nc.binop(nc.t_binop({ text = ">=" }), varName, low)
	high = high and nc.binop(nc.t_binop({ text = "<" }), varName, high)

	local e
	if low and high then 
	e = nc.binop(nc.t_binop({ text = "and" }), low, high) elseif low then 

	e = low else 

	e = high end


	return nc.binop(nc.t_binop({ text = "and" }), 
	nc.binop(nc.t_binop({ text = "==" }), nc.funccall("type", nc.args(nc.explist(varName))), nc.literal({ text = "\"number\"" })), 
	e) else 

	return nc.binop(nc.t_binop({ text = "==" }), varName, cond) end end



	for _, __ldestr2 in ipairs(node[2]) do
		__L_as(__ldestr2, "cannot destructure nil");local cond, ifcond, body = __ldestr2[1], __ldestr2[2], __ldestr2[3];cond = mapCond(cond)

		if ifcond then 
		cond = nc.binop(nc.t_binop({ text = "and" }), cond, ifcond) end


		if curif then 
		local n = nc["elseif"](cond, nc.block(body))
		curif[3] = n
		curif = n else 

		mainif = nc["if"](cond, nc.block(body))
		curif = mainif end
	end


	if mainif then 
	self:writeNode(mainif) end
end


function luafier:getLua()
	return self.buf:tostring()
end

local defopts = {

	matchLinenumbers = true, 


	prettyPrint = true, 


	indentString = "\t", 


	nlString = "\n"
}


local lunaInclusions = [[local ]] .. LUAFN_ASSERT .. [[,__L_to,__L_gmt=assert,type,getmetatable;]] ..
[[local function ]] .. LUAFN_TYPE .. [[(o)local t=__L_to(o) if t=="table" then local mt = __L_gmt(o)return (mt and mt.__type) or t end return t end]]


function to_lua.toLua(node, useropts)
	local opts = {  }

	for k, v in pairs(defopts) do opts[k] = v end
	local __lcoll3 = useropts;if __lcoll3 then for k, v in pairs(__lcoll3) do opts[k] = v end end

	local bufIndentString = opts.prettyPrint and opts.indentString or ""

	local buf = luaBuffer.new(bufIndentString, opts.nlString, not opts.prettyPrint)
	buf:append(lunaInclusions)
	buf:append(";")
	local l = luafier.new(buf, opts)
	l:writeNode(node)
	return l:getLua()
end

return to_lua