--- // SERVICES
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhysicsService = game:GetService("PhysicsService")

--- // OBJECTS
local CreatureModule = require(script.Parent.Creature)
local CreatureStats = require(script.Parent.CreatureStats)
local creatures = ServerStorage.Creatures

local summonSystem = workspace.CreatureSummonSystem
local targetSpawn = summonSystem.CreatureSpawn
local creatureZone = summonSystem.CreatureZone

local creatureSummonEvents = ReplicatedStorage.RemoteEvents.CreatureSummonSystem

--- // CONFIG
local MOVEMENT_DELAY = 3 -- How long until the creature can move. Related to sparkle life length
local MAX_CREATURES = 7 -- Max number of creatures allowed to be summoned at once. Set to 0 or nil for unlimited (not recommended)

local activeCreatures = {} -- Table to hold references for creature classes & creatures that are active in the game world
local creaturesList = {} -- Dictionary of creatures and their limits, sent to clients

--- // FUNCTIONS
-- Must be updated for WOS
local function isGamekeeper(player)
	return true
end

local function canSummon(player, creatureType: string): boolean
	if not isGamekeeper(player) then
		return false, "Only the Care of Magical Creatures instructor to summon creatures."
	end

	if not creatureType or typeof(creatureType) ~= "string" then
		return false, "Invalid creature type."
	end

	-- Check against the global max creatures
	-- Skipped if MAX_CREATURES is 0 or nil
	if MAX_CREATURES and MAX_CREATURES > 0 then
		local activeCreaturesCount = 0
		for _, _ in pairs(activeCreatures) do
			activeCreaturesCount += 1
		end
		if activeCreaturesCount >= MAX_CREATURES then
			return false, "Maximum number of creatures reached."
		end
	end

	-- Check against the creature's summon cap
	local limit = creaturesList[creatureType]
	if limit then
		local activeNum = 0
		for creature, creatureModel in pairs(activeCreatures) do
			if creatureModel.Name == creatureType then
				activeNum += 1
			end
		end
		if activeNum < limit then
			return true
		end
	else
		warn("Failed to get a creature summon limit for", creatureType)
		return false
	end
	return false, creatureType .. " limit reached."
end

-- Function to despawn all creatures
local function despawnCreatures()
	for creatureClass, creatureModel in pairs(activeCreatures) do
		local success, result = pcall(function()
			creatureClass:despawn()
		end)

		if not success then
			creatureModel:Destroy()
		end
	end
end

local function despawnRequested(player, creatureType: string)
	if not isGamekeeper(player) then
		warn(player, "is not the gamekeeper but attempted to despawn a creature! Possible exploit?")
		return
	end

	print("Looking to despawn a", creatureType, "Active creatures:", activeCreatures)

	-- Despawn the first creature found of the requested type
	for creatureClass, creatureModel in pairs(activeCreatures) do
		print(creatureModel.Name, creatureType, creatureModel.Name == creatureType)
		if creatureModel.Name ~= creatureType then
			continue
		end
		local success, result = pcall(function()
			creatureClass:despawn()
			activeCreatures[creatureClass] = nil
		end)

		if not success then
			warn("Error while attempting to despawn creature class:", result)
			creatureModel:Destroy()
			activeCreatures[creatureClass] = nil
		end

		print("Final active creatures:", activeCreatures)
		break
	end
end

local function summonRequested(player, creatureType: string)
	local _canSummon, reason = canSummon(player, creatureType)
	if _canSummon then
		local creatureModelTemplate = creatures:FindFirstChild(creatureType)
		if not creatureModelTemplate then
			warn("Failed to get a creature model for creatureType:", creatureType)
			return
		end
		local creature = CreatureModule.spawn(creatureModelTemplate, targetSpawn.CFrame, true)
		activeCreatures[creature] = creature.model -- Store reference to the creature class and model

		task.wait(MOVEMENT_DELAY)

		-- Placeholder roaming behavior
		for i = 1, 1000 do
			if not creature.model or not creature.model.Parent then
				break
			end
			local t = creature:roam(
				nil,
				creatureType == "Pixie" and workspace.PixieRoamArea:GetChildren()
					or workspace.DementorRoamArea:GetChildren()
			)
			task.wait(t)
		end
	else
		warn("Unable to summon", creatureType, "Reason:", reason)
	end
end

-- Open creature summon GUI for the player, if they are the gamekeeper
local function suitcaseTriggered(player)
	if isGamekeeper(player) then
		print(creaturesList)
		summonSystem.CreatureSpawner.Sparkles:Emit(10)
		creatureSummonEvents.SummonCreature:FireClient(player, creaturesList)
	else
		warn("Only the Care of Magical Creatures instructor can use this.")
	end
end

-- Initial setup for each creature model
local function setupCreature(creature: Model)
	-- Ensure the creature model has the necessary components
	if not creature:FindFirstChild("Rig") then
		error("Creature model " .. creature.Name .. " is missing a Rig!")
	end
	local animations = creature:FindFirstChild("Animations")
	if not animations then
		error("Creature model " .. creature.Name .. " is missing an Animations folder!")
	elseif #animations:GetChildren() == 0 or not animations:FindFirstChild("Idle") then
		error("Creature model " .. creature.Name .. " has no animations!")
	end

	local creatureName = creature.Name
	local creatureStats = CreatureStats[creatureName]
	if not creatureStats then
		warn("No stats found for creature:", creatureName, "Using Default stats.")
		creatureStats = CreatureStats["Default"]
	end
	local summonLimit = creatureStats.summonCap
	if summonLimit and summonLimit > 0 then
		creaturesList[creature.Name] = summonLimit
	end

	local selfCollisions = creature:FindFirstChild("SelfCollisions") and creature.SelfCollisions.Value
	if not selfCollisions then
		PhysicsService:RegisterCollisionGroup(creatureName)
		PhysicsService:CollisionGroupSetCollidable(creatureName, creatureName, false)
	end

	for _, child in ipairs(creature:GetDescendants()) do
		if child:IsA("BasePart") and child.Transparency ~= 1 then
			child:SetAttribute("TargetTransparency", child.Transparency)
			child.Transparency = 1
		elseif child.Name == "Sparkles" then
			local sparklesVal = Instance.new("ObjectValue")
			sparklesVal.Name = "SparklesValue"
			sparklesVal.Value = child
			sparklesVal.Parent = creature
		end
	end
end

--- // MAIN

for _, creature in ipairs(creatures:GetChildren()) do
	setupCreature(creature)
end

creatureSummonEvents.SummonCreature.OnServerEvent:Connect(summonRequested)
creatureSummonEvents.RemoveCreature.OnServerEvent:Connect(despawnRequested)
summonSystem.CreatureSpawner.ProximityPrompt.Triggered:Connect(suitcaseTriggered)
