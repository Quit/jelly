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

--[[--
	This is an overriden Stonehearth file. Parts that were changed, added or removed
	by Jelly have been marked with "START JELLY" and "END JELLY" blocks.
	Everything outside of these Jelly blocks is assumed to have been decompiled from
	the original game files and its copyright belongs entirely to Radiant Entertainment.
--]]--

local MathFns = require("services.server.world_generation.math.math_fns")
local BlueprintGenerator = require("services.server.world_generation.blueprint_generator")
local personality_service = stonehearth.personality
local Point2 = _radiant.csg.Point2
local Point3 = _radiant.csg.Point3
local Point3f = _radiant.csg.Point3f
local Rect2 = _radiant.csg.Rect2
local Region2 = _radiant.csg.Region2
local log = radiant.log.create_logger("world_generation")
local NewGameCallHandler = class()

function NewGameCallHandler:new_game(session, response, num_tiles_x, num_tiles_y, seed)
  local wgs = stonehearth.world_generation
  local blueprint
	local town = stonehearth.town:get_town(session.player_id)
  
  if not town then
    stonehearth.town:add_town(session)
    stonehearth.inventory:add_inventory(session)
    stonehearth.population:add_population(session)
  end
  
  wgs:create_new_game(seed, true)
	--[[ BEGIN JELLY ]]--
	local generation_method = _host:get_config("mods.stonehearth.world_generation.method") or "default"
	--[[ END JELLY ]]--
	
  if generation_method == "tiny" then
    blueprint = wgs.blueprint_generator:get_empty_blueprint(2, 2)
  else
    blueprint = wgs.blueprint_generator:generate_blueprint(num_tiles_x, num_tiles_y, seed)
  end
  
  wgs:set_blueprint(blueprint)
  return NewGameCallHandler:get_overview_map(session, response)
end

function NewGameCallHandler:get_overview_map(session, response)
  local wgs = stonehearth.world_generation
  local width, height = wgs.overview_map:get_dimensions()
  local map = wgs.overview_map:get_map():clone_to_nested_arrays()
  local result = {
    width = width,
    height = height,
    map = map
  }
  
  return result
end

function NewGameCallHandler:generate_start_location(session, response, feature_cell_x, feature_cell_y)
  feature_cell_x = feature_cell_x + 1
  feature_cell_y = feature_cell_y + 1
  local wgs = stonehearth.world_generation
  local x, z = wgs.overview_map:get_coords_of_cell_center(feature_cell_x, feature_cell_y)
	wgs.generation_location = Point3(x, 0, z)
  local radius = 2
  local blueprint = wgs:get_blueprint()
  local i, j = wgs:get_tile_index(x, z)
	--[[ BEGIN JELLY ]]--
  local generation_method = _host:get_config("mods.stonehearth.world_generation.method") or "default"
  
	-- We assume that "tiny" should do both... otherwise you could have just one or another, err?
  if generation_method == "small" or generation_method == "tiny" then
    radius = 1
  end
  --[[ END JELLY ]]--
	
  if blueprint.width > 2 * radius + 1 then
    i = MathFns.bound(i, 1 + radius, blueprint.width - radius)
  end
  
  if blueprint.height > 2 * radius + 1 then
    j = MathFns.bound(j, 1 + radius, blueprint.height - radius)
  end
  
  wgs:generate_tiles(i, j, radius)
  response:resolve({})
end

function NewGameCallHandler:embark_server(session, response)
  local scenario_service = stonehearth.scenario
  local wgs = stonehearth.world_generation
  local x = wgs.generation_location.x
  local z = wgs.generation_location.z
  local y = radiant.terrain.get_height(Point2(x, z))
  return {
    x = x,
    y = y,
    z = z
  }
end

function NewGameCallHandler:embark_client(session, response)
  _radiant.call("stonehearth:embark_server"):done(function(o)
    local camera_height = 30
    local target_distance = 70
    local camera_service = stonehearth.camera
    local target = Point3f(o.x, o.y, o.z)
    local camera_location = Point3f(o.x, o.y + camera_height, o.z + target_distance)
		camera_service:set_position(camera_location, true)
    camera_service:look_at(target)
    _radiant.call("stonehearth:get_visibility_regions"):done(function(o)
      log:info("Visible region uri: %s", o.visible_region_uri)
      log:info("Explored region uri: %s", o.explored_region_uri)
      stonehearth.renderer:set_visibility_regions(o.visible_region_uri, o.explored_region_uri)
      response:resolve({})
    end)
  end)
end

