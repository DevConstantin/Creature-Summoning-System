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

		collisions = false,
		selfCollisions = false,
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

		collisions = false,
		selfCollisions = false,
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

		collisions = true,
		selfCollisions = true,
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

		collisions = false,
		selfCollisions = false,
	},
}

return CreatureStats
