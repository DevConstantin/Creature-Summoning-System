
-- Documentation for the Creature System

--[[
Overview: 
 The Creature System is designed to manage the lifecycle, behaviors, and interactions of creatures within the game world. This currently includes spawning, despawning, walking/flying/moving, and player feeding interactions.
 At this time, the system does not handle combat or advanced AI behaviors. It is only used for the Care of Magical Creatures class.

Required instances:
 ReplicatedStorage
  - Assets:         Particles.HeartsFX (ParticleEmitter)
  - DB:             CreatureStats (Folder)
  - Configurations: CreatureSystemsConfig (Configuration)
  - RSModules:      CreatureSummoningService, Pathfinding
  - RemoteEvents:   CreatureSummonSystem, FeedCreatureEvent

 ServerScriptService
   - CreatureSystem (Folder)
   - ToolPickupHandler (Script) -- For handling tools that can feed creatures (meat, fish, etc.)

 ServerStorage
    - Creatures (Folder) -- Contains creature models and related assets
    - Tools: CookingIngredients (Folder) -- Contains feeding tools and ingredients

 StarterGui
  - CreatureSummonUI

 StarterPlayer
   - StarterCharacters: FeedingHandler (Script) -- For handling feeding tools on the client side

-- ]]
