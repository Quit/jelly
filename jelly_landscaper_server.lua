local log = radiant.log.create_logger("landscaper")

require('jelly')

local MOD = class()

function MOD:__init()
--~ 	radiant.events.listen(radiant, 'radiant:modules_loaded', self, self._patch_all)
end

function MOD:_patch_all()
	radiant.mods.require('rp.rp_server')
	self:_patch('stonehearth.services.world_generation.landscaper', 'jelly.overrides.services.world_generation.landscaper')
end

	function MOD:_patch(original_path, patched_path)
		log:info('patch %s -> %s', original_path, patched_path)
		-- Require both files
		log:spam('require %s', original_path)
		local source = radiant.mods.require(original_path)
		
		-- Get the source mod
		local original_mod = original_path:match('^(.-%.)')
		
		local old_require = require
		
		function require(path)
			if path:sub(-4) == '.lua' then
				path = path:sub(1, -4)
			end
			
			log:spam('include %s (translated to %s%s)', path, original_mod, path)
			
			return radiant.mods.require(original_mod .. path)
		end
		
		log:spam('require %s', patched_path)
		local patch = radiant.mods.require(patched_path)
		
		require = old_require
			
		if not patch then
			log:error('cannot find patch target %s!', patched_path)
			return
		end
		
		log:spam('clear...')
		-- Clear source
		for k, v in pairs(source) do
			source[k] = nil
		end
		
		log:spam('copy...')
		-- Create the patch
		for k, v in pairs(patch) do
			source[k] = v
		end
		
		log:spam('set meta...')
		
		-- Set the metatable
		setmetatable(source, getmetatable(patch))
		
		PrintTable(source)
	end

return MOD()