# Attributes Reference Guide

## 📋 Complete Attributes List

This document lists all attributes used in the game, organized by model type.

---

## 🏝️ Island Model Attributes

### Required Attributes
```lua
Island:SetAttribute("IslandId", 1)           -- number: Unique island identifier
Island:SetAttribute("OwnerUserId", 12345)    -- number: Player who owns this island
```

### Optional Attributes
```lua
Island:SetAttribute("IslandName", "Island_001")  -- string: Display name
Island:SetAttribute("IslandLevel", 1)            -- number: Island upgrade level (future)
```

---

## 👥 Helper Model Attributes

### Identity & Placement
```lua
Helper:SetAttribute("HelperType", "MagicHobo")     -- string: Unit type identifier
Helper:SetAttribute("HelperName", "MagicHobo")     -- string: Display name (alias)
Helper:SetAttribute("UnitType", "MagicHobo")       -- string: Unit type (alias)
Helper:SetAttribute("UnitKey", "MagicHobo")        -- string: Merge key identifier
Helper:SetAttribute("TemplateName", "MagicHobo")   -- string: Template name

Helper:SetAttribute("GridId", "Workspace.Island.Island_001.Gridfloor")  -- string: Grid identifier
Helper:SetAttribute("PlaceRow", 3)                 -- number: Grid row (1-5 for players)
Helper:SetAttribute("PlaceCol", 5)                 -- number: Grid column (1-10)
Helper:SetAttribute("SpawnRow", 3)                 -- number: Spawn row (alias)
Helper:SetAttribute("SpawnCol", 5)                 -- number: Spawn column (alias)
Helper:SetAttribute("OriginalCFrame", CFrame.new(...))  -- CFrame: Original spawn position

Helper:SetAttribute("OwnerUserId", 12345)          -- number: Player who owns this helper
Helper:SetAttribute("IslandId", 1)                 -- number: Island this helper belongs to
Helper:SetAttribute("HelperKey", "1:3:5")          -- string: Blueprint key (GridId:Row:Col)
```

### Stats (Base - Before Star Scaling)
```lua
Helper:SetAttribute("BaseDamage", 12)              -- number: Base attack damage
Helper:SetAttribute("BaseHealth", 100)              -- number: Base max health
Helper:SetAttribute("BaseRange", 14)                -- number: Base attack range
Helper:SetAttribute("BaseCooldown", 1.1)           -- number: Base attack cooldown (seconds)
```

### Stats (Current - After Star Scaling)
```lua
Helper:SetAttribute("AttackDamage", 24)             -- number: Current damage (BaseDamage * 2^StarLevel)
Helper:SetAttribute("AttackRange", 14)              -- number: Current range
Helper:SetAttribute("AttackCooldown", 1.1)         -- number: Current cooldown
```

### Star & Rarity System
```lua
Helper:SetAttribute("StarLevel", 2)                -- number: Star level (0-5+)
Helper:SetAttribute("Star", 2)                      -- number: Star level (alias)
Helper:SetAttribute("Rarity", "Common")              -- string: Rarity tier (Common/Rare/Epic/Legendary)
```

### Movement & State
```lua
Helper:SetAttribute("OriginalWalkSpeed", 16)        -- number: Original walk speed
Helper:SetAttribute("OriginalJumpPower", 50)        -- number: Original jump power
Helper:SetAttribute("Frozen", false)                 -- boolean: Is frozen (prep phase)
Helper:SetAttribute("Aggressive", true)             -- boolean: Is aggressive (wave active)
Helper:SetAttribute("Dead", false)                  -- boolean: Is dead
Helper:SetAttribute("IsDead", false)               -- boolean: Is dead (alias)
```

### Race System (Future)
```lua
Helper:SetAttribute("Race", "Human")                -- string: Race identifier
Helper:SetAttribute("RaceBuffDamage", 1.1)         -- number: Damage multiplier from race
Helper:SetAttribute("RaceBuffHealth", 1.0)          -- number: Health multiplier from race
Helper:SetAttribute("RaceBuffSpeed", 1.0)          -- number: Speed multiplier from race
Helper:SetAttribute("RaceDebuffDamage", 1.0)        -- number: Damage debuff multiplier
Helper:SetAttribute("RaceDebuffHealth", 1.0)        -- number: Health debuff multiplier
```

