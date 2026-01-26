-- HelperPlacementUI.luau - Auto-Chess/MOBA style horizontal shop bar
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local React = require(ReplicatedStorage.Packages.React)

local player = Players.LocalPlayer
local mouse = player:GetMouse()

-- Constants
local GRID_SIZE = 5
local SLOTS_VISIBLE = 6
local SLOT_WIDTH = 140
local SLOT_HEIGHT = 180

-- Ultra-Cool Rarity Color Themes (NO STARS)
local RARITY_COLORS = {
	-- Common — Cold Steel
	Common = {
		primary = Color3.fromHex("#E3E8F0"),
		secondary = Color3.fromHex("#B9C3D6"),
		shadow = Color3.fromHex("#6F7C96"),
	},
	-- Uncommon — Arctic Mint
	Uncommon = {
		primary = Color3.fromHex("#4DFFE3"),
		secondary = Color3.fromHex("#2DDDCB"),
		shadow = Color3.fromHex("#0E6F6A"),
	},
	-- Rare — Ice Blue
	Rare = {
		primary = Color3.fromHex("#5CBFFF"),
		secondary = Color3.fromHex("#2D8CFF"),
		shadow = Color3.fromHex("#0D3F8C"),
	},
	-- Epic — Arcane Violet
	Epic = {
		primary = Color3.fromHex("#9A86FF"),
		secondary = Color3.fromHex("#6B4BFF"),
		shadow = Color3.fromHex("#2A157A"),
	},
	-- Legendary — Celestial Gold
	Legendary = {
		primary = Color3.fromHex("#FFF1C1"),
		secondary = Color3.fromHex("#FFD97A"),
		shadow = Color3.fromHex("#8A6A1E"),
	},
	-- Mythic — Void Crimson
	Mythic = {
		primary = Color3.fromHex("#FF6E7A"),
		secondary = Color3.fromHex("#FF3B5C"),
		shadow = Color3.fromHex("#6F0D1F"),
	},
}

-- Helper rarity mapping (assign rarities to helpers)
local HELPER_RARITIES = {
	-- Default to Common if not specified
	Appraiser = "Common",
	Indigenous = "Uncommon",
	MagicHobo = "Rare",
	MuscularHobo = "Uncommon",
	Thrower = "Epic",
	Tweaker = "Legendary",
}

-- Get rarity colors for a helper
local function getRarityColors(helperName)
	local rarityName = HELPER_RARITIES[helperName] or "Common"
	return RARITY_COLORS[rarityName] or RARITY_COLORS.Common
end

-- Grid ownership tracking
local gridOwners = {} -- gridId (string) -> ownerUserId

-- Find all Gridfloor parts
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

-- Cache grid floors
local cachedGridFloors = {}
local function refreshGridFloors()
	cachedGridFloors = getAllGridFloors()
end
refreshGridFloors()

-- Refresh every 5 seconds
task.spawn(function()
	while true do
		task.wait(5)
		refreshGridFloors()
	end
end)

-- Listen to GridOwnershipEvent
local gridOwnershipEvent = ReplicatedStorage:FindFirstChild("GridOwnershipEvent")
if gridOwnershipEvent then
	gridOwnershipEvent.OnClientEvent:Connect(function(gridId, ownerUserId)
		gridOwners[gridId] = ownerUserId
	end)
end

-- Check if grid is owned by local player
local function isGridOwnedByLocalPlayer(gridPart)
	if not gridPart then
		return false
	end
	local gridId = gridPart:GetFullName()
	local ownerId = gridOwners[gridId]
	return ownerId == player.UserId
end

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

-- Snap to grid
local function snapToGridWorld(position, hitGridPart)
	if not hitGridPart then
		return nil
	end

	local localPos = hitGridPart.CFrame:PointToObjectSpace(position)
	local boardX = hitGridPart.Size.X
	local boardZ = hitGridPart.Size.Z
	local halfX = boardX / 2
	local halfZ = boardZ / 2

	if localPos.X < -halfX or localPos.X > halfX or localPos.Z < -halfZ or localPos.Z > halfZ then
		return nil
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

