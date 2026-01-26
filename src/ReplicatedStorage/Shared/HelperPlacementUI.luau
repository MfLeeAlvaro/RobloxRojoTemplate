-- HelperPlacementUI.luau - React component for helper placement
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local React = require(ReplicatedStorage.Packages.React)

local player = Players.LocalPlayer
local mouse = player:GetMouse()

-- Constants
local GRID_SIZE = 5

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
local gridOwnershipEvent = ReplicatedStorage:WaitForChild("GridOwnershipEvent")
gridOwnershipEvent.OnClientEvent:Connect(function(gridId, ownerUserId)
	gridOwners[gridId] = ownerUserId
end)

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

-- RemoteEvent
local placeHelperEvent = ReplicatedStorage:WaitForChild("PlaceHelperEvent")

-- Global state (like ShopUI pattern)
_G.HelperPlacementData = _G.HelperPlacementData or {
	availableHelpers = {},
	selectedHelper = nil,
	isPlacing = false,
	statusText = "Loading...",
	statusColor = Color3.fromRGB(200, 200, 200),
	isVisible = true,
	updateTime = 0,
}

-- Get helpers list
local function getHelpersList()
	local helperShopEvent = ReplicatedStorage:FindFirstChild("HelperShopEvent")
	if helperShopEvent then
		local received = false
		local helpers = {}
		
		local connection
		connection = helperShopEvent.OnClientEvent:Connect(function(action, data)
			if action == "HelpersList" then
				helpers = data.helpers or {}
				received = true
				if connection then connection:Disconnect() end
			end
		end)
		
		helperShopEvent:FireServer("RequestHelpers")
		
		local startTime = tick()
		while not received and (tick() - startTime) < 2 do
			task.wait(0.1)
		end
		
		if #helpers > 0 then
			return helpers
		end
	end
	
	return {"Appraiser", "Indigenous", "MagicHobo", "MuscularHobo", "Thrower", "Tweaker"}
end

-- Initialize helpers list
task.spawn(function()
	task.wait(1)
	_G.HelperPlacementData.availableHelpers = getHelpersList()
	_G.HelperPlacementData.statusText = "Select a helper, then click on a grid to place it"
	_G.HelperPlacementData.updateTime = tick()
end)

