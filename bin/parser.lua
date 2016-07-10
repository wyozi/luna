local __L_as,__L_to,__L_gmt=assert,type,getmetatable;local function __L_t(o)local t=__L_to(o) if t=="table" then local mt = __L_gmt(o)return (mt and mt.__type) or t end return t end;local unpack = unpack or table.unpack
local gettype = type

local Parser = {  }
Parser.__index = Parser

function Parser.new(lexer)
	local p = setmetatable({
		lexer = lexer, 
		tokens = {  }, 
		tokenIndex = 0
	}, 
	Parser)
	p:next()
	return p
end
function Parser:isEOF()
	return not self.nextToken
end

function Parser:next()
	self.curToken = self.tokens[self.tokenIndex]

	self.nextToken = self.tokens[self.tokenIndex + 1]
	if not self.nextToken then 
	local nt = self.lexer:next()
	if nt then 
	self.tokens[self.tokenIndex + 1] = nt
	self.nextToken = nt end end



	self.tokenIndex = self.tokenIndex + (1)
	return self.curToken
end

function Parser:_createRestorePoint()
	local point = self.tokenIndex
	return function() 
	self.tokenIndex = point - 1
	self:next() end
end


function Parser:error(text)
	__L_as(__L_t(text)=="string", "Invalid value for 'text'. Expected a 'string'")
	local line, col = (self.nextToken and self.nextToken.line) or -1, (self.nextToken and self.nextToken.col) or -1
	text = text .. " preceding tokens: "
	for i = 2, 0, -1 do
		local t = self.tokens[self.tokenIndex - 1 - i]
		if t then text = text .. " [" .. t.type .. ":" .. t.text .. "]" end
	end

	error("[Luna Parser] " .. text .. " at line " .. line .. " col " .. col)
end
function Parser:expectedError(expected)
	__L_as(__L_t(expected)=="string", "Invalid value for 'expected'. Expected a 'string'")
	local t = string.format("expected %s, got %s", expected, (self.nextToken and self.nextToken.type))
	return self:error(t)
end
local node_meta = {  }
node_meta.__index = node_meta
node_meta.__type = "lunanode"

function node_meta:cloneMeta(newType, merget)
	__L_as(__L_t(newType)=="string", "Invalid value for 'newType'. Expected a 'string'");__L_as(merget==nil or __L_t(merget)=="table", "Invalid value for 'merget'. Expected a 'table'")
	local cloned = setmetatable({ type = newType, line = self.line, col = self.col }, node_meta)
	if merget then for k, v in pairs(merget) do cloned[k] = v end end

	return cloned
end
function node_meta:clone(merget)
	__L_as(merget==nil or __L_t(merget)=="table", "Invalid value for 'merget'. Expected a 'table'")
	local cloned = setmetatable({  }, node_meta)
	for k, v in pairs(self) do cloned[k] = v end
	if merget then for k, v in pairs(merget) do cloned[k] = v end end

	return cloned
end






local nodecreator_meta = {  }
local nodecreator_node_meta = {
	__call = function (t, ...)
		local n = t.n
		for i, c in ipairs({ ... }) do
			local key, val = nil, c

			if __L_t(c)=="string" then 
			val = n:cloneMeta("identifier")
			val.text = c elseif type(c) == "function" then 

			val, key = c() elseif type(c) == "table" and not (__L_t(c)=="lunanode") then 

			for k, v in pairs(c) do
				n[k] = v
			end end


			n[key or i] = val
		end
		return n
	end
}
nodecreator_meta.__index = function (self, name)
	local n = rawget(self, "base"):cloneMeta(name)
	return setmetatable({ n = n }, nodecreator_node_meta)
end
function node_meta:newCreator()
	return setmetatable({ base = self }, nodecreator_meta)
end

