local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

-- ===== CONFIG =====
local GRID_SIZE = 5
local GRID_COLS = 10
local GRID_ROWS = 10

local PLAYER_MIN_ROW, PLAYER_MAX_ROW = 1, 5
local ENEMY_MIN_ROW, ENEMY_MAX_ROW = 6, 10

-- NOTE (optional improvement):
-- If you ever switch to left/right halves like your placement fix:
-- you'd replace row ranges with col ranges. Keeping as-is for now.

local PREP_TIME = 10
local SPAWN_INTERVAL = 0.6
local BASE_ENEMIES = 6
local ENEMIES_PER_WAVE = 2

local MINI_BOSS_EVERY = 5
local BOSS_EVERY = 15

-- Combat tuning defaults (if you don’t set attributes on models)
local DEFAULT_HELPER_DAMAGE = 12
local DEFAULT_HELPER_RANGE = 14
local DEFAULT_HELPER_COOLDOWN = 1.1

local DEFAULT_ENEMY_DAMAGE = 8
local DEFAULT_ENEMY_RANGE = 7
local DEFAULT_ENEMY_COOLDOWN = 1.3

-- ===== PATHS =====
local GRID_FLOOR = workspace:WaitForChild("Island")
	:WaitForChild("Arena")
	:WaitForChild("Platform")
	:WaitForChild("BattlePlatform")
	:WaitForChild("Gridfloor")

local ENEMY_TEMPLATES = ServerStorage:WaitForChild("EnemyTemplates") -- you must create this folder
-- Must contain: EnemyGrunt, MiniBoss, Boss (you can add more later)

-- Folders
local helpersFolder = workspace:FindFirstChild("Helpers") or Instance.new("Folder")
helpersFolder.Name = "Helpers"
helpersFolder.Parent = workspace

local enemiesFolder = workspace:FindFirstChild("Enemies") or Instance.new("Folder")
enemiesFolder.Name = "Enemies"
enemiesFolder.Parent = workspace

--========================================================
-- ✅ KEEP: Creating/ensuring Helpers/Enemies folders is fine.
-- BUT NOTE:
-- Your FIXED placement script also ensures Helpers exists.
-- This is still safe because FindFirstChild("Helpers") returns the same one.
--========================================================


-- ===== GRID HELPERS =====
local function worldToCell(worldPos)
	local localPos = GRID_FLOOR.CFrame:PointToObjectSpace(worldPos)

	local halfX = GRID_FLOOR.Size.X / 2
	local halfZ = GRID_FLOOR.Size.Z / 2

	if localPos.X < -halfX or localPos.X > halfX or localPos.Z < -halfZ or localPos.Z > halfZ then
		return nil
	end

	local x01 = localPos.X + halfX
	local z01 = localPos.Z + halfZ

	local col = math.floor(x01 / GRID_SIZE) + 1
	local row = math.floor(z01 / GRID_SIZE) + 1

	if row < 1 or row > GRID_ROWS or col < 1 or col > GRID_COLS then
		return nil
	end

	return row, col
end

--========================================================
-- ✅ KEEP: worldToCell is fine.
-- If you ever want enemies to spawn facing like helpers, you'd also add
-- cellToWorldCFrame like your FIXED placement code.
--========================================================

local function cellToWorldPosition(row, col, yOffset)
	local halfX = GRID_FLOOR.Size.X / 2
	local halfZ = GRID_FLOOR.Size.Z / 2

	local centerX = (-halfX) + (col - 0.5) * GRID_SIZE
	local centerZ = (-halfZ) + (row - 0.5) * GRID_SIZE

	local worldCenter = GRID_FLOOR.CFrame:PointToWorldSpace(Vector3.new(centerX, 0, centerZ))
	local topY = GRID_FLOOR.Position.Y + (GRID_FLOOR.Size.Y / 2)

	return Vector3.new(worldCenter.X, topY + (yOffset or 3), worldCenter.Z)
