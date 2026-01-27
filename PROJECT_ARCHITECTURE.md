# Trainyourslave - Project Architecture Documentation

## 🎮 Game Concept

**Trainyourslave** is a tower defense/auto-battler game where players:
1. **Place helpers** on a grid-based island
2. **Purchase units** from a shop system
3. **Start waves** of enemies that spawn and fight helpers
4. **Merge helpers** to upgrade them (3 same units → 1 upgraded unit)
5. **Earn coins** from combat and passive generation
6. **Survive waves** with increasing difficulty

### Core Gameplay Loop
```
Shop → Buy Helper → Place on Grid → Start Wave → Combat → Win/Lose → Reset → Next Wave
```

---

## 📁 Project Structure

### Recommended Clean Structure

```
src/
├── ServerScriptService/
│   ├── Core/
│   │   ├── WaveManager.server.lua          # Wave spawning & progression
│   │   └── CombatService.server.lua         # Combat logic (attacks, movement)
│   │
│   ├── Helpers/
│   │   ├── HelperPlacement.server.lua      # Helper placement validation
│   │   ├── GridHelperSpawnerServer.server.lua  # Grid placement & spawning
│   │   ├── HelperBlueprintManager.server.lua  # Blueprint system (persistence)
│   │   ├── HelperMerge.server.lua          # Merge 3 → 1 upgrade system
│   │   ├── HelperRespawn.server.lua        # Respawn dead helpers
│   │   ├── HelperShop.server.lua           # Shop system for buying helpers
│   │   ├── HelperPurchaseHandler.server.lua  # Purchase handling & passive bonuses
│   │   └── HelperMoveServer.server.lua     # Server-authoritative helper movement
│   │
│   ├── Enemies/
│   │   └── EnemyMerge.server.lua           # Enemy merge system
│   │
│   ├── Economy/
│   │   ├── CoinSystem.server.lua           # Coin management (merged)
│   │   └── LeaderStats.server.lua          # Leaderboard stats
│   │
│   ├── Special/
│   │   └── TweakerCharge.server.lua        # Special ability for Tweaker unit
│   │
│   └── Utils/
│       ├── RigAnimator.server.lua           # Animation utilities
│       └── DisablePlayerCollision.server.lua  # Player collision management
│
├── StarterPlayer/
│   └── StarterPlayerScripts/
│       ├── Client.client.lua               # Main client entry point
│       ├── GridPlacementSystem.client.lua  # Grid placement UI logic
│       ├── MountUI.lua                     # React UI mounting
│       └── UpdateStatsDisplay.client.lua   # Stats display updates
│
├── ReplicatedStorage/
│   ├── Remotes/
│   │   ├── StartWaveEvent                  # Start wave request
│   │   ├── PlaceHelperEvent               # Place helper request
│   │   ├── RequestBuyHelper               # Buy helper request
│   │   ├── RequestPlaceHelper             # Place helper request
│   │   ├── HelperResponse                 # Helper placement response
│   │   ├── ShopEvent                      # Shop updates
│   │   └── WaveStateEvent                 # Wave state changes
│   │
│   ├── Shared/
│   │   ├── RootUI.luau                    # Main React UI root
│   │   ├── ShopUI.luau                    # Shop UI component
│   │   ├── HelperPlacementUI.luau         # Helper placement UI
│   │   ├── StartWaveUI.luau                # Start wave button UI
│   │   └── Hello.luau                     # (Test file - can remove)
│   │
│   └── Packages/
│       └── React, ReactRoblox, etc.        # React dependencies
│
├── ServerStorage/
│   ├── HelperTemplates/                   # Helper unit templates
│   ├── EnemyTemplates/                    # Enemy unit templates
│   ├── Assets/                           # Other assets
│   └── Modules/                          # Shared server modules
│
└── Workspace/
    ├── Island/                           # Island models (one per player)
    │   └── [Island_001, Island_002, ...]
    │       ├── Gridfloor                 # Battle grid (BasePart)
    │       └── Attributes:
    │           ├── IslandId (number)
    │           └── OwnerUserId (number)
    │
    ├── Helpers/                          # Active helper instances (auto-created)
    └── Enemies/                          # Active enemy instances (auto-created)
```

---

## 🔧 System Architecture

### 1. **Wave System** (`Core/WaveManager.server.lua`)
**Purpose**: Manages wave progression, enemy spawning, and wave state

**Key Functions**:
- `startWaveForPlayer(player)` - Starts a wave for a player's island
- `spawnEnemiesForWaveOnIsland(island, userId, wave)` - Spawns enemies for a wave
- `freezeNPC(npc, isEnemy)` / `unfreezeNPC(npc, isEnemy)` - Freezes/unfreezes NPCs
- `getWavePlan(wave)` - Calculates wave difficulty and enemy count

