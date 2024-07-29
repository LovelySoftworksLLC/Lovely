--!strict

local FreeThreads: { thread } = {}

local function RunCallback(Callback, Thread, ...)
    Callback(...)
    table.insert(FreeThreads, Thread)
end

local function Yielder()
    while true do
        RunCallback(coroutine.yield())
    end
end

return function<T...>(Callback: (T...) -> (), ...: T...)
    local Thread
    if #FreeThreads > 0 then
        Thread = FreeThreads[#FreeThreads]
        FreeThreads[#FreeThreads] = nil
    else
        Thread = coroutine.create(Yielder)
        coroutine.resume(Thread)
    end

    local success, errorValue = coroutine.resume(Thread, Callback, Thread, ...)
    if not success then
        warn(`\n {errorValue} \n {debug.traceback(Thread)}`)
    end
end
