local cloneref = cloneref or function(instance) return instance end;

local OWNER = 'LovelySoftworksLLC'
local GAME = 'SLR2'

local BASE_PATH = 'https://raw.githubusercontent.com/%s/Lovely/refs/heads/main/%s/%s'

local function loadModule(file: string)
    local path = BASE_PATH:format(OWNER, GAME, file)
    local module = game:HttpGet(path)

    return loadstring(module)()
end

local Connector = loadModule('Utils/Connector.luau')

local Players = cloneref(game:GetService('Players'));

local localPlayer = cloneref(Players.LocalPlayer);
local camera = cloneref(workspace.CurrentCamera);

local Heartbeat = getgenv().Heartbeat;
local connections = Connector.new()

local playerInstances = {}

local HEALTH_BAR_OFFSET = Vector2.new(6, 0);
local HEALTH_TEXT_OFFSET = Vector2.new(7, 0);
local HEALTH_BAR_OUTLINE_OFFSET = Vector2.new(0, 1);
local NAME_OFFSET = Vector2.new(0, 6);
local DISTANCE_OFFSET = Vector2.new(0, 6);
local VERTICES = {
	Vector3.new(-1, -1, -1),
	Vector3.new(-1, 1, -1),
	Vector3.new(-1, 1, 1),
	Vector3.new(-1, -1, 1),
	Vector3.new(1, -1, -1),
	Vector3.new(1, 1, -1),
	Vector3.new(1, 1, 1),
	Vector3.new(1, -1, 1)
};

local compareinstances = compareinstances or function(a, b)
	return a:GetDebugId() == b:GetDebugId();
end

local module = {}

module.config = {
    box = {
        Enabled = false,
        Color = Color3.fromRGB(100,0,0),
    },
    boxOutline = {
        Enabled = false,
        Color = Color3.fromRGB(0, 0, 0),
    },
    boxFill = {
        Enabled = false,
        Color = Color3.fromRGB(255,0,0),
        Transparency = 0.85,
    },
    
    name = {
        Enabled = false,
        Color = Color3.fromRGB(255,255,255),
        Transparency = 0,
        Outline = true,
        OutlineColor = Color3.fromRGB(0, 0, 0),
        Size = 12,
        Font = 1,
    },
    distance = {
        Enabled = false,
        Color = Color3.fromRGB(255,255,255),
        Transparency = 0,
        Outline = true,
        OutlineColor = Color3.fromRGB(0, 0, 0),
        Size = 9,
        Font = 1,
    },

    healthText = {
        Enabled = false,
        Color = Color3.fromRGB(255,255,255),
        Transparency = 0,
        Outline = true,
        OutlineColor = Color3.fromRGB(0, 0, 0),
        Size = 9,
        Font = 1,
    },
    healthBarOutline = {
        Enabled = false,
        Color = Color3.fromRGB(0, 0, 0),
        Transparency = 0,
    },
    healthBar = {
        Enabled = false,
        HealthyColor = Color3.new(0,1,0),
        DyingColor = Color3.new(1,0,0),
    },

    corners = {
        Enabled = false, 
        Color = Color3.fromRGB(255, 255, 255),
    },
    cornersOutline = {
        Enabled = false, 
        Color = Color3.fromRGB(0, 0, 0),
    },
}

local playerObject: { { player: Player } } = {}
playerObject.__index = playerObject

local function createDrawing(type, properties)
    local drawing = Drawing.new(type)

    for i,v in properties do
        drawing[i] = v
    end

    return drawing
end

local function isBodyPart(part)
    return part.ClassName == 'MeshPart' or part.ClassName == 'Part'
end

local function getBoundingBox(parts)
	local min, max;
	for i = 1, #parts do
		local part = parts[i];
        if not isBodyPart(part) then
            continue
        end

		local cframe, size = part.CFrame, part.Size;

		min = Vector3.zero.Min(min or cframe.Position, (cframe - size*0.5).Position);
		max = Vector3.zero.Max(max or cframe.Position, (cframe + size*0.5).Position);
	end

	local center = (min + max)*0.5;
	local front = Vector3.new(center.X, center.Y, max.Z);
	return CFrame.new(center, front), max - min;
end

local function worldToScreen(world)
	local screen, onScreen = camera:WorldToViewportPoint(world);
	return Vector2.new(screen.X, screen.Y), onScreen, screen.Z;
end