**State Management**:
- `activeWavesByIsland[islandId]` - Tracks active wave loops
- `waveActiveFlags[islandId]` - Tracks if wave is active (for combat)
- `currentWaveNumbers[islandId]` - Current wave number per island

**Data Flow**:
```
Player clicks "Start Wave" 
  → StartWaveEvent fired
  → WaveManagerServer.startWaveForPlayer()
  → Spawns enemies (frozen)
  → Unfreezes all NPCs
  → Combat loop starts
  → Win/Lose conditions checked
  → Reset helpers from blueprints
  → Spawn next wave (frozen)
```

---

### 2. **Combat System** (`Core/CombatService.server.lua`)
**Purpose**: Handles combat between helpers and enemies

**Key Functions**:
- `doAttack(attacker, target, damage, attackSpeed, range, grid)` - Performs attack
- `findNearestTarget(attackerRoot, targets, grid)` - Finds nearest target
- `constrainToGrid(position, grid)` - Constrains movement to grid bounds

**Combat Loop** (runs every `TICK_RATE` seconds):
1. Iterate all helpers → find nearest enemy → attack or move closer
2. Iterate all enemies → find nearest helper → attack or move closer
3. Enforce grid boundaries (continuous check)

**Grid Boundary Enforcement**:
- NPCs can only move within their assigned grid
- Positions are continuously checked and constrained
- Velocities are zeroed if NPC goes outside bounds

---

### 3. **Helper Placement System** (`Helpers/HelperPlacement.server.lua` + `Helpers/GridHelperSpawnerServer.server.lua`)
**Purpose**: Handles helper purchase and placement on grid

**Key Functions**:
- `requestBuyHelper(player, helperType)` - Validates purchase and adds to inventory
- `requestPlaceHelper(player, gridId, row, col, helperType)` - Places helper on grid

**Placement Rules**:
- Players can only place on rows 1-5 (their side of grid)
- Enemies spawn on rows 6-10
- Grid cells are 5x5 studs
- Each grid is 10x10 cells (50x50 studs)

**Data Flow**:
```
Client: Click shop item
  → RequestBuyHelper event
  → Server validates coins
  → Adds to player inventory (Inv_<UnitName> attribute)
  → Client: Click grid cell
  → RequestPlaceHelper event
  → Server validates placement
  → Spawns helper from template
  → Saves blueprint
  → Places helper on grid
```

---

### 4. **Blueprint System** (`Helpers/HelperBlueprintManager.server.lua`)
**Purpose**: Persists helper configurations across waves

**Key Concepts**:
- **Blueprint**: Authoritative copy stored in `ServerStorage/HelperBlueprints`
- **Board Instance**: Active helper in `Workspace/Helpers` that fights

**Lifecycle**:
1. **Placement**: Create board instance + save blueprint
2. **During Wave**: Board instances fight (can die)
3. **Wave End**: Destroy board instances, respawn fresh from blueprints

**Key Functions**:
- `saveBlueprint(boardInstance)` - Saves helper state to blueprint
- `spawnFromBlueprint(blueprint)` - Creates board instance from blueprint
- `_G.ResetHelpersOnIsland(islandId)` - Resets all helpers for an island

**Attributes Stored**:
- `HelperType`, `GridId`, `PlaceRow`, `PlaceCol`
- `StarLevel`, `BaseDamage`, `BaseHealth`, `BaseRange`
- `OriginalCFrame`, `OriginalWalkSpeed`, `OriginalJumpPower`

---

### 5. **Merge System** (`Helpers/HelperMerge.server.lua`)
**Purpose**: Upgrades helpers by merging 3 identical units

**Merge Rules**:
- 3 same helper type + same star level + same island → 1 upgraded unit
- Stats multiply by 2
- Star level increases by 1
- Position: Uses position of first helper in merge group

**Key Functions**:
- `checkAndMergeHelpers()` - Checks for mergeable groups and merges
- `getUnitKey(model)` - Gets unit identifier
- `getStarLevel(model)` - Gets star level

**Data Flow**:
```
3 helpers placed next to each other
  → Merge check runs (periodic or on placement)
  → If 3 match: destroy 3, spawn 1 upgraded
  → Update blueprint with new stats
```

---

### 6. **Shop System** (`Helpers/HelperShop.server.lua`)
**Purpose**: Manages shop UI and helper purchases

**Key Functions**:
- `_G.ShopService.Send(player)` - Sends shop data to client
- `_G.ShopService.Buy(player, slotIndex)` - Processes purchase
- `generateShopOffers()` - Generates random shop offers

**Shop Mechanics**:
- 5 slots with random units
- Units have cost and weight (rarity)
- Units added to player inventory (`Inv_<UnitName>` attribute)
- Shop refreshes after wave completion

---

### 7. **Economy System**
**Files**: `Economy/CoinSystem.server.lua` (merged), `Economy/LeaderStats.server.lua`