function Parser:node(type, ...)
	__L_as(__L_t(type)=="string", "Invalid value for 'type'. Expected a 'string'")
	local n = setmetatable({ type = type, line = (self.curToken and self.curToken.line), col = (self.curToken and self.curToken.col) }, node_meta)
	local args = { ... }



	if gettype(args[1]) == "table" and args[1].type then 
	n.line = args[1].line end


	for i, v in pairs(args) do
		n[i] = v
	end

	return n
end
function Parser:nodeCreator(base)
	return base:newCreator()
end
function Parser:token2node(token, prepend_t)
	__L_as(token==nil or __L_t(token)=="lunatoken", "Invalid value for 'token'. Expected a 'lunatoken'");__L_as(prepend_t==nil or __L_t(prepend_t)=="boolean", "Invalid value for 'prepend_t'. Expected a 'boolean'")
	if not token then return nil end
	local type = token.type
	if prepend_t then 
	type = string.format("t_" .. type) end


	local n = self:node(type)
	n.text, n.line, n.col = token.text, token.line, token.col
	return n
end
function Parser:accept(type, text)
	__L_as(__L_t(type)=="string", "Invalid value for 'type'. Expected a 'string'");__L_as(text==nil or __L_t(text)=="string", "Invalid value for 'text'. Expected a 'string'")
	if (self.nextToken and self.nextToken.type) == type and (not text or self.nextToken.text == text) then return self:next() end
end

function Parser:expect(type, text)
	__L_as(__L_t(type)=="string", "Invalid value for 'type'. Expected a 'string'");__L_as(__L_t(text)=="string", "Invalid value for 'text'. Expected a 'string'")
	local n = self:accept(type, text)
	if not n then return self:error("expected " .. type) end
	return n
end
function Parser:checkEOF(text)
	__L_as(__L_t(text)=="string", "Invalid value for 'text'. Expected a 'string'")
	if not self:isEOF() then return self:error(text) end
end

function Parser:acceptChain(fn, ...)
	__L_as(__L_t(fn)=="function", "Invalid value for 'fn'. Expected a 'function'")
	local rp = self:_createRestorePoint()
	local line, col = (self.nextToken and self.nextToken.line), (self.nextToken and self.nextToken.col)

	local t = {  }
	for i, node in pairs({ ... }) do
		local parsed
		if type(node) == "table" then 
		parsed = self:accept(node[1], node[2]) else 

		local nfn = self[node]
		if not nfn then 
		error("PARSER ERROR! Inexistent node name: " .. tostring(node)) end


		parsed = nfn(self) end










		if not parsed then 
		rp()
		return  end


		t[i] = parsed
	end

	local ret = { fn(unpack(t)) }


	if gettype(ret[1]) == "table" and ret[1].type then 
	ret[1].line = line
	ret[1].col = col end


	return unpack(ret)
end

local chain_meta = {  }
chain_meta.__index = chain_meta

function chain_meta:insertParserFn(expected, fn, name)
	__L_as(__L_t(expected)=="boolean", "Invalid value for 'expected'. Expected a 'boolean'");__L_as(__L_t(fn)=="function", "Invalid value for 'fn'. Expected a 'function'");__L_as(name==nil or __L_t(name)=="string", "Invalid value for 'name'. Expected a 'string'")
	table.insert(self.chain, { name = name or "unknown", expected = expected, fn = fn })
	return self
end
function chain_meta:insertToken(expected, type, text)
	__L_as(__L_t(expected)=="boolean", "Invalid value for 'expected'. Expected a 'boolean'");__L_as(__L_t(type)=="string", "Invalid value for 'type'. Expected a 'string'");__L_as(text==nil or __L_t(text)=="string", "Invalid value for 'text'. Expected a 'string'");table.insert(self.chain, { name = type, expected = expected, fn = function() return self.parser:accept(type, text) end })
	return self
end
function chain_meta:accept(a, b)
	if type(a) == "function" then return self:insertParserFn(false, a, b) end
	return self:insertToken(false, a, b)
end
function chain_meta:expect(a, b)
	if type(a) == "function" then return self:insertParserFn(true, a, b) end
	return self:insertToken(true, a, b)
