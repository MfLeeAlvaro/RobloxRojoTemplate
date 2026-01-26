-- ServerScriptService/EnemyMergeServer.server.lua
-- Merges 3 same enemy kind + same star level + same island => 1 unit, stats x2, star+1

local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local enemiesFolder = Workspace:WaitForChild("Enemies")

-- ===== helpers =====
local function getRoot(model)
	return model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
end

local function getUnitKey(model)
	-- Prefer explicit attribute if you set it when spawning
	local k =
		model:GetAttribute("UnitKey")
		or model:GetAttribute("EnemyType")
		or model:GetAttribute("TemplateName")
		or model:GetAttribute("UnitType")

	if typeof(k) == "string" and k ~= "" then
		return k
	end

	-- fallback: strip suffix like "EnemyGrunt_123"
	local base = model.Name:match("^[^_]+")
	return base or model.Name
end

local function getStarLevel(model)
	local s = model:GetAttribute("StarLevel")
	if typeof(s) ~= "number" then
		s = 0
		model:SetAttribute("StarLevel", s)
	end
	return s
end

local function setStarLevel(model, level)
	model:SetAttribute("StarLevel", level)
end

local function ensureStarGui(model)
	local attach = model:FindFirstChild("Head") or getRoot(model)
	if not attach then return end

	local existing = attach:FindFirstChild("StarGui")
	if existing then return end

	-- Compact, subtle star display
	local bb = Instance.new("BillboardGui")
	bb.Name = "StarGui"
	bb.Size = UDim2.fromOffset(100, 30)
	bb.StudsOffset = Vector3.new(0, 2.5, 0)
	bb.AlwaysOnTop = true
	bb.Enabled = false
	bb.Adornee = attach
	bb.Parent = attach

	-- Subtle background frame
	local frame = Instance.new("Frame")
	frame.Name = "StarFrame"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(20, 0, 0)
	frame.BackgroundTransparency = 0.6
	frame.BorderSizePixel = 0
	frame.Parent = bb

	-- Subtle rounded corners
	local uicorner = Instance.new("UICorner")
	uicorner.CornerRadius = UDim.new(0, 6)
	uicorner.Parent = frame

	-- Subtle border
	local border = Instance.new("UIStroke")
	border.Name = "GlowBorder"
	border.Color = Color3.fromRGB(255, 100, 50)
	border.Thickness = 1.5
	border.Transparency = 0.5
	border.Parent = frame

	-- Main star label - clean and simple
	local label = Instance.new("TextLabel")
	label.Name = "StarLabel"
	label.Size = UDim2.fromScale(1, 1)
	label.Position = UDim2.fromOffset(0, 0)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Text = ""
	label.TextColor3 = Color3.fromRGB(255, 150, 50)
	label.TextStrokeTransparency = 0.7
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.Parent = bb
end

