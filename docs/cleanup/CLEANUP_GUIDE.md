# Project Cleanup Guide

## 🎯 Goal
Reorganize the project structure to be more maintainable, easier to track, and follow best practices.

---

## 📋 Pre-Cleanup Checklist

Before starting, ensure you have:
- [ ] Git commit of current state (backup)
- [ ] All systems tested and working
- [ ] List of all RemoteEvents and their usage
- [ ] List of all global functions (`_G.*`)

---

## 🗂️ Current File Issues

### Files to Remove/Consolidate

1. **Test Files**:
   - `src/ServerScriptService/EnemySpawnTest.server.lua` - Test file, remove or move to `tests/`
   - `src/ServerStorage/EnemyTemplates/WaveManagerServer.server.lua` - Wrong location, remove

2. **Duplicate Functionality**:
   - `HelperPlacement.server.lua` + `GridHelperSpawnerServer.server.lua` → Merge
   - `HelperShopServer.server.lua` + `ShopService.server.lua` → Merge
   - `HelperRespawnManager.server.lua` + `HelperRestore.server.lua` + `HelperRoundReset.server.lua` → Review and consolidate

3. **Unused/Test Files**:
   - `src/ReplicatedStorage/Shared/Hello.luau` - Test file, can remove

---

## 📁 Recommended New Structure

```
src/
├── ServerScriptService/
│   ├── Core/
│   │   ├── WaveManager.server.lua
│   │   ├── CombatService.server.lua
│   │   └── GridBoundaryEnforcement.server.lua  (extracted from CombatService)
│   │
│   ├── Helpers/
│   │   ├── HelperPlacement.server.lua          (merged from HelperPlacement + GridHelperSpawnerServer)
│   │   ├── HelperSpawner.server.lua            (extracted spawn logic)
│   │   ├── HelperBlueprintManager.server.lua
│   │   ├── HelperMerge.server.lua              (renamed from HelperMergeServer)
│   │   ├── HelperRespawn.server.lua            (merged from HelperRespawnManager + HelperRestore + HelperRoundReset)
│   │   └── HelperShop.server.lua               (merged from HelperShopServer + ShopService)
│   │
│   ├── Enemies/
│   │   ├── EnemySpawner.server.lua             (extracted from WaveManagerServer)
│   │   └── EnemyMerge.server.lua               (renamed from EnemyMergeServer)
│   │
│   ├── Economy/
│   │   ├── CoinSystem.server.lua               (merged from CoinCollectionHandler + PassiveCoinGenerator)
│   │   └── LeaderStats.server.lua              (renamed from LeaderStatsHandler)
│   │
│   ├── Special/
│   │   └── TweakerCharge.server.lua
│   │
│   └── Utils/
│       └── RigAnimator.server.lua
│
├── StarterPlayer/
│   └── StarterPlayerScripts/
│       ├── Client.client.lua
│       ├── GridPlacementSystem.client.lua
│       ├── MountUI.lua
│       └── UpdateStatsDisplay.client.lua
│
├── ReplicatedStorage/
│   ├── Remotes/
│   │   ├── StartWaveEvent
│   │   ├── PlaceHelperEvent
│   │   ├── RequestBuyHelper
│   │   ├── RequestPlaceHelper
│   │   ├── HelperResponse
│   │   ├── ShopEvent
│   │   └── WaveStateEvent
│   │
│   ├── Shared/
│   │   ├── RootUI.luau
│   │   ├── ShopUI.luau
│   │   ├── HelperPlacementUI.luau
│   │   └── StartWaveUI.luau
│   │
│   └── Packages/
│       └── (React dependencies)
│
├── ServerStorage/
│   ├── HelperTemplates/
│   ├── EnemyTemplates/
│   ├── Assets/
│   └── Modules/
│
└── Workspace/
    ├── Island/
    ├── Helpers/  (auto-created)
    └── Enemies/  (auto-created)
```

---

## 🔧 Step-by-Step Cleanup Process

### Phase 1: Create Folder Structure

1. **Create new folders**:
   ```bash
   mkdir src/ServerScriptService/Core
   mkdir src/ServerScriptService/Helpers
   mkdir src/ServerScriptService/Enemies
   mkdir src/ServerScriptService/Economy
   mkdir src/ServerScriptService/Special
   mkdir src/ServerScriptService/Utils
   ```

