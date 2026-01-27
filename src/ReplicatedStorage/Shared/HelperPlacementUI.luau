-- HelperPlacementUI.luau - Auto-Chess/MOBA style shop bar
-- Supports TWO modes:
-- 1. Placement Mode: Select helper, click grid to place (existing functionality)
-- 2. Shop Mode: Buy helper from HoboSeller (NEW - randomized shop with reroll)

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

-- RemoteEvents
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local requestBuyHelper = remotes:FindFirstChild("RequestBuyHelper")
local requestPlaceHelper = remotes:FindFirstChild("RequestPlaceHelper")
local helperResponse = remotes:FindFirstChild("HelperResponse")

-- Shop RemoteEvents
local requestHelperShopPurchase = ReplicatedStorage:FindFirstChild("RequestHelperShopPurchase")
local requestHelperShopList = ReplicatedStorage:FindFirstChild("RequestHelperShopList")
local requestHelperShopReroll = ReplicatedStorage:FindFirstChild("RequestHelperShopReroll")
local getHelperPriceEvent = ReplicatedStorage:FindFirstChild("GetHelperPriceEvent")
local helperResponseEvent = ReplicatedStorage:FindFirstChild("HelperResponseEvent")

-- Global state
_G.HelperPlacementData = _G.HelperPlacementData or {
	-- Placement mode
	availableHelpers = {}, -- {name, cost, owned}
	selectedHelper = nil,
	isPlacing = false,
	
	-- Shop mode
	isShopMode = false, -- true = shop mode, false = placement mode
	shopHelpers = {}, -- Randomized list of helper names for shop
	shopPrice = 0, -- Price for next helper
	playerCoins = 0, -- Current player coins
	rerollCost = 20, -- Current reroll cost (increases by 20 per reroll)
	
	-- UI state
	statusText = "Loading...",
	statusColor = Color3.fromRGB(200, 200, 200),
	isVisible = false, -- Hidden by default (only shows when opened)
	isMinimized = false,
	updateTime = 0,
	currentPage = 1,
}

-- ===== SHOP MODE FUNCTIONS =====