### Special Abilities
```lua
Helper:SetAttribute("HasCart", true)                 -- boolean: Has shopping cart (Tweaker)
Helper:SetAttribute("SpecialReady", false)          -- boolean: Special ability ready
Helper:SetAttribute("SpecialCooldown", 0)          -- number: Special ability cooldown
```

### Synergy System (Future)
```lua
Helper:SetAttribute("Synergy", "Fire")              -- string: Synergy type
Helper:SetAttribute("Element", "Fire")              -- string: Element type (alias)
Helper:SetAttribute("SynergyCount", 3)              -- number: Number of same synergy on island
```

### Other
```lua
Helper:SetAttribute("DamageMult", 1.0)             -- number: Damage multiplier (temporary buffs)
Helper:SetAttribute("EnemyType", nil)               -- string: Enemy type (if applicable)
```

---

## 👾 Enemy Model Attributes

### Identity & Placement
```lua
Enemy:SetAttribute("UnitType", "EnemyGrunt")        -- string: Enemy type identifier
Enemy:SetAttribute("EnemyType", "EnemyGrunt")       -- string: Enemy type (alias)
Enemy:SetAttribute("TemplateName", "EnemyGrunt")    -- string: Template name

Enemy:SetAttribute("GridId", "Workspace.Island.Island_001.Gridfloor")  -- string: Grid identifier
Enemy:SetAttribute("SpawnRow", 7)                    -- number: Spawn row (6-10 for enemies)
Enemy:SetAttribute("SpawnCol", 3)                    -- number: Spawn column (1-10)
Enemy:SetAttribute("OriginalCFrame", CFrame.new(...))  -- CFrame: Original spawn position

Enemy:SetAttribute("IslandId", 1)                    -- number: Island this enemy belongs to
Enemy:SetAttribute("TargetUserId", 12345)           -- number: Player to target
```

### Wave Information
```lua
Enemy:SetAttribute("Wave", 5)                       -- number: Wave number
Enemy:SetAttribute("IsMiniBoss", false)             -- boolean: Is mini-boss
Enemy:SetAttribute("IsBoss", false)                 -- boolean: Is boss
```

### Stats (Base - Before Wave Scaling)
```lua
Enemy:SetAttribute("BaseDamage", 8)                 -- number: Base attack damage
Enemy:SetAttribute("BaseHealth", 150)               -- number: Base max health
Enemy:SetAttribute("BaseRange", 7)                  -- number: Base attack range
Enemy:SetAttribute("BaseCooldown", 1.3)            -- number: Base attack cooldown
```

### Stats (Current - After Wave Scaling)
```lua
Enemy:SetAttribute("AttackDamage", 12)              -- number: Current damage (BaseDamage * DamageMult)
Enemy:SetAttribute("AttackRange", 7)                -- number: Current range
Enemy:SetAttribute("AttackCooldown", 1.3)           -- number: Current cooldown
Enemy:SetAttribute("DamageMult", 1.5)               -- number: Wave difficulty multiplier
Enemy:SetAttribute("BaseDamageMult", 1.5)           -- number: Base damage multiplier (stored)
```

### Star System
```lua
Enemy:SetAttribute("StarLevel", 0)                   -- number: Star level (usually 0 for enemies)
```

### Movement & State
```lua
Enemy:SetAttribute("OriginalWalkSpeed", 12)         -- number: Original walk speed
Enemy:SetAttribute("OriginalJumpPower", 50)         -- number: Original jump power
Enemy:SetAttribute("Frozen", false)                 -- boolean: Is frozen (prep phase)
Enemy:SetAttribute("Aggressive", true)              -- boolean: Is aggressive (wave active)
```

### Race System (Future)
```lua
Enemy:SetAttribute("Race", "Demon")                  -- string: Race identifier
Enemy:SetAttribute("RaceBuffDamage", 1.2)           -- number: Damage multiplier from race
Enemy:SetAttribute("RaceBuffHealth", 1.1)           -- number: Health multiplier from race
```