2. **Create Remotes folder** (if not exists):
   ```bash
   mkdir src/ReplicatedStorage/Remotes
   ```

### Phase 2: Move Files to New Locations

#### Core Systems
- `WaveManagerServer.server.lua` → `Core/WaveManager.server.lua`
- `CombatService.server.lua` → `Core/CombatService.server.lua`

#### Helper Systems
- `HelperPlacement.server.lua` → `Helpers/HelperPlacement.server.lua`
- `GridHelperSpawnerServer.server.lua` → `Helpers/HelperPlacement.server.lua` (merge)
- `HelperBlueprintManager.server.lua` → `Helpers/HelperBlueprintManager.server.lua`
- `HelperMergeServer.server.lua` → `Helpers/HelperMerge.server.lua`
- `HelperShopServer.server.lua` → `Helpers/HelperShop.server.lua` (merge with ShopService)
- `ShopService.server.lua` → `Helpers/HelperShop.server.lua` (merge)

#### Enemy Systems
- `EnemyMergeServer.server.lua` → `Enemies/EnemyMerge.server.lua`

#### Economy Systems
- `CoinCollectionHandler.server.lua` → `Economy/CoinSystem.server.lua` (merge)
- `PassiveCoinGenerator.server.lua` → `Economy/CoinSystem.server.lua` (merge)
- `LeaderStatsHandler.server.lua` → `Economy/LeaderStats.server.lua`

#### Special Systems
- `TweakerCharge.server.lua` → `Special/TweakerCharge.server.lua`

#### Utils
- `RigAnimator.server.lua` → `Utils/RigAnimator.server.lua`

### Phase 3: Consolidate Duplicate Files

#### Merge HelperPlacement + GridHelperSpawnerServer

**New file**: `Helpers/HelperPlacement.server.lua`

Combine:
- Placement validation from `HelperPlacement.server.lua`
- Grid spawning logic from `GridHelperSpawnerServer.server.lua`
- Island ownership tracking from `GridHelperSpawnerServer.server.lua`

**Key functions to merge**:
- `requestBuyHelper()` - from HelperPlacement
- `requestPlaceHelper()` - from HelperPlacement
- `getAllGridFloors()` - from GridHelperSpawnerServer
- `notifyGridOwnership()` - from GridHelperSpawnerServer

#### Merge HelperShopServer + ShopService

**New file**: `Helpers/HelperShop.server.lua`

Combine:
- Shop UI management from `ShopService.server.lua`
- Helper purchase handling from `HelperShopServer.server.lua`

**Key functions to merge**:
- `_G.ShopService.Send()` - from ShopService
- `_G.ShopService.Buy()` - from ShopService
- Shop offer generation - from ShopService
- Helper purchase validation - from HelperShopServer

#### Consolidate Helper Respawn Systems

**New file**: `Helpers/HelperRespawn.server.lua`

Review and combine:
- `HelperRespawnManager.server.lua` - Main respawn logic
- `HelperRestore.server.lua` - Restore functionality
- `HelperRoundReset.server.lua` - Round reset logic

**Key functions to keep**:
- Respawn dead helpers during wave
- Reset helpers after wave end
- Restore helper state

#### Merge Coin Systems

**New file**: `Economy/CoinSystem.server.lua`

Combine:
- `CoinCollectionHandler.server.lua` - Coin collection from combat
- `PassiveCoinGenerator.server.lua` - Passive coin generation

**Key functions to merge**:
- `handleCoinCollection()` - from CoinCollectionHandler
- `generatePassiveCoins()` - from PassiveCoinGenerator
- `getCoins(player)` - unified function
- `setCoins(player, amount)` - unified function

### Phase 4: Remove Unused Files

1. **Delete test files**:
   - `src/ServerScriptService/EnemySpawnTest.server.lua`
   - `src/ServerStorage/EnemyTemplates/WaveManagerServer.server.lua`
   - `src/ReplicatedStorage/Shared/Hello.luau`

