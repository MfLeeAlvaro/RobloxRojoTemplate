local Players = game:GetService("Players")

local function getPlayerCoinsPerSec(player)
	local hiddenStats = player:FindFirstChild("HiddenStats")
	if not hiddenStats then return 0 end

	local coinsPerSec = hiddenStats:FindFirstChild("CoinsPerSec")
	if not coinsPerSec then return 0 end

	return coinsPerSec.Value
end

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
