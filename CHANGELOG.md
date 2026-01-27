# Changelog

All notable changes to the Trainyourslave project will be documented in this file.

## [2.0] - December 2024

### 🎯 Major Refactoring - Project Cleanup

#### Added
- **Organized folder structure** - Files grouped by system type:
  - `Core/` - Core game systems (waves, combat)
  - `Helpers/` - Helper-related systems
  - `Enemies/` - Enemy-related systems
  - `Economy/` - Economy and coin systems
  - `Special/` - Special abilities
  - `Utils/` - Utility scripts
- **HelperMoveServer.server.lua** - Server-authoritative helper movement system
- **DisablePlayerCollision.server.lua** - Player collision management utility
- **Comprehensive documentation** - Added multiple documentation files:
  - `PROJECT_ARCHITECTURE.md` - Complete system architecture
  - `FILE_STRUCTURE_REFERENCE.md` - File structure reference
  - `ATTRIBUTES_REFERENCE.md` - Attributes reference guide
  - `CLEANUP_COMPLETED.md` - Cleanup progress report
  - `CLEANUP_MERGE_COMPLETE.md` - Merge completion report

#### Changed
- **File reorganization** - All server scripts moved to organized folders
- **File renaming** - Standardized naming conventions:
  - `WaveManagerServer.server.lua` → `Core/WaveManager.server.lua`
  - `HelperMergeServer.server.lua` → `Helpers/HelperMerge.server.lua`
  - `EnemyMergeServer.server.lua` → `Enemies/EnemyMerge.server.lua`
  - `LeaderStatsHandler.server.lua` → `Economy/LeaderStats.server.lua`
- **Merged duplicate files**:
  - `ShopService.server.lua` + `HelperShopServer.server.lua` → `Helpers/HelperShop.server.lua`
  - `CoinCollectionHandler.server.lua` + `PassiveCoinGenerator.server.lua` → `Economy/CoinSystem.server.lua`
  - `HelperRespawnManager.server.lua` + `HelperRestore.server.lua` + `HelperRoundReset.server.lua` → `Helpers/HelperRespawn.server.lua`

#### Removed
- **Test files**:
  - `EnemySpawnTest.server.lua`
  - `ServerStorage/EnemyTemplates/WaveManagerServer.server.lua`
  - `ReplicatedStorage/Shared/Hello.luau`
- **Duplicate files** (merged):
  - `ShopService.server.lua`
  - `HelperShopServer.server.lua`
  - `CoinCollectionHandler.server.lua`
  - `PassiveCoinGenerator.server.lua`
  - `HelperRespawnManager.server.lua`
  - `HelperRestore.server.lua`
  - `HelperRoundReset.server.lua`

#### Benefits
- ✅ **Better organization** - Files grouped by system type
- ✅ **Easier navigation** - Clear folder structure
- ✅ **No duplicate code** - All duplicate functionality merged
- ✅ **Single source of truth** - Each system has one authoritative file
- ✅ **Better maintainability** - Related files are together
- ✅ **Improved scalability** - Easy to add new files to appropriate folders

---

## [1.0] - Initial Release

Initial project setup with Rojo template.

---

**Note**: This changelog follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) format.
