-- ===== WAVE MANAGER SERVER - REFACTORED FOR MULTI-ISLAND SYSTEM =====
-- This script manages wave spawning per island with proper ownership checks
-- Location: ServerScriptService > WaveManagerServer.server.lua

print("[WaveManagerServer] ========================================")
print("[WaveManagerServer] ✅ REFACTORED VERSION - Starting...")
print("[WaveManagerServer] ========================================")

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local workspace = game:GetService("Workspace")

-- ===== CONFIG =====
local GRID_SIZE = 5
local GRID_COLS = 10
local GRID_ROWS = 10
local PLAYER_MIN_ROW, PLAYER_MAX_ROW = 1, 5
local ENEMY_MIN_ROW, ENEMY_MAX_ROW = 6, 10

local PREP_TIME = 10
local SPAWN_INTERVAL = 1.2
local BASE_ENEMIES = 4
local ENEMIES_PER_WAVE = 1.5
local MINI_BOSS_EVERY = 5
local BOSS_EVERY = 15

-- Combat defaults
local DEFAULT_HELPER_DAMAGE = 12
local DEFAULT_HELPER_RANGE = 14
local DEFAULT_HELPER_COOLDOWN = 1.1
local DEFAULT_ENEMY_DAMAGE = 8
local DEFAULT_ENEMY_RANGE = 7
local DEFAULT_ENEMY_COOLDOWN = 1.3

-- ===== DEBUG FLAG =====
local DEBUG = false
local function dprint(...)
	if DEBUG then print(...) end
end

-- ===== PATHS =====
local ENEMY_TEMPLATES = ServerStorage:FindFirstChild("EnemyTemplates")
if not ENEMY_TEMPLATES then
	warn("[WaveManagerServer] ❌ EnemyTemplates folder not found in ServerStorage!")
	ENEMY_TEMPLATES = Instance.new("Folder")
	ENEMY_TEMPLATES.Name = "EnemyTemplates"
	ENEMY_TEMPLATES.Parent = ServerStorage
end

-- Ensure folders exist
local helpersFolder = workspace:FindFirstChild("Helpers")
if not helpersFolder then
	helpersFolder = Instance.new("Folder")
helpersFolder.Name = "Helpers"
helpersFolder.Parent = workspace
end

local enemiesFolder = workspace:FindFirstChild("Enemies")
if not enemiesFolder then
	enemiesFolder = Instance.new("Folder")
enemiesFolder.Name = "Enemies"
enemiesFolder.Parent = workspace
end

-- ===== FORCE ISLAND ID ASSIGNMENT (CRITICAL) =====
local islandFolder = workspace:FindFirstChild("Island")
if islandFolder then
	local nextIslandId = 1
	
	-- find max existing ID first
	for _, island in ipairs(islandFolder:GetChildren()) do
		if island:IsA("Model") then
			local id = island:GetAttribute("IslandId")
			if typeof(id) == "number" and id >= nextIslandId then
				nextIslandId = id + 1
			end
		end
	end
	
	-- assign missing IDs
	for _, island in ipairs(islandFolder:GetChildren()) do
		if island:IsA("Model") then
			-- only real islands (must contain Gridfloor)
			if island:FindFirstChild("Gridfloor", true) then
				if typeof(island:GetAttribute("IslandId")) ~= "number" then
					island:SetAttribute("IslandId", nextIslandId)
					print("[WaveManagerServer] ✅ Assigned IslandId " .. nextIslandId .. " to " .. island:GetFullName())
					nextIslandId = nextIslandId + 1
				end
			end
		end
	end
else
	warn("[WaveManagerServer] ⚠️ Island folder not found in workspace - island auto-assignment skipped")
end

-- ===== ISLAND MANAGEMENT =====
-- Island caches (declared early for use in functions)
local islandById = {}
local islandByGridId = {} -- grid:GetFullName() -> island (O(1) lookup)

-- STRICT: Get numeric IslandId (never fall back to Name)
local function getIslandIdStrict(island)
	if not island then return nil end
	local id = island:GetAttribute("IslandId")
	if typeof(id) ~= "number" then
		warn("[WaveManagerServer] ❌ Island missing numeric IslandId: " .. island:GetFullName())
		return nil
	end
	return id
end

-- Find island model from a grid part (by walking up hierarchy)
local function getIslandFromGrid(gridPart)
	if not gridPart then return nil end
	
	-- Walk up the hierarchy to find Island model
	local current = gridPart
	while current and current.Parent and current.Parent ~= workspace do
		if current:IsA("Model") then
			-- Check if it's an island (must have numeric IslandId)
			local islandId = current:GetAttribute("IslandId")
			if typeof(islandId) == "number" then
				return current
			end
		end
		current = current.Parent
	end
	
	return nil
end

-- Find island from a GridId (full name of Gridfloor part) - OPTIMIZED with cache
local function getIslandFromGridId(gridId)
	-- Fast O(1) lookup from cache
	local island = islandByGridId[gridId]
	if island and island.Parent then
		return island
	end
	
	-- Fallback: slow path (should rarely happen)
	local gridPart = workspace:FindFirstChild(gridId, true)
	if not gridPart then
		-- Try searching for Gridfloor parts
		for _, descendant in ipairs(workspace:GetDescendants()) do
			if descendant:IsA("BasePart") and descendant.Name == "Gridfloor" then
				if descendant:GetFullName() == gridId then
					gridPart = descendant
					break
				end
			end
		end
	end
	
	if gridPart then
		local foundIsland = getIslandFromGrid(gridPart)
		if foundIsland then
			-- Cache it for next time
			islandByGridId[gridId] = foundIsland
		end
		return foundIsland
	end
	
	return nil
end

