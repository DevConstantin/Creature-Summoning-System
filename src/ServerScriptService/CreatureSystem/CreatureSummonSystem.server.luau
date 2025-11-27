--- // SERVICES
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhysicsService = game:GetService("PhysicsService")

--- // OBJECTS
local CreatureModule = require(script.Parent.Creature)
local CreatureStats = require(ReplicatedStorage.DB.CreatureStats)
local CreatureSummoningService = require(ReplicatedStorage.RSModules.CreatureSummoningService)
local MessageModule = ReplicatedStorage.RSModules:FindFirstChild("MessageModule")
MessageModule = MessageModule and require(MessageModule)

local creatures: Folder = ServerStorage.Creatures
local summonSystem: Folder = workspace.CreatureSummonSystem
local summonedCreaturesFolder: Folder = workspace.SummonedCreatures
local summonBriefcase: BasePart = summonSystem.CreatureSpawner
local targetSpawn: BasePart = summonSystem.CreatureSpawn
local creatureZone = CreatureModule.CreatureZone
local leashTemplate: Tool = ServerStorage.Tools:FindFirstChild("Leash")

local creatureEvents = ReplicatedStorage.RemoteEvents.CreatureSummonSystem
local manageCreatureEvent: RemoteEvent = creatureEvents.ManageCreatureEvent

--- // CONFIG
local config = ReplicatedStorage.Configurations.CreatureSystemsConfig
local MOVEMENT_DELAY = 3 -- How long until the creature can move. Related to sparkle life length
local MAX_CREATURES = config:GetAttribute("MaxCreatures") or 7 -- Max number of creatures allowed to be summoned at once. Set to 0 or nil for unlimited (not recommended)
local MAX_DESPAWN_DISTANCE = config:GetAttribute("MaxDespawnDistance") or 200 -- Max distance from the spawn point before a creature despawns itself
local MAX_DESPAWN_TIME = config:GetAttribute("MaxDespawnTime") or 60 -- Max time (in seconds) to wait for a creature to reach the despawn point before forcing despawn

local activeCreatures = {} -- Table to hold references for creature classes & creatures that are active in the game world
local creaturesList = {} -- Dictionary of creatures and their limits, sent to clients
type NPC = CreatureModule.NPC

--- // FUNCTIONS

-- Helper function to get a creature class from the creature model or creature name
local function getCreatureClass(creature: Model | string): (Model?, NPC?)
	if typeof(creature) == "string" then -- Try to get the first creature with this name
		for creatureModel: Model, creatureClass: NPC in pairs(activeCreatures) do
			if creatureClass.despawning then
				continue
			end

			if creatureClass.creatureName == creature then
				return creatureModel, creatureClass
			end
		end
	else
		return creature, activeCreatures[creature]
	end
end
------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------ Summon Functions ------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------------
-- Function to despawn all creatures
local function despawnCreatures()
	for creatureModel: Model, creatureClass: NPC in pairs(activeCreatures) do
		local success, result = pcall(function()
			creatureClass:despawn()
		end)

		if not success then
			creatureModel:Destroy()
		end
	end
end

local function despawnRequested(player, creature: string | Model)
	local isGamekeeper, reason = CreatureSummoningService.isGamekeeper(player)
	if not isGamekeeper then
		warn(player, "is not the gamekeeper but attempted to despawn a creature! Possible exploit?")
		return
	end

	print("Looking to despawn a", creature, "Active creatures:", activeCreatures)
	local creatureModel: Model?, creatureClass: NPC? = getCreatureClass(creature)

	-- Despawn the first creature found of the requested type
	local success, result = pcall(function()
		local moveTime = creatureClass:moveToPoint(targetSpawn.Position)
		moveTime = math.clamp(moveTime, 0, MAX_DESPAWN_TIME)
		creatureClass.despawning = true
		-- Wait until the creature reaches the spawn position / briefcase, then despawn
		task.wait(moveTime + 0.5) -- Wait until the creature reaches the briefcase
		creatureClass:despawn()
		activeCreatures[creatureModel] = nil
	end)

	if not success then
		warn("Error while attempting to despawn creature class:", result)
		creatureModel:Destroy()
		activeCreatures[creatureModel] = nil
	end

	print("Final active creatures:", activeCreatures)
end

local function summonRequested(player, creatureType: string)
	local canSummon, reason = CreatureSummoningService.canSummonCreature(player, creatureType, creaturesList)
	if not canSummon then
		warn("Unable to summon", creatureType, reason)
		if MessageModule then
			MessageModule.sendWarning(player, reason)
		end
		return
	end

	local creatureModelTemplate = creatures:FindFirstChild(creatureType)
	if not creatureModelTemplate then
		warn("Failed to get a creature model for creatureType:", creatureType)
		return
	end

	local creature =
		CreatureModule.spawn(creatureModelTemplate, summonedCreaturesFolder, targetSpawn.CFrame, true, true)
	activeCreatures[creature.model] = creature

	creature:startRoaming()
