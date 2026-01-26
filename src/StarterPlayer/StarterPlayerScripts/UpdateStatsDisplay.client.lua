local Players = game:GetService("Players")
local player = Players.LocalPlayer

print("=== UpdateStatsDisplay Debug Start ===")
print("Player: " .. player.Name)

-- Wait for the StatsDisplay to exist in Workspace
local statsDisplay = workspace:WaitForChild("StatsDisplay", 10)
if not statsDisplay then
	warn("StatsDisplay not found in Workspace!")
	return
end
print("✅ StatsDisplay found")

local surfaceGui = statsDisplay:WaitForChild("SurfaceGui", 5)
if not surfaceGui then
	warn("SurfaceGui not found!")
	return
end
print("✅ SurfaceGui found")

local frame = surfaceGui:WaitForChild("Frame", 5)
if not frame then
	warn("Frame not found!")
	return
end
print("✅ Frame found")

-- List ALL children in Frame
print("=== Frame Children ===")
for _, child in pairs(frame:GetChildren()) do
	print("  - " .. child.Name .. " (" .. child.ClassName .. ")")
end
print("======================")

-- Try to find each label
print("Looking for labels...")

local accumulatedLabel = frame:FindFirstChild("AccumulatedCoins")
if accumulatedLabel then
	print("✅ AccumulatedCoins found")
else
	warn("❌ AccumulatedCoins NOT FOUND")
end

local passiveLabel = frame:FindFirstChild("PassiveIncome")
if passiveLabel then
	print("✅ PassiveIncome found")
else
	warn("❌ PassiveIncome NOT FOUND")
end

local coinMultLabel = frame:FindFirstChild("CoinMultiplier")
if coinMultLabel then
	print("✅ CoinMultiplier found")
else
	warn("❌ CoinMultiplier NOT FOUND")
end

local damageMultLabel = frame:FindFirstChild("DamageMultiplier")
if damageMultLabel then
	print("✅ DamageMultiplier found")
else
	warn("❌ DamageMultiplier NOT FOUND")
end

if not accumulatedLabel or not passiveLabel or not coinMultLabel or not damageMultLabel then
	warn("❌ Some labels are missing! Check the names above.")
	return
end

print("✅ All UI elements found! Starting update loop...")

-- Function to format numbers
local function formatNumber(num)
	local formatted = tostring(math.floor(num))
	local k
	while true do
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
		if k == 0 then break end
	end
	return formatted
end

-- Update loop
local updateCount = 0
while true do
	task.wait(1)
	updateCount = updateCount + 1

	print("=== Update #" .. updateCount .. " ===")

	local hiddenStats = player:FindFirstChild("HiddenStats")
	if hiddenStats then
		local accumulated = hiddenStats:FindFirstChild("AccumulatedCoins")
		local coinsPerSec = hiddenStats:FindFirstChild("CoinsPerSec")
		local coinMult = hiddenStats:FindFirstChild("CoinMultiplier")
		local damageMult = hiddenStats:FindFirstChild("DamageMultiplier")

		if accumulated then
			print("  Setting AccumulatedCoins to: " .. accumulated.Value)
			accumulatedLabel.Text = "💰 Accumulated: " .. formatNumber(accumulated.Value) .. " coins"
		end

		if coinsPerSec then
			print("  Setting PassiveIncome to: " .. coinsPerSec.Value)
			passiveLabel.Text = "⚡ Passive: " .. formatNumber(coinsPerSec.Value) .. " coins/sec"
		end

		if coinMult then
			print("  Setting CoinMultiplier to: " .. coinMult.Value)
			coinMultLabel.Text = "📈 Coin Multiplier: " .. string.format("%.1f", coinMult.Value) .. "x"
		end

		if damageMult then
			print("  Setting DamageMultiplier to: " .. damageMult.Value)
			damageMultLabel.Text = "⚔️ Damage: " .. string.format("%.2f", damageMult.Value) .. "x"
		end
	else
		warn("HiddenStats not found!")
	end
end