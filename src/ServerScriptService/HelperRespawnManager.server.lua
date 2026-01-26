-- ServerScriptService/HelperRespawnManager.server.lua
-- Manages helper respawn system: destroy on death, respawn during active waves, reset at wave end

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

-- ===== DEPENDENCIES (from WaveManagerServer) =====
-- These should be accessible if WaveManagerServer runs first, or we'll get them directly
local helpersFolder = workspace:WaitForChild("Helpers")
local helperTemplates = ServerStorage:WaitForChild("HelperTemplates")

-- Grid constants (must match GridHelperSpawnerServer)
local GRID_SIZE = 5
local GRID_COLS = 10
local GRID_ROWS = 10

-- ===== REGISTRY STRUCTURE =====
-- helperRegistry[islandId][slotKey] = {
--   templateName = "Tweaker",
--   ownerUserId = 123,
--   gridId = "Island.1.Arena.Platform.BattlePlatform.Gridfloor",
--   originalCFrame = CFrame.new(...),
--   placeRow = 3,
--   placeCol = 4,
--   star = 0,
--   rarity = "Common",
--   helperType = "Tweaker",
--   baseDamage = 12,
--   baseHealth = 100,
--   baseRange = 14,
--   baseCooldown = 1.1,
--   starLevel = 0,
--   islandId = 1,
--   ... (any other attributes)
-- }
local helperRegistry = {} -- [islandId][slotKey] = record

-- ===== UTILITY FUNCTIONS =====

-- Get island from GridId string
local function getIslandFromGridId(gridId)
	if not gridId or typeof(gridId) ~= "string" then return nil end
	
	local parts = {}
	for part in gridId:gmatch("[^.]+") do
		table.insert(parts, part)
	end
	
	local current = workspace
	for _, partName in ipairs(parts) do
		current = current:FindFirstChild(partName)
		if not current then return nil end
	end
	
	-- Walk up to find Island model
	while current and current.Parent and current.Parent ~= workspace do
		if current:IsA("Model") then
			local islandId = current:GetAttribute("IslandId")
			if typeof(islandId) == "number" then
				return current
			end
		end
		current = current.Parent
	end
	
	return nil
end

-- Get islandId from island model
local function getIslandIdStrict(island)
	if not island then return nil end
	local id = island:GetAttribute("IslandId")
	if typeof(id) == "number" then
		return id
	end
	return nil
end

-- Get grid part from GridId string
local function getGridFromGridId(gridId)
	if not gridId or typeof(gridId) ~= "string" then return nil end
	
	local parts = {}
	for part in gridId:gmatch("[^.]+") do
		table.insert(parts, part)
	end
	
	local current = workspace
	for _, partName in ipairs(parts) do
		current = current:FindFirstChild(partName)
		if not current then return nil end
	end
	
	if current and current:IsA("BasePart") and current.Name == "Gridfloor" then
		return current
	end
	
	return nil
end

-- Convert world position to (row, col) on a grid
local function worldToCell(worldPos, grid)
	if not grid then return nil, nil end
	
	local localPos = grid.CFrame:PointToObjectSpace(worldPos)
	local halfX = grid.Size.X / 2
	local halfZ = grid.Size.Z / 2
	
	if localPos.X < -halfX or localPos.X > halfX or localPos.Z < -halfZ or localPos.Z > halfZ then
		return nil, nil
	end
	
	local x01 = localPos.X + halfX
	local z01 = localPos.Z + halfZ
	
	local col = math.floor(x01 / GRID_SIZE) + 1
	local row = math.floor(z01 / GRID_SIZE) + 1
	
	if row < 1 or row > GRID_ROWS or col < 1 or col > GRID_COLS then
		return nil, nil
	end
	
	return row, col
end

-- Get template name from helper
local function getHelperTemplateName(helper)
	-- Prefer explicit attribute
	local helperType = helper:GetAttribute("HelperType") 
		or helper:GetAttribute("HelperName")
		or helper:GetAttribute("UnitType")
	
	if helperType and typeof(helperType) == "string" and helperType ~= "" then
		return helperType
	end
	
	-- Fallback: strip suffixes from Name
	local baseName = helper.Name:match("^[^_]+")
	if baseName then
		return baseName
	end
	
	return helper.Name
end

