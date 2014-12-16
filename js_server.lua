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

local JS = class()

local data_store = radiant.create_datastore()

local calls = {}
local data = {}

local function update_data_store()
  data_store:set_data({ calls = calls, data = data })
  calls = {}
end

function JS:__init()
  update_data_store()
end

function JS:_get_server_data_store()
  return { data_store = data_store }
end

function JS:call(fn, ...)
  table.insert(calls, { fn = fn, args = { ... }})
  update_data_store()
  calls = {} -- I'm not sure why we reset the calls once we've inserted one. That seems kinda counter-intuitive if we have multiple calls between two polls. TODO.
end

function JS:print(session, response, ...)
  print(...)
end

function JS:store_data(session, response, var_name, value)
  -- The data store is not updated, as the JS side does its own house keeping too.
  -- If the JS state is created (again), it will query the current status, upon which we'll have the
  -- data prepared.
  data[var_name] = value
end

return JS