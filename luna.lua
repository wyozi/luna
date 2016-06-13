local args = {...}

local function loadInput()
-- check if we should read from a file instead of stdin
	if args[2] then
		io.input(args[2])
	end

	return io.read("*a")
end

_lexer, _parser, _toLua = require("src/lexer"), require("src/parser"), require("src/to_lua").toLua

function toAST(code)
	local l = _lexer.new(code)
	local p = _parser.new(l)
	return p:block()
end

compilestring = loadstring or load -- 5.2/5.3 compat

if args[1] == "compile" or args[1] == "c" then
	local block = toAST(loadInput())
	local luac = _toLua(block)
	print(luac)
elseif args[1] == "ast" then
	local block = toAST(loadInput())
	
	local function printnode(t, i)
		local indent = ("  "):rep(i or 0)
		local indentn = ("  "):rep((i or 0) + 1)

		local function printkv(k, v)
			io.write(indent)
			io.write(tostring(k))
			io.write(" = ")

			if type(v) == "table" then
				print()
				printnode(v, (i or 0) + 1)
			else
				print(tostring(v))
			end
		end

		if t.type then
			local s = string.format("[%s at line %d; col %d]", t.type, t.line or -1, t.col or -1)
			if t.type == "identifier" or t.type == "literal" then
				print(indent .. s .. " = " .. t.text)
			else
				print(indent .. s .. " {")
				for k,v in ipairs(t) do
					if type(v) == "table" then
						printnode(v, (i or 0) + 1)
					else
						print(indentn .. tostring(v))
					end
				end
				print(indent .. "}")
			end
		else
			for k,v in pairs(t) do
				printkv(k, v)
			end
		end
	end
	printnode(block)
elseif args[1] == "run" then
	local block = toAST(loadInput())

	local luac = _toLua(block)
	
	local f, e = compilestring(luac)
	if f then
		f()
	else
		print("compilation failed: ", e)
	end
elseif args[1] == "t" or args[1] == "test" then
	-- OS detection hack! from: http://stackoverflow.com/a/14425862
	local isWindows = package.config:sub(1,1) == "\\"

	local testls = io.popen(isWindows and "dir /b /a-d tests" or "ls tests")
	for name in testls:lines() do
		if name ~= "" then
			io.write("Running '" .. name .. "' .. ")
			
  			local f = io.open("tests/" .. name, "rb")
			local src = f:read("*a")
			f:close()

			io.write("luafying .. ")
			local luafied = _toLua(toAST(src))

			io.write("running .. ")
			local f, e = compilestring(luafied, "tests/" .. name)
			if f then
				f()
			else
				error("Lua compilation failed: ", e)
			end

			print("done")
		end
	end
else
	print("No command given. Try 'compile', 'ast' or 'run'.")
end