**Coin Sources**:
- Combat rewards (enemy deaths)
- Passive generation over time
- Wave completion bonuses

**Storage**:
- Coins stored in `leaderstats.Coins` (IntValue) or `Player.Coins` attribute
- Leaderboard integration via `LeaderStatsHandler`

---

### 8. **Helper Movement System** (`Helpers/HelperMoveServer.server.lua`)
**Purpose**: Server-authoritative helper movement validation

**Key Functions**:
- Validates helper move requests from clients
- Ensures moves stay within player rows (1-5)
- Updates grid cell occupancy
- Maintains server authority over helper positions

---

### 9. **UI System** (React-based)
**Files**: `RootUI.luau`, `ShopUI.luau`, `HelperPlacementUI.luau`, `StartWaveUI.luau`

**Architecture**:
- React components in `ReplicatedStorage/Shared`
- Mounted via `MountUI.lua` in `StarterPlayerScripts`
- Global state: `_G.ShopUIData`, `_G.HelperPlacementData`, `_G.StartWaveUIData`
- Updates trigger re-renders

**Components**:
- `RootUI` - Main container
- `ShopUI` - Shop interface
- `HelperPlacementUI` - Grid placement interface
- `StartWaveUI` - Wave start button

---

## 🔄 Data Flow Diagrams

### Helper Placement Flow
```
Client (GridPlacementSystem)
  ↓
RequestBuyHelper RemoteEvent
  ↓
HelperPlacement.server.lua
  ↓
Validates coins → Adds to inventory
  ↓
RequestPlaceHelper RemoteEvent
  ↓
GridHelperSpawnerServer.server.lua
  ↓
Validates placement → Spawns helper
  ↓
HelperBlueprintManager.saveBlueprint()
  ↓
Helper placed in Workspace/Helpers
```

### Wave Start Flow
```
Client (StartWaveUI)
  ↓
StartWaveEvent RemoteEvent
  ↓
WaveManagerServer.startWaveForPlayer()
  ↓
Spawns enemies (frozen)
  ↓
Unfreezes all NPCs
  ↓
CombatService starts combat loop
  ↓
Win/Lose conditions checked
  ↓
ResetHelpersOnIsland() → Respawn from blueprints
  ↓
Spawn next wave (frozen)
```

### Combat Flow
```
RunService.Heartbeat (every frame)
  ↓
CombatService.mainLoop()
  ↓
For each helper:
  - Find nearest enemy
  - If in range: attack
  - If out of range: move closer (constrained to grid)
  ↓
For each enemy:
  - Find nearest helper
  - If in range: attack
  - If out of range: move closer (constrained to grid)
  ↓
Grid boundary enforcement (continuous)
```

---

## 🗂️ File Organization Recommendations

### Current Issues
1. **Duplicate/Redundant Files**:
   - `EnemySpawnTest.server.lua` - Test file, should be removed or moved to tests/
   - `ServerStorage/EnemyTemplates/WaveManagerServer.server.lua` - Wrong location, should be removed
   - `HelperRespawnManager.server.lua` vs `HelperRestore.server.lua` vs `HelperRoundReset.server.lua` - May have overlapping functionality

2. **Unclear Responsibilities**:
   - `GridHelperSpawnerServer.server.lua` vs `HelperPlacement.server.lua` - Both handle placement
   - `HelperShopServer.server.lua` vs `ShopService.server.lua` - Both handle shop

3. **Missing Organization**:
   - All server scripts in one folder (hard to navigate)
   - No clear separation of concerns

### Recommended Cleanup

#### 1. Consolidate Helper Systems
**Merge into single files**:
- `HelperPlacement.server.lua` + `GridHelperSpawnerServer.server.lua` → `Helpers/HelperPlacement.server.lua`
- `HelperShopServer.server.lua` + `ShopService.server.lua` → `Helpers/HelperShop.server.lua`
- `HelperRespawnManager.server.lua` + `HelperRestore.server.lua` + `HelperRoundReset.server.lua` → Review and consolidate into `Helpers/HelperRespawn.server.lua`

#### 2. Organize by System
Create folders:
```
ServerScriptService/
├── Core/          # Core game systems
├── Helpers/       # Helper-related systems
├── Enemies/       # Enemy-related systems
├── Economy/       # Economy systems
├── Special/      # Special abilities
└── Utils/         # Utility scripts
```

#### 3. Remove Test/Duplicate Files
- Delete `EnemySpawnTest.server.lua` (or move to tests/)
- Delete `ServerStorage/EnemyTemplates/WaveManagerServer.server.lua`
- Review and remove duplicate functionality

#### 4. Standardize Naming
- All server scripts: `*.server.lua`
- All client scripts: `*.client.lua`
- All shared modules: `*.lua` or `*.luau`

---

