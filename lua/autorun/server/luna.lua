
local gode = [[gassign = "hey"

local setupvar
local setuptvar: string

local name:string, age:number = "Mike", 32

local function lualocalfunc(a, b, c) return x, y, z end
local lualocalfunc_a = function(a, b, c) return x, y, z end
function luaglobfunc(a, b, c) return x, y, z end
luaglobfunc_a = function(a, b, c) return x, y, z end

local shortfn1 = (name) => "Hello " .. name
local shortfn2 = (a, b) => print("I will ", a, " your ", b)
shortfn2("eat", "banana")

local t = { target = 8, num = 2 }
t.num *= t.target / t.num

assert(t.num == t.target)

if local key = t.target then
	print("nice key :) ", key)
else
	print("key was not a thing")
end
print("key is no more :( ", key)

local function fn(a: string, b: number?)
	print(a, "must be a string and ", b, " must be a number or nil")
end
fn("hello")
]]

local l = include("luna/lexer.lua").new(gode)
local p = include("luna/parser.lua").new(l)

local chunk = p:block()
local luac = include("luna/to_lua.lua").toLua(chunk)

print("===ast:")
local function printt(t, i)
	for k,v in pairs(t) do
		if ({line=true, col=true})[k] then
			continue
		end
		Msg((" "):rep(i or 0))
		Msg(tostring(k))
		Msg(" = ")

		if type(v) == "table" then
			MsgN()
			printt(v, (i or 0) + 1)
		else
			MsgN(tostring(v))
		end
	end
end
--printt(chunk)

print("==luafied:")
print(luac)

print("==run:")
RunString(luac)