--========================================================
-- HelperMoveServer.server.lua
-- Server-authoritative helper move system
-- Validates and executes helper moves on the board
--========================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local workspace = game:GetService("Workspace")

-- Debug flag
local DEBUG = true -- Enable for debugging grid lookup issues

-- Constants
local GRID_SIZE = 5
local PLAYER_MIN_ROW, PLAYER_MAX_ROW = 1, 5

-- RemoteEvents
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local requestMoveHelper = remotes:FindFirstChild("RequestMoveHelper")
if not requestMoveHelper then
	requestMoveHelper = Instance.new("RemoteEvent")
	requestMoveHelper.Name = "RequestMoveHelper"
	requestMoveHelper.Parent = remotes
end

local moveHelperResult = remotes:FindFirstChild("MoveHelperResult")
if not moveHelperResult then
	moveHelperResult = Instance.new("RemoteEvent")
	moveHelperResult.Name = "MoveHelperResult"
	moveHelperResult.Parent = remotes
end

-- Helpers folder
local helpersFolder = workspace:WaitForChild("Helpers")

-- Helper templates folder (for cloning fresh instances from platforms)
local helperTemplatesFolder = ServerStorage:WaitForChild("HelperTemplates")

-- Find grid part from GridId string
-- GridId is stored as GetFullName() which includes "Workspace." prefix
-- Use recursive search to find the part directly
local function getGridFromGridId(gridId)
	if not gridId or typeof(gridId) ~= "string" then return nil end
	
	-- Remove "Workspace." prefix if present (GetFullName() includes it)
	local searchPath = gridId
	if gridId:sub(1, 10) == "Workspace." then
		searchPath = gridId:sub(11) -- Remove "Workspace." prefix
	end
	
	-- Try recursive search first (most reliable)
	local gridPart = workspace:FindFirstChild(searchPath, true)
	if gridPart and gridPart:IsA("BasePart") and gridPart.Name == "Gridfloor" then
		return gridPart
	end
	
	-- Fallback: parse path manually (skip "Workspace" if present)
	local parts = {}
	for part in gridId:gmatch("[^.]+") do
		table.insert(parts, part)
	end
	
	-- Skip "Workspace" if it's the first part
	local startIdx = 1
	if parts[1] == "Workspace" then
		startIdx = 2
	end
	
	local current = workspace
	for i = startIdx, #parts do
		current = current:FindFirstChild(parts[i])
		if not current then 
			warn("[HelperMoveServer] Failed to find part in path: " .. parts[i] .. " (full path: " .. gridId .. ")")
			return nil 
		end
	end
	
	if current and current:IsA("BasePart") and current.Name == "Gridfloor" then
		return current
	end
	
	warn("[HelperMoveServer] Grid part found but invalid: " .. tostring(current) .. " (expected Gridfloor, got " .. (current and current.Name or "nil") .. ")")
	return nil
end

-- Get occupancy key
local function getOccupancyKey(gridId, row, col)
	return gridId .. ":" .. row .. ":" .. col
end

