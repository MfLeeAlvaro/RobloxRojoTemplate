-- dialogScript.lua
-- HoboSeller NPC dialog script
-- Opens shop UI when player confirms "Yes, buy a helper"

-- services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
--modules
local DialogModule = require(ReplicatedStorage.Modules.DialogModule)
--references
local player = game.Players.LocalPlayer
local npc = script.Parent
local _npcGui = npc:WaitForChild("Head"):WaitForChild("gui")
local prompt = npc:WaitForChild("ProximityPrompt")

-- RemoteEvents
local getHelperPriceEvent = ReplicatedStorage:WaitForChild("GetHelperPriceEvent")
local requestHelperShopList = ReplicatedStorage:FindFirstChild("RequestHelperShopList")

-- Create new RemoteEvent for collecting coins
local collectCoinsEvent = ReplicatedStorage:FindFirstChild("CollectCoinsEvent")
if not collectCoinsEvent then
	collectCoinsEvent = Instance.new("RemoteEvent")
	collectCoinsEvent.Name = "CollectCoinsEvent"
	collectCoinsEvent.Parent = ReplicatedStorage
end

-- Create dialog object
local dialogObject = DialogModule.new("Indigenous Guide", npc, prompt)

-- Track current state
local currentHelperPrice = 100
local currentHelperCount = 0
local isDialogOpen = false

-- Function to get player's accumulated coins
local function getAccumulatedCoins()
	local hiddenStats = player:FindFirstChild("HiddenStats")
	if not hiddenStats then return 0 end

	local accumulated = hiddenStats:FindFirstChild("AccumulatedCoins")
	return accumulated and accumulated.Value or 0
end

-- Function to get player's coin multiplier
local function getCoinMultiplier()
	local hiddenStats = player:FindFirstChild("HiddenStats")
	if not hiddenStats then return 1 end

	local multiplier = hiddenStats:FindFirstChild("CoinMultiplier")
	return multiplier and multiplier.Value or 1
end

-- Function to get player's coins per second
local function getCoinsPerSec()
	local hiddenStats = player:FindFirstChild("HiddenStats")
	if not hiddenStats then return 0 end

	local coinsPerSec = hiddenStats:FindFirstChild("CoinsPerSec")
	return coinsPerSec and coinsPerSec.Value or 0
end