-- RemoteEvents
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local requestBuyHelper = remotes:WaitForChild("RequestBuyHelper")
local requestPlaceHelper = remotes:WaitForChild("RequestPlaceHelper")
local helperResponse = remotes:WaitForChild("HelperResponse")

	-- Global state
	_G.HelperPlacementData = _G.HelperPlacementData or {
		availableHelpers = {}, -- {name, cost, owned}
		selectedHelper = nil,
		isPlacing = false,
		statusText = "Loading...",
		statusColor = Color3.fromRGB(200, 200, 200),
		isVisible = true,
		isMinimized = false,
		updateTime = 0,
		currentPage = 1,
	}

-- Get helpers list from server
local function requestHelpersList()
	print("[HelperPlacementUI] Requesting helpers list...")
	requestBuyHelper:FireServer("GetHelpersList")
end

-- Listen for helpers list response
helperResponse.OnClientEvent:Connect(function(action, data)
	if action == "HelpersList" then
		_G.HelperPlacementData.availableHelpers = data.helpers or {}
		_G.HelperPlacementData.statusText = "Select a helper, then click on a grid to place it"
		_G.HelperPlacementData.updateTime = tick()
		print("[HelperPlacementUI] Loaded helper list: " .. #_G.HelperPlacementData.availableHelpers)
	elseif action == "PlaceResult" then
		if data.success then
			_G.HelperPlacementData.statusText = "Placed " .. (data.helperName or "") .. "!"
			_G.HelperPlacementData.statusColor = Color3.fromRGB(100, 255, 100)
			_G.HelperPlacementData.isPlacing = false
			_G.HelperPlacementData.selectedHelper = nil
		else
			_G.HelperPlacementData.statusText = data.message or "Placement failed"
			_G.HelperPlacementData.statusColor = Color3.fromRGB(255, 100, 100)
		end
		_G.HelperPlacementData.updateTime = tick()
	end
end)

-- Initialize helpers list
task.spawn(function()
	task.wait(1)
	requestHelpersList()
end)

-- Handle helper selection
local function selectHelper(helperName)
	_G.HelperPlacementData.selectedHelper = helperName
	_G.HelperPlacementData.isPlacing = true
	_G.HelperPlacementData.statusText = "Selected: " .. helperName .. " - Click on grid to place"
	_G.HelperPlacementData.statusColor = Color3.fromRGB(100, 255, 100)
	_G.HelperPlacementData.updateTime = tick()
	print("[HelperPlacementUI] Selected helper: " .. helperName)
end

-- Buy function removed - helpers are now free to place

-- Handle mouse click for placement
local function onMouseClick()
	if not _G.HelperPlacementData.isPlacing or not _G.HelperPlacementData.selectedHelper then
		return
	end
	
	local hitPosition, hitGridPart = getMouseWorldOnAnyGrid()
	if not hitPosition or not hitGridPart then
		_G.HelperPlacementData.statusText = "No grid found - click on a grid floor"
		_G.HelperPlacementData.statusColor = Color3.fromRGB(255, 100, 100)
		_G.HelperPlacementData.updateTime = tick()
		return
	end
	
	if not isGridOwnedByLocalPlayer(hitGridPart) then
		_G.HelperPlacementData.statusText = "This grid belongs to another player!"
		_G.HelperPlacementData.statusColor = Color3.fromRGB(255, 100, 100)
		_G.HelperPlacementData.updateTime = tick()
		return
	end
	
	local snappedWorld, row, col = snapToGridWorld(hitPosition, hitGridPart)
	if not snappedWorld or not row or not col then
		_G.HelperPlacementData.statusText = "Invalid grid position"
		_G.HelperPlacementData.statusColor = Color3.fromRGB(255, 100, 100)
		_G.HelperPlacementData.updateTime = tick()
		return
	end
	
	-- Check if row is on player side (1-5 only)
	local PLAYER_MIN_ROW, PLAYER_MAX_ROW = 1, 5
	if row < PLAYER_MIN_ROW or row > PLAYER_MAX_ROW then
		_G.HelperPlacementData.statusText = "Can't place on enemy side"
		_G.HelperPlacementData.statusColor = Color3.fromRGB(255, 100, 100)
		_G.HelperPlacementData.updateTime = tick()
		return
	end
	
	print("[HelperPlacementUI] Place request fired: " .. _G.HelperPlacementData.selectedHelper)
	requestPlaceHelper:FireServer(_G.HelperPlacementData.selectedHelper, CFrame.new(snappedWorld))
end

-- Keyboard toggles
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	
	if input.KeyCode == Enum.KeyCode.B then
		_G.HelperPlacementData.isVisible = not _G.HelperPlacementData.isVisible
		_G.HelperPlacementData.updateTime = tick()
		print("[HelperPlacementUI] Helper bar " .. (_G.HelperPlacementData.isVisible and "opened" or "closed"))
	elseif input.KeyCode == Enum.KeyCode.Escape then
		_G.HelperPlacementData.isVisible = false
		_G.HelperPlacementData.updateTime = tick()
		print("[HelperPlacementUI] Helper bar closed via Esc")
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
		onMouseClick()
	end
end)

