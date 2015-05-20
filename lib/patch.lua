--[=============================================================================[
The MIT License (MIT)

Copyright (c) 2015 RepeatPan
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

-- This library can be included in other mods to have patching functionality,
-- although this is not really recommended. Use at your own risk.

local patch = {}
local log = radiant.log.create_logger("patching")

-- "Replaces" `original_path` with `patched_path`.
-- Note that both paths need to be denoted in lua's require kind of style... thing.
-- i.e. "stonehearth.services.server.world_generation.landscaper"
-- dots instead of slashes, without file extension.
function patch.lua(original_path, patched_path)
  local current_module_name = __get_current_module_name(1)

  log:info('patch %q -> %q', original_path, patched_path)
  -- Require both files
  log:spam('require source file %q', original_path)
  local source = radiant.mods.require(original_path)
  
  -- Get the source mod
  local original_mod = original_path:match('^(.-%.)')
  
  local old_require = require
  
  function require(path)
    if path:sub(-4) == '.lua' then
      path = path:sub(1, -4)
    end
    
    if path:sub(1, 5) == 'jelly' then
      return radiant.mods.require(path)
    end
    
    log:spam('include %q (translated to %s%s)', path, original_mod, path)
    
    return radiant.mods.require(original_mod .. path)
  end
  
  local old___get_current_module_name = __get_current_module_name
  
  local callee_filename = '@' .. patched_path:gsub('%.', '/') .. '.lua'
  
  function __get_current_module_name(depth)
    local old_result = old___get_current_module_name(depth + 1)
    local callee = debug.getinfo(3, 'S').source
    
    if depth == 3 and old_result == current_module_name and callee == callee_filename then
      log:spam('changed module name from %q to %q (%q)', current_module_name, original_mod, debug.getinfo(3, 'S').source)
      return original_mod
    end
    
    return old_result
  end
  
  log:spam('require patch file %q', patched_path)
  local patch = radiant.mods.require(patched_path)
  
  require = old_require
    
  if not patch then
    error('cannot find patch file '.. patched_path .. ' _or_ there was an error')
    return
  end
  
  -- Clear source
  for k, v in pairs(source) do
    source[k] = nil
  end
  
  -- Create the patch
  for k, v in pairs(patch) do
    source[k] = v
  end
  
  -- Set the metatable
  setmetatable(source, getmetatable(patch))
end

return patch