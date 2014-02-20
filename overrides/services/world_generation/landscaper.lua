local TerrainType = require("services.world_generation.terrain_type")
local TerrainInfo = require("services.world_generation.terrain_info")
local Array2D = require("services.world_generation.array_2D")
local MathFns = require("services.world_generation.math.math_fns")
local FilterFns = require("services.world_generation.filter.filter_fns")
local PerturbationGrid = require("services.world_generation.perturbation_grid")
local BoulderGenerator = require("services.world_generation.boulder_generator")
local log = radiant.log.create_logger("world_generation")
local Point3 = _radiant.csg.Point3
local mod_name = "stonehearth"
local mod_prefix = mod_name .. ":"
local oak = "oak_tree"
local juniper = "juniper_tree"
local tree_types = {oak, juniper}
local small = "small"
local medium = "medium"
local large = "large"
local tree_sizes = {
  small,
  medium,
  large
}
local pink_flower_name = mod_prefix .. "pink_flower"
local berry_bush_name = mod_prefix .. "berry_bush"
local generic_vegetaion_name = "vegetation"

--[[ JELLY START ]]--
local generic_vegetation_name = generic_vegetaion_name
local jelly = radiant.mods.require('jelly.jelly')
--[[ JELLY END ]]--

local boulder_name = "boulder"
local Landscaper = class()

function Landscaper:__init(terrain_info, rng, async)
  if async == nil then
    async = false
  end
  self._terrain_info = terrain_info
  self._tile_width = self._terrain_info.tile_size
  self._tile_height = self._terrain_info.tile_size
  self._feature_size = self._terrain_info.feature_size
  self._rng = rng
  self._async = async
  self._boulder_probabilities = {
    [TerrainType.plains] = 0.02,
    [TerrainType.foothills] = 0.02,
    [TerrainType.mountains] = 0.02
  }
  self._boulder_generator = BoulderGenerator(self._terrain_info, self._rng)
  self._noise_map_buffer = nil
  self._density_map_buffer = nil
  self._perturbation_grid = PerturbationGrid(self._tile_width, self._tile_height, self._feature_size, self._rng)
  self:_initialize_function_table()
end

function Landscaper:_initialize_function_table()
  local tree_name
  local function_table = {}
  for _, tree_type in pairs(tree_types) do
    for _, tree_size in pairs(tree_sizes) do
      tree_name = get_tree_name(tree_type, tree_size)
      if tree_size == small then
        function_table[tree_name] = self._place_small_tree
      else
        function_table[tree_name] = self._place_normal_tree
      end
    end
  end
  function_table[berry_bush_name] = self._place_berry_bush
  function_table[pink_flower_name] = self._place_flower
  self._function_table = function_table
end

function Landscaper:_get_filter_buffers(width, height)
  if self._noise_map_buffer == nil or self._noise_map_buffer.width ~= width or self._noise_map_buffer.height ~= height then
    self._noise_map_buffer = Array2D(width, height)
    self._density_map_buffer = Array2D(width, height)
  end
  assert(self._density_map_buffer.width == self._noise_map_buffer.width)
  assert(self._density_map_buffer.height == self._noise_map_buffer.height)
  return self._noise_map_buffer, self._density_map_buffer
end

function Landscaper:is_forest_feature(feature_name)
  if feature_name == nil then
    return false
  end
  if self:is_tree_name(feature_name) then
    return true
  end
  if feature_name == generic_vegetaion_name then
    return true
  end
  return false
end

function Landscaper:place_flora(tile_map, feature_map, tile_offset_x, tile_offset_y)
  local function place_item(uri, x, y)
    local entity = radiant.entities.create_entity(uri)
    radiant.terrain.place_entity(entity, Point3(x - 1 + tile_offset_x, 1, y - 1 + tile_offset_y))
    self:_set_random_facing(entity)
    return entity
  end
  self:place_features(tile_map, feature_map, place_item)
end

