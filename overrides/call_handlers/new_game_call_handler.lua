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

local MathFns = require("services.world_generation.math.math_fns")
local BlueprintGenerator = require("services.world_generation.blueprint_generator")
local game_master = require("services.game_master.game_master_service")
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
  wgs:initialize(seed, true)
  local generation_method = radiant.util.get_config("world_generation.method", "default")
  
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
  wgs.start_x = x
  wgs.start_z = z
  local radius = 2
  local blueprint = wgs:get_blueprint()
  local i, j = wgs:get_tile_index(x, z)
  local generation_method = radiant.util.get_config("world_generation.method", "default")
  
  if generation_method == "small" then
    radius = 1
  end
  
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
  local x = wgs.start_x
  local z = wgs.start_z
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
    camera_service._next_position = camera_location
    camera_service:set_position(camera_location)
    camera_service:look_at(target)
    _radiant.call("stonehearth:get_visibility_regions"):done(function(o)
      log:info("Visible region uri: %s", o.visible_region_uri)
      log:info("Explored region uri: %s", o.explored_region_uri)
      _radiant.renderer.visibility.set_visibility_regions(o.visible_region_uri, o.explored_region_uri)
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
  self._capture = _radiant.client.capture_input()
  self._capture:on_input(function(e)
    
    if e.type == _radiant.client.Input.MOUSE then
      return self:_on_mouse_event(e.mouse, response)
    elseif e.type == _radiant.client.Input.KEYBOARD then
      return self:_on_keyboard_event(e.keyboard, response)
    end
    
    return false
  end)
end

function NewGameCallHandler:_on_mouse_event(e, response)
  assert(self._capture, "got mouse event after releasing capture")
  local s = _radiant.client.query_scene(e.x, e.y)
  local pt = s.location and s.location or Point3(0, -100000, 0)
  pt.y = pt.y + 1
  self._cursor_entity:add_component("mob"):set_location_grid_aligned(pt)
  
  if e:up(1) and s.location then
    self._capture:destroy()
    self._capture = nil
    _radiant.call("stonehearth:create_camp", pt):always(function()
      _radiant.client.destroy_authoring_entity(self._cursor_entity:get_id())
      response:resolve({result = true})
    end)
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
  self._capture:destroy()
  self._capture = nil
end

function NewGameCallHandler:create_camp(session, response, pt)
  stonehearth.scenario:clear_starting_location(pt.x, pt.z)
	--[[ BEGIN JELLY ]]--
	-- Load the entities
	local json = radiant.resources.load_json('jelly:index:camp_start')
	local factionName = json.faction.name
	
  local faction = stonehearth.population:get_faction(factionName, json.faction.kingdom)
  local town = stonehearth.town:get_town(session.faction)
  local location = Point3(pt.x, pt.y, pt.z)
  local banner_entity = radiant.entities.create_entity(json.banner_entity)
  radiant.terrain.place_entity(banner_entity, location)
  town:set_banner(banner_entity)
  local camp_x = pt.x
  local camp_z = pt.z
	for _, workerDef in pairs(json.citizens) do
		local worker = self:place_citizen(camp_x + workerDef.x, camp_z + workerDef.z)
		radiant.events.trigger(personality_service, "stonehearth:journal_event", {
			entity = worker,
			description = "person_embarks"
		})
		
		if workerDef.item then
			radiant.entities.pickup_item(worker, faction:create_entity(workerDef.item))
		end
	end
	
	for _, entityDef in pairs(json.entities) do
		self:place_item(entityDef.entity_ref, camp_x + entityDef.x, camp_z + entityDef.z, factionName)
	end
	--[[ END JELLY ]]--
  return {}
end

function NewGameCallHandler:place_citizen(x, z, profession)
  local faction = stonehearth.population:get_faction("civ", "stonehearth:factions:ascendancy")
  local citizen = faction:create_new_citizen()
  profession = profession or "worker"
  faction:promote_citizen(citizen, profession)
  radiant.terrain.place_entity(citizen, Point3(x, 1, z))
  return citizen
end

function NewGameCallHandler:place_item(uri, x, z, faction)
  local entity = radiant.entities.create_entity(uri)
  radiant.terrain.place_entity(entity, Point3(x, 1, z))
  
  if faction then
    entity:add_component("unit_info"):set_faction(faction)
  end
  
  return entity
end

function NewGameCallHandler:place_stockpile(faction, x, z, w, h)
  if not w or not w then
    w = 3
  end
  
  if not h or not h then
    h = 3
  end
  
  local location = Point3(x, 1, z)
  local size = {w, h}
  local inventory = stonehearth.inventory:get_inventory(faction)
  inventory:create_stockpile(location, size)
end

return NewGameCallHandler
