
-- 23.10.25: Refactor of script to handle general item pickup

-- Objects involved in stew system:
-- workspace.StewPots
-- RSModules.ShopModule2
-- ServerStorage["Hearty Stew"]

--- // SERVICES
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

--- // OBJECTS
local shopModule2 = require(ReplicatedStorage.RSModules.ShopModule2)
local msgModule = require(ReplicatedStorage.RSModules.MessageSystem)

local stewPots = workspace:FindFirstChild("StewPots")
local tools: Folder = ServerStorage.Tools
local stewTemplate = ServerStorage.Tools.Food["Hearty Stew"]

--- // CONFIG
local creatureConfig = ReplicatedStorage.Configurations.CreatureSystemsConfig
local PURCHASE_TIME_LIMIT = 2 * 60
local TAG_TOOL_PICKUP = "ToolPickup"
local HOLD_DURATION = 0.3
local MAX_ACTIVATION_DISTANCE = 7 -- Max proximity prompt activation distance

--- // VARIABLES
local stewPurchases = {}

--- // FUNCTIONS
local function createPrompt(pickupPart: BasePart, itemName: string): ProximityPrompt
    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = "Pick up " .. itemName
    prompt.HoldDuration = HOLD_DURATION
    prompt.MaxActivationDistance = MAX_ACTIVATION_DISTANCE
    prompt.Parent = pickupPart
    return prompt
end

local function getToolTemplate(itemName: string): Tool?
    local toolTemplate = tools:FindFirstChild(itemName)
    if toolTemplate and toolTemplate:IsA("Tool") then
        return toolTemplate
    else
        -- Some tools are stored within folders inside the Tools folder for organization
        for _, toolContainer: Folder in ipairs(tools:GetChildren()) do
            if not toolContainer:IsA("Folder") then continue end        
            local foundTool = toolContainer:FindFirstChild(itemName)
            if foundTool then
                return foundTool
            end
        end
    end
    return nil
end

local function initializePickupPart(pickupPart: BasePart)
    local itemName = pickupPart:GetAttribute("ItemName") or pickupPart.Name

    local toolTemplate = getToolTemplate(itemName)
    if not toolTemplate then
        warn("Failed to find tool template for item: " .. itemName)
        return
    end

    local prompt = pickupPart:FindFirstChildWhichIsA("ProximityPrompt") or createPrompt(pickupPart, itemName)
    prompt.Triggered:Connect(function(player)
        local purchased, reason = shopModule2.purchaseTool(player, toolTemplate)
        if not purchased then
            msgModule.sendClient(player, reason or "Failed to acquire " .. string.lower(itemName) .. ": " .. tostring(reason))
        end
    end)
end

local function initializeStewPot(pot: Model)
    local stockPot = pot:FindFirstChild("StockPot")
    if not stockPot then
        warn("Failed to find StockPot in stew pot model!")
        return
    end

    local prompt = stockPot:FindFirstChildWhichIsA("ProximityPrompt") or createPrompt(stockPot, stewTemplate.Name)
    prompt.ActionText = "Get " .. stewTemplate.Name

    local price, totalUses = stewTemplate:GetAttribute("Price"), stewTemplate:GetAttribute("TotalUses")
    if price and price ~= 0 then
        prompt.ActionText = prompt.ActionText .. ", " .. price .. " Galleons"
    end

    if totalUses and totalUses > 0 then
        prompt.ActionText = prompt.ActionText .. ", " .. totalUses .. " Uses"
    end

    prompt.Triggered:Connect(function(player)
        local purchased, errMsg = shopModule2.purchaseTool(player, stewTemplate)
        if not purchased then
            msgModule.sendClient(player, errMsg or "Failed to get " .. stewTemplate.Name .. ".")
        end
    end)
end

--- // MAIN
for _, pickupPart: BasePart in ipairs(CollectionService:GetTagged(TAG_TOOL_PICKUP)) do
    initializePickupPart(pickupPart)
end

if stewPots then
	for _, stewPot: Model in pairs(stewPots:GetChildren()) do
		initializeStewPot(stewPot)
	end
end
