-- ServerScriptService/TweakerCharge.server.lua
-- Tweaker special: super-fast straight-line charge using ShoppingCart, breaks cart on impact, then melee.

local RunService = game:GetService("RunService")
local workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local helpersFolder = workspace:WaitForChild("Helpers")
local enemiesFolder = workspace:WaitForChild("Enemies")
local helperTemplates = ServerStorage:WaitForChild("HelperTemplates")

-- Wave state tracking
local waveActiveFlags = {} -- [islandId] = true/false

-- Listen for wave state changes from WaveManagerServer
local waveStateEvent = ReplicatedStorage:FindFirstChild("WaveStateEvent")
if not waveStateEvent then
	-- Create it if it doesn't exist (WaveManagerServer will also create it)
	waveStateEvent = Instance.new("BindableEvent")
	waveStateEvent.Name = "WaveStateEvent"
	waveStateEvent.Parent = ReplicatedStorage
end

waveStateEvent.Event:Connect(function(islandId, isActive)
	if typeof(islandId) == "number" then
		waveActiveFlags[islandId] = isActive
		print("[TweakerCharge] Wave state updated: Island " .. islandId .. " = " .. tostring(isActive))
	end
end)

-- Get island ID from helper
local function getIslandIdFromHelper(helper)
	local islandId = helper:GetAttribute("IslandId")
	if typeof(islandId) == "number" then
		return islandId
	end
	
	-- Try to get from GridId
	local gridId = helper:GetAttribute("GridId")
	if gridId and typeof(gridId) == "string" then
		-- Find grid and walk up to island
		local parts = {}
		for part in gridId:gmatch("[^.]+") do
			table.insert(parts, part)
		end
		local current = workspace
		for _, partName in ipairs(parts) do
			current = current:FindFirstChild(partName)
			if not current then return nil end
		end
		
		-- Walk up to find Island model
		while current and current.Parent and current.Parent ~= workspace do
			if current:IsA("Model") then
				local id = current:GetAttribute("IslandId")
				if typeof(id) == "number" then
					return id
				end
			end
			current = current.Parent
		end
	end
	
	return nil
end

-- Check if wave is active for a helper
local function isWaveActiveForHelper(helper)
	local islandId = getIslandIdFromHelper(helper)
	if not islandId then 
		-- If no islandId, allow charging (backwards compatibility)
		return true
	end
	-- If wave state is explicitly false, don't charge. Otherwise allow (default to true if not set)
	local isActive = waveActiveFlags[islandId] ~= false
	return isActive
end

-- ========= CONFIG =========
local CHARGE_COOLDOWN = 7.0
local CHARGE_RANGE = 55            -- studs forward
local CHARGE_SPEED = 140           -- studs/sec (FAST)
local CHARGE_HIT_RADIUS = 5        -- how close to count as "impact"
local MASSIVE_DAMAGE_MULT = 6      -- baseDamage * mult * this

-- ========= STATE =========
local lastChargeTime = {}          -- [Model] = os.clock()
local isCharging = {}              -- [Model] = true/false
local weldedTweakers = {}          -- [Model] = true (tracks which Tweakers have welded carts)
local brokenCarts = {}             -- [Model] = cart (store broken carts for restoration)

-- ========= HELPERS =========
local function getRoot(model)
	return model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
end

local function getHum(model)
	return model:FindFirstChildOfClass("Humanoid")
end

local function starMult(npc)
	local star = npc:GetAttribute("Star") or 0
	return 2 ^ star
end

local function hasShoppingCart(npc)
	-- Your Tweaker has a "ShoppingCart" instance in the model tree 
	return npc:FindFirstChild("ShoppingCart", true) ~= nil
end

local function weldShoppingCart(tweaker)
	local cart = tweaker:FindFirstChild("ShoppingCart", true)
	local hrp = getRoot(tweaker)
	
	if not cart or not hrp then return false end
	
	-- Check if already welded
	if weldedTweakers[tweaker] then return true end
	
	-- Weld all BaseParts in the cart to HumanoidRootPart
	for _, part in ipairs(cart:GetDescendants()) do
		if part:IsA("BasePart") then
			-- Unanchor and disable collision
			part.Anchored = false
			part.CanCollide = false
			
			-- Create weld constraint
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = hrp
			weld.Part1 = part
			weld.Parent = part
		end
	end
	
	weldedTweakers[tweaker] = true
	tweaker:SetAttribute("HasCart", true)
	return true
end

