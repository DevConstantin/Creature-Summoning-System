--- // CREATURE SETUP INFO
-- Add 'Collisions' BoolValue to configure if the creature has collisions or not
-- Add "SelfCollisions" BoolValue to configure if the creature has collisions with itself (so pixies don't collide for instance)
-- Add a "IsFlying" BoolValue to the creature if it's supposed to fly. AlignPosition and AlignOrientation will be set up by 'Utilities' module

local NPC = {}
NPC.__index = NPC

--- // SERVICES
local TweenPlus = game:GetService("TweenService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")
local Debris = game:GetService("Debris")

--- // OBJECTS
local Utilities = require(script.Parent.Utilities)
local creatureStats = require(script.Parent.CreatureStats)
local summonedCreatures = workspace.SummonedCreatures

local visibilityTweenInfo = TweenInfo.new(2)

--- // CONFIG
local SUMMON_SPARKLE_AMOUNT = 10
local MOVEMENT_DELAY = 3 -- Related to sparkle life length
local SPAWN_OFFSET = 3
type Zone = {}

local function createWeld(p1, p2)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = p1
	weld.Part1 = p2
	weld.Parent = p1
	p1.Anchored = false
end

-- Function to spawn an NPC and set up its parts
-- @param spawnCFrame: Where the NPC will spawn
-- @param useFF: Optional, add a force field and make the creature immortal
local function spawnNPC(model, spawnCFrame: CFrame, useFF: boolean)
	local creatureName = model.Name
	model:PivotTo(
		spawnCFrame + Vector3.new(math.random(-SPAWN_OFFSET, SPAWN_OFFSET), 0, math.random(-SPAWN_OFFSET, SPAWN_OFFSET))
	)
	local humrp = model.HumanoidRootPart

	-- Apply a force field, if the creature should use it
	if useFF then
		local safezoneFF = Instance.new("ForceField")
		safezoneFF.Name = "SafezoneFF" -- Need to confirm that this is the correct name
		safezoneFF.Visible = false
		safezoneFF.Parent = model
	end

	local collisions = model:FindFirstChild("Collisions") and model.Collisions.Value or true
	local selfCollisions = model:FindFirstChild("SelfCollisions") and model.SelfCollisions.Value or true

	for _, part in ipairs(model:GetDescendants()) do
		if not part:IsA("BasePart") or part == humrp then
			continue
		end

		createWeld(part, humrp)

		local targetTransparency = part:GetAttribute("TargetTransparency") or 1

		if creatureName == "Dementor" then
			print(part:GetFullName(), targetTransparency)
		end

		if part.Transparency ~= targetTransparency then
			TweenPlus:Create(part, visibilityTweenInfo, { Transparency = targetTransparency }):Play()
		end

		if collisions == false then
			part.CanCollide = false
		end
		if collisions and selfCollisions == false then
			part.CollisionGroup = creatureName
		end
	end

	model.Parent = summonedCreatures
end

-- Main spawn function for an NPC
-- @param isClassSummon: Optional, if the creature is being summoned durring a COMC class, it will not attack the COMC instructor
function NPC.spawn(npcModelTemplate, spawnLocation: CFrame | Vector3, useForceField: boolean?, isClassSummon: boolean?)
	if typeof(spawnLocation) == Vector3 then
		spawnLocation = CFrame.new(spawnLocation)
	end

	local self = setmetatable({}, NPC)

	local model = npcModelTemplate:Clone()
	local creatureName = npcModelTemplate.Name
	local humanoid = model:WaitForChild("Humanoid")

	-- Basic info
	self.model = model
	self.humanoid = humanoid
	self.rootPart = model:WaitForChild("HumanoidRootPart")
	self.creatureName = creatureName
	self.despawning = false

	-- Initialize creature stats
	local stats = creatureStats[creatureName] or creatureStats["Default"]
	self.isAggressive = npcModelTemplate:GetAttribute("Aggressive")
	self.aggression = stats.aggression or 0
	self.fear = stats.fear or 0
	self.attackRange = stats.attackRange or 45
	self.biteRange = stats.biteRange or 10
	self.speedMin = stats.speedMin or 16
	self.speedMax = stats.speedMax or 16
	self.moveToNearby = stats.moveToNearby or false
	self.damagePart = model:FindFirstChild("DamagePart") -- The part that will be used to check for players to damage
	self.trackTarget = nil
	self.isClassSummon = isClassSummon or false

	-- Tables
	self.connections = {}
	self.animations = {}
	local animsFolder = npcModelTemplate:FindFirstChild("Animations")
	if animsFolder then
		for _, animation in ipairs(animsFolder:GetChildren()) do
			self.animations[animation.Name] = animation
		end
	else
		warn("Failed to find animations folder within", npcModelTemplate)
	end

	-- Spawn the creature
	self:playAnimation("Idle")

	if not self.model:FindFirstChild("IsFlying") then
		-- Set a random WalkSpeed, can be updated later
		humanoid.WalkSpeed = math.random(self.speedMin, self.speedMax)

		-- If the creature has a walk animation, switch between walk and idle based on movement
		-- Only do this if the creature has a walk animation
		if self.animations["Walk"] then
			local movementChangedConnect
			movementChangedConnect = humanoid:GetPropertyChangedSignal("MoveDirection"):Connect(function()
				if humanoid.MoveDirection.Magnitude > 0 and self.Animations["Walk"] then
					self:playAnimation("Walk")
				else
					self:playAnimation("Idle")
				end
			end)
			table.insert(self.connections, movementChangedConnect)
		end
	end

	spawnNPC(model, spawnLocation, useForceField)
	self:emitSparkles()

	-- Run aggression functionality
	-- Currently DISABLED, as this is not optimized
	-- if  then
	-- 	local aggroConnect = nil
	-- 	local cooldown = false

	-- 	local speedT, speedInterval = 0, 1.7

	-- 	aggroConnect = RunService.Stepped:Connect(function(dt)
	-- 		if cooldown then
	-- 			return
	-- 		end
	-- 		local destinationEta = self:moveToNearbyTarget(Vector3.new(56.783, 26.334, -24.727))
	-- 		--if destinationEta then
	-- 		--	cooldown = true
	-- 		--	task.wait(destinationEta)
	-- 		--	cooldown = false
	-- 		--end

	-- 		if (os.clock() - speedT) < speedInterval then
	-- 			return
	-- 		end
	-- 		speedT = os.clock()
	-- 		self:updateSpeed(math.random(self.speedMin, self.speedMax))
	-- 	end)

	-- 	table.insert(self.connections, aggroConnect)
	-- end

	return self
end

-- Doesn't seem to work properly when spawning the creature in
function NPC:emitSparkles()
	local sparklesValue = self.model and self.model.Parent and self.model:FindFirstChild("SparklesValue")
	if sparklesValue and sparklesValue.Value then
		print("Emitting sparkles!")
		task.wait()
		sparklesValue.Value:Emit(SUMMON_SPARKLE_AMOUNT)
	else
		warn("Failed to get sparkles for", self.model)
	end
end

-- Method to get NPC's current position
-- @return: NPC's current position
function NPC:getPosition(): Vector3?
	return self.rootPart and self.rootPart.Position
end

-- Method to update the NPC's movement speed
function NPC:updateSpeed(targetSpeed: number)
	local hum = self.humanoid
	--print("Updating speed to", targetSpeed)

	if self.model:FindFirstChild("IsFlying") then
		local humrp = self.model:WaitForChild("HumanoidRootPart")
		local alignPos = humrp:FindFirstChild("AlignPosition")
		if alignPos then
			alignPos.MaxVelocity = targetSpeed
		else
			hum.WalkSpeed = targetSpeed
		end
	else
		hum.WalkSpeed = targetSpeed
	end
end

-- Handle fly movement (uses AlignPosition & AlignOrientation)
local function flyMove(npcModel: Model, currentPos: Vector3, targetPos: Vector3)
	local flightPosPart = npcModel:FindFirstChild("AlignPosPart") or Utilities.setupFlight(npcModel)
	flightPosPart.CFrame = CFrame.lookAlong(targetPos, (targetPos - currentPos).Unit)
end

function NPC:playAnimation(animationType: "Idle" | "Walk" | "Attack" | "Death")
	local animation: Animation = self.animations[animationType]
	local animController = self.model:FindFirstChild("Rig") and self.model.Rig:FindFirstChild("AnimationController")
	if animation and animController then
		local loadedAnim = animController:LoadAnimation(animation)
		loadedAnim:Play()
	else
		warn("Failed to get animation ID for animation type:", animationType, "for", self.creatureName)
	end
end

-- Method to move the NPC to a position
-- @param area: zone value
-- @return: Estimated time to reach the destination
function NPC:moveToPoint(pos: Vector3): number
	if self.despawning then
		return
	end

	if not pos then
		warn("Missing pos value for moveTo function.")
		return
	end

	local currentPos = self:getPosition()
	if self.model:FindFirstChild("IsFlying") then
		flyMove(self.model, currentPos, pos)
	else
		self.humanoid:MoveTo(pos)
	end

	return currentPos and (pos - currentPos).Magnitude / self.humanoid.WalkSpeed
end

-- Method to make an NPC stalk a player
function NPC:trackPlayer(targetPlayer)
	print("Tracking", targetPlayer)
end

-- Method to damage a player near the NPC
function NPC:damageNearby()
	if not self.biteRange or not self.damagePart then
		warn(self.creatureName, "cannot do damage! Missing:", self.biteRange, self.damagePart)
		return
	end
end

-- Generic method to loop through nearby players and move towards one
-- @param zoneArea: Optional parameter. Look for players within the zone
function NPC:moveToNearbyTarget(aggroOrigin: Vector3, zoneArea: Zone)
	local currentPos = self:getPosition()
	if not currentPos then
		warn("Failed to get current position for the NPC!")
		return
	end

	local players = zoneArea and zoneArea:getPlayers() or Players:GetPlayers()
	local closestTarget: Model, closestTargetPos =
		Utilities.getClosest(currentPos, players, self.attackRange, aggroOrigin)
	if closestTargetPos then
		--print("Moving to closest player position of", closestTargetPos)
		self:moveToPoint(closestTargetPos)
	end
end

-- Method to move NPC to a random position within zone / series of nodes. Must input either a roamZone or a table of nodes (parts)
-- @param area: zone class to grab a random position
-- @param nodeTable: list of node parts to move to
function NPC:roam(roamArea: Folder | Zone): number?
	if self.despawning then
		return
	end

	local targetPos = nil
	if typeof(roamArea) == "Instance" and roamArea:IsA("Folder") then
		local roamNodes = roamArea:GetChildren()
		targetPos = roamNodes[math.random(1, #roamNodes)].Position
	elseif roamArea ~= nil then
		targetPos = roamArea:getRandomPoint()
	else
		warn("You must provide either a roam zone object or table of nodes for NPC:roam function!")
		return
	end

	local t = self:moveToPoint(targetPos)
	return t
end

-- Method to respawn an NPC and disconnect all connections
function NPC:despawn()
	if self.model and self.model.Parent then
		self:emitSparkles()
		for _, part in ipairs(self.model:GetDescendants()) do
			if not part:IsA("BasePart") or part.Transparency == 1 then
				continue
			end
			TweenPlus:Create(part, visibilityTweenInfo, { Transparency = 1 }):Play()
		end
		Debris:AddItem(self.model, visibilityTweenInfo.Time)
	end

	for _, connection in ipairs(self.connections) do
		connection:Disconnect()
	end
end

return NPC