-- Marks the trees
function Landscaper:mark_trees(elevation_map, feature_map)
  local rng = self._rng
  local terrain_info = self._terrain_info
  local normal_tree_density = 0.8
  local mountains_size_modifier = 0.1
  local mountains_density_base = 0.4
  local mountains_density_peaks = 0.1
  local noise_map, density_map = self:_get_filter_buffers(feature_map.width, feature_map.height)
  local tree_name, tree_type, tree_size, occupied, value, elevation, terrain_type, step, tree_density
	
	--[[ START JELLY ]]--
	local tree_object
	--[[ END JELLY ]]--
	
  local function noise_fn(i, j)
    local mean = 0
    local std_dev = 100
    if noise_map:is_boundary(i, j) then
      mean = mean - 20
    end
    local elevation = elevation_map:get(i, j)
    local terrain_type, step = terrain_info:get_terrain_type_and_step(elevation)
    if terrain_type == TerrainType.mountains then
      if step <= 2 then
        mean = mean + 50
        std_dev = 0
      else
        std_dev = std_dev * 0.3
      end
    elseif terrain_type == TerrainType.plains then
      if step == 2 then
        mean = mean - 5
      else
        mean = mean - 100
      end
    elseif step == 2 then
      mean = mean + 5
      std_dev = std_dev * 0.3
    else
      std_dev = std_dev * 0.3
    end
    return rng:get_gaussian(mean, std_dev)
  end
	
  noise_map:fill_ij(noise_fn)
  FilterFns.filter_2D_0125(density_map, noise_map, noise_map.width, noise_map.height, 10)
	
  for j = 1, density_map.height do
    for i = 1, density_map.width do
      occupied = feature_map:get(i, j) ~= nil
			
			-- Not occupied
      if not occupied then
				-- Get the density
        value = density_map:get(i, j)
				
        if value > 0 then
          elevation = elevation_map:get(i, j)
          terrain_type, step = terrain_info:get_terrain_type_and_step(elevation)
					-- Get the tree name directly.
					--[[ JELLY START ]]--
					
				
				--[[
          tree_type = self:_get_tree_type(terrain_type, step)
          if terrain_type ~= TerrainType.mountains then
            tree_density = normal_tree_density
          else
            value = value * mountains_size_modifier
            if step == 1 then
              tree_density = mountains_density_base
            else
              tree_density = mountains_density_peaks
            end
          end
          tree_size = self:_get_tree_size(value)
          tree_name = get_tree_name(tree_type, tree_size)
				]]
				
					tree_object = self:_get_tree_object(elevation, value, terrain_type, step)
					if tree_object and (not tree_object.vegetation_chance or tree_object.vegetation_chance > rng:get_real(0, 1)) then
						tree_name = tree_object.jelly_id
					else
						tree_name = generic_vegetation_name
					end
					
					-- TODO: properly decide what to do here
				--[[
          if terrain_type ~= TerrainType.mountains then
            if tree_size ~= small and tree_density <= rng:get_real(0, 1) then
              tree_name = generic_vegetaion_name
            end
            feature_map:set(i, j, tree_name)
          elseif tree_density > rng:get_real(0, 1) then
            feature_map:set(i, j, tree_name)
          end
				]]--
				
				feature_map:set(i, j, tree_name)
				
				--[[ JELLY END ]]
        end
      end
    end
  end
end

function Landscaper:_get_tree_type(terrain_type, step)
  local rng = self._rng
  local terrain_info = self._terrain_info
  local high_foothills_juniper_chance = 0.75
  local low_foothills_juniper_chance = 0.25
  if terrain_type == TerrainType.plains then
    return oak
  end
  if terrain_type == TerrainType.mountains then
    return juniper
  end
  if step == 2 then
    if high_foothills_juniper_chance > rng:get_real(0, 1) then
      return juniper
    else
      return oak
    end
  elseif low_foothills_juniper_chance > rng:get_real(0, 1) then
    return juniper
  else
    return oak
  end
end

function Landscaper:_get_tree_size(value)
  local large_tree_threshold = 20
  local medium_tree_threshold = 4
  if value >= large_tree_threshold then
    return large
  end
  if value >= medium_tree_threshold then
    return medium
  end
  return small
end

function Landscaper:_place_small_tree(feature_name, i, j, tile_map, place_item)
  local small_tree_density = 0.5
  local exclusion_radius = 2
  local factor = 0.5
  local rng = self._rng
  local perturbation_grid = self._perturbation_grid
  local x, y, w, h, nested_grid_spacing
  x, y, w, h = perturbation_grid:get_cell_bounds(i, j)
  local center = self._feature_size * 0.5
  local elevation = tile_map:get(x + center, y + center)
  local terrain_type = self._terrain_info:get_terrain_type(elevation)
  if terrain_type == TerrainType.mountains then
    return self:_place_normal_tree(feature_name, i, j, tile_map, place_item)
  end
  nested_grid_spacing = math.floor(perturbation_grid.grid_spacing * factor)
  local function try_place_item(x, y)
    place_item(feature_name, x, y)
    return true
  end
  self:_place_dense_items(tile_map, x, y, w, h, nested_grid_spacing, exclusion_radius, small_tree_density, try_place_item)