function NewGameCallHandler:choose_camp_location(session, response)
	--[[ BEGIN JELLY ]]--
	local json = radiant.resources.load_json('jelly:index:camp_start')
  self._cursor_entity = radiant.entities.create_entity(json.banner_entity)
	--[[ END JELLY ]]
  local re = _radiant.client.create_render_entity(1, self._cursor_entity)
  self._input_capture = stonehearth.input:capture_input():on_mouse_event(function(e)
    return self:_on_mouse_event(e, response)
  end):on_keyboard_event(function(e)
    return self:_on_keyboard_event(e, response)
  end)
end

function NewGameCallHandler:_on_mouse_event(e, response)
  assert(self._input_capture, "got mouse event after releasing capture")
  local s = _radiant.client.query_scene(e.x, e.y)
  local pt = s:is_valid() and s:brick_of(0) or Point3(0, -100000, 0)
  pt.y = pt.y + 1
  self._cursor_entity:add_component("mob"):set_location_grid_aligned(pt)
  
  if e:up(1) and s:is_valid() then
    self:_destroy_capture()
    do
      local default_camp_name = "Defaultville"
      _radiant.call("stonehearth:create_camp", pt):done(function(o)
        default_camp_name = o.random_town_name
      end):always(function()
        _radiant.client.destroy_authoring_entity(self._cursor_entity:get_id())
        response:resolve({result = true, townName = default_camp_name})
      end)
    end
  end
  
  return true
end

function NewGameCallHandler:_on_keyboard_event(e, response)
  if e.key == _radiant.client.KeyboardInput.KEY_ESC and e.down then
    self:_destroy_capture()
    _radiant.client.destroy_authoring_entity(self._cursor_entity:get_id())
    response:resolve({result = false})
  end
  
  return true
end

function NewGameCallHandler:_destroy_capture()
  if self._input_capture then
    self._input_capture:destroy()
    self._input_capture = nil
  end
end

function NewGameCallHandler:create_camp(session, response, pt)
	stonehearth.world_generation:set_starting_location(Point2(pt.x, pt.z))
	local town = stonehearth.town:get_town(session.player_id)
	local pop = stonehearth.population:get_population(session.player_id)
	local random_town_name = town:get_town_name()
	--[[ BEGIN JELLY ]]--
	-- Load the entities
	local json = radiant.resources.load_json('jelly:index:camp_start')
	
  local location = Point3(pt.x, pt.y, pt.z)
  local banner_entity = radiant.entities.create_entity(json.banner_entity)
  radiant.terrain.place_entity(banner_entity, location)
  town:set_banner(banner_entity)
  local camp_x = pt.x
  local camp_z = pt.z
	
	local function place_citizen_embark(x, z)
		local citizen = self:place_citizen(pop, x, z)
		radiant.events.trigger_async(personality_service, 'stonehearth:journal_event', {
			entity = citizen,
			description = "person_embarks"
		})
		
		return citizen
	end
	
	for _, workerDef in pairs(json.citizens) do
		local worker = place_citizen_embark(camp_x + workerDef.x, camp_z + workerDef.z)

		if workerDef.item then
			radiant.entities.pickup_item(worker, pop:create_entity(workerDef.item))
		end
	end
	
	for _, entityDef in pairs(json.entities) do
		self:place_item(pop, entityDef.entity_ref, camp_x + entityDef.x, camp_z + entityDef.z)
	end
	--[[ END JELLY ]]--
  
	return { random_town_name = random_town_name }
end

function NewGameCallHandler:place_citizen(pop, x, z, profession)
  local citizen = pop:create_new_citizen()
  profession = profession or "stonehearth:professions:worker"
  pop:promote_citizen(citizen, profession)
  radiant.terrain.place_entity(citizen, Point3(x, 1, z))
  return citizen
end

function NewGameCallHandler:place_item(pop, uri, x, z)
  local entity = radiant.entities.create_entity(uri)
  radiant.terrain.place_entity(entity, Point3(x, 1, z))
  local unit_info = entity:add_component('unit_info')
	unit_info:set_faction(pop:get_faction())
	unit_info:set_player_id(pop:get_player_id())
  return entity
end

function NewGameCallHandler:get_town_name(session, response)
  local town = stonehearth.town:get_town(session.player_id)
  
  if town then
    return {
      townName = town:get_town_name()
    }
  
  else
    return {
      townName = "Defaultville"
    }
  end
end

function NewGameCallHandler:set_town_name(session, response, town_name)
  local town = stonehearth.town:get_town(session.player_id)
  town:set_town_name(town_name)
  return true
end

return NewGameCallHandler