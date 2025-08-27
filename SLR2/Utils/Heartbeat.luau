--!strict
--!native

--[[

	Heartbeat.luau    | A Heartbeat Wrapper for LovelySoftworks
	
	LovelySoftworks  | 2025
	Version          | v1.0.0

--]] 


--// Services

local RunService = game:GetService('RunService');

--// Types

type Callback = (...any) -> (...any);

type Task = {
	Running: boolean,
	Cancel: (Task) -> (),
	
	_fn: Callback,
	_alive: boolean,
	_interval: number,
	_lastCalled: number,
}

--// Helpers

local FreeThreads: { thread } = { };

local function _handleCallback(fn: Callback, ...)
	local thread = coroutine.running();
	
	local success, err = pcall(fn, ...);
	if not success then
		warn(`[Heartbeat]: {err}`);
	end
	table.insert(FreeThreads, thread);
end

local function _yielder()
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
		_tasks = { } :: { Task },
		_elapsed = 0;
		_running = true,
		_conn = nil :: RBXScriptConnection?,
	}, Heartbeat)
	
	self.__conn = RunService.Heartbeat:Connect(function(deltaTime: number) 
		self._elapsed += deltaTime;
		
		local tasks = self._tasks;
		local elapsed = self._elapsed;

		for index, currentTask in tasks do
			if not currentTask._alive then
				table.remove(tasks, index);
				continue;
			end
			
			if elapsed - currentTask._lastCalled < currentTask._interval then
				continue;
			end
			
			currentTask._lastCalled = elapsed;
			_execute(currentTask._fn);
		end
		
	end)
	
	return self;
end

function Heartbeat:Schedule(fn: Callback, interval: number)
	if not self._running then
		return;
	end
	
	local tasks = self._tasks;
	
	local taskObj = {
		_fn = fn,
		_alive = true,
		
		_interval = interval or 0,
		_lastCalled = -1,
		
		Running = true;
	};
	
	function taskObj:Cancel()
		if not self.Running then
			return;
		end

		self.Running = false;
		taskObj._alive = false;	
	end	
	
	table.insert(tasks, taskObj);

	return taskObj;
end

function Heartbeat:Destroy()
	local tasks = self._tasks;
	for index, runningTask in tasks do
		runningTask:Cancel();
		tasks[index] = nil;
	end
	
	if self._conn then
		self._conn:Disconnect();
	end
end

return Heartbeat;
