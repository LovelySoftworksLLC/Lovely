--!native
--!strict
--!optimize 2

local RunService = game:GetService("RunService")

local Queue: {{buff: buffer?, callback: (deltaTime: number) -> ()}} = {}
local IncrementingNumber: number = 1

local Spawn = loadstring(game:HttpGet("https://raw.githubusercontent.com/LovelySoftworksLLC/Lovely/main/Survival%20Odyssey/Utils/Spawn.luau"))()

RunService.Heartbeat:Connect(function(deltaTime: number)
    for _, info in Queue do
        local callback = info.callback
        local buff = info.buff
        
        if not buff then
            Spawn(callback, deltaTime)
            continue
        end

        local Time = buffer.readf32(buff, 0) + deltaTime
        local Interval = buffer.readf32(buff, 4)
        
        buffer.writef32(buff, 0, Time)
        
        if Time > Interval * 10 then
            buffer.writef32(buff, 0, 0)
        elseif Time > Interval then
            buffer.writef32(buff, 0, Time - Interval)
        else
            continue
        end
        
        local Past = buffer.readf64(buff, 8)
        local Current = os.clock()
        
        buffer.writef64(buff, 8, Current)

        Spawn(callback, (Current - Past))
    end
end)

return function(callback: (deltaTime: number) -> (), Interval: number?): () -> ()    
    local storedCase = IncrementingNumber
    
    IncrementingNumber += 1
    
    local function removeCase(): ()
        Queue[storedCase] = nil
    end
    
    if not Interval then
        Queue[storedCase] = {callback = callback}
        return removeCase
    end

    local buff = buffer.create(16)
    buffer.writef32(buff, 0, 0)
    buffer.writef32(buff, 4, Interval)
    buffer.writef64(buff, 8, os.clock())

    Queue[storedCase] = {buff = buff, callback = callback}

    return removeCase
end
