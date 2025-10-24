-- General purpose shop module that contains useful functions for managing and checking galleons and adding a tool to the player
-- Also contains functions for checking item caps
-- WARNING: Used by BOTH client and server scripts

local shopModule = {}

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local msgModule = require(ReplicatedStorage:WaitForChild("RSModules"):WaitForChild("MessageSystem"))

local IGNORE_GALLEON_CHECK = true -- Set to true to ignore galleon checks (for testing purposes)
local ITEM_CAP = 3 -- Default item cap

-- Stores how many of an item a player has purchased, and when was the last time they purchased the item
local purchases = {}

local function getGalleonsObject(player)
	local charData = player:FindFirstChild("CharacterData")
	return charData and charData:FindFirstChild("galleons")
end

-- Checks if a player has purchased a maximum quantity of an item within a certain timeframe
function shopModule.purchaseCooldownExceeded(player, item)
	local purchaseInfo = purchases[player]
	if not purchaseInfo then
		return false
	end

	local itemName = item.Name
	local maxPurchases = item:GetAttribute("MaxPurchases")
	local purchaseCooldown = item:GetAttribute("PurchaseCooldown_MIN")

	local itemPurchasesInfo = purchaseInfo[itemName]
	if not itemPurchasesInfo then
		return false
	end

	local totalPurchases = itemPurchasesInfo[1]
	local lastPurchaseTime = itemPurchasesInfo[2]
	local itemPurchaseCooldown = itemPurchasesInfo[3]

	if totalPurchases >= maxPurchases then
		return true
	end
end

function shopModule.sufficientGalleons(player, price)
	local galleons = getGalleonsObject(player)
	if not galleons then
		warn("Failed to get the galleon quantity!")
		return false
	end

	return galleons.Value >= price
end

-- Method to check if the player has sufficient galleons to purchase an ITEM
-- Item must have a "Price" attribute!
function shopModule.galleonRequirementMet(player, item)
	if IGNORE_GALLEON_CHECK then
		warn("Ignoring galleon check for player:", player.Name, "Ensure this is intended!")
		return true
	end

	local galleons = getGalleonsObject(player)
	if not galleons then
		warn("Failed to get the galleon quantity!")
		return false
	end

	local price = item:GetAttribute("Price") or 0

	return galleons.Value >= price
end

-- Method to subtract galleons
-- This does NOT check if the player has sufficient galleons for a purchase, ONLY subtracts!
-- Purchase effect boolean is optional, defaults to true
function shopModule.subtractGalleons(player, amount: number, purchaseEffect: boolean): (boolean)
	local success, result = pcall(function()
		local galleons = getGalleonsObject(player)
		if not galleons then
			warn("Failed to get the galleons object for player:", player.Name)
			return false
		end

		amount = amount or 0
		galleons.Value = math.max(galleons.Value - amount, 0)
		if purchaseEffect == nil then
			purchaseEffect = true
		end

		if purchaseEffect then
			msgModule.sendRandomPosMsg(
				player,
				"-" .. amount .. "$ Galleons",
				nil,
				Color3.new(1, 0.745098, 0.0980392),
				1,
				Color3.new(1, 1, 1),
				"RBLX UI Purchase (SFX)",
				true
			)
		end
	end)

	if not success then
		return false, result
	else
		return true
	end
end

-- Gets the inventory cap for a given item
function shopModule.getItemCap(item: Tool): number
	local itemCap = item:GetAttribute("InventoryCap")
	-- Override checks
	if not itemCap then
		print(item, "has no inventory cap. This is possibly not intentional.")
		itemCap = ITEM_CAP
	elseif itemCap == 0 then
		warn(item, "has a cap of 0! This is not intentional!")
		itemCap = ITEM_CAP
	end

	return itemCap
end

function shopModule.exceededCap(player, item: Tool): boolean
	local backpack = player.Backpack
	local char = player.Character

	if not char or not backpack then
		return true
	end -- Somehow the backpack wasn't found, returning true so the item won't be given

	local itemCap = shopModule.getItemCap(item)
	-- Check how many of the item the player currently has, including in their character model (equipped)
	local totalQuantity = char:FindFirstChild(item.Name) and 1 or 0
	for _, tool in ipairs(backpack:GetChildren()) do
		if tool.Name == item.Name then
			totalQuantity += 1
		end
	end

	print(totalQuantity < itemCap)
	return totalQuantity >= itemCap
end

-- Simply adds a tool to the player's backpack
local function addTool(player, item: Tool)
	local backpack = player:FindFirstChild("Backpack")
	if not backpack then
		warn("Failed to find backpack.")
		return false
	end

	local newFoodTool = item:Clone()
	newFoodTool.Parent = backpack
end

-- This function is a misnomer. You can use it on a tool with a price of 0 to "purchase" it for free.
-- All items are capped at 5, unless configured otherwise through the "InventoryCap" attribute on the tool.
-- Returns true if the purchase was successful, false otherwise.
function shopModule.purchaseTool(player, item: Tool): (boolean, string?)
	local exceededCap = shopModule.exceededCap(player, item)
	if exceededCap then
		return false, "You have reached the maximum quantity for " .. string.lower(item.Name) .. "."
	end

	local galleonMet = shopModule.galleonRequirementMet(player, item)
	if not galleonMet then
		return false, "You do not have enough Galleons to purchase " .. string.lower(item.Name) .. "."
	end

	local price = item:GetAttribute("Price")
	if price and price > 0 then
		local success, result = shopModule.subtractGalleons(player, price, true)
		if not success then
			return false, "Failed to subtract Galleons: " .. tostring(result)
		end
	end

	addTool(player, item)
	return true
end

return shopModule
