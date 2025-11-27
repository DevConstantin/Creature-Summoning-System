--- // SERVICES
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--- // OBJECTS
local CreatureSummoningService = require(ReplicatedStorage.RSModules.CreatureSummoningService)
local localPlayer: Player = Players.LocalPlayer

-- UI objects
local managementFrame: Frame = script.Parent.CreatureManagementFrame
local creatureSelectionFrame: Frame = managementFrame.CreatureSelectionFrame
local titleLabel: TextLabel = managementFrame.Title
local buttonTemplate: TextButton = managementFrame.ManagementButtonTemplate
local targetCreature: ObjectValue = script.Parent.TargetCreature -- ObjectValue to keep track of the creature (model) we want to interact with. This value is updated within FeedingHandler player script, which handles creature rendering

-- Remote events
local creatureEvents = ReplicatedStorage.RemoteEvents.CreatureSummonSystem
local manageCreatureEvent: RemoteEvent = creatureEvents.ManageCreatureEvent
local despawnCreatureEvent: RemoteEvent = creatureEvents.RemoveCreature

-- Sounds
local uiSounds = game:GetService("SoundService"):WaitForChild("UI_Sounds")
local clickSound = uiSounds:WaitForChild("RBLX UI Hover 02 (SFX)")
local hoverSound = uiSounds:WaitForChild("RBLX UI Hover 03 (SFX)")
local confirmSound = uiSounds:WaitForChild("RBLX UI Back (SFX)")

--[[
    Adding New Commands
    1. Add new command to the table below. Add a 'valid command' check in CreatureSummonSystem.server.luau
    2. Add command check under initializeButton function
    3. Account for command in creatureActionRequested (CreatureSummonSystem.server.luau)
    4. Ensure the creature handles the command correctly
]]
local commands = {
    "Stay",
    "Roam",
    "Despawn",
    "Follow", -- Follow self
    -- MoveTo, -- Move to a Vector3 position
}

--- // FUNCTIONS

-- @param action string - The action to request ("Stay", "Roam", "Despawn")
-- @param target Model | Vector3? - The target model (to follow) or position (to move to), if applicable
local function requestCreatureAction(action: string, target: (Model | Vector3)?)
    -- Sends the desired action, the creature to perform it to, and either another model or vector 3
    manageCreatureEvent:FireServer(action, targetCreature.Value, target)
end

------------------ Button Initialization ------------------
local function initializeButton(command: string)
    local button: TextButton = buttonTemplate:Clone()
    button.Name = command .. "_Button"
    button.TextLabel.Text = command
    button.Visible = true

    button.MouseButton1Click:Connect(function()
        clickSound:Play()

        local targetCreatureModel: Model? = targetCreature.Value
        if targetCreatureModel == nil then
            return
        end

        local isGamekeeper, reason = CreatureSummoningService.isGamekeeper(localPlayer)
        if not isGamekeeper then
            warn("You are not the gamekeeper and cannot issue creature commands. Reason:", reason)
        end

        -- These basic commands don't require any additional functionality (at this time)
        if command == "Stay" or command == "Roam" or command == "Follow" then
            requestCreatureAction(command)
        elseif command == "Despawn" then
            despawnCreatureEvent:FireServer(targetCreatureModel)
        --elseif command == "Follow Target" then
            -- Will require unique functionality for selecting a target, if implemented
        else
            warn("Invalid creature command:", command) -- Shouldn't be necessary, but good practice
        end
    end)

    button.Parent = creatureSelectionFrame
end

local function updateTitle()
    local targetCreature: Instance? = targetCreature.Value
    titleLabel.Text = targetCreature and targetCreature.Name or "Manage Creature" -- Fallback to "Manage Creature" if no target.
end

targetCreature:GetPropertyChangedSignal("Value"):Connect(updateTitle)

--- // MAIN
for _, command in ipairs(commands) do
    initializeButton(command)
end