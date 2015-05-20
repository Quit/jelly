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
local log = radiant.log.create_logger("server")

local MOD = class()

function MOD:__init()
  radiant.events.listen(radiant, 'radiant:required_loaded', self, self._patch_all)
end

function MOD:_patch_all()
  log:info('Patch stuff.')
  -- Increased complexity with the water update.
  --self:_patch('stonehearth.services.server.world_generation.landscaper', 'jelly.overrides.services.world_generation.landscaper')
  jelly.patch.lua('stonehearth.call_handlers.new_game_call_handler', 'jelly.overrides.call_handlers.new_game_call_handler')
end

-- Because of Stonehearths... rather undesirable mod loading process, we alias those who don't require() us.
function MOD:__get(key)
  return rawget(jelly, key)
end

return MOD()