local __L_as,__L_t=assert,type;; local unpack = unpack or table.unpack
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



	self.tokenIndex = self.tokenIndex + 1
	return self.curToken
end

function Parser:_createRestorePoint()
	local point = self.tokenIndex
	return function() 
	self.tokenIndex = point - 1
	self:next() end
end


function Parser:error(text)
	__L_as(__L_t(text) == "string", "Parameter 'text' must be a string")
	local line, col
	if self.nextToken then ; line, col = self.nextToken.line, self.nextToken.col else 

	line, col = -1, -1 end


	text = text .. " preceding tokens: "
	for i = 2, 0, -1 do
		local t = self.tokens[self.tokenIndex - 1 - i]
		if t then ; text = text .. " [" .. t.type .. ":" .. t.text .. "]" end
	end

	error("[Luna Parser] " .. text .. " at line " .. line .. " col " .. col)
end
function Parser:expectedError(expected)
	__L_as(__L_t(expected) == "string", "Parameter 'expected' must be a string")
	local t = string.format("expected %s, got %s", expected, (self.nextToken and self.nextToken.type))
	return self:error(t)
end
local node_meta = {  }
node_meta.__index = node_meta

function node_meta:cloneMeta(newType)
	__L_as(__L_t(newType) == "string", "Parameter 'newType' must be a string")
	return setmetatable({ type = newType, line = self.line, col = self.col }, node_meta)
end
function Parser:node(type, ...)
	__L_as(__L_t(type) == "string", "Parameter 'type' must be a string")
	local n = setmetatable({ type = type, line = (self.curToken) and (self.curToken.line), col = (self.curToken) and (self.curToken.col) }, node_meta)
	local args = { ... }



	if gettype(args[1]) == "table" and args[1].type then 
	n.line = args[1].line end


	for i, v in pairs(args) do
		n[i] = v
	end

	return n
end
function Parser:accept(type, text)
	__L_as(__L_t(type) == "string", "Parameter 'type' must be a string"); __L_as(text == nil or __L_t(text) == "string", "Parameter 'text' must be a string")
	if self.nextToken and self.nextToken.type == type and (not text or self.nextToken.text == text) then ; return self:next() end
end

function Parser:expect(type, text)
	__L_as(__L_t(type) == "string", "Parameter 'type' must be a string"); __L_as(__L_t(text) == "string", "Parameter 'text' must be a string")
	local n = self:accept(type, text)
	if not n then return self:error("expected " .. type) end
	return n
end
function Parser:checkEOF(text)
	__L_as(__L_t(text) == "string", "Parameter 'text' must be a string")
	if not self:isEOF() then return self:error(text) end
end
function Parser:acceptChain(fn, ...)
	__L_as(__L_t(fn) == "function", "Parameter 'fn' must be a function"); local rp = self:_createRestorePoint()
	local line, col = (self.nextToken) and (self.nextToken.line), (self.nextToken) and (self.nextToken.col)

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


	if ret[1] and type(ret[1]) == "table" and ret[1].type then 
	ret[1].line = line
	ret[1].col = col end


	return unpack(ret)
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
		return self:node("assignment", op.text, varlist, explist)
	end
	local function fnstmt(_, name, body)
		return self:node("globalfunc", name, body)
	end
	local function localfnstmt(_, _, name, body)
		return self:node("localfunc", name, body)
	end

	return self:acceptChain(function ()  end, { "symbol", ";" }) or
	self:acceptChain(assignment, "varlist", { "assignop" }, "explist") or
	self:stat_while() or
	self:stat_if() or
	self:stat_for() or
	self:acceptChain(fnstmt, { "keyword", "function" }, "funcname", "funcbody") or
	self:acceptChain(localfnstmt, { "keyword", "local" }, { "keyword", "function" }, "name", "funcbody") or
	self:stat_local() or
	self:primaryexp() or

	self:laststat()
end

function Parser:stat_while()
	local function whileloop(_, cond, _, b)
		return self:node("while", cond, b)
	end
	local function repeatloop(_, b, cond)
		return self:node("repeat", b, cond)
	end

	return self:acceptChain(whileloop, { "keyword", "while" }, "exp", { "keyword", "do" }, "block") or
	self:acceptChain(repeatloop, { "keyword", "repeat" }, "block", "exp")
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
		if not b then ; self:error("expected else block") end
		return self:node("else", b)
	end
	function _elseif()
		local cond, b = self:acceptChain(function (e, _, b) 
		return e, b end, "exp", { "keyword", "then" }, "block")
		if not b then ; self:error("expected elseif condition or block") end

		local node = self:node("elseif", cond, b)
		cont(b, node)
		return node
	end

	local function normalif(_, cond, _, b)
		local node = self:node("if", cond, b)
		cont(b, node)
		return node
	end

	local function assignif(_, assign, _, b)
		if #assign[1] ~= 1 or #assign[2] ~= 1 then 
		self:error("If-Assign must have exactly one assigned variable") end


		local node = self:node("ifassign", assign, b)
		cont(b, node)
		return node
	end

	return self:acceptChain(normalif, { "keyword", "if" }, "exp", { "keyword", "then" }, "block") or
	self:acceptChain(assignif, { "keyword", "if" }, "stat_local", { "keyword", "then" }, "block")
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
	local function forof(_, var, _, iter, _, b)
		return self:node("forof", var, iter, b)
	end

	return self:acceptChain(fornum_step, { "keyword", "for" }, "name", { "assignop", "=" }, "exp", { "symbol", "," }, "exp", { "symbol", "," }, "exp", { "keyword", "do" }, "block") or
	self:acceptChain(fornum, { "keyword", "for" }, "name", { "assignop", "=" }, "exp", { "symbol", "," }, "exp", { "keyword", "do" }, "block") or
	self:acceptChain(forgen, { "keyword", "for" }, "typednamelist", { "keyword", "in" }, "exp", { "keyword", "do" }, "block") or
	self:acceptChain(forof, { "keyword", "for" }, "for_var", { "identifier", "of" }, "exp", { "keyword", "do" }, "block")
