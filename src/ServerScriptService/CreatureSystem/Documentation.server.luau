--[[

Documentation for the Creature System. Developed by DevConstantin.

Overview:
 The Creature System is designed to manage the lifecycle, behaviors, and interactions of creatures within the game world.
 This currently includes creature spawning, despawning, walking/flying/moving, and feeding interactions.
 At this time, the system does not handle combat or advanced AI behaviors. It is only used for the Care of Magical Creatures class.

WARNING:
 ShopSystemModule2: Ensure ignore galleon check is false for LIVE environment

Required instances:
 Workspace
  - CreatureSummonSystem (Folder) -- Main folder for the Creature Summoning System, containing all necessary creature spawn instances
  - PixieRoamArea (Folder) -- Contains waypoints for pixies, which fly around the area
  - SummonedCreatures (Folder) -- Stores all currently summoned creatures near the COMC area, used by client & server

 ReplicatedStorage
  - Assets:         Particles.HeartsFX (ParticleEmitter)
  - DB:             CreatureStats (Folder)
  - Configurations: CreatureSystemsConfig (Configuration)
  - RSModules:      CreatureSummoningService, Pathfinding, MessageSystem (warnings), ShopModule2 (feeding item pickups), Zone (Creature roaming), DebugService (optional)
  - RemoteEvents:   CreatureSummonSystem, FeedCreatureEvent, Message system events

 ServerScriptService
   - CreatureSystem (Folder)
   - ToolPickupHandler (Script) -- For handling tools that can feed creatures (meat, fish, etc.)

 ServerStorage
    - Creatures (Folder) -- Contains creature models and related assets
    - Tools: CookingIngredients (Folder) -- Contains feeding tools and ingredients

 StarterGui
  - CreatureSummonUI
  - MessageGui (for warnings and messages)

 StarterPlayer
   - StarterCharacters: FeedingHandler (Script) -- For handling feeding tools on the client side

-- ]]
