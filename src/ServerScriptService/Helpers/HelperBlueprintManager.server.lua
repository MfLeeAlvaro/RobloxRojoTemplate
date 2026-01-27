-- HelperBlueprintManager.server.lua
-- Blueprint system: board instances fight, blueprints are authoritative copies
-- On placement: create board instance + save blueprint
-- On wave end: destroy board instances, respawn fresh from blueprints

local ServerStorage = game:GetService("ServerStorage")
local workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local helpersFolder = workspace:WaitForChild("Helpers")
local helperTemplates = ServerStorage:WaitForChild("HelperTemplates")

-- Create blueprint storage folder
local blueprintFolder = ServerStorage:FindFirstChild("HelperBlueprints")
if not blueprintFolder then
	blueprintFolder = Instance.new("Folder")
	blueprintFolder.Name = "HelperBlueprints"
	blueprintFolder.Parent = ServerStorage
end

-- ===== UTILITY FUNCTIONS =====

-- Generate stable key for a helper
local function getHelperKey(gridId, placeRow, placeCol)
	if not gridId or not placeRow or not placeCol then
		return nil
	end
	return gridId .. ":" .. tostring(placeRow) .. ":" .. tostring(placeCol)
end

-- Get helper key from a helper model
local function getKeyFromHelper(helper)
	local gridId = helper:GetAttribute("GridId")
	local placeRow = helper:GetAttribute("PlaceRow") or helper:GetAttribute("SpawnRow")
	local placeCol = helper:GetAttribute("PlaceCol") or helper:GetAttribute("SpawnCol")
	return getHelperKey(gridId, placeRow, placeCol)
end

-- ===== BLUEPRINT MANAGEMENT =====

