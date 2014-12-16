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

local log = radiant.log.create_logger('jelly')
log:info('Loading Jelly.')

-- The jelly family
jelly = {}
jelly.util = require('lib.util')
jelly.resources = require('lib.resources')
jelly.linq = require('lib.linq')
jelly.sh = require('lib.sh')
jelly.timers = require('lib.timers')
jelly.tasks = require('lib.tasks')
jelly.out = require('lib.out')

-- lua standard library extensions
require('lib.table')

-- Standard patches
require('overrides.misc')

if radiant.is_server then
  local js = require('js_server')
  
  --! desc Simulates _radiant.call. This will cause a significant delay, as all commands are re-directed to JavaScript, where they are
  --! desc then re-evaluated. Use this only if you really need to call client sided functions from the server side.
  --! returns Nothing. It is not possible to wait for these calls.
  function jelly.call(...)
    js:call(...)
  end
end

log:info('Jelly loaded.')
print('Jelly loaded.')

return jelly