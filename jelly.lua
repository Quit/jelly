local log = radiant.log.create_logger('jelly')

--! realm jelly
jelly = {}

local resources = {}
jelly.resources = resources
--~ setmetatable(resources, { __index = radiant.resources })

--! desc If `name` is a table, `name` is returned. If `name` is a string, it is tried to `radiant.resources.load_json`.
--! param string/table name The value that should be loaded (if necessary).
--! returns table The table that represents this value.
--! remarks This function is especially useful if you wish to load data from JSON, but wish that they might be `file()`'d instead of hardcoded in.
function resources.load_table(name)
	if type(name) == 'table' then
		return name
	elseif type(name) == 'string' then
		return resources.load_json(name)
	else
		error('bad argument #1 to jelly.resources.load_table: expected string or table, got ' .. type(name))
	end
end

local util = {}
jelly.util = util
--~ setmetatable(util, { __index = radiant.util })

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
--! param table tbl Table to be copied. If `tbl` is not a copy, it will simply be returned.
--! returns table Simple copy of tbl.
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
	log:spam('load %s', name)
	local class = elements[name]
	
	-- Make sure it's a table. Load if necessary. Create a copy.
	elements[name] = util.copy(resources.load_table(class))
	
	-- Avoid cycles.
	if loaded[name] == LOADING then
		log:error('already loaded %s -> cycle!', name)
		error('cyclic behaviour detected while loading ' .. name)
	-- Avoid duplicate loading.
	elseif loaded[name] == LOADED then
		return class
	end

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

local linq = {}
jelly.linq = linq

--! desc Maps `tbl` using `func`. Lazy evaluated.
--! param table tbl Table that should be mapped
--! param function func Function that receives two arguments (`key`, `value`) and returns the new element.
--! returns lua iterator
--! EXPERIMENTAL
function linq.map_pairs(tbl, func)
	local map_next = function(tbl, index)
		local k, v = next(tbl, index)
		
		if k == nil then
			return nil, nil
		end
		
		return k, func(k, v)
	end
	
	return map_next, tbl, nil	
end

--! desc Picks only certain elements from `tbl` by evaluating them using `func`
--! param table tbl Table that should be searched for
--! param function func Function that decides whether an element is taken or not
--! returns lua iterator
--! EXPERIMENTAL
function linq.where_pairs(tbl, func)
	local grep_next = function(tbl, k)
		local v
		repeat
			k, v = next(tbl, k)
		until not k or func(k, v)
		
		return k, v
	end
	
	return grep_next, tbl, nil
end

--! desc Maps `tbl` using `func`.
--! param table tbl Table that should be mapped
--! param function func Function that receives two arguments (`key`, `value`) and returns the new element.
--! returns table with mapped values
function util.map(tbl, func)
	local t = {}
	for k, v in linq.map_pairs(tbl, func) do
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
	for k, v in linq.where_pairs(tbl, func) do
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

return jelly