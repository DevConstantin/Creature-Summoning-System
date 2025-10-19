local DebugService = {}

local function createHighlight(part, color)
	if not script:GetAttribute("Highlights") then return end 

	local hl = Instance.new("Highlight")
	hl.FillColor = color
	hl.OutlineColor = color
	hl.Parent = part
end

-- @param color3: Optional. Defaults to white 
-- @param remainDuration: How long the line will stay. Defaults to 2
-- @param sizeMultiplier: Applied to a sphere size of 1,1,1. .1 by default 
function DebugService:placeNode(pos, color, sizeMultiplier, remainDuration)
	if not script:GetAttribute("Nodes") then return end
	
	if typeof(pos) == "CFrame" then pos = pos.position end 

	local nodePart = Instance.new("Part")
	nodePart.Anchored = true 
	nodePart.Size = Vector3.new(1,1,1) * (not sizeMultiplier and .1 or sizeMultiplier)
	nodePart.Color = color or Color3.new(1, 1, 1)
	nodePart.Transparency = 0
	nodePart.CanCollide = false 
	nodePart.CanQuery = false 
	nodePart.CanTouch = false
	nodePart.Shape = Enum.PartType.Ball
	nodePart.Material = Enum.Material.Neon
	nodePart.Position = pos 
	createHighlight(nodePart, nodePart.Color)
	nodePart.Parent = workspace

	task.delay(remainDuration or 2, function()
		nodePart:Destroy()
	end)
end

-- Draw a line between two positions
-- @param color3: Optional. Defaults to green 
-- @param remainDuration: How long the line will stay. Defaults to 4
function DebugService:connectPositions(p1, p2, color3, sizeMultiplier, remainDuration)
	if not script:GetAttribute("Lines") then return end
	
	local part = Instance.new("Part")
	part.Size = Vector3.new(1 * sizeMultiplier, 1 * sizeMultiplier, (p2 - p1).magnitude)
	part.CFrame = CFrame.new(p1, p2) * CFrame.new(0, 0, -part.Size.Z/2)
	part.Color = color3 or BrickColor.new("Green").Color
	part.Material = Enum.Material.Neon
	--part.Shape = Enum.PartType.Cylinder
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false 
	part.Transparency = script:GetAttribute("Highlights") and 0 or .5
	createHighlight(part, part.Color)
	part.Parent = game.Workspace
	task.delay(remainDuration or 4, function()
		part:Destroy()
	end)
end

return DebugService