-- Handle move request
requestMoveHelper.OnServerEvent:Connect(function(player, helperInstance, gridId, targetRow, targetCol, targetCFrame)
	if DEBUG then
		print("[HelperMoveServer] Move request from " .. player.Name .. " for helper " .. (helperInstance and helperInstance.Name or "nil"))
	end

	-- Validate helper exists and is in Helpers folder
	if not helperInstance or not helperInstance:IsA("Model") then
		if DEBUG then
			warn("[HelperMoveServer] Invalid helper instance")
		end
		moveHelperResult:FireClient(player, false, "Invalid helper")
		return
	end

	-- Allow helpers from workspace.Helpers OR workspace (shop platforms)
	local isInHelpersFolder = helperInstance.Parent == helpersFolder
	local isInWorkspace = helperInstance.Parent == workspace
	
	if not isInHelpersFolder and not isInWorkspace then
		if DEBUG then
			warn("[HelperMoveServer] Helper not in Helpers folder or workspace")
		end
		moveHelperResult:FireClient(player, false, "Helper not found")
		return
	end

	-- Validate ownership
	local ownerId = helperInstance:GetAttribute("OwnerUserId")
	if not ownerId or ownerId ~= player.UserId then
		if DEBUG then
			warn("[HelperMoveServer] Ownership mismatch: " .. tostring(ownerId) .. " != " .. tostring(player.UserId))
		end
		moveHelperResult:FireClient(player, false, "You don't own this helper")
		return
	end

	-- Get current gridId (may be nil if helper is on platform)
	local currentGridId = helperInstance:GetAttribute("GridId")
	
	-- If helper is on a platform (no GridId), allow moving to any grid
	-- If helper is already on a grid, validate gridId matches
	if currentGridId and currentGridId ~= "" and currentGridId ~= gridId then
		if DEBUG then
			warn("[HelperMoveServer] GridId mismatch: " .. tostring(currentGridId) .. " != " .. tostring(gridId))
		end
		moveHelperResult:FireClient(player, false, "Invalid grid")
		return
	end

	-- Validate target row (must be 1-5)
	if not targetRow or targetRow < PLAYER_MIN_ROW or targetRow > PLAYER_MAX_ROW then
		if DEBUG then
			warn("[HelperMoveServer] Invalid row: " .. tostring(targetRow))
		end
		moveHelperResult:FireClient(player, false, "You can only move to your side (rows 1-5)")
		return
	end

	-- Get current position (BEFORE updating)
	local currentRow = helperInstance:GetAttribute("PlaceRow")
	local currentCol = helperInstance:GetAttribute("PlaceCol")
	local currentGridId = helperInstance:GetAttribute("GridId")

	-- Check if same tile (only if helper is already on a grid)
	if currentGridId and currentGridId ~= "" and currentRow and currentCol then
		if currentRow == targetRow and currentCol == targetCol and currentGridId == gridId then
			if DEBUG then
				print("[HelperMoveServer] Same tile, no move needed")
			end
			moveHelperResult:FireClient(player, true, "Moved")
			return
		end
	end

	-- CRITICAL: Remove old blueprint BEFORE updating position (only if helper was on a grid)
	-- This prevents duplicate blueprints at old and new positions
	if _G.RemoveHelperBlueprint and currentGridId and currentGridId ~= "" and currentRow and currentCol then
		_G.RemoveHelperBlueprint(currentGridId, currentRow, currentCol)
		if DEBUG then
			print("[HelperMoveServer] Removed old blueprint at (" .. currentRow .. ", " .. currentCol .. ")")
		end
	end

	-- Check occupancy (authoritative: use blueprint system)
	if _G.IsHelperTileOccupied then
		if _G.IsHelperTileOccupied(gridId, targetRow, targetCol) then
			-- Check if it's occupied by THIS helper (moving to same tile)
			local occupiedHelper = nil
			-- Try to find the helper occupying this tile
			for _, h in ipairs(helpersFolder:GetChildren()) do
				if h:IsA("Model") then
					local hGridId = h:GetAttribute("GridId")
					local hRow = h:GetAttribute("PlaceRow")
					local hCol = h:GetAttribute("PlaceCol")
					if hGridId == gridId and hRow == targetRow and hCol == targetCol then
						if h ~= helperInstance then
							occupiedHelper = h
							break
						end
					end
				end
			end

			if occupiedHelper then
				if DEBUG then
					warn("[HelperMoveServer] Tile occupied by another helper")
				end
				moveHelperResult:FireClient(player, false, "That tile is already occupied")
				return
			end
		end
	else
		-- Fallback: check board instances
		for _, h in ipairs(helpersFolder:GetChildren()) do
			if h:IsA("Model") and h ~= helperInstance then
				local hGridId = h:GetAttribute("GridId")
				local hRow = h:GetAttribute("PlaceRow")
				local hCol = h:GetAttribute("PlaceCol")
				if hGridId == gridId and hRow == targetRow and hCol == targetCol then
					if DEBUG then
						warn("[HelperMoveServer] Tile occupied by another helper (fallback check)")
					end
					moveHelperResult:FireClient(player, false, "That tile is already occupied")
					return
				end
			end
		end
	end

	-- Validate targetCFrame
	if not targetCFrame or typeof(targetCFrame) ~= "CFrame" then
		if DEBUG then
			warn("[HelperMoveServer] Invalid targetCFrame")
		end
		moveHelperResult:FireClient(player, false, "Invalid position")
		return
	end

	-- Get grid part for positioning
	local gridPart = getGridFromGridId(gridId)
	if not gridPart then
		warn("[HelperMoveServer] ❌ Grid part not found!")
		warn("[HelperMoveServer]   GridId: " .. tostring(gridId))
		warn("[HelperMoveServer]   Helper: " .. helperInstance.Name)
		warn("[HelperMoveServer]   Helper GridId attribute: " .. tostring(helperInstance:GetAttribute("GridId")))
		
		-- Try to find grid by helper's current position as fallback
		local root = helperInstance:FindFirstChild("HumanoidRootPart") or helperInstance.PrimaryPart
		if root then
			-- Search for nearest Gridfloor
			local allGrids = {}
			for _, descendant in ipairs(workspace:GetDescendants()) do
				if descendant:IsA("BasePart") and descendant.Name == "Gridfloor" then
					table.insert(allGrids, descendant)
				end
			end
			
			local closestGrid = nil
			local closestDist = math.huge
			for _, grid in ipairs(allGrids) do
				local dist = (grid.Position - root.Position).Magnitude
				if dist < closestDist then
					closestDist = dist
					closestGrid = grid
				end
			end
			
			if closestGrid then
				warn("[HelperMoveServer]   Found fallback grid: " .. closestGrid:GetFullName() .. " (distance: " .. math.floor(closestDist) .. ")")
				gridPart = closestGrid
				-- Update GridId to match
				gridId = closestGrid:GetFullName()
				helperInstance:SetAttribute("GridId", gridId)
			end
		end
		
		if not gridPart then
			moveHelperResult:FireClient(player, false, "Grid not found")
			return
		end
	end

	-- Calculate proper Y position (on grid surface)
	local gridWorldPos = gridPart.CFrame:PointToWorldSpace(Vector3.new(0, gridPart.Size.Y / 2, 0))
	local root = helperInstance:FindFirstChild("HumanoidRootPart") or helperInstance.PrimaryPart
	local yOffset = 0
	if root then
		yOffset = root.Size.Y / 2
	end
	local finalPosition = Vector3.new(targetCFrame.Position.X, gridWorldPos.Y + yOffset, targetCFrame.Position.Z)

	-- Calculate facing direction (same as placement: face opposite of grid's LookVector)
	local faceDir = -gridPart.CFrame.LookVector
	faceDir = Vector3.new(faceDir.X, 0, faceDir.Z).Unit
	local finalCFrame = CFrame.lookAt(finalPosition, finalPosition + faceDir)

	-- Update occupancy (free old tile, occupy new tile)
	-- Note: Blueprint system handles authoritative occupancy, but we also update GridHelperSpawnerServer's table if needed
	-- The blueprint system will be updated when we call UpdateHelperBlueprint

	-- Get IslandId from grid (for merge system and wave system)
	local function getIslandIdFromGrid(gridPart)
		if not gridPart then return nil end
		local current = gridPart
		while current and current.Parent and current.Parent ~= workspace do
			if current:IsA("Model") then
				local islandId = current:GetAttribute("IslandId")
				if typeof(islandId) == "number" then
					return islandId
				end
			end
			current = current.Parent
		end
		return nil
	end
	
	local islandId = getIslandIdFromGrid(gridPart)
	
	-- SPECIAL CASE: If helper is coming from platform (workspace), clone a fresh instance
	-- This ensures Tweaker cart and other special parts are intact
	local isFromPlatform = helperInstance.Parent == workspace
	local finalHelper = helperInstance
	
	if isFromPlatform then
		if DEBUG then
			print("[HelperMoveServer] Helper is from platform, cloning fresh instance...")
		end
		
		-- Get helper type from attributes
		local helperType = helperInstance:GetAttribute("HelperType") or helperInstance:GetAttribute("HelperName")
		if not helperType or helperType == "" then
			-- Try to infer from name (remove numbers/suffixes)
			helperType = helperInstance.Name:match("^([^%s%d]+)")
		end
		
		if not helperType then
			warn("[HelperMoveServer] Could not determine helper type for cloning, using existing instance")
		else
			-- Find template
			local template = helperTemplatesFolder:FindFirstChild(helperType)
			if not template or not template:IsA("Model") then
				-- Try folder with model inside
				if template and template:IsA("Folder") then
					template = template:FindFirstChildOfClass("Model")
				end
			end
			
			if template and template:IsA("Model") then
				-- Clone fresh instance
				finalHelper = template:Clone()
				finalHelper.Name = helperType
				
				-- Disable player collision (prevent players from getting stuck)
				if _G.DisablePlayerCollision then
					_G.DisablePlayerCollision(finalHelper)
				end
				
				-- Copy all important attributes from old helper
				local importantAttrs = {
					"OwnerUserId", "HelperType", "HelperName", "Star", "Rarity",
					"AttackDamage", "AttackRange", "AttackCooldown", "Synergy", "Element",
					"DamageMult", "SpecialReady", "SpecialCooldown"
				}
				
				for _, attrName in ipairs(importantAttrs) do
					local value = helperInstance:GetAttribute(attrName)
					if value ~= nil then
						finalHelper:SetAttribute(attrName, value)
					end
				end
				
				-- Set new position attributes
				finalHelper:SetAttribute("GridId", gridId)
				finalHelper:SetAttribute("PlaceRow", targetRow)
				finalHelper:SetAttribute("PlaceCol", targetCol)
				finalHelper:SetAttribute("OriginalCFrame", finalCFrame)
				if islandId then
					finalHelper:SetAttribute("IslandId", islandId)
				end
				
				-- Position the new helper
				finalHelper.Parent = helpersFolder
				finalHelper:PivotTo(finalCFrame)
				
				-- Delete old helper from platform
				helperInstance:Destroy()
				
				if DEBUG then
					print("[HelperMoveServer] ✅ Cloned fresh " .. helperType .. " and deleted old platform instance")
				end
			else
				warn("[HelperMoveServer] Template not found for " .. helperType .. ", using existing instance")
				-- Fall through to normal move logic
			end
		end
	end
	
	-- Normal move logic (if not from platform, or if cloning failed)
	if not isFromPlatform or finalHelper == helperInstance then
		-- Update helper attributes BEFORE moving
		finalHelper:SetAttribute("GridId", gridId)
		finalHelper:SetAttribute("PlaceRow", targetRow)
		finalHelper:SetAttribute("PlaceCol", targetCol)
		finalHelper:SetAttribute("OriginalCFrame", finalCFrame)
		if islandId then
			finalHelper:SetAttribute("IslandId", islandId)
		end
		
		-- Move helper safely
		finalHelper:PivotTo(finalCFrame)
		
		-- Ensure helper is in Helpers folder
		if finalHelper.Parent ~= helpersFolder then
			finalHelper.Parent = helpersFolder
		end
	end

	-- Save NEW blueprint at new position (this creates a new blueprint with new helperKey)
	-- The old blueprint was already removed above
	if _G.SaveHelperBlueprint then
		_G.SaveHelperBlueprint(finalHelper)
		if DEBUG then
			print("[HelperMoveServer] Saved new blueprint at (" .. targetRow .. ", " .. targetCol .. ")")
		end
	end

	-- Keep helper frozen if wave not active (maintain state)
	local hum = finalHelper:FindFirstChildOfClass("Humanoid")
	if hum then
		local isFrozen = finalHelper:GetAttribute("Frozen") == true
		if isFrozen then
			hum.WalkSpeed = 0
			hum.JumpPower = 0
			hum:Move(Vector3.zero)
		end
	end

	if DEBUG then
		print("[HelperMoveServer] ✅ Moved helper " .. finalHelper.Name .. " to (" .. targetRow .. ", " .. targetCol .. ")")
	end

	moveHelperResult:FireClient(player, true, "Moved successfully")
end)

print("[HelperMoveServer] ✅ Initialized")
