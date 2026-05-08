local module = {}
module.__index = module

function module.new()
    return setmetatable({
        _connections = {}
    }, module)
end

function module:Add(name: string | number, connection: RBXScriptConnection, callback: () -> ()): number
    self:Remove(name)

    self._connections[name] = {
        connection = connection,
        callback = callback,
    }
end

function module:Remove(name: string | number): boolean
    local data = self._connections[name]
    if not data then return false end 

    data.connection:Disconnect()
    
    if data.callback then
        data.callback()
    end
    
    self._connections[name] = nil
    
    return true
end

function module:Exists(name: string | number): boolean
    return self._connections[name] ~= nil
end

function module:Reset()
    for _, data: RBXScriptConnection in self._connections do
        data:Disconnect()

        if data.callback then
            data.callback()
        end
    end
    table.clear(self._connections)
end

function module:Destroy()
    self:Reset()
    self._connections = nil
end

return module
