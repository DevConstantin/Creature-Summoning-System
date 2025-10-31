-- Default is used as a fallback if a creature doesn't have unique stats
-- Default must have all stat values
local CreatureStats = {
	["Pixie"] = {
		-- Social
		aggression = 0,
		fear = 0,
		-- Combat
		attackRange = 45,
		-- Movement
		moveSpeed = 18,
		trackSpeed = 20,
		-- Summoning during Care of Magical Creatures
		summonCap = 5,
	},

	["Dementor"] = {
		-- Social
		aggression = 0,
		fear = 0,
		-- Combat
		attackRange = 15,
		biteRange = 10,
		-- Movement
		speedMin = 7,
		speedMax = 7,
		trackSpeed = 20,
		-- Summoning during Care of Magical Creatures
		summonCap = 3,
		moveToNearby = false,
	},

	["Hippogriff"] = {
		-- Social
		aggression = 0,
		fear = 0,
		-- Combat
		attackRange = 0,
		biteRange = 0,
		-- Movement
		speedMin = 7,
		speedMax = 7,
		trackSpeed = 20,
		-- Summoning during Care of Magical Creatures
		summonCap = 1,
		moveToNearby = false,
	},

	["Default"] = {
		-- Social
		aggression = 0,
		fear = 0,
		-- Combat
		attackRange = 15,
		biteRange = 10,
		-- Movement
		speedMin = 16,
		speedMax = 16,
		trackSpeed = 20,
		-- Summoning during Care of Magical Creatures
		summonCap = 3,
		moveToNearby = false,
	},
}

return CreatureStats