-- Create highlight for grid placement preview
task.spawn(function()
	local highlight = Instance.new("Part")
	highlight.Name = "HelperPlacementHighlight"
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
	
	highlight.Transparency = 1
	selectionBox.Transparency = 1
	
	RunService.RenderStepped:Connect(function()
		if not _G.HelperPlacementData.isPlacing or not _G.HelperPlacementData.selectedHelper then
			highlight.Transparency = 1
			selectionBox.Transparency = 1
			return
		end
		
		local hitPosition, hitGridPart = getMouseWorldOnAnyGrid()
		if not hitPosition or not hitGridPart then
			highlight.Transparency = 1
			selectionBox.Transparency = 1
			return
		end
		
		local isOwned = isGridOwnedByLocalPlayer(hitGridPart)
		local snappedWorld, row, _col = snapToGridWorld(hitPosition, hitGridPart)
		
		-- Check if row is valid (1-5 for player side)
		local PLAYER_MIN_ROW, PLAYER_MAX_ROW = 1, 5
		local isValidRow = row and row >= PLAYER_MIN_ROW and row <= PLAYER_MAX_ROW
		
		-- Set highlight color based on ownership AND row validity
		if isOwned and isValidRow then
			highlight.Color = Color3.fromRGB(0, 255, 0)
			selectionBox.Color3 = Color3.fromRGB(0, 255, 0)
		else
			highlight.Color = Color3.fromRGB(255, 0, 0)
			selectionBox.Color3 = Color3.fromRGB(255, 0, 0)
		end
		
		-- Update status text
		if not isOwned then
			_G.HelperPlacementData.statusText = "This grid belongs to another player!"
			_G.HelperPlacementData.statusColor = Color3.fromRGB(255, 100, 100)
		elseif not isValidRow then
			_G.HelperPlacementData.statusText = "Can't place on enemy side"
			_G.HelperPlacementData.statusColor = Color3.fromRGB(255, 100, 100)
		else
			_G.HelperPlacementData.statusText = "Click to place"
			_G.HelperPlacementData.statusColor = Color3.fromRGB(200, 200, 200)
		end
		
		if snappedWorld then
			local floorY = hitGridPart.Position.Y + (hitGridPart.Size.Y / 2)
			highlight.Position = Vector3.new(snappedWorld.X, floorY + 0.25, snappedWorld.Z)
			highlight.Transparency = 0.5
			selectionBox.Transparency = 0
		else
			highlight.Transparency = 1
			selectionBox.Transparency = 1
		end
	end)
end)