### Debug
```lua
Enemy:SetAttribute("OrphanWarningShown", false)    -- boolean: Warning shown flag
```

---

## 👤 Player Attributes

### Economy
```lua
Player:SetAttribute("Coins", 500)                    -- number: Current coins
```

### Inventory (Helper Units)
```lua
Player:SetAttribute("Inv_MagicHobo", 2)              -- number: MagicHobo units in inventory
Player:SetAttribute("Inv_Appraiser", 1)             -- number: Appraiser units in inventory
Player:SetAttribute("Inv_Indigenous", 0)             -- number: Indigenous units in inventory
-- Pattern: Inv_<UnitName> = number
```

### Race System (Future)
```lua
Player:SetAttribute("PreferredRace", "Human")        -- string: Player's preferred race (for bonuses)
Player:SetAttribute("RaceMastery_Human", 5)          -- number: Mastery level for Human race
Player:SetAttribute("RaceMastery_Elf", 3)            -- number: Mastery level for Elf race
-- Pattern: RaceMastery_<RaceName> = number
```

---

## 📊 Attribute Categories Summary

### Required for Helpers
- `HelperType` or `UnitType`
- `GridId`
- `PlaceRow` / `PlaceCol`
- `OwnerUserId`
- `IslandId`
- `BaseDamage`, `BaseHealth`, `BaseRange`, `BaseCooldown`
- `StarLevel`
- `OriginalCFrame`

### Required for Enemies
- `UnitType`
- `GridId`
- `SpawnRow` / `SpawnCol`
- `IslandId`
- `TargetUserId`
- `Wave`
- `BaseDamage`, `BaseHealth`, `BaseRange`, `BaseCooldown`
- `DamageMult`

### Required for Islands
- `IslandId` (number)
- `OwnerUserId` (number)

---

## 🔄 Attribute Lifecycle

### Helper Placement
1. **Template** → Clone helper
2. **Set Identity**: `HelperType`, `UnitType`, `TemplateName`
3. **Set Placement**: `GridId`, `PlaceRow`, `PlaceCol`, `OriginalCFrame`
4. **Set Ownership**: `OwnerUserId`, `IslandId`
5. **Set Base Stats**: `BaseDamage`, `BaseHealth`, `BaseRange`, `BaseCooldown`
6. **Set Star Level**: `StarLevel` (default 0)
7. **Calculate Current Stats**: `AttackDamage = BaseDamage * (2^StarLevel)`
8. **Set Movement**: `OriginalWalkSpeed`, `OriginalJumpPower`
9. **Set State**: `Frozen = true`, `Aggressive = false`
10. **Save Blueprint**: All attributes saved to blueprint

### Helper Merge
1. **Check**: 3 same `UnitType` + same `StarLevel` + same `IslandId`
2. **Merge**: Destroy 3, spawn 1
3. **Upgrade**: `StarLevel += 1`, `BaseStats *= 2`
4. **Recalculate**: `AttackDamage = BaseDamage * (2^StarLevel)`
5. **Update Blueprint**: Save new stats

### Wave Start
1. **Unfreeze**: `Frozen = false`, `Aggressive = true`
2. **Restore Movement**: `WalkSpeed = OriginalWalkSpeed`, `JumpPower = OriginalJumpPower`

### Wave End
1. **Freeze**: `Frozen = true`, `Aggressive = false`
2. **Reset Position**: Use `OriginalCFrame`
3. **Reset Health**: `Health = MaxHealth`
4. **Reset from Blueprint**: Destroy and respawn from blueprint

---

## 🎯 Best Practices

1. **Always set attributes before parenting** to workspace (so ChildAdded events can read them)
2. **Use consistent naming**: Prefer `HelperType` over `UnitType` for helpers
3. **Store base stats separately** from current stats (for scaling calculations)
4. **Use CFrame for positions** (not Vector3) to preserve rotation
5. **Set IslandId as number** (not string) for performance
6. **Store blueprint key** as `GridId:Row:Col` format
7. **Initialize all required attributes** when spawning
8. **Update blueprints** when stats change (merge, upgrade, etc.)

---

**Last Updated**: 2024
**Version**: 1.0
