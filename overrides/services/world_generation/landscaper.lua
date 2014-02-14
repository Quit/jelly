local TerrainType = require("services.world_generation.terrain_type")
local TerrainInfo = require("services.world_generation.terrain_info")
local Array2D = require("services.world_generation.array_2D")
local MathFns = require("services.world_generation.math.math_fns")
local FilterFns = require("services.world_generation.filter.filter_fns")
local PerturbationGrid = require("services.world_generation.perturbation_grid")
local log = radiant.log.create_logger("world_generation")
local Terrain = _radiant.om.Terrain
local Point3 = _radiant.csg.Point3
local Cube3 = _radiant.csg.Cube3
local ConstructCube3 = _radiant.csg.ConstructCube3
local Region3 = _radiant.csg.Region3
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
local rabbit_name = mod_prefix .. "rabbit"
local generic_vegetaion_name = "vegetation"
local boulder_name = "boulder"

--[[ JELLY START ]]--
local generic_vegetation_name = generic_vegetaion_name
local jelly = radiant.mods.require('jelly.jelly')
--[[ JELLY END ]]--

local Landscaper = class()

function Landscaper:__init(terrain_info, tile_width, tile_height, rng, async)
  if async == nil then
    async = false
  end
  self._terrain_info = terrain_info
  self._tile_width = tile_width
  self._tile_height = tile_height
  self._rng = rng
  self._async = async
  local grid_spacing = 16
  self._feature_cell_size = grid_spacing
  self._perturbation_grid = PerturbationGrid(tile_width, tile_height, grid_spacing, self._rng)
  local feature_map_width, feature_map_height = self._perturbation_grid:get_dimensions()
  self._feature_map = Array2D(feature_map_width, feature_map_height)
  self._noise_map_buffer = Array2D(self._feature_map.width, self._feature_map.height)
  self._density_map_buffer = Array2D(self._feature_map.width, self._feature_map.height)
	
	self:_load_trees()
end

function Landscaper:clear_feature_map()
  self._feature_map:clear(nil)
end

function Landscaper:get_feature_map()
  return self._feature_map:clone()
end

function Landscaper:get_feature_cell_size()
  return self._feature_cell_size
end

function Landscaper:is_forest_feature(feature_name)
  if feature_name == nil then
    return false
  end
  if is_tree_name(feature_name) then
    return true
  end
  if feature_name == generic_vegetaion_name then
    return true
  end
  return false
end

function Landscaper:place_flora(tile_map, tile_offset_x, tile_offset_y)
  assert(tile_map.width == self._tile_width and tile_map.height == self._tile_height)
  if tile_offset_x == nil then
    tile_offset_x = 0
  end
  if tile_offset_y == nil then
    tile_offset_y = 0
  end
  local function place_item(uri, x, y)
    local entity = radiant.entities.create_entity(uri)
    radiant.terrain.place_entity(entity, Point3(x - 1 + tile_offset_x, 1, y - 1 + tile_offset_y))
    self:_set_random_facing(entity)
    return entity
  end
  self:_place_trees(tile_map, place_item)
  self:_yield()
  self:_place_berry_bushes(tile_map, place_item)
  self:_yield()
  self:_place_flowers(tile_map, place_item)
  self:_yield()
end

