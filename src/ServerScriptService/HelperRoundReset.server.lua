-- HelperRoundReset.server.lua
-- Replace ALL helpers with fresh clones at wave end (dead or alive)
-- Keeps same attributes + same tile.

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local workspace = game:GetService("Workspace")

local helpersFolder = workspace:WaitForChild("Helpers")

local HELPER_TEMPLATES = ServerStorage:WaitForChild("HelperTemplates")

-- ========== CONFIG ==========
local IMPORTANT_ATTRS = {
	"OwnerUserId",
	"GridId",
	"IslandId",

	"HelperType",      -- recommended
	"PlaceRow",
	"PlaceCol",
	"OriginalCFrame",

	"Star",
	"StarLevel",
	"Rarity",

	"BaseDamage",
	"BaseHealth",
	"BaseRange",
	"BaseCooldown",
	
	"AttackDamage",
	"AttackRange",
	"AttackCooldown",

	-- any other attributes you care about:
	"Synergy",
	"Element",
	"DamageMult",
	"SpecialReady",
	"SpecialCooldown",
	"HasCart",
	"UnitKey",
	"EnemyType",
	"TemplateName",
}

-- Try to infer template name if HelperType missing
local function inferHelperType(helperModel)
	local t = helperModel:GetAttribute("HelperType")
		or helperModel:GetAttribute("HelperName")
		or helperModel:GetAttribute("UnitType")
	
	if typeof(t) == "string" and t ~= "" then
		return t
	end

	-- Fallback: strip suffixes like "_12345" etc
	local name = helperModel.Name
	name = name:gsub("_%d+$", "")
	name = name:gsub(" %d+$", "") -- Also handle "Tweaker 123" format
	return name
end

local function snapshotHelper(helper)
	local data = {
		attrs = {},
		helperType = inferHelperType(helper),
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

	-- Ensure PlaceRow/PlaceCol exist (derive from position if missing)
	if not data.attrs.PlaceRow or not data.attrs.PlaceCol then
		local root = helper:FindFirstChild("HumanoidRootPart") or helper.PrimaryPart
		if root and data.attrs.GridId then
			-- Try to derive from grid position
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
					local GRID_SIZE = 5
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

local function applyAttrs(model, attrs)
	for k, v in pairs(attrs) do
		model:SetAttribute(k, v)
	end
end

local function reviveAndFullHeal(model)
	local hum = model:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	if hum.Health <= 0 then
		hum:ChangeState(Enum.HumanoidStateType.GettingUp)
		hum.Health = 1
	end
	hum.Health = hum.MaxHealth
end

-- Replace one helper with a fresh clone at the same tile
local function replaceHelper(helper)
	if not helper or not helper.Parent then return nil end

	local snap = snapshotHelper(helper)
	local helperType = snap.helperType

	local template = HELPER_TEMPLATES:FindFirstChild(helperType)
	if not template then
		warn("[HelperRoundReset] Missing template in ServerStorage/HelperTemplates:", helperType)
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
		warn("[HelperRoundReset] Template is not a Model:", helperType)
		return nil
	end

	-- Save CFrame before destroying
	local spawnCf = snap.attrs.OriginalCFrame
	local root = helper:FindFirstChild("HumanoidRootPart") or helper.PrimaryPart
	if typeof(spawnCf) ~= "CFrame" and root then
		spawnCf = root.CFrame
	end

	-- Destroy old helper (dead or alive)
	helper:Destroy()

	-- Clone fresh
	local newHelper = modelToClone:Clone()
	newHelper.Name = helperType .. "_" .. (snap.attrs.OwnerUserId or "Unknown") .. "_" .. os.time()

	-- Set PrimaryPart before positioning
	local primary = newHelper:FindFirstChild("HumanoidRootPart", true) 
		or newHelper.PrimaryPart 
		or newHelper:FindFirstChildWhichIsA("BasePart", true)
	if primary then
		newHelper.PrimaryPart = primary
	end

	-- Apply saved attributes back
	applyAttrs(newHelper, snap.attrs)

	-- Pivot to tile
	if typeof(spawnCf) == "CFrame" then
		newHelper:PivotTo(spawnCf)
		newHelper:SetAttribute("OriginalCFrame", spawnCf)
	end

	-- Set humanoid stats based on star level
	local hum = newHelper:FindFirstChildOfClass("Humanoid")
	if hum then
		local starLevel = snap.attrs.StarLevel or snap.attrs.Star or 0
		local baseHealth = snap.attrs.BaseHealth or 100
		hum.MaxHealth = baseHealth * (2 ^ starLevel)
		hum.Health = hum.MaxHealth
		
		-- Store original walk speed/jump power if not set
		if newHelper:GetAttribute("OriginalWalkSpeed") == nil then
			newHelper:SetAttribute("OriginalWalkSpeed", hum.WalkSpeed > 0 and hum.WalkSpeed or 16)
		end
		if newHelper:GetAttribute("OriginalJumpPower") == nil then
			newHelper:SetAttribute("OriginalJumpPower", hum.JumpPower > 0 and hum.JumpPower or 50)
		end
	end

	-- Parent + heal
	newHelper.Parent = helpersFolder
	reviveAndFullHeal(newHelper)

	-- Reset special state (Tweaker cart, etc.)
	if newHelper.Name:find("Tweaker") then
		local restoreCartEvent = ReplicatedStorage:FindFirstChild("RestoreTweakerCart")
		if restoreCartEvent then
			restoreCartEvent:Fire(newHelper)
		end
	end

	-- Freeze helper for prep phase (wave just ended)
	local hum = newHelper:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = 0
		hum.JumpPower = 0
		hum:Move(Vector3.zero)
		newHelper:SetAttribute("Aggressive", false)
		newHelper:SetAttribute("Frozen", true)
	end

	return newHelper
end

-- ========== PUBLIC API ==========
-- Call this from your WaveManager when a wave ends:
_G.ResetHelpersOnIsland = function(islandId)
	if typeof(islandId) ~= "number" then
		warn("[HelperRoundReset] Invalid islandId:", islandId)
		return
	end

	-- Collect helpers for this islandId
	local toReplace = {}
	for _, h in ipairs(helpersFolder:GetChildren()) do
		if h:IsA("Model") then
			local hid = h:GetAttribute("IslandId")
			if typeof(hid) == "number" and hid == islandId then
				table.insert(toReplace, h)
			end
		end
	end

	-- Replace each helper
	for _, h in ipairs(toReplace) do
		replaceHelper(h)
	end

	print("[HelperRoundReset] ✅ Rebuilt " .. #toReplace .. " helpers for island: " .. islandId)
end

print("[HelperRoundReset] ✅ Initialized")
