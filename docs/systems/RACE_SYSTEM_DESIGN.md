# Race System Design & Implementation Guide

## 🎯 Overview

The Race System adds strategic depth by giving units racial bonuses and penalties. Races affect combat stats, synergies, and special abilities.

---

## 🏛️ Race System Architecture

### Core Components

1. **Race Definitions** - Race data (buffs/debuffs)
2. **Race Manager** - Applies race effects to units
3. **Race Synergy System** - Bonuses for multiple units of same race
4. **Race Combat Integration** - Applies race effects in combat

---

## 📋 Race Definitions

### Race Data Structure

```lua
-- ServerScriptService/Core/RaceDefinitions.server.lua

local RaceDefinitions = {}

-- Race configuration table
RaceDefinitions.RACES = {
	Human = {
		name = "Human",
		description = "Balanced fighters with no weaknesses",
		
		-- Base stat multipliers (applied to BaseDamage, BaseHealth, etc.)
		buffs = {
			damage = 1.0,      -- No damage bonus
			health = 1.0,      -- No health bonus
			speed = 1.0,       -- No speed bonus
			range = 1.0,       -- No range bonus
			cooldown = 1.0,    -- No cooldown bonus
		},
		
		-- Debuffs (weaknesses)
		debuffs = {
			damage = 1.0,      -- No damage penalty
			health = 1.0,      -- No health penalty
		},
		
		-- Special abilities
		special = {
			type = "none",     -- No special ability
		},
		
		-- Synergy bonuses (when X units of same race on island)
		synergy = {
			[3] = { damage = 1.1 },      -- 3 Humans: +10% damage
			[5] = { damage = 1.2, health = 1.1 },  -- 5 Humans: +20% damage, +10% health
			[7] = { damage = 1.3, health = 1.2, speed = 1.1 },  -- 7 Humans: +30% damage, +20% health, +10% speed
		},
	},
	
	Elf = {
		name = "Elf",
		description = "Swift archers with high range",
		
		buffs = {
			damage = 0.9,      -- -10% damage (weakness)
			health = 0.85,     -- -15% health (weakness)
			speed = 1.2,       -- +20% speed (strength)
			range = 1.3,       -- +30% range (strength)
			cooldown = 0.9,    -- -10% cooldown (faster attacks)
		},
		
		debuffs = {
			damage = 1.0,
			health = 1.0,
		},
		
		special = {
			type = "piercing",  -- Attacks pierce through enemies
			value = 0.5,        -- 50% damage to next target
		},
		
		synergy = {
			[3] = { range = 1.15, cooldown = 0.95 },
			[5] = { range = 1.25, cooldown = 0.9, speed = 1.1 },
		},
	},
	
	Demon = {
		name = "Demon",
		description = "Powerful but slow attackers",
		
		buffs = {
			damage = 1.3,      -- +30% damage
			health = 1.2,      -- +20% health
			speed = 0.8,       -- -20% speed (weakness)
			range = 0.9,       -- -10% range (weakness)
			cooldown = 1.2,    -- +20% cooldown (slower attacks)
		},
		
		debuffs = {
			damage = 1.0,
			health = 1.0,
		},
		
		special = {
			type = "lifesteal",  -- Heals on attack
			value = 0.1,         -- 10% of damage as healing
		},
		
		synergy = {
			[3] = { damage = 1.15, health = 1.1 },
			[5] = { damage = 1.25, health = 1.2, special = 1.2 },  -- +20% lifesteal
		},
	},
	
	Beast = {
		name = "Beast",
		description = "Fast melee fighters",
		
		buffs = {
			damage = 1.1,      -- +10% damage
			health = 1.1,      -- +10% health
			speed = 1.3,       -- +30% speed
			range = 0.7,       -- -30% range (melee)
			cooldown = 0.85,   -- -15% cooldown
		},
		
		debuffs = {
			damage = 1.0,
			health = 1.0,
		},
		
		special = {
			type = "frenzy",    -- Attack speed increases on kill
			value = 0.1,        -- +10% attack speed per kill (stacks)
		},
		
		synergy = {
			[3] = { speed = 1.15, cooldown = 0.95 },
			[5] = { speed = 1.25, damage = 1.1 },
		},
	},
	
	Undead = {
		name = "Undead",
		description = "Tanky units that resist damage",
		
		buffs = {
			damage = 0.95,     -- -5% damage
			health = 1.4,      -- +40% health
			speed = 0.9,       -- -10% speed
			range = 1.0,
			cooldown = 1.1,    -- +10% cooldown
		},
		
		debuffs = {
			damage = 1.0,
			health = 1.0,
		},
		
		special = {
			type = "resistance",  -- Takes reduced damage
			value = 0.15,         -- -15% damage taken
		},
		
		synergy = {
			[3] = { health = 1.15, special = 1.1 },  -- +10% resistance
			[5] = { health = 1.25, special = 1.2 },  -- +20% resistance
		},
	},
	
	Angel = {
		name = "Angel",
		description = "Support units that buff allies",
		
		buffs = {
			damage = 0.85,     -- -15% damage
			health = 0.9,      -- -10% health
			speed = 1.0,
			range = 1.2,       -- +20% range
			cooldown = 1.0,
		},
		
		debuffs = {
			damage = 1.0,
			health = 1.0,
		},
		
		special = {
			type = "aura",      -- Buffs nearby allies
			value = 0.1,        -- +10% damage to nearby allies
			range = 10,         -- 10 stud range
		},
		
		synergy = {
			[3] = { special = 1.15 },  -- +15% aura effect
			[5] = { special = 1.25, range = 1.2 },  -- +25% aura, +20% range
		},
	},
}

-- Get race definition
function RaceDefinitions.GetRace(raceName)
	return RaceDefinitions.RACES[raceName]
end

-- Get all race names
function RaceDefinitions.GetAllRaces()
	local races = {}
	for name, _ in pairs(RaceDefinitions.RACES) do
		table.insert(races, name)
	end
	return races
end

return RaceDefinitions
```

