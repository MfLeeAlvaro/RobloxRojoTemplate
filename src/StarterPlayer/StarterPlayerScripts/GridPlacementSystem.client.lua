local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()

-- SETTINGS
local GRID_SIZE = 5

-- ============================================================
-- REMOVED: Hard-coded single GRID_FLOOR path
-- OLD CODE (lines 10-14):
--   local GRID_FLOOR = workspace:WaitForChild("Island")
--   	:WaitForChild("Arena")
--   	:WaitForChild("Platform")
--   	:WaitForChild("BattlePlatform")
--   	:WaitForChild("Gridfloor")
-- WHY REMOVED: This only worked for one specific grid path.
--   With duplicated islands/platforms, we need to support ANY Gridfloor part.
-- ============================================================

-- ============================================================
-- ADDED: Island ownership tracking for client-side feedback
-- gridOwners[gridId] = ownerUserId (gridId is grid:GetFullName() string)
-- ============================================================
local gridOwners = {} -- gridId (string) -> ownerUserId

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

-- Cache grid floors (refresh periodically in case new ones are added)
local cachedGridFloors = {}
local function refreshGridFloors()
	cachedGridFloors = getAllGridFloors()
end
refreshGridFloors()

-- Refresh every 5 seconds in case new grids are added
task.spawn(function()
	while true do
		task.wait(5)
		refreshGridFloors()
	end
end)

-- ============================================================
-- ADDED: Listen to GridOwnershipEvent to track ownership
-- WHY: Client needs to know which grids are owned by which players
--   to show appropriate highlight colors and block placement
-- ============================================================
local gridOwnershipEvent = ReplicatedStorage:WaitForChild("GridOwnershipEvent")

gridOwnershipEvent.OnClientEvent:Connect(function(gridId, ownerUserId)
	-- gridId is grid:GetFullName() string, ownerUserId is the owner's userId (or nil if unowned)
	gridOwners[gridId] = ownerUserId
	print("[GridPlacementSystem] Grid ownership updated: " .. gridId .. " -> userId " .. tostring(ownerUserId))
end)

-- Function to check if a grid is owned by the local player
local function isGridOwnedByLocalPlayer(gridPart)
	if not gridPart then
		return false
	end
	local gridId = gridPart:GetFullName()
	local ownerId = gridOwners[gridId]
	return ownerId == player.UserId
end

-- ============================================================
-- UPDATED: Now returns (hitPosition, hitGridPart) instead of just position
-- OLD CODE (lines 17-33): Only returned hitPosition, used single GRID_FLOOR
-- WHY CHANGED: We need to know WHICH grid was hit to use its CFrame for snapping
-- ============================================================
local function getMouseWorldOnAnyGrid()
	local unitRay = mouse.UnitRay
	local origin = unitRay.Origin
	local direction = unitRay.Direction * 1000

	-- Refresh grid floors if cache is empty
	if #cachedGridFloors == 0 then
		refreshGridFloors()
	end

	local params = RaycastParams.new()
	-- Note: Linter may show error, but Enum.RaycastFilterType.Whitelist is valid in Roblox
	params.FilterType = Enum.RaycastFilterType.Whitelist
	params.FilterDescendantsInstances = cachedGridFloors
	params.IgnoreWater = true

	local result = workspace:Raycast(origin, direction, params)
	if result and result.Instance then
		-- Verify it's actually a Gridfloor part
		if result.Instance:IsA("BasePart") and result.Instance.Name == "Gridfloor" then
			return result.Position, result.Instance
		end
	end

	return nil, nil
end

-- RemoteEvent
local placeHelperEvent = ReplicatedStorage:WaitForChild("PlaceHelperEvent")

-- GUI
local playerGui = player:WaitForChild("PlayerGui")
local selectorGui = playerGui:WaitForChild("Spawner")
local selectorFrame = selectorGui:WaitForChild("SelectorFrame")
local selectedLabel = selectorFrame:WaitForChild("SelectedLabel")
local toggleButton = selectorGui:WaitForChild("ToggleButton")

-- Buttons
local magichoboButton = selectorFrame:WaitForChild("MagicHobo")
local appraiserButton = selectorFrame:WaitForChild("Appraiser")

