-- HelperPlacement.server.lua
-- Must be placed in: ServerScriptService > HelperPlacement.server.lua

print("[HelperPlacement] Server script starting...")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

-- Get helper templates
local templatesFolder = ServerStorage:WaitForChild("HelperTemplates")
print("[HelperPlacement] Found HelperTemplates folder")

-- Ensure Remotes folder exists
local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
	print("[HelperPlacement] Created Remotes folder")
end

-- Create RemoteEvents
local requestBuyHelper = remotes:FindFirstChild("RequestBuyHelper")
if not requestBuyHelper then
	requestBuyHelper = Instance.new("RemoteEvent")
	requestBuyHelper.Name = "RequestBuyHelper"
	requestBuyHelper.Parent = remotes
	print("[HelperPlacement] Created RequestBuyHelper RemoteEvent")
end

local requestPlaceHelper = remotes:FindFirstChild("RequestPlaceHelper")
if not requestPlaceHelper then
	requestPlaceHelper = Instance.new("RemoteEvent")
	requestPlaceHelper.Name = "RequestPlaceHelper"
	requestPlaceHelper.Parent = remotes
	print("[HelperPlacement] Created RequestPlaceHelper RemoteEvent")
end

local helperResponse = remotes:FindFirstChild("HelperResponse")
if not helperResponse then
	helperResponse = Instance.new("RemoteEvent")
	helperResponse.Name = "HelperResponse"
	helperResponse.Parent = remotes
	print("[HelperPlacement] Created HelperResponse RemoteEvent")
end

-- Ensure Helpers folder exists
local helpersFolder = workspace:FindFirstChild("Helpers")
if not helpersFolder then
	helpersFolder = Instance.new("Folder")
	helpersFolder.Name = "Helpers"
	helpersFolder.Parent = workspace
	print("[HelperPlacement] Created Helpers folder in workspace")
end

-- Helper costs
local HELPER_COSTS = {
	Appraiser = 150,
	Indigenous = 200,
	MagicHobo = 100,
	MuscularHobo = 120,
	Thrower = 180,
	Tweaker = 160,
}

-- Grid ownership system (integrated with GridHelperSpawnerServer)
local gridOwnerUserId = {} -- grid -> userId

-- Get all grid floors (same as GridHelperSpawnerServer)
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