end
function chain_meta:done(fn)
	__L_as(__L_t(fn)=="function", "Invalid value for 'fn'. Expected a 'function'")
	local parser = self.parser
	local rp = parser:_createRestorePoint()
	local line, col = (parser.nextToken and parser.nextToken.line), (parser.nextToken and parser.nextToken.col)

	local t = {  }
	for i, ch in ipairs(self.chain) do
		__L_as(ch, "cannot destructure nil");local name, expected, fn = ch.name, ch.expected, ch.fn
		local parsed = fn()


		if not parsed then 
		if expected then 
		parser:expectedError(name) end


		rp()
		return  end


		t[i] = parsed
	end

	local ret = { fn(unpack(t)) }


	if ret[1] and type(ret[1]) == "table" and ret[1].type then 
	ret[1].line = line
	ret[1].col = col end


	return unpack(ret)
end



function Parser:chain(name)
	__L_as(__L_t(name)=="string", "Invalid value for 'name'. Expected a 'string'")
	return setmetatable({ name = name, parser = self, chain = {  } }, chain_meta)
end
function Parser:block()
	local block = self:node("block")


	block.line = self.nextToken.line
	block.col = self.nextToken.col

	local finished = false

	while true do 
	local stat = self:stat()

	if not stat then 

	local endkw = self:accept("keyword", "end") or
	self:accept("keyword", "elseif") or
	self:accept("keyword", "else") or
	self:accept("keyword", "until")


	if endkw then 
	finished = true
	block.endkw = endkw.text end


	break end


	table.insert(block, stat) end


	if not finished and not self:isEOF() then 
	local post = "got " .. (self.nextToken and (self.nextToken.type .. " " .. self.nextToken.text)) .. " "
	self:error("expected statement; " .. post) end


	return block
end

function Parser:stat()
	local function assignment(varlist, op, explist)
		return self:node("assignment", self:token2node(op), varlist, explist)
	end
	local function fnstmt(_, name, body)
		return self:node("globalfunc", name, body)
	end
	local function localfnstmt(_, _, name, body)
		return self:node("localfunc", name, body)
	end

	self:accept("symbol", ";")

	return self:acceptChain(assignment, "varlist", { "assignop" }, "explist") or
	self:stat_while() or
	self:stat_if() or
	self:stat_for() or
	self:acceptChain(fnstmt, { "keyword", "function" }, "funcname", "funcbody") or
	self:acceptChain(localfnstmt, { "keyword", "local" }, { "keyword", "function" }, "name", "funcbody") or
	self:stat_local() or
	self:stat_match() or
	self:stat_import() or
	self:primaryexp() or

	self:laststat()
end

function Parser:stat_while()
	return self:acceptChain(function(_, cond, _, b) return self:node("while", cond, b) end, { "keyword", "while" }, "exp", { "keyword", "do" }, "block") or
	self:acceptChain(function(_, b, cond) return self:node("repeat", b, cond) end, { "keyword", "repeat" }, "block", "exp")
end

function Parser:stat_if()
	local _else, _elseif

	local function cont(b, node)
		if b.endkw == "elseif" then 
		table.insert(node, _elseif()) elseif b.endkw == "else" then 

		table.insert(node, _else()) end
	end


	function _else()
		local b = self:block()
		if not b then self:error("expected else block") end
		return self:node("else", b)
	end
	function _elseif()
		local cond = self:exp()
		if not cond then self:error("expected elseif condition") end

		self:accept("keyword", "then")

		local b = self:block()
		if not b then self:error("expected elseif body") end

		local node = self:node("elseif", cond, b)
		cont(b, node)
		return node
	end

	local function normalif(cond, b)
		if not cond then self:error("expected if condition") end
		if not b then self:error("expected if body") end

		local node = self:node("if", cond, b)
		cont(b, node)
		return node
	end

	local function assignif(assign, b)
		if #assign[1] ~= 1 or #assign[2] ~= 1 then 
		self:error("If-Assign must have exactly one assigned variable") end

		if not b then self:error("expected if body") end

		local node = self:node("ifassign", assign, b)
		cont(b, node)
		return node
	end

	if self:accept("keyword", "if") then 
	local e = self:exp()
	if e then 
	self:accept("keyword", "then")
	return normalif(e, self:block()) end


	local a = self:stat_local()
	if a then 
	self:accept("keyword", "then")
	return assignif(a, self:block()) end end
