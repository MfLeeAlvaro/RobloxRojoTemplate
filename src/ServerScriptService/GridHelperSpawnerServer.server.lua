--========================================================
-- GridHelperSpawnerServer (MULTI-GRID SUPPORT + ISLAND OWNERSHIP)
-- Supports placement on ANY Gridfloor part in workspace
-- Each island is owned by exactly one player
--========================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local placeHelperEvent = ReplicatedStorage:WaitForChild("PlaceHelperEvent")

-- ============================================================
-- ISLAND OWNERSHIP SYSTEM
-- gridOwnerUserId[grid] = userId (which player owns this grid)
-- ownedGridByUserId[userId] = grid (which grid does this player own)
-- ============================================================
local gridOwnerUserId = {} -- grid -> userId
local ownedGridByUserId = {} -- userId -> grid

-- Find all Gridfloor parts in workspace (supports multiple islands/platforms)
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

-- Get all grids on server startup
local allGrids = getAllGridFloors()
print("[GridHelperSpawnerServer] Found " .. #allGrids .. " Gridfloor parts in workspace")

-- Create or get GridOwnershipEvent RemoteEvent for replicating ownership to clients
local gridOwnershipEvent = ReplicatedStorage:FindFirstChild("GridOwnershipEvent")
if not gridOwnershipEvent then
	gridOwnershipEvent = Instance.new("RemoteEvent")
	gridOwnershipEvent.Name = "GridOwnershipEvent"
	gridOwnershipEvent.Parent = ReplicatedStorage
	print("[GridHelperSpawnerServer] Created GridOwnershipEvent RemoteEvent")
end

-- Function to notify all clients about grid ownership change
local function notifyGridOwnership(grid, ownerUserId)
	-- Use grid:GetFullName() as a string identifier for the grid
	local gridId = grid:GetFullName()
	gridOwnershipEvent:FireAllClients(gridId, ownerUserId)
	print("[GridHelperSpawnerServer] Notified clients: Grid " .. gridId .. " owned by userId " .. tostring(ownerUserId))
end

-- Function to assign a grid to a player
local function assignGridToPlayer(grid, player)
	if not grid or not player then
		return false
	end
	
	-- If grid is already owned by this player, do nothing
	if gridOwnerUserId[grid] == player.UserId then
		print("[GridHelperSpawnerServer] Grid " .. grid:GetFullName() .. " already owned by " .. player.Name)
		return true
	end
	
	-- If grid is owned by someone else, cannot assign
	if gridOwnerUserId[grid] then
		print("[GridHelperSpawnerServer] Grid " .. grid:GetFullName() .. " already owned by userId " .. gridOwnerUserId[grid])
		return false
	end
	
	-- Free the player's previous grid if they had one
	if ownedGridByUserId[player.UserId] then
		local oldGrid = ownedGridByUserId[player.UserId]
		gridOwnerUserId[oldGrid] = nil
		notifyGridOwnership(oldGrid, nil)
		print("[GridHelperSpawnerServer] Freed old grid " .. oldGrid:GetFullName() .. " from " .. player.Name)
	end
	
	-- Assign new grid
	gridOwnerUserId[grid] = player.UserId
	ownedGridByUserId[player.UserId] = grid
	notifyGridOwnership(grid, player.UserId)
	print("[GridHelperSpawnerServer] ✅ Assigned grid " .. grid:GetFullName() .. " to player " .. player.Name .. " (userId: " .. player.UserId .. ")")
	return true
end

-- Function to find the closest Gridfloor to a position
local function findClosestGrid(position)
	local closestGrid = nil
	local closestDistance = math.huge
	
	for _, grid in ipairs(allGrids) do
		local distance = (grid.Position - position).Magnitude
		if distance < closestDistance then
			closestDistance = distance
			closestGrid = grid
		end
	end
	
	return closestGrid
end

-- Function to find the closest UNOWNED Gridfloor to a position
local function findClosestUnownedGrid(position)
	local closestGrid = nil
	local closestDistance = math.huge
	
	for _, grid in ipairs(allGrids) do
		-- Skip if already owned
		if not gridOwnerUserId[grid] then
			local distance = (grid.Position - position).Magnitude
			if distance < closestDistance then
				closestDistance = distance
				closestGrid = grid
			end
		end
	end
	
	return closestGrid
end

-- Function to assign island to player when they spawn
local function assignIslandOnSpawn(player)
	-- Wait for character to spawn
	local character = player.Character or player.CharacterAdded:Wait()
	
	-- Wait for HumanoidRootPart or PrimaryPart
	local rootPart = character:WaitForChild("HumanoidRootPart", 10) 
		or character:FindFirstChild("PrimaryPart")
		or character:FindFirstChildWhichIsA("BasePart")
	
	if not rootPart then
		warn("[GridHelperSpawnerServer] Could not find root part for " .. player.Name)
		return
	end
	
	-- Wait a moment for character to fully spawn
	task.wait(0.5)
	
	local spawnPosition = rootPart.Position
	
	-- Check if player already owns a grid (rejoin scenario)
	if ownedGridByUserId[player.UserId] then
		local existingGrid = ownedGridByUserId[player.UserId]
		-- Verify the grid still exists
		if existingGrid.Parent then
			print("[GridHelperSpawnerServer] Player " .. player.Name .. " rejoined, keeping existing grid: " .. existingGrid:GetFullName())
			notifyGridOwnership(existingGrid, player.UserId)
			return
		else
			-- Grid was deleted, free it
			gridOwnerUserId[existingGrid] = nil
			ownedGridByUserId[player.UserId] = nil
		end
	end
	
	-- Find closest grid to spawn position
	local closestGrid = findClosestGrid(spawnPosition)
	
	if not closestGrid then
		warn("[GridHelperSpawnerServer] No grids found for " .. player.Name)
		return
	end
	
	-- Try to assign closest grid
	if assignGridToPlayer(closestGrid, player) then
		return
	end
	
	-- If closest grid is owned, find closest unowned grid
	local unownedGrid = findClosestUnownedGrid(spawnPosition)
	if unownedGrid then
		assignGridToPlayer(unownedGrid, player)
	else
		warn("[GridHelperSpawnerServer] No unowned grids available for " .. player.Name .. " - they can spectate but not place")
	end
end

local TEMPLATES_FOLDER = ServerStorage:WaitForChild("HelperTemplates")

-- Grid rules
local GRID_SIZE = 5
local GRID_COLS = 10
local GRID_ROWS = 10

-- ============================================================
-- UPDATED: Occupancy is now per-grid + per-player
-- OLD CODE (line 40): local occupied = {} (per-player only)
-- NEW CODE: occupied[grid][userId][row][col] = model
-- WHY CHANGED: Each grid needs its own occupancy tracking,
--   so units on different grids don't conflict
-- ============================================================
-- Occupancy per-grid + per-player: occupied[grid][userId][row][col] = model
local occupied = {}

local function ensurePlayerTable(grid, userId)
	if not occupied[grid] then
		occupied[grid] = {}
	end
	if not occupied[grid][userId] then
		occupied[grid][userId] = {}
		for r = 1, GRID_ROWS do
			occupied[grid][userId][r] = {}
		end
	end
end

-- ============================================================
-- UPDATED: Now uses the specific hitGrid's CFrame for calculations
-- OLD CODE (lines 50-73): Used hard-coded GRID_FLOOR.CFrame
-- WHY CHANGED: Each grid can be at different positions/rotations,
--   so we must use the specific grid's CFrame for accurate cell calculations
-- ============================================================
-- Convert world position to (row, col) on a specific grid (supports rotation)
local function worldToCell(worldPos, hitGrid)
	if not hitGrid then
		return nil
	end

	-- Use the specific grid's CFrame (supports rotation/movement)
	local localPos = hitGrid.CFrame:PointToObjectSpace(worldPos)

	local halfX = hitGrid.Size.X / 2
	local halfZ = hitGrid.Size.Z / 2

	-- outside board
	if localPos.X < -halfX or localPos.X > halfX or localPos.Z < -halfZ or localPos.Z > halfZ then
		return nil
	end

	-- convert to [0..size]
	local x01 = localPos.X + halfX
	local z01 = localPos.Z + halfZ

	local col = math.floor(x01 / GRID_SIZE) + 1
	local row = math.floor(z01 / GRID_SIZE) + 1

	if row < 1 or row > GRID_ROWS or col < 1 or col > GRID_COLS then
		return nil
	end

	return row, col
end

-- ============================================================
-- UPDATED: Now uses the specific hitGrid's CFrame for world position
-- OLD CODE (lines 76-98): Used hard-coded GRID_FLOOR.CFrame
-- WHY CHANGED: Each grid can be at different positions/rotations,
--   so we must use the specific grid's CFrame for accurate placement
-- ============================================================
-- Convert (row, col) to world CFrame at the center of the cell, facing a direction
local function cellToWorldCFrame(row, col, yOffset, faceDirWorld, hitGrid)
	if not hitGrid then
		return nil
	end

	local halfX = hitGrid.Size.X / 2
	local halfZ = hitGrid.Size.Z / 2

	local centerX = (-halfX) + (col - 0.5) * GRID_SIZE
	local centerZ = (-halfZ) + (row - 0.5) * GRID_SIZE

	-- Use the specific grid's CFrame to convert to world space
	local worldCenter = hitGrid.CFrame:PointToWorldSpace(Vector3.new(centerX, 0, centerZ))
	local topY = hitGrid.Position.Y + (hitGrid.Size.Y / 2)

	local pos = Vector3.new(worldCenter.X, topY + (yOffset or 0), worldCenter.Z)

	-- Default: face opposite of grid's LookVector (or custom if provided)
	local dir = faceDirWorld or -hitGrid.CFrame.LookVector
	dir = Vector3.new(dir.X, 0, dir.Z)

	-- Safety: if dir becomes zero-length, fall back
	if dir.Magnitude < 0.001 then
		dir = Vector3.new(0, 0, -1)
	end

	return CFrame.lookAt(pos, pos + dir)
end

local playerOrder = {}

Players.PlayerAdded:Connect(function(plr)
	table.insert(playerOrder, plr.UserId)
	
	-- Assign island when player spawns
	plr.CharacterAdded:Connect(function()
		assignIslandOnSpawn(plr)
	end)
	
	-- Also try to assign immediately if character already exists
	if plr.Character then
		task.spawn(function()
			assignIslandOnSpawn(plr)
		end)
	end
end)

-- ============================================================
-- ADDED: PlayerRemoving handler to free grids
-- WHY: When a player leaves, their grid should be freed so others can use it
-- ============================================================
Players.PlayerRemoving:Connect(function(plr)
	local ownedGrid = ownedGridByUserId[plr.UserId]
	if ownedGrid then
		print("[GridHelperSpawnerServer] 🗑️ Freeing grid " .. ownedGrid:GetFullName() .. " from leaving player " .. plr.Name)
		gridOwnerUserId[ownedGrid] = nil
		ownedGridByUserId[plr.UserId] = nil
		notifyGridOwnership(ownedGrid, nil)
		
		-- Clean up occupancy for this player on this grid
		if occupied[ownedGrid] and occupied[ownedGrid][plr.UserId] then
			occupied[ownedGrid][plr.UserId] = nil
		end
	end
	
	-- Remove from playerOrder
	for i, uid in ipairs(playerOrder) do
		if uid == plr.UserId then
			table.remove(playerOrder, i)
			break
		end
	end
end)

local function getAllowedRowsForPlayer(player)
	for i, uid in ipairs(playerOrder) do
		if uid == player.UserId then
			if i == 1 then return 1, 5 end
			if i == 2 then return 6, 10 end
			return nil
		end
	end
	return nil
end

-- ============================================================
-- FIXED: RemoteEvent argument order to match client call
-- OLD CODE (line 117): OnServerEvent:Connect(function(player, worldPosition, helperName)
-- NEW CODE: OnServerEvent:Connect(function(player, hitGrid, worldPosition, helperName)
-- WHY CHANGED: Client now sends (hitGridPart, snappedWorldPos, helperName),
--   so server receives (player, hitGrid, worldPosition, helperName)
-- ============================================================
placeHelperEvent.OnServerEvent:Connect(function(player, hitGrid, worldPosition, helperName)
	-- ============================================================
	-- ADDED: Validate hitGrid is a BasePart named "Gridfloor"
	-- WHY: Security - ensure client sent a valid grid part
	-- ============================================================
	if not hitGrid or not hitGrid:IsA("BasePart") or hitGrid.Name ~= "Gridfloor" then
		warn("Invalid grid part from player " .. player.Name)
		return
	end

	-- ============================================================
	-- ADDED: Ownership check - only grid owner can place
	-- WHY: Each island is owned by one player, only they can place
	-- ============================================================
	if gridOwnerUserId[hitGrid] ~= player.UserId then
		local ownerId = gridOwnerUserId[hitGrid]
		print("[GridHelperSpawnerServer] ❌ Placement denied: Player " .. player.Name .. " tried to place on grid owned by userId " .. tostring(ownerId))
		placeHelperEvent:FireClient(player, false, "This island belongs to another player.")
		return
	end

	-- Basic validation
	if typeof(worldPosition) ~= "Vector3" or typeof(helperName) ~= "string" then
		return
	end

	-- ============================================================
	-- UPDATED: Use hitGrid instead of hard-coded GRID_FLOOR
	-- OLD CODE (line 123): local row, col = worldToCell(worldPosition)
	-- NEW CODE: local row, col = worldToCell(worldPosition, hitGrid)
	-- WHY CHANGED: Must use the specific grid that was hit
	-- ============================================================
	local row, col = worldToCell(worldPosition, hitGrid)
	if not row then
		placeHelperEvent:FireClient(player, false, "Not on the grid.")
		return
	end

	-- Check half-board restriction
	local minRow, maxRow = getAllowedRowsForPlayer(player)
	if not minRow then
		placeHelperEvent:FireClient(player, false, "You are not assigned a side (only first 2 players can place).")
		return
	end
	if row < minRow or row > maxRow then
		placeHelperEvent:FireClient(player, false, "You can only place on your side of the board.")
		return
	end

	-- ============================================================
	-- UPDATED: Use hitGrid for occupancy tracking
	-- OLD CODE (line 140): ensurePlayerTable(player.UserId)
	-- NEW CODE: ensurePlayerTable(hitGrid, player.UserId)
	-- WHY CHANGED: Occupancy is now per-grid, so we need the grid reference
	-- ============================================================
	ensurePlayerTable(hitGrid, player.UserId)

	-- ============================================================
	-- UPDATED: Check occupancy on the specific grid
	-- OLD CODE (line 143): if occupied[player.UserId][row][col] then
	-- NEW CODE: if occupied[hitGrid][player.UserId][row][col] then
	-- WHY CHANGED: Occupancy is now per-grid + per-player
	-- ============================================================
	-- Occupancy check (per-grid + per-player)
	if occupied[hitGrid][player.UserId][row][col] then
		placeHelperEvent:FireClient(player, false, "That cell is already occupied.")
		return
	end

	local template = TEMPLATES_FOLDER:FindFirstChild(helperName)
	if not template or not template:IsA("Model") then
		placeHelperEvent:FireClient(player, false, "Invalid unit: " .. helperName)
		return
	end

	-- Ensure Helpers folder exists
	local helpersFolder = workspace:FindFirstChild("Helpers") or Instance.new("Folder")
	helpersFolder.Name = "Helpers"
	helpersFolder.Parent = workspace

	local unit = template:Clone()
	unit.Parent = helpersFolder

	--========================================================
	-- ✅ FIX #1: Pick/set PrimaryPart BEFORE PivotTo
	-- WHY:
	-- PivotTo uses the model pivot. If PrimaryPart/pivot isn't stable,
	-- the model can land offset or rotate weirdly.
	--========================================================
	local primary =
		unit:FindFirstChild("HumanoidRootPart", true)
		or unit.PrimaryPart
		or unit:FindFirstChildWhichIsA("BasePart", true)

	local yOffset = 2
	if primary and primary:IsA("BasePart") then
		unit.PrimaryPart = primary
		yOffset = primary.Size.Y / 2
	end

	-- ============================================================
	-- UPDATED: Use hitGrid's LookVector instead of hard-coded GRID_FLOOR
	-- OLD CODE (line 179): local faceDir = -GRID_FLOOR.CFrame.LookVector
	-- NEW CODE: local faceDir = -hitGrid.CFrame.LookVector
	-- WHY CHANGED: Each grid can have different orientation
	-- ============================================================
	local faceDir = -hitGrid.CFrame.LookVector

	--========================================================
	-- ✅ FIX #2: Compute cf BEFORE PivotTo
	-- OLD BUG: PivotTo(cf) was called before cf existed → cf was nil
	-- Result: runtime error, event handler stops, unit stays at template location.
	--========================================================
	-- ============================================================
	-- UPDATED: Pass hitGrid to cellToWorldCFrame
	-- OLD CODE (line 186): local cf = cellToWorldCFrame(row, col, yOffset, faceDir)
	-- NEW CODE: local cf = cellToWorldCFrame(row, col, yOffset, faceDir, hitGrid)
	-- WHY CHANGED: Must use the specific grid's CFrame for placement
	-- ============================================================
	local cf = cellToWorldCFrame(row, col, yOffset, faceDir, hitGrid)
	if not cf then
		warn("Failed to compute CFrame for placement")
		return
	end

	unit:SetAttribute("OwnerUserId", player.UserId)
	unit:SetAttribute("UnitType", helperName)

	unit:PivotTo(cf) -- ✅ correct placement happens here

	-- ============================================================
	-- UPDATED: Store occupancy on the specific grid
	-- OLD CODE (line 199): occupied[player.UserId][row][col] = unit
	-- NEW CODE: occupied[hitGrid][player.UserId][row][col] = unit
	-- WHY CHANGED: Occupancy is now per-grid + per-player
	-- ============================================================
	occupied[hitGrid][player.UserId][row][col] = unit
	placeHelperEvent:FireClient(player, true, ("Placed %s at (%d, %d)"):format(helperName, row, col))
end)

print("✅ GridHelperSpawnerServer loaded! (Multi-grid support + Island ownership enabled)")