end

--========================================================
-- 🔁 CHANGE (optional but recommended):
-- Your FIXED placement uses PivotTo(CFrame) with facing direction.
-- This old function returns only Position, so enemies will spawn with
-- template rotation, not aligned to the board.
--
-- OLD (kept) spawns using: enemy:PivotTo(CFrame.new(pos))
-- NEW (recommended) would be:
--   local faceDir = GRID_FLOOR.CFrame.LookVector (or -LookVector)
--   enemy:PivotTo(CFrame.lookAt(pos, pos + faceDir))
--========================================================


-- ===== UNIT QUERIES =====
local function isAliveModel(model)
	if not model or not model.Parent then return false end
	local hum = model:FindFirstChildOfClass("Humanoid")
	return hum and hum.Health > 0
end

local function getHelpersForPlayer(userId)
	local list = {}
	for _, m in ipairs(helpersFolder:GetChildren()) do
		if m:IsA("Model") and m:GetAttribute("OwnerUserId") == userId and isAliveModel(m) then
			table.insert(list, m)
		end
	end
	return list
end

local function getEnemiesForPlayer(userId)
	local list = {}
	for _, m in ipairs(enemiesFolder:GetChildren()) do
		if m:IsA("Model") and m:GetAttribute("TargetUserId") == userId and isAliveModel(m) then
			table.insert(list, m)
		end
	end
	return list
end

--========================================================
-- ✅ KEEP: This matches your FIXED placement system perfectly
-- because your placed units set OwnerUserId.
--========================================================


-- ===== COMBAT CORE =====
local function getRoot(model)
	return model:FindFirstChild("HumanoidRootPart")
		or model.PrimaryPart
		or model:FindFirstChildWhichIsA("BasePart", true)
end

local function getStat(model, statName, defaultValue)
	local v = model:GetAttribute(statName)
	if typeof(v) == "number" then return v end
	return defaultValue
end

local function findNearestInRange(attacker, targets, range)
	local aRoot = getRoot(attacker)
	if not aRoot then return nil end

	local best, bestDist = nil, range
	for _, t in ipairs(targets) do
		local tRoot = getRoot(t)
		if tRoot then
			local dist = (tRoot.Position - aRoot.Position).Magnitude
			if dist <= bestDist then
				bestDist = dist
				best = t
			end
		end
	end
	return best
end

local function dealDamage(attacker, target, amount)
	local hum = target:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 then
		hum:TakeDamage(amount)
	end
end

-- Track cooldowns
local lastAttack = setmetatable({}, { __mode = "k" }) -- weak keys

local function canAttack(model, cooldown)
	local t = os.clock()
	local last = lastAttack[model] or 0
	if (t - last) >= cooldown then
		lastAttack[model] = t
		return true
	end
	return false
end

--========================================================
-- ✅ KEEP: Combat loop is independent of placement.
--========================================================


-- ===== ENEMY SPAWNING ON RANDOM ENEMY CELLS =====
local enemyOccupied = {} -- enemyOccupied[userId][row][col] = true

local function ensureEnemyOcc(userId)
	enemyOccupied[userId] = enemyOccupied[userId] or {}
	for r = 1, GRID_ROWS do
		enemyOccupied[userId][r] = enemyOccupied[userId][r] or {}
	end
end

local function pickRandomEnemyCell(userId)
	ensureEnemyOcc(userId)

	-- try a bunch of times to find a free cell
	for _ = 1, 60 do
		local row = math.random(ENEMY_MIN_ROW, ENEMY_MAX_ROW)
		local col = math.random(1, GRID_COLS)

		if not enemyOccupied[userId][row][col] then
			return row, col
		end
	end

	return nil
end

