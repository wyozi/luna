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

#### Optional `then` (implemented: ✔)

```lua
if x
	print("do x")
elseif y
	print("do y")
else
	print("else")
end
```

#### Assignment operators (implemented: ✔)

```lua
local x = 1
x += 2
assert(x == 3)

local t = { num = 2 }
t.num *= 3.5
assert(t.num == 7)
```

#### Binary literals (implemented: ✔)

```lua
assert(0b11 == 3)
assert(0b10_01 == 9)
```

#### `if local` (implemented: ✔)

```lua
if local x = someMethod() then
	print("x is trueish!")
end

assert(x == nil) -- no longer in scope
```

#### Shorthand function syntax (implemented: ✔)

```lua
local fn1 = name => "Hello " .. name
local fn2 = (age: number) => do
	print("You are " .. age .. " years old")
end

print(fn1("Mike"))
fn2(25)
```
```lua
local function sqr(x) = x * x
assert(sqr(2) == 4)
```

#### Type signatures (implemented: ✔)

Internally uses the Lua `type` function to check for types.
If you have a custom table type, you can add `__type` field to its metatable, and it'll work with Luna's type system.

Note: at the moment the type checking is only done for function parameters.

```lua
function fn(a: string, b: number?)end

fn() -- error: missing 'a'
fn(40) -- error: 'a' is invalid type
fn("hello") -- works
fn("hello", "world") -- error: 'b' is invalid type
fn("hello", 42) -- works

assert("hello" is string) -- can also use 'x is y' syntax
```

#### Default parameter values (implemented: ✔)

```lua
function fn(b: number? = 42) return b end

assert(fn() == 42)
assert(fn(nil) == 42)
assert(fn(13) == 13)
fn("hello") -- throws an error: 'hello' is not a number
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

#### `return if` (implemented: ✔)

```lua
function fn(x: number)
	return false if x < 0

	return 2 ^ x
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

#### `for of` (implemented: ✔)

Note: destructuring within loop variable is only supported in `for of` loops at the moment.

`of` uses `pairs` internally.  
`ofi` uses `ipairs` internally.

```lua
local people = { { name = "Mike", age = 25 }, { name = "John", age = 47 } }
for {name, age} of people do
	print(name, age)
end

local vecs = { { "a", "b" }, { "o", "p" } }
for i, [first, second] ofi vecs do
	print("vec #" .. i .. ":", first, second)
end

-- only iterates collection if it is not nil
for k,v of? coll do
	print(k, v)
end
```

#### Method references (implemented: ✔)

```lua
function obj:Method()
	local ref = self::Callback

	ref("this is the arg")
end
function obj:Callback(arg)
	print(arg)
end
```

#### Safe indexing (implemented: ✔)

```lua
local x: table? = { item = "banana" }

print(x?.item) -- prints "banana"

x = nil
print(x?.item) -- prints nil
```

#### Pattern matching (implemented: partially)

Note: pattern matching body must be a statement for now.

```lua
match x
	0..10 => return "is a number between 0 and 10"
	"hello" => return "is a string that says hello"
	str: string => return "is a string: " .. str
	num: number if num > 10 => return "is a number over 10: " .. num
	nil => return "nil!"
	_ => return "is nothing we care about :("
end
```

#### Modules (implemented: partially)

Note: only `import * as name from "lib"` works at the moment. To export members simply return a table containing them in a file.

```lua
-- a.luna
export TARGET_WORLD = "World"
export function getTarget()
	return TARGET_WORLD
end
```
```lua
-- b.luna
import getTarget from "a"
print("Hello " .. getTarget())
```
```lua
-- c.luna
import * as a from "a"
print("Hello " .. a.getTarget())
```

#### Macros (implemented: ✘)

Note: cannot create your own macros at the moment.

```lua
local tbl = { "dog", "word", "mate" }

-- extension macro; can be called as if it was a method
local ntbl = tbl:map!((w) => w:upper())

-- above line is equal to this
local ntbl = map!(tbl, (w) => w:upper())

-- extension macros can be chained
local ntbl = tbl:map!((w) => w:upper()):filter!((w) => #w > 3)

```