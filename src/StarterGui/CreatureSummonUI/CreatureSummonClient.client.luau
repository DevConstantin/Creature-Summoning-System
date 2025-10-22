--- // SERVICES
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

--- // OBJECTS

local summonedCreatures: Folder = workspace.SummonedCreatures -- Folder containing all currently summoned creatures

local summonUI = script.Parent
local mainFrame = summonUI.MainFrame
local summonFrame = mainFrame.CreatureSpawnFrame
local creatureButtonTemplate = mainFrame.CreatureButton
local limitText = mainFrame.LimitHint -- Text label for the currently selected creature's limit
local maxCreaturesHint = mainFrame.MaxCreaturesHint -- Text label for the global max creatures
local buttonFrame = mainFrame.CreatureSelectionFrame

local creatureSummonEvents = ReplicatedStorage.RemoteEvents.CreatureSummonSystem
local summonCreature = creatureSummonEvents.SummonCreature
local removeCreature = creatureSummonEvents.RemoveCreature

local uiSounds = game:GetService("SoundService"):WaitForChild("UI_Sounds")
local clickSound = uiSounds:WaitForChild("RBLX UI Hover 02 (SFX)")
local hoverSound = uiSounds:WaitForChild("RBLX UI Hover 03 (SFX)")
local confirmSound = uiSounds:WaitForChild("RBLX UI Back (SFX)")

--- // CONFIG
local MAX_CREATURES = 7 -- Must match server config. Used for display purposes only
local SUMMON_SPARKLE_AMOUNT = 10
local frameVisibilityTweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.InOut)

--- // VARIABLES
local INITIAL_POS = mainFrame.Position
local CLOSED_POS = UDim2.new(1.5, 0, INITIAL_POS.Y.Scale, 0)
local initialized = false
local creatureList = nil -- Table of creature names and their limits, received from the server on initialization
local previousSelected = nil
local currentCreature = nil

--- // FUNCTIONS

local function tweenVisibility()
	local visible = summonUI:GetAttribute("FramesVisible")
	TweenService:Create(mainFrame, frameVisibilityTweenInfo, { Position = visible and INITIAL_POS or CLOSED_POS })
		:Play()
end

local function canRequest(): boolean
	return currentCreature ~= nil and typeof(currentCreature) == "string"
end

local function updateButtonLimitText(button: TextButton, applyUnderline: boolean)
	if not button:IsA("TextButton") then return end

	-- Apply an underline to the creature's name, used when selecting a creature in the UI
	local creatureName = button:GetAttribute("Name")
	if applyUnderline then
		creatureName = "<u>" .. creatureName .. "</u>"
	end

	-- Apply limit text
	local currentCount = 0
	for _, creatureModel in ipairs(summonedCreatures:GetChildren()) do
		if creatureModel.Name == creatureName then
			currentCount += 1
		end
	end
	local limit = creatureList and creatureList[creatureName] or 0
	button.TextLabel.Text = string.format("%s (%d / %d)", creatureName, currentCount, limit)
end

local function createCreatureButton(name: string, limit: number)
	local button = creatureButtonTemplate:Clone()
	button.Visible = true
	button:SetAttribute("Name", name)
	button.TextLabel.Text = name
	updateButtonLimitText(button)

	button.MouseButton1Click:Connect(function()
		if previousSelected and previousSelected ~= button then
			print("Restoring previous button (" .. previousSelected.TextLabel.Text .. ") text.")
			previousSelected.TextLabel.Text = previousSelected:GetAttribute("Name")
			updateButtonLimitText(previousSelected)
		end

		previousSelected = button
		currentCreature = name
		updateButtonLimitText(button, button.TextLabel.Text == name) -- I don't even know what this equality test does

		limitText.Text = name .. " Limit: " .. limit

		clickSound:Play()
	end)

	print(name, "button initialized!")
	button.Parent = buttonFrame
end

local function toggleUI(_creatureList)
	summonUI:SetAttribute("FramesVisible", not summonUI:GetAttribute("FramesVisible"))
	tweenVisibility()

	if not summonUI:GetAttribute("FramesVisible") then
		confirmSound:Play()
	end

	if initialized then
		return
	end

	creatureList = _creatureList
	print(creatureList, _creatureList)
	local success, result = pcall(function()
		for name, limit in pairs(creatureList) do
			if limit == 0 then
				warn(name, "has a limit of 0 and cannot be summoned.")
				continue
			end
			createCreatureButton(name, limit)
		end
	end)

	if success then
		initialized = true
	else
		warn("Error when initializing creature summon buttons:", result)
	end
end

local function requestCreature()
	if not canRequest() then
		return
	end
	hoverSound:Play()
	print("Client: Requesting", currentCreature, "to be spawned.")
	summonCreature:FireServer(currentCreature)
end

local function despawnCreature()
	if not canRequest() then
		return
	end
	hoverSound:Play()
	print("Client: Requesting", currentCreature, "to be removed.")
	removeCreature:FireServer(currentCreature)
end

local function updateLimitText()
	maxCreaturesHint.Text = #summonedCreatures:GetChildren() .. " / " .. MAX_CREATURES .. " Creatures Summoned"

	-- Update each creature button to show current limits
	for _, button in pairs(buttonFrame:GetChildren()) do
		updateButtonLimitText(button)
	end
end

-- Used to emit sparkles. For some reason, didn't work effectively when run on the server
local function creatureAdded(creature: Model)
	pcall(function()
		updateLimitText()
		local sparklesValue = creature and creature.Parent and creature:FindFirstChild("SparklesValue")
		if sparklesValue and sparklesValue.Value then
			print("Emitting sparkles!")
			task.wait()
			sparklesValue.Value:Emit(SUMMON_SPARKLE_AMOUNT)
		else
			warn("Failed to get sparkles for", creature)
		end
	end)
end

--- // MAIN
updateLimitText()
summonUI:SetAttribute("FramesVisible", false)
mainFrame.Position = CLOSED_POS
summonUI.Enabled = true

summonedCreatures.ChildAdded:Connect(creatureAdded)
summonedCreatures.ChildRemoved:Connect(updateLimitText)
mainFrame.CloseButton.MouseButton1Click:Connect(toggleUI)
summonFrame.SpawnButton.MouseButton1Click:Connect(requestCreature)
summonFrame.DespawnButton.MouseButton1Click:Connect(despawnCreature)
summonCreature.OnClientEvent:Connect(toggleUI)