-- Track current selection
local currentSelection = nil

-- Wait for workspace to be ready
task.wait(1)

-- Highlight part
local highlight = Instance.new("Part")
highlight.Name = "GridHighlight"
highlight.Size = Vector3.new(GRID_SIZE * 0.98, 0.5, GRID_SIZE * 0.98)
highlight.Anchored = true
highlight.CanCollide = false
highlight.Transparency = 0.5
highlight.Color = Color3.fromRGB(0, 255, 0) -- Green (default, will change based on ownership)
highlight.Material = Enum.Material.Neon
highlight.Parent = workspace

local selectionBox = Instance.new("SelectionBox")
selectionBox.LineThickness = 0.1
selectionBox.Color3 = Color3.fromRGB(0, 255, 0) -- Green (default, will change based on ownership)
selectionBox.Adornee = highlight
selectionBox.Parent = highlight

-- Start hidden
highlight.Transparency = 1
selectionBox.Transparency = 1

-- Current grid position and the grid part we're hovering over (stored for potential future use)
local _currentGridPosition = nil
local _currentHoveredGrid = nil
local isHighlightVisible = false

-- ============================================================
-- ADDED: Function to update highlight color based on ownership
-- WHY: Show green if owned by local player, red if not
-- ============================================================
local function updateHighlightColor(isOwned)
	if isOwned then
		-- Green for owned grid
		highlight.Color = Color3.fromRGB(0, 255, 0)
		selectionBox.Color3 = Color3.fromRGB(0, 255, 0)
	else
		-- Red for non-owned grid
		highlight.Color = Color3.fromRGB(255, 0, 0)
		selectionBox.Color3 = Color3.fromRGB(255, 0, 0)
	end
end

-- ============================================================
-- UPDATED: Now uses the specific hitGridPart's CFrame for snapping
-- OLD CODE (lines 81-109): Used hard-coded GRID_FLOOR.CFrame
-- WHY CHANGED: Each grid can be at different positions/rotations,
--   so we must use the specific grid's CFrame for accurate snapping
-- ============================================================
local function snapToGridWorld(position, hitGridPart)
	if not hitGridPart then
		return nil
	end

	-- Use the specific grid's CFrame (supports rotation/movement)
	local localPos = hitGridPart.CFrame:PointToObjectSpace(position)

	local boardX = hitGridPart.Size.X
	local boardZ = hitGridPart.Size.Z
	local halfX = boardX / 2
	local halfZ = boardZ / 2

	-- outside board
	if localPos.X < -halfX or localPos.X > halfX or localPos.Z < -halfZ or localPos.Z > halfZ then
		return nil
	end

	-- convert to cell indices
	local x01 = localPos.X + halfX
	local z01 = localPos.Z + halfZ

	local col = math.floor(x01 / GRID_SIZE) + 1
	local row = math.floor(z01 / GRID_SIZE) + 1

	-- cell center back to world using the specific grid's CFrame
	local centerX = (-halfX) + (col - 0.5) * GRID_SIZE
	local centerZ = (-halfZ) + (row - 0.5) * GRID_SIZE

	local localCenter = Vector3.new(centerX, 0, centerZ)
	local worldCenter = hitGridPart.CFrame:PointToWorldSpace(localCenter)

	return worldCenter, row, col
end

-- Function to show highlight
local function showHighlight()
	if not isHighlightVisible then
		highlight.Transparency = 0.5
		selectionBox.Transparency = 0
		isHighlightVisible = true
	end
end

-- Function to hide highlight
local function hideHighlight()
	if isHighlightVisible then
		highlight.Transparency = 1
		selectionBox.Transparency = 1
		isHighlightVisible = false
	end
end

-- Function to update button visuals
local function updateButtonSelection(selectedButton)
	-- Reset all buttons
	magichoboButton.BackgroundColor3 = Color3.fromRGB(70, 130, 180)
	appraiserButton.BackgroundColor3 = Color3.fromRGB(180, 70, 70)

	-- Highlight selected
	if selectedButton then
		selectedButton.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
	end
end