end

function Parser:for_var()
	return self:name() or self:destructor()
end
function Parser:stat_local()
	local function localstmt(_, namelist)
		local explist
		if self:accept("assignop", "=") then 
		explist = self:explist()
		if not explist then ; self:error("expected explist") end end


		return self:node("local", namelist, explist)
	end
	local function localdestr(_, destructor, _, target)
		return self:node("localdestructor", destructor, target)
	end

	return self:acceptChain(localdestr, { "keyword", "local" }, "destructor", { "assignop", "=" }, "exp") or
	self:acceptChain(localstmt, { "keyword", "local" }, "typednamelist")
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
	return self:acceptChain(function (_, e, _, c) 
	return self:node("returnif", e, c) end, { "keyword", "return" }, "explist", { "keyword", "if" }, "exp") or
	self:acceptChain(function (_, e) ; return self:node("return", e) end, { "keyword", "return" }, "explist") or
	self:acceptChain(function () ; return self:node("break") end, { "keyword", "break" })
end

function Parser:funcname()
	local namebuf = self:node("funcname")

	local name = self:name()
	if not name then ; return  end
	namebuf[1] = name

	while self:accept("symbol", ".") do 
	name = self:name()
	if not name then ; self:error("funcname terminates abruptly") end
	table.insert(namebuf, name) end


	if self:accept("symbol", ":") then 
	name = self:name()
	if not name then ; self:error("funcname terminates abruptly") end
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
	return self:accept("identifier")
end

function Parser:typedname()
	local __ifa0_i = self:name(); if __ifa0_i then ; local i = __ifa0_i
	return self:node("typedname", i, self:type()) end
end


function Parser:type()
	if self:accept("symbol", ":") then 

	local n = self:accept("identifier") or self:accept("keyword", "function")
	if not n then return  end

	local isOptional = self:accept("symbol", "?")
	return self:node("type", n, not not isOptional) end
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

function Parser:primaryexp()
	local pref = self:prefixexp()
	if not pref then return  end

	local n = pref

	while true do 

	local nn = self:acceptChain(function (_, nm) ; return self:node("index", n, nm) end, { "symbol", "." }, "name") or
	self:acceptChain(function (_, e) ; return self:node("indexb", n, e) end, { "symbol", "[" }, "exp", { "symbol", "]" }) or
	self:acceptChain(function (_, nm, a) ; return self:node("methodcall", n, nm, a) end, { "symbol", ":" }, "name", "args") or
	self:acceptChain(function (a) ; return self:node("funccall", n, a) end, "args")

	if not nn then 


	local pend = self:acceptChain(function (_, _, nm) 
	return self:node("methodref", n, nm) end, { "symbol", ":" }, { "symbol", ":" }, "name")

	return pend or n end


	n = nn end
end


function Parser:simpleexp()

	local shortFn = self:acceptChain(function(_, p, _, _, b) return self:node("sfunc", p, b) end, 
	{ "symbol", "(" }, "parlist", { "symbol", ")" }, { "symbol", "=>" }, "sfuncbody")
	if shortFn then return shortFn end

	return self:accept("keyword", "nil") or
	self:accept("keyword", "false") or
	self:accept("keyword", "true") or
	self:accept("number") or
	self:accept("literal") or
	self:varargs() or
	self:func() or
	self:tableconstructor() or
	self:primaryexp()
end


function Parser:subexp()
	local unop = self:accept("unop") or self:accept("binop", "-")
	if unop then return self:node("unop", unop.text, self:subexp()) end

	local e = self:simpleexp()

	if e then 

	local b = self:accept("binop")
	if b then 
	local e2 = self:subexp()
	if not e2 then 
	self:error("expected right side of binop") end


	local node = self:node("binop", b.text, e, e2)
	node.line = e.line
	node.col = e.col
	return node end end



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
	local names = self:node("parlist")

	local function nextarg()
		return self:typedname() or self:varargs()
	end

	local __ifa1_name = nextarg(); if __ifa1_name then ; local name = __ifa1_name


	local vargsAdded = false

	repeat 
	if vargsAdded then 
	error("Varargs must be the last element in a parameter list") end


	table.insert(names, name)

	if name.type == "varargs" then 
	vargsAdded = true end


	if self:accept("symbol", ",") then 
	name = nextarg() else 

	name = nil end until not name end




	return names
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
	return self:acceptChain(function(_, n, _, _, e) return self:node("field", n, e) end, { "symbol", "[" }, { "literal" }, { "symbol", "]" }, { "assignop", "=" }, "exp") or
	self:acceptChain(function(n, _, e) return self:node("field", n, e) end, "name", { "assignop", "=" }, "exp") or
	self:acceptChain(function(e) return self:node("field", nil, e) end, "exp")
end

function Parser:fieldsep()
	return self:accept("symbol", ",") or self:accept("symbol", ";")
end



function Parser:sfuncbody()
	return self:acceptChain(function(_, b) return b end, { "keyword", "do" }, "block") or
	self:acceptChain(function(e) return self:node("return", e) end, "exp")
end


return Parser