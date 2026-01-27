--========================================================
-- HelperRespawn.server.lua
-- Unified helper respawn/restore/reset system
-- Merged from HelperRespawnManager, HelperRestore, and HelperRoundReset
-- Integrates with HelperBlueprintManager for persistence
--========================================================

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local workspace = game:GetService("Workspace")

local helpersFolder = workspace:WaitForChild("Helpers")
local helperTemplates = ServerStorage:WaitForChild("HelperTemplates")

-- Grid constants
local GRID_SIZE = 5
local GRID_COLS = 10
local GRID_ROWS = 10

-- ===== IMPORTANT ATTRIBUTES TO PRESERVE =====
local IMPORTANT_ATTRS = {
	"OwnerUserId", "GridId", "IslandId",
	"HelperType", "PlaceRow", "PlaceCol", "OriginalCFrame",
	"Star", "StarLevel", "Rarity",
	"BaseDamage", "BaseHealth", "BaseRange", "BaseCooldown",
	"AttackDamage", "AttackRange", "AttackCooldown",
	"Synergy", "Element", "DamageMult",
	"SpecialReady", "SpecialCooldown",
	"HasCart", "UnitKey", "EnemyType", "TemplateName",
	"Race", "OriginalWalkSpeed", "OriginalJumpPower",
}

-- ===== UTILITY FUNCTIONS =====

-- Get helper template name
local function getHelperTemplateName(helper)
	local helperType = helper:GetAttribute("HelperType")
		or helper:GetAttribute("HelperName")
		or helper:GetAttribute("UnitType")
	
	if helperType and typeof(helperType) == "string" and helperType ~= "" then
		return helperType
	end
	
	-- Fallback: strip suffixes
	local baseName = helper.Name:match("^[^_]+")
	return baseName or helper.Name
end

-- Restore visibility of a helper
local function restoreVisibility(helper)
	for _, part in ipairs(helper:GetDescendants()) do
		if part:IsA("BasePart") then
			local origTrans = part:GetAttribute("OriginalTransparency")
			if origTrans ~= nil then
				part.Transparency = origTrans
			else
				part.Transparency = 0
			end
			
			local origCanCollide = part:GetAttribute("OriginalCanCollide")
			if origCanCollide ~= nil then
				part.CanCollide = origCanCollide
			else
				part.CanCollide = true
			end
		elseif part:IsA("Decal") or part:IsA("Texture") then
			local origTrans = part:GetAttribute("OriginalTransparency")
			if origTrans ~= nil then
				part.Transparency = origTrans
			else
				part.Transparency = 0
			end
		end
	end
end

-- Reset helper position to original tile
local function resetPosition(helper)
	local originalCFrame = helper:GetAttribute("OriginalCFrame")
	if originalCFrame and typeof(originalCFrame) == "CFrame" then
		local root = helper:FindFirstChild("HumanoidRootPart") or helper.PrimaryPart
		if root then
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
		end
		helper:PivotTo(originalCFrame)
		return true
	end
	return false
end

-- Revive and heal helper
local function reviveAndHeal(helper)
	local hum = helper:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	
	-- Revive if dead
	if hum.Health <= 0 then
		hum:ChangeState(Enum.HumanoidStateType.GettingUp)
		hum.Health = 1
		helper:SetAttribute("IsDead", false)
	end
	
	-- Heal to full
	hum.Health = hum.MaxHealth
	
	-- Reset physics state
	local root = helper:FindFirstChild("HumanoidRootPart") or helper.PrimaryPart
	if root then
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		if root.Anchored then
			root.Anchored = false
		end
	end
end

