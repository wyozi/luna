local Lexer = {}
Lexer.__index = Lexer

function Lexer.new(str)
	return setmetatable({
		buf = str,
		tokens = {},
		pos = 1,

		line = 1,
		col = 1
	}, Lexer)
end

function Lexer:error(msg, line, col)
	 error(msg .. " at line " .. (line or self.line) .. " col " .. (col or self.col))
end

function Lexer:_readPattern(p)
	local txt = self.buf:match(p, self.pos)
	if not txt then
		return nil
	end

	self.pos = self.pos + #txt

	-- Count how many lines and cols did we advance

	local afterLastNLSpace = txt:match("\r?\n([^\n]*)$")
	-- there was at least one newline
	if afterLastNLSpace then
		local nlCount = 0
		for nl in txt:gmatch("\n") do nlCount = nlCount + 1 end
		self.line = self.line + nlCount
		self.col = 1 + #afterLastNLSpace
	else
		-- tabs count as 4 spaces
		local tabCount = 0
		for tab in txt:gmatch("\t") do tabCount = tabCount + 1 end
		
		self.col = self.col + #txt - tabCount + (tabCount * 4)
	end

	return txt
end

function Lexer:_skipWhitespace()
	self:_readPattern("^%s+")
end

function Lexer:_readToken(type, pattern)
	local pos, line, col = self.pos, self.line, self.col
	local matched = self:_readPattern(pattern)
	if matched then
		return { type = type, text = matched, pos = pos, line = line, col = col }
	end
end

local _keywords = {
	"local", "return", "break", "function",
	"end", "do", "if", "while", "for",
	"else", "elseif", "then"
}
function Lexer:_readIdentifierOrKeyword()
	local id = self:_readToken("identifier", "^[_%a][_%w]*")
	if id and table.HasValue(_keywords, id.text) then
		id.type = "keyword"
	end
	return id
end

-- Reads a one line string
-- Exists as its own function so that we can give better errors
function Lexer:_readOneLineString()
	local t = self:_readToken("literal", "^%b\"\"")
	if t and t.text:find("\n") then
		self:error("unterminated string", t.line, t.col)
	end
	return t
end

function Lexer:next()
	self:_skipWhitespace()

	if self.pos > #self.buf then
		return nil -- EOF
	end

	return
		self:_readIdentifierOrKeyword() or
		self:_readOneLineString() or

		-- longer symbol sequences
		self:_readToken("symbol", "^%.%.%.") or
		self:_readToken("symbol", "^%=%>") or

		-- this needs to be here so that it's detected over single period
		self:_readToken("binop", "^%.%.") or

		-- 1-char symbols
		self:_readToken("symbol", "^[%:%;%,%(%)%[%]%{%}%.]") or

		-- mod assign ops (must be before 1-char binops)
		self:_readToken("assignop", "^[%+%-%*%/%^%%]%=") or

		-- longer binop sequences
		self:_readToken("binop", "^%<%=") or
		self:_readToken("binop", "^%>%=") or
		self:_readToken("binop", "^%=%=") or
		self:_readToken("binop", "^%~%=") or
		self:_readToken("binop", "^and") or
		self:_readToken("binop", "^or") or
		-- 1-char binops
		self:_readToken("binop", "^[%+%-%*%/%^%%%<%>]") or

		-- assign op (must be after binops)
		self:_readToken("assignop", "^%=") or

		self:_readToken("number", "^[%d%.]+") or

		self:error("invalid token " .. self.buf:sub(self.pos, self.pos))
end

return Lexer