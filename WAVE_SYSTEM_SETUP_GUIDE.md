# Wave System Setup Guide

## 📋 Overview
This guide explains how to set up the refactored multi-island wave spawning system in Roblox Studio.

## 🏗️ Required Structure in Studio

### 1. Island Models Structure
Each island must be a **Model** in workspace with the following structure:

```
Workspace
└── [Your Island Models]
    ├── Island_001 (Model)
    │   ├── Attributes:
    │   │   ├── IslandId: "Island_001" (String)
    │   │   └── OwnerUserId: [number] (set when player claims island)
    │   ├── Gridfloor (BasePart) - The battle grid
    │   ├── SpawnPoints (Folder) - Optional: for custom spawn locations
    │   └── ActiveNPCs (Folder) - Optional: for organizing NPCs
    │
    ├── Island_002 (Model)
    │   └── [Same structure]
    │
    └── Island_003 (Model)
        └── [Same structure]
```

### 2. Required Folders

#### ServerStorage
```
ServerStorage
└── EnemyTemplates (Folder)
    ├── EnemyGrunt (Model or Folder containing Model)
    ├── MiniBoss (Model or Folder containing Model)
    ├── Boss (Model or Folder containing Model)
    ├── Goons (Model or Folder containing Model) - Optional
    ├── Guz (Model or Folder containing Model) - Optional
    ├── Donald (Model or Folder containing Model) - Optional
    └── MoneyMan (Model or Folder containing Model) - Optional
```

#### Workspace (Auto-created by script)
```
Workspace
├── Helpers (Folder) - Auto-created
└── Enemies (Folder) - Auto-created
```

### 3. Script Location
```
ServerScriptService
└── WaveManagerServer.server.lua (This script)
```

## 🔧 Setup Steps

### Step 1: Create Island Models
1. In Studio, create Model instances for each island
2. Name them: `Island_001`, `Island_002`, etc.
3. Add **StringValue** attribute: `IslandId` = `"Island_001"` (match the name)
4. Add **NumberValue** attribute: `OwnerUserId` = `0` (will be set when player claims)

### Step 2: Add Gridfloor Parts
1. Inside each Island model, create a **BasePart** named `Gridfloor`
2. Size it appropriately (e.g., 50x1x50 studs for a 10x10 grid)
3. Position it where you want the battle area
4. Make it **Anchored** = `true` and **CanCollide** = `true`

### Step 3: Set Up Enemy Templates
1. In **ServerStorage**, create folder `EnemyTemplates`
2. Add your enemy models (each must have):
   - A **Humanoid** object
   - A **HumanoidRootPart** (or set PrimaryPart)
   - Any AI/attack scripts (they'll be disabled when frozen)

### Step 4: Claim Island Ownership
When a player claims an island (e.g., places first helper), set:
```lua
island:SetAttribute("OwnerUserId", player.UserId)
```

## 🎮 How It Works

### Ownership System
- **No Owner** (`OwnerUserId` = nil or 0): Island cannot spawn waves
- **Has Owner**: Only that player can start waves on that island
- **Player Leaves**: Ownership is cleared, wave loops stop

### Wave Loop Singleton
- Each island can only have **ONE** active wave loop at a time
- Guarded by `activeWavesByIsland[islandId]`
- Prevents duplicate wave starts

### NPC Freeze System (NO ANCHORING)
- **Pre-Wave**: NPCs are frozen but **NOT anchored**
  - `WalkSpeed = 0`, `JumpPower = 0`
  - AI scripts disabled
  - Set to Neutral/passive
  - Idle animations still play
- **Wave Active**: NPCs unfreeze
  - Original WalkSpeed/JumpPower restored
  - AI scripts enabled
  - Set to Aggressive

### Position Reset
- When NPC spawns: Original CFrame is stored
- When wave ends: All NPCs reset to original spawn positions
- Uses `PivotTo()` to restore position
- Velocity is zeroed before reset

## 🔍 Key Features

### ✅ Fixed Issues
1. **No spawning on unowned islands** - Ownership check before every spawn
2. **Singleton wave loops** - Only one wave per island at a time
3. **No anchoring** - NPCs use movement locking instead
4. **Position reset** - NPCs return to spawn positions after each wave
5. **No duplicate connections** - Guard prevents multiple event handlers

### 🎯 Island-Scoped Spawning
- Each island has its own spawn points (Gridfloor cells)
- Enemies spawn only on their island's grid
- No cross-island contamination

## 📝 Example: Setting Island Ownership

```lua
-- When player places first helper on an island
local island = workspace:FindFirstChild("Island_001")
if island then
    island:SetAttribute("OwnerUserId", player.UserId)
    print("Island claimed by player " .. player.Name)
end
```

## 🐛 Debugging

### Check Island Ownership
```lua
local island = workspace:FindFirstChild("Island_001")
local ownerId = island:GetAttribute("OwnerUserId")
print("Owner: " .. tostring(ownerId))
```

### Check Active Waves
The script prints:
- `🚀 Starting wave X on island Y`
- `🎉 WON wave X`
- `💀 LOST: All helpers dead`
- `❄️ Frozen NPC` / `🔥 Unfrozen NPC`

## ⚠️ Important Notes

1. **Island Models**: Must be Models (not Folders) with `IslandId` attribute
2. **Gridfloor**: Must be a BasePart named exactly `"Gridfloor"` inside the island
3. **Enemy Templates**: Must have Humanoid and HumanoidRootPart
4. **No Anchoring**: Script never anchors NPC parts - uses movement locking only
5. **Position Storage**: Original positions stored in `npcOriginalCFrames` table

## 🚀 Next Steps

1. Set up your island models with the required structure
2. Add `IslandId` and `OwnerUserId` attributes
3. Create `EnemyTemplates` folder in ServerStorage
4. Test by claiming an island and starting a wave
5. Verify NPCs freeze (no anchor) and reset positions after wave
