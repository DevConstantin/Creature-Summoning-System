-- Default is used as a fallback if a creature doesn't have unique stats
-- Default must have all stat values
local CreatureStats = {
	["Pixie"] = {
		aggression = 0,
		fear = 0,
		attackRange = 45,
		moveSpeed = 18,
		trackSpeed = 20,
	},

	["Dementor"] = {
		aggression = 0,
		fear = 0,

		attackRange = 15,
		biteRange = 10,

		speedMin = 7,
		speedMax = 7,
		trackSpeed = 20,

		moveToNearby = false,
	},

	["Default"] = {
		aggression = 0,
		fear = 0,

		attackRange = 15,
		biteRange = 10,

		speedMin = 16,
		speedMax = 16,
		trackSpeed = 20,

		moveToNearby = false,
	},
}

return CreatureStats
