local Pathfinding = {}

local PathfindingService = game:GetService("PathfindingService")
local DebugService = require(game.ReplicatedStorage.RSModules.DebugService)

local VISUALIZE_PATHS = true

local path = PathfindingService:CreatePath({
    AgentRadius = 2,
    AgentHeight = 5,
    AgentCanJump = true,
    WaypointSpacing = 4,
    --  AgentWalkableTypes = {Enum.Material.Grass, Enum.Material.Concrete, Enum.Material.WoodPlanks, Enum.Material.Metal}
})

-- Predefined paths for specific NPC types, accounting for their unique sizes and movement capabilities
-- May need to be seperated to a different module if more NPC types are added in the future
local pathsDB = {
    ["Hippogriff"] = PathfindingService:CreatePath({
        AgentRadius = 8,
        AgentHeight = 10,
        AgentCanJump = false,
        WaypointSpacing = 10,
    }),

    ["Dementor"] = PathfindingService:CreatePath({
        AgentRadius = 3,
        AgentHeight = 9,
        AgentCanJump = true,
        WaypointSpacing = 10,
    }),

    ["Acromantula"] = PathfindingService:CreatePath({
        AgentRadius = 4,
        AgentHeight = 3,
        AgentCanJump = false,
        WaypointSpacing = 10,
    }),

    ["Monster Book"] = PathfindingService:CreatePath({
        AgentRadius = 6,
        AgentHeight = 1,
        AgentCanJump = false,
        WaypointSpacing = 2.3,
    }),

    ["Troll"] = PathfindingService:CreatePath({
        AgentRadius = 5,
        AgentHeight = 14,
        AgentCanJump = true,
        WaypointSpacing = 10,
    }),
}

function Pathfinding:GetPath(npcName: string?)
    print("Pathfinding | Retrieving path for NPC:", npcName)

    if not npcName then
        return path
    end

    if pathsDB[npcName] then
        return pathsDB[npcName]
    else
        local newPath = path
        pathsDB[npcName] = newPath
        print(pathsDB)
        return newPath
    end
end

-- @param agentName Optional name to store the custom path under, for later retrieval
function Pathfinding:CreateCustomPath(agentName: string?, agentRadius: number, agentHeight: number, agentCanJump: boolean, waypointSpacing: number)
    local customPath = PathfindingService:CreatePath({
        AgentRadius = agentRadius,
        AgentHeight = agentHeight,
        AgentCanJump = agentCanJump,
        WaypointSpacing = waypointSpacing,
    })
    if agentName then
        pathsDB[agentName] = customPath
    end
    return customPath
end

local function visualizePath(waypoints: {PathWaypoint})
    if not VISUALIZE_PATHS then return end
    DebugService:placeNode(waypoints[1].Position, Color3.new(0, 0, 1), 0.2, 5)
   -- print("Visualizing path with", #waypoints, "waypoints.")
    for i, waypoint in ipairs(waypoints) do
        if i == 1 or i == #waypoints then
            continue
        end
        DebugService:placeNode(waypoint.Position, Color3.new(0, 1, 0), 0.1, 5)
    end
    DebugService:placeNode(waypoints[#waypoints].Position, Color3.new(1, 0, 0), 0.2, 5)
end

function Pathfinding:GetWaypoints(npcName: string?, startPos: Vector3, endPos: Vector3)
    local npcPath = self:GetPath(npcName)
    local success, errorMessage = pcall(function()
        npcPath:ComputeAsync(startPos, endPos)
    end)
    if success then
        if npcPath.Status == Enum.PathStatus.Success then
            visualizePath(npcPath:GetWaypoints())
            return npcPath:GetWaypoints()
        else
            warn("Pathfinding | Pathfinding failed with status:", npcPath.Status, "from", tostring(startPos), "to", tostring(endPos))
            return nil
        end
    else
        warn("Pathfinding | Error computing path:", errorMessage)
        return nil
    end
end

return Pathfinding