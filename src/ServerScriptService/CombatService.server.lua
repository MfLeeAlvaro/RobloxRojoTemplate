--========================================================
-- CombatService (SERVER)
-- Simple PvE auto-combat:
-- Helpers attack nearest enemy in range (within grid bounds only)
-- Enemies attack nearest helper in range
-- Uses Humanoid:TakeDamage()
-- Helpers can only move within their assigned 10x10 grid
--========================================================

local RunService = game:GetService("RunService")

-- Folders
local helpersFolder = workspace:FindFirstChild("Helpers") or Instance.new("Folder")
helpersFolder.Name = "Helpers"
helpersFolder.Parent = workspace

local enemiesFolder = workspace:FindFirstChild("Enemies") or Instance.new("Folder")
enemiesFolder.Name = "Enemies"
enemiesFolder.Parent = workspace

--========================
-- CONFIG (tune these)
--========================
local TICK_RATE = 0.25 -- seconds
local DEFAULT_RANGE = 12
local DEFAULT_DAMAGE = 10
local DEFAULT_ATTACK_SPEED = 1.0 -- attacks per second

local ENEMY_RANGE = 10
local ENEMY_DAMAGE = 8
local ENEMY_ATTACK_SPEED = 1.0

-- Per-model attack cooldown tracking
local nextAttackTime = {} -- [Model] = time

--========================
-- Helpers
--========================
local function getHumanoidAndRoot(model: Model)
	if not model or not model:IsA("Model") then return nil, nil end
	local hum = model:FindFirstChildOfClass("Humanoid")
	if not hum then return nil, nil end

	local root =
		model:FindFirstChild("HumanoidRootPart")
		or model.PrimaryPart
		or model:FindFirstChildWhichIsA("BasePart")

	return hum, root
end

local function isAliveHum(h: Humanoid)
	return h and h.Health > 0 and h.Parent ~= nil
end

local function getModels(folder: Instance)
	local t = {}
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("Model") then
			table.insert(t, child)
		end
	end
	return t
end

local function distance(a: BasePart, b: BasePart)
	return (a.Position - b.Position).Magnitude
end

-- Find the grid that a helper or enemy belongs to
local function getHelperGrid(helper: Model)
	-- Try to get grid from attribute (set when placed)
	local gridId = helper:GetAttribute("GridId")
	if gridId then
		-- Find grid by full name
		local function findGridByName(name)
			local function searchDescendants(parent)
				for _, descendant in ipairs(parent:GetDescendants()) do
					if descendant:IsA("BasePart") and descendant.Name == "Gridfloor" then
						if descendant:GetFullName() == name then
							return descendant
						end
					end
				end
				return nil
			end
			return searchDescendants(workspace)
		end
		return findGridByName(gridId)
	end
	
	-- Fallback: Find closest grid to helper position
	local helperRoot = helper:FindFirstChild("HumanoidRootPart") or helper.PrimaryPart
	if not helperRoot then return nil end
	
	local function getAllGridFloors()
		local gridFloors = {}
		local function searchDescendants(parent)
			for _, descendant in ipairs(parent:GetDescendants()) do
				if descendant:IsA("BasePart") and descendant.Name == "Gridfloor" then
					table.insert(gridFloors, descendant)
				end
			end
		end
		searchDescendants(workspace)
		return gridFloors
	end
	
	local allGrids = getAllGridFloors()
	local closestGrid = nil
	local closestDist = math.huge
	
	for _, grid in ipairs(allGrids) do
		local dist = (grid.Position - helperRoot.Position).Magnitude
		if dist < closestDist then
			closestDist = dist
			closestGrid = grid
		end
	end
	
	return closestGrid
end

-- Check if a position is within grid bounds
local function isPositionInGrid(position: Vector3, grid: BasePart)
	if not grid then return false end
	
	local localPos = grid.CFrame:PointToObjectSpace(position)
	local halfX = grid.Size.X / 2
	local halfZ = grid.Size.Z / 2
	
	return math.abs(localPos.X) <= halfX and math.abs(localPos.Z) <= halfZ
end

-- Constrain a position to grid bounds
local function constrainToGrid(position: Vector3, grid: BasePart): Vector3
	if not grid then return position end
	
	local localPos = grid.CFrame:PointToObjectSpace(position)
	local halfX = grid.Size.X / 2
	local halfZ = grid.Size.Z / 2
	
	-- Clamp to grid bounds
	local clampedX = math.clamp(localPos.X, -halfX, halfX)
	local clampedZ = math.clamp(localPos.Z, -halfZ, halfZ)
	
	local clampedLocal = Vector3.new(clampedX, localPos.Y, clampedZ)
	return grid.CFrame:PointToWorldSpace(clampedLocal)
end