end


function Parser:stat_for()
	local function fornum(_, var, _, low, _, high, _, b)
		return self:node("fornum", var, low, high, nil, b)
	end
	local function fornum_step(_, var, _, low, _, high, _, step, _, b)
		return self:node("fornum", var, low, high, step, b)
	end
	local function forgen(_, names, _, iter, _, b)
		return self:node("forgen", names, iter, b)
	end

	return self:acceptChain(fornum_step, { "keyword", "for" }, "name", { "assignop", "=" }, "exp", { "symbol", "," }, "exp", { "symbol", "," }, "exp", { "keyword", "do" }, "block") or
	self:acceptChain(fornum, { "keyword", "for" }, "name", { "assignop", "=" }, "exp", { "symbol", "," }, "exp", { "keyword", "do" }, "block") or
	self:acceptChain(forgen, { "keyword", "for" }, "typednamelist", { "keyword", "in" }, "exp", { "keyword", "do" }, "block") or

	self:stat_for_of()
end

function Parser:stat_for_of()
	return self:acceptChain(function(_, v, _, i, _, b) return self:node("forof", v, i, b) end, { "keyword", "for" }, "for_of_var", { "identifier", "of" }, "exp", { "keyword", "do" }, "block") or
	self:acceptChain(function(_, v, _, i, _, b) 

	local n = self:node("forof", v, i, b)
	n.iterArray = true
	return n end, 
	{ "keyword", "for" }, "for_of_var", { "identifier", "ofi" }, "exp", { "keyword", "do" }, "block") or
	self:acceptChain(function(_, v, _, _, i, _, b) 
	local n = self:node("forof", v, i, b)
	n.nillableColl = true
	return n end, 
	{ "keyword", "for" }, "for_of_var", { "identifier", "of" }, { "symbol", "?" }, "exp", { "keyword", "do" }, "block")
end
function Parser:for_of_var()
	local index = self:acceptChain(function(n) return n end, "name", { "symbol", "," })

	local __ifa0_value = self:name() or self:destructor(); if __ifa0_value then local value = __ifa0_value
	return self:node("forofvar", index, value) end
end

function Parser:stat_local()
	local function localstmt(_, namelist)
		local explist
		if self:accept("assignop", "=") then 
		explist = self:explist()
		if not explist then self:error("expected explist") end end


		return self:node("local", namelist, explist)
	end
	local function localdestr(_, destructor, _, target)
		return self:node("localdestructor", destructor, target)
	end

	return self:acceptChain(localdestr, { "keyword", "local" }, "destructor", { "assignop", "=" }, "exp") or
	self:acceptChain(localstmt, { "keyword", "local" }, "typednamelist")
end

function Parser:stat_match()
	return self:chain("match"):accept("identifier", "match"):accept((function(...) return self:exp(...) end)):expect((function(...) return self:matchblock(...) end)):done(function (_, e, b)

		return self:node("match", e, b)
	end)
end
function Parser:matchblock()
	local block = self:node("matchblock")

	block.line = self.nextToken.line
	block.col = self.nextToken.col

	while true do 
	if self:accept("keyword", "end") then 
	break end


	local cond = self:matchcond()
	if not cond then self:expectedError("match condition") end

	local extraif
	if self:accept("keyword", "if") then 
	extraif = self:exp()
	if not extraif then self:expectedError("if condition") end end


	self:expect("symbol", "=>")

	if self:accept("keyword", "do") then 
	local mblock = self:block()
	if not mblock then self:expectedError("match block") end

	table.insert(block, self:node("matcharm", cond, extraif, mblock)) else 

	local stat = self:stat()
	if not stat then self:expectedError("match statement") end

	table.insert(block, self:node("matcharm", cond, extraif, stat)) end end



	return block
