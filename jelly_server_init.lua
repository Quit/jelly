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


local jelly = require('jelly')
local TerrainType = radiant.mods.require("stonehearth.services.server.world_generation.terrain_type")
local log = radiant.log.create_logger("server")

local MOD = class()

function MOD:__init()
  radiant.events.listen(radiant, 'radiant:modules_loaded', self, self._patch_all)
end

function MOD:_patch_all()
  log:info('Patch stuff.')
  self:_patch('stonehearth.services.server.world_generation.landscaper', 'jelly.overrides.services.world_generation.landscaper')
  self:_patch('stonehearth.call_handlers.new_game_call_handler', 'jelly.overrides.call_handlers.new_game_call_handler')
end

function MOD:_patch(original_path, patched_path)
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

-- Because of Stonehearths... rather undesirable mod loading process, we alias those who don't require() us.
function MOD:__get(key)
  return rawget(jelly, key)
end

return MOD()