-- Reset helper state (special flags, cooldowns, etc.)
local function resetHelperState(helper)
	-- Clear dead flag
	helper:SetAttribute("Dead", false)
	helper:SetAttribute("IsDead", false)
	
	-- Clear special flags
	helper:SetAttribute("UsingSpecial", false)
	helper:SetAttribute("SpecialReady", false)
	helper:SetAttribute("SpecialCooldown", 0)
	
	-- Reset to neutral/not aggressive
	helper:SetAttribute("Aggressive", false)
	helper:SetAttribute("Frozen", true)
	
	-- Freeze for prep phase
	local hum = helper:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = 0
		hum.JumpPower = 0
		hum:Move(Vector3.zero)
	end
	
	-- Restore Tweaker cart if needed
	if helper.Name:find("Tweaker") then
		local restoreCartEvent = ReplicatedStorage:FindFirstChild("RestoreTweakerCart")
		if restoreCartEvent then
			restoreCartEvent:Fire(helper)
		end
	end
end

-- Restore a single helper (from HelperRestore)
local function restoreHelper(helper)
	if not helper or not helper.Parent then return end
	
	-- Restore visibility
	restoreVisibility(helper)
	
	-- Reset position
	resetPosition(helper)
	
	-- Revive and heal
	reviveAndHeal(helper)
	
	-- Reset state
	resetHelperState(helper)
end

-- ===== WAVE END RESET =====