end
function Parser:matchcond()
	return self:token2node(self:accept("keyword", "nil")) or
	self:token2node(self:accept("keyword", "false")) or
	self:token2node(self:accept("keyword", "true")) or
	self:acceptChain(function(low, _, high) return self:node("range", self:token2node(low), self:token2node(high)) end, { "number" }, { "binop", ".." }, { "number" }) or
	self:typedname() or
	self:token2node(self:accept("number")) or
	self:token2node(self:accept("literal")) or
	self:token2node(self:accept("identifier", "_"))
end

function Parser:stat_import()
	return self:acceptChain(function(_, _, _, bindingName, _, libName) return self:node("import", self:token2node(bindingName), self:token2node(libName)) end, 
	{ "identifier", "import" }, { "binop", "*" }, { "identifier", "as" }, { "identifier" }, { "identifier", "from" }, { "literal" })
end


function Parser:destructor()
	local function destruct_array(_, namelist)
		return self:node("arraydestructor", namelist)
	end
	local function destruct_table(_, namelist)
		return self:node("tabledestructor", namelist)
	end

	return self:acceptChain(destruct_array, { "symbol", "[" }, "typednamelist", { "symbol", "]" }) or
	self:acceptChain(destruct_table, { "symbol", "{" }, "typednamelist", { "symbol", "}" })
end


function Parser:laststat()
	return self:acceptChain(function(_, e, _, c) return self:node("returnif", e, c) end, { "keyword", "return" }, "explist", { "keyword", "if" }, "exp") or
	self:acceptChain(function(_, e) return self:node("return", e) end, { "keyword", "return" }, "explist") or
	self:acceptChain(function() return self:node("break") end, { "keyword", "break" })
end


function Parser:funcname()
	local namebuf = self:node("funcname")

	local name = self:name()
	if not name then return  end

	namebuf[1] = name

	while self:accept("symbol", ".") do 
	name = self:name()
	if not name then self:error("funcname terminates abruptly") end
	table.insert(namebuf, name) end


	if self:accept("symbol", ":") then 
	name = self:name()
	if not name then self:error("funcname terminates abruptly") end
	table.insert(namebuf, name)

	namebuf.isMethod = true end


	return namebuf
end

function Parser:varlist()
	local vars = self:node("varlist")

	local var = self:primaryexp()
	while var do 
	table.insert(vars, var)
	if self:accept("symbol", ",") then 
	var = self:primaryexp() else 

	var = nil end end



	return vars
end

function Parser:name()
	return self:token2node(self:accept("identifier"))
end

function Parser:typedname()
	local __ifa1_i = self:name(); if __ifa1_i then local i = __ifa1_i
	local typedname = self:node("typedname", i)
	if self:accept("symbol", ":") then 
	local __ifa2_type = self:type(); if __ifa2_type then local type = __ifa2_type
	typedname[2] = type else 

	self:expectedError("type") end end


	return typedname end
end


function Parser:type()

	local type = self:name() or self:token2node(self:accept("keyword", "function"))
	if not type then return  end

	local isOptional = self:accept("symbol", "?")
	local node = self:node("type", type)
	node.isOptional = not not isOptional
	return node
end

function Parser:typednamelist()
	local names = self:node("typednamelist")

	local name = self:typedname()
	while name do 
	table.insert(names, name)
	if self:accept("symbol", ",") then 
	name = self:typedname() else 

	name = nil end end



	return names
end

function Parser:explist()
	local exps = self:node("explist")

	local exp = self:exp()
	while exp do 
	table.insert(exps, exp)
	if self:accept("symbol", ",") then 
	exp = self:exp() else 

	exp = nil end end



	return exps
end