function Landscaper:_place_trees(tile_map, place_item)
  local rng = self._rng
  local terrain_info = self._terrain_info
  local feature_map = self._feature_map
  local perturbation_grid = self._perturbation_grid
  local large_tree_threshold = 25
  local medium_tree_threshold = 6
  local small_tree_threshold = 0
  local max_trunk_radius = 3
  local ground_radius = 2
  local normal_tree_density = 0.8
  local small_tree_density = 0.5
  local noise_map = self._noise_map_buffer
  local density_map = self._density_map_buffer
  local i, j, x, y, tree_type, tree_name, occupied, value, elevation, terrain_type
	
  local function noise_fn(i, j)
    local mean = 0
    local std_dev = 100
    if noise_map:is_boundary(i, j) then
      mean = mean - 20
    end
    local x, y = perturbation_grid:get_unperturbed_coordinates(i, j)
    local elevation = tile_map:get(x, y)
    local terrain_type = terrain_info:get_terrain_type(elevation)
    if terrain_type == TerrainType.mountains then
      std_dev = std_dev * 0.3
    elseif terrain_type == TerrainType.plains then
      do
        local plains_info = self._terrain_info[TerrainType.plains]
        if elevation == plains_info.max_height then
          mean = mean - 5
        else
          mean = mean - 75
        end
      end
    else
      local foothills_info = self._terrain_info[TerrainType.foothills]
      if elevation == foothills_info.max_height then
        mean = mean + 30
        std_dev = std_dev * 0.3
      else
        mean = mean + 5
        std_dev = std_dev * 0.3
      end
    end
    return rng:get_gaussian(mean, std_dev)
  end
	
  noise_map:fill_ij(noise_fn)
  FilterFns.filter_2D_0125(density_map, noise_map, noise_map.width, noise_map.height, 10)
	
	-- density_map is a map of "vegetation density", based on elevation, or rather biome
  for j = 1, density_map.height do
    for i = 1, density_map.width do
			-- Density of this tree tile
      value = density_map:get(i, j)
			
			--[[ START JELLY CODE ]]--
			
			-- Are we occupied?
			occupied = feature_map:get(i, j)

			local USE_JELLY = true
			
			if USE_JELLY and not occupied then
				x, y = perturbation_grid:get_perturbed_coordinates(i, j, max_trunk_radius)
				
				-- Check for flatness
				if self:_is_flat(tile_map, x, y, ground_radius) then
					elevation = tile_map:get(x, y)
					
					-- Get the terrain
					terrain_type = terrain_info:get_terrain_type(elevation)
					
					local terrain = terrain_info[terrain_type]
					
					-- Place the tree. Kinda ugly right now, but I'd rather have this as dedicated function.
					self:_place_tree(place_item, i, j, value, elevation, terrain_type, terrain, perturbation_grid, feature_map, tile_map, x, y)
				end
			end
			--[[ END JELLY CODE ]]--
			
			-- If we have space for at least a small tree
      if not USE_JELLY and small_tree_threshold <= value then
        occupied = feature_map:get(i, j) ~= nil
				
				-- If there's nothing there yet (boulder, flowers, etc.)
        if not occupied then
          x, y = perturbation_grid:get_perturbed_coordinates(i, j, max_trunk_radius)
					
					-- Flat...ness... check?
          if self:_is_flat(tile_map, x, y, ground_radius) then
						-- Get the elevation
            elevation = tile_map:get(x, y)
						-- Get the tree type based on elevation
						-- START OUR STUFF
            tree_type = self:_get_tree_type(elevation)
						
						-- If we are to place a tree here
            if tree_type ~= nil then
							-- Get... the better terrain type?
              terrain_type = self._terrain_info:get_terrain_type(elevation)
							
							-- Space for a big tree?
              if large_tree_threshold <= value then
                tree_name = get_tree_name(tree_type, large)
							-- Space for a medium tree?
              elseif medium_tree_threshold <= value then
                tree_name = get_tree_name(tree_type, medium)
							-- Space for a small tree? This was the requirement before, therefore else and not elsif
              else
                tree_name = get_tree_name(tree_type, small)
              end
							
							-- more space than a medium tree *or* mountains (wat)?
              if medium_tree_threshold <= value or terrain_type == TerrainType.mountains then
								-- 0.8 > [0, 1]? => 20% chance that a tree is spawned
                if normal_tree_density > rng:get_real(0, 1) then
                  place_item(tree_name, x, y)
                  feature_map:set(i, j, tree_name)
								-- 80% chance of normal vegetation
                else
                  feature_map:set(i, j, generic_vegetaion_name)
                end
							
							-- medium_tree > value && !mountains
							-- If there's only space for a small tree and we're not in the mountains
              else
                local w, h, factor, nested_grid_spacing, exclusion_radius, placed
                x, y, w, h = perturbation_grid:get_cell_bounds(i, j)
								
                factor = 0.5
                exclusion_radius = 2
                nested_grid_spacing = math.floor(perturbation_grid.grid_spacing * factor)
                
								local function try_place_item(x, y)
                  place_item(tree_name, x, y)
                  return true
                end
								
								-- function Landscaper:_place_dense_items(tile_map, cell_origin_x, cell_origin_y, cell_width, cell_height, grid_spacing, exclusion_radius, probability, try_place_item)
								-- Places... tons of... trees?
                placed = self:_place_dense_items(tile_map, x, y, w, h, nested_grid_spacing, exclusion_radius, small_tree_density, try_place_item)
                
								if placed then
                  feature_map:set(i, j, tree_name)
                else
                  feature_map:set(i, j, generic_vegetaion_name)
                end
              end
            end
          end
        end
      end -- end threshold check
    end
  end