## 📊 Key Data Structures

### Helper Attributes
```lua
Helper:SetAttribute("HelperType", "MagicHobo")
Helper:SetAttribute("GridId", "Workspace.Island.Island_001.Gridfloor")
Helper:SetAttribute("PlaceRow", 3)
Helper:SetAttribute("PlaceCol", 5)
Helper:SetAttribute("OwnerUserId", 12345)
Helper:SetAttribute("IslandId", 1)
Helper:SetAttribute("StarLevel", 2)
Helper:SetAttribute("BaseDamage", 12)
Helper:SetAttribute("BaseHealth", 100)
Helper:SetAttribute("BaseRange", 14)
Helper:SetAttribute("AttackDamage", 24)  -- BaseDamage * (2^StarLevel)
Helper:SetAttribute("AttackRange", 14)
Helper:SetAttribute("AttackCooldown", 1.1)
Helper:SetAttribute("OriginalCFrame", CFrame.new(...))
Helper:SetAttribute("OriginalWalkSpeed", 16)
Helper:SetAttribute("OriginalJumpPower", 50)
Helper:SetAttribute("Frozen", false)
Helper:SetAttribute("Aggressive", true)
```

### Enemy Attributes
```lua
Enemy:SetAttribute("UnitType", "EnemyGrunt")
Enemy:SetAttribute("GridId", "Workspace.Island.Island_001.Gridfloor")
Enemy:SetAttribute("IslandId", 1)
Enemy:SetAttribute("TargetUserId", 12345)
Enemy:SetAttribute("Wave", 5)
Enemy:SetAttribute("IsMiniBoss", false)
Enemy:SetAttribute("IsBoss", false)
Enemy:SetAttribute("StarLevel", 0)
Enemy:SetAttribute("BaseDamage", 8)
Enemy:SetAttribute("BaseHealth", 150)
Enemy:SetAttribute("BaseRange", 7)
Enemy:SetAttribute("DamageMult", 1.5)  -- Wave difficulty multiplier
Enemy:SetAttribute("SpawnRow", 7)
Enemy:SetAttribute("SpawnCol", 3)
```

### Island Attributes
```lua
Island:SetAttribute("IslandId", 1)  -- Must be number
Island:SetAttribute("OwnerUserId", 12345)  -- Player who owns this island
```

### Player Attributes
```lua
Player:SetAttribute("Coins", 500)
Player:SetAttribute("Inv_MagicHobo", 2)
Player:SetAttribute("Inv_Appraiser", 1)
Player:SetAttribute("Inv_Indigenous", 0)
```

---

## 🔌 Remote Events

### Client → Server
- `StartWaveEvent` - Start a wave
- `RequestBuyHelper` - Buy a helper from shop
- `RequestPlaceHelper` - Place helper on grid
- `PlaceHelperEvent` - Place helper (alternative)

### Server → Client
- `HelperResponse` - Helper placement response
- `ShopEvent` - Shop data updates
- `GridOwnershipEvent` - Grid ownership changes
- `WaveStateEvent` - Wave state changes (active/inactive)

### BindableEvents
- `RestoreTweakerCart` - Restore Tweaker's cart
- `WaveStateEvent` - Wave state changes (internal)

---

## 🎯 Core Game Logic Summary

1. **Player joins** → Gets assigned an island (or claims one)
2. **Player shops** → Buys helpers → Added to inventory
3. **Player places** → Validates grid cell → Spawns helper → Saves blueprint
4. **Player starts wave** → Spawns enemies → Unfreezes NPCs → Combat begins
5. **Combat** → Helpers attack enemies, enemies attack helpers → Grid boundaries enforced
6. **Wave ends** → Win: Reset helpers from blueprints, spawn next wave | Lose: Game over
7. **Merge** → 3 same helpers → 1 upgraded helper (stats x2, star +1)
8. **Economy** → Coins earned from combat → Used to buy more helpers

---

## 🚀 Next Steps for Cleanup

1. **Create folder structure** (Core/, Helpers/, Enemies/, Economy/, etc.)
2. **Move files** to appropriate folders
3. **Consolidate duplicate functionality** (placement, shop, respawn)
4. **Remove test/duplicate files**
5. **Update imports** in all files to reflect new structure
6. **Test** to ensure everything still works
7. **Document** any remaining edge cases

---

## 📝 Notes

- **Grid System**: 10x10 grid, 5 studs per cell, 50x50 stud total
- **Player Rows**: 1-5 (helpers)
- **Enemy Rows**: 6-10 (enemies)
- **Island System**: Multi-island support, one player per island
- **Blueprint System**: Helpers persist across waves via blueprints
- **React UI**: Uses React-Roblox for UI rendering
- **Combat**: Real-time, grid-constrained, wave-based

---

**Last Updated**: December 2024
**Version**: 2.0 (Post-Cleanup)