---

## 🔧 Race Manager Implementation

### Race Manager Module

```lua
-- ServerScriptService/Core/RaceManager.server.lua

local RaceDefinitions = require(script.Parent.RaceDefinitions)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local workspace = game:GetService("Workspace")

local RaceManager = {}

local helpersFolder = workspace:WaitForChild("Helpers")

-- ===== APPLY RACE TO UNIT =====

-- Apply race buffs/debuffs to a unit
function RaceManager.ApplyRaceToUnit(unit, raceName)
	if not unit or not raceName then return end
	
	local race = RaceDefinitions.GetRace(raceName)
	if not race then
		warn("[RaceManager] Unknown race: " .. tostring(raceName))
		return
	end
	
	-- Set race attribute
	unit:SetAttribute("Race", raceName)
	
	-- Get base stats
	local baseDamage = unit:GetAttribute("BaseDamage") or 10
	local baseHealth = unit:GetAttribute("BaseHealth") or 100
	local baseRange = unit:GetAttribute("BaseRange") or 10
	local baseCooldown = unit:GetAttribute("BaseCooldown") or 1.0
	local baseSpeed = unit:GetAttribute("OriginalWalkSpeed") or 16
	
	-- Apply race buffs to base stats
	local raceDamage = baseDamage * race.buffs.damage
	local raceHealth = baseHealth * race.buffs.health
	local raceRange = baseRange * race.buffs.range
	local raceCooldown = baseCooldown * race.buffs.cooldown
	local raceSpeed = baseSpeed * race.buffs.speed
	
	-- Store race multipliers (for synergy calculations)
	unit:SetAttribute("RaceBuffDamage", race.buffs.damage)
	unit:SetAttribute("RaceBuffHealth", race.buffs.health)
	unit:SetAttribute("RaceBuffSpeed", race.buffs.speed)
	unit:SetAttribute("RaceBuffRange", race.buffs.range)
	unit:SetAttribute("RaceBuffCooldown", race.buffs.cooldown)
	
	-- Store debuff multipliers
	unit:SetAttribute("RaceDebuffDamage", race.debuffs.damage)
	unit:SetAttribute("RaceDebuffHealth", race.debuffs.health)
	
	-- Update base stats (race-modified)
	unit:SetAttribute("BaseDamage", raceDamage)
	unit:SetAttribute("BaseHealth", raceHealth)
	unit:SetAttribute("BaseRange", raceRange)
	unit:SetAttribute("BaseCooldown", raceCooldown)
	unit:SetAttribute("OriginalWalkSpeed", raceSpeed)
	
	-- Recalculate current stats (with star scaling)
	local starLevel = unit:GetAttribute("StarLevel") or 0
	unit:SetAttribute("AttackDamage", raceDamage * (2 ^ starLevel))
	unit:SetAttribute("AttackRange", raceRange)
	unit:SetAttribute("AttackCooldown", raceCooldown)
	
	-- Update humanoid health
	local hum = unit:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.MaxHealth = raceHealth * (2 ^ starLevel)
		hum.Health = math.min(hum.Health, hum.MaxHealth)  -- Cap health
	end
	
	-- Store special ability info
	if race.special and race.special.type ~= "none" then
		unit:SetAttribute("RaceSpecialType", race.special.type)
		unit:SetAttribute("RaceSpecialValue", race.special.value or 0)
		if race.special.range then
			unit:SetAttribute("RaceSpecialRange", race.special.range)
		end
	end
	
	print("[RaceManager] ✅ Applied race " .. raceName .. " to " .. unit.Name)
end

-- ===== SYNERGY SYSTEM =====

-- Count units of each race on an island
function RaceManager.CountRacesOnIsland(islandId)
	local raceCounts = {}
	
	for _, helper in ipairs(helpersFolder:GetChildren()) do
		if helper:IsA("Model") then
			local helperIslandId = helper:GetAttribute("IslandId")
			if helperIslandId == islandId then
				local race = helper:GetAttribute("Race")
				if race then
					raceCounts[race] = (raceCounts[race] or 0) + 1
				end
			end
		end
	end
	
	return raceCounts
end

-- Apply synergy bonuses to all units on an island
function RaceManager.ApplySynergyBonuses(islandId)
	local raceCounts = RaceManager.CountRacesOnIsland(islandId)
	
	-- Apply synergy to each unit
	for _, helper in ipairs(helpersFolder:GetChildren()) do
		if helper:IsA("Model") then
			local helperIslandId = helper:GetAttribute("IslandId")
			if helperIslandId == islandId then
				local race = helper:GetAttribute("Race")
				if race then
					local count = raceCounts[race] or 0
					RaceManager.ApplySynergyToUnit(helper, race, count)
				end
			end
		end
	end
end

-- Apply synergy bonuses to a single unit
function RaceManager.ApplySynergyToUnit(unit, raceName, count)
	local race = RaceDefinitions.GetRace(raceName)
	if not race or not race.synergy then return end
	
	-- Find highest synergy tier we qualify for
	local bestSynergy = nil
	local bestTier = 0
	
	for tier, bonuses in pairs(race.synergy) do
		if count >= tier and tier > bestTier then
			bestTier = tier
			bestSynergy = bonuses
		end
	end
	
	if not bestSynergy then return end
	
	-- Apply synergy multipliers
	local synergyDamage = bestSynergy.damage or 1.0
	local synergyHealth = bestSynergy.health or 1.0
	local synergySpeed = bestSynergy.speed or 1.0
	local synergyRange = bestSynergy.range or 1.0
	local synergyCooldown = bestSynergy.cooldown or 1.0
	local synergySpecial = bestSynergy.special or 1.0
	
	-- Store synergy multipliers
	unit:SetAttribute("SynergyTier", bestTier)
	unit:SetAttribute("SynergyDamage", synergyDamage)
	unit:SetAttribute("SynergyHealth", synergyHealth)
	unit:SetAttribute("SynergySpeed", synergySpeed)
	unit:SetAttribute("SynergyRange", synergyRange)
	unit:SetAttribute("SynergyCooldown", synergyCooldown)
	unit:SetAttribute("SynergySpecial", synergySpecial)
	
	-- Recalculate final stats
	local baseDamage = unit:GetAttribute("BaseDamage") or 10
	local baseHealth = unit:GetAttribute("BaseHealth") or 100
	local baseRange = unit:GetAttribute("BaseRange") or 10
	local baseCooldown = unit:GetAttribute("BaseCooldown") or 1.0
	local baseSpeed = unit:GetAttribute("OriginalWalkSpeed") or 16
	
	local starLevel = unit:GetAttribute("StarLevel") or 0
	
	-- Final stats = (Base * Race) * Synergy * Star
	unit:SetAttribute("AttackDamage", baseDamage * synergyDamage * (2 ^ starLevel))
	unit:SetAttribute("AttackRange", baseRange * synergyRange)
	unit:SetAttribute("AttackCooldown", baseCooldown * synergyCooldown)
	
	local hum = unit:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.MaxHealth = baseHealth * synergyHealth * (2 ^ starLevel)
		hum.Health = math.min(hum.Health, hum.MaxHealth)
	end
	
	if synergySpeed ~= 1.0 then
		unit:SetAttribute("OriginalWalkSpeed", baseSpeed * synergySpeed)
		local hum = unit:FindFirstChildOfClass("Humanoid")
		if hum and not unit:GetAttribute("Frozen") then
			hum.WalkSpeed = baseSpeed * synergySpeed
		end
	end
	
	print("[RaceManager] ✅ Applied synergy tier " .. bestTier .. " to " .. unit.Name .. " (count: " .. count .. ")")
end

-- ===== INITIALIZATION =====

-- Apply race to unit when it's placed
function RaceManager.InitializeUnit(unit, raceName)
	RaceManager.ApplyRaceToUnit(unit, raceName)
	
	-- Apply synergy after a brief delay (to ensure all units are placed)
	task.wait(0.1)
	local islandId = unit:GetAttribute("IslandId")
	if islandId then
		RaceManager.ApplySynergyBonuses(islandId)
	end
end

-- Recalculate all synergies on an island (call after merge, placement, etc.)
function RaceManager.RecalculateIslandSynergies(islandId)
	RaceManager.ApplySynergyBonuses(islandId)
end

return RaceManager
```

