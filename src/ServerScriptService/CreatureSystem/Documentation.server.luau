--[[

Documentation for the Creature System. Developed by DevConstantin.

Overview:
 The Creature System is designed to manage the lifecycle, behaviors, and interactions of creatures within the game world.
 This currently includes creature spawning, despawning, walking/flying/moving, and feeding interactions.
 At this time, the system does not handle combat or advanced AI behaviors. It is only used for the Care of Magical Creatures class.

Usage:
-- To remove or add creatures, modify the "Creatures" folder in ServerStorage.
-- To adjust creature roaming zones, modify the "CreatureSummonSystem" folder in Workspace
-- To adjust feeding items, modify the "CookingIngredients" folder in ServerStorage/Tools and add workspace parts with the "FeedingItem" tag.

Creature properties:
-- Adjust creature properties in the "CreatureStats" folder in ReplicatedStorage/DB
-- Add a "IsFlying" BoolValue to the creature if it's supposed to fly. AlignPosition and AlignOrientation will be set up by 'Utilities' module
-- You can place sparkle FX (must be named 'Sparkles') anywhere in the NPC. Creature initialization will set up a "SparklesValue" object value to easily reference them
-- Sounds can be parented to any part in the creature. Just make sure they are named correctly to match the sound types in the code (Idle, Walk, Run, Attack, Death, Scream, Eat, etc)
-- Animations must be placed in an 'Animations' folder within the creature model. They must also be named correctly to match the animation types in the code (Idle, Walk, Run, Attack, Death, etc)
-- Add head part named "Head" or "HeadPart" under creature model (for effects such as feeding hearts). The head part doesn't exist on all creatures, and must be added manually if needed. Will fall back to HRP if not found.

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
