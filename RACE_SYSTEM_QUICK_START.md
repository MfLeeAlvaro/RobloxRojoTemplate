# Race System Quick Start Guide

## 🚀 Quick Implementation Steps

### Step 1: Create Race Definitions File

Create `src/ServerScriptService/Core/RaceDefinitions.server.lua` with the race data from `RACE_SYSTEM_DESIGN.md`.

### Step 2: Create Race Manager File

Create `src/ServerScriptService/Core/RaceManager.server.lua` with the manager code from `RACE_SYSTEM_DESIGN.md`.

### Step 3: Add Race to Helper Templates

In Roblox Studio, for each helper template in `ServerStorage/HelperTemplates`:
1. Select the template model
2. Add StringValue attribute: `Race` = `"Human"` (or desired race)
3. Repeat for all templates

### Step 4: Modify Helper Placement

In `GridHelperSpawnerServer.server.lua` or `HelperPlacement.server.lua`, add after spawning:

```lua
local RaceManager = require(script.Parent.Parent.Core.RaceManager)

-- After setting all attributes, before parenting:
local race = modelToClone:GetAttribute("Race") or "Human"
RaceManager.InitializeUnit(unit, race)
```

### Step 5: Modify Helper Merge

In `HelperMergeServer.server.lua`, add after merge:

```lua
local RaceManager = require(script.Parent.Parent.Core.RaceManager)

-- After creating merged helper:
local race = helpers[1]:GetAttribute("Race") or "Human"
RaceManager.InitializeUnit(mergedHelper, race)

local islandId = mergedHelper:GetAttribute("IslandId")
if islandId then
	RaceManager.RecalculateIslandSynergies(islandId)
end
```

### Step 6: Modify Blueprint System

In `HelperBlueprintManager.server.lua`, add race to saved attributes:

```lua
-- In saveBlueprint(), add to requiredAttrs:
local requiredAttrs = {
	-- ... existing ...
	"Race",  -- Add this
	"RaceBuffDamage", "RaceBuffHealth", "RaceBuffSpeed",  -- Optional: save multipliers
	"SynergyTier", "SynergyDamage", "SynergyHealth",  -- Optional: save synergy
}

-- In spawnFromBlueprint(), after setting attributes:
local race = blueprint:GetAttribute("Race") or "Human"
if _G.RaceManager then
	_G.RaceManager.InitializeUnit(boardInstance, race)
end
```

### Step 7: Update CombatService (Optional - for special abilities)

In `CombatService.server.lua`, modify `doAttack()` to use race-modified damage (see `RACE_SYSTEM_DESIGN.md` for full code).

---

## 📋 Minimal Implementation

If you want to start simple, just add race attribute and basic multipliers:

```lua
-- In HelperPlacement or GridHelperSpawnerServer, after spawning:

local race = modelToClone:GetAttribute("Race") or "Human"

-- Simple race multipliers (you can expand later)
local raceMultipliers = {
	Human = { damage = 1.0, health = 1.0 },
	Elf = { damage = 0.9, health = 0.85, speed = 1.2, range = 1.3 },
	Demon = { damage = 1.3, health = 1.2, speed = 0.8 },
	-- Add more as needed
}

local multipliers = raceMultipliers[race] or raceMultipliers.Human

-- Apply to base stats
local baseDamage = unit:GetAttribute("BaseDamage") or 10
local baseHealth = unit:GetAttribute("BaseHealth") or 100

unit:SetAttribute("BaseDamage", baseDamage * multipliers.damage)
unit:SetAttribute("BaseHealth", baseHealth * multipliers.health)
unit:SetAttribute("Race", race)

-- Recalculate current stats
local starLevel = unit:GetAttribute("StarLevel") or 0
unit:SetAttribute("AttackDamage", baseDamage * multipliers.damage * (2 ^ starLevel))

-- Update humanoid
local hum = unit:FindFirstChildOfClass("Humanoid")
if hum then
	hum.MaxHealth = baseHealth * multipliers.health * (2 ^ starLevel)
	hum.Health = hum.MaxHealth
end
```

---

## ✅ Testing

1. Place a helper with `Race = "Elf"` attribute
2. Check that `AttackRange` is increased
3. Check that `BaseHealth` is reduced
4. Place 3 more Elves on same island
5. Check that synergy bonuses apply

---

**See `RACE_SYSTEM_DESIGN.md` for full implementation details.**