-- Setup ViewportFrame with 3D model
local function setupViewport(viewportFrame, helperName)
	-- Check if already set up (prevent React re-render issues)
	if viewportFrame:GetAttribute("Ready") then
		return
	end
	
	print("[HelperPlacementUI] Setting up viewport for: " .. helperName)
	
	-- Get rarity colors for rim lighting
	local rarityColors = getRarityColors(helperName)
	local primaryColor = rarityColors.primary
	local secondaryColor = rarityColors.secondary
	
	-- Clean up existing content (only known names, not all Models/Parts)
	for _, child in ipairs(viewportFrame:GetChildren()) do
		if child.Name == "ViewportCamera" or child.Name == "ViewportLight" or child.Name == "TopLight" or child:IsA("Model") then
			child:Destroy()
		end
	end
	
	-- Get display model from ReplicatedStorage
	local displayFolder = ReplicatedStorage:FindFirstChild("HelperDisplayTemplates")
	if not displayFolder then
		warn("[HelperPlacementUI] ❌ HelperDisplayTemplates folder not found in ReplicatedStorage")
		return
	end
	
	print("[HelperPlacementUI] Found HelperDisplayTemplates folder, looking for: " .. helperName)
	
	local template = displayFolder:FindFirstChild(helperName)
	if not template then
		warn("[HelperPlacementUI] ❌ Display template not found: " .. helperName)
		local available = {}
		for _, child in ipairs(displayFolder:GetChildren()) do
			table.insert(available, child.Name)
		end
		warn("[HelperPlacementUI] Available templates: " .. table.concat(available, ", "))
		return
	end
	
	print("[HelperPlacementUI] ✅ Found template: " .. helperName)
	
	-- Clone model for viewport
	local model = template:Clone()
	local modelToShow = model
	
	-- Handle folders
	if model:IsA("Folder") then
		modelToShow = model:FindFirstChildOfClass("Model")
		if not modelToShow then
			warn("[HelperPlacementUI] No model found in folder: " .. helperName)
			model:Destroy()
			return
		end
	end
	
	-- Set PrimaryPart if missing (for proper bounding box)
	if not modelToShow.PrimaryPart then
		local hrp = modelToShow:FindFirstChild("HumanoidRootPart", true)
		if hrp then
			modelToShow.PrimaryPart = hrp
		end
	end
	
	-- Parent model to viewport FIRST
	modelToShow.Parent = viewportFrame
	
	-- Pivot model to origin for consistent viewport positioning
	modelToShow:PivotTo(CFrame.new(0, 0, 0))
	
	print("[HelperPlacementUI] ✅ Model to show: " .. modelToShow.Name)
	
	-- Wait a frame for model to load
	task.wait(0.1)
	
	-- Create camera
	local camera = Instance.new("Camera")
	camera.Name = "ViewportCamera"
	camera.Parent = viewportFrame
	viewportFrame.CurrentCamera = camera
	
	-- Get bounding box and center camera
	local success, cf, size = pcall(function()
		return modelToShow:GetBoundingBox()
	end)
	
	if not success or not cf or not size then
		warn("[HelperPlacementUI] ❌ Failed to get bounding box for: " .. helperName)
		return
	end
	
	local center = cf.Position
	print("[HelperPlacementUI] Model center: " .. tostring(center) .. ", size: " .. tostring(size))
	
	-- Calculate camera distance to fit model (CLOSER - was 2.5, now 1.4)
	local maxSize = math.max(size.X, size.Y, size.Z)
	local distance = maxSize * 1.4
	
	-- Position camera to look at model center (closer angle)
	camera.CFrame = CFrame.lookAt(center + Vector3.new(distance, distance * 0.4, distance), center)
	
	-- Add lighting to viewport (CRITICAL for models to be visible)
	-- Create a light part that follows the camera
	local lightPart = Instance.new("Part")
	lightPart.Name = "ViewportLight"
	lightPart.Size = Vector3.new(0.1, 0.1, 0.1)
	lightPart.Transparency = 1
	lightPart.Anchored = true
	lightPart.CanCollide = false
	lightPart.Parent = viewportFrame
	
	-- Add PointLight to the light part (with subtle rarity tint)
	local light = Instance.new("PointLight")
	light.Brightness = 5
	light.Range = 200
	-- Subtle rarity color tint (blend with white for restrained effect)
	light.Color = Color3.new(
		(primaryColor.R + 1) / 2,
		(primaryColor.G + 1) / 2,
		(primaryColor.B + 1) / 2
	)
	light.Shadows = false
	light.Parent = lightPart
	
	-- Position light near the camera
	lightPart.CFrame = camera.CFrame
	
	-- Update light position as camera rotates
	task.spawn(function()
		while modelToShow.Parent == viewportFrame and lightPart.Parent do
			lightPart.CFrame = camera.CFrame
			task.wait(0.1)
		end
	end)
	
	-- Add additional ambient light from above (with rarity secondary color)
	local topLight = Instance.new("Part")
	topLight.Name = "TopLight"
	topLight.Size = Vector3.new(0.1, 0.1, 0.1)
	topLight.Transparency = 1
	topLight.Anchored = true
	topLight.CanCollide = false
	topLight.Parent = viewportFrame
	
	local topPointLight = Instance.new("PointLight")
	topPointLight.Brightness = 3
	topPointLight.Range = 200
	-- Subtle rarity secondary color tint
	topPointLight.Color = Color3.new(
		(secondaryColor.R + 1) / 2,
		(secondaryColor.G + 1) / 2,
		(secondaryColor.B + 1) / 2
	)
	topPointLight.Shadows = false
	topPointLight.Parent = topLight
	
	-- Position light above the model
	topLight.CFrame = CFrame.new(center + Vector3.new(0, distance * 1.5, 0))
	
	-- Note: Rim lighting on model parts is handled via the colored PointLights above
	-- The subtle rarity color tint in the lights creates the restrained aura effect
	
	print("[HelperPlacementUI] ✅ Lighting added")
	
	-- Rotation animation (faster rotation)
	task.spawn(function()
		local rotation = 0
		local offset = Vector3.new(distance, distance * 0.4, distance)
		
		while modelToShow.Parent == viewportFrame and viewportFrame.Parent do
			rotation = (rotation + 1.5) % 360 -- Faster: 1.5 degrees per frame (was 0.15)
			local rot = CFrame.Angles(0, math.rad(rotation), 0)
			local camPos = center + rot:VectorToWorldSpace(offset)
			
			camera.CFrame = CFrame.lookAt(camPos, center)
			-- Update light position
			if lightPart.Parent then
				lightPart.CFrame = camera.CFrame
			end
			task.wait(0.05)
		end
	end)
	
	-- Mark as ready (prevent re-setup on React re-renders)
	viewportFrame:SetAttribute("Ready", true)
	
	print("[HelperPlacementUI] ✅ Viewport fully set up for " .. helperName)