local function spawnEnemy(userId, templateName, wave, isMiniBoss, isBoss)
	local template = ENEMY_TEMPLATES:FindFirstChild(templateName)
	if not template or not template:IsA("Model") then
		warn("Missing enemy template:", templateName)
		return nil
	end

	local row, col = pickRandomEnemyCell(userId)
	if not row then
		warn("Could not find free enemy cell to spawn.")
		return nil
	end

	local enemy = template:Clone()
	enemy.Parent = enemiesFolder
	enemy:SetAttribute("TargetUserId", userId)
	enemy:SetAttribute("Wave", wave)
	enemy:SetAttribute("IsMiniBoss", isMiniBoss)
	enemy:SetAttribute("IsBoss", isBoss)

	-- Basic scaling
	local hum = enemy:FindFirstChildOfClass("Humanoid")
	if hum then
		local baseMax = hum.MaxHealth
		local healthMult = (1.12 ^ (wave - 1))
		local damageMult = (1.08 ^ (wave - 1))

		if isMiniBoss then
			healthMult *= 2.5
			damageMult *= 1.6
		end
		if isBoss then
			healthMult *= 6.0
			damageMult *= 2.2
		end

		hum.MaxHealth = math.floor(baseMax * healthMult)
		hum.Health = hum.MaxHealth
		enemy:SetAttribute("DamageMult", damageMult)
	end

	--========================================================
	-- ✅ FIX-STYLE CHANGE (Recommended):
	-- Make enemy PrimaryPart stable BEFORE PivotTo (same reason as helpers).
	-- Your current code does this, good.
	--========================================================
	local root = getRoot(enemy)
	if root and root:IsA("BasePart") then
		enemy.PrimaryPart = root
	end

	local pos = cellToWorldPosition(row, col, 3)

	--========================================================
	-- 🔁 CHANGE (to match your FIXED helper orientation):
	-- OLD:
	--enemy:PivotTo(CFrame.new(pos))
	-- WHY OLD IS "WEAKER":
	-- CFrame.new(pos) preserves the TEMPLATE rotation.
	-- If your enemy template faces some random direction, it will spawn sideways.
	--
	-- NEW (commented, recommended):
	--local faceDir = -GRID_FLOOR.CFrame.LookVector
	--enemy:PivotTo(CFrame.lookAt(pos, pos + faceDir))
	--Them goons facing the wrong waay so i flip it with thiss line
	local faceDir = GRID_FLOOR.CFrame.LookVector
	enemy:PivotTo(CFrame.lookAt(pos, pos + faceDir))
	--========================================================

	-- Mark cell occupied until this enemy dies
	enemyOccupied[userId][row][col] = true

	if hum then
		hum.Died:Connect(function()
			enemyOccupied[userId][row][col] = nil
			task.defer(function()
				if enemy and enemy.Parent then enemy:Destroy() end
			end)
		end)
	end

	return enemy
end


-- ===== WAVE LOOP PER PLAYER =====
local function getWavePlan(wave)
	local isBoss = (wave % BOSS_EVERY == 0)
	local isMiniBoss = (not isBoss) and (wave % MINI_BOSS_EVERY == 0)

	local adds = BASE_ENEMIES + (wave - 1) * ENEMIES_PER_WAVE
	if isMiniBoss then adds = math.floor(adds * 0.8) end
	if isBoss then adds = math.floor(adds * 0.6) end

	return {
		wave = wave,
		isMiniBoss = isMiniBoss,
		isBoss = isBoss,
		addCount = math.max(1, adds),
	}
end