---

## ⚔️ Combat Integration

### Modify CombatService to Use Race Stats

```lua
-- In CombatService.server.lua, modify doAttack():

local function doAttack(attacker: Model, target: Model, damage: number, attackSpeed: number, range: number, grid: BasePart?)
	-- ... existing code ...
	
	-- Get race-modified damage
	local baseDamage = attacker:GetAttribute("AttackDamage") or damage
	local raceDamage = baseDamage
	
	-- Apply synergy multiplier if exists
	local synergyDamage = attacker:GetAttribute("SynergyDamage")
	if synergyDamage and synergyDamage ~= 1.0 then
		raceDamage = baseDamage * synergyDamage
	end
	
	-- Apply special abilities
	local raceSpecial = attacker:GetAttribute("RaceSpecialType")
	if raceSpecial == "lifesteal" then
		local lifestealValue = attacker:GetAttribute("RaceSpecialValue") or 0
		local healAmount = raceDamage * lifestealValue
		local attackerHum = attacker:FindFirstChildOfClass("Humanoid")
		if attackerHum then
			attackerHum.Health = math.min(attackerHum.Health + healAmount, attackerHum.MaxHealth)
		end
	elseif raceSpecial == "piercing" then
		-- Handle piercing attacks (damage multiple enemies)
		-- Implementation depends on your combat system
	end
	
	-- Apply damage resistance if target has it
	local targetRaceSpecial = target:GetAttribute("RaceSpecialType")
	if targetRaceSpecial == "resistance" then
		local resistanceValue = target:GetAttribute("RaceSpecialValue") or 0
		local synergySpecial = target:GetAttribute("SynergySpecial") or 1.0
		local totalResistance = resistanceValue * synergySpecial
		raceDamage = raceDamage * (1 - totalResistance)
	end
	
	-- Use race-modified damage
	targetHum:TakeDamage(raceDamage)
	
	-- ... rest of existing code ...
end
```