local function updateStarGui(model)
	local level = getStarLevel(model)
	ensureStarGui(model)

	local attach = model:FindFirstChild("Head") or getRoot(model)
	if not attach then return end
	local bb = attach:FindFirstChild("StarGui")
	if not bb then return end
	local label = bb:FindFirstChild("StarLabel")
	local frame = bb:FindFirstChild("StarFrame")
	local border = frame and frame:FindFirstChild("GlowBorder")
	
	if not label then return end

	if level <= 0 then
		bb.Enabled = false
	else
		bb.Enabled = true
		
		-- Epic star display with color gradient based on level
		local starText = ""
		local starCount = math.clamp(level, 1, 5)
		
		-- Use different star symbols for visual variety
		for i = 1, starCount do
			starText = starText .. "★"
		end
		
		-- Add level number if over 5 stars
		if level > 5 then
			starText = starText .. " +" .. tostring(level - 5)
		end
		
		label.Text = starText
		
		-- Epic color progression system (same as helpers)
		local color, borderColor
		if level >= 8 then
			-- 8★+ Cosmic/Ascended - White core with rainbow edges
			color = Color3.fromRGB(255, 255, 255) -- White core
			borderColor = Color3.fromRGB(255, 0, 255) -- Will animate to rainbow
		elseif level >= 7 then
			-- 7★ Prismatic/Rainbow - Animated gradient
			color = Color3.fromRGB(255, 0, 0) -- Will cycle through rainbow
			borderColor = Color3.fromRGB(0, 255, 0)
		elseif level >= 6 then
			-- 6★ Crimson Red
			color = Color3.fromRGB(255, 60, 60)
			borderColor = Color3.fromRGB(255, 100, 100)
		elseif level >= 5 then
			-- 5★ Royal Purple
			color = Color3.fromRGB(150, 60, 255)
			borderColor = Color3.fromRGB(180, 100, 255)
		elseif level >= 4 then
			-- 4★ Electric Blue
			color = Color3.fromRGB(0, 190, 255)
			borderColor = Color3.fromRGB(100, 220, 255)
		elseif level >= 3 then
			-- 3★ Emerald Green
			color = Color3.fromRGB(0, 255, 140)
			borderColor = Color3.fromRGB(100, 255, 180)
		elseif level >= 2 then
			-- 2★ Gold
			color = Color3.fromRGB(255, 215, 90)
			borderColor = Color3.fromRGB(255, 235, 150)
		elseif level >= 1 then
			-- 1★ White/Silver
			color = Color3.fromRGB(235, 235, 235)
			borderColor = Color3.fromRGB(255, 255, 255)
		end
		
		if color then
			label.TextColor3 = color
			if border then
				border.Color = borderColor or color
				-- More glow at higher levels
				border.Transparency = level >= 5 and 0.4 or 0.6
			end
			
			-- Special effects for 7★+ (Prismatic/Rainbow)
			if level >= 7 then
				-- Animate rainbow colors
				local rainbowColors = {
					Color3.fromRGB(255, 0, 0),   -- Red
					Color3.fromRGB(255, 127, 0), -- Orange
					Color3.fromRGB(255, 255, 0), -- Yellow
					Color3.fromRGB(0, 255, 0),   -- Green
					Color3.fromRGB(0, 0, 255),   -- Blue
					Color3.fromRGB(75, 0, 130),  -- Indigo
					Color3.fromRGB(148, 0, 211)  -- Violet
				}
				
				local colorIndex = 1
				-- Cycle through rainbow colors
				task.spawn(function()
					while label.Parent and label.Parent.Parent do
						colorIndex = (colorIndex % #rainbowColors) + 1
						label.TextColor3 = rainbowColors[colorIndex]
						if border then
							border.Color = rainbowColors[colorIndex]
						end
						task.wait(0.3)
					end
				end)
			end
			
			-- Special effects for 8★+ (Cosmic/Ascended)
			if level >= 8 then
				-- White core with rainbow border animation
				label.TextColor3 = Color3.fromRGB(255, 255, 255)
				
				-- Animate border through rainbow
				local rainbowColors = {
					Color3.fromRGB(255, 0, 0),   -- Red
					Color3.fromRGB(255, 127, 0), -- Orange
					Color3.fromRGB(255, 255, 0), -- Yellow
					Color3.fromRGB(0, 255, 0),   -- Green
					Color3.fromRGB(0, 0, 255),   -- Blue
					Color3.fromRGB(75, 0, 130),  -- Indigo
					Color3.fromRGB(148, 0, 211)  -- Violet
				}
				
				if border then
					border.Transparency = 0.2 -- More visible for cosmic
					local colorIndex = 1
					task.spawn(function()
						while border.Parent and border.Parent.Parent do
							colorIndex = (colorIndex % #rainbowColors) + 1
							border.Color = rainbowColors[colorIndex]
							task.wait(0.2)
						end
					end)
				end
				
				-- Subtle pulsing glow for cosmic tier
				local pulseInfo = TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
				local pulseTween = TweenService:Create(label, pulseInfo, {
					TextTransparency = 0.3
				})
				pulseTween:Play()
			end
		end
	end
end

-- Apply exponential star scaling from BASE stats only
local function applyStarScaling(unit)
	local star = unit:GetAttribute("StarLevel") or 0

	local baseDamage = unit:GetAttribute("BaseDamage")
	local baseHealth = unit:GetAttribute("BaseHealth")
	local baseRange = unit:GetAttribute("BaseRange")
	local baseCooldown = unit:GetAttribute("BaseCooldown")
	local baseDamageMult = unit:GetAttribute("BaseDamageMult") -- Store original DamageMult

	if baseDamage then
		unit:SetAttribute("AttackDamage", baseDamage * (2 ^ star))
	end

	if baseHealth then
		local hum = unit:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.MaxHealth = baseHealth * (2 ^ star)
			hum.Health = hum.MaxHealth
		end
	end

	-- Range does NOT scale with stars (keeps base range)

	if baseCooldown then
		unit:SetAttribute(
			"AttackCooldown",
			math.max(baseCooldown * (0.9 ^ star), baseCooldown * 0.2)
		)
	end
	
	-- Scale DamageMult if it exists (for wave difficulty scaling)
	if baseDamageMult then
		unit:SetAttribute("DamageMult", baseDamageMult * (2 ^ star))
	end
end

-- ===== merge engine =====
local mergeLockByIsland = {} -- islandId -> true

local function snapshotEnemiesForIsland(islandId)
	local list = {}
	for _, m in ipairs(enemiesFolder:GetChildren()) do
		if m:IsA("Model") and m.Parent then
			if m:GetAttribute("IslandId") == islandId then
				local hum = m:FindFirstChildOfClass("Humanoid")
				if hum and hum.Health > 0 then
					table.insert(list, m)
				end
			end
		end
	end
	return list
end

local function tryMergeIsland(islandId)
	if typeof(islandId) ~= "number" then return end
	if mergeLockByIsland[islandId] then return end
	mergeLockByIsland[islandId] = true

	local merged = true
	while merged do
		merged = false

		local enemies = snapshotEnemiesForIsland(islandId)

		-- group by owner + unitKey + starLevel
		local groups = {}
		for _, e in ipairs(enemies) do
			local owner = e:GetAttribute("TargetUserId") -- Enemies use TargetUserId instead of OwnerUserId
			local key = getUnitKey(e)
			local star = getStarLevel(e)

			local gk = tostring(owner) .. "|" .. key .. "|" .. tostring(star)
			groups[gk] = groups[gk] or {}
			table.insert(groups[gk], e)
		end

		for _, group in pairs(groups) do
			if #group >= 3 then
				local keep, a, b = group[1], group[2], group[3]
				if keep and keep.Parent and a and a.Parent and b and b.Parent then
					-- upgrade keep (increase star level)
					setStarLevel(keep, getStarLevel(keep) + 1)
					-- Apply scaling from BASE stats (exponential: 2^star)
					applyStarScaling(keep)
					updateStarGui(keep)

					-- remove the other two
					a:Destroy()
					b:Destroy()

					merged = true
					break -- restart grouping fresh
				end
			end
		end
	end

	-- refresh star UI for remaining units
	for _, e in ipairs(snapshotEnemiesForIsland(islandId)) do
		updateStarGui(e)
	end

	mergeLockByIsland[islandId] = nil
end

-- Function to get IslandId from GridId (fallback for backwards compatibility)
local function getIslandIdFromGridId(gridId)
	if not gridId or typeof(gridId) ~= "string" then return nil end
	
	local gridPart = workspace:FindFirstChild(gridId, true)
	if not gridPart then return nil end
	
	-- Walk up the hierarchy to find Island model
	local current = gridPart
	while current and current.Parent and current.Parent ~= workspace do
		if current:IsA("Model") then
			local islandId = current:GetAttribute("IslandId")
			if typeof(islandId) == "number" then
				return islandId
			end
		end
		current = current.Parent
	end
	
	return nil
end

-- ===== hook: whenever an enemy is added =====
enemiesFolder.ChildAdded:Connect(function(enemy)
	if not enemy:IsA("Model") then return end

	-- let attributes replicate/set by spawn scripts
	task.wait(0.05)

	-- Get IslandId - try direct attribute first, then fallback to GridId resolution
	local islandId = enemy:GetAttribute("IslandId")
	if typeof(islandId) ~= "number" then
		-- Fallback: resolve from GridId
		local gridId = enemy:GetAttribute("GridId")
		if gridId then
			islandId = getIslandIdFromGridId(gridId)
			if islandId then
				-- Cache it for next time
				enemy:SetAttribute("IslandId", islandId)
			end
		end
	end
	
	if typeof(islandId) ~= "number" then
		-- Cannot merge without IslandId
		return
	end

	-- init star + ui
	if enemy:GetAttribute("StarLevel") == nil then
		enemy:SetAttribute("StarLevel", 0)
	end
	
	-- Ensure base stats are stored (if not already set by spawn script)
	if enemy:GetAttribute("BaseDamage") == nil then
		local currentDamage = enemy:GetAttribute("AttackDamage") or 8
		enemy:SetAttribute("BaseDamage", currentDamage)
	end
	if enemy:GetAttribute("BaseHealth") == nil then
		local hum = enemy:FindFirstChildOfClass("Humanoid")
		if hum then
			enemy:SetAttribute("BaseHealth", hum.MaxHealth)
		end
	end
	if enemy:GetAttribute("BaseRange") == nil then
		local currentRange = enemy:GetAttribute("AttackRange") or 7
		enemy:SetAttribute("BaseRange", currentRange)
	end
	if enemy:GetAttribute("BaseCooldown") == nil then
		local currentCooldown = enemy:GetAttribute("AttackCooldown") or 1.3
		enemy:SetAttribute("BaseCooldown", currentCooldown)
	end
	if enemy:GetAttribute("BaseDamageMult") == nil then
		local currentMult = enemy:GetAttribute("DamageMult") or 1
		enemy:SetAttribute("BaseDamageMult", currentMult)
	end
	
	-- Apply initial scaling (star 0 = 1x multiplier)
	applyStarScaling(enemy)
	updateStarGui(enemy)

	-- merge attempt
	tryMergeIsland(islandId)
end)
