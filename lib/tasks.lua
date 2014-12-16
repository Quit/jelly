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
local coroutine, error = coroutine, error
local radiant, jelly, is_a = radiant, jelly, is_a

--! class Task
local Task = class()

--! desc Creates a new task that executes said function in those intervals.
function Task:__init(action, interval)
  self._action, self._interval = coroutine.create(action), interval or 0
  
  if not self._action then
    error('cannot create task: coroutine.create failed!')
  end
  
  self._status = 'created'
end

--! desc 
function Task:start()
  if not self:can_start() then
    error('cannot start task: status is ' .. self._status)
  end
  
  jelly.timers.create(self, self._interval, math.huge, self._run, self)
  self._status = 'running'
  
  -- Call the first tick already.
  self:_run()
end

--! desc Returns the task's status.
function Task:status()
  return self._status
end

--! desc Returns whether a task can be started
function Task:can_start()
  return self._status == 'created' or self._status == 'stopped'
end

--! hidden
function Task:_run()
  local status, err = coroutine.resume(self._action)

  if not status then	
    self:stop()
    self._status = 'faulted'
    error('task execution failed: ' .. err)
  end
  
  -- Did we finish?
  if coroutine.status(self._action) == 'dead' then
    self:_finished()
  end
end

--! desc Stops execution of said task immediately.
function Task:stop()
  jelly.timers.destroy(self)
  self._status = 'stopped'
end

--! desc Queues a function - or task - to be executed/scheduled as soon as this task
--! desc has successfully finished
function Task:continue_with(action)
  if not is_a(action, Task) and type(action) ~= 'function' then
    error('action must be a Task or function!')
  end
  
  if type(action) == 'function' then
    action = Task(action)
  end
  
  if not self._done then
    self._done = {}
  end
  
  table.insert(self._done, action)
  
  -- Allow mass-chaining them.
  if is_a(action, Task) then
    return action
  end
end

--! hidden
function Task:_finished()
  -- Stop us
  self:stop()
  
  if self._done then
    for k, done in pairs(self._done) do
      -- Is it another task?
      if is_a(done, Task) and done:can_start() then
        done:start()
      else
        done()
      end
    end
  end
end

local tasks = {}

--! desc Creates a new task and immediately executes it. Returns the task at hand.
function tasks.run(func, interval)
  local t = Task(func, interval)
  t:start()
  
  return t
end

-- To create new tasks on the fly. Might move to its own file at some point...
tasks.Task = Task

return tasks