end

-- HelperPlacementUI React Component
local function HelperPlacementUI()
	-- Get current state from global
	local data = _G.HelperPlacementData or {}
	local availableHelpers = data.availableHelpers or {}
	local selectedHelper = data.selectedHelper
	local isVisible = data.isVisible ~= false
	local isMinimized = data.isMinimized or false
	local currentPage = data.currentPage or 1
	
	-- Don't render if not visible
	if not isVisible then
		return nil
	end
	
	-- Calculate pagination
	local totalHelpers = #availableHelpers
	local totalPages = math.ceil(totalHelpers / SLOTS_VISIBLE)
	local startIndex = (currentPage - 1) * SLOTS_VISIBLE + 1
	local endIndex = math.min(startIndex + SLOTS_VISIBLE - 1, totalHelpers)
	local visibleHelpers = {}
	
	for i = startIndex, endIndex do
		if availableHelpers[i] then
			table.insert(visibleHelpers, availableHelpers[i])
		end
	end
	
	-- Create helper slot items
	local slotItems = {}
	for i, helperData in ipairs(visibleHelpers) do
		local helperName = helperData.name or helperData
		local isSelected = selectedHelper == helperName
		
		-- Get rarity colors (ultra-cool theme)
		local rarityColors = getRarityColors(helperName)
		local primaryColor = rarityColors.primary
		local secondaryColor = rarityColors.secondary
		local shadowColor = rarityColors.shadow
		
		-- Create viewport frame name for later lookup
		local viewportName = "Viewport_" .. helperName .. "_" .. i
		
		slotItems[i] = React.createElement("Frame", {
			Size = UDim2.new(0, SLOT_WIDTH, 0, SLOT_HEIGHT),
			BackgroundColor3 = Color3.fromRGB(25, 25, 30),
			BorderSizePixel = 0,
			LayoutOrder = i,
		}, {
			UICorner = React.createElement("UICorner", {
				CornerRadius = UDim.new(0, 8),
			}),
			
			-- Gradient background with rarity accent (subtle)
			BackgroundGradient = React.createElement("UIGradient", {
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(35, 35, 45)),
					ColorSequenceKeypoint.new(0.5, Color3.fromRGB(25, 25, 30)),
					ColorSequenceKeypoint.new(1, shadowColor), -- Subtle rarity shadow at bottom
				}),
				Rotation = 45,
			}),
			
			-- Rarity indicator stripe (top accent)
			RarityStripe = React.createElement("Frame", {
				Size = UDim2.new(1, 0, 0, 3),
				Position = UDim2.new(0, 0, 0, 0),
				BackgroundColor3 = primaryColor,
				BorderSizePixel = 0,
			}, {
				UICorner = React.createElement("UICorner", {
					CornerRadius = UDim.new(0, 8),
				}),
				StripeGradient = React.createElement("UIGradient", {
					Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, primaryColor),
						ColorSequenceKeypoint.new(1, secondaryColor),
					}),
				}),
			}),
			
			-- Subtle rarity outline (rim light effect)
			RarityOutline = React.createElement("UIStroke", {
				Color = primaryColor,
				Thickness = isSelected and 2.5 or 1.5,
				Transparency = isSelected and 0.4 or 0.7, -- Brighter when selected
			}),
			
			-- Selection border (uses rarity color when selected)
			SelectionBorder = isSelected and React.createElement("UIStroke", {
				Color = secondaryColor,
				Thickness = 2,
				Transparency = 0.3,
			}) or nil,
			
			-- ViewportFrame for 3D model with rarity-colored border (rim light)
			ViewportContainer = React.createElement("Frame", {
				Size = UDim2.new(1, -10, 0, 100),
				Position = UDim2.new(0, 5, 0, 8),
				BackgroundColor3 = Color3.fromRGB(15, 15, 20),
				BorderSizePixel = 0,
				Name = viewportName .. "_Container",
			}, {
				UICorner = React.createElement("UICorner", {
					CornerRadius = UDim.new(0, 6),
				}),
				ViewportGradient = React.createElement("UIGradient", {
					Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, Color3.fromRGB(20, 20, 30)),
						ColorSequenceKeypoint.new(0.5, Color3.fromRGB(15, 15, 20)),
						ColorSequenceKeypoint.new(1, shadowColor), -- Subtle rarity shadow
					}),
					Rotation = 135,
				}),
				-- Rarity-colored rim light border (soft aura effect)
				ViewportBorder = React.createElement("UIStroke", {
					Color = primaryColor,
					Thickness = 1.5,
					Transparency = 0.6, -- Soft, restrained glow
				}),
				Viewport = React.createElement("ViewportFrame", {
					Size = UDim2.new(1, -4, 1, -4),
					Position = UDim2.new(0, 2, 0, 2),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Name = "Viewport", -- Fixed: Use consistent name
				}),
			}),
			
			-- Helper name
			HelperName = React.createElement("TextLabel", {
				Size = UDim2.new(1, -10, 0, 20),
				Position = UDim2.new(0, 5, 0, 110),
				BackgroundTransparency = 1,
				Text = helperName,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 14,
				Font = Enum.Font.GothamBold,
				TextXAlignment = Enum.TextXAlignment.Center,
			}),
			
			-- Select button with gradient (no cost, free to place)
			ActionButton = React.createElement("TextButton", {
				Size = UDim2.new(1, -10, 0, 32),
				Position = UDim2.new(0, 5, 1, -38),
				BackgroundColor3 = isSelected and Color3.fromRGB(100, 200, 100) or Color3.fromRGB(50, 150, 50),
				BorderSizePixel = 0,
				Text = isSelected and "Selected" or "Select",
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 13,
				Font = Enum.Font.GothamBold,
				AutoButtonColor = false,
				[React.Event.Activated] = function()
					selectHelper(helperName)
				end,
			}, {
				UICorner = React.createElement("UICorner", {
					CornerRadius = UDim.new(0, 4),
				}),
				ButtonGradient = React.createElement("UIGradient", {
					Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, isSelected and Color3.fromRGB(120, 220, 120) or Color3.fromRGB(70, 170, 70)),
						ColorSequenceKeypoint.new(1, isSelected and Color3.fromRGB(80, 180, 80) or Color3.fromRGB(30, 130, 30)),
					}),
				}),
				ButtonStroke = React.createElement("UIStroke", {
					Color = Color3.fromRGB(150, 255, 150),
					Thickness = 1.5,
					Transparency = isSelected and 0.3 or 0.7,
				}),
			}),
		})
	end
	
	-- Calculate bar width and height (minimized state)
	local barWidth = math.min(SLOTS_VISIBLE, #visibleHelpers) * SLOT_WIDTH + 20 + (totalPages > 1 and 80 or 0)
	local barHeight = isMinimized and 50 or (SLOT_HEIGHT + 20)
	local barYOffset = isMinimized and -60 or (-SLOT_HEIGHT - 30)
	
	local mainFrame = React.createElement("Frame", {
		Size = UDim2.new(0, barWidth, 0, barHeight),
		Position = UDim2.new(0.5, 0, 1, barYOffset),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Color3.fromRGB(20, 20, 25),
		BorderSizePixel = 0,
		Name = "HelperShopBar",
	}, {
		UICorner = React.createElement("UICorner", {
			CornerRadius = UDim.new(0, 12),
		}),
		
		-- Main gradient background
		BackgroundGradient = React.createElement("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 30, 40)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(20, 20, 25)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(15, 15, 20)),
			}),
			Rotation = 45,
		}),
		
		-- Main border with gradient effect
		Border = React.createElement("UIStroke", {
			Color = Color3.fromRGB(80, 100, 120),
			Thickness = 2,
			Transparency = 0.3,
		}),
		
		-- Minimize button
		MinimizeButton = React.createElement("TextButton", {
			Size = UDim2.new(0, 30, 0, 30),
			Position = UDim2.new(1, -70, 0, 5),
			BackgroundColor3 = Color3.fromRGB(60, 100, 150),
			BorderSizePixel = 0,
			Text = isMinimized and "▲" or "▼",
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextSize = 16,
			Font = Enum.Font.GothamBold,
			AutoButtonColor = false,
			[React.Event.Activated] = function()
				_G.HelperPlacementData.isMinimized = not _G.HelperPlacementData.isMinimized
				_G.HelperPlacementData.updateTime = tick()
				print("[HelperPlacementUI] UI " .. (_G.HelperPlacementData.isMinimized and "minimized" or "expanded"))
			end,
		}, {
			UICorner = React.createElement("UICorner", {
				CornerRadius = UDim.new(0, 6),
			}),
			MinimizeGradient = React.createElement("UIGradient", {
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 120, 170)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 80, 130)),
				}),
			}),
		}),
		
		-- Close button (X)
		CloseButton = React.createElement("TextButton", {
			Size = UDim2.new(0, 30, 0, 30),
			Position = UDim2.new(1, -35, 0, 5),
			BackgroundColor3 = Color3.fromRGB(200, 50, 50),
			BorderSizePixel = 0,
			Text = "×",
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextSize = 20,
			Font = Enum.Font.GothamBold,
			AutoButtonColor = false,
			[React.Event.Activated] = function()
				_G.HelperPlacementData.isVisible = false
				_G.HelperPlacementData.updateTime = tick()
				print("[HelperPlacementUI] ✅ UI closed")
			end,
		}, {
			UICorner = React.createElement("UICorner", {
				CornerRadius = UDim.new(0, 6),
			}),
			CloseGradient = React.createElement("UIGradient", {
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(220, 70, 70)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 30, 30)),
				}),
			}),
		}),
		
		-- Left arrow (if more than 1 page and not minimized)
		LeftArrow = not isMinimized and totalPages > 1 and currentPage > 1 and React.createElement("TextButton", {
			Size = UDim2.new(0, 35, 0, SLOT_HEIGHT),
			Position = UDim2.new(0, 5, 0, 10),
			BackgroundColor3 = Color3.fromRGB(40, 40, 50),
			BorderSizePixel = 0,
			Text = "◀",
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextSize = 24,
			Font = Enum.Font.GothamBold,
			AutoButtonColor = false,
			[React.Event.Activated] = function()
				_G.HelperPlacementData.currentPage = math.max(1, currentPage - 1)
				_G.HelperPlacementData.updateTime = tick()
			end,
		}, {
			UICorner = React.createElement("UICorner", {
				CornerRadius = UDim.new(0, 6),
			}),
			ArrowGradient = React.createElement("UIGradient", {
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(60, 60, 70)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 30, 40)),
				}),
			}),
		}) or nil,
		
		-- Slots container (hidden when minimized)
		SlotsContainer = not isMinimized and React.createElement("Frame", {
			Size = UDim2.new(1, totalPages > 1 and -90 or -20, 0, SLOT_HEIGHT),
			Position = UDim2.new(0, totalPages > 1 and 45 or 10, 0, 10),
			BackgroundTransparency = 1,
		}, {
			UIListLayout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		}, slotItems) or nil,
		
		-- Right arrow (if more than 1 page and not minimized)
		RightArrow = not isMinimized and totalPages > 1 and currentPage < totalPages and React.createElement("TextButton", {
			Size = UDim2.new(0, 35, 0, SLOT_HEIGHT),
			Position = UDim2.new(1, -40, 0, 10),
			BackgroundColor3 = Color3.fromRGB(40, 40, 50),
			BorderSizePixel = 0,
			Text = "▶",
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextSize = 24,
			Font = Enum.Font.GothamBold,
			AutoButtonColor = false,
			[React.Event.Activated] = function()
				_G.HelperPlacementData.currentPage = math.min(totalPages, currentPage + 1)
				_G.HelperPlacementData.updateTime = tick()
			end,
		}, {
			UICorner = React.createElement("UICorner", {
				CornerRadius = UDim.new(0, 6),
			}),
			ArrowGradient = React.createElement("UIGradient", {
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(60, 60, 70)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 30, 40)),
				}),
			}),
		}) or nil,
	})
	
	-- Setup viewports after render (using a hook-like approach)
	task.spawn(function()
		task.wait(0.2) -- Wait for React to create the UI
		local playerGui = player:FindFirstChild("PlayerGui")
		if not playerGui then return end
		
		local reactGui = playerGui:FindFirstChild("React")
		if not reactGui then return end
		
		local shopBar = reactGui:FindFirstChild("HelperShopBar", true)
		if not shopBar then return end
		
		-- Setup viewports for visible helpers (use the same visibleHelpers array)
		for i, helperData in ipairs(visibleHelpers) do
			local helperName = helperData.name or helperData
			local viewportName = "Viewport_" .. helperName .. "_" .. i
			local viewportContainer = shopBar:FindFirstChild(viewportName .. "_Container", true)
			
			if not viewportContainer then
				warn("[HelperPlacementUI] Viewport container not found: " .. viewportName .. "_Container")
			else
				-- Find the nested ViewportFrame inside the container
				local viewport = viewportContainer:FindFirstChild("Viewport")
				
				if not viewport then
					warn("[HelperPlacementUI] ViewportFrame not found in container for: " .. helperName)
				elseif viewport:IsA("ViewportFrame") then
					-- Check if already set up
					if not viewport:FindFirstChildOfClass("Camera") then
						print("[HelperPlacementUI] Setting up viewport for: " .. helperName)
						setupViewport(viewport, helperName)
					else
						print("[HelperPlacementUI] Viewport already set up for: " .. helperName)
					end
				else
					warn("[HelperPlacementUI] Found 'Viewport' but it's not a ViewportFrame: " .. tostring(viewport.ClassName))
				end
			end
		end
	end)
	
	return mainFrame
end

return HelperPlacementUI
