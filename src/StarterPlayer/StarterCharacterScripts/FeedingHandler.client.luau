-- This module handles creature interaction logic on the client side
-- It tracks when the player equips food items, highlights feedable creatures (if any are nearby), and fires server events to feed them
-- It also handles using a leash tool to interact with creatures, using the same highlight and interaction logic
-- IMPORTANT: To mark a tool as a feeding tool, set a "FeedingTool" bool attribute to true on the tool instance

--- // SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

--- // OBJECTS
local localPlayer: Player = Players.LocalPlayer
local character: Model? = localPlayer.Character or localPlayer.CharacterAdded:Wait()
local summonedCreatures: Folder = game.Workspace.SummonedCreatures

local feedEvent: RemoteEvent = ReplicatedStorage.RemoteEvents.CreatureSummonSystem.FeedCreatureEvent

--- // CONFIG
local config = ReplicatedStorage.Configurations.CreatureSystemsConfig
local leashToolName = "Leash"
local INTERACT_RANGE_DEFAULT = config:GetAttribute("InteractRange") or 10 -- Distance within which a creature can be fed

--- // VARIABLES
local interactionHighlight: Highlight? = nil -- Store the highlight instance, reused for efficiency
local highlightConnect = nil
local inputConnect = nil

--- // FUNCTIONS
-------------------- Highlight Instance Management --------------------

-- Get or create the highlight instance, reusing it for efficiency
local function getHighlight(): Highlight
	if interactionHighlight then
		return interactionHighlight
	end

	interactionHighlight = Instance.new("Highlight")
	interactionHighlight.FillColor = Color3.new(1, 1, 1) -- White color for highlighting
	interactionHighlight.FillTransparency = 1
	interactionHighlight.OutlineColor = Color3.new(1, 1, 1) -- White outline
	interactionHighlight.OutlineTransparency = 0
	interactionHighlight.Name = "InteractionHighlight"
	return interactionHighlight
end

-- Apply highlight to the specified creature model
local function setHighlight(creatureModel: Model): Highlight
	local highlight = getHighlight(creatureModel)
	highlight.Adornee = creatureModel
	highlight.Enabled = true
	highlight.Parent = creatureModel
	return highlight
end

-- Remove the highlight from the current creature
local function removeHighlight()
	if interactionHighlight and interactionHighlight.Parent ~= ReplicatedStorage then
		interactionHighlight.Adornee = nil
		interactionHighlight.Parent = ReplicatedStorage
	end
end

--------------------- Creature Highlight Logic --------------------
local function getFeedingTool(): Tool?
	for _, tool in ipairs(character:GetChildren()) do
		if tool:IsA("Tool") and tool:GetAttribute("FeedingTool") == true then
			return tool
		end
	end
	return nil
end

local function getLeashTool(): Tool?
	return character:FindFirstChild(leashToolName) :: Tool?
end

-- Get the closest creature within interaction range
local function getClosestCreature(): Model?
	local closestCreature: Model? = nil
	local closestDistance: number = INTERACT_RANGE_DEFAULT

	for _, creatureModel in ipairs(summonedCreatures:GetChildren()) do
		if creatureModel:GetAttribute("Despawning") == true or creatureModel:GetAttribute("Spawning") == true then
			-- Skip despawning or spawning creatures
			continue
		end

		local creaturePart: BasePart? = creatureModel:FindFirstChild("HumanoidRootPart") :: BasePart?
		if creaturePart then
			local distance: number = (character.PrimaryPart.Position - creaturePart.Position).Magnitude
			if distance < closestDistance then
				closestDistance = distance
				closestCreature = creatureModel
			end
		end
	end

	if closestDistance > INTERACT_RANGE_DEFAULT then
		return nil
	end
	return closestCreature
end

-- Highlight closest creature that can be fed
local function highlightCreature(): boolean
	local interactionTool = getFeedingTool() or getLeashTool()
	if not interactionTool then
		removeHighlight()
		return false
	end

	local closestCreature: Model? = getClosestCreature()
	if not closestCreature then
		removeHighlight()
		return false
	end

	setHighlight(closestCreature)
	return true
end

-------------------- UI Management --------------------
-- Toggle the Creature Management UI visibility. Enabled when a creature is highlighted for interaction, disabled otherwise
local function toggleCreatureManagementFrame(enabled: boolean)
	local summonUI = localPlayer:WaitForChild("PlayerGui"):FindFirstChild("CreatureSummonUI") :: ScreenGui?
	local managementFrame = summonUI and summonUI:FindFirstChild("CreatureManagementFrame") :: Frame?
	local targetCreature: ObjectValue = summonUI and summonUI:FindFirstChild("TargetCreature")
	if managementFrame then
		managementFrame.Visible = enabled
		summonUI.Enabled = true
		targetCreature.Value = enabled and interactionHighlight.Adornee or nil
	else
		warn("Creature management frame not found:", summonUI, managementFrame)
	end
end

--------------------- Creature Interaction Logic --------------------
local function interactWithCreature(input, gpe)
	if gpe then
		return
	end

	local interactionTool = getFeedingTool() or getLeashTool()
	if not interactionTool then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if interactionHighlight and interactionHighlight.Adornee then
			local highlightedCreature: Model = interactionHighlight.Adornee :: Model
			print("Interacting with creature:", highlightedCreature.Name)
			if interactionTool:GetAttribute("FeedingTool") == true then
				print("Feeding creature with tool:", interactionTool.Name)
				feedEvent:FireServer(highlightedCreature, interactionTool.Name)
			else
				print("Using leash on creature:", highlightedCreature.Name)
			end
		end
	end
end

--- // MAIN

-- Listen for tools with the FeedingTool attribute being equipped/unequipped
-- When equipped, start highlighting nearby creatures and listen for input to feed them
character.ChildAdded:Connect(function(child)
	if child:IsA("Tool") and (child:GetAttribute("FeedingTool") == true or child.Name == leashToolName) then
		print("Creature interaction tool equipped")
		highlightConnect = RunService.Heartbeat:Connect(function()
			local foundCreature = highlightCreature()
			toggleCreatureManagementFrame(foundCreature)
		end)
		inputConnect = UserInputService.InputBegan:Connect(interactWithCreature)		-- Listen for input to feed creatures
	end
end)

character.ChildRemoved:Connect(function(child)
	if child:IsA("Tool") and (child:GetAttribute("FeedingTool") == true or child.Name == leashToolName) then
		print("Creature interaction tool unequipped")
		-- Player unequipped a feeding tool
		if highlightConnect then
			toggleCreatureManagementFrame(false)
			highlightConnect:Disconnect()
			highlightConnect = nil
		end

		if inputConnect then
			inputConnect:Disconnect()
			inputConnect = nil
		end	
		-- Remove any existing highlight
		removeHighlight()
	end
end)