-- Get slot key from helper (row:col format)
local function getSlotKeyFromHelper(helper)
	local row = helper:GetAttribute("PlaceRow") or helper:GetAttribute("SpawnRow")
	local col = helper:GetAttribute("PlaceCol") or helper:GetAttribute("SpawnCol")
	
	if row and col and typeof(row) == "number" and typeof(col) == "number" then
		return row .. ":" .. col
	end
	
	-- Derive from OriginalCFrame position
	local originalCFrame = helper:GetAttribute("OriginalCFrame")
	if originalCFrame and typeof(originalCFrame) == "CFrame" then
		local gridId = helper:GetAttribute("GridId")
		if gridId then
			local grid = getGridFromGridId(gridId)
			if grid then
				local r, c = worldToCell(originalCFrame.Position, grid)
				if r and c then
					return r .. ":" .. c
				end
			end
		end
	end
	
	return nil
end

-- Get slot key from row and col
local function makeSlotKey(row, col)
	if row and col then
		return row .. ":" .. col
	end
	return nil
end

-- ===== REGISTRY MANAGEMENT =====

-- Register a helper (called when placed or first seen)
local function registerHelper(helper)
	if not helper:IsA("Model") then return false end
	
	local ownerUserId = helper:GetAttribute("OwnerUserId")
	local gridId = helper:GetAttribute("GridId")
	
	if not ownerUserId or not gridId then
		return false
	end
	
	local island = getIslandFromGridId(gridId)
	if not island then return false end
	
	local islandId = getIslandIdStrict(island)
	if not islandId then return false end
	
	-- Get slot key
	local row, col = nil, nil
	row = helper:GetAttribute("PlaceRow") or helper:GetAttribute("SpawnRow")
	col = helper:GetAttribute("PlaceCol") or helper:GetAttribute("SpawnCol")
	
	-- If not stored, derive from position
	if not row or not col then
		local root = helper:FindFirstChild("HumanoidRootPart") or helper.PrimaryPart
		if root then
			local grid = getGridFromGridId(gridId)
			if grid then
				row, col = worldToCell(root.Position, grid)
			end
		end
	end
	
	if not row or not col then
		warn("[HelperRespawnManager] Could not determine row/col for helper " .. helper.Name)
		return false
	end
	
	local slotKey = makeSlotKey(row, col)
	
	-- Initialize island registry if needed
	if not helperRegistry[islandId] then
		helperRegistry[islandId] = {}
	end
	
	-- Get original CFrame
	local originalCFrame = helper:GetAttribute("OriginalCFrame")
	if not originalCFrame or typeof(originalCFrame) ~= "CFrame" then
		local root = helper:FindFirstChild("HumanoidRootPart") or helper.PrimaryPart
		if root then
			originalCFrame = root.CFrame
			helper:SetAttribute("OriginalCFrame", originalCFrame)
		else
			warn("[HelperRespawnManager] Could not get CFrame for helper " .. helper.Name)
			return false
		end
	end
	
	-- Get template name
	local templateName = getHelperTemplateName(helper)
	
	-- Build registry record
	local record = {
		templateName = templateName,
		ownerUserId = ownerUserId,
		gridId = gridId,
		originalCFrame = originalCFrame,
		placeRow = row,
		placeCol = col,
		star = helper:GetAttribute("Star") or 0,
		starLevel = helper:GetAttribute("StarLevel") or 0,
		rarity = helper:GetAttribute("Rarity") or "Common",
		helperType = templateName,
		islandId = islandId,
		baseDamage = helper:GetAttribute("BaseDamage") or helper:GetAttribute("AttackDamage") or 12,
		baseHealth = helper:GetAttribute("BaseHealth") or 100,
		baseRange = helper:GetAttribute("BaseRange") or helper:GetAttribute("AttackRange") or 14,
		baseCooldown = helper:GetAttribute("BaseCooldown") or helper:GetAttribute("AttackCooldown") or 1.1,
	}
	
	-- Copy any other important attributes
	for _, attrName in ipairs({"HasCart", "UnitKey", "EnemyType", "TemplateName"}) do
		local val = helper:GetAttribute(attrName)
		if val ~= nil then
			record[attrName] = val
		end
	end
	
	helperRegistry[islandId][slotKey] = record
	
	print("[HelperRespawnManager] ✅ Registered helper: " .. templateName .. " at island " .. islandId .. " slot " .. slotKey)
	return true
end

-- Unregister a helper (when permanently removed/sold)
local function unregisterHelper(helper)
	local islandId = helper:GetAttribute("IslandId")
	local slotKey = getSlotKeyFromHelper(helper)
	
	if islandId and slotKey and helperRegistry[islandId] then
		helperRegistry[islandId][slotKey] = nil
		print("[HelperRespawnManager] ❌ Unregistered helper at island " .. islandId .. " slot " .. slotKey)
	end
