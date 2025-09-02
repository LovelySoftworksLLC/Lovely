--!strict
--!native

--[[

	Heartbeat.luau    | A Heartbeat Wrapper for LovelySoftworks
	
	LovelySoftworks  | 2025
	Version          | v1.3

--]] 


--// Services

local RunService = game:GetService('RunService');

--// Types

type Callback = (deltaTime: number) -> any;

type Task = {
	Cancel: (Task) -> (),
	
	_fn: Callback,
	_alive: boolean,
	_interval: number?,
	_lastCalled: number,
	
	_next: Task?,
	_prev: Task?,
}

--// Helpers

local FreeThreads: { thread } = { };

local function _handleCallback(fn: Callback, ...)
	local thread = coroutine.running();
	
	local success, err = pcall(fn, ...);
	if not success then
		warn(`[Heartbeat]: {err}`);
	end
	
	if coroutine.status(thread) ~= 'dead' then
		table.insert(FreeThreads, thread);
	end
end

local function _yielder()
	-- // keeps thread alive, allows reuse
	while true do
		_handleCallback(coroutine.yield());
	end
end

local function _execute(fn: Callback, ...)
	local freeThread = table.remove(FreeThreads);
	if not freeThread then
		freeThread = coroutine.create(_yielder);
		coroutine.resume(freeThread :: any);
	end
	
	task.spawn(freeThread :: thread, fn, ...);
end

--// Heartbeat Class

local Heartbeat = { };
Heartbeat.__index = Heartbeat;

function Heartbeat.new()
	local self = setmetatable({
		_elapsed = 0;
		_running = true,
		_conn = nil :: RBXScriptConnection?,
		
		_next = nil,
		_prev = nil,
	}, Heartbeat)
	
	self._conn = RunService.Heartbeat:Connect(function(deltaTime: number) 
		self._elapsed += deltaTime;
		
		local currentTask = self._next;
		local elapsed = self._elapsed;

		while currentTask do
			local nextTask = currentTask._next;
			
			if currentTask._alive then
				local lastCalled = currentTask._lastCalled;
				local interval = currentTask._interval;

				if elapsed - lastCalled >= interval then
					currentTask._lastCalled = elapsed;
					_execute(currentTask._fn, deltaTime);
				end
			else
				if currentTask._prev then
					currentTask._prev._next = currentTask._next;
				end
				
				if currentTask._next then
					currentTask._next._prev = currentTask._prev;
				end
			end
			
			currentTask = nextTask;
		end
		
	end)
	
	return self;
end

function Heartbeat:Schedule(fn: Callback, interval: number?)
	if not self._running then
		return;
	end
	
	local taskObj = {
		_fn = fn,
		_alive = true,
		
		_interval = interval or 0,
		_lastCalled = self._elapsed,
		
		_next = self._next,
		_prev = self,
	};
	
	if self._next ~= nil then
		self._next._prev = taskObj;
	end
	
	self._next = taskObj;
	
	function taskObj:Cancel()
		if not self._alive then
			return;
		end
		
		if taskObj._prev then
			taskObj._prev._next = taskObj._next;
		end
		
		if taskObj._next then
			taskObj._next._prev = taskObj._prev;
		end
		
		taskObj._alive = false;	
	end	

	return taskObj;
end

function Heartbeat:Destroy()
	if not self._running then
		return;
	end
	
	local currentTask = self._next;
	while currentTask do
		currentTask:Cancel();
		currentTask = currentTask._next;
	end
	
	if self._conn then
		self._conn:Disconnect();
		
		(self :: any)._conn = nil;
	end
	
	(self :: any)._next = nil;
	(self :: any)._prev = nil;
	
	self._running = false;
end

return Heartbeat;
