local args = {...}

local function loadInput()
-- check if we should read from a file instead of stdin
	if args[2] then
		io.input(args[2])
	end

	return io.read("*a")
end

if args[1] == "compile" or args[1] == "c" then
	local l = require("src/lexer").new(loadInput())
	local p = require("src/parser").new(l)
	local block = p:block()

	local luac = require("src/to_lua").toLua(block)
	print(luac)
elseif args[1] == "ast" then
	local l = require("src/lexer").new(loadInput())
	local p = require("src/parser").new(l)
	local block = p:block()
	
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
	local l = require("src/lexer").new(loadInput())
	local p = require("src/parser").new(l)
	local block = p:block()

	local luac = require("src/to_lua").toLua(block)
	local runner = loadstring or load
	
	local f, e = runner(luac)
	if f then
		f()
	else
		print("compilation failed: ", e)
	end
else
	print("No command given. Try 'compile', 'ast' or 'run'.")
end