function Parser:macroinvocation(prefix)
	local function expandMethodMacro(name, args)
		if name.text == "map" then 
		local nargs = args:cloneMeta("args")
		nargs[1] = prefix
		for i = 1, #args do nargs[1 + i] = args[i] end

		return self:macroexpand_map(nargs) else 

		self:error("unknown macro name '" .. name.text .. "'") end
	end


	return self:acceptChain(function(_, nm, _, a) return expandMethodMacro(nm, a) end, { "symbol", ":" }, "name", { "symbol", "!" }, "args")
end

function Parser:macroexpand_map(args)
	local nc = self:nodeCreator(args)

	local sourceTable = args[1]
	local cfunc = args[2][1]

	__L_as(cfunc, "cannot destructure nil");local cpars, cbody = cfunc[1], cfunc[2]


	if cbody.type == "return" then 
	cbody = cbody[1] end


	local cparFirstName = cpars[1][1].text
	local function rewriteIdentifiers(n)
		if __L_t(n)=="lunanode" then 
		for _, v in pairs(n) do
			rewriteIdentifiers(v)
		end

		if n.type == "identifier" and n.text == cparFirstName then 
		n.text = "v" end end
	end



	rewriteIdentifiers(cbody)

	local mm = nc.parexp(nc.funccall(nc.parexp(nc.func(nc.funcbody(nc.parlist(nc.typedname("t")), 
	nc.block(nc["local"](nc.typedname("nt"), nc.explist(nc.tableconstructor(nc.fieldlist()))), 
	nc.forgen(nc.typednamelist(nc.typedname("k"), nc.typedname("v")), 
	nc.funccall("pairs", nc.args(nc.explist("t"))), 
	nc.block(nc.assignment(nc.t_assignop({ text = "=" }), 
	nc.varlist(nc.indexb("nt", "k")), 
	nc.explist(cbody)))), 




	nc["return"]("nt"))))), 



	nc.args(nc.explist(sourceTable:clone({ line = args.line })))))










	return mm
end

function Parser:primaryexp()
	local pref = self:prefixexp()
	if not pref then return  end

	local n = pref

	while true do 

	local nn = self:acceptChain(function(_, nm) return self:node("index", n, nm) end, { "symbol", "." }, "name") or
	self:acceptChain(function(_, _, nm) return self:node("indexsafe", n, nm) end, { "symbol", "?" }, { "symbol", "." }, "name") or
	self:acceptChain(function(_, e) return self:node("indexb", n, e) end, { "symbol", "[" }, "exp", { "symbol", "]" }) or
	self:acceptChain(function(_, nm, a) return self:node("methodcall", n, nm, a) end, { "symbol", ":" }, "name", "args") or
	self:acceptChain(function(a) return self:node("funccall", n, a) end, "args") or
	self:macroinvocation(n)


	if not nn then 


	local pend = self:acceptChain(function(_, _, nm) return self:node("methodref", n, nm) end, { "symbol", ":" }, { "symbol", ":" }, "name")


	return pend or n end


	n = nn end
end


function Parser:simpleexp()
	local n = self:token2node(self:accept("keyword", "nil")) or
	self:token2node(self:accept("keyword", "false")) or
	self:token2node(self:accept("keyword", "true")) or
	self:token2node(self:accept("number")) or
	self:token2node(self:accept("literal")) or
	self:varargs() or
	self:func() or
	self:sfunc() or
	self:tableconstructor() or
	self:primaryexp()


	if n then return n end
end

function Parser:sfunc()
	return self:chain("shortfunc"):accept((function(...) return self:sfuncparams(...) end)):accept("symbol", "=>"):expect((function(...) return self:sfuncbody(...) end), "function body"):done(function(p, _, b) return self:node("sfunc", p, b) end)
end