-- Button click handlers
magichoboButton.MouseButton1Click:Connect(function()
	currentSelection = "MagicHobo"
	selectedLabel.Text = "Selected: Magic Hobo (100 coins)"
	updateButtonSelection(magichoboButton)
	print("Selected: MagicHobo")
end)

appraiserButton.MouseButton1Click:Connect(function()
	currentSelection = "Appraiser"
	selectedLabel.Text = "Selected: Appraiser (150 coins)"
	updateButtonSelection(appraiserButton)
	print("Selected: Appraiser")
end)

-- Toggle button
local selectorVisible = true
toggleButton.MouseButton1Click:Connect(function()
	selectorVisible = not selectorVisible
	selectorFrame.Visible = selectorVisible
	toggleButton.Text = selectorVisible and "📦" or "📦 ▶"
end)

-- Update highlight position every frame
RunService.RenderStepped:Connect(function()
	-- If nothing selected, no highlight
	if not currentSelection then
		hideHighlight()
		_currentGridPosition = nil
		_currentHoveredGrid = nil
		return
	end

	-- Use raycast so we always "hit" a grid floor
	local hitPosition, hitGridPart = getMouseWorldOnAnyGrid()
	if not hitPosition or not hitGridPart then
		hideHighlight()
		_currentGridPosition = nil
		_currentHoveredGrid = nil
		return
	end

	-- Snap the ray hit to a cell center using the specific grid
	local snappedWorld = snapToGridWorld(hitPosition, hitGridPart)
	if snappedWorld then
		-- ============================================================
		-- ADDED: Check ownership and update highlight color
		-- WHY: Show green if owned by local player, red if not
		-- ============================================================
		local isOwned = isGridOwnedByLocalPlayer(hitGridPart)
		updateHighlightColor(isOwned)
		
		-- ============================================================
		-- UPDATED: Use hitGridPart's Position/Size for highlight Y
		-- OLD CODE (line 184): Used hard-coded GRID_FLOOR.Position.Y
		-- WHY CHANGED: Each grid can be at different heights,
		--   so we must use the specific grid's position
		-- ============================================================
		local floorY = hitGridPart.Position.Y + (hitGridPart.Size.Y / 2)
		highlight.Position = Vector3.new(snappedWorld.X, floorY + 0.25, snappedWorld.Z)
		showHighlight()
		_currentGridPosition = snappedWorld
		_currentHoveredGrid = hitGridPart
	else
		hideHighlight()
		_currentGridPosition = nil
		_currentHoveredGrid = nil
	end
end)

-- ============================================================
-- FIXED: RemoteEvent argument order to match server expectations
-- OLD CODE (line 206): placeHelperEvent:FireServer(snappedWorld, currentSelection)
-- NEW CODE: FireServer(hitGridPart, snappedWorldPos, helperName)
-- WHY CHANGED: Server expects (player, hitGrid, worldPosition, helperName)
--   but FireServer automatically adds player as first arg, so we send:
--   (hitGridPart, snappedWorldPos, helperName)
-- ============================================================
-- ============================================================
-- UPDATED: Added ownership check before firing server
-- WHY: Block placement attempts on non-owned grids client-side
--   (server will also validate, but this prevents unnecessary network calls)
-- ============================================================
mouse.Button1Down:Connect(function()
	if not currentSelection then return end

	local hitPosition, hitGridPart = getMouseWorldOnAnyGrid()
	if not hitPosition or not hitGridPart then return end

	-- ============================================================
	-- ADDED: Client-side ownership check
	-- WHY: Block placement on grids not owned by local player
	-- ============================================================
	if not isGridOwnedByLocalPlayer(hitGridPart) then
		print("[GridPlacementSystem] ❌ Cannot place: Grid not owned by local player")
		return
	end

	local snappedWorld = snapToGridWorld(hitPosition, hitGridPart)
	if not snappedWorld then return end

	print("Placing " .. currentSelection .. " at: " .. tostring(snappedWorld) .. " on grid: " .. hitGridPart:GetFullName())
	-- Fixed argument order: (hitGridPart, snappedWorldPos, helperName)
	placeHelperEvent:FireServer(hitGridPart, snappedWorld, currentSelection)
end)

print("✅ Grid placement system loaded! (Multi-grid support + Island ownership enabled)")