end

function Landscaper:_place_normal_tree(feature_name, i, j, tile_map, place_item)
--~ 	log:spam('place normal %s', feature_name)
  local max_trunk_radius = 3
  local ground_radius = 2
  local rng = self._rng
  local perturbation_grid = self._perturbation_grid
  local x, y
  x, y = perturbation_grid:get_perturbed_coordinates(i, j, max_trunk_radius)
  if self:_is_flat(tile_map, x, y, ground_radius) then
    place_item(feature_name, x, y)
  end
end

function Landscaper:place_features(tile_map, feature_map, place_item)
  local feature_name, fn
  for j = 1, feature_map.height do
    for i = 1, feature_map.width do
      feature_name = feature_map:get(i, j)
      fn = self._function_table[feature_name]
      if fn then
        fn(self, feature_name, i, j, tile_map, place_item)
      end
    end
    self:_yield()
  end
end

function Landscaper:mark_berry_bushes(elevation_map, feature_map)
  local rng = self._rng
  local terrain_info = self._terrain_info
  local perturbation_grid = self._perturbation_grid
  local noise_map, density_map = self:_get_filter_buffers(feature_map.width, feature_map.height)
  local value, occupied, elevation, terrain_type
  local function noise_fn(i, j)
    local mean = -50
    local std_dev = 30
    local feature = feature_map:get(i, j)
    if self:is_tree_name(feature) then
      mean = mean + 100
    end
    return rng:get_gaussian(mean, std_dev)
  end
  noise_map:fill_ij(noise_fn)
  FilterFns.filter_2D_050(density_map, noise_map, noise_map.width, noise_map.height, 6)
  for j = 1, density_map.height do
    for i = 1, density_map.width do
      value = density_map:get(i, j)
      if value > 0 then
        occupied = feature_map:get(i, j) ~= nil
        if not occupied then
          elevation = elevation_map:get(i, j)
          terrain_type = terrain_info:get_terrain_type(elevation)
          if terrain_type ~= TerrainType.mountains then
            feature_map:set(i, j, berry_bush_name)
          end
        end
      end
    end
  end
end

function Landscaper:_place_berry_bush(feature_name, i, j, tile_map, place_item)
  local terrain_info = self._terrain_info
  local perturbation_grid = self._perturbation_grid
  local item_spacing = math.floor(perturbation_grid.grid_spacing * 0.33)
  local item_density = 0.9
  local x, y, w, h, rows, columns
  local function try_place_item(x, y)
    local elevation = tile_map:get(x, y)
    local terrain_type = terrain_info:get_terrain_type(elevation)
    if terrain_type == TerrainType.mountains then
      return false
    end
    place_item(feature_name, x, y)
    return true
  end
  x, y, w, h = perturbation_grid:get_cell_bounds(i, j)
  rows, columns = self:_random_berry_pattern()
  self:_place_pattern(tile_map, x, y, w, h, rows, columns, item_spacing, item_density, 1, try_place_item)
end

function Landscaper:_random_berry_pattern()
  local roll = self._rng:get_int(1, 3)
  if roll == 1 then
    return 2, 3
  elseif roll == 2 then
    return 3, 2
  else
    return 2, 2
  end
end

function Landscaper:mark_flowers(elevation_map, feature_map)
  local rng = self._rng
  local terrain_info = self._terrain_info
  local perturbation_grid = self._perturbation_grid
  local noise_map, density_map = self:_get_filter_buffers(feature_map.width, feature_map.height)
  local value, occupied, elevation, terrain_type
  local function noise_fn(i, j)
    local mean = 0
    local std_dev = 100
    if noise_map:is_boundary(i, j) then
      mean = mean - 20
    end
    local feature = feature_map:get(i, j)
    if self:is_tree_name(feature) then
      mean = mean - 200
    end
    local elevation = elevation_map:get(i, j)
    local terrain_type, step = terrain_info:get_terrain_type_and_step(elevation)
    if terrain_type == TerrainType.plains and step == 1 then
      mean = mean - 200
    end
    return rng:get_gaussian(mean, std_dev)
  end
  noise_map:fill_ij(noise_fn)
  FilterFns.filter_2D_025(density_map, noise_map, noise_map.width, noise_map.height, 8)
  for j = 1, density_map.height do
    for i = 1, density_map.width do
      value = density_map:get(i, j)
      if value > 0 then
        occupied = feature_map:get(i, j) ~= nil
        if not occupied and value >= rng:get_int(1, 100) then
          elevation = elevation_map:get(i, j)
          terrain_type = terrain_info:get_terrain_type(elevation)
          if terrain_type == TerrainType.plains then
            feature_map:set(i, j, pink_flower_name)
          end
        end
      end
    end
  end
