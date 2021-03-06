local check = require "luacheck.check"

describe("check", function()
   it("does not find anything wrong in an empty block", function()
      assert.same({}, check(""))
   end)

   it("does not find anything wrong in used locals", function()
      assert.same({
         {code = "113", name = "print", line = 5, column = 4}
      }, check[[
local a
local b = 5
a = 6
do
   print(b, {a})
end
      ]])
   end)

   it("detects global set", function()
      assert.same({
         {code = "111", name = "foo", line = 1, column = 1, top = true}
      }, check[[
foo = {}
      ]])
   end)

   it("detects global set in nested functions", function()
      assert.same({
         {code = "111", name = "foo", line = 2, column = 4}
      }, check[[
local function bar()
   foo = {}
end
bar()
      ]])
   end)

   it("detects global access in multi-assignments", function()
      assert.same({
         {code = "532", line = 2, column = 1},
         {code = "111", name = "y", line = 2, column = 4, top = true},
         {code = "113", name = "print", line = 3, column = 1}
      }, check[[
local x
x, y = 1
print(x)
      ]])
   end)

   it("detects global access in self swap", function()
      assert.same({
         {code = "113", name = "a", line = 1, column = 11},
         {code = "113", name = "print", line = 2, column = 1}
      }, check[[
local a = a
print(a)
      ]])
   end)

   it("detects global mutation", function()
      assert.same({
         {code = "112", name = "a", line = 1, column = 1}
      }, check[[
a[1] = 6
      ]])
   end)

   it("detects unused locals", function()
      assert.same({
         {code = "211", name = "a", line = 1, column = 7},
         {code = "113", name = "print", line = 5, column = 4}
      }, check[[
local a = 4

do
   local b = 6
   print(b)
end
      ]])
   end)

   it("detects unused locals from function arguments", function()
      assert.same({
         {code = "212", name = "foo", line = 1, column = 17}
      }, check[[
return function(foo, ...)
   return ...
end
      ]])
   end)

   it("detects unused implicit self", function()
      assert.same({
         {code = "212", name = "self", self = true, line = 2, column = 13}
      }, check[[
local a = {}
function a:b()
   
end
      ]])
   end)

   it("detects unused locals from loops", function()
      assert.same({
         {code = "213", name = "i", line = 1, column = 5},
         {code = "213", name = "i", line = 2, column = 5},
         {code = "113", name = "pairs", line = 2, column = 10}
      }, check[[
for i=1, 2 do end
for i in pairs{} do end
      ]])
   end)

   it("detects unused values", function()
      assert.same({
         {code = "311", name = "a", line = 3, column = 4},
         {code = "311", name = "a", line = 5, column = 4},
         {code = "113", name = "print", line = 9, column = 1}
      }, check[[
local a
if true then
   a = 2
else
   a = 3
end

a = 5
print(a)
      ]])
   end)

   it("does not detect unused value when it and a closure using it can live together", function()
      assert.same({
         {code = "113", name = "escape", line = 3, column = 4}
      }, check[[
local a = 3
if true then
   escape(function() return a end)
end
      ]])
   end)

   it("does not consider value assigned to upvalue as unused if it is accessed in another closure", function()
      assert.same({}, check[[
local a

local function f(x) a = x end
local function g() return a end
return f, g
      ]])
   end)

   it("does not consider a variable initialized if it can't get a value due to short rhs", function()
      assert.same({}, check[[
local a, b = "foo"
b = "bar"
return a, b
      ]])
   end)

   it("considers a variable initialized if short rhs ends with potential multivalue", function()
      assert.same({
         {code = "311", name = "b", line = 2, column = 13, secondary = true}
      }, check[[
return function(...)
   local a, b = ...
   b = "bar"
   return a, b
end
      ]])
   end)

   it("reports unused variable as secondary if it is assigned together with a used one", function()
      assert.same({
         {code = "211", name = "a", line = 2, column = 10, secondary = true}
      }, check[[
return function(f)
   local a, b = f()
   return b
end
      ]])
   end)

   it("reports unused value as secondary if it is assigned together with a used one", function()
      assert.same({
         {code = "231", name = "a", line = 2, column = 10, secondary = true}
      }, check[[
return function(f)
   local a, b
   a, b = f()
   return b
end
      ]])

      assert.same({
         {code = "231", name = "a", line = 2, column = 10, secondary = true}
      }, check[[
return function(f, t)
   local a
   a, t[1] = f()
end
      ]])
   end)

   it("considers a variable assigned even if it can't get a value due to short rhs (it still gets nil)", function()
      assert.same({
         {code = "311", name = "a", line = 1, column = 7},
         {code = "311", name = "b", line = 1, column = 10},
         {code = "532", line = 2, column = 1}
      }, check[[
local a, b = "foo", "bar"
a, b = "bar"
return a, b
      ]])
   end)

   it("reports vartype == var when the unused value is not the initial", function()
      assert.same({
         {code = "312", name = "b", line = 1, column = 23},
         {code = "311", name = "a", line = 2, column = 4}
      }, check[[
local function foo(a, b)
   a = a or "default"
   a = 42
   b = 7
   return a, b
end

return foo
      ]])
   end)

   it("does not detect unused values in loops", function()
      assert.same({
         {code = "113", name = "print", line = 3, column = 4},
         {code = "113", name = "math", line = 4, column = 8}
      }, check[[
local a = 10
while a > 0 do
   print(a)
   a = math.floor(a/2)
end
      ]])
   end)

   it("detects redefinition in the same scope", function()
      assert.same({
         {code = "211", name = "foo", line = 1, column = 7},
         {code = "411", name = "foo", line = 2, column = 7, prev_line = 1, prev_column = 7},
         {code = "113", name = "print", line = 3, column = 1}
      }, check[[
local foo
local foo = "bar"
print(foo)
      ]])
   end)

   it("detects redefinition of function arguments", function()
      assert.same({
         {code = "212", name = "foo", line = 1, column = 17},
         {code = "212", name = "...", line = 1, column = 22, vararg = true},
         {code = "412", name = "foo", line = 2, column = 10, prev_line = 1, prev_column = 17}
      }, check[[
return function(foo, ...)
   local foo = 1
   return foo
end
      ]])
   end)

   it("marks redefinition of implicit self", function()
      assert.same({
         {code = "112", name = "t", line = 1, column = 10},
         {code = "212", name = "self", line = 1, column = 13, self = true},
         {code = "212", name = "self", line = 3, column = 16, self = true},
         {code = "432", name = "self", line = 3, column = 16, self = true, prev_line = 1, prev_column = 13}
      }, check[[
function t:f()
   local o = {}
   function o:g() end
end
      ]])

      assert.same({
         {code = "112", name = "t", line = 1, column = 10},
         {code = "212", name = "self", line = 1, column = 14},
         {code = "212", name = "self", line = 3, column = 16, self = true},
         {code = "432", name = "self", line = 3, column = 16, prev_line = 1, prev_column = 14}
      }, check[[
function t.f(self)
   local o = {}
   function o:g() end
end
      ]])

      assert.same({
         {code = "112", name = "t", line = 1, column = 10},
         {code = "212", name = "self", line = 1, column = 13, self = true},
         {code = "212", name = "self", line = 3, column = 17},
         {code = "432", name = "self", line = 3, column = 17, prev_line = 1, prev_column = 13}
      }, check[[
function t:f()
   local o = {}
   function o.g(self) end
end
      ]])
   end)

   it("detects shadowing definitions", function()
      assert.same({
         {code = "431", name = "a", line = 4, column = 10, prev_line = 1, prev_column = 7},
         {code = "421", name = "a", line = 7, column = 13, prev_line = 4, prev_column = 10}
      }, check[[
local a = 46

return a, function(foo, ...)
   local a = 1

   do
      local a = 6
      foo(a, ...)
   end

   return a
end
      ]])
   end)

   it("detects unset variables", function()
      assert.same({
         {code = "221", name = "a", line = 1, column = 7}
      }, check[[
local a
return a
      ]])
   end)

   it("detects unused labels", function()
      assert.same({
         {code = "521", name = "fail", line = 2, column = 4}
      }, check[[
::fail::
do ::fail:: end
goto fail
      ]])
   end)

   it("detects unreachable code", function()
      assert.same({
         {code = "511", line = 2, column = 1}
      }, check[[
do return end
if true then return 6 end
return 3
      ]])

      assert.same({
         {code = "511", line = 7, column = 1},
         {code = "511", line = 13, column = 1}
      }, check[[
if false then
   return 4
else
   return 6
end

if true then
   return 7
else
   return 8
end

return 3
      ]])
   end)

   it("detects accessing uninitialized variables", function()
      assert.same({
         {code = "113", name = "get", line = 6, column = 8},
         {code = "321", name = "a", line = 6, column = 12}
      }, check[[
local a

if true then
   a = 5
else
   a = get(a)
end

return a
      ]])
   end)

   it("does not detect accessing unitialized variables incorrectly in loops", function()
      assert.same({
         {code = "113", name = "get", line = 4, column = 8}
      }, check[[
local a

while not a do
   a = get()
end

return a
      ]])
   end)

   it("detects unbalanced assignments", function()
      assert.same({
         {code = "532", line = 4, column = 1},
         {code = "531", line = 5, column = 1}
      }, check[[
local a, b = 4; (...)(a)

a, b = (...)(); (...)(a, b)
a, b = 5; (...)(a, b)
a, b = 1, 2, 3; (...)(a, b)
      ]])
   end)

   it("detects empty blocks", function()
      assert.same({
         {code = "541", line = 1, column = 1},
         {code = "542", line = 3, column = 9},
         {code = "542", line = 5, column = 14},
         {code = "542", line = 7, column = 1}
      }, check[[
do end

if true then

elseif false then

else

end

while true do end
repeat until true
      ]])
   end)

   it("handles argparse sample", function()
      assert.table(check(io.open("spec/samples/argparse.lua", "rb"):read("*a")))
   end)
end)