-- Listen for placement results
placeHelperEvent.OnClientEvent:Connect(function(success, message)
	if success then
		_G.HelperPlacementData.statusText = "Placed " .. (_G.HelperPlacementData.selectedHelper or "") .. "!"
		_G.HelperPlacementData.statusColor = Color3.fromRGB(100, 255, 100)
		_G.HelperPlacementData.isPlacing = false
		_G.HelperPlacementData.selectedHelper = nil
	else
		_G.HelperPlacementData.statusText = message or "Placement failed"
		_G.HelperPlacementData.statusColor = Color3.fromRGB(255, 100, 100)
	end
	_G.HelperPlacementData.updateTime = tick()
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
	
	local snappedWorld = snapToGridWorld(hitPosition, hitGridPart)
	if not snappedWorld then
		_G.HelperPlacementData.statusText = "Invalid grid position"
		_G.HelperPlacementData.statusColor = Color3.fromRGB(255, 100, 100)
		_G.HelperPlacementData.updateTime = tick()
		return
	end
	
	print("[HelperPlacementUI] Placing " .. _G.HelperPlacementData.selectedHelper .. " at " .. tostring(snappedWorld))
	placeHelperEvent:FireServer(hitGridPart, snappedWorld, _G.HelperPlacementData.selectedHelper)
end

-- Keyboard toggles
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	
	if input.KeyCode == Enum.KeyCode.B then
		_G.HelperPlacementData.isVisible = not _G.HelperPlacementData.isVisible
		_G.HelperPlacementData.updateTime = tick()
		print("[HelperPlacementUI] UI toggled via B key: " .. tostring(_G.HelperPlacementData.isVisible))
	elseif input.KeyCode == Enum.KeyCode.Escape then
		_G.HelperPlacementData.isVisible = false
		_G.HelperPlacementData.updateTime = tick()
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
		if isOwned then
			highlight.Color = Color3.fromRGB(0, 255, 0)
			selectionBox.Color3 = Color3.fromRGB(0, 255, 0)
		else
			highlight.Color = Color3.fromRGB(255, 0, 0)
			selectionBox.Color3 = Color3.fromRGB(255, 0, 0)
		end
		
		local snappedWorld = snapToGridWorld(hitPosition, hitGridPart)
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

-- HelperPlacementUI React Component
local function HelperPlacementUI()
	-- Get current state from global
	local data = _G.HelperPlacementData or {}
	local availableHelpers = data.availableHelpers or {}
	local selectedHelper = data.selectedHelper
	local isPlacing = data.isPlacing
	local statusText = data.statusText or "Loading..."
	local statusColor = data.statusColor or Color3.fromRGB(200, 200, 200)
	local isVisible = data.isVisible ~= false -- Default to true
	
	-- Don't render if not visible
	if not isVisible then
		return nil
	end
	
	-- Create helper items
	local helperItems = {}
	for i, helperName in ipairs(availableHelpers) do
		local isSelected = selectedHelper == helperName
		
		helperItems[i] = React.createElement("Frame", {
			Size = UDim2.new(1, -10, 0, 60),
			BackgroundColor3 = isSelected and Color3.fromRGB(50, 100, 50) or Color3.fromRGB(35, 35, 35),
			BorderSizePixel = 0,
			LayoutOrder = i,
		}, {
			UICorner = React.createElement("UICorner", {
				CornerRadius = UDim.new(0, 6),
			}),
			
			HelperName = React.createElement("TextLabel", {
				Size = UDim2.new(0.6, 0, 1, 0),
				Position = UDim2.new(0, 10, 0, 0),
				BackgroundTransparency = 1,
				Text = helperName,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 16,
				Font = Enum.Font.GothamBold,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			
			SelectButton = React.createElement("TextButton", {
				Size = UDim2.new(0, 100, 0, 40),
				Position = UDim2.new(1, -110, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundColor3 = isSelected and Color3.fromRGB(100, 200, 100) or Color3.fromRGB(50, 150, 50),
				BorderSizePixel = 0,
				Text = isSelected and "Selected" or "Select",
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 14,
				Font = Enum.Font.GothamBold,
				AutoButtonColor = false,
				[React.Event.Activated] = function()
					selectHelper(helperName)
				end,
			}, {
				UICorner = React.createElement("UICorner", {
					CornerRadius = UDim.new(0, 4),
				}),
			}),
		})
	end
	
	return React.createElement("Frame", {
		Size = UDim2.fromOffset(400, 500),
		Position = UDim2.new(0, 20, 0, 20),
		BackgroundColor3 = Color3.fromRGB(30, 30, 30),
		BorderSizePixel = 0,
	}, {
		UICorner = React.createElement("UICorner", {
			CornerRadius = UDim.new(0, 8),
		}),
		
		Title = React.createElement("Frame", {
			Size = UDim2.new(1, -50, 0, 40),
			BackgroundColor3 = Color3.fromRGB(40, 40, 40),
			BorderSizePixel = 0,
		}, {
			UICorner = React.createElement("UICorner", {
				CornerRadius = UDim.new(0, 8),
			}),
			
			TitleLabel = React.createElement("TextLabel", {
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
				Text = "Helper Placement",
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 20,
				Font = Enum.Font.GothamBold,
			}),
		}),
		
		CloseButton = React.createElement("TextButton", {
			Size = UDim2.new(0, 40, 0, 40),
			Position = UDim2.new(1, -40, 0, 0),
			BackgroundColor3 = Color3.fromRGB(200, 50, 50),
			BorderSizePixel = 0,
			Text = "×",
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextSize = 24,
			Font = Enum.Font.GothamBold,
			AutoButtonColor = false,
			[React.Event.Activated] = function()
				_G.HelperPlacementData.isVisible = false
				_G.HelperPlacementData.updateTime = tick()
				print("[HelperPlacementUI] ✅ UI closed")
			end,
		}, {
			UICorner = React.createElement("UICorner", {
				CornerRadius = UDim.new(0, 8),
			}),
		}),
		
		StatusLabel = React.createElement("TextLabel", {
			Size = UDim2.new(1, -20, 0, 30),
			Position = UDim2.new(0, 10, 0, 50),
			BackgroundTransparency = 1,
			Text = statusText,
			TextColor3 = statusColor,
			TextSize = 14,
			Font = Enum.Font.Gotham,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		
		ScrollingFrame = React.createElement("ScrollingFrame", {
			Size = UDim2.new(1, -20, 1, -90),
			Position = UDim2.new(0, 10, 0, 90),
			BackgroundColor3 = Color3.fromRGB(25, 25, 25),
			BorderSizePixel = 0,
			ScrollBarThickness = 6,
			CanvasSize = UDim2.new(0, 0, 0, #availableHelpers * 65),
		}, {
			UICorner = React.createElement("UICorner", {
				CornerRadius = UDim.new(0, 6),
			}),
			
			UIListLayout = React.createElement("UIListLayout", {
				Padding = UDim.new(0, 5),
				SortOrder = Enum.SortOrder.Name,
			}),
		}, helperItems),
	})
end

return HelperPlacementUI