end

function Landscaper:_place_flower(feature_name, i, j, tile_map, place_item)
  local exclusion_radius = 1
  local ground_radius = 1
  local perturbation_grid = self._perturbation_grid
  local x, y
  x, y = perturbation_grid:get_perturbed_coordinates(i, j, exclusion_radius)
  if self:_is_flat(tile_map, x, y, ground_radius) then
    place_item(feature_name, x, y)
  end
end

function Landscaper:_place_pattern(tile_map, x, y, w, h, columns, rows, spacing, density, max_empty_positions, try_place_item)
  local rng = self._rng
  local i, j, result
  local x_offset = math.floor((w - spacing * (columns - 1)) * 0.5)
  local y_offset = math.floor((h - spacing * (rows - 1)) * 0.5)
  local x_start = x + x_offset
  local y_start = y + y_offset
  local num_empty_positions = 0
  local skip
  local placed = false
  for j = 1, rows do
    for i = 1, columns do
      skip = false
      if max_empty_positions > num_empty_positions and density <= rng:get_real(0, 1) then
        num_empty_positions = num_empty_positions + 1
        skip = true
      end
      if not skip then
        result = try_place_item(x_start + (i - 1) * spacing, y_start + (j - 1) * spacing)
        if result then
          placed = true
        end
      end
    end
  end
  return placed
end

function Landscaper:_place_dense_items(tile_map, cell_origin_x, cell_origin_y, cell_width, cell_height, grid_spacing, exclusion_radius, probability, try_place_item)
  local rng = self._rng
  local perturbation_grid = PerturbationGrid(cell_width, cell_height, grid_spacing, rng)
  local grid_width, grid_height = perturbation_grid:get_dimensions()
  local i, j, dx, dy, x, y, result
  local placed = false
  for j = 1, grid_height do
    for i = 1, grid_width do
      if probability > rng:get_real(0, 1) then
        if exclusion_radius >= 0 then
          dx, dy = perturbation_grid:get_perturbed_coordinates(i, j, exclusion_radius)
        else
          dx, dy = perturbation_grid:get_unperturbed_coordinates(i, j)
        end
        x = cell_origin_x + dx - 1
        y = cell_origin_y + dy - 1
        result = try_place_item(x, y)
        if result then
          placed = true
        end
      end
    end
  end
  return placed
end

function Landscaper:_is_flat(tile_map, x, y, distance)
  if distance == 0 then
    return true
  end
  local start_x, start_y = tile_map:bound(x - distance, y - distance)
  local end_x, end_y = tile_map:bound(x + distance, y + distance)
  local block_width = end_x - start_x + 1
  local block_height = end_y - start_y + 1
  local height = tile_map:get(x, y)
  local is_flat = true
  is_flat = tile_map:visit_block(start_x, start_y, block_width, block_height, function(value)
    return value == height
  end)
  return is_flat
end

function Landscaper:_set_random_facing(entity)
  entity:add_component("mob"):turn_to(90 * self._rng:get_int(0, 3))
end

function get_tree_name(tree_type, tree_size)
  return mod_prefix .. tree_size .. "_" .. tree_type
end

function Landscaper:is_tree_name(feature_name)
  if feature_name == nil then
    return false
  end
  local index = feature_name:find("_tree", -5)
  return index ~= nil
end

function Landscaper:mark_boulders(elevation_map, feature_map)
  local elevation
  for j = 2, feature_map.height - 1 do
    for i = 2, feature_map.width - 1 do
      elevation = elevation_map:get(i, j)
      if self:_should_place_boulder(elevation) then
        feature_map:set(i, j, boulder_name)
      end
    end
  end
end

function Landscaper:place_boulders(region3_boxed, tile_map, feature_map)
  local boulder_region
  local exclusion_radius = 8
  local grid_width, grid_height = self._perturbation_grid:get_dimensions()
  local feature_name, elevation, i, j, x, y
  region3_boxed:modify(function(region3)
    for j = 2, grid_height - 1 do
      for i = 2, grid_width - 1 do
        feature_name = feature_map:get(i, j)
        if feature_name == boulder_name then
          x, y = self._perturbation_grid:get_perturbed_coordinates(i, j, exclusion_radius)
          elevation = tile_map:get(x, y)
          boulder_region = self._boulder_generator:_create_boulder(x, y, elevation)
          region3:add_region(boulder_region)
        end
      end
    end
  end)
  self:_yield()
