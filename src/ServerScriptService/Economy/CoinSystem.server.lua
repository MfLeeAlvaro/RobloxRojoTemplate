--========================================================
-- CoinSystem.server.lua
-- Unified coin system: handles coin collection and passive generation
-- Merged from CoinCollectionHandler.server.lua and PassiveCoinGenerator.server.lua
--========================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Create RemoteEvent if it doesn't exist
local collectCoinsEvent = ReplicatedStorage:FindFirstChild("CollectCoinsEvent")
if not collectCoinsEvent then
	collectCoinsEvent = Instance.new("RemoteEvent")
	collectCoinsEvent.Name = "CollectCoinsEvent"
	collectCoinsEvent.Parent = ReplicatedStorage
end

--========================
-- COIN UTILITIES
--========================

-- Get player coins (supports both leaderstats and attributes)
local function getPlayerCoins(player)
	local ls = player:FindFirstChild("leaderstats")
	local coins = ls and ls:FindFirstChild("Coins")
	if coins and coins:IsA("IntValue") then
		return coins.Value
	end
	
	local v = player:GetAttribute("Coins")
	if typeof(v) == "number" then
		return v
	end
	return 0
end

-- Set player coins (supports both leaderstats and attributes)
local function setPlayerCoins(player, amount)
	local ls = player:FindFirstChild("leaderstats")
	local coins = ls and ls:FindFirstChild("Coins")
	if coins and coins:IsA("IntValue") then
		coins.Value = amount
		return
	end
	player:SetAttribute("Coins", amount)
end

-- Add coins to player
local function addCoins(player, amount)
	local current = getPlayerCoins(player)
	setPlayerCoins(player, current + amount)
end

-- Get coins per second for a player
local function getPlayerCoinsPerSec(player)
	local hiddenStats = player:FindFirstChild("HiddenStats")
	if not hiddenStats then return 0 end

	local coinsPerSec = hiddenStats:FindFirstChild("CoinsPerSec")
	if not coinsPerSec then return 0 end

	return coinsPerSec.Value
end

--========================
-- COIN COLLECTION (from CoinCollectionHandler)
--========================

-- Handle coin collection
collectCoinsEvent.OnServerEvent:Connect(function(player)
	print(player.Name .. " is collecting coins")

	-- Get leaderstats for Coins
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then 
		collectCoinsEvent:FireClient(player, false, "<font color='rgb(255,100,100)'>Error: No stats found!</font>")
		return 
	end

	-- Get HiddenStats for AccumulatedCoins and Multiplier
	local hiddenStats = player:FindFirstChild("HiddenStats")
	if not hiddenStats then 
		collectCoinsEvent:FireClient(player, false, "<font color='rgb(255,100,100)'>Error: No hidden stats found!</font>")
		return 
	end

	local coins = leaderstats:FindFirstChild("Coins")
	local accumulatedCoins = hiddenStats:FindFirstChild("AccumulatedCoins")
	local coinMultiplier = hiddenStats:FindFirstChild("CoinMultiplier")

	if not coins or not accumulatedCoins then 
		collectCoinsEvent:FireClient(player, false, "<font color='rgb(255,100,100)'>Error: Stats not found!</font>")
		return 
	end

	local amountToCollect = accumulatedCoins.Value

	if amountToCollect > 0 then
		-- Apply coin multiplier
		local multiplier = coinMultiplier and coinMultiplier.Value or 1
		local finalAmount = math.floor(amountToCollect * multiplier)

		-- Add coins to player
		coins.Value = coins.Value + finalAmount

		-- Reset accumulated
		accumulatedCoins.Value = 0

		print(player.Name .. " collected " .. amountToCollect .. " coins (x" .. multiplier .. " = " .. finalAmount .. " total!)")

		-- Send success message
		local message = "<font color='rgb(100,255,100)'>Collected " .. amountToCollect .. " coins!</font> <font color='rgb(150,255,150)'>(x" .. string.format("%.1f", multiplier) .. " = " .. finalAmount .. " coins added!)</font>"
		collectCoinsEvent:FireClient(player, true, message)
	else
		print(player.Name .. " has no coins to collect")
		collectCoinsEvent:FireClient(player, false, "<font color='rgb(255,200,100)'>You don't have any coins yet!</font>")
	end
end)

--========================
-- PASSIVE COIN GENERATION (from PassiveCoinGenerator)
--========================

task.spawn(function()
	while true do
		task.wait(1)

		for _, player in pairs(Players:GetPlayers()) do
			local hiddenStats = player:FindFirstChild("HiddenStats")
			if not hiddenStats then continue end

			local accumulatedCoins = hiddenStats:FindFirstChild("AccumulatedCoins")
			if not accumulatedCoins then continue end

			local coinsPerSec = getPlayerCoinsPerSec(player)
			if coinsPerSec > 0 then
				accumulatedCoins.Value += coinsPerSec
				print(player.Name .. " generated " .. coinsPerSec .. " coins (Total: " .. accumulatedCoins.Value .. ")")
			end
		end
	end
end)

--========================
-- PUBLIC API
--========================

local CoinSystem = {
	GetCoins = getPlayerCoins,
	SetCoins = setPlayerCoins,
	AddCoins = addCoins,
	GetCoinsPerSec = getPlayerCoinsPerSec,
}

_G.CoinSystem = CoinSystem

print("✅ CoinSystem loaded (merged from CoinCollectionHandler + PassiveCoinGenerator)")