function Parser:subexp()
	local __ifa3_unop = self:accept("unop") or self:accept("binop", "-"); if __ifa3_unop then local unop = __ifa3_unop
	return self:node("unop", self:token2node(unop), self:subexp()) end


	local e = self:simpleexp()

	if e then 

	local __ifa4_b = self:accept("binop"); if __ifa4_b then local b = __ifa4_b
	local e2 = self:subexp()
	if not e2 then 
	self:error("expected right side of binop") end


	local node = self:node("binop", self:token2node(b), e, e2)
	node.line = e.line
	node.col = e.col
	return node end



	local __ifa5_check = self:chain("typecheck"):accept("identifier", "is"):expect((function(...) return self:type(...) end)):done(function(_, type) return type end); if __ifa5_check then local check = __ifa5_check
	return self:node("typecheck", e, check) end end



	return e
end

function Parser:exp()
	return self:subexp()
end

function Parser:prefixexp()
	return self:name() or
	self:acceptChain(function(_, e, _) return self:node("parexp", e) end, { "symbol", "(" }, "exp", { "symbol", ")" })
end


function Parser:args()
	return self:acceptChain(function(_, el) return self:node("args", el) end, { "symbol", "(" }, "explist", { "symbol", ")" }) or
	self:acceptChain(function(tbl) return self:node("args", self:node("explist", tbl)) end, "tableconstructor")
end


function Parser:func()
	return self:acceptChain(function(_, f) return self:node("func", f) end, { "keyword", "function" }, "funcbody")
end


function Parser:funcbody()
	return self:acceptChain(function(_, p, _, b) return self:node("funcbody", p, b) end, { "symbol", "(" }, "parlist", { "symbol", ")" }, "block")
end


function Parser:varargs()
	if self:accept("symbol", "...") then return self:node("varargs") end
end

function Parser:parlist()
	local params = self:node("parlist")

	local function nextarg()
		local __ifa6_n = self:typedname(); if __ifa6_n then local n = __ifa6_n

		local __ifa7_value = self:chain("default value"):accept("assignop", "="):expect((function(...) return self:exp(...) end)):done(function(_, e) return e end); if __ifa7_value then local value = __ifa7_value
		return self:node("paramwithvalue", n, value) end

		return n end



		return self:varargs()
	end

	local __ifa8_param = nextarg(); if __ifa8_param then local param = __ifa8_param


	local vargsAdded = false

	repeat 
	if vargsAdded then 
	error("Varargs must be the last element in a parameter list") end


	table.insert(params, param)

	if param.type == "varargs" then 
	vargsAdded = true end


	if self:accept("symbol", ",") then 
	param = nextarg() else 

	param = nil end until not param end




	return params
end

function Parser:tableconstructor()
	return self:acceptChain(function(_, fl) return self:node("tableconstructor", fl) end, { "symbol", "{" }, "fieldlist", { "symbol", "}" })
end


function Parser:fieldlist()
	local fields = self:node("fieldlist")

	local field = self:field()
	while field do 
	table.insert(fields, field)
	if self:fieldsep() then 
	field = self:field() else 

	field = nil end end



	return fields
end

function Parser:field()
	return self:acceptChain(function(_, n, _, _, e) return self:node("field", self:token2node(n), e) end, { "symbol", "[" }, { "literal" }, { "symbol", "]" }, { "assignop", "=" }, "exp") or
	self:acceptChain(function(n, _, e) return self:node("field", n, e) end, "name", { "assignop", "=" }, "exp") or
	self:acceptChain(function(e) return self:node("field", nil, e) end, "exp")
end

function Parser:fieldsep()
	return self:accept("symbol", ",") or self:accept("symbol", ";")
end



function Parser:sfuncparams()
	local __ifa9_n = self:name(); if __ifa9_n then local n = __ifa9_n
	return self:node("parlist", n) end


	return self:acceptChain(function(_, parl, _) return parl end, { "symbol", "(" }, "parlist", { "symbol", ")" })
end




function Parser:sfuncbody()
	return self:acceptChain(function(_, b) return b end, { "keyword", "do" }, "block") or
	self:acceptChain(function(e) return self:node("return", e) end, "exp")
end


return Parser