end

function Landscaper:_place_berry_bushes(tile_map, place_item)
  local rng = self._rng
  local terrain_info = self._terrain_info
  local feature_map = self._feature_map
  local perturbation_grid = self._perturbation_grid
  local noise_map = self._noise_map_buffer
  local density_map = self._density_map_buffer
  local item_spacing = math.floor(perturbation_grid.grid_spacing * 0.33)
  local item_density = 0.9
  local i, j, x, y, w, h, rows, columns, occupied, value, placed
  local function try_place_item(x, y)
    local elevation = tile_map:get(x, y)
    local terrain_type = terrain_info:get_terrain_type(elevation)
    if terrain_type == TerrainType.mountains then
      return false
    end
    place_item(berry_bush_name, x, y)
    return true
  end
  local function noise_fn(i, j)
    local mean = -45
    local std_dev = 30
    local feature = feature_map:get(i, j)
    if is_tree_name(feature) then
      mean = mean + 100
    end
    local x, y = perturbation_grid:get_unperturbed_coordinates(i, j)
    local elevation = tile_map:get(x, y)
    local terrain_type = terrain_info:get_terrain_type(elevation)
    if terrain_type == TerrainType.foothills then
      local foothills_info = terrain_info[TerrainType.foothills]
      if elevation == foothills_info.max_height then
        mean = mean + 50
      end
    end
    return rng:get_gaussian(mean, std_dev)
  end
  noise_map:fill_ij(noise_fn)
  FilterFns.filter_2D_050(density_map, noise_map, noise_map.width, noise_map.height, 6)
  for j = 1, density_map.height do
    for i = 1, density_map.width do
      value = density_map:get(i, j)
      if value > 0 then
        occupied = self._feature_map:get(i, j) ~= nil
        if not occupied then
          x, y, w, h = perturbation_grid:get_cell_bounds(i, j)
          rows, columns = self:_random_berry_pattern()
          placed = self:_place_pattern(tile_map, x, y, w, h, rows, columns, item_spacing, item_density, 1, try_place_item)
          if placed then
            self._feature_map:set(i, j, berry_bush_name)
          end
        end
      end
    end
  end
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

