local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")

-- RemoteEvents
local buyHelperEvent = ReplicatedStorage:WaitForChild("BuyHelperEvent")
local helperResponseEvent = ReplicatedStorage:WaitForChild("HelperResponseEvent")
local getHelperPriceEvent = ReplicatedStorage:WaitForChild("GetHelperPriceEvent")

-- Get the helper template
local templatesFolder = ServerStorage:WaitForChild("HelperTemplates")

-- Build a stable list of templates (Models/NPCs) to cycle through
local helperTemplates = {}
for _, inst in ipairs(templatesFolder:GetChildren()) do
	if inst:IsA("Model") then
		table.insert(helperTemplates, inst)
	end
end

-- Keep the order consistent (important)
table.sort(helperTemplates, function(a, b)
	return a.Name < b.Name
end)

if #helperTemplates == 0 then
	error("HelperTemplates folder has no Model templates!")
end


-- Find the platforms folder
local platformsFolder = workspace:WaitForChild("IndigenousPlatform")

-- Settings
local BASE_HELPER_COST = 100
local MAX_HELPERS = 7

-- Track how many helpers each player has
local playerHelperCount = {}
local playerMultipliers = {}

-- Helper bonuses (coins/sec, coin multiplier %, damage multiplier %)
local HELPER_BONUSES = {
	{coinsPerSec = 10, coinBonus = 0.10, damageBonus = 0.05},  -- Helper 1
	{coinsPerSec = 25, coinBonus = 0.25, damageBonus = 0.10},  -- Helper 2
	{coinsPerSec = 60, coinBonus = 0.50, damageBonus = 0.20},  -- Helper 3
	{coinsPerSec = 150, coinBonus = 1.00, damageBonus = 0.35}, -- Helper 4
	{coinsPerSec = 375, coinBonus = 2.00, damageBonus = 0.50}, -- Helper 5
	{coinsPerSec = 940, coinBonus = 4.00, damageBonus = 0.75}, -- Helper 6
	{coinsPerSec = 2350, coinBonus = 8.00, damageBonus = 1.00} -- Helper 7
}

-- Function to calculate total multipliers for a player
local function updatePlayerMultipliers(player)
	if not playerMultipliers[player] then
		playerMultipliers[player] = {
			totalCoinBonus = 0,
			totalDamageBonus = 0,
			totalCoinsPerSec = 0
		}
	end

	local totalCoinBonus = 0
	local totalDamageBonus = 0
	local totalCoinsPerSec = 0

	-- Add up bonuses from all helpers
	for i = 1, playerHelperCount[player] or 0 do
		local bonuses = HELPER_BONUSES[i]
		totalCoinBonus = totalCoinBonus + bonuses.coinBonus
		totalDamageBonus = totalDamageBonus + bonuses.damageBonus
		totalCoinsPerSec = totalCoinsPerSec + bonuses.coinsPerSec
	end

	playerMultipliers[player].totalCoinBonus = totalCoinBonus
	playerMultipliers[player].totalDamageBonus = totalDamageBonus
	playerMultipliers[player].totalCoinsPerSec = totalCoinsPerSec

	-- Store in player's HIDDENSTATS instead of leaderstats
	local hiddenStats = player:FindFirstChild("HiddenStats")
	if hiddenStats then
		-- Update or create multiplier values
		local coinMultiplier = hiddenStats:FindFirstChild("CoinMultiplier")
		if not coinMultiplier then
			coinMultiplier = Instance.new("NumberValue")
			coinMultiplier.Name = "CoinMultiplier"
			coinMultiplier.Parent = hiddenStats
		end
		coinMultiplier.Value = 1 + totalCoinBonus

		local damageMultiplier = hiddenStats:FindFirstChild("DamageMultiplier")
		if not damageMultiplier then
			damageMultiplier = Instance.new("NumberValue")
			damageMultiplier.Name = "DamageMultiplier"
			damageMultiplier.Parent = hiddenStats
		end
		damageMultiplier.Value = 1 + totalDamageBonus

		local coinsPerSec = hiddenStats:FindFirstChild("CoinsPerSec")
		if not coinsPerSec then
			coinsPerSec = Instance.new("NumberValue")
			coinsPerSec.Name = "CoinsPerSec"
			coinsPerSec.Parent = hiddenStats
		end
		coinsPerSec.Value = totalCoinsPerSec
	end

	print(player.Name .. " multipliers updated - Coin: " .. (1 + totalCoinBonus) .. "x, Damage: " .. (1 + totalDamageBonus) .. "x, Passive: " .. totalCoinsPerSec .. "/sec")
end

