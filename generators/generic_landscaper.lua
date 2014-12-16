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

local jelly = jelly

local log = radiant.log.create_logger("world_generation")

local TerrainType, FilterFns = jelly.sh.TerrainType, jelly.sh.FilterFns

local Generator = class()

--! desc Initialises the generator.
--! param RandomNumberGenerator rng The random number generator the landscaper expects this generator to use.
--! param Landscaper landscaper The landscaper that is requesting us
--! param table elements Foo_by_terrain table. TODO.
function Generator:__init(elements, filter_function, filter_order, args)
  self._elements, self._filter_function, self._filter_order = elements, filter_function, filter_order
  
  self._args = args
end

function Generator:set_noise_function(func)
  -- Import our variables from args
  self._noise_func = func
end

function Generator:mark()
  assert(self._noise_func, "noise func was not set")
  
  local args = self._args
  
  -- Import. Kind of.
  local landscaper, feature_map = args.landscaper, args.feature_map
  local noise_map, density_map = args.landscaper:_get_filter_buffers(feature_map.width, feature_map.height) -- JELLY EDIT // TODO: Make this less private?
  
  -- Augment args
  args.noise_map, args.density_map = noise_map, density_map
  
  -- Fill the noise map
  noise_map:fill_ij(function(i, j) return self._noise_func(i, j, args) end)
  -- trees: 2D_0125 (10)
  -- bushes: 2D_050 (6)
  -- flowers: 2D_025 (8)
  FilterFns[self._filter_function](density_map, noise_map, noise_map.width, noise_map.height, self._filter_order)
  
  for j = 1, density_map.height do
    for i = 1, density_map.width do
      -- Not occupied
      if feature_map:get(i, j) == nil then
        -- Get the density
        self:place(args, i, j, density_map:get(i, j))
      end
    end
  end
end

function Generator:place(args, i, j, density)
  if density > 0 then
    local landscaper = args.landscaper
    
    -- Determine elevation
    local elevation = args.elevation_map:get(i, j)
    
    -- Determine terrain type and step ("plateau level"?)
    local terrain_type, step = args.terrain_info:get_terrain_type_and_step(elevation)
    
    -- Get the tree name directly.
    local tree_type = landscaper:_get_tree_type(terrain_type, step)
    
    -- Get the tree object
    log:info('find object for %.1f (%s - %d)', density, terrain_type, step)
    local tree_object = landscaper:_get_flora_object(self._elements[terrain_type], density, args.rng, terrain_type, step)
    log:info('object: %s', tostring(tree_object))
    if tree_object and (not tree_object.vegetation_chance or tree_object.vegetation_chance < args.rng:get_real(0, 1)) then
      tree_object = tree_object.jelly_id
    else
      tree_object = landscaper.generic_vegetation_name
    end

    args.feature_map:set(i, j, tree_object)
    log:info('place %s at %d/%d', tree_object, i, j)
  --[[ JELLY END ]]
  end	
end

return Generator