end

-- ===== HELPER STATE RESET =====

-- Reset helper special state (cart, cooldowns, etc.)
local function resetHelperState(helper)
	-- Reset Tweaker cart if needed
	if helper.Name:find("Tweaker") then
		local restoreCartEvent = ReplicatedStorage:FindFirstChild("RestoreTweakerCart")
		if restoreCartEvent then
			restoreCartEvent:Fire(helper)
		end
	end
	
	-- Clear special flags
	helper:SetAttribute("IsDead", false)
	helper:SetAttribute("UsingSpecial", false)
	
	-- Clear charge cooldown (for TweakerCharge script)
	-- This will be handled by TweakerCharge script listening to restore event
	
	-- Reset velocities
	local root = helper:FindFirstChild("HumanoidRootPart") or helper.PrimaryPart
	if root then
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end
	
	-- Restore walk speed/jump power
	local hum = helper:FindFirstChildOfClass("Humanoid")
	if hum then
		local ws = helper:GetAttribute("OriginalWalkSpeed")
		local jp = helper:GetAttribute("OriginalJumpPower")
		if typeof(ws) == "number" and ws > 0 then
			hum.WalkSpeed = ws
		end
		if typeof(jp) == "number" and jp > 0 then
			hum.JumpPower = jp
		end
	end
end

-- ===== SPAWN/RESPAWN FUNCTIONS =====

-- Spawn a helper from registry record
local function spawnHelperFromRecord(islandId, slotKey, record)
	if not record then return nil end
	
	-- Find template
	local template = helperTemplates:FindFirstChild(record.templateName)
	if not template then
		warn("[HelperRespawnManager] Template not found: " .. record.templateName)
		return nil
	end
	
	-- Handle folder templates
	local modelToClone = template
	if template:IsA("Folder") then
		modelToClone = template:FindFirstChildOfClass("Model")
		if not modelToClone then
			modelToClone = template
		end
	end
	
	if not modelToClone:IsA("Model") then
		warn("[HelperRespawnManager] Template is not a Model: " .. record.templateName)
		return nil
	end
	
	-- Clone
	local helper = modelToClone:Clone()
	helper.Name = record.templateName .. "_" .. record.ownerUserId .. "_" .. os.time()
	
	-- Set PrimaryPart before positioning
	local primary = helper:FindFirstChild("HumanoidRootPart", true) 
		or helper.PrimaryPart 
		or helper:FindFirstChildWhichIsA("BasePart", true)
	if primary then
		helper.PrimaryPart = primary
	end
	
	-- Position at original CFrame
	helper:PivotTo(record.originalCFrame)
	
	-- Apply all attributes from record
	helper:SetAttribute("OwnerUserId", record.ownerUserId)
	helper:SetAttribute("GridId", record.gridId)
	helper:SetAttribute("IslandId", record.islandId)
	helper:SetAttribute("OriginalCFrame", record.originalCFrame)
	helper:SetAttribute("PlaceRow", record.placeRow)
	helper:SetAttribute("PlaceCol", record.placeCol)
	helper:SetAttribute("HelperType", record.helperType)
	helper:SetAttribute("HelperName", record.templateName)
	helper:SetAttribute("Star", record.star)
	helper:SetAttribute("StarLevel", record.starLevel)
	helper:SetAttribute("Rarity", record.rarity)
	helper:SetAttribute("BaseDamage", record.baseDamage)
	helper:SetAttribute("BaseHealth", record.baseHealth)
	helper:SetAttribute("BaseRange", record.baseRange)
	helper:SetAttribute("BaseCooldown", record.baseCooldown)
	helper:SetAttribute("AttackDamage", record.baseDamage * (2 ^ record.starLevel))
	helper:SetAttribute("AttackRange", record.baseRange)
	helper:SetAttribute("AttackCooldown", record.baseCooldown)
	
	-- Copy other attributes
	for key, val in pairs(record) do
		if key ~= "templateName" and key ~= "ownerUserId" and key ~= "gridId" 
			and key ~= "originalCFrame" and key ~= "placeRow" and key ~= "placeCol"
			and key ~= "star" and key ~= "starLevel" and key ~= "rarity"
			and key ~= "helperType" and key ~= "islandId"
			and key ~= "baseDamage" and key ~= "baseHealth" and key ~= "baseRange" and key ~= "baseCooldown" then
			helper:SetAttribute(key, val)
		end
	end
	
	-- Set humanoid health
	local hum = helper:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.MaxHealth = record.baseHealth * (2 ^ record.starLevel)
		hum.Health = hum.MaxHealth
		
		-- Store original walk speed/jump power if not set
		if helper:GetAttribute("OriginalWalkSpeed") == nil then
			helper:SetAttribute("OriginalWalkSpeed", hum.WalkSpeed > 0 and hum.WalkSpeed or 16)
		end
		if helper:GetAttribute("OriginalJumpPower") == nil then
			helper:SetAttribute("OriginalJumpPower", hum.JumpPower > 0 and hum.JumpPower or 50)
		end
	end
	
	-- Parent to Helpers folder
	helper.Parent = helpersFolder
	
	-- Reset state
	resetHelperState(helper)
	
	print("[HelperRespawnManager] ✅ Spawned helper: " .. record.templateName .. " at island " .. islandId .. " slot " .. slotKey)
	return helper