-- When a player tries to buy a helper
buyHelperEvent.OnServerEvent:Connect(function(player)
	print(player.Name .. " is trying to buy a helper")

	if not playerHelperCount[player] then
		playerHelperCount[player] = 0
	end

	if playerHelperCount[player] >= MAX_HELPERS then
		print(player.Name .. " already has max helpers")
		helperResponseEvent:FireClient(player, false, "<font color='rgb(255,100,100)'>You already have the maximum number of helpers!</font>")
		return
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then 
		warn("Player doesn't have leaderstats")
		helperResponseEvent:FireClient(player, false, "<font color='rgb(255,100,100)'>Error: No stats found!</font>")
		return 
	end

	local coins = leaderstats:FindFirstChild("Coins")
	if not coins then 
		warn("Player doesn't have Coins")
		helperResponseEvent:FireClient(player, false, "<font color='rgb(255,100,100)'>Error: No coins found!</font>")
		return 
	end

	local helperCost = BASE_HELPER_COST * (5 ^ playerHelperCount[player])
	print("Cost for helper #" .. (playerHelperCount[player] + 1) .. " is " .. helperCost)

	if coins.Value >= helperCost then
		print(player.Name .. " has enough coins")
		coins.Value = coins.Value - helperCost

		playerHelperCount[player] = playerHelperCount[player] + 1
		local helperNumber = playerHelperCount[player]

		print("Spawning helper #" .. helperNumber .. " for " .. player.Name)

		local platformName = "Platform " .. helperNumber
		local spawnPlatform = platformsFolder:FindFirstChild(platformName)

		if not spawnPlatform then
			warn("Platform '" .. platformName .. "' not found!")
			helperResponseEvent:FireClient(player, false, "<font color='rgb(255,100,100)'>Error: Platform not found!</font>")
			coins.Value = coins.Value + helperCost
			playerHelperCount[player] = playerHelperCount[player] - 1
			return
		end

		print("Found platform: " .. platformName)

		-- Cycle through templates in ServerStorage/HelperTemplates
		local templateIndex = ((helperNumber - 1) % #helperTemplates) + 1
		local chosenTemplate = helperTemplates[templateIndex]
		local helperTypeName = chosenTemplate.Name

		local newHelper = chosenTemplate:Clone()
		newHelper.Name = helperTypeName .. " " .. helperNumber


		local platformPosition = spawnPlatform.Position
		local platformSize = spawnPlatform.Size

		local spawnPosition = Vector3.new(
			platformPosition.X,
			platformPosition.Y + (platformSize.Y / 2) + 0.5,
			platformPosition.Z
		)

		newHelper.Parent = workspace
		newHelper:PivotTo(CFrame.new(spawnPosition))

		local humanoid = newHelper:WaitForChild("Humanoid")
		local animator = humanoid:WaitForChild("Animator")

		local idleAnimation = Instance.new("Animation")
		idleAnimation.AnimationId = "rbxassetid://115691907219551"

		local idleAnimTrack = animator:LoadAnimation(idleAnimation)
		idleAnimTrack.Looped = true
		idleAnimTrack:Play()

		print("Playing idle animation for helper #" .. helperNumber)
		print("Successfully spawned helper #" .. helperNumber)

		-- UPDATE MULTIPLIERS - THIS IS THE KEY LINE!
		updatePlayerMultipliers(player)

		-- Get bonuses for message
		local bonuses = HELPER_BONUSES[helperNumber]
		local bonusText = "<font color='rgb(150,255,150)'>+" .. (bonuses.coinBonus * 100) .. "% coins, +" .. (bonuses.damageBonus * 100) .. "% damage, +" .. bonuses.coinsPerSec .. " coins/sec</font>"

		local remainingSlots = MAX_HELPERS - playerHelperCount[player]
		if remainingSlots > 0 then
			helperResponseEvent:FireClient(player, true, "<font color='rgb(100,255,100)'>Helper purchased!</font> " .. bonusText .. " You have <font color='rgb(255,220,127)'>" .. remainingSlots .. "</font> slots remaining.")
		else
			helperResponseEvent:FireClient(player, true, "<font color='rgb(100,255,100)'>Helper purchased!</font> " .. bonusText .. " <font color='rgb(255,220,127)'>Max helpers!</font>")
		end

	else
		print(player.Name .. " doesn't have enough coins")
		local needed = helperCost - coins.Value
		helperResponseEvent:FireClient(player, false, "<font color='rgb(255,100,100)'>Not enough coins!</font> You need <font color='rgb(255,220,127)'>" .. needed .. "</font> more coins.")
	end
end)

Players.PlayerRemoving:Connect(function(player)
	playerHelperCount[player] = nil
	playerMultipliers[player] = nil
	print(player.Name .. " left, cleaned up helper data")
end)

getHelperPriceEvent.OnServerEvent:Connect(function(player)
	print("Server received price request from " .. player.Name)

	if not playerHelperCount[player] then
		playerHelperCount[player] = 0
	end

	local nextHelperCost = BASE_HELPER_COST * (5 ^ playerHelperCount[player])
	local helperCount = playerHelperCount[player]

	print("Sending price " .. nextHelperCost .. " to " .. player.Name)

	getHelperPriceEvent:FireClient(player, nextHelperCost, helperCount)
end)

-- Initialize multipliers when player joins
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		wait(1)
		updatePlayerMultipliers(player)
	end)
end)