local function runWavesForPlayer(player)
	local userId = player.UserId
	local wave = 0

	while player.Parent do
		wave += 1
		local plan = getWavePlan(wave)

		-- Prep phase
		print(("[PVE] %s - Wave %d prep (%ds)"):format(player.Name, wave, PREP_TIME))
		task.wait(PREP_TIME)

		-- If player has no helpers, they effectively lose the wave immediately
		if #getHelpersForPlayer(userId) == 0 then
			warn(("[PVE] %s has no helpers placed. Lose."):format(player.Name))
			break
		end

		print(("[PVE] %s - Wave %d start. Adds=%d MiniBoss=%s Boss=%s"):format(
			player.Name, wave, plan.addCount, tostring(plan.isMiniBoss), tostring(plan.isBoss)
			))

		-- Spawn order: boss/mini-boss first (if applicable) + adds
		if plan.isBoss then
			spawnEnemy(userId, "Boss", wave, false, true)
			task.wait(SPAWN_INTERVAL)
		elseif plan.isMiniBoss then
			spawnEnemy(userId, "MiniBoss", wave, true, false)
			task.wait(SPAWN_INTERVAL)
		end

		for i = 1, plan.addCount do
			spawnEnemy(userId, "EnemyGrunt", wave, false, false)
			task.wait(SPAWN_INTERVAL)
		end

		-- Combat resolution loop:
		-- Win when enemies are 0, lose when helpers are 0
		while player.Parent do
			local helpers = getHelpersForPlayer(userId)
			local enemies = getEnemiesForPlayer(userId)

			if #helpers == 0 then
				warn(("[PVE] %s - LOST on wave %d (all helpers dead)."):format(player.Name, wave))
				return
			end

			if #enemies == 0 then
				print(("[PVE] %s - WON wave %d."):format(player.Name, wave))
				break
			end

			task.wait(0.4)
		end
	end
end


-- ===== GLOBAL COMBAT TICK (server) =====
RunService.Heartbeat:Connect(function()
	-- Helpers attack
	for _, helper in ipairs(helpersFolder:GetChildren()) do
		if helper:IsA("Model") and isAliveModel(helper) then
			local ownerId = helper:GetAttribute("OwnerUserId")
			if typeof(ownerId) == "number" then
				local enemies = getEnemiesForPlayer(ownerId)
				if #enemies > 0 then
					local range = getStat(helper, "AttackRange", DEFAULT_HELPER_RANGE)
					local cooldown = getStat(helper, "AttackCooldown", DEFAULT_HELPER_COOLDOWN)
					local damage = getStat(helper, "AttackDamage", DEFAULT_HELPER_DAMAGE)

					local target = findNearestInRange(helper, enemies, range)
					if target and canAttack(helper, cooldown) then
						dealDamage(helper, target, damage)
					end
				end
			end
		end
	end

	-- Enemies attack
	for _, enemy in ipairs(enemiesFolder:GetChildren()) do
		if enemy:IsA("Model") and isAliveModel(enemy) then
			local targetId = enemy:GetAttribute("TargetUserId")
			if typeof(targetId) == "number" then
				local helpers = getHelpersForPlayer(targetId)
				if #helpers > 0 then
					local range = getStat(enemy, "AttackRange", DEFAULT_ENEMY_RANGE)
					local cooldown = getStat(enemy, "AttackCooldown", DEFAULT_ENEMY_COOLDOWN)

					local baseDamage = getStat(enemy, "AttackDamage", DEFAULT_ENEMY_DAMAGE)
					local damageMult = enemy:GetAttribute("DamageMult")
					if typeof(damageMult) ~= "number" then damageMult = 1 end

					local target = findNearestInRange(enemy, helpers, range)
					if target and canAttack(enemy, cooldown) then
						dealDamage(enemy, target, baseDamage * damageMult)
					end
				end
			end
		end
	end
end)

-- Start per-player waves
Players.PlayerAdded:Connect(function(player)
	task.spawn(function()
		task.wait(2) -- let character load
		runWavesForPlayer(player)
	end)
end)

--========================================================
-- OPTIONAL (recommended):
-- If players can respawn/rejoin and you want waves to restart cleanly,
-- you may want to clear enemyOccupied[userId] when player leaves.
--========================================================
--[[
Players.PlayerRemoving:Connect(function(player)
	enemyOccupied[player.UserId] = nil
end)
]]