end

function Landscaper:_should_place_boulder(elevation)
  local terrain_type = self._terrain_info:get_terrain_type(elevation)
  local probability = self._boulder_probabilities[terrain_type]
  return probability > self._rng:get_real(0, 1)
end

function Landscaper:_yield()
  if self._async then
    coroutine.yield()
  end
end


--[[ START JELLY CODE ]]--

function Landscaper:_jelly_place_small_tree(jelly_id, ...)
	return self:_place_small_tree(self._trees[jelly_id].entity_ref, ...)
end

function Landscaper:_jelly_place_normal_tree(jelly_id, ...)
	return self:_place_normal_tree(self._trees[jelly_id].entity_ref, ...)
end

function Landscaper:_initialize_function_table()
	-- Load the templates
	local templates = jelly.util.build_classes(radiant.resources.load_json('jelly:index:tree_templates').tree_templates)
	
	-- Load the index
	local json = radiant.resources.load_json('jelly:index:trees')

	local trees = {}
	local trees_by_terrain = {}
	
	local last_id = 1
	
	local function_table = {}
	
	-- Build the trees.
	for _, tree in pairs(json.trees) do
		-- Map the parents, if any
		local parents = jelly.util.map(tree.template or {}, function(_, k) return templates[k] end)
		
		tree = jelly.util.mixinto(tree, parents)
		
		assert(tree.threshold, "threshold missing for #" .. _)
		
		-- Do we need to evaluate chance?
		if type(tree.chance) == 'string' then
			local func, err = loadstring('local terrain, step = ... return ' .. tree.chance)
			if not func then
				log:error('cannot compile function %q: %s', tree.chance, err)
			end
			
			tree.chance = func
		end
		
		tree.jelly_id = 'jelly_tree_' .. last_id
		last_id = last_id + 1
		
		function_table[tree.jelly_id] = function() end

		if tree.cluster then
			assert(tree.cluster_exclusion_radius, "cluster_exclusion_radius missing for #" .. _)
			assert(tree.cluster_factor, "cluster_factor missing for #" .. _)
			assert(tree.cluster_density, "cluster_density missing for #" .. _)
			function_table[tree.jelly_id] = self._jelly_place_small_tree
		else
			function_table[tree.jelly_id] = self._jelly_place_normal_tree
		end
		
		trees[tree.jelly_id] = tree
		
		for k, v in pairs(tree.terrain_types) do
			trees_by_terrain[v] = trees_by_terrain[v] or { fallback = {}, normal = {} }
			if tree.chance then
				table.insert(trees_by_terrain[v].normal, tree)
			else
				table.insert(trees_by_terrain[v].fallback, tree)
			end
		end
	end
	
	-- Sort all tables.
	local function sort_by_density(a, b) return a.threshold > b.threshold end
	table.sort(trees, sort_by_density)
	
	for k, v in pairs(trees_by_terrain) do
		table.sort(v.normal, sort_by_density)
		table.sort(v.fallback, sort_by_density)
	end
	
	self._trees = trees
	self._trees_by_terrain = trees_by_terrain
	
	self._function_table = function_table
end

local function accept_tree(tree, chance, terrain_type, step)
	local t = type(tree.chance)
	if t == 'function' then
		local eval_chance = tree.chance(terrain_type, step)
--~ 		log:spam('evaluated chance %s: %.2f > %.2f', tree.entity_ref, eval_chance, chance)
		return eval_chance > chance
	elseif t == 'number' then
		return tree.chance > chance
	else
		return true
	end
end

function Landscaper:_get_tree_object(elevation, value, terrain_type, step)
	-- Get the list of trees that are OK
	local terrain_trees = self._trees_by_terrain[terrain_type]
	
	if #terrain_trees.fallback > 0 then
		-- Get the chance for this tree.
		local chance = self._rng:get_real(0, 1)
		
		for _, tree in pairs(terrain_trees.normal) do
			if value >= tree.threshold and accept_tree(tree, chance, terrain_type, step) then
				return tree
			end
		end
	end
	
	if #terrain_trees.fallback > 0 then
		for _, tree in pairs(terrain_trees.fallback) do
			if value >= tree.threshold then
				return tree
			end
		end
	end
	
	return nil
end

-- Not necessary.
function Landscaper:_get_tree_size() end

-- get_tree_type already dealt with this.
--~ function Landscaper:_get_tree_name(tree_type, tree_size) return tree_type end
--[[ END JELLY CODE ]]--
return Landscaper