function Landscaper:_place_flowers(tile_map, place_item)
  local rng = self._rng
  local terrain_info = self._terrain_info
  local feature_map = self._feature_map
  local perturbation_grid = self._perturbation_grid
  local grid_spacing = perturbation_grid.grid_spacing
  local exclusion_radius = 1
  local ground_radius = 1
  local noise_map = self._noise_map_buffer
  local density_map = self._density_map_buffer
  local i, j, x, y, occupied, value, elevation, terrain_type
  local function noise_fn(i, j)
    local mean = 0
    local std_dev = 100
    if noise_map:is_boundary(i, j) then
      mean = mean - 50
    end
    local feature = feature_map:get(i, j)
    if is_tree_name(feature) then
      mean = mean - 50
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
          x, y = perturbation_grid:get_perturbed_coordinates(i, j, exclusion_radius)
          if self:_is_flat(tile_map, x, y, ground_radius) then
            elevation = tile_map:get(x, y)
            terrain_type = terrain_info:get_terrain_type(elevation)
            if terrain_type == TerrainType.plains then
              place_item(pink_flower_name, x, y)
              feature_map:set(i, j, pink_flower_name)
            end
          end
        end
      end
    end
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

function Landscaper:_get_tree_type(elevation)
  local rng = self._rng
  local mountains_juniper_chance = 0.25
  local high_foothills_juniper_chance = 0.8
  local low_foothills_juniper_chance = 0.2
  local terrain_info = self._terrain_info
  local terrain_type = terrain_info:get_terrain_type(elevation)
  if terrain_type == TerrainType.plains then
    return oak
  end
  if terrain_type == TerrainType.mountains then
    if mountains_juniper_chance > rng:get_real(0, 1) then
      return juniper
    else
      return nil
    end
  end
  local foothills_info = terrain_info[TerrainType.foothills]
  if elevation >= foothills_info.max_height then
    if high_foothills_juniper_chance > rng:get_real(0, 1) then
      return juniper
    else
      return oak
    end
  end
  if elevation >= foothills_info.max_height - foothills_info.step_size then
    if low_foothills_juniper_chance > rng:get_real(0, 1) then
      return juniper
    else
      return oak
    end
  end
end