-- Restore all helpers for an island (from HelperRestore)
_G.RestoreHelpersOnIsland = function(islandId)
	if typeof(islandId) ~= "number" then
		warn("[HelperRespawn] Invalid islandId:", islandId)
		return
	end
	
	-- Use blueprint system if available (preferred)
	if _G.ResetHelpersOnIsland then
		_G.ResetHelpersOnIsland(islandId)
		return
	end
	
	-- Fallback: restore existing helpers
	local toRestore = {}
	for _, helper in ipairs(helpersFolder:GetChildren()) do
		if helper:IsA("Model") then
			local hid = helper:GetAttribute("IslandId")
			if typeof(hid) == "number" and hid == islandId then
				table.insert(toRestore, helper)
			end
		end
	end
	
	-- Restore each helper
	for _, helper in ipairs(toRestore) do
		if helper and helper.Parent == helpersFolder then
			restoreHelper(helper)
		end
	end
	
	print("[HelperRespawn] ✅ Restored " .. #toRestore .. " helpers for island: " .. islandId)
end

-- ===== ROUND RESET (Replace with fresh clones) =====

-- Snapshot helper attributes
local function snapshotHelper(helper)
	local data = {
		attrs = {},
		helperType = getHelperTemplateName(helper),
	}
	
	for _, key in ipairs(IMPORTANT_ATTRS) do
		local v = helper:GetAttribute(key)
		if v ~= nil then
			data.attrs[key] = v
		end
	end
	
	-- Ensure OriginalCFrame exists
	if typeof(data.attrs.OriginalCFrame) ~= "CFrame" then
		local root = helper:FindFirstChild("HumanoidRootPart") or helper.PrimaryPart
		if root then
			data.attrs.OriginalCFrame = root.CFrame
		end
	end
	
	-- Ensure PlaceRow/PlaceCol exist
	if not data.attrs.PlaceRow or not data.attrs.PlaceCol then
		local root = helper:FindFirstChild("HumanoidRootPart") or helper.PrimaryPart
		if root and data.attrs.GridId then
			-- Derive from grid position
			local gridId = data.attrs.GridId
			local parts = {}
			for part in gridId:gmatch("[^.]+") do
				table.insert(parts, part)
			end
			local current = workspace
			for _, partName in ipairs(parts) do
				current = current:FindFirstChild(partName)
				if not current then break end
			end
			if current and current:IsA("BasePart") and current.Name == "Gridfloor" then
				local grid = current
				local localPos = grid.CFrame:PointToObjectSpace(root.Position)
				local halfX = grid.Size.X / 2
				local halfZ = grid.Size.Z / 2
				if localPos.X >= -halfX and localPos.X <= halfX and localPos.Z >= -halfZ and localPos.Z <= halfZ then
					local x01 = localPos.X + halfX
					local z01 = localPos.Z + halfZ
					local col = math.floor(x01 / GRID_SIZE) + 1
					local row = math.floor(z01 / GRID_SIZE) + 1
					if row >= 1 and row <= 10 and col >= 1 and col <= 10 then
						data.attrs.PlaceRow = row
						data.attrs.PlaceCol = col
					end
				end
			end
		end
	end
	
	return data
end

-- Apply attributes to model
local function applyAttrs(model, attrs)
	for k, v in pairs(attrs) do
		model:SetAttribute(k, v)
	end
end

-- Replace one helper with a fresh clone (from HelperRoundReset)
local function replaceHelper(helper)
	if not helper or not helper.Parent then return nil end
	
	local snap = snapshotHelper(helper)
	local helperType = snap.helperType
	
	local template = helperTemplates:FindFirstChild(helperType)
	if not template then
		warn("[HelperRespawn] Missing template: " .. helperType)
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
		warn("[HelperRespawn] Template is not a Model: " .. helperType)
		return nil
	end
	
	-- Clone
	local newHelper = modelToClone:Clone()
	newHelper.Name = helperType .. "_" .. (snap.attrs.OwnerUserId or "Unknown") .. "_" .. os.time()
	
	-- Disable player collision (prevent players from getting stuck)
	if _G.DisablePlayerCollision then
		_G.DisablePlayerCollision(newHelper)
	end
	
	-- Set PrimaryPart
	local primary = newHelper:FindFirstChild("HumanoidRootPart", true)
		or newHelper.PrimaryPart
		or newHelper:FindFirstChildWhichIsA("BasePart", true)
	if primary then
		newHelper.PrimaryPart = primary
	end
	
	-- Apply attributes
	applyAttrs(newHelper, snap.attrs)
	
	-- Position at original CFrame
	if snap.attrs.OriginalCFrame and typeof(snap.attrs.OriginalCFrame) == "CFrame" then
		newHelper:PivotTo(snap.attrs.OriginalCFrame)
	end
	
	-- Set humanoid health
	local hum = newHelper:FindFirstChildOfClass("Humanoid")
	if hum then
		local starLevel = snap.attrs.StarLevel or 0
		local baseHealth = snap.attrs.BaseHealth or 100
		hum.MaxHealth = baseHealth * (2 ^ starLevel)
		hum.Health = hum.MaxHealth
		
		-- Store original walk speed/jump power
		if newHelper:GetAttribute("OriginalWalkSpeed") == nil then
			newHelper:SetAttribute("OriginalWalkSpeed", hum.WalkSpeed > 0 and hum.WalkSpeed or 16)
		end
		if newHelper:GetAttribute("OriginalJumpPower") == nil then
			newHelper:SetAttribute("OriginalJumpPower", hum.JumpPower > 0 and hum.JumpPower or 50)
		end
	end
	
	-- Parent to Helpers folder
	newHelper.Parent = helpersFolder
	
	-- Reset state
	resetHelperState(newHelper)
	
	-- Destroy old helper
	helper:Destroy()
	
	return newHelper
end

-- Reset all helpers for an island (replace with fresh clones)
_G.ResetHelpersOnIslandRound = function(islandId)
	if typeof(islandId) ~= "number" then
		warn("[HelperRespawn] Invalid islandId:", islandId)
		return
	end
	
	-- Collect all helpers for this island
	local toReset = {}
	for _, helper in ipairs(helpersFolder:GetChildren()) do
		if helper:IsA("Model") then
			local hid = helper:GetAttribute("IslandId")
			if typeof(hid) == "number" and hid == islandId then
				table.insert(toReset, helper)
			end
		end
	end
	
	-- Replace each helper
	for _, helper in ipairs(toReset) do
		replaceHelper(helper)
	end
	
	print("[HelperRespawn] ✅ Reset " .. #toReset .. " helpers for island: " .. islandId)
end

print("[HelperRespawn] ✅ Initialized (merged from HelperRespawnManager + HelperRestore + HelperRoundReset)")
