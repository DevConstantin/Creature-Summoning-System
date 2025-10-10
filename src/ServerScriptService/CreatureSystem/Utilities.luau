local Utilities = {}

-- Method to setup the necessary instances and prepare an NPC model for flight
function Utilities.setupFlight(npcModel)
	local success, result = pcall(function()
		local humrp = npcModel:WaitForChild("HumanoidRootPart")

		local alignPosPart = Instance.new("Part")
		alignPosPart.CanCollide = false
		alignPosPart.CanQuery = false
		alignPosPart.Transparency = 1
		alignPosPart.Name = "AlignPosPart"
		alignPosPart.Size = Vector3.new(1, 1, 1)
		alignPosPart.Anchored = true

		local a0 = humrp:FindFirstChild("Attachment")
		if not a0 then
			a0 = Instance.new("Attachment")
			a0.Parent = humrp
		end

		local a1 = alignPosPart:FindFirstChild("Attachment")
		if not a1 then
			a1 = Instance.new("Attachment")
			a1.Parent = alignPosPart
		end

		local alignPos = humrp:FindFirstChild("AlignPosition")
		if not alignPos then
			alignPos = Instance.new("AlignPosition")
			alignPos.Attachment0 = a0
			alignPos.Attachment1 = a1
			alignPos.MaxVelocity = math.random(7, 16)
			alignPos.Responsiveness = 20
			--alignPos.MaxForce = math.huge
			alignPos.Parent = humrp
		end

		local alignOri = humrp:FindFirstChild("AlignOrientation")
		if not alignOri then
			alignOri = Instance.new("AlignOrientation")
			alignOri.Attachment0 = a0
			alignOri.Attachment1 = a1
			alignOri.Responsiveness = 30
			--alignOri.RigidityEnabled = true
			alignOri.Parent = humrp
		end

		alignPosPart.Parent = npcModel

		return alignPosPart
	end)

	if not success then
		warn("Error while attempting to fly", npcModel, ":", result)
	else
		return result
	end
end

-- Method to check if point 1 and point 2 are within 'range' of each of each other
function Utilities.inProximity(p1, p2, range)
	if p1 and typeof(p1) == Vector3 and p2 and typeof(p2) == Vector3 and range and typeof(range) == "number" then
		return (p2 - p1).Magnitude <= range
	else
		warn("Invalid value inputted into inProximity function!", p1, p2, range)
	end
end

-- Method to get the closest instance to the current position
-- @param list: A list of objects to loop through, either players or characters
-- @param aggroRange: Optional, range for the creature to consider targets. Defaults to math.huge
-- @param aggroOrigin: Optional, the origin of the aggro range to consider targets, so the creature can't wander forever. Defaults to currentPos if nil
function Utilities.getClosest(currentPos, list, aggroRange, aggroOrigin)
	if not aggroRange then
		aggroRange = math.huge
	end
	if aggroOrigin then
		currentPos = aggroOrigin
	end

	local closestTarget, closestPlayerDistance, closestTargetPos = nil, nil, nil
	for _, target in ipairs(list) do
		local char = (target:IsA("Player") and target.Character) or target
		local humrp = char and char:FindFirstChild("HumanoidRootPart")
		if not humrp then
			continue
		end

		local distance = (humrp.Position - currentPos).Magnitude

		if distance > aggroRange then
			continue
		elseif (not closestPlayerDistance) or (distance < closestPlayerDistance) then
			closestTarget = char
			closestPlayerDistance = distance
			closestTargetPos = humrp.Position
		end
	end

	local targetHumrp = closestTarget and closestTarget:FindFirstChild("HumanoidRootPart")
	if not targetHumrp then
		return
	end
	local velocityOffset = targetHumrp.AssemblyLinearVelocity * 0.32
	-- Predict where the player will be in PREDICTION_TIME seconds
	return closestTarget, targetHumrp.Position
end

return Utilities
