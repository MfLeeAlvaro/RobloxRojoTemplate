# File Structure Reference

## ✅ Complete File List (Clean Structure)

This document lists all files that should exist in the cleaned-up project structure.

---

## 📁 ServerScriptService

### Core/
- `WaveManager.server.lua` - Wave spawning, progression, NPC freeze/unfreeze
- `CombatService.server.lua` - Combat logic, attacks, movement
- `GridBoundaryEnforcement.server.lua` - (Optional) Extracted grid boundary logic

### Helpers/
- `HelperPlacement.server.lua` - Helper purchase & placement validation
- `GridHelperSpawnerServer.server.lua` - Grid placement & spawning logic
- `HelperBlueprintManager.server.lua` - Blueprint persistence system
- `HelperMerge.server.lua` - Merge 3 → 1 upgrade system
- `HelperRespawn.server.lua` - Respawn dead helpers, reset after waves
- `HelperShop.server.lua` - Shop UI & purchase handling (merged)
- `HelperPurchaseHandler.server.lua` - Purchase handling & passive bonuses
- `HelperMoveServer.server.lua` - Server-authoritative helper movement

### Enemies/
- `EnemySpawner.server.lua` - (Optional) Extracted enemy spawn logic
- `EnemyMerge.server.lua` - Enemy merge system (if used)

### Economy/
- `CoinSystem.server.lua` - Coin collection, passive generation, management (merged)
- `LeaderStats.server.lua` - Leaderboard stats handling

### Special/
- `TweakerCharge.server.lua` - Tweaker unit special ability

### Utils/
- `RigAnimator.server.lua` - Animation utilities
- `DisablePlayerCollision.server.lua` - Player collision management

---

## 📁 StarterPlayer/StarterPlayerScripts

- `Client.client.lua` - Main client entry point
- `GridPlacementSystem.client.lua` - Grid placement UI logic
- `MountUI.lua` - React UI mounting
- `UpdateStatsDisplay.client.lua` - Stats display updates

---

## 📁 ReplicatedStorage

### Remotes/
- `StartWaveEvent` (RemoteEvent) - Start wave request
- `PlaceHelperEvent` (RemoteEvent) - Place helper request
- `RequestBuyHelper` (RemoteEvent) - Buy helper request
- `RequestPlaceHelper` (RemoteEvent) - Place helper request
- `HelperResponse` (RemoteEvent) - Helper placement response
- `ShopEvent` (RemoteEvent) - Shop data updates
- `WaveStateEvent` (BindableEvent) - Wave state changes

### Shared/
- `RootUI.luau` - Main React UI root component
- `ShopUI.luau` - Shop UI component
- `HelperPlacementUI.luau` - Helper placement UI component
- `StartWaveUI.luau` - Start wave button UI component

### Packages/
- `React` - React library
- `ReactRoblox` - React-Roblox bindings
- (Other React dependencies)

---

## 📁 ServerStorage

### HelperTemplates/
- `MagicHobo` (Model) - Helper unit template
- `Appraiser` (Model) - Helper unit template
- `Indigenous` (Model) - Helper unit template
- `Tweaker` (Model) - Helper unit template
- (Other helper templates)

### EnemyTemplates/
- `EnemyGrunt` (Model) - Basic enemy template
- `Goons` (Model) - Enemy template
- `Guz` (Model) - Enemy template
- `Donald` (Model) - Enemy template
- `MoneyMan` (Model) - Enemy template
- `MiniBoss` (Model) - Mini boss template
- `Boss` (Model) - Boss template

### Assets/
- (Other assets)

### Modules/
- (Shared server modules, if any)

### HelperBlueprints/
- (Auto-created folder for blueprints)
- `{GridId}:{Row}:{Col}` (Model) - Blueprint instances

---

## 📁 Workspace

### Island/
- `Island_001` (Model) - Island instance
  - `Gridfloor` (BasePart) - Battle grid
  - Attributes:
    - `IslandId` (number)
    - `OwnerUserId` (number)
- `Island_002` (Model) - (Additional islands)
- (More islands as needed)