end

----------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------ Creature Management Functions ----------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------------

-- This is not ideal but it's serviceable with a small number of commands. Make sure to update this along with the table in LeashHandler.client.luau
-- Despawn command is not applicable here, as the despawn command runs the separate despawning functionality
local function isValidCommand(command): boolean
	return command == "Stay" or command == "Roam" or command == "Follow"
end

local function creatureActionRequested(
	player: Player,
	command: string,
	creatureModel: Model,
	target: (Model | Vector3)?
)
	if not isValidCommand(command) then
		warn("Invalid command requested. Possible exploit? Player:", player, player.UserId, command)
		return
	end

	-- It's possible that the player will have a leash item without being the gamekeeper
	local isGamekeeper, _ = CreatureSummoningService.isGamekeeper(player, true)
	if not isGamekeeper then
		MessageModule.sendWarning("Only the gamekeeper can interact with these creatures!")
		return
	end

	if not creatureModel or typeof(creatureModel) ~= "Instance" or not creatureModel:IsA("Model") then
		warn("Invalid creature requested. Possible exploit? Player:", player, player.UserId, creatureModel)
		return
	end

	local _, creatureClass = getCreatureClass(creatureModel)
	if not creatureClass then
		warn("CreatureSummonSystem | Action requested, but failed to get creature class.", command, creatureModel)
	end

	print(creatureClass)

	creatureClass:stopMoving() -- Stop any active movement behavior
	if command == "Stay" then
		creatureClass:stopMoving()
	elseif command == "Roam" then
		creatureClass:startRoaming()
	elseif command == "Follow" then
		local playerChar: Model? = player.Character
		creatureClass:followTarget(playerChar)
	end
end

----------------------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------ Suitcase & Setup Functions ------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------------

local function addLeashTool(player: Player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		warn("Failed to find backpack for player:", player.Name)
		return
	end

	if backpack:FindFirstChild("Leash") or player.Character:FindFirstChild("Leash") then
		-- Player already has a leash tool
		return
	end

	if not leashTemplate then
		warn("Leash tool template not found in ServerStorage.Tools")
		return
	end

	local leashTool = leashTemplate:Clone()
	leashTool.Parent = backpack
end

-- Open creature summon GUI for the player, if they are the gamekeeper
local function suitcaseTriggered(player)
	local isGamekeeper, _ = CreatureSummoningService.isGamekeeper(player, true)
	if isGamekeeper then
		print(creaturesList)
		summonBriefcase.Sparkles:Emit(10)
		creatureEvents.SummonCreature:FireClient(player, creaturesList)
		addLeashTool(player)
	else
		warn("Only the Care of Magical Creatures instructor can use this.")
		if MessageModule then
			MessageModule.sendWarning(player, "Only the Care of Magical Creatures instructor can use this.")
		end
	end
end

-- Initial setup for each creature model, including validation
local function setupCreature(creature: Model)
	-- Ensure the creature model has the necessary components
	-- if not creature:FindFirstChild("Rig") then
	-- 	error("Creature model " .. creature.Name .. " is missing a Rig!")
	-- end

	-- Ensure the creature model has an Animations folder with at least an Idle animation
	local animations = creature:FindFirstChild("Animations")
	if not animations then
		error("Creature model " .. creature.Name .. " is missing an Animations folder!")
	elseif #animations:GetChildren() == 0 then
		error("Creature model " .. creature.Name .. " has no animations!")
	end

	-- Ensure all sounds are parented to a BasePart or Attachment
	for _, sound in ipairs(creature:GetDescendants()) do
		if sound:IsA("Sound") and not sound.Parent:IsA("BasePart") and not sound.Parent:IsA("Attachment") then
			warn(
				"Sound",
				sound.Name,
				"in creature",
				creature.Name,
				"is not parented to a BasePart or Attachment. This may cause issues."
			)
		end
	end

	-- Access the creature's stats, or use Default if none are found
	local creatureName = creature.Name
	local creatureStats = CreatureStats[creatureName]
	if not creatureStats then
		warn("No stats found for creature:", creatureName, "Using Default stats.")
		creatureStats = CreatureStats["Default"]
	end

	local summonLimit = creatureStats.summonCap
	if summonLimit and summonLimit > 0 then
		creaturesList[creature.Name] = math.min(summonLimit, MAX_CREATURES > 0 and MAX_CREATURES or summonLimit)
	end

	-- Setup collision group for the creature to avoid self-collisions
	local selfCollisions: boolean? = creature:FindFirstChild("SelfCollisions") and creature.SelfCollisions.Value
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

manageCreatureEvent.OnServerEvent:Connect(creatureActionRequested)
creatureEvents.SummonCreature.OnServerEvent:Connect(summonRequested)
creatureEvents.RemoveCreature.OnServerEvent:Connect(despawnRequested)
summonBriefcase.ProximityPrompt.Triggered:Connect(suitcaseTriggered)