---

## 🎮 Integration Points

### 1. Helper Placement

```lua
-- In HelperPlacement.server.lua or GridHelperSpawnerServer.server.lua

local RaceManager = require(script.Parent.Parent.Core.RaceManager)

-- After spawning helper:
local helper = template:Clone()
-- ... set attributes ...

-- Get race from template or assign default
local race = template:GetAttribute("Race") or "Human"

-- Apply race
RaceManager.InitializeUnit(helper, race)

-- Parent to workspace
helper.Parent = helpersFolder

-- Recalculate synergies for island
local islandId = helper:GetAttribute("IslandId")
if islandId then
	RaceManager.RecalculateIslandSynergies(islandId)
end
```

### 2. Helper Merge

```lua
-- In HelperMerge.server.lua

local RaceManager = require(script.Parent.Parent.Core.RaceManager)

-- After merging:
local mergedHelper = -- ... create merged helper ...

-- Preserve race from original helpers
local race = originalHelpers[1]:GetAttribute("Race") or "Human"
RaceManager.InitializeUnit(mergedHelper, race)

-- Recalculate synergies
local islandId = mergedHelper:GetAttribute("IslandId")
if islandId then
	RaceManager.RecalculateIslandSynergies(islandId)
end
```

### 3. Wave End Reset

