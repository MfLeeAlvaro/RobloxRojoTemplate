--========================================================
-- HelperDragClient.client.lua
-- Drag & Drop Helper Move System
-- Allows players to drag existing helpers to new tiles
--========================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()

-- Constants
local GRID_SIZE = 5
local PLAYER_MIN_ROW, PLAYER_MAX_ROW = 1, 5

-- Debug flag
local DEBUG = true -- Enable for debugging

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

-- Wave state tracking
local waveActiveFlags = {} -- [islandId] = true/false

-- Listen for wave state changes via RemoteEvent
local waveStateRemote = ReplicatedStorage:FindFirstChild("WaveStateRemote")
if waveStateRemote then
	waveStateRemote.OnClientEvent:Connect(function(islandId, isActive)
		if typeof(islandId) == "number" then
			waveActiveFlags[islandId] = isActive
			if DEBUG then
				print("[HelperDragClient] Wave state updated: Island " .. islandId .. " = " .. tostring(isActive))
			end
		end
	end)
end

-- Check if wave is active for a helper
local function isWaveActiveForHelper(helper)
	local islandId = helper:GetAttribute("IslandId")
	if not islandId or typeof(islandId) ~= "number" then
		return false -- Default to false if no islandId
	end
	return waveActiveFlags[islandId] == true
end

-- Find all Gridfloor parts
local cachedGridFloors = {}
local function refreshGridFloors()
	cachedGridFloors = {}
	local function searchDescendants(parent)
		for _, descendant in ipairs(parent:GetDescendants()) do
			if descendant:IsA("BasePart") and descendant.Name == "Gridfloor" then
				table.insert(cachedGridFloors, descendant)
			end
		end
	end
	searchDescendants(workspace)
end
refreshGridFloors()

-- Refresh every 5 seconds
task.spawn(function()
	while true do
		task.wait(5)
		refreshGridFloors()
	end
end)

-- Get mouse world position on any grid
local function getMouseWorldOnAnyGrid()
	local unitRay = mouse.UnitRay
	local origin = unitRay.Origin
	local direction = unitRay.Direction * 1000

	if #cachedGridFloors == 0 then
		refreshGridFloors()
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = cachedGridFloors
	params.IgnoreWater = true

	local result = workspace:Raycast(origin, direction, params)
	if result and result.Instance then
		if result.Instance:IsA("BasePart") and result.Instance.Name == "Gridfloor" then
			return result.Position, result.Instance
		end
	end

	return nil, nil
end

-- Snap to grid (returns worldCenter, row, col)
local function snapToGridWorld(position, hitGridPart)
	if not hitGridPart then
		return nil, nil, nil
	end

	local localPos = hitGridPart.CFrame:PointToObjectSpace(position)
	local boardX = hitGridPart.Size.X
	local boardZ = hitGridPart.Size.Z
	local halfX = boardX / 2
	local halfZ = boardZ / 2

	if localPos.X < -halfX or localPos.X > halfX or localPos.Z < -halfZ or localPos.Z > halfZ then
		return nil, nil, nil
	end

	local x01 = localPos.X + halfX
	local z01 = localPos.Z + halfZ

	local col = math.floor(x01 / GRID_SIZE) + 1
	local row = math.floor(z01 / GRID_SIZE) + 1

	local centerX = (-halfX) + (col - 0.5) * GRID_SIZE
	local centerZ = (-halfZ) + (row - 0.5) * GRID_SIZE

	local localCenter = Vector3.new(centerX, 0, centerZ)
	local worldCenter = hitGridPart.CFrame:PointToWorldSpace(localCenter)

	return worldCenter, row, col
end

-- Drag state
local dragState = {
	isDragging = false,
	draggedHelper = nil,
	originalCFrame = nil,
	previewPart = nil,
	selectionBox = nil,
}

-- Create preview highlight
local function createPreview()
	if dragState.previewPart then
		dragState.previewPart:Destroy()
	end

	local highlight = Instance.new("Part")
	highlight.Name = "HelperMovePreview"
	highlight.Size = Vector3.new(GRID_SIZE * 0.98, 0.5, GRID_SIZE * 0.98)
	highlight.Anchored = true
	highlight.CanCollide = false
	highlight.Transparency = 0.5
	highlight.Color = Color3.fromRGB(0, 255, 0)
	highlight.Material = Enum.Material.Neon
	highlight.Parent = workspace

	local selectionBox = Instance.new("SelectionBox")
	selectionBox.LineThickness = 0.1
	selectionBox.Color3 = Color3.fromRGB(0, 255, 0)
	selectionBox.Adornee = highlight
	selectionBox.Parent = highlight

	dragState.previewPart = highlight
	dragState.selectionBox = selectionBox
end

