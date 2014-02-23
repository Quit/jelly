--[=============================================================================[
The MIT License (MIT)

Copyright (c) 2014 RepeatPan

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]=============================================================================]

local radiant = radiant
local type, error = type, error

local resources = {}

--! desc If `name` is a table, `name` is returned. If `name` is a string, it is tried to `radiant.resources.load_json`.
--! param string/table name The value that should be loaded (if necessary).
--! returns table The table that represents this value.
--! remarks This function is especially useful if you wish to load data from JSON, but wish that they might be `file()`'d or aliased instead of "written in"
function resources.load_table(name)
	if type(name) == 'table' then
		return name
	elseif type(name) == 'string' then
		return radiant.resources.load_json(name)
	else
		error('bad argument #1 to jelly.resources.load_table: expected string or table, got ' .. type(name))
	end
end

return resources