function Landscaper:random_tree_type()
  local roll = self._rng:get_int(1, #tree_types)
  return tree_types[roll]
end

function Landscaper:_set_random_facing(entity)
  entity:add_component("mob"):turn_to(90 * self._rng:get_int(0, 3))
end

function get_tree_name(tree_type, tree_size)
  return mod_prefix .. tree_size .. "_" .. tree_type
end

function is_tree_name(feature_name)
  if feature_name == nil then
    return false
  end
  local index = feature_name:find("_tree", -5)
  return index ~= nil
end

function Landscaper:place_boulders(region3_boxed, tile_map)
  local boulder_region
  local exclusion_radius = 8
  local grid_width, grid_height = self._perturbation_grid:get_dimensions()
  local elevation, i, j, x, y
  region3_boxed:modify(function(region3)
    for j = 2, grid_height - 1 do
      for i = 2, grid_width - 1 do
        x, y = self._perturbation_grid:get_perturbed_coordinates(i, j, exclusion_radius)
        elevation = tile_map:get(x, y)
        if self:_should_place_boulder(elevation) then
          boulder_region = self:_create_boulder(x, y, elevation)
          region3:add_region(boulder_region)
          self._feature_map:set(i, j, boulder_name)
        end
      end
    end
  end)
  self:_yield()
end

function Landscaper:_should_place_boulder(elevation)
  local rng = self._rng
  local terrain_type = self._terrain_info:get_terrain_type(elevation)
  local mountain_boulder_probability = 0.02
  local foothills_boulder_probability = 0.02
  local plains_boulder_probability = 0.02
  if terrain_type == TerrainType.mountains then
    return mountain_boulder_probability >= rng:get_real(0, 1)
  end
  if terrain_type == TerrainType.foothills then
    return foothills_boulder_probability >= rng:get_real(0, 1)
  end
  if terrain_type == TerrainType.plains then
    return plains_boulder_probability >= rng:get_real(0, 1)
  end
  return false
end

function Landscaper:_create_boulder(x, y, elevation)
  local terrain_info = self._terrain_info
  local terrain_type = terrain_info:get_terrain_type(elevation)
  local step_size = terrain_info[terrain_type].step_size
  local boulder_region = Region3()
  local boulder_center = Point3(x, elevation, y)
  local i, j, half_width, half_length, half_height, boulder, chunk
  half_width, half_length, half_height = self:_get_boulder_dimensions(terrain_type)
  boulder = Cube3(Point3(x - half_width, elevation - 2, y - half_length), Point3(x + half_width, elevation + half_height, y + half_length), Terrain.BOULDER)
  boulder_region:add_cube(boulder)
  local avg_length = MathFns.round((2 * half_width + 2 * half_length) * 0.5)
  if avg_length >= 6 then
    local chip_size = MathFns.round(avg_length * 0.15)
    local chip
    for j = -1, 1, 2 do
      for i = -1, 1, 2 do
        chip = self:_get_boulder_chip(i, j, chip_size, boulder_center, half_width, half_height, half_length)
        boulder_region:subtract_cube(chip)
      end
    end
  end
  chunk = self:_get_boulder_chunk(boulder_center, half_width, half_height, half_length)
  boulder_region:subtract_cube(chunk)
  return boulder_region
end

function Landscaper:_get_boulder_dimensions(terrain_type)
  local rng = self._rng
  local half_length, half_width, half_height, aspect_ratio
  if terrain_type == TerrainType.mountains then
    half_width = rng:get_int(4, 9)
  elseif terrain_type == TerrainType.foothills then
    half_width = rng:get_int(3, 6)
  elseif terrain_type == TerrainType.plains then
    half_width = rng:get_int(1, 3)
  else
    return nil, nil, nil
  end
  half_height = half_width + 1
  half_length = half_width
  aspect_ratio = rng:get_gaussian(1, 0.15)
  if rng:get_real(0, 1) <= 0.5 then
    half_width = MathFns.round(half_width * aspect_ratio)
  else
    half_length = MathFns.round(half_length * aspect_ratio)
  end
  return half_width, half_length, half_height
end

function Landscaper:_get_boulder_chip(sign_x, sign_y, chip_size, boulder_center, half_width, half_height, half_length)
  local corner1 = boulder_center + Point3(sign_x * half_width, half_height, sign_y * half_length)
  local corner2 = corner1 + Point3(-sign_x * chip_size, -chip_size, -sign_y * chip_size)
  return ConstructCube3(corner1, corner2, 0)
end

function Landscaper:_get_boulder_chunk(boulder_center, half_width, half_height, half_length)
  local rng = self._rng
  local sign_x = rng:get_int(0, 1) * 2 - 1
  local sign_y = rng:get_int(0, 1) * 2 - 1
  local corner1 = boulder_center + Point3(sign_x * half_width, half_height, sign_y * half_length)
  local chunk_length_percent = rng:get_int(1, 2) * 0.25
  local chunk_depth = math.floor(half_height * 0.5)
  local chunk_size, corner2
  if 0.5 >= rng:get_real(0, 1) then
    chunk_size = math.floor(2 * half_width * chunk_length_percent)
    if chunk_size == 0 then
      chunk_size = 1
    end
    corner2 = corner1 + Point3(-sign_x * chunk_size, -chunk_depth, -sign_y * chunk_depth)
  else
    chunk_size = math.floor(2 * half_length * chunk_length_percent)
    if chunk_size == 0 then
      chunk_size = 1
    end
    corner2 = corner1 + Point3(-sign_x * chunk_depth, -chunk_depth, -sign_y * chunk_size)
  end
  return ConstructCube3(corner1, corner2, 0)
end

function Landscaper:_yield()
  if self._async then
    coroutine.yield()
  end
end


--[[ START JELLY CODE ]]--
function Landscaper:_load_trees()
	-- Load the templates
	local templates = jelly.util.build_classes(radiant.resources.load_json('jelly:index:tree_templates').tree_templates)
	
	-- Load the index
	local json = radiant.resources.load_json('jelly:index:trees')

	local trees = {}
	local trees_by_terrain = {}
	
	-- Build the trees.
	for _, tree in pairs(json.trees) do
		-- Map the parents, if any
		local parents = jelly.util.map(tree.template or {}, function(_, k) return templates[k] end)
		
		tree = jelly.util.mixinto(tree, parents)
		
		-- Do we need to evaluate chance?
		if type(tree.chance) == 'string' then
			tree.chance = loadstring('function(elevation, terrain) return ' .. tree.chance .. ' end')
		end
		
		if tree.cluster then
			assert(tree.cluster_exclusion_radius, "cluster_exclusion_radius missing for #" .. _)
			assert(tree.cluster_factor, "cluster_factor missing for #" .. _)
			assert(tree.cluster_density, "cluster_density missing for #" .. _)
		end
		
		table.insert(trees, tree)
		
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
	local function sort_by_density(a, b) return a.threshold < b.threshold end
	table.sort(trees, sort_by_density)
	
	for k, v in pairs(trees_by_terrain) do
		table.sort(v, sort_by_density)
	end
	
	self._trees = trees
	self._trees_by_terrain = trees_by_terrain
	
	log:spam(table.show(self._trees_by_terrain))
end

local function accept_tree(tree, chance, elevation, terrain)
	local t = type(tree.chance)
	if t == 'function' then
		return tree.chance(elevation, terrain) > chance
	elseif t == 'number' then
		return tree.chance > chance
	else
		return true
	end
end

function Landscaper:_place_tree(place_item, i, j, value, elevation, terrain_type, terrain_info, perturbation_grid, feature_map, tile_map, x, y)
	-- Get the list of trees that are OK
	local best_tree = nil
	
	local terrain_trees = self._trees_by_terrain[terrain_type]
	
	if #terrain_trees.fallback > 0 then
		-- Get the chance for this tree.
		local chance = self._rng:get_real(0, 1)
		
		for _, tree in pairs(terrain_trees.normal) do
			if value >= tree.threshold and accept_tree(tree, chance, elevation, terrain_info) and (not best_tree or best_tree.threshold < tree.threshold) then
				best_tree = tree
				break
			end
		end
	end
	
	if not best_tree and #terrain_trees.fallback > 0 then
		for _, tree in pairs(terrain_trees.fallback) do
			if value >= tree.threshold and (not best_tree or best_tree.threshold < tree.threshold) then
				best_tree = tree
				break
			end
		end
	end
	
	if not best_tree then
		return
	end
	
	-- Pick a random one
	local tree = best_tree

	-- Does this tree define vegetation *and* is said vegetation winning?
	if tree.vegetation_chance then
		if self._rng:get_real(0, 1) < tree.vegetation_chance then
			feature_map:set(i, j, generic_vegetation_name)
			return
		end
	end
	
	-- Cluster?
	if tree.cluster then
		local x, y, w, h, factor, nested_grid_spacing, exclusion_radius, placed
		x, y, w, h = perturbation_grid:get_cell_bounds(i, j)
		
		local factor = tree.cluster_factor
		local exclusion_radius = tree.cluster_exclusion_radius
		local nested_grid_spacing = math.floor(perturbation_grid.grid_spacing * factor)
		
		local function try_place_item(x, y)
			place_item(tree.entity_ref, x, y)
			return true
		end
		
		-- Places... tons of... trees?
		placed = self:_place_dense_items(tile_map, x, y, w, h, nested_grid_spacing, exclusion_radius, tree.cluster_density, try_place_item)
		
		if placed then
			feature_map:set(i, j, tree.ref)
		else
			feature_map:set(i, j, generic_vegetation_name)
		end
	-- No cluster.
	else
		-- TODO: Have biomes add into this chance.
		place_item(tree.entity_ref, x, y)
		feature_map:set(i, j, tree.entity_ref)
	end
end

--[[ END JELLY CODE ]]--
return Landscaper
