local Parser = {}
Parser.__index = Parser

function Parser.new(lexer)
	local p = setmetatable({
		lexer = lexer,
		tokens = {},
		tokenIndex = 0
	}, Parser)
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
			--print("nt: ", table.ToString(nt))
			self.tokens[self.tokenIndex + 1] = nt
			self.nextToken = nt
		end
	end
	
	self.tokenIndex = self.tokenIndex + 1
	return self.curToken
end

function Parser:_createRestorePoint()
	local point = self.tokenIndex
	return function()
		self.tokenIndex = point - 1
		self:next()
	end
end

function Parser:error(text)
	local line, col
	if self.nextToken then
		line, col = self.nextToken.line, self.nextToken.col
	else
		line, col = -1, -1
	end
	error("[Luna Parser] " .. text .. " at line " .. line .. " col " .. col)
end
function Parser:expectedError(expected)
	local t = string.format("expected %s, got %s", expected, (self.nextToken and self.nextToken.type))
	return self:error(t)
end

function Parser:node(type, ...)
	local n = { type = type, line = (self.nextToken) and (self.nextToken.line), col = (self.nextToken) and (self.nextToken.col)}
	for i,v in pairs{...} do
		table.insert(n, v)
	end
	return n
end
function Parser:accept(type, text)
	if self.nextToken and self.nextToken.type == type and (not text or self.nextToken.text == text) then
		return self:next()
	end
end
function Parser:expect(type, text)
	local n = self:accept(type, text)
	if not n then self:error("expected " .. type) end
	return n
end
function Parser:checkEOF(text)
	if not self:isEOF() then
		self:error(text)
	end
end
function Parser:acceptChain(fn, ...)
	local rp = self:_createRestorePoint()

	local t = {}
	for i,node in pairs{...} do
		local parsed
		if type(node) == "table" then
			parsed = self:accept(node[1], node[2])
		else
			parsed = self[node](self)
			-- todo should catch errors?
			--[[local r, e = pcall(self[node], self)
			if r then
				parsed = e
			else
				print(node, e)
			end]]
		end

		-- could not parse given chain part; restore
		if not parsed then
			rp()
			return
		end

		t[i] = parsed
	end

	return fn(unpack(t))
end

function Parser:block()
	local block = self:node("block")

	local finished = false

	while true do
		local stat = self:stat()

		if not stat then

			local endkw =
				self:accept("keyword", "end") or
				self:accept("keyword", "elseif") or
				self:accept("keyword", "else")

			if endkw then
				finished = true
				block.endkw = endkw.text
			end

			break
		end

		table.insert(block, stat)
	end

	if not finished and not self:isEOF() then
		self:error("expected statement; got " .. (self.nextToken and (self.nextToken.type .. " " .. self.nextToken.text)))
	end

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

	return
		self:acceptChain(function() end, {"symbol", ";"}) or
		self:acceptChain(assignment, "varlist", {"assignop"}, "explist") or
		self:functioncall() or
		self:stat_if() or
		self:acceptChain(fnstmt, {"keyword", "function"}, "name", "funcbody") or
		self:acceptChain(localfnstmt, {"keyword", "local"}, {"keyword", "function"}, "name", "funcbody") or
		self:stat_local() or

		-- these were in laststat(). Moved here for some time..
		-- TODO move back to laststat
		self:acceptChain(function(_,e) return self:node("return", e) end, {"keyword", "return"}, "explist") or
		self:acceptChain(function() return self:node("break") end, {"keyword", "break"})
end
function Parser:stat_if()
	local _else, _elseif

	local function cont(b, node)
		if b.endkw == "elseif" then
			table.insert(node, _elseif())
		elseif b.endkw == "else" then
			table.insert(node, _else())
		end
	end

	function _else()
		local b = self:block()
		if not b then self:error("expected else block") end
		return self:node("else", b)
	end
	function _elseif()
		local cond, b =
			self:acceptChain(function(e,_,b) return e, b end, "exp", {"keyword", "then"}, "block")
		if not b then self:error("expected elseif cond/block") end

		local node = self:node("elseif", cond, b)
		cont(b, node)
		return node
	end

	local function normalif(_,cond,_,b)
		local node = self:node("if", cond, b)
		cont(b, node)
		return node
	end

	local function assignif(_,assign,_,b)
		if #assign[1] ~= 1 or #assign[2] ~= 1 then
			self:error("If-Assign must have exactly one assigned variable")
		end

		local node = self:node("ifassign", assign, b)
		cont(b, node)
		return node
	end

	return
		self:acceptChain(normalif, {"keyword", "if"}, "exp", {"keyword", "then"}, "block") or
		self:acceptChain(assignif, {"keyword", "if"}, "stat_local", {"keyword", "then"}, "block")
end
function Parser:stat_local()
	local function localstmt(_, namelist)
		local explist
		if self:accept("assignop", "=") then
			explist = self:explist()
			if not explist then self:error("expected explist") end
		end

		return self:node("local", namelist, explist)
	end

	return self:acceptChain(localstmt, {"keyword", "local"}, "typednamelist")
end

function Parser:laststat()
	-- not used, see above
	if self:accept("keyword", "return") then
		return self:node("return", self:stat())
	end
	if self:accept("keyword", "break") then
		return self:node("break")
	end
