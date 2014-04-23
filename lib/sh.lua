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

--! realm jelly
local sh = {}

--! desc Requires a file from within Stonehearth. For the lazy.
--! param string path Path to the file inside stonehearth/. No file extension.
--! returns Whatever the loaded file returns - usually a class or an object.
function sh.require(path)
	return radiant.mods.require('stonehearth.' .. path)
end

-- Define a list of classes we might want to use, including name.
local classes = 
{
	TerrainType = "services.server.world_generation.terrain_type",
	TerrainInfo = "services.server.world_generation.terrain_info",
	Array2D = "services.server.world_generation.array_2D",
	MathFns = "services.server.world_generation.math.math_fns",
	FilterFns = "services.server.world_generation.filter.filter_fns",
	PerturbationGrid = "services.server.world_generation.perturbation_grid",
	BoulderGenerator = "services.server.world_generation.boulder_generator"
}

for k, v in pairs(classes) do
	sh[k] = sh.require(v)
end

return sh