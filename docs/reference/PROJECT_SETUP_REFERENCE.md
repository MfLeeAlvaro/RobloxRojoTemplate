# Project Setup Reference

Complete reference for recreating the project structure from scratch, including Rojo configuration and file structure mapping.

---

## 📋 Table of Contents

1. [Rojo Project Configuration](#rojo-project-configuration)
2. [Complete File Structure](#complete-file-structure)
3. [Recreating from Scratch](#recreating-from-scratch)
4. [Folder Mappings](#folder-mappings)
5. [Configuration Details](#configuration-details)

---

## 🔧 Rojo Project Configuration

### `default.project.json` - Complete Configuration

```json
{
  "name": "RobloxRojoTemplate",
  "tree": {
    "$className": "DataModel",

    "Workspace": {
      "$ignoreUnknownInstances": true,
      "Map": { "$path": "src/Workspace/Map", "$ignoreUnknownInstances": true },
      "Systems": { "$path": "src/Workspace/Systems", "$ignoreUnknownInstances": true }
    },

    "ReplicatedStorage": {
      "$ignoreUnknownInstances": true,
      "Packages": { "$path": "Packages" },
      "Modules": { "$path": "src/ReplicatedStorage/Modules", "$ignoreUnknownInstances": true },
      "Remotes": { "$path": "src/ReplicatedStorage/Remotes", "$ignoreUnknownInstances": true },
      "Shared": { "$path": "src/ReplicatedStorage/Shared", "$ignoreUnknownInstances": true }
    },

    "ServerScriptService": {
      "$ignoreUnknownInstances": true,
      "$path": "src/ServerScriptService"
    },

    "ServerStorage": {
      "$ignoreUnknownInstances": true,
      "Modules": { "$path": "src/ServerStorage/Modules", "$ignoreUnknownInstances": true },
      "Assets": { "$path": "src/ServerStorage/Assets", "$ignoreUnknownInstances": true }
    },

    "StarterGui": {
      "$ignoreUnknownInstances": true,
      "UI": { "$path": "src/StarterGui/UI", "$ignoreUnknownInstances": true }
    },

    "StarterPack": {
      "$ignoreUnknownInstances": true,
      "Tools": { "$path": "src/StarterPack/Tools", "$ignoreUnknownInstances": true }
    },

    "StarterPlayer": {
      "$ignoreUnknownInstances": true,

      "StarterPlayerScripts": {
        "$ignoreUnknownInstances": true,
        "$path": "src/StarterPlayer/StarterPlayerScripts"
      },

      "StarterCharacterScripts": {
        "$ignoreUnknownInstances": true,
        "Character": { "$path": "src/StarterPlayer/StarterCharacterScripts/Character", "$ignoreUnknownInstances": true }
      }
    },

    "SoundService": {
      "$ignoreUnknownInstances": true,
      "Sounds": { "$path": "src/SoundService/Sounds", "$ignoreUnknownInstances": true }
    },

    "Teams": {
      "$ignoreUnknownInstances": true,
      "Config": { "$path": "src/Teams/Config", "$ignoreUnknownInstances": true }
    },

    "Chat": {
      "$ignoreUnknownInstances": true
    }
  }
}
```

---

## 📁 Complete File Structure

### Root Directory Structure

```
Trainyourslave/
├── .gitignore
├── aftman.toml                    # Tool management config
├── default.project.json           # Rojo project configuration
├── README.md                      # Main project readme
├── CHANGELOG.md                   # Project changelog
├── wally.toml                     # Wally package manager config
├── wally.lock                     # Wally lock file
├── sourcemap.json                 # Rojo sourcemap (auto-generated)
│
├── Packages/                      # Wally packages (auto-managed)
│   ├── React.lua
│   ├── ReactRoblox.lua
│   └── _Index/                    # Package index
│
├── docs/                          # Documentation
│   ├── README.md
│   ├── PROJECT_ARCHITECTURE.md
│   ├── CONTRIBUTING.md
│   ├── reference/
│   │   ├── FILE_STRUCTURE_REFERENCE.md
│   │   ├── ATTRIBUTES_REFERENCE.md
│   │   └── PROJECT_SETUP_REFERENCE.md
│   ├── cleanup/
│   │   ├── CLEANUP_COMPLETED.md
│   │   ├── CLEANUP_GUIDE.md
│   │   └── CLEANUP_MERGE_COMPLETE.md
│   └── systems/
│       ├── RACE_SYSTEM_DESIGN.md
│       ├── RACE_SYSTEM_QUICK_START.md
│       ├── WAVE_SYSTEM_SETUP_GUIDE.md
│       └── PLACEMENT_PATCHES.md
│
└── src/                           # Source code (synced to Roblox)
    ├── Workspace/
    │   ├── Map/                    # Map assets
    │   ├── Systems/                # Workspace systems
    │   └── IndigenousPlatform/
    │       └── HoboSeller/
    │           └── dialogScript.lua
    │
    ├── ReplicatedStorage/
    │   ├── Modules/                 # Shared modules
    │   ├── Remotes/                 # RemoteEvents/BindableEvents (created dynamically)
    │   └── Shared/                  # React UI components
    │       ├── RootUI.luau
    │       ├── ShopUI.luau
    │       ├── HelperPlacementUI.luau
    │       └── StartWaveUI.luau
    │
    ├── ServerScriptService/
    │   ├── Core/
    │   │   ├── WaveManager.server.lua
    │   │   └── CombatService.server.lua
    │   ├── Helpers/
    │   │   ├── HelperPlacement.server.lua
    │   │   ├── GridHelperSpawnerServer.server.lua
    │   │   ├── HelperBlueprintManager.server.lua
    │   │   ├── HelperMerge.server.lua
    │   │   ├── HelperRespawn.server.lua
    │   │   ├── HelperShop.server.lua
    │   │   ├── HelperPurchaseHandler.server.lua
    │   │   └── HelperMoveServer.server.lua
    │   ├── Enemies/
    │   │   └── EnemyMerge.server.lua
    │   ├── Economy/
    │   │   ├── CoinSystem.server.lua
    │   │   └── LeaderStats.server.lua
    │   ├── Special/
    │   │   └── TweakerCharge.server.lua
    │   └── Utils/
    │       ├── RigAnimator.server.lua
    │       └── DisablePlayerCollision.server.lua
    │
    ├── ServerStorage/
    │   ├── Modules/                 # Server modules
    │   ├── Assets/                  # Server assets
    │   └── EnemyTemplates/           # Enemy unit templates
    │
    ├── StarterGui/
    │   └── UI/                      # GUI elements
    │
    ├── StarterPack/
    │   └── Tools/                   # Starter tools
    │
    ├── StarterPlayer/
    │   ├── StarterPlayerScripts/
    │   │   ├── Client.client.lua
    │   │   ├── GridPlacementSystem.client.lua
    │   │   ├── HelperDragClient.client.lua
    │   │   ├── MountUI.lua
    │   │   └── UpdateStatsDisplay.client.lua
    │   └── StarterCharacterScripts/
    │       └── Character/           # Character scripts
    │
    ├── SoundService/
    │   └── Sounds/                  # Sound assets
    │
    └── Teams/
        └── Config/                  # Team configuration
```

---

## 🗺️ Folder Mappings

### Roblox → File System Mapping

| Roblox Service/Folder | Local Path | Notes |
|----------------------|------------|-------|
| `Workspace` | `src/Workspace/` | Map and systems |
| `Workspace.Map` | `src/Workspace/Map/` | Map assets |
| `Workspace.Systems` | `src/Workspace/Systems/` | Workspace systems |
| `ReplicatedStorage.Packages` | `Packages/` | Wally packages |
| `ReplicatedStorage.Modules` | `src/ReplicatedStorage/Modules/` | Shared modules |
| `ReplicatedStorage.Remotes` | `src/ReplicatedStorage/Remotes/` | RemoteEvents (created dynamically) |
| `ReplicatedStorage.Shared` | `src/ReplicatedStorage/Shared/` | React UI components |
| `ServerScriptService` | `src/ServerScriptService/` | All server scripts |
| `ServerScriptService.Core` | `src/ServerScriptService/Core/` | Core systems |
| `ServerScriptService.Helpers` | `src/ServerScriptService/Helpers/` | Helper systems |
| `ServerScriptService.Enemies` | `src/ServerScriptService/Enemies/` | Enemy systems |
| `ServerScriptService.Economy` | `src/ServerScriptService/Economy/` | Economy systems |
| `ServerScriptService.Special` | `src/ServerScriptService/Special/` | Special abilities |
| `ServerScriptService.Utils` | `src/ServerScriptService/Utils/` | Utility scripts |
| `ServerStorage.Modules` | `src/ServerStorage/Modules/` | Server modules |
| `ServerStorage.Assets` | `src/ServerStorage/Assets/` | Server assets |
| `ServerStorage.EnemyTemplates` | `src/ServerStorage/EnemyTemplates/` | Enemy templates |
| `StarterGui.UI` | `src/StarterGui/UI/` | GUI elements |
| `StarterPack.Tools` | `src/StarterPack/Tools/` | Starter tools |
| `StarterPlayer.StarterPlayerScripts` | `src/StarterPlayer/StarterPlayerScripts/` | Client scripts |
| `StarterPlayer.StarterCharacterScripts.Character` | `src/StarterPlayer/StarterCharacterScripts/Character/` | Character scripts |
| `SoundService.Sounds` | `src/SoundService/Sounds/` | Sound assets |
| `Teams.Config` | `src/Teams/Config/` | Team configuration |

---

## 🔍 Configuration Details

### Key Configuration Features

1. **`$ignoreUnknownInstances: true`**
   - Allows Roblox instances that don't exist in the file system
   - Useful for instances created at runtime (e.g., RemoteEvents, Models)
   - Prevents Rojo from deleting runtime-created instances

2. **`$path` Property**
   - Maps Roblox instances to local file system paths
   - Can be relative to project root or absolute

3. **`$className` Property**
   - Specifies the Roblox class name (e.g., "DataModel", "Folder")

### Important Notes

- **RemoteEvents**: Created dynamically in scripts, not stored in file system
- **Packages**: Managed by Wally, located in `Packages/` folder
- **Templates**: Stored in `ServerStorage/` (HelperTemplates, EnemyTemplates)
- **Runtime Instances**: Many instances are created at runtime (Helpers, Enemies, etc.)

---

## 🚀 Recreating from Scratch

### Step 1: Initialize Project

```bash
# Create project directory
mkdir Trainyourslave
cd Trainyourslave

# Initialize git (optional)
git init
```

### Step 2: Create Root Files

Create these files in the root directory:

**`default.project.json`**
```json
{
  "name": "RobloxRojoTemplate",
  "tree": {
    "$className": "DataModel",
    "Workspace": {
      "$ignoreUnknownInstances": true,
      "Map": { "$path": "src/Workspace/Map", "$ignoreUnknownInstances": true },
      "Systems": { "$path": "src/Workspace/Systems", "$ignoreUnknownInstances": true }
    },
    "ReplicatedStorage": {
      "$ignoreUnknownInstances": true,
      "Packages": { "$path": "Packages" },
      "Modules": { "$path": "src/ReplicatedStorage/Modules", "$ignoreUnknownInstances": true },
      "Remotes": { "$path": "src/ReplicatedStorage/Remotes", "$ignoreUnknownInstances": true },
      "Shared": { "$path": "src/ReplicatedStorage/Shared", "$ignoreUnknownInstances": true }
    },
    "ServerScriptService": {
      "$ignoreUnknownInstances": true,
      "$path": "src/ServerScriptService"
    },
    "ServerStorage": {
      "$ignoreUnknownInstances": true,
      "Modules": { "$path": "src/ServerStorage/Modules", "$ignoreUnknownInstances": true },
      "Assets": { "$path": "src/ServerStorage/Assets", "$ignoreUnknownInstances": true }
    },
    "StarterGui": {
      "$ignoreUnknownInstances": true,
      "UI": { "$path": "src/StarterGui/UI", "$ignoreUnknownInstances": true }
    },
    "StarterPack": {
      "$ignoreUnknownInstances": true,
      "Tools": { "$path": "src/StarterPack/Tools", "$ignoreUnknownInstances": true }
    },
    "StarterPlayer": {
      "$ignoreUnknownInstances": true,
      "StarterPlayerScripts": {
        "$ignoreUnknownInstances": true,
        "$path": "src/StarterPlayer/StarterPlayerScripts"
      },
      "StarterCharacterScripts": {
        "$ignoreUnknownInstances": true,
        "Character": { "$path": "src/StarterPlayer/StarterCharacterScripts/Character", "$ignoreUnknownInstances": true }
      }
    },
    "SoundService": {
      "$ignoreUnknownInstances": true,
      "Sounds": { "$path": "src/SoundService/Sounds", "$ignoreUnknownInstances": true }
    },
    "Teams": {
      "$ignoreUnknownInstances": true,
      "Config": { "$path": "src/Teams/Config", "$ignoreUnknownInstances": true }
    },
    "Chat": {
      "$ignoreUnknownInstances": true
    }
  }
}
```

**`aftman.toml`**
```toml
# This file lists tools managed by Aftman, a cross-platform toolchain manager.
# For more information, see https://github.com/LPGhatguy/aftman

# To add a new tool, add an entry to this table.
[tools]
rojo = "rojo-rbx/rojo@7.6.1"
wally = "UpliftGames/wally@0.3.2"
```

**`wally.toml`**
```toml
[package]
name = "trainyourslave/game"
version = "0.1.0"
registry = "https://github.com/UpliftGames/wally-index"
realm = "shared"

[dependencies]
React = "jsdotlua/react@17.2.1"
ReactRoblox = "jsdotlua/react-roblox@17.2.1"
```

### Step 3: Create Folder Structure

```bash
# Create main source directories
mkdir -p src/Workspace/Map
mkdir -p src/Workspace/Systems
mkdir -p src/ReplicatedStorage/Modules
mkdir -p src/ReplicatedStorage/Remotes
mkdir -p src/ReplicatedStorage/Shared
mkdir -p src/ServerScriptService/Core
mkdir -p src/ServerScriptService/Helpers
mkdir -p src/ServerScriptService/Enemies
mkdir -p src/ServerScriptService/Economy
mkdir -p src/ServerScriptService/Special
mkdir -p src/ServerScriptService/Utils
mkdir -p src/ServerStorage/Modules
mkdir -p src/ServerStorage/Assets
mkdir -p src/ServerStorage/EnemyTemplates
mkdir -p src/StarterGui/UI
mkdir -p src/StarterPack/Tools
mkdir -p src/StarterPlayer/StarterPlayerScripts
mkdir -p src/StarterPlayer/StarterCharacterScripts/Character
mkdir -p src/SoundService/Sounds
mkdir -p src/Teams/Config
```

### Step 4: Install Dependencies

```bash
# Install tools via Aftman
aftman install

# Install packages via Wally
wally install
```

### Step 5: Create Initial Files

Create placeholder files in each directory as needed. For example:

**`src/ServerScriptService/Core/WaveManager.server.lua`**
```lua
-- WaveManager.server.lua
-- Wave spawning and progression system
```

**`src/ServerScriptService/Core/CombatService.server.lua`**
```lua
-- CombatService.server.lua
-- Combat logic and NPC interactions
```

Continue creating files according to the [FILE_STRUCTURE_REFERENCE.md](FILE_STRUCTURE_REFERENCE.md).

### Step 6: Build and Test

```bash
# Build the place file
rojo build -o "Trainyourslave.rbxlx"

# Start Rojo server
rojo serve
```

---

## 📝 Quick Reference

### Essential Files

- `default.project.json` - Rojo project configuration
- `aftman.toml` - Tool versions (Rojo, Wally)
- `wally.toml` - Package dependencies (React, ReactRoblox)
- `wally.lock` - Locked package versions (auto-generated)
- `sourcemap.json` - Rojo sourcemap (auto-generated)

### Key Directories

- `src/` - All source code synced to Roblox
- `Packages/` - Wally packages (auto-managed)
- `docs/` - Project documentation

### Build Commands

```bash
# Build place file
rojo build -o "Trainyourslave.rbxlx"

# Start sync server
rojo serve

# Install dependencies
aftman install
wally install
```

---

## 🔗 Related Documentation

- [FILE_STRUCTURE_REFERENCE.md](FILE_STRUCTURE_REFERENCE.md) - Complete file list
- [PROJECT_ARCHITECTURE.md](../PROJECT_ARCHITECTURE.md) - System architecture
- [CONTRIBUTING.md](../CONTRIBUTING.md) - Setup and contribution guide

---

**Last Updated**: January 2026  
**Version**: 2.0
