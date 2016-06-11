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
	
	local function printt(t, i)
		for k,v in pairs(t) do
			if not ({line=true, col=true})[k] then
				io.write((" "):rep(i or 0))
				io.write(tostring(k))
				io.write(" = ")

				if type(v) == "table" then
					print()
					printt(v, (i or 0) + 1)
				else
					print(tostring(v))
				end
			end
		end
	end
	printt(block)
elseif args[1] == "run" then
	local l = require("src/lexer").new(loadInput())
	local p = require("src/parser").new(l)
	local block = p:block()

	local luac = require("src/to_lua").toLua(block)
	local runner = loadstring or load
	runner(luac)
else
	print("No command given. Try 'compile', 'ast' or 'run'.")
end