local Players = game:GetService("Players")

Players.PlayerAdded:Connect(function(player)
	-- Leaderstats (visible)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Value = 500 -- change as you want
	coins.Parent = leaderstats

	-- Hidden stats
	local hiddenStats = Instance.new("Folder")
	hiddenStats.Name = "HiddenStats"
	hiddenStats.Parent = player

	local accumulatedCoins = Instance.new("IntValue")
	accumulatedCoins.Name = "AccumulatedCoins"
	accumulatedCoins.Value = 0
	accumulatedCoins.Parent = hiddenStats

	local coinMultiplier = Instance.new("NumberValue")
	coinMultiplier.Name = "CoinMultiplier"
	coinMultiplier.Value = 1
	coinMultiplier.Parent = hiddenStats

	local damageMultiplier = Instance.new("NumberValue")
	damageMultiplier.Name = "DamageMultiplier"
	damageMultiplier.Value = 1
	damageMultiplier.Parent = hiddenStats

	local coinsPerSec = Instance.new("NumberValue")
	coinsPerSec.Name = "CoinsPerSec"
	coinsPerSec.Value = 0
	coinsPerSec.Parent = hiddenStats
end)
