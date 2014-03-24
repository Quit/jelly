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

--! realm jelly
local linq = {}

-- Localise.
local next = next

--! desc Maps `tbl` using `func`. Lazy evaluated.
--! param table tbl Table that should be mapped
--! param function func Function that receives two arguments (`key`, `value`) and returns the new element.
--! returns lua iterator
--! EXPERIMENTAL
function linq.map_pairs(tbl, func)
	local map_next = function(tbl, index)
		local k, v = next(tbl, index)
		
		if k == nil then
			return nil, nil
		end
		
		return k, func(k, v)
	end
	
	return map_next, tbl, nil	
end

--! desc Picks only certain elements from `tbl` by evaluating them using `func`
--! param table tbl Table that should be searched for
--! param function func Function that decides whether an element is taken or not
--! returns lua iterator
--! EXPERIMENTAL
function linq.where_pairs(tbl, func)
	local grep_next = function(tbl, k)
		local v
		repeat
			k, v = next(tbl, k)
		until not k or func(k, v)
		
		return k, v
	end
	
	return grep_next, tbl, nil
end

--! desc Concats multiple tables into one.
--! EXPERIMENTAL
function linq.concat_pairs(tbl, ...)
	local args = { ... }
	local concat_next
	concat_next	= function(_, k)
		local k, v = next(tbl, k)
		
		-- end of table?
		if k == nil then
			-- next one!
			tbl = table.remove(args, 1)
			-- no table left?
			if tbl == nil then
				return nil, nil
			end
			
			-- re-iterate, just to be sure. and stuff.
			return concat_next(_, nil)
		end
		
		return k, v
	end
	
	return concat_next, tbl, nil
end

return linq