## Luna

Transpiled language that compiles to Lua.

- Compatible with Lua. Most files are valid Luna files straight away.
- Multiple transpilation levels (implemented: ✘):
	- `debug (default)` attempts to match Lua line numbers with original Luna source line numbers.
	- `pretty` creates as readable Lua code as possible, leaves in comments etc..
	- `optimize` attempts to save space by shortening identifiers, removing whitespace etc..

### Usage

`lua luna.lua [args]`

Compiling the example file: `example.luna`, run `lua luna.lua c examples/example.luna`

### Differences from vanilla Lua

#### Assignment operators (implemented: ✔)

```lua
local x = 1
x += 2
assert(x == 3)

local t = { num = 2 }
t.num *= 3.5
assert(t.num == 7)
```

#### Conditional assignment (`if local` (implemented: ✔) / `while local` (implemented: ✘))

```lua
if local x = someMethod() then
	print("x is trueish!")
end

assert(x == nil) -- no longer in scope
```
```lua
while local node = getNextNode() do
	print("node: ", node)
end
```

#### Shorthand function syntax (implemented: ✔)

```lua
local fn1 = (name) => "Hello " .. name
local fn2 = (age) => do
	print("You are " .. age .. " years old")
end

print(fn("Mike"))
fn2(25)
```

#### Type signatures (implemented: ✔)

Note: can be used in eg. local variables, but at the moment do not do anything there.

```lua
function fn(a: string, b: number?)end

fn() -- error: missing 'a'
fn(40) -- error: 'a' is invalid type
fn("hello") -- works
fn("hello", "world") -- error: 'b' is invalid type
fn("hello", 42) -- works
```

#### Set-If-Falsey operator (implemented: ✔)

```lua
local x = nil

x ||= "hello"
-- x = "hello"

x ||= "world"
-- x = "hello"

x ||= print("exec")
-- nothing prints, expression is not evaluated if x is truthy
```

#### Pattern matching (implemented: ✘)

```lua
x match
	0..10 => print("is a number between 0 and 10")
	"hello" => print("is a string that says hello")
	s: boolean => print("is a boolean: " .. s)
	_ => print("is nothing we care about :(")
end
```

#### Local table/array destructuring (implemented: ✔)

```lua
local person = { name = "Mike", age = 25 }
local {name, age} = person
print(name, " is ", age, " years old")

local vecs = { "a", "b" }
local [first, second] = vecs
print(first, second)
```

#### For loop table/array destructuring (implemented: ✘)

```lua
local people = { { name = "Mike", age = 25 }, { name = "John", age = 47 } }
for _, {name, age} in pairs(people) do
	print(name, age)
end

local vecs = { { "a", "b" }, { "o", "p" } }
for _, [first, second] in pairs(vecs) do
	print(first, second)
end
```

#### Macros (implemented: ✘)

Note: cannot create your own macros at the moment.

```lua
local tbl = { "word", "mate" }
local m = map!(tbl, (w) => w:upper())
```

#### Method references (implemented: ✘)

```lua
function obj:Method()
	local ref = self::Callback

	ref("this is the arg")
end
function obj:Callback(arg)
	print(arg)
end
```