-- Update grid ownership from GridOwnershipEvent
local gridOwnershipEvent = ReplicatedStorage:FindFirstChild("GridOwnershipEvent")
if gridOwnershipEvent then
	-- Listen for ownership updates (server-side, we'll track manually)
	task.spawn(function()
		-- Poll for grid ownership by checking GridHelperSpawnerServer's state
		-- For now, we'll validate on placement
	end)
end

-- Find grid at position
local function findGridAtPosition(position)
	local allGrids = getAllGridFloors()
	local closestGrid = nil
	local closestDistance = math.huge
	
	for _, grid in ipairs(allGrids) do
		-- Check if position is within grid bounds
		local localPos = grid.CFrame:PointToObjectSpace(position)
		local halfX = grid.Size.X / 2
		local halfZ = grid.Size.Z / 2
		
		if math.abs(localPos.X) <= halfX and math.abs(localPos.Z) <= halfZ then
			local distance = (grid.Position - position).Magnitude
			if distance < closestDistance then
				closestDistance = distance
				closestGrid = grid
			end
		end
	end
	
	return closestGrid
end

-- Get grid owner from GridHelperSpawnerServer (check workspace for Helpers with OwnerUserId attribute)
local function getGridOwner(grid)
	-- Check if any helper on this grid has an OwnerUserId attribute matching a player
	-- This is a workaround - ideally we'd access GridHelperSpawnerServer's state
	-- For now, we'll use a simpler approach: check if grid has a StringValue with owner info
	-- Or we can check workspace.Helpers for helpers placed on this grid
	
	-- Better approach: Use the grid's GetFullName to match with GridHelperSpawnerServer
	-- Since we can't directly access GridHelperSpawnerServer's state, we'll validate differently
	-- Check if player has any helpers on this grid already
	return nil -- Will be validated by checking existing helpers
end

-- Get available helpers
local function getAvailableHelpers()
	local helpers = {}
	for _, child in ipairs(templatesFolder:GetChildren()) do
		if child:IsA("Model") or child:IsA("Folder") then
			-- Check if it has a model inside (for folders)
			local hasModel = false
			if child:IsA("Folder") then
				hasModel = child:FindFirstChildOfClass("Model") ~= nil
				-- Or check if it has parts
				if not hasModel then
					for _, desc in ipairs(child:GetDescendants()) do
						if desc:IsA("BasePart") or desc:IsA("Model") then
							hasModel = true
							break
						end
					end
				end
			else
				hasModel = true
			end
			
			if hasModel then
				table.insert(helpers, {
					name = child.Name,
					cost = HELPER_COSTS[child.Name] or 150,
				})
			end
		end
	end
	table.sort(helpers, function(a, b) return a.name < b.name end)
	return helpers
end

-- Get player coins
local function getCoins(player)
	local ls = player:FindFirstChild("leaderstats")
	local coins = ls and ls:FindFirstChild("Coins")
	if coins and coins:IsA("IntValue") then
		return coins.Value
	end
	return 0
end

-- Get owned count for a helper
local function getOwnedCount(player, helperName)
	local key = "Inv_" .. helperName
	return player:GetAttribute(key) or 0
end

-- Get placed helpers count
local function getPlacedCount(player)
	local count = 0
	for _, helper in ipairs(helpersFolder:GetChildren()) do
		if helper:GetAttribute("OwnerUserId") == player.UserId then
			count = count + 1
		end
	end
	return count
end

-- Send helpers list
local function sendHelpersList(player)
	print("[HelperPlacement] Sending helpers list to", player.Name)
	local helpers = getAvailableHelpers()
	local response = {}
	
	for _, helper in ipairs(helpers) do
		table.insert(response, {
			name = helper.name,
			cost = helper.cost,
			owned = getOwnedCount(player, helper.name),
		})
	end
	
	helperResponse:FireClient(player, "HelpersList", {
		helpers = response,
	})
	
	print("[HelperPlacement] Sent", #response, "helpers to", player.Name)
end

-- Get all grid floors (same as GridHelperSpawnerServer)
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

-- Find grid at position
local function findGridAtPosition(position)
	local allGrids = getAllGridFloors()
	local closestGrid = nil
	local closestDistance = math.huge
	
	for _, grid in ipairs(allGrids) do
		-- Check if position is within grid bounds
		local localPos = grid.CFrame:PointToObjectSpace(position)
		local halfX = grid.Size.X / 2
		local halfZ = grid.Size.Z / 2
		
		if math.abs(localPos.X) <= halfX and math.abs(localPos.Z) <= halfZ then
			local distance = (grid.Position - position).Magnitude
			if distance < closestDistance then
				closestDistance = distance
				closestGrid = grid
			end
		end
	end
	
	return closestGrid
end

-- Check if grid has helpers from other players
local function gridHasOtherPlayerHelpers(grid, playerUserId)
	local helpersFolder = workspace:FindFirstChild("Helpers")
	if not helpersFolder then
		return false
	end
	
	for _, helper in ipairs(helpersFolder:GetChildren()) do
		if helper:IsA("Model") then
			local ownerId = helper:GetAttribute("OwnerUserId")
			if ownerId and ownerId ~= playerUserId then
				-- Check if helper is on this grid
				local helperPos = helper:GetPivot().Position
				local gridLocalPos = grid.CFrame:PointToObjectSpace(helperPos)
				local halfX = grid.Size.X / 2
				local halfZ = grid.Size.Z / 2
				if math.abs(gridLocalPos.X) <= halfX and math.abs(gridLocalPos.Z) <= halfZ then
					return true
				end
			end
		end
	end
	
	return false
end

-- Handle place request
local function handlePlace(player, helperName, hitCFrame)
	print("[HelperPlacement] Place request from", player.Name, "for", helperName, "at", hitCFrame.Position)
	
	-- Validate helper exists
	local template = templatesFolder:FindFirstChild(helperName)
	if not template then
		print("[HelperPlacement] ERROR: Template not found:", helperName)
		helperResponse:FireClient(player, "PlaceResult", {
			success = false,
			message = "Helper template not found: " .. helperName,
		})
		return
	end
	
	-- Find grid at placement position
	local targetGrid = findGridAtPosition(hitCFrame.Position)
	if not targetGrid then
		print("[HelperPlacement] ERROR: No grid found at position")
		helperResponse:FireClient(player, "PlaceResult", {
			success = false,
			message = "No grid found at that position!",
		})
		return
	end
	
	-- Check grid ownership by checking if player has helpers on this grid
	-- If they have helpers here, they own it. Otherwise check if grid is empty.
	local hasHelpersOnGrid = false
	local helpersFolder = workspace:FindFirstChild("Helpers")
	if helpersFolder then
		for _, helper in ipairs(helpersFolder:GetChildren()) do
			if helper:IsA("Model") and helper:GetAttribute("OwnerUserId") == player.UserId then
				-- Check if helper is on this grid (within bounds)
				local helperPos = helper:GetPivot().Position
				local gridLocalPos = targetGrid.CFrame:PointToObjectSpace(helperPos)
				local halfX = targetGrid.Size.X / 2
				local halfZ = targetGrid.Size.Z / 2
				if math.abs(gridLocalPos.X) <= halfX and math.abs(gridLocalPos.Z) <= halfZ then
					hasHelpersOnGrid = true
					break
				end
			end
		end
	end
	
	-- Check if grid has any helpers from other players
	local hasOtherPlayerHelpers = false
	if helpersFolder then
		for _, helper in ipairs(helpersFolder:GetChildren()) do
			if helper:IsA("Model") then
				local ownerId = helper:GetAttribute("OwnerUserId")
				if ownerId and ownerId ~= player.UserId then
					local helperPos = helper:GetPivot().Position
					local gridLocalPos = targetGrid.CFrame:PointToObjectSpace(helperPos)
					local halfX = targetGrid.Size.X / 2
					local halfZ = targetGrid.Size.Z / 2
					if math.abs(gridLocalPos.X) <= halfX and math.abs(gridLocalPos.Z) <= halfZ then
						hasOtherPlayerHelpers = true
						break
					end
				end
			end
		end
	end
	
	-- If grid has other player's helpers, deny placement
	if hasOtherPlayerHelpers then
		print("[HelperPlacement] ERROR: Grid has other player's helpers")
		helperResponse:FireClient(player, "PlaceResult", {
			success = false,
			message = "This grid belongs to another player!",
		})
		return
	end
	
	-- Placement limit removed - will be implemented separately later
	
	-- Validate distance (≤60 studs)
	local character = player.Character
	if not character then
		helperResponse:FireClient(player, "PlaceResult", {
			success = false,
			message = "Character not found!",
		})
		return
	end
	
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then
		helperResponse:FireClient(player, "PlaceResult", {
			success = false,
			message = "HumanoidRootPart not found!",
		})
		return
	end
	
	local distance = (hitCFrame.Position - humanoidRootPart.Position).Magnitude
	if distance > 60 then
		print("[HelperPlacement] ERROR: Distance too far:", distance)
		helperResponse:FireClient(player, "PlaceResult", {
			success = false,
			message = "Too far! Must be within 60 studs.",
		})
		return
	end
	
	-- Clone template
	local helper = template:Clone()
	helper.Name = helperName .. "_" .. player.Name .. "_" .. os.time()
	
	-- Find model inside if it's a folder
	local modelToPosition = helper
	if helper:IsA("Folder") then
		modelToPosition = helper:FindFirstChildOfClass("Model")
		if not modelToPosition then
			modelToPosition = helper
		end
	end
	
	-- Set PrimaryPart if missing
	if modelToPosition:IsA("Model") then
		if not modelToPosition.PrimaryPart then
			local humanoidRootPart = modelToPosition:FindFirstChild("HumanoidRootPart")
			if humanoidRootPart then
				modelToPosition.PrimaryPart = humanoidRootPart
			else
				-- Find first BasePart
				for _, part in ipairs(modelToPosition:GetDescendants()) do
					if part:IsA("BasePart") then
						modelToPosition.PrimaryPart = part
						break
					end
				end
			end
		end
	end
	
	-- Calculate facing direction - helpers face opposite of grid's LookVector (towards enemy side)
	-- This matches GridHelperSpawnerServer's original behavior
	local faceDir = -targetGrid.CFrame.LookVector
	faceDir = Vector3.new(faceDir.X, 0, faceDir.Z).Unit -- Keep horizontal, normalize
	
	-- Get position from hitCFrame
	local position = hitCFrame.Position
	
	-- Calculate Y offset (place on grid surface)
	local yOffset = 0
	if modelToPosition:IsA("Model") and modelToPosition.PrimaryPart then
		yOffset = modelToPosition.PrimaryPart.Size.Y / 2
	else
		-- Find first part for size calculation
		for _, part in ipairs(helper:GetDescendants()) do
			if part:IsA("BasePart") then
				yOffset = part.Size.Y / 2
				break
			end
		end
	end
	
	-- Adjust position to be on grid surface
	local gridWorldPos = targetGrid.CFrame:PointToWorldSpace(Vector3.new(0, targetGrid.Size.Y / 2 + yOffset, 0))
	position = Vector3.new(position.X, gridWorldPos.Y, position.Z)
	
	-- Create CFrame with proper facing (same as GridHelperSpawnerServer)
	local facingCFrame = CFrame.lookAt(position, position + faceDir)
	
	-- Position helper with correct facing
	if modelToPosition:IsA("Model") and modelToPosition.PrimaryPart then
		modelToPosition:PivotTo(facingCFrame)
	else
		-- Fallback: find any part and position it
		local firstPart = nil
		for _, part in ipairs(helper:GetDescendants()) do
			if part:IsA("BasePart") then
				firstPart = part
				break
			end
		end
		if firstPart then
			helper:PivotTo(facingCFrame)
		end
	end
	
	-- Parent to workspace.Helpers
	helper.Parent = helpersFolder
	
	-- Get IslandId from grid (for merge system and wave system)
	local function getIslandIdFromGrid(gridPart)
		if not gridPart then return nil end
		
		-- Walk up the hierarchy to find Island model
		local current = gridPart
		while current and current.Parent and current.Parent ~= workspace do
			if current:IsA("Model") then
				-- Check if it's an island (must have numeric IslandId)
				local islandId = current:GetAttribute("IslandId")
				if typeof(islandId) == "number" then
					return islandId
				end
			end
			current = current.Parent
		end
		
		return nil
	end
	
	local islandId = getIslandIdFromGrid(targetGrid)
	
	-- Set attributes (CRITICAL for WaveManagerServer and merge system)
	helper:SetAttribute("OwnerUserId", player.UserId)
	helper:SetAttribute("HelperName", helperName)
	helper:SetAttribute("GridId", targetGrid:GetFullName()) -- Required for WaveManagerServer to find island
	if islandId then
		helper:SetAttribute("IslandId", islandId) -- Required for merge system
	end
	
	-- Calculate row/col from position for HelperRespawnManager
	local function worldToCellForGrid(worldPos, grid)
		if not grid then return nil, nil end
		local localPos = grid.CFrame:PointToObjectSpace(worldPos)
		local halfX = grid.Size.X / 2
		local halfZ = grid.Size.Z / 2
		if localPos.X < -halfX or localPos.X > halfX or localPos.Z < -halfZ or localPos.Z > halfZ then
			return nil, nil
		end
		local x01 = localPos.X + halfX
		local z01 = localPos.Z + halfZ
		local GRID_SIZE = 5
		local col = math.floor(x01 / GRID_SIZE) + 1
		local row = math.floor(z01 / GRID_SIZE) + 1
		return row, col
	end
	
	local placeRow, placeCol = worldToCellForGrid(hitCFrame.Position, targetGrid)
	if not placeRow or not placeCol then
		helperResponse:FireClient(player, "PlaceResult", {
			success = false,
			message = "Invalid tile position!",
		})
		return
	end
	
	-- Check if placement is on player side (rows 1-5 only)
	local PLAYER_MIN_ROW, PLAYER_MAX_ROW = 1, 5
	if placeRow < PLAYER_MIN_ROW or placeRow > PLAYER_MAX_ROW then
		helperResponse:FireClient(player, "PlaceResult", {
			success = false,
			message = "You can only place on your side.",
		})
		return
	end
	
	-- Check if tile is already occupied (check blueprints - authoritative source)
	local gridId = targetGrid:GetFullName()
	if _G.IsHelperTileOccupied then
		if _G.IsHelperTileOccupied(gridId, placeRow, placeCol) then
			helperResponse:FireClient(player, "PlaceResult", {
				success = false,
				message = "That tile is already occupied!",
			})
			return
		end
	else
		-- Fallback: check board instances if blueprint system not loaded
		for _, existingHelper in ipairs(helpersFolder:GetChildren()) do
			if existingHelper:IsA("Model") then
				local existingGridId = existingHelper:GetAttribute("GridId")
				local existingRow = existingHelper:GetAttribute("PlaceRow")
				local existingCol = existingHelper:GetAttribute("PlaceCol")
				
				if existingGridId == gridId 
					and typeof(existingRow) == "number" and existingRow == placeRow
					and typeof(existingCol) == "number" and existingCol == placeCol then
					helperResponse:FireClient(player, "PlaceResult", {
						success = false,
						message = "That tile is already occupied!",
					})
					return
				end
			end
		end
	end
	
	-- Set tile position attributes
	helper:SetAttribute("PlaceRow", placeRow)
	helper:SetAttribute("PlaceCol", placeCol)
	
	-- Set HelperType
	helper:SetAttribute("HelperType", helperName)
	
	-- Store OriginalCFrame if not set
	if not helper:GetAttribute("OriginalCFrame") then
		local root = helper:FindFirstChild("HumanoidRootPart") or helper.PrimaryPart
		if root then
			helper:SetAttribute("OriginalCFrame", root.CFrame)
		end
	end
	
	-- Save blueprint (authoritative copy)
	if _G.SaveHelperBlueprint then
		_G.SaveHelperBlueprint(helper)
	end
	
	print("[HelperPlacement] Successfully placed", helperName, "for", player.Name, "at", hitCFrame.Position)
	print("[HelperPlacement]   ✅ Set GridId=" .. targetGrid:GetFullName() .. (islandId and (", IslandId=" .. tostring(islandId)) or ""))
	
	helperResponse:FireClient(player, "PlaceResult", {
		success = true,
		message = "Placed " .. helperName .. "!",
		helperName = helperName,
	})
end

-- Remote event handlers
requestBuyHelper.OnServerEvent:Connect(function(player, action)
	print("[HelperPlacement] RequestBuyHelper from", player.Name, "action:", action)
	
	if action == "GetHelpersList" then
		sendHelpersList(player)
	end
end)

requestPlaceHelper.OnServerEvent:Connect(function(player, helperName, hitCFrame)
	print("[HelperPlacement] RequestPlaceHelper from", player.Name, "helper:", helperName)
	
	if typeof(helperName) == "string" and typeof(hitCFrame) == "CFrame" then
		handlePlace(player, helperName, hitCFrame)
	else
		warn("[HelperPlacement] Invalid place request from", player.Name)
		helperResponse:FireClient(player, "PlaceResult", {
			success = false,
			message = "Invalid request!",
		})
	end
end)

-- Sync display models to ReplicatedStorage for client ViewportFrames
local function syncDisplayModels()
	local displayFolder = ReplicatedStorage:FindFirstChild("HelperDisplayTemplates")
	if not displayFolder then
		displayFolder = Instance.new("Folder")
		displayFolder.Name = "HelperDisplayTemplates"
		displayFolder.Parent = ReplicatedStorage
		print("[HelperPlacement] Created HelperDisplayTemplates folder")
	end
	
	-- Clear existing display models
	for _, child in ipairs(displayFolder:GetChildren()) do
		child:Destroy()
	end
	
	-- Clone templates to ReplicatedStorage
	for _, template in ipairs(templatesFolder:GetChildren()) do
		if template:IsA("Model") or template:IsA("Folder") then
			local displayModel = template:Clone()
			displayModel.Name = template.Name
			displayModel.Parent = displayFolder
			print("[HelperPlacement] Synced display model: " .. template.Name)
		end
	end
end

-- Sync on startup
syncDisplayModels()

-- Re-sync when templates change
templatesFolder.ChildAdded:Connect(function()
	task.wait(0.5)
	syncDisplayModels()
end)

templatesFolder.ChildRemoved:Connect(function()
	task.wait(0.5)
	syncDisplayModels()
end)

-- Send helpers list when player joins
Players.PlayerAdded:Connect(function(player)
	task.wait(1) -- Wait for leaderstats
	sendHelpersList(player)
end)

-- Send to existing players
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(function()
		task.wait(1)
		sendHelpersList(player)
	end)
end

print("[HelperPlacement] Server script initialized!")
local helpers = getAvailableHelpers()
print("[HelperPlacement] Found", #helpers, "available helpers:", table.concat((function()
	local names = {}
	for _, h in ipairs(helpers) do
		table.insert(names, h.name)
	end
	return names
end)(), ", "))