-- Function to open shop UI (NEW - replaces direct purchase)
local function openShop()
	print("[HoboSeller Dialog] Opening shop UI...")
	
	-- Wait for HelperPlacementUI to load if needed
	if not _G.OpenHelperShop then
		-- Wait a bit for HelperPlacementUI to initialize
		for i = 1, 10 do
			task.wait(0.1)
			if _G.OpenHelperShop then
				break
			end
		end
		
		if not _G.OpenHelperShop then
			warn("[HoboSeller Dialog] _G.OpenHelperShop not found after waiting! Make sure HelperPlacementUI is loaded.")
			return
		end
	end
	
	-- Request helpers list from server and wait for response
	if requestHelperShopList then
		requestHelperShopList:FireServer()
		
		-- Wait for helpers list response
		task.spawn(function()
			local helpersList = {}
			local success, data = pcall(function()
				return requestHelperShopList.OnClientEvent:Wait()
			end)
			
			if success and data and data.helpers then
				helpersList = data.helpers
			else
				-- Fallback: try again if first attempt failed
				task.wait(0.2)
				local success2, data2 = pcall(function()
					return requestHelperShopList.OnClientEvent:Wait()
				end)
				if success2 and data2 and data2.helpers then
					helpersList = data2.helpers
				end
			end
			
			-- Open shop UI with current price and helpers list
			if _G.OpenHelperShop then
				_G.OpenHelperShop(currentHelperPrice, helpersList)
				print("[HoboSeller Dialog] Shop opened with " .. #helpersList .. " helpers, price: " .. currentHelperPrice)
			else
				warn("[HoboSeller Dialog] _G.OpenHelperShop disappeared!")
			end
		end)
	else
		-- If RemoteEvent doesn't exist, open shop with empty list (will be populated by reroll)
		if _G.OpenHelperShop then
			_G.OpenHelperShop(currentHelperPrice, {})
			print("[HoboSeller Dialog] Shop opened (no helpers list available)")
		end
	end
end

-- Function to setup all dialogs
local function setupDialogs()
	-- Clear existing dialogs
	dialogObject.dialogs = {}

	local _accumulated = getAccumulatedCoins()
	local _multiplier = getCoinMultiplier()
	local _coinsPerSec = getCoinsPerSec()

	-- Dialog 1: Main Menu
	dialogObject:addDialog("Greetings! What brings you here today? <font color='rgb(200,200,200)'></font>", {
		"Buy a helper",
		"Collect my coins",
		"Nevermind"
	})

	-- Dialog 2: Buy Helper Confirmation
	local priceText = "<font color='rgb(255,220,127)'>" .. currentHelperPrice .. " coins</font>"
	local helperNumText = "<font color='rgb(150,200,255)'>(Helper #" .. (currentHelperCount + 1) .. ")</font>"

	dialogObject:addDialog("Would you like to buy a helper for " .. priceText .. "? " .. helperNumText, {
		"Yes, buy a helper", 
		"No, go back"
	})
end

-- What happens when triggered
prompt.Triggered:Connect(function(playerWhoTriggered)
	if isDialogOpen then
		print("Dialog is already open, ignoring trigger")
		return
	end

	isDialogOpen = true
	print("Opening main dialog...")

	-- Request current price from server
	getHelperPriceEvent:FireServer()

	-- Wait for price response
	local price, helperCount = getHelperPriceEvent.OnClientEvent:Wait()
	currentHelperPrice = price
	currentHelperCount = helperCount

	-- Setup all dialogs
	setupDialogs()

	-- Show main dialog (dialog #1)
	dialogObject:triggerDialog(playerWhoTriggered, 1)
end)

-- Handle dialog responses
dialogObject.responded:Connect(function(responseNum, dialogNum)
	-- MAIN MENU (dialogNum = 1)
	if dialogNum == 1 then
		if responseNum == 1 then
			-- Option 1: Buy a helper
			print("Player chose to buy a helper")

			-- Show buy helper dialog (dialog #2)
			dialogObject:triggerDialog(player, 2)

		elseif responseNum == 2 then
			-- Option 2: Collect coins
			print("Player chose to collect coins")

			local accumulated = getAccumulatedCoins()

			if accumulated <= 0 then
				dialogObject:hideGui("<font color='rgb(255,200,100)'>You don't have any coins to collect yet! Keep your helpers working!</font>")
				task.wait(2.5)
				isDialogOpen = false
			else
				-- Send collect request to server
				collectCoinsEvent:FireServer()

				-- Wait for response
				local _success, message = collectCoinsEvent.OnClientEvent:Wait()

				dialogObject:hideGui(message)
				task.wait(2.5)
				isDialogOpen = false
			end

		elseif responseNum == 3 then
			-- Option 3: Nevermind
			dialogObject:hideGui("Come back anytime!")
			task.wait(2.5)
			isDialogOpen = false
		end

	-- BUY HELPER MENU (dialogNum = 2)
	elseif dialogNum == 2 then
		if responseNum == 1 then
			-- Yes, buy helper - OPEN SHOP UI INSTEAD OF DIRECT PURCHASE
			print("Player confirmed purchase - opening shop UI")

			-- Close dialog
			dialogObject:hideGui("<font color='rgb(100,255,100)'>Opening shop...</font>")
			task.wait(0.5)
			isDialogOpen = false

			-- Open shop UI (this will show the randomized shop)
			openShop()

		elseif responseNum == 2 then
			-- No, go back to main menu
			print("Player went back to main menu")

			-- Update prices and go back to dialog #1
			getHelperPriceEvent:FireServer()
			local price, helperCount = getHelperPriceEvent.OnClientEvent:Wait()
			currentHelperPrice = price
			currentHelperCount = helperCount

			setupDialogs()
			dialogObject:triggerDialog(player, 1)
		end
	end
end)

-- Listen for shop close to reset dialog state
task.spawn(function()
	while true do
		task.wait(0.5)
		if not _G.HelperPlacementData or not _G.HelperPlacementData.isShopMode then
			if isDialogOpen then
				isDialogOpen = false
			end
		end
	end
end)

print("[HoboSeller Dialog] ✅ Initialized")