2. **Delete old files after merge**:
   - `GridHelperSpawnerServer.server.lua` (merged)
   - `HelperShopServer.server.lua` (merged)
   - `ShopService.server.lua` (merged)
   - `HelperRespawnManager.server.lua` (merged)
   - `HelperRestore.server.lua` (merged)
   - `HelperRoundReset.server.lua` (merged)
   - `CoinCollectionHandler.server.lua` (merged)
   - `PassiveCoinGenerator.server.lua` (merged)

### Phase 5: Update Imports

After moving files, update all `require()` statements:

1. **Server scripts** that require other server scripts:
   ```lua
   -- Old
   local HelperPlacement = require(script.Parent.HelperPlacement)
   
   -- New
   local HelperPlacement = require(script.Parent.Parent.Helpers.HelperPlacement)
   ```

2. **Client scripts** that require shared modules:
   ```lua
   -- Should remain the same (ReplicatedStorage paths unchanged)
   local RootUI = require(ReplicatedStorage.Shared.RootUI)
   ```

3. **Global functions** (`_G.*`):
   - Update any references to moved modules
   - Ensure `_G.ResetHelpersOnIsland` still works
   - Ensure `_G.ShopService` still works

### Phase 6: Update RemoteEvent References

Ensure all RemoteEvent paths are correct:

```lua
-- Old
local startWaveEvent = ReplicatedStorage:FindFirstChild("StartWaveEvent")

-- New (should be same, but verify)
local startWaveEvent = ReplicatedStorage.Remotes:FindFirstChild("StartWaveEvent")
-- OR keep in ReplicatedStorage root if that's how it's set up
```

### Phase 7: Test Everything

1. **Test helper placement**:
   - Buy helper from shop
   - Place helper on grid
   - Verify blueprint is saved

2. **Test wave system**:
   - Start wave
   - Verify enemies spawn
   - Verify helpers unfreeze
   - Verify combat works

3. **Test merge system**:
   - Place 3 same helpers
   - Verify merge works
   - Verify stats upgrade

4. **Test economy**:
   - Verify coins are earned
   - Verify passive generation
   - Verify shop purchases

5. **Test respawn**:
   - Let helper die
   - Verify respawn works
   - Verify blueprint persistence

---

## 📝 Naming Conventions

### File Naming
- Server scripts: `*.server.lua`
- Client scripts: `*.client.lua`
- Shared modules: `*.lua` or `*.luau`
- React components: `*.luau`

### Function Naming
- Use camelCase: `getHelperGrid()`, `spawnEnemy()`
- Use descriptive names: `findNearestTarget()` not `findTarget()`
- Prefix utility functions: `isPositionInGrid()`, `constrainToGrid()`

### Variable Naming
- Use camelCase: `playerIsland`, `currentWave`
- Use descriptive names: `helpersByIsland` not `helpers`
- Prefix booleans: `isActive`, `hasHelper`, `canAttack`

---

## 🔍 Verification Checklist

After cleanup, verify:

- [ ] All files are in correct folders
- [ ] No duplicate functionality
- [ ] All imports updated
- [ ] All RemoteEvents work
- [ ] All `_G.*` functions accessible
- [ ] Helper placement works
- [ ] Wave system works
- [ ] Combat works
- [ ] Merge system works
- [ ] Economy works
- [ ] Blueprint system works
- [ ] Grid boundaries enforced
- [ ] UI updates correctly
- [ ] No errors in output

---

## 🚨 Common Issues & Solutions

### Issue: "Module not found"
**Solution**: Check `require()` paths match new file locations

### Issue: "RemoteEvent not found"
**Solution**: Verify RemoteEvents are created in correct location

### Issue: "Global function not found"
**Solution**: Ensure `_G.*` functions are set before being called

### Issue: "Helpers not spawning"
**Solution**: Check HelperPlacement server script is running

### Issue: "Wave not starting"
**Solution**: Check WaveManagerServer is running and StartWaveEvent exists

---

## 📚 Additional Resources

- See `../PROJECT_ARCHITECTURE.md` for system documentation
- See `../systems/WAVE_SYSTEM_SETUP_GUIDE.md` for wave system setup
- Check git history for original file locations if needed

---

**Last Updated**: 2024
**Version**: 1.0
