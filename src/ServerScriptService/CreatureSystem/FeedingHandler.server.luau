local ReplicatedStorage = game:GetService("ReplicatedStorage")

--- // OBJECTS
local Creature = require(script.Parent.Creature)
local summonedCreatures: Folder = game.Workspace.SummonedCreatures

local feedingEvent: RemoteEvent = ReplicatedStorage.RemoteEvents.FeedCreatureEvent

--- // CONFIG
local config = ReplicatedStorage.Configurations.CreatureSystemsConfig
local FEEDING_RANGE_DEFAULT = config:GetAttribute("FeedingRange") or 12 -- Default feeding range. Slightly higher than client to account for latency.

local function inProximity(player: Player, creatureModel: Model): boolean
    local character = player.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then
        return false
    end

    local hrp = character.HumanoidRootPart
    local creatureHrp = creatureModel:FindFirstChild("HumanoidRootPart")
    if not creatureHrp then
        return false
    end

    local distance = (hrp.Position - creatureHrp.Position).Magnitude
    return distance <= FEEDING_RANGE_DEFAULT
end

local function onFeedCreature(player: Player, creatureModel: Model, feedingToolName: string)
    if not creatureModel or not creatureModel:IsDescendantOf(game.Workspace) then
        warn("Invalid creature model provided for feeding.")
        return
    end

    print(player.Name, "is attempting to feed creature:", creatureModel, "Active creatures:", Creature.getActiveCreatures())
    local creatureClass = Creature.getActiveCreatures()[creatureModel]
    if not creatureClass then
        warn("No active creature class found for the provided model.")
        return
    end

    if not inProximity(player, creatureModel) then
        warn("Player", player.Name, "is too far from the creature to feed it. Possible exploit attempt?")
        return
    end

    creatureClass:feed(player, feedingToolName)
end

feedingEvent.OnServerEvent:Connect(onFeedCreature)
