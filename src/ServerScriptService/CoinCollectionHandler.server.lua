local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Create RemoteEvent if it doesn't exist
local collectCoinsEvent = ReplicatedStorage:FindFirstChild("CollectCoinsEvent")
if not collectCoinsEvent then
	collectCoinsEvent = Instance.new("RemoteEvent")
	collectCoinsEvent.Name = "CollectCoinsEvent"
	collectCoinsEvent.Parent = ReplicatedStorage
end

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