local function findNearestTarget(attackerRoot: BasePart, targets: {Model}, grid: BasePart?)
	local best, bestDist = nil, math.huge
	for _, m in ipairs(targets) do
		local hum, root = getHumanoidAndRoot(m)
		if isAliveHum(hum) and root then
			-- If grid is provided, only consider targets within grid bounds
			if grid and not isPositionInGrid(root.Position, grid) then
				continue
			end
			
			local d = distance(attackerRoot, root)
			if d < bestDist then
				bestDist = d
				best = m
			end
		end
	end
	return best, bestDist
end

local function faceTarget(attackerRoot: BasePart, targetRoot: BasePart)
	local a = attackerRoot.Position
	local b = targetRoot.Position
	local dir = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	if dir.Magnitude > 0.01 then
		attackerRoot.CFrame = CFrame.lookAt(a, a + dir)
	end
end

local function doAttack(attacker: Model, target: Model, damage: number, attackSpeed: number, range: number, grid: BasePart?)
	local now = os.clock()
	nextAttackTime[attacker] = nextAttackTime[attacker] or 0
	if now < nextAttackTime[attacker] then return end

	local targetHum, targetRoot = getHumanoidAndRoot(target)
	local attackerHum, attackerRoot = getHumanoidAndRoot(attacker)
	if not (isAliveHum(attackerHum) and attackerRoot and isAliveHum(targetHum) and targetRoot) then
		return
	end

	local d = distance(attackerRoot, targetRoot)
	if d > range then
		-- Move closer, but constrain to grid bounds if helper
		local moveTarget = targetRoot.Position
		if grid then
			moveTarget = constrainToGrid(moveTarget, grid)
		end
		attackerHum:MoveTo(moveTarget)
		return
	end

	-- Attack
	faceTarget(attackerRoot, targetRoot)
	targetHum:TakeDamage(damage)

	-- Cooldown
	local cooldown = 1 / math.max(attackSpeed, 0.1)
	nextAttackTime[attacker] = now + cooldown
end

--========================
-- MAIN LOOP
--========================
local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < TICK_RATE then return end
	acc = 0

	local helpers = getModels(helpersFolder)
	local enemies = getModels(enemiesFolder)

	-- Helpers attack enemies (only within their grid)
	for _, helper in ipairs(helpers) do
		local hum, root = getHumanoidAndRoot(helper)
		if isAliveHum(hum) and root then
			-- Get the grid this helper belongs to
			local grid = getHelperGrid(helper)
			
			-- Only find targets within the grid bounds
			local target, dist = findNearestTarget(root, enemies, grid)
			if target and dist then
				-- You can override helper stats by Attributes:
				-- Range, Damage, AttackSpeed
				local range = helper:GetAttribute("Range") or DEFAULT_RANGE
				local dmg = helper:GetAttribute("Damage") or DEFAULT_DAMAGE
				local aspd = helper:GetAttribute("AttackSpeed") or DEFAULT_ATTACK_SPEED
				doAttack(helper, target, dmg, aspd, range, grid)
			end
			
			-- Constrain helper position to grid bounds
			if grid then
				local currentPos = root.Position
				if not isPositionInGrid(currentPos, grid) then
					local constrainedPos = constrainToGrid(currentPos, grid)
					root.CFrame = CFrame.new(constrainedPos, root.CFrame.LookVector)
				end
			end
		end
	end

	-- Enemies attack helpers (only within their grid AND only if wave is active)
	for _, enemy in ipairs(enemies) do
		local hum, root = getHumanoidAndRoot(enemy)
		if isAliveHum(hum) and root then
			-- Get the grid this enemy belongs to
			local grid = getHelperGrid(enemy) -- Reuse same function
			
			-- Check if wave is active for this grid
			if grid then
				local gridId = grid:GetFullName()
				-- Check if wave is active (we need to access WaveManagerServer's waveActiveFlags)
				-- For now, we'll check if enemy has a WaveActive attribute set by spawn
				local waveActive = enemy:GetAttribute("WaveActive")
				if not waveActive then
					continue -- Wave not active, enemies don't attack
				end
			end
			
			-- Only find targets within the grid bounds
			local target, dist = findNearestTarget(root, helpers, grid)
			if target and dist then
				local range = enemy:GetAttribute("Range") or ENEMY_RANGE
				local dmg = enemy:GetAttribute("Damage") or ENEMY_DAMAGE
				local aspd = enemy:GetAttribute("AttackSpeed") or ENEMY_ATTACK_SPEED
				doAttack(enemy, target, dmg, aspd, range, grid)
			end
			
			-- Constrain enemy position to grid bounds
			if grid then
				local currentPos = root.Position
				if not isPositionInGrid(currentPos, grid) then
					local constrainedPos = constrainToGrid(currentPos, grid)
					root.CFrame = CFrame.new(constrainedPos, root.CFrame.LookVector)
				end
			end
		end
	end
end)

print("✅ CombatService running (Helpers <-> Enemies)")