### Helpers/
- (Auto-created folder)
- `{HelperType}_{UserId}_{Timestamp}` (Model) - Active helper instances

### Enemies/
- (Auto-created folder)
- `{EnemyType}_{IslandId}_{Timestamp}` (Model) - Active enemy instances

---

## 📁 Root Level

- `README.md` - Project readme
- `PROJECT_ARCHITECTURE.md` - System architecture documentation
- `CLEANUP_GUIDE.md` - Cleanup instructions
- `FILE_STRUCTURE_REFERENCE.md` - This file
- `WAVE_SYSTEM_SETUP_GUIDE.md` - Wave system setup guide
- `wally.toml` - Wally package manager config
- `wally.lock` - Wally lock file
- `aftman.toml` - Aftman config
- `default.project.json` - Rojo project config
- `sourcemap.json` - Rojo sourcemap

---

## 🗑️ Files to Remove

### Test Files
- `src/ServerScriptService/EnemySpawnTest.server.lua`
- `src/ServerStorage/EnemyTemplates/WaveManagerServer.server.lua`
- `src/ReplicatedStorage/Shared/Hello.luau`

### Duplicate Files (After Merge)
- `src/ServerScriptService/GridHelperSpawnerServer.server.lua` (merged into HelperPlacement)
- `src/ServerScriptService/HelperShopServer.server.lua` (merged into HelperShop)
- `src/ServerScriptService/ShopService.server.lua` (merged into HelperShop)
- `src/ServerScriptService/HelperRespawnManager.server.lua` (merged into HelperRespawn)
- `src/ServerScriptService/HelperRestore.server.lua` (merged into HelperRespawn)
- `src/ServerScriptService/HelperRoundReset.server.lua` (merged into HelperRespawn)
- `src/ServerScriptService/CoinCollectionHandler.server.lua` (merged into CoinSystem)
- `src/ServerScriptService/PassiveCoinGenerator.server.lua` (merged into CoinSystem)
- `src/ServerScriptService/LeaderStatsHandler.server.lua` (renamed to LeaderStats)
- `src/ServerScriptService/HelperPurchaseHandler.server.lua` (check if duplicate)

---

## 📊 File Count Summary

### Server Scripts
- **Core**: 2 files
- **Helpers**: 8 files
- **Enemies**: 1 file
- **Economy**: 2 files
- **Special**: 1 file
- **Utils**: 2 files
- **Total**: 16 server scripts

### Client Scripts
- **StarterPlayerScripts**: 4 files

### UI Components
- **Shared**: 4 React components

### Remote Events
- **Remotes**: 7 RemoteEvents/BindableEvents

### Templates
- **HelperTemplates**: Variable (depends on units)
- **EnemyTemplates**: Variable (depends on enemies)

---

## 🔍 Quick Reference: File Purposes

| File | Purpose | Key Functions |
|------|---------|---------------|
| `WaveManager.server.lua` | Wave system | `startWaveForPlayer()`, `spawnEnemiesForWaveOnIsland()` |
| `CombatService.server.lua` | Combat logic | `doAttack()`, `findNearestTarget()` |
| `HelperPlacement.server.lua` | Helper placement | `requestBuyHelper()`, `requestPlaceHelper()` |
| `HelperBlueprintManager.server.lua` | Blueprint system | `saveBlueprint()`, `spawnFromBlueprint()` |
| `HelperMerge.server.lua` | Merge system | `checkAndMergeHelpers()` |
| `HelperShop.server.lua` | Shop system | `_G.ShopService.Send()`, `_G.ShopService.Buy()` |
| `CoinSystem.server.lua` | Economy | `getCoins()`, `setCoins()`, passive generation |
| `TweakerCharge.server.lua` | Special ability | Tweaker charge logic |

---

## 📝 Notes

- All server scripts should be `.server.lua`
- All client scripts should be `.client.lua`
- React components should be `.luau`
- RemoteEvents are created dynamically in scripts (not files)
- Folders like `Helpers/`, `Enemies/` are auto-created by scripts
- Blueprint folder is auto-created by HelperBlueprintManager

---

**Last Updated**: December 2024
**Version**: 2.0 (Post-Cleanup)