-- Save a blueprint from a board instance
-- If oldHelperKey is provided, removes the old blueprint first (for moves)
local function saveBlueprint(boardInstance, oldHelperKey)
	if not boardInstance or not boardInstance.Parent then
		return false
	end
	
	local helperKey = getKeyFromHelper(boardInstance)
	if not helperKey then
		warn("[HelperBlueprintManager] Cannot save blueprint: missing GridId/PlaceRow/PlaceCol")
		return false
	end
	
	-- Remove old blueprint if moving (oldHelperKey provided and different from new key)
	if oldHelperKey and oldHelperKey ~= helperKey then
		local oldBlueprint = blueprintFolder:FindFirstChild(oldHelperKey)
		if oldBlueprint then
			oldBlueprint:Destroy()
			print("[HelperBlueprintManager] ❌ Removed old blueprint: " .. oldHelperKey)
		end
	end
	
	-- Check if blueprint already exists at new position
	local existingBlueprint = blueprintFolder:FindFirstChild(helperKey)
	if existingBlueprint then
		-- Update existing blueprint (shouldn't happen normally, but handle it)
		existingBlueprint:Destroy()
	end
	
	-- Clone board instance as blueprint
	local blueprint = boardInstance:Clone()
	blueprint.Name = helperKey
	blueprint.Parent = blueprintFolder
	
	-- Set HelperKey attribute
	blueprint:SetAttribute("HelperKey", helperKey)
	
	-- Ensure blueprint has all required attributes
	local requiredAttrs = {
		"HelperType", "GridId", "PlaceRow", "PlaceCol", "OriginalCFrame",
		"OwnerUserId", "IslandId", "Star", "StarLevel", "Rarity",
		"BaseDamage", "BaseHealth", "BaseRange", "BaseCooldown",
		"AttackDamage", "AttackRange", "AttackCooldown"
	}
	
	for _, attrName in ipairs(requiredAttrs) do
		local val = boardInstance:GetAttribute(attrName)
		if val ~= nil then
			blueprint:SetAttribute(attrName, val)
		end
	end
	
	-- Copy any other important attributes
	for _, attrName in ipairs({"HasCart", "UnitKey", "EnemyType", "TemplateName", "HelperName"}) do
		local val = boardInstance:GetAttribute(attrName)
		if val ~= nil then
			blueprint:SetAttribute(attrName, val)
		end
	end
	
	print("[HelperBlueprintManager] ✅ Saved blueprint: " .. helperKey)
	return true
end

-- Check if a tile is occupied (by checking blueprint existence)
local function isTileOccupied(gridId, placeRow, placeCol)
	local helperKey = getHelperKey(gridId, placeRow, placeCol)
	if not helperKey then return false end
	
	local blueprint = blueprintFolder:FindFirstChild(helperKey)
	return blueprint ~= nil
end

-- Get blueprint for a tile
local function getBlueprint(gridId, placeRow, placeCol)
	local helperKey = getHelperKey(gridId, placeRow, placeCol)
	if not helperKey then return nil end
	
	return blueprintFolder:FindFirstChild(helperKey)
end

-- Spawn board instance from blueprint
local function spawnFromBlueprint(blueprint)
	if not blueprint or not blueprint.Parent then
		return nil
	end
	
	local helperKey = blueprint:GetAttribute("HelperKey")
	local helperType = blueprint:GetAttribute("HelperType") or blueprint:GetAttribute("HelperName")
	local originalCFrame = blueprint:GetAttribute("OriginalCFrame")
	
	if not helperKey or not helperType or not originalCFrame then
		warn("[HelperBlueprintManager] Blueprint missing required attributes: " .. tostring(helperKey))
		return nil
	end
	
	-- Clone blueprint to create board instance
	local boardInstance = blueprint:Clone()
	boardInstance.Name = helperType .. "_" .. (blueprint:GetAttribute("OwnerUserId") or "Unknown") .. "_" .. os.time()
	
	-- Disable player collision (prevent players from getting stuck)
	if _G.DisablePlayerCollision then
		_G.DisablePlayerCollision(boardInstance)
	end
	
	boardInstance.Parent = helpersFolder
	
	-- Set HelperKey on board instance
	boardInstance:SetAttribute("HelperKey", helperKey)
	
	-- Set PrimaryPart before positioning
	local primary = boardInstance:FindFirstChild("HumanoidRootPart", true) 
		or boardInstance.PrimaryPart 
		or boardInstance:FindFirstChildWhichIsA("BasePart", true)
	if primary then
		boardInstance.PrimaryPart = primary
	end
	
	-- Position at original tile
	if typeof(originalCFrame) == "CFrame" then
		boardInstance:PivotTo(originalCFrame)
	end
	
	-- Set humanoid health
	local hum = boardInstance:FindFirstChildOfClass("Humanoid")
	if hum then
		local starLevel = blueprint:GetAttribute("StarLevel") or blueprint:GetAttribute("Star") or 0
		local baseHealth = blueprint:GetAttribute("BaseHealth") or 100
		hum.MaxHealth = baseHealth * (2 ^ starLevel)
		hum.Health = hum.MaxHealth
		
		-- Get original walk speed/jump power from blueprint FIRST (before freezing)
		local originalWS = blueprint:GetAttribute("OriginalWalkSpeed")
		local originalJP = blueprint:GetAttribute("OriginalJumpPower")
		
		-- If blueprint doesn't have it, use current humanoid values (before freezing)
		if not originalWS or typeof(originalWS) ~= "number" or originalWS <= 0 then
			originalWS = hum.WalkSpeed > 0 and hum.WalkSpeed or 16
		end
		if not originalJP or typeof(originalJP) ~= "number" or originalJP <= 0 then
			originalJP = hum.JumpPower > 0 and hum.JumpPower or 50
		end
		
		-- Store the original values BEFORE freezing
		boardInstance:SetAttribute("OriginalWalkSpeed", originalWS)
		boardInstance:SetAttribute("OriginalJumpPower", originalJP)
		
		-- Freeze for prep phase
		hum.WalkSpeed = 0
		hum.JumpPower = 0
		hum:Move(Vector3.zero)
	end
	
	-- Reset state
	boardInstance:SetAttribute("Aggressive", false)
	boardInstance:SetAttribute("Frozen", true)
	boardInstance:SetAttribute("Dead", false)
	
	-- Restore Tweaker cart if needed
	if boardInstance.Name:find("Tweaker") then
		local restoreCartEvent = ReplicatedStorage:FindFirstChild("RestoreTweakerCart")
		if restoreCartEvent then
			restoreCartEvent:Fire(boardInstance)
		end
	end
	
	print("[HelperBlueprintManager] ✅ Spawned board instance from blueprint: " .. helperKey)
	return boardInstance
end

-- Update blueprint when helper is upgraded (merge, star increase, etc.)
local function updateBlueprint(boardInstance)
	return saveBlueprint(boardInstance)
end

-- Remove blueprint (when helper is sold/removed)
local function removeBlueprint(gridId, placeRow, placeCol)
	local helperKey = getHelperKey(gridId, placeRow, placeCol)
	if not helperKey then return false end
	
	local blueprint = blueprintFolder:FindFirstChild(helperKey)
	if blueprint then
		blueprint:Destroy()
		print("[HelperBlueprintManager] ❌ Removed blueprint: " .. helperKey)
		return true
	end
	return false
end

-- ===== WAVE END RESET =====

-- Reset all helpers for an island (destroy board instances, respawn from blueprints)
_G.ResetHelpersOnIsland = function(islandId)
	if typeof(islandId) ~= "number" then
		warn("[HelperBlueprintManager] Invalid islandId:", islandId)
		return
	end
	
	-- Collect all blueprints for this island
	local blueprintsToSpawn = {}
	for _, blueprint in ipairs(blueprintFolder:GetChildren()) do
		if blueprint:IsA("Model") then
			local hid = blueprint:GetAttribute("IslandId")
			if typeof(hid) == "number" and hid == islandId then
				table.insert(blueprintsToSpawn, blueprint)
			end
		end
	end
	
	-- Destroy all existing board instances for this island
	for _, boardInstance in ipairs(helpersFolder:GetChildren()) do
		if boardInstance:IsA("Model") then
			local hid = boardInstance:GetAttribute("IslandId")
			if typeof(hid) == "number" and hid == islandId then
				boardInstance:Destroy()
			end
		end
	end
	
	-- Spawn fresh board instances from blueprints
	for _, blueprint in ipairs(blueprintsToSpawn) do
		spawnFromBlueprint(blueprint)
	end
	
	print("[HelperBlueprintManager] ✅ Reset " .. #blueprintsToSpawn .. " helpers for island: " .. islandId)
end

-- ===== PUBLIC API =====

-- Check if tile is occupied (for placement validation)
_G.IsHelperTileOccupied = function(gridId, placeRow, placeCol)
	return isTileOccupied(gridId, placeRow, placeCol)
end

-- Save blueprint when helper is placed
_G.SaveHelperBlueprint = function(boardInstance)
	return saveBlueprint(boardInstance)
end

-- Update blueprint when helper is upgraded
_G.UpdateHelperBlueprint = function(boardInstance)
	return updateBlueprint(boardInstance)
end

-- Remove blueprint when helper is sold
_G.RemoveHelperBlueprint = function(gridId, placeRow, placeCol)
	return removeBlueprint(gridId, placeRow, placeCol)
end

print("[HelperBlueprintManager] ✅ Initialized")