-- Get grid part from island (finds Gridfloor part within island)
local function getGridFromIsland(island)
	if not island then return nil end
	
	-- Search for Gridfloor part in island descendants
	for _, descendant in ipairs(island:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Name == "Gridfloor" then
			return descendant
		end
	end
	
	return nil
end

-- Get island owner (checks Island model's OwnerUserId attribute OR finds from helpers)
local function getIslandOwner(island)
	if not island then return nil end
	
	-- First check island attribute
	local ownerId = island:GetAttribute("OwnerUserId")
	if typeof(ownerId) == "number" and ownerId > 0 then
		return ownerId
	end
	
	-- Fallback: Find owner from helpers on this island's grid
	local grid = getGridFromIsland(island)
	if grid then
		local gridId = grid:GetFullName()
		for _, helper in ipairs(helpersFolder:GetChildren()) do
			if helper:IsA("Model") and helper:GetAttribute("GridId") == gridId then
				local helperOwnerId = helper:GetAttribute("OwnerUserId")
				if typeof(helperOwnerId) == "number" and helperOwnerId > 0 then
					-- Auto-set island ownership
					island:SetAttribute("OwnerUserId", helperOwnerId)
					return helperOwnerId
				end
			end
		end
	end
	
	return nil
end

-- Get all islands in workspace (REQUIRES Gridfloor part)
local function getAllIslands()
	local islands, seen = {}, {}

	for _, m in ipairs(workspace:GetDescendants()) do
		if m:IsA("Model") and m:FindFirstChild("Gridfloor", true) then
			local id = m:GetAttribute("IslandId")
			if typeof(id) == "number" and not seen[m] then
				seen[m] = true
				table.insert(islands, m)
			end
		end
	end

	return islands
end

-- Island cache functions (islandById and islandByGridId declared above)
local function indexIsland(island)
	local grid = getGridFromIsland(island)
	if grid then
		islandByGridId[grid:GetFullName()] = island
	end
end

local function rebuildIslandCache()
	table.clear(islandById)
	table.clear(islandByGridId)
	for _, isl in ipairs(getAllIslands()) do
		local id = getIslandIdStrict(isl)
		if id then 
			islandById[id] = isl
			indexIsland(isl)
		end
	end
end

rebuildIslandCache()
workspace.DescendantAdded:Connect(function(obj)
	if obj:IsA("Model") and obj:FindFirstChild("Gridfloor", true) and typeof(obj:GetAttribute("IslandId"))=="number" then
		task.wait(0.1)
		rebuildIslandCache()
	end
end)

-- Find player's island by checking their helpers
local function findPlayerIsland(userId)
	-- Check all helpers to find which island the player owns
	for _, helper in ipairs(helpersFolder:GetChildren()) do
		if helper:IsA("Model") then
			local helperOwnerId = helper:GetAttribute("OwnerUserId")
			if helperOwnerId == userId then
	local gridId = helper:GetAttribute("GridId")
	if gridId then
					local island = getIslandFromGridId(gridId)
					if island then
						-- Auto-set ownership
						island:SetAttribute("OwnerUserId", userId)
						return island
						end
					end
				end
			end
		end
	
	return nil
end

-- ===== WAVE DIFFICULTY SYSTEM =====
local function getWaveDifficulty(wave)
	local baseMultiplier = 1.0 + ((wave - 1) * 0.1)
	local healthMultiplier = math.pow(1.12, wave - 1)
	local damageMultiplier = math.pow(1.08, wave - 1)
	local spawnMultiplier = 1.0 + ((wave - 1) * 0.15)
	
	return {
		wave = wave,
		baseMultiplier = baseMultiplier,
		healthMultiplier = healthMultiplier,
		damageMultiplier = damageMultiplier,
		spawnMultiplier = spawnMultiplier,
	}
end

-- ===== ENEMY TYPE PROGRESSION =====
local ENEMY_TYPE_POOLS = {
	early = {
		{name = "EnemyGrunt", weight = 100},
	},
	mid = {
		{name = "EnemyGrunt", weight = 60},
		{name = "Goons", weight = 30},
		{name = "Guz", weight = 10},
	},
	late = {
		{name = "EnemyGrunt", weight = 40},
		{name = "Goons", weight = 30},
		{name = "Guz", weight = 20},
		{name = "Donald", weight = 10},
	},
	elite = {
		{name = "EnemyGrunt", weight = 30},
		{name = "Goons", weight = 25},
		{name = "Guz", weight = 20},
		{name = "Donald", weight = 15},
		{name = "MoneyMan", weight = 10},
	},
}

local function getEnemyTypePool(wave)
	if wave >= 13 then
		return ENEMY_TYPE_POOLS.elite
	elseif wave >= 8 then
		return ENEMY_TYPE_POOLS.late
	elseif wave >= 4 then
		return ENEMY_TYPE_POOLS.mid
	else
		return ENEMY_TYPE_POOLS.early
	end
end

local function selectEnemyType(wave)
	local pool = getEnemyTypePool(wave)
	local totalWeight = 0
	for _, entry in ipairs(pool) do
		totalWeight = totalWeight + entry.weight
	end
	
	local random = math.random(1, totalWeight)
	local currentWeight = 0
	
	for _, entry in ipairs(pool) do
		currentWeight = currentWeight + entry.weight
		if random <= currentWeight then
			return entry.name
		end
	end
	
	return "EnemyGrunt"
end

-- ===== WAVE PLAN =====
local function getWavePlan(wave)
	local isBoss = (wave % BOSS_EVERY == 0)
	local isMiniBoss = (not isBoss) and (wave % MINI_BOSS_EVERY == 0)
	
	local baseCount = BASE_ENEMIES + math.floor((wave - 1) * ENEMIES_PER_WAVE)
	local difficulty = getWaveDifficulty(wave)
	local adds = math.floor(baseCount * difficulty.spawnMultiplier)
	
	if isMiniBoss then
		adds = math.floor(adds * 0.75)
	end
	if isBoss then
		adds = math.floor(adds * 0.5)
	end
	
	return {
		wave = wave,
		isMiniBoss = isMiniBoss,
		isBoss = isBoss,
		addCount = math.max(1, adds),
		difficulty = difficulty,
	}
end

-- ===== NPC ORIGINAL POSITION TRACKING =====
local npcOriginalCFrames = {} -- npc -> CFrame (stores original spawn position)

local function storeNPCPosition(npc)
	local root = npc:FindFirstChild("HumanoidRootPart") or npc.PrimaryPart
	if root then
		npcOriginalCFrames[npc] = root.CFrame
		npc:SetAttribute("OriginalCFrame", root.CFrame)
		print("[WaveManagerServer] 📍 Stored original position for " .. npc.Name)
	end
end

local function resetNPCPosition(npc)
	local originalCFrame = npcOriginalCFrames[npc] or npc:GetAttribute("OriginalCFrame")
	if not originalCFrame or typeof(originalCFrame) ~= "CFrame" then
		return false
	end
	
	local root = npc:FindFirstChild("HumanoidRootPart") or npc.PrimaryPart
	if not root then
	return false
end

	-- Stop all velocity
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	
	-- Reset position
	npc:PivotTo(originalCFrame)
	
	print("[WaveManagerServer] 🔄 Reset position for " .. npc.Name)
	return true
end

-- Get ALL helpers for an island (including dead ones)
local function getAllHelpersForIsland(island)
	if not island then return {} end
	local grid = getGridFromIsland(island)
	if not grid then return {} end

	local gridId = grid:GetFullName()
	local helpers = {}

	for _, helper in ipairs(helpersFolder:GetChildren()) do
		if helper:IsA("Model") then
			if helper:GetAttribute("GridId") == gridId then
				table.insert(helpers, helper)
			end
		end
	end

	return helpers
end

-- ===== NPC FREEZE/UNFREEZE (NO ANCHORING) =====
local function ensureAnimator(hum)
	if not hum then return end
	if not hum:FindFirstChildOfClass("Animator") then
		Instance.new("Animator").Parent = hum
	end
end

local function freezeNPC(npc, isEnemy)
	local hum = npc:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	
	-- prevent spam re-freeze
	if npc:GetAttribute("Frozen") == true then
		return
	end
	npc:SetAttribute("Frozen", true)

	ensureAnimator(hum)

	-- store originals once
	if npc:GetAttribute("OriginalWalkSpeed") == nil then
		npc:SetAttribute("OriginalWalkSpeed", hum.WalkSpeed > 0 and hum.WalkSpeed or 16)
	end
	if npc:GetAttribute("OriginalJumpPower") == nil then
		npc:SetAttribute("OriginalJumpPower", hum.JumpPower > 0 and hum.JumpPower or 50)
	end

	-- freeze movement only (DO NOT disable any scripts)
	hum.WalkSpeed = 0
	hum.JumpPower = 0
	hum:Move(Vector3.zero)

	npc:SetAttribute("Aggressive", false)
end

local function unfreezeNPC(npc, isEnemy)
	local hum = npc:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	
	npc:SetAttribute("Frozen", false)

	ensureAnimator(hum)

	local ws = npc:GetAttribute("OriginalWalkSpeed")
	local jp = npc:GetAttribute("OriginalJumpPower")
	if typeof(ws) ~= "number" or ws <= 0 then ws = 16 end
	if typeof(jp) ~= "number" or jp <= 0 then jp = 50 end

	hum.WalkSpeed = ws
	hum.JumpPower = jp

	npc:SetAttribute("Aggressive", true)
end

-- Make body parts fly away at high speed and destroy after delay
local function explodeAndDestroy(npc, delay)
	delay = delay or 1
	
	-- Apply high velocity to all body parts to make them fly away
	for _, part in ipairs(npc:GetDescendants()) do
		if part:IsA("BasePart") then
			-- Make sure part is not anchored so it can move
			part.Anchored = false
			
			-- Apply random high velocity in all directions
			local randomDirection = Vector3.new(
				(math.random() - 0.5) * 200,
				math.random() * 100 + 50, -- Upward bias
				(math.random() - 0.5) * 200
			)
			part.AssemblyLinearVelocity = randomDirection
			
			-- Add random angular velocity for spinning effect
			part.AssemblyAngularVelocity = Vector3.new(
				(math.random() - 0.5) * 50,
				(math.random() - 0.5) * 50,
				(math.random() - 0.5) * 50
			)
		end
	end
	
	-- Destroy after delay
	task.wait(delay)
	if npc and npc.Parent then
		npc:Destroy()
	end
end

-- Revive + heal helpers at end of wave
local function reviveAndHealHelpers(island)
	local helpers = getAllHelpersForIsland(island)

	for _, helper in ipairs(helpers) do
		local hum = helper:FindFirstChildOfClass("Humanoid")
		if hum then
			-- REVIVE if dead
			if hum.Health <= 0 then
				-- Humanoid:ChangeState helps break "Dead" state weirdness sometimes
				hum:ChangeState(Enum.HumanoidStateType.GettingUp)
				hum.Health = 1
			end

			-- HEAL to full
			hum.Health = hum.MaxHealth
		end

		-- send back + freeze for prep
		resetNPCPosition(helper)
		freezeNPC(helper, false)
	end
end

-- ===== TRACKED PER-ISLAND LISTS (OPTIMIZATION) =====
local helpersByIsland = {} -- islandId -> { [model]=true }
local enemiesByIsland = {} -- islandId -> { [model]=true }

local function ensureSet(t, key)
	t[key] = t[key] or {}
	return t[key]
end

local function addToSet(t, islandId, model)
	if not islandId then return end
	ensureSet(t, islandId)[model] = true
end

local function removeFromSet(t, islandId, model)
	if not islandId then return end
	local set = t[islandId]
	if set then set[model] = nil end
end

local function getLivingFromSet(set)
	local list = {}
	for model in pairs(set or {}) do
		if model.Parent then
			local hum = model:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 then
				table.insert(list, model)
			end
		end
	end
	return list
end

-- ===== ENEMY OCCUPANCY SYSTEM =====
local enemyOccupied = {} -- islandId -> {row -> {col -> true}}

local function ensureEnemyOcc(islandId)
	if not enemyOccupied[islandId] then
		enemyOccupied[islandId] = {}
		for r = 1, GRID_ROWS do
			enemyOccupied[islandId][r] = {}
		end
	end
end

local function pickRandomEnemyCell(islandId)
	ensureEnemyOcc(islandId)
	
	local availableCells = {}
	for r = ENEMY_MIN_ROW, ENEMY_MAX_ROW do
		for c = 1, GRID_COLS do
			if not enemyOccupied[islandId][r][c] then
				table.insert(availableCells, {row = r, col = c})
			end
		end
	end
	
	if #availableCells == 0 then
		warn("[WaveManagerServer] ❌ No free enemy cells on island " .. tostring(islandId))
		return nil
	end
	
	local selected = availableCells[math.random(1, #availableCells)]
	return selected.row, selected.col
end

-- Get ALL enemies for an island (including dead ones)
local function getAllEnemiesForIsland(island)
	if not island then return {} end
	local grid = getGridFromIsland(island)
	if not grid then return {} end

	local islandId = getIslandIdStrict(island)
	local gridId = grid:GetFullName()

	local enemies = {}
	for _, enemy in ipairs(enemiesFolder:GetChildren()) do
		if enemy:IsA("Model") then
			local eIslandId = enemy:GetAttribute("IslandId")
			if (typeof(eIslandId) == "number" and islandId and eIslandId == islandId) or (enemy:GetAttribute("GridId") == gridId) then
				table.insert(enemies, enemy)
			end
		end
	end
	return enemies
end

-- Clear ALL enemy bodies for an island (alive or dead)
local function destroyEnemiesForIsland(island)
	local enemies = getAllEnemiesForIsland(island)
	for _, enemy in ipairs(enemies) do
		-- free occupancy if it had a cell
		local islandId = enemy:GetAttribute("IslandId")
		local r = enemy:GetAttribute("SpawnRow")
		local c = enemy:GetAttribute("SpawnCol")
		if typeof(islandId) == "number" and typeof(r) == "number" and typeof(c) == "number" then
			if enemyOccupied[islandId] and enemyOccupied[islandId][r] then
				enemyOccupied[islandId][r][c] = nil
			end
		end

		npcOriginalCFrames[enemy] = nil
		enemy:Destroy()
	end
end

-- IMPORTANT: reset occupancy for the enemy rows so next wave can spawn cleanly
local function clearEnemyOccupancy(islandId)
	if not islandId then return end
	ensureEnemyOcc(islandId)
	for r = ENEMY_MIN_ROW, ENEMY_MAX_ROW do
		for c = 1, GRID_COLS do
			enemyOccupied[islandId][r][c] = nil
		end
	end
end

-- ===== ENEMY TEMPLATE RESOLUTION =====
local function resolveEnemyTemplate(templateName)
	local found = ENEMY_TEMPLATES:FindFirstChild(templateName)
	if not found then
		warn("[WaveManagerServer] ❌ Template not found: " .. templateName)
		return nil
	end
	
	if found:IsA("Model") then
		local hasHumanoid = found:FindFirstChildOfClass("Humanoid")
		local hasRoot = found:FindFirstChild("HumanoidRootPart") or found.PrimaryPart
		if hasHumanoid and hasRoot then
		return found
		end
	end
	
	if found:IsA("Folder") then
		local model = found:FindFirstChildOfClass("Model")
		if model then
			local hasHumanoid = model:FindFirstChildOfClass("Humanoid")
			local hasRoot = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
			if hasHumanoid and hasRoot then
				return model
			end
			end
		end
		
		return nil
	end
	
-- ===== ENEMY SPAWNING =====
local function spawnEnemyForIsland(island, userId, templateName, wave, isMiniBoss, isBoss)
	if not island then
		warn("[WaveManagerServer] ❌ Cannot spawn: Island is nil")
	return nil
end

	-- STRICT: never spawn on unowned or mismatched islands
	local ownerId = getIslandOwner(island)
	if not ownerId then
		warn("[WaveManagerServer] ❌ Cannot spawn: Island has no owner")
		return nil
	end

	if ownerId ~= userId then
		warn("[WaveManagerServer] ❌ Cannot spawn: Island owned by " .. tostring(ownerId) .. ", not " .. tostring(userId))
		return nil
	end

	-- Get grid from island
	local grid = getGridFromIsland(island)
	if not grid then
		warn("[WaveManagerServer] ❌ Cannot spawn: Island has no Gridfloor part")
		return nil
	end
	
	-- Resolve template
	local template = resolveEnemyTemplate(templateName)
	if not template then
		warn("[WaveManagerServer] ❌ Failed to resolve template: " .. templateName)
		return nil
	end

	-- Pick spawn cell
	local islandId = getIslandIdStrict(island)
	if not islandId then
		warn("[WaveManagerServer] ❌ Cannot spawn: Island missing numeric IslandId")
		return nil
	end
	local row, col = pickRandomEnemyCell(islandId)
	if not row then
		return nil
	end
	
	-- Calculate cell position
	local cellX = (col - (GRID_COLS / 2) - 0.5) * GRID_SIZE
	local cellZ = (row - (GRID_ROWS / 2) - 0.5) * GRID_SIZE
	local gridCFrame = grid.CFrame
	local worldPos = gridCFrame:PointToWorldSpace(Vector3.new(cellX, 2, cellZ))
	
	-- Calculate facing direction: enemies face towards helpers (towards player side)
	-- Player side is rows 1-5, enemy side is rows 6-10
	-- In grid space: player side is negative Z, enemy side is positive Z
	-- So enemies should face in the -Z direction (towards lower row numbers)
	-- Face towards player side (negative Z in grid space = -gridCFrame.LookVector in world space)
	local faceDirection = gridCFrame.LookVector
	local cframe = CFrame.new(worldPos, worldPos + faceDirection)
	
	-- Clone and position
	local enemy = template:Clone()
	enemy.Name = templateName .. "_" .. islandId .. "_" .. os.time()
	
	-- Set attributes (CRITICAL: Set IslandId and GridId)
	enemy:SetAttribute("TargetUserId", userId)
	enemy:SetAttribute("IslandId", islandId)
	enemy:SetAttribute("GridId", grid:GetFullName()) -- Also set GridId for compatibility
	enemy:SetAttribute("Wave", wave)
	enemy:SetAttribute("IsMiniBoss", isMiniBoss)
	enemy:SetAttribute("IsBoss", isBoss)
	
	print("[WaveManagerServer]   ✅ Set attributes: IslandId=" .. tostring(islandId) .. ", GridId=" .. grid:GetFullName())
	
	-- Apply difficulty scaling
	local difficulty = getWaveDifficulty(wave)
	local hum = enemy:FindFirstChildOfClass("Humanoid")
	if hum then
		local baseMax = hum.MaxHealth
		local healthMult = difficulty.healthMultiplier
		local damageMult = difficulty.damageMultiplier

		if isMiniBoss then
			healthMult = healthMult * 2.5
			damageMult = damageMult * 1.6
		end
		if isBoss then
			healthMult = healthMult * 6.0
			damageMult = damageMult * 2.2
		end

		hum.MaxHealth = math.floor(baseMax * healthMult)
		hum.Health = hum.MaxHealth
		enemy:SetAttribute("DamageMult", damageMult)
	end

	-- Position enemy
	enemy:PivotTo(cframe)
	
	-- Store original position
	storeNPCPosition(enemy)
	
	-- Freeze enemy (no anchoring)
	freezeNPC(enemy, true)
	
	-- Mark cell occupied
	ensureEnemyOcc(islandId)
	enemyOccupied[islandId][row][col] = true
	enemy:SetAttribute("SpawnRow", row)
	enemy:SetAttribute("SpawnCol", col)
	
	-- Parent to enemies folder
	enemy.Parent = enemiesFolder
	
	-- Track enemy in per-island set (OPTIMIZATION)
	addToSet(enemiesByIsland, islandId, enemy)
	
	-- Cleanup on death - explode then destroy after 1 second
	if hum then
		hum.Died:Connect(function()
			-- Free cell
			if enemyOccupied[islandId] and enemyOccupied[islandId][row] then
				enemyOccupied[islandId][row][col] = nil
			end
			-- Remove from tracked set
			removeFromSet(enemiesByIsland, islandId, enemy)
			-- Clean up stored position
			npcOriginalCFrames[enemy] = nil
			-- Explode and destroy after 1 second
			task.spawn(function()
				explodeAndDestroy(enemy, 1)
			end)
		end)
	end
	
	-- Track removal when enemy is removed from workspace
	enemy.AncestryChanged:Connect(function(_, parent)
		if not parent then
			removeFromSet(enemiesByIsland, islandId, enemy)
		end
	end)

	dprint("[WaveManagerServer] ✅ Spawned " .. templateName .. " on island " .. tostring(islandId) .. " (Wave " .. wave .. ")")
	return enemy
end

-- ===== WAVE STATE MANAGEMENT (spawn locks) =====
local spawningWaveByIsland = {} -- islandId -> true/false
local spawnedWaveNumberByIsland = {} -- islandId -> number

-- ===== WAVE SPAWNING =====
local function spawnEnemiesForWaveOnIsland(island, userId, wave)
	if not island then
		warn("[WaveManagerServer] ❌ Cannot spawn: Island is nil")
		return false
	end

	local ownerId = getIslandOwner(island)
	if not ownerId then
		warn("[WaveManagerServer] ❌ Cannot spawn: Island has no owner")
		return false
	end
	if ownerId ~= userId then
		warn("[WaveManagerServer] ❌ Cannot spawn: Island owned by different player")
		return false
	end

	local islandId = getIslandIdStrict(island)
	if not islandId then
		warn("[WaveManagerServer] ❌ Cannot spawn: Island missing numeric IslandId")
		return false
	end

	if spawningWaveByIsland[islandId] then
		warn("[WaveManagerServer] ⚠️ Spawn already in progress for island " .. tostring(islandId))
		return false
	end
	if spawnedWaveNumberByIsland[islandId] == wave then
		warn("[WaveManagerServer] ⚠️ Wave " .. wave .. " already spawned for island " .. tostring(islandId))
		return false
	end

	spawningWaveByIsland[islandId] = true
	local plan = getWavePlan(wave)

	-- Spawn boss/mini-boss first (still instant, just priority)
	if plan.isBoss then
		if not spawnEnemyForIsland(island, userId, "Boss", wave, false, true) then
			spawningWaveByIsland[islandId] = false
			return false
		end
	elseif plan.isMiniBoss then
		if not spawnEnemyForIsland(island, userId, "MiniBoss", wave, true, false) then
			spawningWaveByIsland[islandId] = false
			return false
		end
	end

	-- Spawn adds in micro-batches (prevents lag spike)
	local function spawnAddsInBatches(count, batchSize)
		batchSize = batchSize or 6
		local spawned = 0
		
		for i = 1, count do
			local enemyType = selectEnemyType(wave)
			if spawnEnemyForIsland(island, userId, enemyType, wave, false, false) then
				spawned = spawned + 1
			end
			
			if (i % batchSize) == 0 then
				task.wait() -- Yield 1 frame, prevents server hitch
			end
		end
		
		return spawned
	end
	
	local spawnedCount = spawnAddsInBatches(plan.addCount, 6)

	spawnedWaveNumberByIsland[islandId] = wave
	spawningWaveByIsland[islandId] = false

	print("[WaveManagerServer] ✅ Spawned " .. spawnedCount .. " enemies for wave " .. wave .. " on island " .. tostring(islandId))
	return true
end

-- ===== WAVE STATE MANAGEMENT =====
local activeWavesByIsland = {} -- islandId -> boolean (true = wave loop running)
local waveActiveFlags = {} -- islandId -> boolean (true = wave is active, NPCs aggressive)
local currentWaveNumbers = {} -- islandId -> number

-- Get enemies for an island - OPTIMIZED with tracked sets
local function getEnemiesForIsland(island)
	if not island then return {} end
	local islandId = getIslandIdStrict(island)
	if not islandId then return {} end
	return getLivingFromSet(enemiesByIsland[islandId])
end

-- Get helpers for an island - OPTIMIZED with tracked sets
local function getHelpersForIsland(island)
	if not island then 
		dprint("[WaveManagerServer] ⚠️ getHelpersForIsland: island is nil")
		return {} 
	end
	
	local islandId = getIslandIdStrict(island)
	if not islandId then 
		dprint("[WaveManagerServer] ⚠️ getHelpersForIsland: no islandId for island " .. tostring(island.Name))
		return {} 
	end
	
	return getLivingFromSet(helpersByIsland[islandId])
end

-- ===== WAVE START =====
local function startWaveForPlayer(player)
	local userId = player.UserId
	
	-- Find player's island (try multiple methods)
	local playerIsland = nil
	
	-- Method 1: Find by checking helpers (most reliable)
	playerIsland = findPlayerIsland(userId)
	
	-- Method 2: Fallback - check all islands
	if not playerIsland then
		for _, island in ipairs(getAllIslands()) do
			local ownerId = getIslandOwner(island)
			if ownerId == userId then
				playerIsland = island
			break
			end
		end
	end
	
	if not playerIsland then
		warn("[WaveManagerServer] ❌ Player " .. player.Name .. " has no island")
		warn("[WaveManagerServer]   - Make sure player has placed at least one helper")
		warn("[WaveManagerServer]   - Helper must have GridId attribute pointing to a Gridfloor part")
		return
	end
	
	-- Get IslandId (must be numeric)
	local islandId = getIslandIdStrict(playerIsland)
	if not islandId then
		warn("[WaveManagerServer] ❌ Cannot start wave: Island missing numeric IslandId")
		return
	end
	
	-- CRITICAL: Prevent duplicate wave loops
	if activeWavesByIsland[islandId] then
		warn("[WaveManagerServer] ⚠️ Wave already running for island " .. tostring(islandId))
		return
	end
	
	-- Check ownership again
	local ownerId = getIslandOwner(playerIsland)
	if not ownerId or ownerId ~= userId then
		warn("[WaveManagerServer] ❌ Cannot start wave: Island ownership mismatch")
		return
	end
	
	-- Mark wave as active
	activeWavesByIsland[islandId] = true
	waveActiveFlags[islandId] = true
	
	local wave = currentWaveNumbers[islandId] or 1
	currentWaveNumbers[islandId] = wave
	
	print("[WaveManagerServer] 🚀 Starting wave " .. wave .. " on island " .. tostring(islandId) .. " (owner: " .. userId .. ")")
	
	-- Get all NPCs first
	local enemies = getEnemiesForIsland(playerIsland)
	local helpers = getHelpersForIsland(playerIsland)
	
	print("[WaveManagerServer]   - Found " .. #enemies .. " enemies and " .. #helpers .. " helpers")
	
	-- Spawn enemies if none exist
	if #enemies == 0 then
		-- only spawn if not already spawning / already spawned
		if not spawningWaveByIsland[islandId] and spawnedWaveNumberByIsland[islandId] ~= wave then
			print("[WaveManagerServer]   - No enemies found, spawning wave " .. wave)
			spawnEnemiesForWaveOnIsland(playerIsland, userId, wave)
		end

		task.wait(0.5)
		enemies = getEnemiesForIsland(playerIsland)
	end
	
	-- CRITICAL: Unfreeze all NPCs on this island
	print("[WaveManagerServer]   - Unfreezing " .. #enemies .. " enemies...")
	for i, enemy in ipairs(enemies) do
		print("[WaveManagerServer]     - Unfreezing enemy #" .. i .. ": " .. enemy.Name)
		unfreezeNPC(enemy, true)
		-- Double-check after a brief moment
		task.wait(0.1)
		local hum = enemy:FindFirstChildOfClass("Humanoid")
		if hum then
			print("[WaveManagerServer]       ✅ Enemy " .. enemy.Name .. " WalkSpeed: " .. hum.WalkSpeed .. ", JumpPower: " .. hum.JumpPower)
		end
	end
	
	print("[WaveManagerServer]   - Unfreezing " .. #helpers .. " helpers...")
	for i, helper in ipairs(helpers) do
		print("[WaveManagerServer]     - Unfreezing helper #" .. i .. ": " .. helper.Name)
		unfreezeNPC(helper, false)
	end
	
	print("[WaveManagerServer] ✅ All NPCs unfrozen for wave " .. wave)
	
	-- Wave completion loop
	task.spawn(function()
		while waveActiveFlags[islandId] and activeWavesByIsland[islandId] do
			local currentHelpers = getHelpersForIsland(playerIsland)
			local currentEnemies = getEnemiesForIsland(playerIsland)
			
			-- Check win/loss conditions
			if #currentHelpers == 0 then
				print("[WaveManagerServer] 💀 LOST: All helpers dead on island " .. tostring(islandId))
				waveActiveFlags[islandId] = false
				activeWavesByIsland[islandId] = false
				
				-- Freeze remaining enemies
				for _, enemy in ipairs(currentEnemies) do
					freezeNPC(enemy, true)
				end
				return
			end

			if #currentEnemies == 0 then
				print("[WaveManagerServer] 🎉 WON wave " .. wave .. " on island " .. tostring(islandId))
				waveActiveFlags[islandId] = false
				activeWavesByIsland[islandId] = false
				currentWaveNumbers[islandId] = wave + 1
				
				-- ✅ Reset helpers (revive + full heal + reset + freeze)
				reviveAndHealHelpers(playerIsland)
				
				-- ✅ ENEMY BODIES DISAPPEAR: wipe all enemies (alive + dead)
				destroyEnemiesForIsland(playerIsland)
				
				-- ✅ Reset occupancy so next wave can spawn
				clearEnemyOccupancy(islandId)
				
				-- ✅ Spawn next wave IMMEDIATELY (frozen)
				local nextWave = wave + 1
				spawnEnemiesForWaveOnIsland(playerIsland, userId, nextWave)
				
				return
			end

			task.wait(0.4)
		end
	end)
end

-- ===== REMOTE EVENT SETUP =====
local startWaveEvent = ReplicatedStorage:FindFirstChild("StartWaveEvent")
if not startWaveEvent then
	startWaveEvent = Instance.new("RemoteEvent")
	startWaveEvent.Name = "StartWaveEvent"
	startWaveEvent.Parent = ReplicatedStorage
end

-- CRITICAL: Prevent duplicate connections
local connectionEstablished = false
if not connectionEstablished then
startWaveEvent.OnServerEvent:Connect(function(player)
		print("[WaveManagerServer] 🎯 StartWaveEvent from " .. player.Name)
	startWaveForPlayer(player)
end)
	connectionEstablished = true
	print("[WaveManagerServer] ✅ StartWaveEvent handler connected (singleton)")
end

-- ===== COMBAT FUNCTIONS =====
local lastAttackTime = {} -- [Model] = time

local function getRoot(model)
	return model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
end

local function distance(a, b)
	if not a or not b then return math.huge end
	return (a.Position - b.Position).Magnitude
end

local function findNearestTarget(attacker, targets, maxRange)
	local attackerRoot = getRoot(attacker)
	if not attackerRoot then return nil end
	
	local nearest = nil
	local nearestDist = maxRange or math.huge
	
	for _, target in ipairs(targets) do
		local targetHum = target:FindFirstChildOfClass("Humanoid")
		local targetRoot = getRoot(target)
		
		if targetHum and targetHum.Health > 0 and targetRoot then
			local dist = distance(attackerRoot, targetRoot)
			if dist < nearestDist then
				nearestDist = dist
				nearest = target
			end
		end
	end
	
	return nearest, nearestDist
end

local function faceTarget(attackerRoot, targetRoot)
	if not attackerRoot or not targetRoot then return end
	local dir = (targetRoot.Position - attackerRoot.Position)
	dir = Vector3.new(dir.X, 0, dir.Z) -- Keep horizontal
	if dir.Magnitude > 0.01 then
		attackerRoot.CFrame = CFrame.lookAt(attackerRoot.Position, attackerRoot.Position + dir)
	end
end

local function canAttack(attacker, cooldown)
	local now = os.clock()
	local last = lastAttackTime[attacker] or 0
	if (now - last) >= cooldown then
		lastAttackTime[attacker] = now
	return true
	end
	return false
end

local function dealDamage(attacker, target, damage)
	local targetHum = target:FindFirstChildOfClass("Humanoid")
	if targetHum and targetHum.Health > 0 then
		targetHum:TakeDamage(damage)
		dprint("[WaveManagerServer] ⚔️ " .. attacker.Name .. " attacked " .. target.Name .. " for " .. damage .. " damage")
	end
end

-- ===== COMBAT LOOP =====
RunService.Heartbeat:Connect(function()
	-- Helpers attack enemies (only if wave is active)
	for _, helper in ipairs(helpersFolder:GetChildren()) do
		if helper:IsA("Model") then
			local hum = helper:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 then
				-- Get helper's grid to find island
	local gridId = helper:GetAttribute("GridId")
				if gridId then
					local island = getIslandFromGridId(gridId)
					if island then
						local islandId = getIslandIdStrict(island)
						if not islandId then
							-- Skip if island has no valid IslandId
						elseif waveActiveFlags[islandId] and helper:GetAttribute("Aggressive") == true then
							-- Wave is active - helpers can attack
							local enemies = getEnemiesForIsland(island)
							if #enemies > 0 then
								local range = helper:GetAttribute("AttackRange") or DEFAULT_HELPER_RANGE or 14
								local cooldown = helper:GetAttribute("AttackCooldown") or DEFAULT_HELPER_COOLDOWN or 1.1
								local damage = helper:GetAttribute("AttackDamage") or DEFAULT_HELPER_DAMAGE or 12
								
								local target, dist = findNearestTarget(helper, enemies, range)
								if target and canAttack(helper, cooldown) then
									local helperRoot = getRoot(helper)
									local targetRoot = getRoot(target)
									if helperRoot and targetRoot then
										faceTarget(helperRoot, targetRoot)
										dealDamage(helper, target, damage)
									end
								elseif target and dist > range then
									-- Move towards target
									local helperRoot = getRoot(helper)
									local targetRoot = getRoot(target)
									if helperRoot and targetRoot then
										hum:MoveTo(targetRoot.Position)
				end
			end
							end
						else
							-- Ensure helper stays frozen if wave not active
							if hum.WalkSpeed > 0 then
								freezeNPC(helper, false)
							end
						end
					end
				end
			end
		end
	end
	
	-- Enemies attack helpers (only if wave is active)
	for _, enemy in ipairs(enemiesFolder:GetChildren()) do
		if enemy:IsA("Model") then
			local hum = enemy:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 then
				-- Use cached island lookup (performance optimization)
				local islandId = enemy:GetAttribute("IslandId")
				local island = nil
				
				-- Method 1: Use IslandId attribute with cache
				if typeof(islandId) == "number" then
					island = islandById[islandId]
				end
				
				-- Method 2: Find island from GridId (fallback)
				if not island then
					local gridId = enemy:GetAttribute("GridId")
					if gridId then
						island = getIslandFromGridId(gridId)
						-- If found via GridId, sync IslandId
						if island then
							local correctId = getIslandIdStrict(island)
							if correctId then
								enemy:SetAttribute("IslandId", correctId)
								islandId = correctId
							end
						end
					end
				end
				
				-- Skip enemies that have no IslandId and no GridId (orphaned enemies not part of wave system)
				if not island or not islandId then
					-- Only warn once per enemy (store in attribute)
					if not enemy:GetAttribute("OrphanWarningShown") then
						warn("[WaveManagerServer] ⚠️ Enemy " .. enemy.Name .. " has no IslandId or GridId - skipping (orphaned enemy)")
						enemy:SetAttribute("OrphanWarningShown", true)
					end
					-- Skip this enemy - it's not part of the wave system
				else
					-- Enemy has valid island - process combat
					if typeof(islandId) ~= "number" then
						-- Skip if islandId is not numeric
					elseif waveActiveFlags[islandId] and enemy:GetAttribute("Aggressive") == true then
						-- Wave is active - enemies can attack
						-- Get helpers for this island
						local helpers = getHelpersForIsland(island)
						
						-- Helpers are now tracked efficiently, no fallback needed
						
						if #helpers > 0 then
							local range = enemy:GetAttribute("AttackRange") or DEFAULT_ENEMY_RANGE or 7
							local cooldown = enemy:GetAttribute("AttackCooldown") or DEFAULT_ENEMY_COOLDOWN or 1.3
							local baseDamage = enemy:GetAttribute("AttackDamage") or DEFAULT_ENEMY_DAMAGE or 8
							local damageMult = enemy:GetAttribute("DamageMult")
							if typeof(damageMult) ~= "number" then damageMult = 1 end
							local damage = baseDamage * damageMult
							
							local target, dist = findNearestTarget(enemy, helpers, math.huge) -- Find any target, not just in range
							
							if target then
								local enemyRoot = getRoot(enemy)
								local targetRoot = getRoot(target)
								
								if enemyRoot and targetRoot then
									-- Always face target
									faceTarget(enemyRoot, targetRoot)
									
									-- If in range, attack
									if dist <= range and canAttack(enemy, cooldown) then
										dealDamage(enemy, target, damage)
									else
										-- Always move towards target if not in range
										if dist > range then
											hum:MoveTo(targetRoot.Position)
										end
									end
								end
							end
						end
					else
						-- Ensure enemy stays frozen if wave not active
						if hum.WalkSpeed > 0 then
							freezeNPC(enemy, true)
						end
					end
				end
			end
		end
	end
end)

-- ===== CLEANUP ON PLAYER LEAVE =====
Players.PlayerRemoving:Connect(function(player)
	local userId = player.UserId
	
	-- Find player's island and clear ownership
	for _, island in ipairs(getAllIslands()) do
		if getIslandOwner(island) == userId then
			local islandId = getIslandIdStrict(island)
			if islandId then
				-- Stop wave loop
				activeWavesByIsland[islandId] = false
				waveActiveFlags[islandId] = false
				
				-- Clear ownership
				island:SetAttribute("OwnerUserId", nil)
				
				-- Cleanup NPCs (optional - you may want to keep them)
				-- for _, enemy in ipairs(getEnemiesForIsland(island)) do
				-- 	enemy:Destroy()
				-- end
				
				print("[WaveManagerServer] 🧹 Cleaned up island " .. tostring(islandId) .. " for player " .. player.Name)
				break
			end
		end
	end
end)

-- ===== INITIAL ENEMY SPAWNING (BEFORE HELPERS ARE PLACED) =====
-- DISABLED: Don't spawn enemies on unowned islands
-- Enemies will spawn when first helper is placed on an island
local function spawnInitialEnemiesForAllIslands()
	print("[WaveManagerServer] 🎯 Initial enemy spawning DISABLED - enemies will spawn when helpers are placed")
	-- This prevents spawning on unowned islands
	return
end

-- Spawn initial enemies when script starts
task.spawn(function()
	spawnInitialEnemiesForAllIslands()
end)

-- Initialize tracked sets for existing helpers/enemies
task.spawn(function()
	task.wait(0.5) -- Wait for attributes to be set
	
	-- Track existing helpers
	for _, helper in ipairs(helpersFolder:GetChildren()) do
		if helper:IsA("Model") then
			local gridId = helper:GetAttribute("GridId")
			if gridId then
				local island = getIslandFromGridId(gridId)
				if island then
					local islandId = getIslandIdStrict(island)
					if islandId then
						addToSet(helpersByIsland, islandId, helper)
					end
				end
			end
		end
	end
	
	-- Track existing enemies
	for _, enemy in ipairs(enemiesFolder:GetChildren()) do
		if enemy:IsA("Model") then
			local islandId = enemy:GetAttribute("IslandId")
			if typeof(islandId) == "number" then
				addToSet(enemiesByIsland, islandId, enemy)
			end
		end
	end
end)

-- Monitor helpers folder - when first helper is placed on an island, assign enemies to that player
helpersFolder.ChildAdded:Connect(function(helper)
	task.wait(0.05)
	
	if not helper:IsA("Model") then
		return
	end
	
	-- store helper original placement position once
	if not helper:GetAttribute("OriginalCFrame") then
		storeNPCPosition(helper)
	end

	-- ensure helpers start neutral/frozen
	freezeNPC(helper, false)
	
	-- Cleanup on death - explode then destroy after 1 second
	local hum = helper:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.Died:Connect(function()
			-- Clean up stored position
			npcOriginalCFrames[helper] = nil
			-- Explode and destroy after 1 second
			task.spawn(function()
				explodeAndDestroy(helper, 1)
			end)
		end)
	end
	
	local ownerId = helper:GetAttribute("OwnerUserId")
	local gridId = helper:GetAttribute("GridId")
	
	if not ownerId or not gridId then
		return
	end
	
	-- Find island from helper's GridId
	local island = getIslandFromGridId(gridId)
	if not island then
		return
	end
	
	local islandId = getIslandIdStrict(island)
	if not islandId then
		warn("[WaveManagerServer] ⚠️ Helper placed on island without numeric IslandId - skipping")
		return
	end
	
	-- Track helper in per-island set (OPTIMIZATION)
	addToSet(helpersByIsland, islandId, helper)
	
	-- Track removal when helper is removed from workspace
	helper.AncestryChanged:Connect(function(_, parent)
		if not parent then
			removeFromSet(helpersByIsland, islandId, helper)
		end
	end)
	
	-- Check if enemies already exist and are unassigned
	local existingEnemies = getEnemiesForIsland(island)
	if #existingEnemies > 0 then
		-- Assign existing enemies to this player
		print("[WaveManagerServer] 🎯 Assigning " .. #existingEnemies .. " existing enemies to player " .. ownerId)
		for _, enemy in ipairs(existingEnemies) do
			local currentTarget = enemy:GetAttribute("TargetUserId")
			if currentTarget == 0 or enemy:GetAttribute("Unassigned") then
				enemy:SetAttribute("TargetUserId", ownerId)
				enemy:SetAttribute("Unassigned", nil)
				print("[WaveManagerServer] ✅ Assigned enemy " .. enemy.Name .. " to player " .. ownerId)
			end
		end
		
		-- Set island ownership
		island:SetAttribute("OwnerUserId", ownerId)
		return
	end
	
	-- No enemies exist yet - spawn them now for this player
	local wave = currentWaveNumbers[islandId] or 1
	print("[WaveManagerServer] 🎯 First helper placed on island " .. tostring(islandId) .. " - spawning enemies for wave " .. wave .. " (owner: " .. ownerId .. ")")
	
		task.spawn(function()
			spawnEnemiesForWaveOnIsland(island, ownerId, wave)
			-- Set island ownership
			island:SetAttribute("OwnerUserId", ownerId)
		end)
	end)

-- Handle helper removal (cleanup tracked sets)
helpersFolder.ChildRemoved:Connect(function(helper)
	if not helper:IsA("Model") then return end
	
	-- Remove from all island sets (helper might be removed before we know its islandId)
	for islandId, set in pairs(helpersByIsland) do
		if set[helper] then 
			set[helper] = nil
			break
		end
	end
end)

print("[WaveManagerServer] ✅ REFACTORED SYSTEM INITIALIZED")
print("[WaveManagerServer] ========================================")
