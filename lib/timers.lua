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

local radiant = radiant
local math, tonumber, pairs, type, unpack = math, tonumber, pairs, type, unpack

local constants = radiant.resources.load_json("/stonehearth/services/calendar/calendar_constants.json")

--! realm jelly
local timers = {}

-- We use this class a few times in the code, but define it later due to realm stuff.
local Timer

--[[ Generic helper functions ]]--

--! desc Parses a string à "4d12h" into hours, minutes and seconds.
--! desc Accepts days (d), hours (h), minutes (m) and seconds (s) as modifiers.
--! param string str String that should be parsed.
--! returns three numbers: The hours, minutes and seconds present in the string. These will be normalized, i.e. hours and seconds are in `[0, 59]`.
--! remarks This function allows parsing of time strings, which can be handy - but also absurd. It does not validate the input, so `"1d1d`" would be equal to `"2d"`.
function timers.parse_time(str)
	local hours, minutes, seconds = 0, 0, 0
	
	for time, unit in str:gmatch('(%d+)([dhms])') do
		time = tonumber(time)
		if unit == 'd' then
			hours = hours + time * constants.hours_per_day
		elseif unit == 'h' then
			hours = hours + time
		elseif unit == 'm' then
			minutes = minutes + time
		elseif unit == 's' then
			seconds = seconds + time
		end
	end
	
	local whole
	
	minutes, seconds = minutes + math.floor(seconds / constants.seconds_per_minute), seconds % constants.seconds_per_minute
	hours, minutes = hours + math.floor(minutes / constants.minutes_per_hour), minutes % constants.minutes_per_hour
	
	return hours, minutes, seconds
end

--! desc Converts a time(-span) into an amount of game ticks
--! param number hours Hours
--! param number minutes Minutes
--! param number seconds Seconds
--! returns number Number of the action, in game ticks - according to current timing standards.
function timers.time_to_ticks(hours, minutes, seconds)
	return constants.ticks_per_second * ((hours * constants.minutes_per_hour + minutes) * constants.seconds_per_minute + seconds)
end

-- When we last checked our stuff.
local last_now = 0

-- List of timers we have to deal with.
local ticking_timers = {}

-- Gameloop listener.
-- Goes through the list of timers, checks if they need to run, calls them if necessary.
local function on_gameloop(event)
	last_now = event.now
	
	-- List of "run out" timers
	local t = {}
	-- Last index of the run out timers
	local t0 = 0
	
	for id, timer in pairs(ticking_timers) do
		if timer._next_run <= last_now then
			-- If we have ran out of repetitions...
			if not timer:_run() then
				-- Remove us after the loop
				t0 = t0 + 1
				t[t0] = id
			end
		end
	end
	
	-- For each expired timer
	for i = 1, t0 do
		-- Make sure that the timer is *really* dead and wasn't restarted in-between
		if ticking_timers[t[i]]:is_stopped() then
			ticking_timers[t[i]] = nil
		end
	end
end

--! desc Returns the last now().
--! returns The last now, in milliseconds.
function timers.now()
	return last_now
end

-- On the server, timers are on the gameloop, which is all ~200ms
if radiant.is_server then
	radiant.events.listen(radiant.events, 'stonehearth:gameloop', on_gameloop)
else
	-- On the client, we don't have such a thing yet. Hacks ahoy!
	timers._frame_tracer = _radiant.client.trace_render_frame()
	timers._frame_tracer:on_frame_start("update jelly client timers", function(now, alpha, frame_time) on_gameloop({ now = now }) end)
end

--[[ jelly public functions ]]--
--! desc Creates a timer with a certain id that runs at `interval' ticks and has `repetition` repetitions while calling `func`
--! param value id An unique ID that identifies this timer. Timers with the same ID will overwrite each other and this ID can be used to identify/search for a timer in case the object gets lost.
--! param number/string interval The interval, in ticks (when a number) or a time span (when a string, parsed with `jelly.timers.parse_time`), that this timer will run on. Note that this is the *minimum* interval, i.e. there is no guarantee that the timer will run every X ticks - only that it will be executed after X ticks.
--! param number repetition Number of repetitions that the timer should have. "1" will run the timer once, 
--! param function func Function to be called whenever the timer is to be executed
--! param ... ... Any arguments passed to `func`
--! returns The `Timer` object representing this timer.
function timers.create(id, interval, repetition, func, ...)
	-- If a time string has been passed
	if type(interval) == 'string' then
		interval = timers.time_to_ticks(timers.parse_time(interval))
	end
	
	-- Does a timer with that id already exist?
	if ticking_timers[id] then
		-- Stop it.
		ticking_timers[id]:stop()
	end
	
	local timer = Timer(id, interval, repetition, func, ...)
	ticking_timers[id] = timer
	
	return timer
end

--! same jelly.timers.create
timers.add = timers.create

--! desc Removes the timer with the id `id`.
--! param value id Id that was used to create the timer and identifies it.
function timers.remove_timer(id)
	local timer = ticking_timers[id]
	if timer then
		timer:stop()
	end
end

--! same jelly.timers.remove_timer
timers.destroy = timers.remove_timer

--! desc Creates a fire-and-forget timer.
--! param number interval Interval after which the timer is executed
--! param function func Function that is called
--! param ... ... Any arguments passed to the function.
function timers.simple(interval, func, ...)
	return timers.create({}, interval, 1, func, ...)
end

--! desc Returns timer with id `id`
--! param value id Id used to create the timer
--! returns `Timer` object
function timers.get_timer(id)
	return timers[id]
end

--[[ Timer class ]]--
--! class Timer

Timer = class()

--! hidden
function Timer:__init(id, interval, repetition, func, ...)
	assert(id)
	radiant.check.is_number(interval)
	radiant.check.is_number(repetition)
	radiant.check.is_function(func)

	self.id, self.interval, self.repetition, self.func, self.args = id, interval, repetition, func, { ... }
	
	-- When we'll run the timer the next time
	self._next_run = last_now + interval
end

--! hidden
function Timer:_run()
	self.repetition = self.repetition - 1
	
	if self.repetition < 0 then
		return false
	end
	
	self.func(unpack(self.args))
	
	if self.repetition >= 1 then
		self:reset()
		return true
	end
	
	return false
end

--! desc Resets the time until the timer is executed again to the given interval. This does not re-start stopped timers.
function Timer:reset()
	self._next_run = last_now + self.interval
end

--! desc Stops the timer and destroys it as soon as possible.
function Timer:stop()
	self.repetition = -1
	self._next_run = math.huge
end

--! desc Queries whether the timer has been stopped or is still running.
--! returns Boolean that depicts if the timer will run again (at some point)
function Timer:is_stopped()
	return self.repetition < 0
end

return timers