```lua
-- In HelperBlueprintManager.server.lua or WaveManagerServer.server.lua

local RaceManager = require(script.Parent.Parent.Core.RaceManager)

-- After respawning from blueprint:
local helper = spawnFromBlueprint(blueprint)

-- Get race from blueprint
local race = blueprint:GetAttribute("Race") or "Human"

-- Reapply race (synergy will be recalculated)
RaceManager.InitializeUnit(helper, race)
```

---

## 📊 Race Assignment Methods

### Method 1: Template-Based (Recommended)
Set race in the template model:
```lua
-- In Roblox Studio, set attribute on template:
Template:SetAttribute("Race", "Elf")
```

### Method 2: Unit Type Mapping
Map unit types to races:
```lua
local UNIT_RACE_MAP = {
	MagicHobo = "Human",
	Appraiser = "Elf",
	Indigenous = "Beast",
	Tweaker = "Demon",
}
```

### Method 3: Random Assignment
Randomly assign race when placing:
```lua
local races = RaceDefinitions.GetAllRaces()
local randomRace = races[math.random(1, #races)]
```

---

## 🎯 Future Enhancements

1. **Race Mastery System**: Players unlock race bonuses through gameplay
2. **Race Evolution**: Units can evolve to higher race tiers
3. **Race Combos**: Special bonuses for specific race combinations
4. **Race Shop**: Buy race-specific units from special shop
5. **Race Events**: Temporary race bonuses during events

---

## 📝 Testing Checklist

- [ ] Race applies correctly on placement
- [ ] Synergy bonuses activate at correct thresholds
- [ ] Stats recalculate correctly after merge
- [ ] Race persists through wave resets
- [ ] Special abilities work (lifesteal, piercing, etc.)
- [ ] Synergy updates when units are removed
- [ ] Multiple races on same island work correctly
- [ ] Race attributes saved in blueprints

---

**Last Updated**: 2024
**Version**: 1.0