local function calculateCorners(cframe, size)
	local corners = table.create(#VERTICES);
	for i = 1, #VERTICES do
		corners[i] = worldToScreen((cframe + size * 0.5 * VERTICES[i]).Position);
	end

	local min = Vector2.zero.Min(camera.ViewportSize, unpack(corners));
	local max = Vector2.zero.Max(Vector2.zero, unpack(corners));

	return {
		topLeft = Vector2.new(math.floor(min.X), math.floor(min.Y)),
		topRight = Vector2.new(math.floor(max.X), math.floor(min.Y)),
		bottomLeft = Vector2.new(math.floor(min.X), math.floor(max.Y)),
		bottomRight = Vector2.new(math.floor(max.X), math.floor(max.Y))
	};
end

function playerObject.new(player: Player)
    local self = setmetatable({
        player = player,
        drawings = {
            boxFill = createDrawing('Square', { Filled = true, Visible = false }),
            boxOutline = createDrawing('Square', { Thickness = 2, Visible = false }),
            box = createDrawing('Square', { Thickness = 1, Visible = false, ZIndex = 2, }),
            healthBarOutline = createDrawing('Line', { Thickness = 3, Visible = false }),
			healthBar = createDrawing('Line', { Thickness = 1, Visible = false }),
			healthText = createDrawing('Text', { Center = true, Visible = false }),
			name = createDrawing('Text', { Text = player.DisplayName, Center = true, Visible = false }),
			distance = createDrawing('Text', { Center = true, Visible = false }),

            corners = {},
            cornersOutline = {},
        },
        connections = Connector.new(),
        character = nil,
    }, playerObject)
   
    for _, v in {"topLeft", "topRight", "bottomLeft", "bottomRight"} do
        self.drawings.cornersOutline[v..'_vertical'], self.drawings.cornersOutline[v..'_horizontal'] = createDrawing('Line', { Thickness = 2, Visible = false }), createDrawing('Line', { Thickness = 2, Visible = false })
        self.drawings.corners[v..'_vertical'], self.drawings.corners[v..'_horizontal'] = createDrawing('Line', { Thickness = 1, Visible = false }), createDrawing('Line', { Thickness = 1, Visible = false, ZIndex = 2, })
    end 

    local function characterAdded(character: Model)
        local humanoid = character and character:WaitForChild('Humanoid', 10)
        if not player:IsDescendantOf(Players) or not humanoid or humanoid.Health <= 0 then
            return
        end

        self.character = character

        self.connections:Add('died', character.Humanoid.Died:Once(function()
            self.character = nil

            self:HideDrawings()
        end))
    end

    if player.Character then
        characterAdded(player.Character)
    end
    self.connections:Add('characteradded', player.CharacterAdded:Connect(characterAdded))

    playerInstances[player.UserId] = self
    return self
end

function playerObject:HideDrawings()
    for _, drawing in self.drawings do
        if not isrenderobj(drawing) then -- it isn't a drawing / is a table
            for i,v in drawing do
                v.Visible = false 
            end
        else
            drawing.Visible = false
        end
    end
end

function playerObject:Render()
    local humanoid = self.character:FindFirstChild('Humanoid')
    local head = self.character and self.character:FindFirstChild("Head")

    if not humanoid or not head then
        return self:HideDrawings()
    end

    local corners = calculateCorners(getBoundingBox(self.character:GetChildren()));
    local _, onScreen, depth = worldToScreen(head.Position);

    if not onScreen then
        return self:HideDrawings()
    end

    for i, v in { self.drawings.cornersOutline, self.drawings.corners } do
        for corner, obj in v do
            local corner, direction = table.unpack(string.split(corner, '_'))
            local boxSize = corners.bottomRight - corners.topLeft
            
            local vertMul  = string.find(corner:lower(), "top") and 1 or -1
            local horizMul = string.find(corner:lower(), "left") and 1 or -1

            local offset = direction == "vertical" and Vector2.new(0, boxSize.Y * 0.2 * vertMul) or Vector2.new(boxSize.X * 0.2 * horizMul, 0)
            
            obj.Visible = if i == 2 then module.config.corners.Enabled else module.config.cornersOutline.Enabled
            obj.Color = if i == 2 then module.config.corners.Color else module.config.cornersOutline.Color
            obj.To = corners[corner] + offset
            obj.From = corners[corner]
        end 
    end

    local box = self.drawings.box
    box.Visible = module.config.box.Enabled
    if box.Visible then
        box.Position = corners.topLeft
        box.Size = corners.bottomRight - corners.topLeft
        box.Color = module.config.box.Color
    end

    local boxOutline = self.drawings.boxOutline
    boxOutline.Visible = module.config.boxOutline.Enabled
    if boxOutline.Visible then
        boxOutline.Position = corners.topLeft
        boxOutline.Size = corners.bottomRight - corners.topLeft
        boxOutline.Color = module.config.boxOutline.Color
    end

    local boxFill = self.drawings.boxFill
    boxFill.Visible = module.config.boxFill.Enabled
    if boxFill.Visible then
        boxFill.Position = corners.topLeft
        boxFill.Size = corners.bottomRight - corners.topLeft
        boxFill.Color = module.config.boxFill.Color
        boxFill.Transparency = 1 - module.config.boxFill.Transparency
    end

    local name = self.drawings.name
    name.Visible = module.config.name.Enabled
    if name.Visible then
        name.Color = module.config.name.Color
        name.Transparency = 1 - module.config.name.Transparency
        name.Font = module.config.name.Font
        name.Size = module.config.name.Size
        name.Outline = module.config.name.Outline
        name.OutlineColor = module.config.name.OutlineColor
        name.Position = (corners.topLeft + corners.topRight) * 0.5 - Vector2.yAxis * name.TextBounds.Y - NAME_OFFSET;
    end

    local distance = self.drawings.distance
    distance.Visible = module.config.distance.Enabled
    if distance.Visible then
        distance.Color = module.config.distance.Color
        distance.Transparency = 1 - module.config.distance.Transparency
        distance.Font = module.config.distance.Font
        distance.Text = `{math.round(depth)} studs`
        distance.Size = module.config.distance.Size
        distance.Outline = module.config.distance.Outline
        distance.OutlineColor = module.config.distance.OutlineColor
        distance.Position = (corners.bottomLeft + corners.bottomRight) * 0.5 + DISTANCE_OFFSET;
    end

    local barFrom = corners.topLeft - HEALTH_BAR_OFFSET
    local barTo = corners.bottomLeft - HEALTH_BAR_OFFSET;

    local healthText = self.drawings.healthText
    healthText.Visible = module.config.healthText.Enabled
    if healthText.Visible then
        healthText.Color = module.config.healthText.Color
        healthText.Transparency = 1 - module.config.healthText.Transparency
        healthText.Font = module.config.healthText.Font
        healthText.Text = `{math.round(humanoid.Health)} hp`
        healthText.Size = module.config.healthText.Size
        healthText.Outline = module.config.healthText.Outline
        healthText.OutlineColor = module.config.healthText.OutlineColor
		healthText.Position = Vector2.zero.Lerp(barTo, barFrom, humanoid.Health/humanoid.MaxHealth) - healthText.TextBounds*0.5 - HEALTH_TEXT_OFFSET;
    end

    local healthBar = self.drawings.healthBar
    healthBar.Visible = module.config.healthBar.Enabled 
    if healthBar.Visible then
        healthBar.To = barTo;
		healthBar.From = Vector2.zero.Lerp(barTo, barFrom, humanoid.Health/humanoid.MaxHealth);
		healthBar.Color = Color3.new().Lerp(module.config.healthBar.HealthyColor, module.config.healthBar.DyingColor, humanoid.Health/humanoid.MaxHealth);
    end

    local healthBarOutline = self.drawings.healthBarOutline
    healthBarOutline.Visible = module.config.healthBarOutline.Enabled 
    if healthBarOutline.Visible then
        healthBarOutline.To = barTo + HEALTH_BAR_OUTLINE_OFFSET;
		healthBarOutline.From = barFrom - HEALTH_BAR_OUTLINE_OFFSET;
        healthBarOutline.Color = module.config.healthBarOutline.Color
        healthBarOutline.Transparency = module.config.healthBarOutline.Transparency
    end
end

function playerObject:Destroy()
    for _, drawing in self.drawings do
        if not isrenderobj(drawing) then -- it isn't a drawing / is a table
            for _,v in drawing do
                v:Remove()
            end
        else
            drawing:Remove()
        end
    end

    self.connections:Destroy()
    playerInstances[self.player.UserId] = nil
end

function module.Load(config)
    if config then 
        for setting, properties in module.config do
            if not config[setting] then
                continue 
            end

            for property in properties do
                local lower = property:lower()

                if config[setting][lower] then
                    module.config[setting][property] = config[setting][lower]
                end
            end
        end
    end

    for _, player: Player in Players:GetPlayers() do
        if compareinstances(player, localPlayer) then
            continue
        end

        playerObject.new(player)
    end

    connections:Add('playeradded', Players.PlayerAdded:Connect(playerObject.new))
    connections:Add('playerremoving', Players.PlayerRemoving:Connect(function(player)
        if not playerInstances[player.UserId] then 
            return 
        end

        playerInstances[player.UserId]:Destroy()
    end))

    Heartbeat:Schedule(function()
        for _, v in playerInstances do
            if not v.character then
                continue
            end
    
            v:Render()
        end
    end, 1/60)
end

function module:ChangeSetting(setting, properties)
    local realSetting
    for k,_ in module.config do
        if k:lower() == setting:lower() then
            realSetting = k
            break
        end
    end
    if not realSetting then return end

    for prop, val in properties do
        for pk,_ in module.config[realSetting] do
            if pk:lower() == prop:lower() then
                module.config[realSetting][pk] = val
                break
            end
        end
    end
end

function module:GetSetting(setting, property)
    local realSetting
    for k,_ in module.config do
        if k:lower() == setting:lower() then
            realSetting = k
            break
        end
    end
    if not realSetting then return nil end

    for pk,_ in module.config[realSetting] do
        if pk:lower() == property:lower() then
            return module.config[realSetting][pk]
        end
    end

    return nil
end


function module.Unload()
    Heartbeat:Destroy()
    connections:Destroy()

    for _, v in playerInstances do
        v:Destroy()
    end
    table.clear(playerInstances) -- already does this in the :Destroy() but why not

    module.config = nil
end

return module