end

function Parser:varlist()
	local vars = self:node("varlist")

	local var = self:var()
	while var do
		table.insert(vars, var)
		if self:accept("symbol", ",") then
			var = self:var()
		else
			var = nil
		end
	end

	return vars
end

function Parser:name()
	local i = self:accept("identifier")
	if i then
		return i
	end
end

function Parser:typedname()
	local i = self:name()
	if i then
		return self:node("typedname", i, self:type())
	end
end

function Parser:type()
	return
		self:acceptChain(function(_, name)
			local isOptional = self:accept("symbol", "?")
			return { type = "type", name, not not isOptional }
		end, {"symbol", ":"}, {"identifier"})
end

function Parser:var()
	local n = self:name()

	if not n then
		return
	end

	local f =
		self:acceptChain(function(_,e) return e end, {"symbol", "["}, "exp", {"symbol", "]"}) or
		self:acceptChain(function(_,e) return e end, {"symbol", "."}, "name")

	if f then
		return { type = "index", n, f }
	end

	return n
end

function Parser:typednamelist()
	local names = self:node("typednamelist")

	local name = self:typedname()
	while name do
		table.insert(names, name)
		if self:accept("symbol", ",") then
			name = self:typedname()
		else
			name = nil
		end
	end

	return names
end

function Parser:explist()
	local exps = self:node("explist")

	local exp = self:exp()
	while exp do
		table.insert(exps, exp)
		if self:accept("symbol", ",") then
			exp = self:exp()
		else
			exp = nil
		end
	end

	return exps
end

function Parser:exp()
	-- check if it's a short function
	local shortFn = self:acceptChain(function(_,p,_,_,b) return { type = "sfunc", p, b } end,
		{"symbol", "("}, "parlist", {"symbol", ")"}, {"symbol", "=>"}, "sfuncbody")
	if shortFn then
		return shortFn
	end

	local unop = self:accept("unop")

	if unop then
		return self:node("unop", unop.text, self:exp())
	end

	local e =
		self:accept("identifier", "nil") or
		self:accept("identifier", "false") or
		self:accept("identifier", "true") or
		self:accept("number") or
		self:accept("literal") or
		self:accept("symbol", "...") or
		self:func() or
		self:functioncall() or
		self:prefixexp() or
		self:tableconstructor()

	if e then
		-- check if exp is directly followed by binary operator
		local b = self:accept("binop")
		if b then
			local e2 = self:exp()
			if not e2 then
				self:error("expected right side of binop")
			end
			return self:node("binop", b.text, e, e2)
		end
	end
	
	return e
end

function Parser:prefixexp()
	return
		self:var() or
		self:acceptChain(function(_,e,_) return e end, {"symbol", "("}, "exp", {"symbol", ")"})
end

function Parser:functioncall()
	return
		self:acceptChain(function(p,a) return { type = "funccall", p, a } end, "prefixexp", "args") or
		self:acceptChain(function(p,_,n,a) return { type = "methodcall", p, n, a } end, "prefixexp", {"symbol", ":"}, "name", "args")
end


function Parser:args()
	return
		self:acceptChain(function(_,el) return { type = "args", el } end, {"symbol", "("}, "explist", {"symbol", ")"})
end

function Parser:func()
	return
		self:acceptChain(function(_, f) return { type = "func", f } end, {"keyword", "function"}, "funcbody")
end

function Parser:funcbody()
	return
		self:acceptChain(function(_, p, _, b) return { type = "funcbody", p, b } end, {"symbol", "("}, "parlist", {"symbol", ")"}, "block")
end

function Parser:parlist()
	local names = self:node("parlist")

	local function nextarg()
		local a = self:typedname()
		if a then return a end
		a = self:accept("symbol", "...")
		if a then return { type = "varargs" } end
	end

	local name = nextarg()
	local vargsAdded = false
	if name then
		repeat
			if vargsAdded then
				error("Varargs must be the last element in a parameter list")
			end

			table.insert(names, name)

			if name.type == "varargs" then
				vargsAdded = true
			end

			if self:accept("symbol", ",") then
				name = nextarg()
			else
				name = nil
			end
		until not name
	end

	return names
end

function Parser:tableconstructor()
	return
		self:acceptChain(function(_,fl) return { type = "tableconstructor", fl } end, {"symbol", "{"}, "fieldlist", {"symbol", "}"})
end

function Parser:fieldlist()
	local fields = self:node("fieldlist")

	local field = self:field()
	while field do
		table.insert(fields, field)
		if self:fieldsep() then
			field = self:field()
		else
			field = nil
		end
	end

	return fields
end

function Parser:field()
	return
		-- TODO [] = exp
		self:acceptChain(function(n,_,e) return { type = "field", n, e } end, "name", {"assignop", "="}, "exp") or
		self:acceptChain(function(e) return { type = "field", nil, e } end, "exp")
end
function Parser:fieldsep()
	return self:accept("symbol", ",") or self:accept("symbol", ";")
end

-- Body of a short hand function
-- Can be single exp or a block
function Parser:sfuncbody()
	return
		self:acceptChain(function(_, b) return b end, {"keyword", "do"}, "block") or
		self:acceptChain(function(e) return { type = "return", e} end, "exp")
end

return Parser