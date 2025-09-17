local module = {}
module.__index = module

function module.new()
    return setmetatable({
        _connections = {}
    }, module)
end

function module:Add(name: string | number, connection: RBXScriptConnection): number
    self:Remove(name)
    self._connections[name] = connection
end

function module:Remove(name: string | number, connectionIndex: number): boolean
    if self._connections[name] then
        self._connections[name]:Disconnect()
        self._connections[name] = nil
        return true
    end
    return false
end

function module:Reset()
    for _, connection: RBXScriptConnection in self._connections do
        connection:Disconnect()
    end
    table.clear(self._connections)
end

function module:Destroy()
    self:Reset()
    self._connections = nil
end

return module