end

-- ===== DEATH HANDLING =====

-- Access waveActiveFlags from WaveManagerServer (we'll get it via a shared module or direct access)
-- For now, we'll use a BindableEvent to check wave state
local waveActiveFlags = {} -- [islandId] = true/false

-- Listen for wave state changes
local waveStateEvent = ReplicatedStorage:FindFirstChild("WaveStateEvent")
if not waveStateEvent then
	waveStateEvent = Instance.new("BindableEvent")
	waveStateEvent.Name = "WaveStateEvent"
	waveStateEvent.Parent = ReplicatedStorage
end

waveStateEvent.Event:Connect(function(islandId, isActive)
	if typeof(islandId) == "number" then
		waveActiveFlags[islandId] = isActive
	end
end)

-- Check if wave is active for an island
local function isWaveActive(islandId)
	return waveActiveFlags[islandId] == true
end

-- Handle helper death
local function handleHelperDeath(helper)
	local islandId = helper:GetAttribute("IslandId")
	local slotKey = getSlotKeyFromHelper(helper)
	
	if not islandId or not slotKey then
		-- Can't respawn without registry info
		warn("[HelperRespawnManager] Helper died but missing islandId or slotKey: " .. helper.Name)
		return
	end
	
	local record = helperRegistry[islandId] and helperRegistry[islandId][slotKey]
	if not record then
		-- Try to register before destroying
		registerHelper(helper)
		record = helperRegistry[islandId] and helperRegistry[islandId][slotKey]
	end
	
	-- Check if wave is active
	local waveActive = isWaveActive(islandId)
	
	if waveActive and record then
		-- Wave is active: destroy and respawn immediately
		print("[HelperRespawnManager] Helper died during wave - respawning: " .. helper.Name)
		
		-- Destroy the old helper (with explosion effect)
		task.spawn(function()
			-- Apply explosion effect
			for _, part in ipairs(helper:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Anchored = false
					part.AssemblyLinearVelocity = Vector3.new(
						(math.random() - 0.5) * 200,
						math.random() * 100 + 50,
						(math.random() - 0.5) * 200
					)
					part.AssemblyAngularVelocity = Vector3.new(
						(math.random() - 0.5) * 50,
						(math.random() - 0.5) * 50,
						(math.random() - 0.5) * 50
					)
				end
			end
			
			task.wait(1.0)
			if helper and helper.Parent then
				helper:Destroy()
			end
			
			-- Respawn after destruction
			task.wait(0.1)
			local newHelper = spawnHelperFromRecord(islandId, slotKey, record)
			if newHelper then
				-- Unfreeze and make aggressive if wave still active
				if isWaveActive(islandId) then
					-- Signal WaveManagerServer to unfreeze (or do it directly if accessible)
					local unfreezeEvent = ReplicatedStorage:FindFirstChild("UnfreezeHelperEvent")
					if unfreezeEvent then
						unfreezeEvent:Fire(newHelper)
					end
					newHelper:SetAttribute("Aggressive", true)
				else
					-- Wave ended, keep frozen
					newHelper:SetAttribute("Aggressive", false)
				end
			end
		end)
	else
		-- Wave not active: just destroy, no respawn
		print("[HelperRespawnManager] Helper died outside wave - destroying: " .. helper.Name)
		task.spawn(function()
			for _, part in ipairs(helper:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Anchored = false
					part.AssemblyLinearVelocity = Vector3.new(
						(math.random() - 0.5) * 200,
						math.random() * 100 + 50,
						(math.random() - 0.5) * 200
					)
					part.AssemblyAngularVelocity = Vector3.new(
						(math.random() - 0.5) * 50,
						(math.random() - 0.5) * 50,
						(math.random() - 0.5) * 50
					)
				end
			end
			task.wait(1.0)
			if helper and helper.Parent then
				helper:Destroy()
			end
		end)
	end
end

-- ===== WAVE END RESET =====

-- Reset all helpers for an island at wave end
local function resetHelpersForIsland(islandId)
	if not helperRegistry[islandId] then return end
	
	print("[HelperRespawnManager] 🔄 Resetting helpers for island " .. islandId)
	
	-- Get all existing helpers for this island
	local existingHelpers = {}
	for _, helper in ipairs(helpersFolder:GetChildren()) do
		if helper:IsA("Model") then
			local helperIslandId = helper:GetAttribute("IslandId")
			if helperIslandId == islandId then
				local slotKey = getSlotKeyFromHelper(helper)
				if slotKey then
					existingHelpers[slotKey] = helper
				end
			end
		end
	end
	
	-- Ensure exactly one helper per registered slot
	for slotKey, record in pairs(helperRegistry[islandId]) do
		local existing = existingHelpers[slotKey]
		
		if existing and existing.Parent then
			-- Helper exists: hard reset
			local hum = existing:FindFirstChildOfClass("Humanoid")
			if hum then
				-- Revive if dead
				if hum.Health <= 0 then
					hum:ChangeState(Enum.HumanoidStateType.GettingUp)
					hum.Health = 1
				end
				-- Heal to full
				hum.Health = hum.MaxHealth
			end
			
			-- Reset position
			if record.originalCFrame then
				existing:PivotTo(record.originalCFrame)
			end
			
			-- Reset state
			resetHelperState(existing)
			
			-- Freeze for prep phase
			local freezeEvent = ReplicatedStorage:FindFirstChild("FreezeHelperEvent")
			if freezeEvent then
				freezeEvent:Fire(existing)
			end
			existing:SetAttribute("Aggressive", false)
		else
			-- Helper missing: respawn
			print("[HelperRespawnManager] Respawn missing helper at slot " .. slotKey)
			local newHelper = spawnHelperFromRecord(islandId, slotKey, record)
			if newHelper then
				-- Keep frozen for prep phase
				newHelper:SetAttribute("Aggressive", false)
			end
		end
	end
	
	-- Remove any duplicate helpers (helpers not in registry)
	for slotKey, helper in pairs(existingHelpers) do
		if not helperRegistry[islandId][slotKey] then
			warn("[HelperRespawnManager] Removing orphaned helper: " .. helper.Name)
			helper:Destroy()
		end
	end
end

-- ===== INITIALIZATION =====

-- DISABLED: HelperRespawnManager death handling is disabled
-- WaveManagerServer now handles helper death (hide, don't destroy)
-- Monitor helpers folder for new placements
--[[
helpersFolder.ChildAdded:Connect(function(helper)
	task.wait(0.1) -- Wait for attributes to be set
	
	if not helper:IsA("Model") then return end
	
	-- Register the helper
	registerHelper(helper)
	
	-- Set up death handler
	local hum = helper:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.Died:Once(function()
			handleHelperDeath(helper)
		end)
	end
end)
--]]

-- Monitor for removal (unregister if permanently removed)
helpersFolder.ChildRemoved:Connect(function(helper)
	-- Only unregister if it's a permanent removal (not a respawn)
	-- We can't easily distinguish, so we'll keep the registry and let wave end reset handle it
end)

-- Listen for wave end events
local waveEndEvent = ReplicatedStorage:FindFirstChild("WaveEndEvent")
if not waveEndEvent then
	waveEndEvent = Instance.new("BindableEvent")
	waveEndEvent.Name = "WaveEndEvent"
	waveEndEvent.Parent = ReplicatedStorage
end

waveEndEvent.Event:Connect(function(islandId)
	if typeof(islandId) == "number" then
		resetHelpersForIsland(islandId)
	end
end)

-- DISABLED: HelperRespawnManager death handling is disabled
-- WaveManagerServer now handles helper death (hide, don't destroy)
-- Register existing helpers on startup
--[[
task.wait(1) -- Wait for other scripts to initialize
for _, helper in ipairs(helpersFolder:GetChildren()) do
	if helper:IsA("Model") then
		task.spawn(function()
			task.wait(0.1)
			registerHelper(helper)
			
			-- Set up death handler for existing helpers
			local hum = helper:FindFirstChildOfClass("Humanoid")
			if hum then
				hum.Died:Once(function()
					handleHelperDeath(helper)
				end)
			end
		end)
	end
end
--]]

print("[HelperRespawnManager] ✅ Initialized")
