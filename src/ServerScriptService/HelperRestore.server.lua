-- HelperRestore.server.lua
-- Restore ALL helpers (dead or alive) at wave end
-- Makes them visible, revives them, resets position and state

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local workspace = game:GetService("Workspace")

local helpersFolder = workspace:WaitForChild("Helpers")

-- Restore visibility of a helper
local function restoreVisibility(helper)
	for _, part in ipairs(helper:GetDescendants()) do
		if part:IsA("BasePart") then
			-- Restore original transparency
			local origTrans = part:GetAttribute("OriginalTransparency")
			if origTrans ~= nil then
				part.Transparency = origTrans
			else
				part.Transparency = 0
			end
			
			-- Restore original CanCollide
			local origCanCollide = part:GetAttribute("OriginalCanCollide")
			if origCanCollide ~= nil then
				part.CanCollide = origCanCollide
			else
				part.CanCollide = true
			end
		elseif part:IsA("Decal") or part:IsA("Texture") then
			-- Restore original transparency
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
			-- Stop all velocity
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
	end
	
	-- Heal to full
	hum.Health = hum.MaxHealth
	
	-- Reset physics state
	local root = helper:FindFirstChild("HumanoidRootPart") or helper.PrimaryPart
	if root then
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		-- Unanchor if it was anchored
		if root.Anchored then
			root.Anchored = false
		end
	end
end

-- Reset helper state (special flags, cooldowns, etc.)
local function resetHelperState(helper)
	-- Clear dead flag
	helper:SetAttribute("Dead", false)
	
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

-- Restore a single helper
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

-- Restore all helpers for an island (including Dead=true ones)
_G.RestoreHelpersOnIsland = function(islandId)
	if typeof(islandId) ~= "number" then
		warn("[HelperRestore] Invalid islandId:", islandId)
		return
	end
	
	-- Collect ALL helpers for this island (including hidden/dead ones)
	local toRestore = {}
	for _, helper in ipairs(helpersFolder:GetChildren()) do
		if helper:IsA("Model") then
			local hid = helper:GetAttribute("IslandId")
			if typeof(hid) == "number" and hid == islandId then
				-- Include ALL helpers, even if Dead=true
				table.insert(toRestore, helper)
			end
		end
	end
	
	-- Restore each helper (dead or alive)
	for _, helper in ipairs(toRestore) do
		-- Safety: skip if helper was destroyed (shouldn't happen, but be safe)
		if helper and helper.Parent == helpersFolder then
			restoreHelper(helper)
		end
	end
	
	print("[HelperRestore] ✅ Restored " .. #toRestore .. " helpers for island: " .. islandId)
end

print("[HelperRestore] ✅ Initialized")
