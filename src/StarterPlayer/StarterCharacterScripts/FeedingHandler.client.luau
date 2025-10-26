-- This module handles creature feeding logic on the client side
-- It tracks when the player equips food items, highlights feedable creatures (if any are nearby), and fires server events to feed them
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

local feedingEvent: RemoteEvent = ReplicatedStorage.RemoteEvents.FeedCreatureEvent

--- // CONFIG
local FEEDING_RANGE_DEFAULT = 10 -- Distance within which a creature can be fed

--- // VARIABLES
local feedingHighlight: Highlight? = nil -- Store the highlight instance, reused for efficiency
local highlightConnect = nil
local inputConnect = nil

--- // FUNCTIONS

-------------------- Highlight Management --------------------

-- Get or create the highlight instance, reusing it for efficiency
local function getHighlight(): Highlight
	if feedingHighlight then
		return feedingHighlight
	end

	feedingHighlight = Instance.new("Highlight")
	feedingHighlight.FillColor = Color3.new(1, 1, 1) -- White color for highlighting
	feedingHighlight.FillTransparency = 1
	feedingHighlight.OutlineColor = Color3.new(1, 1, 1) -- White outline
	feedingHighlight.OutlineTransparency = 0
	feedingHighlight.Name = "FeedingHighlight"
	return feedingHighlight
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
	if feedingHighlight and feedingHighlight.Parent ~= ReplicatedStorage then
		feedingHighlight.Adornee = nil
		feedingHighlight.Parent = ReplicatedStorage
	end
end

--------------------- Creature Feeding Logic --------------------
-- Check if the character has a tool that can be used for feeding
local function getFeedingTool(): Tool?
	for _, tool in ipairs(character:GetChildren()) do
		if tool:IsA("Tool") and tool:GetAttribute("FeedingTool") == true then
			return tool
		end
	end
	return nil
end

-- Get the closest creature within feeding range
local function getClosestCreature(): Model?
	local closestCreature: Model? = nil
	local closestDistance: number = FEEDING_RANGE_DEFAULT

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

	if closestDistance > FEEDING_RANGE_DEFAULT then
		return nil
	end

	return closestCreature
end

-- Highlight closest creature that can be fed
local function highlightCreature()
	local feedingTool = getFeedingTool()
	if not feedingTool then
		removeHighlight()
		return
	end

	local closestCreature: Model? = getClosestCreature()
	if closestCreature then
		setHighlight(closestCreature)
	else
		removeHighlight()
		return
	end
end

local function feedCreature(input, gpe)
	if gpe then
		return
	end

	local feedingTool = getFeedingTool()
	if not feedingTool then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if feedingHighlight and feedingHighlight.Adornee then
			local highlightedCreature: Model = feedingHighlight.Adornee :: Model
			print("Feeding creature:", highlightedCreature.Name)
            feedingEvent:FireServer(highlightedCreature)
		end
	end
end

--- // MAIN

-- Listen for tools with the FeedingTool attribute being equipped/unequipped
-- When equipped, start highlighting nearby creatures and listen for input to feed them
character.ChildAdded:Connect(function(child)
	if child:IsA("Tool") and child:GetAttribute("FeedingTool") == true then
		print("Feeding tool equipped")
		-- Player equipped a feeding tool
		highlightConnect = RunService.RenderStepped:Connect(highlightCreature)

		-- Listen for input to feed creatures
		inputConnect = UserInputService.InputBegan:Connect(feedCreature)
	end
end)

character.ChildRemoved:Connect(function(child)
	if child:IsA("Tool") and child:GetAttribute("FeedingTool") == true then
		print("Feeding tool unequipped")
		-- Player unequipped a feeding tool
		if highlightConnect then
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