-- Update preview position and color
local function updatePreview()
	if not dragState.isDragging or not dragState.previewPart then
		return
	end

	local hitPosition, hitGridPart = getMouseWorldOnAnyGrid()
	if not hitPosition or not hitGridPart then
		dragState.previewPart.Transparency = 1
		dragState.selectionBox.Transparency = 1
		return
	end

	local snappedWorld, row, col = snapToGridWorld(hitPosition, hitGridPart)
	if not snappedWorld or not row or not col then
		dragState.previewPart.Transparency = 1
		dragState.selectionBox.Transparency = 1
		return
	end

	-- Check validity
	local gridId = hitGridPart:GetFullName()
	local draggedGridId = dragState.draggedHelper:GetAttribute("GridId")
	local draggedRow = dragState.draggedHelper:GetAttribute("PlaceRow")
	local draggedCol = dragState.draggedHelper:GetAttribute("PlaceCol")

	local isValid = true
	local reason = ""

	-- If helper is on a platform (no GridId), allow moving to any grid
	-- If helper is already on a grid, check if it's the same tile
	if not draggedGridId or draggedGridId == "" then
		-- Helper is on platform, allow moving to grid
		isValid = true
	else
		-- Helper is on grid, check if same tile (no-op)
		if gridId == draggedGridId and row == draggedRow and col == draggedCol then
			isValid = true -- Same tile is valid (no-op)
		end
	end

	-- Check row (must be 1-5) for any move
	if row < PLAYER_MIN_ROW or row > PLAYER_MAX_ROW then
		isValid = false
		reason = "Can't move to enemy side"
	end

	-- Update preview color
	if isValid then
		dragState.previewPart.Color = Color3.fromRGB(0, 255, 0)
		dragState.selectionBox.Color3 = Color3.fromRGB(0, 255, 0)
	else
		dragState.previewPart.Color = Color3.fromRGB(255, 0, 0)
		dragState.selectionBox.Color3 = Color3.fromRGB(255, 0, 0)
	end

	-- Position preview
	local floorY = hitGridPart.Position.Y + (hitGridPart.Size.Y / 2)
	dragState.previewPart.Position = Vector3.new(snappedWorld.X, floorY + 0.25, snappedWorld.Z)
	dragState.previewPart.Transparency = 0.5
	dragState.selectionBox.Transparency = 0
end

-- Start dragging
local function startDrag(helper)
	if not helper or not helper.Parent then
		return
	end

	-- Check ownership
	local ownerId = helper:GetAttribute("OwnerUserId")
	if not ownerId or ownerId ~= player.UserId then
		if DEBUG then
			print("[HelperDragClient] Cannot drag: not owned by player")
		end
		return
	end

	-- Check if wave is active (block dragging during waves)
	if isWaveActiveForHelper(helper) then
		if DEBUG then
			print("[HelperDragClient] Cannot drag: wave is active")
		end
		return
	end

	dragState.isDragging = true
	dragState.draggedHelper = helper
	dragState.originalCFrame = helper:GetPivot()

	createPreview()

	if DEBUG then
		print("[HelperDragClient] Started dragging: " .. helper.Name)
	end
end

-- End dragging
local function endDrag()
	if not dragState.isDragging or not dragState.draggedHelper then
		return
	end

	local helper = dragState.draggedHelper
	local hitPosition, hitGridPart = getMouseWorldOnAnyGrid()

	if hitPosition and hitGridPart then
		local snappedWorld, row, col = snapToGridWorld(hitPosition, hitGridPart)
		if snappedWorld and row and col then
			local gridId = hitGridPart:GetFullName()
			local draggedGridId = helper:GetAttribute("GridId")
			local draggedRow = helper:GetAttribute("PlaceRow")
			local draggedCol = helper:GetAttribute("PlaceCol")

			-- Check if same tile (only if helper is already on a grid)
			if draggedGridId and draggedGridId ~= "" and gridId == draggedGridId and row == draggedRow and col == draggedCol then
				-- Same tile, do nothing
				if DEBUG then
					print("[HelperDragClient] Same tile, no move needed")
				end
			else
				-- Fire server request (moving from platform to grid, or grid to grid)
				local targetCFrame = CFrame.new(snappedWorld)
				
				-- Debug: verify gridId
				if DEBUG then
					local helperGridId = helper:GetAttribute("GridId")
					print("[HelperDragClient] Moving helper:")
					print("  Helper GridId: " .. tostring(helperGridId) .. " (nil = on platform)")
					print("  Target GridId: " .. tostring(gridId))
					print("  Target Row/Col: " .. row .. "/" .. col)
				end
				
				requestMoveHelper:FireServer(helper, gridId, row, col, targetCFrame)
			end
		end
	end

	-- Clean up preview
	if dragState.previewPart then
		dragState.previewPart:Destroy()
		dragState.previewPart = nil
		dragState.selectionBox = nil
	end

	dragState.isDragging = false
	dragState.draggedHelper = nil
	dragState.originalCFrame = nil
end

-- Listen for move result
moveHelperResult.OnClientEvent:Connect(function(success, message)
	if not success then
		-- Show error message (you can integrate with your UI system)
		print("[HelperDragClient] Move failed: " .. (message or "Unknown error"))
	end
end)

-- Mouse input handling
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		local target = mouse.Target
		if target then
			-- Walk up hierarchy to find helper model
			local helper = target
			while helper and helper ~= workspace do
				if helper:IsA("Model") then
					-- Check if it's owned by player (for drag & drop)
					local ownerId = helper:GetAttribute("OwnerUserId")
					if ownerId == player.UserId then
						-- Allow dragging helpers from workspace.Helpers OR workspace (shop platforms)
						local isInHelpersFolder = helper.Parent == workspace:FindFirstChild("Helpers")
						local isInWorkspace = helper.Parent == workspace
						
						if isInHelpersFolder or isInWorkspace then
							startDrag(helper)
							break
						end
					end
				end
				helper = helper.Parent
			end
		end
	end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if dragState.isDragging then
			endDrag()
		end
	end
end)

-- Update preview position while dragging
RunService.RenderStepped:Connect(function()
	if dragState.isDragging then
		updatePreview()
	end
end)

print("[HelperDragClient] ✅ Initialized")
