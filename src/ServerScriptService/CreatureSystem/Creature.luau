--- // CREATURE SETUP INFO
-- Add 'Collisions' BoolValue to configure if the creature has collisions or not
-- Add "SelfCollisions" BoolValue to configure if the creature has collisions with itself (so pixies don't collide for instance)
-- Add a "IsFlying" BoolValue to the creature if it's supposed to fly. AlignPosition and AlignOrientation will be set up by 'Utilities' module
-- You can place sparkle FX (must be named 'Sparkles') anywhere in the NPC. Creature initialization will set up a "SparklesValue" object value to easily reference them

local NPC = {}
NPC.__index = NPC

--- // SERVICES
local TweenPlus = game:GetService("TweenService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")
local Debris = game:GetService("Debris")

--- // OBJECTS
local Utilities = require(script.Parent.Utilities)
local creatureStats = require(script.Parent.CreatureStats)
local summonedCreatures = workspace.SummonedCreatures
local Pathfinding = require(ReplicatedStorage.RSModules.Pathfinding)

local visibilityTweenInfo = TweenInfo.new(2, Enum.EasingStyle.Exponential, Enum.EasingDirection.In)

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
	self.humanoidRootPart = model.HumanoidRootPart
	local humanoid = model.Humanoid

	-- Basic info
	self.model = model
	self.head = model:FindFirstChild("Head") or model:FindFirstChild("HeadPart")
	self.humanoid = humanoid
	self.rootPart = model:WaitForChild("HumanoidRootPart")
	self.creatureName = creatureName
	self.despawning = false -- Flag to prevent actions such as movement when despawning

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

	self.targetDestination = nil

	-- Tables
	self.connections = {}
	self.animations = {} -- Raw Animation objects
	self.loadedAnimations = {} -- Cached AnimationTracks
	self.activeAnimations = {} -- Currently playing tracks

	-- Sounds may be parented to different parts for better emission control
	self.sounds = {}
	for _, sound in ipairs(model:GetDescendants()) do
		if sound:IsA("Sound") then
			self.sounds[sound.Name] = sound
		end
	end

	local animsFolder = npcModelTemplate:FindFirstChild("Animations")
	if animsFolder then
		for _, animation in ipairs(animsFolder:GetChildren()) do
			self.animations[animation.Name] = animation
		end
	else
		warn("Failed to find animations folder within", npcModelTemplate)
	end

	-- For whatever reason, the hippogriff walk animation will not play unless set here first
	if self.creatureName == "Hippogriff" then
		self:playAnimation("Walk")
	else
		self:playAnimation("Idle")
	end

	if not self.model:FindFirstChild("IsFlying") then
		humanoid.WalkSpeed = math.random(self.speedMin, self.speedMax)

		local hasWalk = self.animations["Walk"] ~= nil
		if hasWalk then
			-- Store connection for cleanup
			table.insert(self.connections, humanoid.Running:Connect(function(speed)
				if math.floor(speed) > 0 then
					self:playAnimation("Walk")
				else
					self:stopAnimation("Walk")
					self:playAnimation("Idle")
				end
			end))
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

------------------------------------------------ EFFECT & SOUND METHODS ------------------------------------------------
-- Doesn't seem to work properly when spawning the creature in
-- Important: The object value for sparkles is stored in the template creatures upon initialization (under CreatureSummonSystem script)
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

function NPC:playSound(soundType: "Move" | "Run" | "Attack" | "Scream" | "Death")
	local sound = self.sounds[soundType]
	if sound then
		sound:Play()
	else
		warn("Failed to find sound:", soundType, "on", self.creatureName)
	end
end

function NPC:stopSound(soundType: "Move" | "Run" | "Attack" | "Scream" | "Death")
	local sound = self.sounds[soundType]
	if sound and sound.IsPlaying then
		sound:Stop()
	else
		warn("Failed to find sound:", soundType, "on", self.creatureName)
	end
end

------------------------------------------------ UTILITY METHODS ------------------------------------------------
-- Method to get NPC's current position
-- @return: NPC's current position
function NPC:getPosition(): Vector3?
	return self.rootPart and self.rootPart.Position
end

--------------------------------------------- ANIMATION METHODS ---------------------------------------------
function NPC:playAnimation(animationType: "Idle" | "Walk" | "Attack" | "Death")
    -- If already playing this animation, don't restart it
    if self.activeAnimations[animationType] and self.activeAnimations[animationType].IsPlaying then
        return
    end

    local animation: Animation = self.animations[animationType]
    local animController = self.model:FindFirstChild("Rig") and self.model.Rig:FindFirstChild("AnimationController")
    
    if not animation or not animController then
        warn("Failed to get animation ID for animation type:", animationType, "for", self.creatureName)
        return
    end

    -- Load animation once and cache it
    if not self.loadedAnimations[animationType] then
        local loadedAnim = animController:LoadAnimation(animation)
        loadedAnim.Name = animationType
        self.loadedAnimations[animationType] = loadedAnim
		print("Play animation function:", animationType, "cached for", self.creatureName)
    end

    local track = self.loadedAnimations[animationType]
    track:Play()
    self.activeAnimations[animationType] = track

    print("Now playing animation", animationType, "for", self.creatureName)
end

function NPC:stopAnimation(animationType: "Idle" | "Walk" | "Attack" | "Death" | "All")
    if animationType == "All" then
        for name, track in pairs(self.activeAnimations) do
            track:Stop()
        end
        table.clear(self.activeAnimations)
		print("All animations stopped for", self.creatureName)
    else
        local track = self.activeAnimations[animationType]
        if track then
			print("Stopping", animationType, "animation for", self.creatureName)
            track:Stop()
            self.activeAnimations[animationType] = nil
        end
    end
end

--------------------------------------------- MOVEMENT METHODS ---------------------------------------------
function NPC:canMove(): boolean
	return not self.despawning and self.humanoid.Health > 0 and not self.model:GetAttribute("UnderPetrificus")
end

-- @return speed of the creature. WARNING: This function can return 0, which must be accounted for in any calculations!
function NPC:getSpeed(): number
	local speed = 16
	if self.model:FindFirstChild("IsFlying") then
		local alignPos = Utilities.getFlightInstances(self.model)
		if alignPos then
			speed = alignPos.MaxVelocity
		else
			speed = self.humanoid.WalkSpeed
		end
	else
		speed = self.humanoid.WalkSpeed
	end
	return speed > 0 and speed or 16
end

-- Method to update the NPC's movement speed
function NPC:updateSpeed(targetSpeed: number)
	local hum = self.humanoid
	--print("Updating speed to", targetSpeed)

	-- Account for flying creatures, which use separate functionality
	if self.model:FindFirstChild("IsFlying") then
		local alignPos = Utilities.getFlightInstances(self.model)
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

-- Method to move the NPC to a position
-- @param area: zone value
-- @return: Estimated time to reach the destination. Will return nil if the creature is stationary, which shouldn't happen
function NPC:moveToPoint(pos: Vector3): number?
	if not self:canMove() then
		return nil
	end

	if not pos then
		warn("Missing pos value for moveTo function.")
		return nil
	end

	self.targetDestination = pos
	local targetDestination = pos
	local currentPos = self:getPosition()
	local speed = self:getSpeed()
	if speed <= 0 then
		warn("Creature", self.creatureName, "has 0 speed! Cannot move.")
		return nil
	end

	-- Handle flying creatures separately
	if self.model:FindFirstChild("IsFlying") then
		flyMove(self.model, currentPos, pos)
		return (currentPos and (pos - currentPos).Magnitude / speed)
	end

	-- Handle ground movement with pathfinding
	local pathWaypoints = Pathfinding:GetWaypoints(self.creatureName, currentPos, pos)

	-- Fallback: If pathfinding fails, move directly to the point
	if not pathWaypoints or #pathWaypoints == 0 then
		warn("Failed to get path waypoints for", self.creatureName, "from", currentPos, "to", pos)
		self.humanoid:MoveTo(pos)
		local travelTime = currentPos and (pos - currentPos).Magnitude / speed
		print("Moving", self.creatureName, "to", pos, "from", currentPos, "Travel time:", travelTime)
		return travelTime
	end

	task.spawn(function()
		for num, waypoint in ipairs(pathWaypoints) do
			if not self:canMove() or targetDestination ~= self.targetDestination then
				break
			end
			self.humanoid:MoveTo(waypoint.Position)
			print("Moving to waypoint ", num, "at", waypoint.Position, "for", self.creatureName)

			-- Frankly this is a mess, but MoveToFinished is choppy resulting in stuttered movement
			-- Also this should ideally be on the client
			local MoveToFinished = false
			local ListenConn
			ListenConn = self.humanoid.MoveToFinished:connect(function()
				ListenConn:Disconnect()
				MoveToFinished = true
			end)

			while MoveToFinished == false do
				local wpDistance = (self.humanoidRootPart.Position - waypoint.Position).Magnitude
				local distFactor = 3.3
				if wpDistance <= distFactor then
					ListenConn:Disconnect()
					break
				end
				RunService.Heartbeat:Wait()
			end
		end
	end)

	local travelDistance = 0
	for i = 2, #pathWaypoints do
		travelDistance += (pathWaypoints[i].Position - pathWaypoints[i - 1].Position).Magnitude
	end
	local travelTime = travelDistance / speed
	return travelTime
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
	if not self:canMove() then
		return
	end

	local targetPos = nil
	if typeof(roamArea) == "Instance" and roamArea:IsA("Folder") then
		local roamNodes = roamArea:GetChildren()
		if #roamNodes == 0 then 
			warn("Roam area", roamArea, "is missing destination nodes!")
			return nil
		end
		targetPos = roamNodes[math.random(1, #roamNodes)].Position
	elseif roamArea ~= nil then
		targetPos = roamArea:getRandomPoint()
	else
		warn("You must provide either a roam zone object or table of nodes for NPC:roam function!")
		return nil
	end

	local t = self:moveToPoint(targetPos)
	return t
end

-- Method to make an NPC stalk a player
function NPC:trackPlayer(targetPlayer: Player)
	print("Tracking", targetPlayer)
end

--------------------------------------------- COMBAT METHODS ---------------------------------------------
-- Method to damage a player near the NPC
function NPC:damageNearby()
	if not self.biteRange or not self.damagePart then
		warn(self.creatureName, "cannot do damage! Missing:", self.biteRange, self.damagePart)
		return
	end
end

--------------------------------------------- DESPAWN METHOD ---------------------------------------------

-- Method to respawn an NPC and disconnect all connections
function NPC:despawn()
	self.despawning = true
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
	table.clear(self.connections)
    table.clear(self.loadedAnimations)
end

return NPC