local function breakShoppingCart(npc)
	local cart = npc:FindFirstChild("ShoppingCart", true)
	if not cart then return end

	-- Break welds by destroying all WeldConstraints
	for _, part in ipairs(cart:GetDescendants()) do
		if part:IsA("BasePart") then
			-- Destroy any weld constraints
			for _, constraint in ipairs(part:GetChildren()) do
				if constraint:IsA("WeldConstraint") then
					constraint:Destroy()
				end
			end
			
			-- Enable physics and toss it
			part.Anchored = false
			part.CanCollide = true
			part.AssemblyLinearVelocity = Vector3.new(
				(math.random() - 0.5) * 60,
				math.random() * 40 + 25,
				(math.random() - 0.5) * 60
			)
			part.AssemblyAngularVelocity = Vector3.new(
				(math.random() - 0.5) * 20,
				(math.random() - 0.5) * 20,
				(math.random() - 0.5) * 20
			)
		end
	end

	-- Store cart reference before detaching (for potential restoration)
	brokenCarts[npc] = cart

	-- Detach by reparenting to workspace so it no longer follows Tweaker
	cart.Parent = workspace
	
	-- Clean up after 2 seconds (but we'll restore it before that if wave ends)
	task.delay(2.0, function()
		if cart and cart.Parent and brokenCarts[npc] == cart then
			cart:Destroy()
			brokenCarts[npc] = nil
		end
	end)

	-- Mark as no longer welded
	weldedTweakers[npc] = nil
	npc:SetAttribute("HasCart", false)
end

local function restoreShoppingCart(tweaker)
	-- Reset charge state
	isCharging[tweaker] = nil
	lastChargeTime[tweaker] = nil
	
	-- Check if cart still exists (not destroyed yet)
	local cart = brokenCarts[tweaker]
	if cart and cart.Parent then
		-- Cart still exists, restore it
		cart.Parent = tweaker
		-- Re-weld it
		weldShoppingCart(tweaker)
		brokenCarts[tweaker] = nil
		return true
	end
	
	-- Cart was destroyed, need to clone from template
	local tweakerName = tweaker.Name:match("^[^_]+") or "Tweaker" -- Get base name
	local template = helperTemplates:FindFirstChild(tweakerName, true)
	if not template then
		-- Try finding any Tweaker template
		for _, child in ipairs(helperTemplates:GetChildren()) do
			if child.Name:find("Tweaker") then
				template = child
				if template:IsA("Folder") then
					template = template:FindFirstChildOfClass("Model")
				end
				break
			end
		end
	end
	
	if template then
		-- Find cart in template
		local cartTemplate = template:FindFirstChild("ShoppingCart", true)
		if cartTemplate then
			-- Clone the cart
			local newCart = cartTemplate:Clone()
			newCart.Parent = tweaker
			-- Re-weld it
			weldShoppingCart(tweaker)
			brokenCarts[tweaker] = nil
			return true
		end
	end
	
	brokenCarts[tweaker] = nil
	return false
end

-- Reset all Tweaker state for helpers on an island (unused - blueprints handle this)
local function _resetTweakerStateForIsland(helpers)
	for _, helper in ipairs(helpers) do
		if helper:IsA("Model") and helper.Name:find("Tweaker") then
			-- Reset charge state
			isCharging[helper] = nil
			lastChargeTime[helper] = nil
			
			-- Restore cart if broken
			if helper:GetAttribute("HasCart") == false or not hasShoppingCart(helper) then
				restoreShoppingCart(helper)
			end
		end
	end
end

local function findNearestEnemyInFront(npc, maxDist)
	local root = getRoot(npc)
	if not root then return nil end

	local best, bestDist = nil, maxDist
	for _, enemy in ipairs(enemiesFolder:GetChildren()) do
		if enemy:IsA("Model") then
			local eh = getHum(enemy)
			local er = getRoot(enemy)
			if eh and eh.Health > 0 and er then
				local toEnemy = er.Position - root.Position
				local dist = toEnemy.Magnitude
				if dist <= bestDist then
					-- must be roughly in front
					local forward = root.CFrame.LookVector
					local dir = toEnemy.Unit
					local dot = forward:Dot(dir)
					if dot > 0.35 then
						best, bestDist = enemy, dist
					end
				end
			end
		end
	end

	return best
end

local function canCharge(npc)
	if isCharging[npc] then return false end
	local now = os.clock()
	local last = lastChargeTime[npc] or 0
	return (now - last) >= CHARGE_COOLDOWN
end

local function dealMassiveDamage(tweaker, enemy)
	local enemyHum = getHum(enemy)
	if not enemyHum or enemyHum.Health <= 0 then return end

	-- Use your existing damage attribute if present (fallback 12)
	local baseDamage = tweaker:GetAttribute("AttackDamage") or 12
	local dmg = math.floor(baseDamage * starMult(tweaker) * MASSIVE_DAMAGE_MULT)

	enemyHum:TakeDamage(dmg)
end

local function doCharge(tweaker)
	local hum = getHum(tweaker)
	local root = getRoot(tweaker)
	if not hum or not root then return end
	if not hasShoppingCart(tweaker) then return end
	if tweaker:GetAttribute("Aggressive") ~= true then return end
	if not canCharge(tweaker) then return end
	
	-- Check if wave is active - no charging outside of waves
	if not isWaveActiveForHelper(tweaker) then
		return
	end

	lastChargeTime[tweaker] = os.clock()
	isCharging[tweaker] = true

	-- Lock into straight line
	local startPos = root.Position
	local forward = root.CFrame.LookVector

	-- Make it feel snappy
	local oldWS = hum.WalkSpeed
	hum.WalkSpeed = 0
	hum:Move(Vector3.zero)

	-- Make server authoritative movement
	root:SetNetworkOwner(nil)

	-- Use LinearVelocity (newer) if possible
	local att = Instance.new("Attachment")
	att.Parent = root

	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = att
	lv.MaxForce = math.huge
	lv.VectorVelocity = forward * CHARGE_SPEED
	lv.Parent = root

	local hitEnemy = nil
	local startTime = os.clock()

	-- Charge loop: stop if hit, time exceeded, or reached distance
	while tweaker.Parent and hum.Health > 0 do
		local elapsed = os.clock() - startTime
		local traveled = (root.Position - startPos).Magnitude

		-- Impact check (enemy in front + close)
		local candidate = findNearestEnemyInFront(tweaker, 20)
		if candidate then
			local er = getRoot(candidate)
			if er and (er.Position - root.Position).Magnitude <= CHARGE_HIT_RADIUS then
				hitEnemy = candidate
				break
			end
		end

		if elapsed >= (CHARGE_RANGE / CHARGE_SPEED) + 0.25 then
			break
		end
		if traveled >= CHARGE_RANGE then
			break
		end

		RunService.Heartbeat:Wait()
	end

	-- Stop movement
	if lv then lv:Destroy() end
	if att then att:Destroy() end

	-- If we hit: massive dmg + break cart
	if hitEnemy and hitEnemy.Parent then
		dealMassiveDamage(tweaker, hitEnemy)
		breakShoppingCart(tweaker)
	end

	-- Return to melee (your normal system)
	hum.WalkSpeed = oldWS > 0 and oldWS or 16
	isCharging[tweaker] = nil
end

-- ========= MAIN =========
-- Listen for cart restoration requests
local restoreCartEvent = ReplicatedStorage:FindFirstChild("RestoreTweakerCart")
if not restoreCartEvent then
	restoreCartEvent = Instance.new("BindableEvent")
	restoreCartEvent.Name = "RestoreTweakerCart"
	restoreCartEvent.Parent = ReplicatedStorage
end

restoreCartEvent.Event:Connect(function(tweaker)
	if tweaker and tweaker.Parent and tweaker.Name:find("Tweaker") then
		restoreShoppingCart(tweaker)
	end
end)

-- Auto-weld carts when Tweakers are added
helpersFolder.ChildAdded:Connect(function(helper)
	if not helper:IsA("Model") then return end
	if not helper.Name:find("Tweaker") then return end
	
	-- Wait a bit for model to fully load
	task.wait(0.1)
	
	-- Try to weld the cart if it exists
	if hasShoppingCart(helper) then
		weldShoppingCart(helper)
	end
end)

-- Only Tweaker helpers do this (by model name)
RunService.Heartbeat:Connect(function()
	for _, helper in ipairs(helpersFolder:GetChildren()) do
		if helper:IsA("Model") and helper.Name:find("Tweaker") then
			-- Auto-weld cart if it exists but isn't welded yet
			if hasShoppingCart(helper) and not weldedTweakers[helper] then
				weldShoppingCart(helper)
			end
			
			-- Only run if they have the cart (or HasCart attribute true)
			if (helper:GetAttribute("HasCart") ~= false) and hasShoppingCart(helper) then
				-- Check if wave is active (defaults to true if not set)
				local waveActive = isWaveActiveForHelper(helper)
				if not waveActive then
					continue
				end
				
				-- Check if already charging
				if isCharging[helper] then
					continue
				end
				
				-- Try charge when an enemy exists in front (avoid charging into nothing constantly)
				local target = findNearestEnemyInFront(helper, 35)
				if target then
					task.spawn(doCharge, helper)
				end
			end
		end
	end
end)
