--[=============================================================================[
The MIT License (MIT)

Copyright (c) 2014 RepeatPan
excluding parts that were written by Radiant Entertainment

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

local stdout = radiant.log.create_logger('out')

-- Note: Most/all of these functions are global too, because they are "too vital"
-- TODO: Make globalisation optional.
local out = {}

do -- Overwrites `io.output' to our log file(s)
	io.output('jelly_stdout' .. (radiant.is_server and '_server' or '') .. '.log')
	local function print_plain(to_logger, ...)
		local t = { ... }
		
		local argc = select('#', ...)
		io.write('[')
		io.write(os.date())
		io.write('] ')
		
		for i = 1, argc do
			t[i] = tostring(t[i])
			io.write(t[i])
			
			if i < argc then
				io.write("\t")
			end
		end
		
		io.write("\n")
		io.flush()
		
		if to_logger then
			stdout:write(0, table.concat(t, '\t'))
		end
	end
	
	function print(...)
		print_plain(true, ...)
	end
	
	function printf(str, ...)
		print_plain(false, string.format(str, ...))
		stdout:write(0, str, ...)
	end
	
	out.print, out.printf = print, printf
end

return out