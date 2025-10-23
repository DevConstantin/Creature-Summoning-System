-- This module contains helpful functions to validate creature summoning permissions and limits. Both for server and client use.

local CreatureSummoningService = {}

-- // SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- // OBJECTS
local summonedCreatures: Folder = game.Workspace.SummonedCreatures
local CreatureStats = require(ReplicatedStorage.DB.CreatureStats)

-- // CONFIG
local MAX_CREATURES = 7 -- Max number of creatures allowed to be summoned at once. Set to 0 or nil for unlimited (not recommended)
local COMC_TITLE = "Care of Magical Creatures Instructor"
local INSTRUCTOR_ONLY = false -- If true, only the Care of Magical Creatures Instructor can summon creatures. Should ONLY be false for testing purposes.

-- // FUNCTIONS
-- Function to check if a player is allowed to summon creatures based on their title, only if INSTRUCTOR_ONLY is true
function CreatureSummoningService.isGamekeeper(player: PlayerMouse): (boolean, string?)
    -- Validate player
    if not player or typeof(player) ~= "Instance" or not player:IsA("Player") then
        warn("Invalid player instance provided to isGamekeeper.", player)
        return false
    end

     if INSTRUCTOR_ONLY then
        local charData = player:FindFirstChild("CharacterData")
        local plrTitle = charData and charData:FindFirstChild("equipped_Title")
        if plrTitle and plrTitle.Value ~= COMC_TITLE then
            return false, "Only the " .. COMC_TITLE .. " can summon creatures."
        end
    end

    return true
end

function CreatureSummoningService.getCreatureLimit(creatureType: string): number
    local creatureStats = CreatureStats[creatureType]
	if not creatureStats then
		warn("No stats found for creature:", creatureType, "Using Default stats.")
		creatureStats = CreatureStats["Default"]
	end

    local summonLimit = creatureStats.summonCap
	if summonLimit and summonLimit > 0 then
		return summonLimit
    else
        return 1 -- Default to 1 if no limit is set, to prevent unlimited summons
	end
end

function CreatureSummoningService.getCreatureCount(creatureType: string): number
    local count = 0
    for _, creatureModel in ipairs(summonedCreatures:GetChildren()) do
        if creatureModel:IsA("Model") and creatureModel.Name == creatureType then
            count += 1
        end
    end
    return count
end

-- Function to check if a player can summon a specific creature, given the current creature limits
-- Run on both client and server
function CreatureSummoningService.canSummonCreature(player: Player, currentCreature: string, creatureList: {[string]: number}): (boolean, string?)
    -- Ensure valid creature type
    if currentCreature == nil or typeof(currentCreature) ~= "string" then
        warn(player.Name .. " attempted to summon an invalid creature type:", currentCreature, "possible exploit?")
        return false
    end

    -- Check if player is the gamekeeper
    local allowed, reason = CreatureSummoningService.isGamekeeper(player, true)
    if not allowed then
        return false, reason
    end

    -- Check if max creatures reached
    local limitReached = #summonedCreatures:GetChildren() >= MAX_CREATURES
    if limitReached then
        warn(player.Name .. " attempted to summon a creature but maximum summoned creatures reached.")
        return false, "Maximum number of summoned creatures reached."
    end

    -- Check against the creature's summon cap
    local creatureLimit = creatureList and creatureList[currentCreature] or CreatureSummoningService.getCreatureLimit(currentCreature)
    local currentCount = CreatureSummoningService.getCreatureCount(currentCreature) or 0
    if currentCount >= creatureLimit then
        warn(player.Name .. " attempted to summon a " .. currentCreature .. " but its limit has been reached.")
        return false, currentCreature .. " limit reached."
    end

    return true
end

return CreatureSummoningService