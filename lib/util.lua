--[=============================================================================[
The MIT License (MIT)

Copyright (c) 2014 RepeatPan

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

--! realm jelly
local util = {}

-- Localise stuff.
local jelly, radiant = jelly, radiant
local table = table
local type, pairs, setmetatable, loadstring, next = type, pairs, setmetatable, loadstring, next

--! desc Attempts to "mixinto" `parents` into `child`.
--! param table child Table that should receive the parent's data.
--! param table parents A table that contains the values we should inherit.
--! remarks Numeric tables will be merged (i.e. the parent's values will be placed after the child ones,
--! remarks if any), other values will be hard-copied over. In the end, `child` can override any value
--! remarks that is set in any of the `parents`, except tables, which can only be added.
--! remarks
--! remarks Currently, this only works with "flat" classes, i.e. tables contained in child or parent are
--! remarks assumed to be numeric arrays that are to be merged.
--! EXPERIMENTAL
function util.mixinto(child, parents)
	-- Create the "inherited" table
	local t = {}
	
	-- For each parent...
	for _, parent in pairs(parents) do
		-- For each key in each parent...
		for k, v in pairs(parent) do
			-- If the key already exists as table and the new one's a table too, merge.
			if type(t[k]) == 'table' and type(v) == 'table' then
				for i = 1, #v do
					table.insert(t[k], v)
				end
			-- Otherwise, this parent overwrites the old one. But just to make sure, copy it.
			else
				t[k] = util.copy(v)
			end
		end
	end

	-- Now that we have our base, copy our child in.
	for k, v in pairs(child) do
		-- The child does not specify this key: Copy it from the parents.
		if type(v) == 'table' and type(t[k]) == 'table' then
			-- t[k] is already a copy.
			for i = 1, #v do
				table.insert(t[k], v)
			end
		else
			t[k] = util.copy(v)
		end -- otherwise the key already existed in the child, therefore was overwritten
	end
	
	return t
end

--! desc Creates a shallow copy of `tbl`.
--! param table tbl Table to be copied. If `tbl` is not a table it will simply be returned.
--! returns table Simple copy of `tbl`.
--! remarks This does **not** create a deep table. Tables inside of `tbl` will simply be referenced!
function util.copy(tbl)
	if type(tbl) ~= 'table' then
		return tbl
	end
	
	local t = {}
	for k,v in pairs(tbl) do
		t[k] = v
	end
	
	return t
end

-- LOADING is bad, nil is good, LOADED is better
local LOADING, LOADED = 0, 1

-- Loads elements[name] and makes sure to mixin parent_key stuff if encountered
local function load_class(elements, parent_key, loaded, name)
	local class = elements[name]
	
	-- Avoid cycles.
	if loaded[name] == LOADING then
		error('cyclic behaviour detected while loading class ' .. name)
	-- Avoid duplicate loading.
	elseif loaded[name] == LOADED then
		return class
	end

	-- Make sure it's a table. Load if necessary. Create a copy.
	elements[name] = util.copy(jelly.resources.load_table(class))
	
	-- mutex.
	loaded[name] = LOADING

	-- Get the parents, if any
	local parents = class[parent_key] or {}

	-- Strength through uniformity .
	if type(parents) ~= 'table' then
		parents = { parents }
	end
	
	local mixintos = {}
	
	-- Load all parents
	for k, parent_name in pairs(parents) do
		table.insert(mixintos, load_class(elements, parent_key, loaded, parent_name))
	end
	
	-- Merge magic.
	class = util.mixinto(class, mixintos)
	
	-- Loaded.
	loaded[name] = LOADED
	elements[name] = class
	
	return class
end

-- TODO: Refactor this into some sort of factory
local classes_cache = {}
local classes_loaded = {}

--! desc Attempts to load `name` as class. `name` is a defined alias (or file path) that defines the class.
--! param string name Name of the class to load. This has to be an alias.
--! param string parent_key Name that defines what the class' inheritance system is based on.
--! returns table containing the finished class
function util.load_class(name, parent_key)
	local class = classes_cache[name]
	
	if class then
		return class
	end
	
	class = load_class(util.json_table(), parent_key, classes_loaded, name)
	
	classes_cache[name] = class
	return class
end

--! desc Builds "classes" out of `elements`, using `parent_key` to determine inheritance/mixintos.
--! param table elements A hash table/object that contains the classes (`class_name => class_data`)
--! param string parent_key The key that determines which key in a class defines its parents/mixintos
--! returns table The modified `elements`.
--! remarks Internally, it's loading the parents using `jelly.resources.load_table` and the inheritance
--! remarks is dealt with by `jelly.util.mixinto`. This function modifies `elements`.
--! This can be used to create "classes" or other (named) mixintos.
--! EXPERIMENTAL
function util.build_classes(elements, parent_key)
	local loaded = {}
	
	elements = util.copy(elements)
	
	for class_name, _ in pairs(elements) do
		elements[class_name] = load_class(elements, parent_key, loaded, class_name)
	end
	
	return elements
end

local json_table = nil

--! desc Returns a table that, if accessed by key, tries to load the json identified by that name.
--! returns Magic table.
function util.json_table()
	if json_table then
		return json_table
	end
	
	json_table = setmetatable({}, { __index = function(tbl, key) local json = radiant.resources.load_json(key) tbl[key] = json return json end })
	
	return json_table
end

--! desc Requires `file`, which is a path to a lua file (without extension), relative to "/mods".
--! param string file Module to be required. Without file extensions. Slashes or periods (`.`) are acceptable.
--! returns value The file. Usually, this is a `table` or `class`, although it depends on the file.
--! remarks Since `radiant.mods.require`could be mis-interpreted as "load a mod" opposed to
--! remarks "load a file", this function does explicitly the latter.
function util.require(file)
	return _host:require(file)
end

--! desc Checks if `tbl` contains `value`.
--! param table tbl Table to check
--! param value value Value to find
--! returns true if the value is in tbl, false otherwise
function util.contains(tbl, value)
	for k, v in pairs(tbl) do
		if v == value then
			return true
		end
	end
	
	return false
end

--! desc Compiles `str` into a function, if any. `args` is a table of string which contains the function's passed arguments.
--! param string str Function's return value.
--! param table args Table containing the name of the passed arguments, as strings.
--! returns function if the compilation succeeded, false and the error message otherwise
--! remarks Because the "return" statement of the function is given, this may only be used for very simple calculations.
--! remarks Its real use is to have json defined short functions for attributes, chances or simple calculations.
function util.compile(str, args)
	if not str then
		return nil, "str is nil"
	end
	
	local argStr = table.concat(args, ',')
	return loadstring(string.format('local %s=... return %s', table.concat(args, ','), str))
end

--! desc Maps `tbl` using `func`.
--! param table tbl Table that should be mapped
--! param function func Function that receives two arguments (`key`, `value`) and returns the new element.
--! returns table with mapped values
function util.map(tbl, func)
	local t = {}
	for k, v in jelly.linq.map_pairs(tbl, func) do
		t[k] = v
	end
	
	return t
end

--! desc Greps `tbl` using `func`
--! param table tbl Table that should be grepped
--! param function func Function that receives two arguments: (`key`, `value`) and returns true if the element should be taken over, false otherwise
--! returns table with reduced entries
--! remarks **Note:** This function will **not** re-sort the table; i.e. the keys are consistent. This can lead to "holes".
function util.grep(tbl, func)
	local t = {}
	for k, v in jelly.linq.where_pairs(tbl, func) do
		t[k] = v
	end
	
	return t
end

--! desc re-sorts `tbl` to be a normal array without "holes" as keys.
--! param table tbl
--! returns re-arranged table
function util.to_list(tbl)
	local t = {}
	local tn = 1
	
	for k, v in pairs(tbl) do
		t[tn] = v
		tn = tn + 1
	end
	
	return t
end

--! desc Returns the best key/value in a table by calling `func` on each pair to evaluate it
--! param table tbl Table to maximize over
--! param function func Function to call
--! DEPRECATED This function is going to be replaced with LINQ.
function util.table_max(tbl, func)
	local k, v, m = next(tbl, nil)
	
	if not k then
		return nil, nil, nil
	end
	
	local best_k, best_v, best_m = k, v, func(k, v)
	
	repeat
		m = func(k, v)
		if m > best_m then
			best_k, best_v, best_m = k, v, m
		end
		
		k, v = next(tbl, k)
	until not k
	
	return best_k, best_v, best_m
end

-- List of things we consider "true" or "false" when dealing with configs.
local boolean_table = 
{
	[0] = false,
	["0"] = false,
	["false"] = false,
	["no"] = false,
	
	[1] = true,
	["1"] = true,
	["true"] =  true,
	["yes"] = true
}

local comfort_table

-- Returns `given` in a way it comforts `default`
local function comfort_values(given, default)
	local given_type, default_type = type(given), type(default)
	
	-- Not compatible?
	if given_type ~= default_type then
		-- Boxing?
		if default_type == 'table' then
			return comfort_table({ given }, default)
		-- tostring
		elseif default_type == 'string' then
			return tostring(given)
		-- numbering
		elseif default_type == 'number' and tonumber(given) then
			return tonumber(given)
		-- booleaning
		elseif default_type == 'boolean' and boolean_table[given] ~= nil then
			return boolean_table[given]
		-- default value
		else
			return default -- This will already be properly aligned
		end
	-- Otherwise, if both are tables, comfort them
	elseif default_type == 'table' then
		return comfort_table(given, default)
	end
	
	return given
end

-- compares if all values in `given` are comfortable to `default`
-- and returns json modified in a way that all values comfort default
-- (i.e. have the same type)
function comfort_table(given, default)
	for key, default_value in pairs(default) do
		local given_value = given[key]
		
		-- json does not define this value: We do it.
		if given_value == nil then
			given[key] = default_value
		else -- json does define this value, validate it
			given[key] = comfort_values(given_value, default_value)
		end
	end
	
	return given
end

--! desc Loads the config of the current mod
function util.load_config()
	local mod_name = __get_current_module_name(3)
	
	local manifest_loaded, manifest = pcall(radiant.resources.load_manifest, mod_name)
	
	if not manifest_loaded then
		error(string.format('cannot load manifest of %s: %s', mod_name, manifest))
	end
	
	if not manifest.jelly or not manifest.jelly.default_config then
		error(string.format('manifest of %s does not contain default config values', mod_name))
	end
	
	manifest = manifest.jelly.default_config
	
	-- Try to load the user settings
	local user_settings = _host:get_config('mods.' .. __get_current_module_name(3))
	
	-- Try to comfort the user_settings to json (which, by now, is our new default)
	if user_settings then
		manifest = comfort_table(user_settings, manifest)
	end
	
	return manifest, user_settings ~= nil
end

return util