-- Randomize shop helpers (6 slots, no duplicates if possible)
local function randomizeShopHelpers(allHelpers)
	if #allHelpers == 0 then return {} end
	
	local shuffled = {}
	for _, name in ipairs(allHelpers) do
		table.insert(shuffled, name)
	end
	
	-- Fisher-Yates shuffle
	local random = Random.new(tick())
	for i = #shuffled, 2, -1 do
		local j = random:NextInteger(1, i)
		shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
	end
	
	-- Take first 6 (or all if less than 6)
	local result = {}
	for i = 1, math.min(SLOTS_VISIBLE, #shuffled) do
		table.insert(result, shuffled[i])
	end
	
	return result
end

-- Open shop mode
local function openShop(price, helpersList)
	-- If helpersList is empty, use stored list or request new one
	if not helpersList or #helpersList == 0 then
		helpersList = _G.HelperPlacementData.allAvailableHelpers or {}
		
		-- If still empty, request from server
		if #helpersList == 0 and requestHelperShopList then
			requestHelperShopList:FireServer()
			-- The event listener will update the shop when response arrives
		end
	end
	
	_G.HelperPlacementData.isShopMode = true
	_G.HelperPlacementData.shopPrice = price
	_G.HelperPlacementData.shopHelpers = randomizeShopHelpers(helpersList)
	_G.HelperPlacementData.rerollCost = 20 -- Reset reroll cost when shop opens
	_G.HelperPlacementData.isVisible = true
	_G.HelperPlacementData.isMinimized = false
	_G.HelperPlacementData.statusText = "Select a helper to purchase"
	_G.HelperPlacementData.statusColor = Color3.fromRGB(200, 200, 200)
	
	-- Update player coins
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local coins = leaderstats:FindFirstChild("Coins")
		if coins then
			_G.HelperPlacementData.playerCoins = coins.Value
		end
	end
	
	_G.HelperPlacementData.updateTime = tick()
	print("[HelperPlacementUI] Shop opened - Price: " .. price .. ", Helpers: " .. #_G.HelperPlacementData.shopHelpers)
end

-- Close shop
local function closeShop()
	_G.HelperPlacementData.isShopMode = false
	_G.HelperPlacementData.isVisible = false
	_G.HelperPlacementData.updateTime = tick()
	print("[HelperPlacementUI] Shop closed")
end

-- Reroll shop (client-side helper - actual reroll happens via server)
local function rerollShop(allHelpers)
	_G.HelperPlacementData.shopHelpers = randomizeShopHelpers(allHelpers)
	_G.HelperPlacementData.updateTime = tick()
	print("[HelperPlacementUI] Shop rerolled")
end

-- Request reroll from server (with cost)
local function requestReroll()
	if not _G.HelperPlacementData.isShopMode then
		return
	end
	
	if not requestHelperShopReroll then
		warn("[HelperPlacementUI] RequestHelperShopReroll RemoteEvent not found!")
		return
	end
	
	-- Request reroll from server (server will validate coins and deduct)
	requestHelperShopReroll:FireServer()
end

-- Purchase helper from shop
local function purchaseHelper(helperName)
	if not _G.HelperPlacementData.isShopMode then
		return
	end
	
	print("[HelperPlacementUI] Purchasing: " .. helperName)
	requestHelperShopPurchase:FireServer(helperName)
end

-- Expose functions globally for dialog script
_G.OpenHelperShop = openShop
_G.CloseHelperShop = closeShop

-- ===== PLACEMENT MODE FUNCTIONS =====

-- Grid ownership tracking (for placement mode)
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

-- Get helpers list from server (placement mode)
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

-- Listen for shop purchase response
if helperResponseEvent then
	helperResponseEvent.OnClientEvent:Connect(function(success, message)
		if _G.HelperPlacementData.isShopMode then
			if success then
				-- Purchase successful - close shop
				closeShop()
				-- Show success message (dialog will handle this)
				print("[HelperPlacementUI] Purchase successful: " .. (message or ""))
			else
				-- Purchase failed - keep shop open, show error
				_G.HelperPlacementData.statusText = message or "Purchase failed"
				_G.HelperPlacementData.statusColor = Color3.fromRGB(255, 100, 100)
				_G.HelperPlacementData.updateTime = tick()
				print("[HelperPlacementUI] Purchase failed: " .. (message or ""))
			end
		end
	end)
end

-- Listen for shop helpers list response
if requestHelperShopList then
	requestHelperShopList.OnClientEvent:Connect(function(data)
		if data and data.helpers then
			-- Store helpers list for future use
			_G.HelperPlacementData.allAvailableHelpers = data.helpers
			
			-- If shop is open but empty, populate it now
			if _G.HelperPlacementData.isShopMode then
				if #_G.HelperPlacementData.shopHelpers == 0 then
					-- Shop was opened before helpers list arrived, populate it now
					_G.HelperPlacementData.shopHelpers = randomizeShopHelpers(data.helpers)
					_G.HelperPlacementData.updateTime = tick()
					print("[HelperPlacementUI] Shop populated with helpers after delay")
				else
					-- Shop already has helpers, this is a reroll request
					rerollShop(data.helpers)
				end
			end
		end
	end)
end

-- Listen for shop reroll response
if requestHelperShopReroll then
	requestHelperShopReroll.OnClientEvent:Connect(function(success, message, newRerollCost, helpersData)
		if _G.HelperPlacementData.isShopMode then
			if success then
				-- Update reroll cost
				if typeof(newRerollCost) == "number" then
					_G.HelperPlacementData.rerollCost = newRerollCost
				end
				
				-- Update helpers list if provided
				if helpersData and helpersData.helpers then
					_G.HelperPlacementData.allAvailableHelpers = helpersData.helpers
					rerollShop(helpersData.helpers)
				end
				
				-- Update player coins
				local leaderstats = player:FindFirstChild("leaderstats")
				if leaderstats then
					local coins = leaderstats:FindFirstChild("Coins")
					if coins then
						_G.HelperPlacementData.playerCoins = coins.Value
					end
				end
				
				_G.HelperPlacementData.statusText = "<font color='rgb(100,255,100)'>Rerolled!</font>"
				_G.HelperPlacementData.statusColor = Color3.fromRGB(100, 255, 100)
				_G.HelperPlacementData.updateTime = tick()
				print("[HelperPlacementUI] Reroll successful, next cost: " .. (newRerollCost or "unknown"))
			else
				-- Reroll failed (not enough coins, etc.)
				_G.HelperPlacementData.statusText = message or "Reroll failed"
				_G.HelperPlacementData.statusColor = Color3.fromRGB(255, 100, 100)
				if typeof(newRerollCost) == "number" then
					_G.HelperPlacementData.rerollCost = newRerollCost
				end
				_G.HelperPlacementData.updateTime = tick()
				print("[HelperPlacementUI] Reroll failed: " .. (message or "unknown error"))
			end
		end
	end)
end

-- Listen for price updates
if getHelperPriceEvent then
	getHelperPriceEvent.OnClientEvent:Connect(function(price, helperCount)
		if _G.HelperPlacementData.isShopMode then
			_G.HelperPlacementData.shopPrice = price
			_G.HelperPlacementData.updateTime = tick()
		end
	end)
end

-- Update player coins periodically
task.spawn(function()
	while true do
		task.wait(0.5)
		if _G.HelperPlacementData.isShopMode then
			local leaderstats = player:FindFirstChild("leaderstats")
			if leaderstats then
				local coins = leaderstats:FindFirstChild("Coins")
				if coins then
					_G.HelperPlacementData.playerCoins = coins.Value
					_G.HelperPlacementData.updateTime = tick()
				end
			end
		end
	end
end)

-- Initialize helpers list (placement mode only)
task.spawn(function()
	task.wait(1)
	if not _G.HelperPlacementData.isShopMode then
		requestHelpersList()
	end
end)

-- Handle helper selection (placement mode)
local function selectHelper(helperName)
	_G.HelperPlacementData.selectedHelper = helperName
	_G.HelperPlacementData.isPlacing = true
	_G.HelperPlacementData.statusText = "Selected: " .. helperName .. " - Click on grid to place"
	_G.HelperPlacementData.statusColor = Color3.fromRGB(100, 255, 100)
	_G.HelperPlacementData.updateTime = tick()
	print("[HelperPlacementUI] Selected helper: " .. helperName)
end

-- Handle mouse click for placement (placement mode only)
local function onMouseClick()
	if _G.HelperPlacementData.isShopMode then
		return -- Don't handle clicks in shop mode
	end
	
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
		if not _G.HelperPlacementData.isShopMode then
			_G.HelperPlacementData.isVisible = not _G.HelperPlacementData.isVisible
			_G.HelperPlacementData.updateTime = tick()
			print("[HelperPlacementUI] Helper bar " .. (_G.HelperPlacementData.isVisible and "opened" or "closed"))
		end
	elseif input.KeyCode == Enum.KeyCode.Escape then
		if _G.HelperPlacementData.isShopMode then
			closeShop()
		else
			_G.HelperPlacementData.isVisible = false
			_G.HelperPlacementData.updateTime = tick()
		end
		print("[HelperPlacementUI] UI closed via Esc")
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
		onMouseClick()
	end
end)

-- Create highlight for grid placement preview (placement mode only)
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
		if _G.HelperPlacementData.isShopMode then
			highlight.Transparency = 1
			selectionBox.Transparency = 1
			return
		end
		
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
	-- Check if viewport is already showing this helper
	local currentHelper = viewportFrame:GetAttribute("CurrentHelper")
	if currentHelper == helperName and viewportFrame:GetAttribute("Ready") then
		-- Already showing this helper, no need to update
		return
	end
	
	-- If showing a different helper, clear the ready flag and update
	if currentHelper ~= helperName then
		viewportFrame:SetAttribute("Ready", false)
		viewportFrame:SetAttribute("CurrentHelper", nil)
		
		-- Clean up existing content BEFORE setting up new helper
		for _, child in ipairs(viewportFrame:GetChildren()) do
			if child.Name == "ViewportCamera" or child.Name == "ViewportLight" or child.Name == "TopLight" or child:IsA("Model") then
				child:Destroy()
			end
		end
	end
	
	print("[HelperPlacementUI] Setting up viewport for: " .. helperName)
	
	-- Get rarity colors for rim lighting
	local rarityColors = getRarityColors(helperName)
	local primaryColor = rarityColors.primary
	local secondaryColor = rarityColors.secondary
	
	-- Clean up existing content (only known names, not all Models/Parts)
	-- This ensures we start fresh even if Ready wasn't set
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
	-- Rotate 180 degrees on Y axis so model faces forward (toward camera)
	modelToShow:PivotTo(CFrame.Angles(0, math.rad(180), 0))
	
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
	
	-- Calculate camera distance to fit model
	local maxSize = math.max(size.X, size.Y, size.Z)
	local distance = maxSize * 1.4
	
	-- Position camera to look at model center
	camera.CFrame = CFrame.lookAt(center + Vector3.new(distance, distance * 0.4, distance), center)
	
	-- Add lighting to viewport
	local lightPart = Instance.new("Part")
	lightPart.Name = "ViewportLight"
	lightPart.Size = Vector3.new(0.1, 0.1, 0.1)
	lightPart.Transparency = 1
	lightPart.Anchored = true
	lightPart.CanCollide = false
	lightPart.Parent = viewportFrame
	
	local light = Instance.new("PointLight")
	light.Brightness = 5
	light.Range = 200
	light.Color = Color3.new(
		(primaryColor.R + 1) / 2,
		(primaryColor.G + 1) / 2,
		(primaryColor.B + 1) / 2
	)
	light.Shadows = false
	light.Parent = lightPart
	
	lightPart.CFrame = camera.CFrame
	
	-- Update light position as camera rotates
	task.spawn(function()
		while modelToShow.Parent == viewportFrame and lightPart.Parent do
			lightPart.CFrame = camera.CFrame
			task.wait(0.1)
		end
	end)
	
	-- Add additional ambient light from above
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
	topPointLight.Color = Color3.new(
		(secondaryColor.R + 1) / 2,
		(secondaryColor.G + 1) / 2,
		(secondaryColor.B + 1) / 2
	)
	topPointLight.Shadows = false
	topPointLight.Parent = topLight
	
	topLight.CFrame = CFrame.new(center + Vector3.new(0, distance * 1.5, 0))
	
	print("[HelperPlacementUI] ✅ Lighting added")
	
	-- Rotation animation
	task.spawn(function()
		local rotation = 0
		local offset = Vector3.new(distance, distance * 0.4, distance)
		
		while modelToShow.Parent == viewportFrame and viewportFrame.Parent do
			rotation = (rotation + 1.5) % 360
			local rot = CFrame.Angles(0, math.rad(rotation), 0)
			local camPos = center + rot:VectorToWorldSpace(offset)
			
			camera.CFrame = CFrame.lookAt(camPos, center)
			if lightPart.Parent then
				lightPart.CFrame = camera.CFrame
			end
			task.wait(0.05)
		end
	end)
	
	-- Mark as ready and store current helper name
	viewportFrame:SetAttribute("Ready", true)
	viewportFrame:SetAttribute("CurrentHelper", helperName)
	
	print("[HelperPlacementUI] ✅ Viewport fully set up for " .. helperName)
end

-- HelperPlacementUI React Component
local function HelperPlacementUI()
	-- Get current state from global
	local data = _G.HelperPlacementData or {}
	local isShopMode = data.isShopMode or false
	local isVisible = data.isVisible ~= false
	local isMinimized = data.isMinimized or false
	
	-- Don't render if not visible
	if not isVisible then
		return nil
	end
	
	-- Get helpers list based on mode
	local visibleHelpers = {}
	if isShopMode then
		-- Shop mode: use randomized shop helpers
		visibleHelpers = data.shopHelpers or {}
	else
		-- Placement mode: use available helpers with pagination
		local availableHelpers = data.availableHelpers or {}
		local currentPage = data.currentPage or 1
		local totalHelpers = #availableHelpers
		local _totalPages = math.ceil(totalHelpers / SLOTS_VISIBLE) -- Reserved for future pagination
		local startIndex = (currentPage - 1) * SLOTS_VISIBLE + 1
		local endIndex = math.min(startIndex + SLOTS_VISIBLE - 1, totalHelpers)
		
		for i = startIndex, endIndex do
			if availableHelpers[i] then
				local helperData = availableHelpers[i]
				local helperName = helperData.name or helperData
				table.insert(visibleHelpers, helperName)
			end
		end
	end
	
	-- Create helper slot items
	local slotItems = {}
	for i, helperName in ipairs(visibleHelpers) do
		local helperDataName = helperName
		if typeof(helperName) == "table" then
			helperDataName = helperName.name or helperName
		end
		
		local isSelected = not isShopMode and data.selectedHelper == helperDataName
		
		-- Get rarity colors
		local rarityColors = getRarityColors(helperDataName)
		local primaryColor = rarityColors.primary
		local secondaryColor = rarityColors.secondary
		local shadowColor = rarityColors.shadow
		
		-- Create viewport frame name for later lookup
		local viewportName = "Viewport_" .. helperDataName .. "_" .. i
		
		-- Button text and action based on mode
		local buttonText = isShopMode and "BUY" or (isSelected and "Selected" or "Select")
		local buttonAction = isShopMode and function()
			purchaseHelper(helperDataName)
		end or function()
			selectHelper(helperDataName)
		end
		
		slotItems[i] = React.createElement("Frame", {
			Size = UDim2.new(0, SLOT_WIDTH, 0, SLOT_HEIGHT),
			BackgroundColor3 = Color3.fromRGB(25, 25, 30),
			BorderSizePixel = 0,
			LayoutOrder = i,
		}, {
			UICorner = React.createElement("UICorner", {
				CornerRadius = UDim.new(0, 8),
			}),
			
			-- Gradient background with rarity accent
			BackgroundGradient = React.createElement("UIGradient", {
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(35, 35, 45)),
					ColorSequenceKeypoint.new(0.5, Color3.fromRGB(25, 25, 30)),
					ColorSequenceKeypoint.new(1, shadowColor),
				}),
				Rotation = 45,
			}),
			
			-- Rarity indicator stripe
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
			
			-- Rarity outline
			RarityOutline = React.createElement("UIStroke", {
				Color = primaryColor,
				Thickness = isSelected and 2.5 or 1.5,
				Transparency = isSelected and 0.4 or 0.7,
			}),
			
			-- Selection border
			SelectionBorder = isSelected and React.createElement("UIStroke", {
				Color = secondaryColor,
				Thickness = 2,
				Transparency = 0.3,
			}) or nil,
			
			-- ViewportFrame for 3D model
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
						ColorSequenceKeypoint.new(1, shadowColor),
					}),
					Rotation = 135,
				}),
				ViewportBorder = React.createElement("UIStroke", {
					Color = primaryColor,
					Thickness = 1.5,
					Transparency = 0.6,
				}),
				Viewport = React.createElement("ViewportFrame", {
					Size = UDim2.new(1, -4, 1, -4),
					Position = UDim2.new(0, 2, 0, 2),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					Name = "Viewport",
				}),
			}),
			
			-- Helper name
			HelperName = React.createElement("TextLabel", {
				Size = UDim2.new(1, -10, 0, 20),
				Position = UDim2.new(0, 5, 0, 110),
				BackgroundTransparency = 1,
				Text = helperDataName,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 14,
				Font = Enum.Font.GothamBold,
				TextXAlignment = Enum.TextXAlignment.Center,
			}),
			
			-- Action button (BUY in shop mode, Select in placement mode)
			ActionButton = React.createElement("TextButton", {
				Size = UDim2.new(1, -10, 0, 32),
				Position = UDim2.new(0, 5, 1, -38),
				BackgroundColor3 = isSelected and Color3.fromRGB(100, 200, 100) or Color3.fromRGB(50, 150, 50),
				BorderSizePixel = 0,
				Text = buttonText,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 13,
				Font = Enum.Font.GothamBold,
				AutoButtonColor = false,
				[React.Event.Activated] = buttonAction,
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
	
	-- Calculate bar width and height
	local barWidth = math.min(SLOTS_VISIBLE, #visibleHelpers) * SLOT_WIDTH + 20
	if isShopMode then
		barWidth = barWidth + 100 -- Extra space for reroll button and price display
	else
		local _totalPages = math.ceil(#(data.availableHelpers or {}) / SLOTS_VISIBLE)
		if _totalPages > 1 then
			barWidth = barWidth + 80
		end
	end
	
	local barHeight = isMinimized and 50 or (SLOT_HEIGHT + 60) -- Extra height for shop info
	local barYOffset = isMinimized and -60 or (-SLOT_HEIGHT - 50)
	
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
		
		-- Main border
		Border = React.createElement("UIStroke", {
			Color = Color3.fromRGB(80, 100, 120),
			Thickness = 2,
			Transparency = 0.3,
		}),
		
		-- Shop mode: Price and coins display
		ShopInfo = isShopMode and not isMinimized and React.createElement("Frame", {
			Size = UDim2.new(1, -20, 0, 30),
			Position = UDim2.new(0, 10, 0, 5),
			BackgroundTransparency = 1,
		}, {
			PriceLabel = React.createElement("TextLabel", {
				Size = UDim2.new(0.5, -5, 1, 0),
				Position = UDim2.new(0, 0, 0, 0),
				BackgroundTransparency = 1,
				Text = "Next Helper: " .. (data.shopPrice or 0) .. " coins",
				TextColor3 = Color3.fromRGB(255, 220, 127),
				TextSize = 14,
				Font = Enum.Font.GothamBold,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			CoinsLabel = React.createElement("TextLabel", {
				Size = UDim2.new(0.5, -5, 1, 0),
				Position = UDim2.new(0.5, 5, 0, 0),
				BackgroundTransparency = 1,
				Text = "Your Coins: " .. (data.playerCoins or 0),
				TextColor3 = Color3.fromRGB(100, 255, 100),
				TextSize = 14,
				Font = Enum.Font.GothamBold,
				TextXAlignment = Enum.TextXAlignment.Right,
			}),
		}) or nil,
		
		-- Reroll button (shop mode only)
		RerollButton = isShopMode and not isMinimized and React.createElement("TextButton", {
			Size = UDim2.new(0, 100, 0, 30),
			Position = UDim2.new(0, 10, 1, -35),
			BackgroundColor3 = Color3.fromRGB(100, 150, 200),
			BorderSizePixel = 0,
			Text = "Reroll (" .. (data.rerollCost or 20) .. ")",
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextSize = 12,
			Font = Enum.Font.GothamBold,
			AutoButtonColor = false,
			[React.Event.Activated] = function()
				requestReroll()
			end,
		}, {
			UICorner = React.createElement("UICorner", {
				CornerRadius = UDim.new(0, 6),
			}),
			RerollGradient = React.createElement("UIGradient", {
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 170, 220)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 130, 180)),
				}),
			}),
		}) or nil,
		
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
				if isShopMode then
					closeShop()
				else
					_G.HelperPlacementData.isVisible = false
					_G.HelperPlacementData.updateTime = tick()
				end
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
		
		-- Status text (shop mode)
		StatusText = isShopMode and not isMinimized and React.createElement("TextLabel", {
			Size = UDim2.new(1, -100, 0, 20),
			Position = UDim2.new(0, 10, 1, -30),
			BackgroundTransparency = 1,
			Text = data.statusText or "",
			TextColor3 = data.statusColor or Color3.fromRGB(200, 200, 200),
			TextSize = 12,
			Font = Enum.Font.Gotham,
			TextXAlignment = Enum.TextXAlignment.Left,
		}) or nil,
		
		-- Slots container
		SlotsContainer = not isMinimized and React.createElement("Frame", {
			Size = UDim2.new(1, -20, 0, SLOT_HEIGHT),
			Position = UDim2.new(0, 10, 0, isShopMode and 40 or 10),
			BackgroundTransparency = 1,
		}, {
			UIListLayout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		}, slotItems) or nil,
	})
	
	-- Setup viewports after render
	task.spawn(function()
		task.wait(0.2)
		local playerGui = player:FindFirstChild("PlayerGui")
		if not playerGui then return end
		
		local reactGui = playerGui:FindFirstChild("React")
		if not reactGui then return end
		
		local shopBar = reactGui:FindFirstChild("HelperShopBar", true)
		if not shopBar then return end
		
		for i, helperName in ipairs(visibleHelpers) do
			local helperDataName = helperName
			if typeof(helperName) == "table" then
				helperDataName = helperName.name or helperName
			end
			
			local viewportName = "Viewport_" .. helperDataName .. "_" .. i
			local viewportContainer = shopBar:FindFirstChild(viewportName .. "_Container", true)
			
			if viewportContainer then
				local viewport = viewportContainer:FindFirstChild("Viewport")
				if viewport and viewport:IsA("ViewportFrame") then
					-- Always call setupViewport - it will check if update is needed
					setupViewport(viewport, helperDataName)
				end
			end
		end
	end)
	
	return mainFrame
end

return HelperPlacementUI
