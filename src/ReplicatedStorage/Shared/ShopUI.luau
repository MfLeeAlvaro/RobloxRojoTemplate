-- ShopUI.luau - React component for shop UI
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local React = require(ReplicatedStorage.Packages.React)

-- RemoteEvent
local shopEvent = ReplicatedStorage:WaitForChild("ShopEvent")

-- Global state
_G.ShopUIData = _G.ShopUIData or {
	wave = 1,
	offers = {},
	costs = {},
	coins = 0,
	inventory = {},
	isVisible = true,
	updateTime = 0,
}

-- Listen for shop updates
shopEvent.OnClientEvent:Connect(function(action, data)
	if action == "ShopUpdate" then
		_G.ShopUIData.wave = data.wave or 1
		_G.ShopUIData.offers = data.offers or {}
		_G.ShopUIData.costs = data.costs or {}
		_G.ShopUIData.coins = data.coins or 0
		_G.ShopUIData.inventory = data.inventory or {}
		_G.ShopUIData.updateTime = tick()
		print("[ShopUI] Shop updated - Wave:", _G.ShopUIData.wave, "Coins:", _G.ShopUIData.coins)
	elseif action == "BuyResult" then
		if data.ok then
			print("[ShopUI] ✅", data.msg)
		else
			warn("[ShopUI] ❌", data.msg)
		end
		-- Request updated shop data
		shopEvent:FireServer("RequestShop")
	end
end)

-- Request shop data on load
task.spawn(function()
	task.wait(0.5)
	shopEvent:FireServer("RequestShop")
end)

-- Keyboard toggle: Tab opens/closes shop
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	
	if input.KeyCode == Enum.KeyCode.Tab then
		_G.ShopUIData.isVisible = not _G.ShopUIData.isVisible
		_G.ShopUIData.updateTime = tick()
		print("[ShopUI] UI toggled via Tab key: " .. tostring(_G.ShopUIData.isVisible))
	elseif input.KeyCode == Enum.KeyCode.Escape then
		_G.ShopUIData.isVisible = false
		_G.ShopUIData.updateTime = tick()
	end
end)

-- Handle buy button
local function handleBuy(unitName: string)
	local cost = _G.ShopUIData.costs[unitName]
	if not cost then
		warn("[ShopUI] No cost found for:", unitName)
		return
	end
	
	if _G.ShopUIData.coins < cost then
		warn("[ShopUI] Not enough coins! Need:", cost, "Have:", _G.ShopUIData.coins)
		return
	end
	
	print("[ShopUI] Buying:", unitName, "for", cost, "coins")
	shopEvent:FireServer("Buy", {
		unitName = unitName,
	})
end

-- ShopUI React Component
local function ShopUI()
	-- Get current state from global
	local data = _G.ShopUIData or {}
	local wave = data.wave or 1
	local offers = data.offers or {}
	local costs = data.costs or {}
	local coins = data.coins or 0
	local inventory = data.inventory or {}
	local isVisible = data.isVisible ~= false -- Default to true
	
	-- Don't render if not visible
	if not isVisible then
		return nil
	end
	
	-- Create shop offer items
	local offerItems = {}
	for i, offer in ipairs(offers) do
		local unitName = offer.name or "Unknown"
		local cost = costs[unitName] or 0
		local canAfford = coins >= cost
		local ownedCount = inventory[unitName] or 0
		
		offerItems[i] = React.createElement("Frame", {
			Size = UDim2.new(1, -10, 0, 80),
			BackgroundColor3 = Color3.fromRGB(35, 35, 35),
			BorderSizePixel = 0,
			LayoutOrder = i,
		}, {
			UICorner = React.createElement("UICorner", {
				CornerRadius = UDim.new(0, 6),
			}),
			
			UnitName = React.createElement("TextLabel", {
				Size = UDim2.new(0.6, 0, 0, 30),
				Position = UDim2.new(0, 10, 0, 5),
				BackgroundTransparency = 1,
				Text = unitName,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 18,
				Font = Enum.Font.GothamBold,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			
			CostLabel = React.createElement("TextLabel", {
				Size = UDim2.new(0.4, 0, 0, 25),
				Position = UDim2.new(0, 10, 0, 35),
				BackgroundTransparency = 1,
				Text = "Cost: " .. cost .. " coins",
				TextColor3 = canAfford and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 100, 100),
				TextSize = 14,
				Font = Enum.Font.Gotham,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			
			OwnedLabel = React.createElement("TextLabel", {
				Size = UDim2.new(0.4, 0, 0, 20),
				Position = UDim2.new(0, 10, 0, 60),
				BackgroundTransparency = 1,
				Text = "Owned: " .. ownedCount,
				TextColor3 = Color3.fromRGB(200, 200, 200),
				TextSize = 12,
				Font = Enum.Font.Gotham,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			
			BuyButton = React.createElement("TextButton", {
				Size = UDim2.new(0, 100, 0, 40),
				Position = UDim2.new(1, -110, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundColor3 = canAfford and Color3.fromRGB(50, 150, 50) or Color3.fromRGB(100, 50, 50),
				BorderSizePixel = 0,
				Text = "Buy",
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 14,
				Font = Enum.Font.GothamBold,
				AutoButtonColor = false,
				[React.Event.Activated] = function()
					if canAfford then
						handleBuy(unitName)
					end
				end,
			}, {
				UICorner = React.createElement("UICorner", {
					CornerRadius = UDim.new(0, 4),
				}),
			}),
		})
	end
	
	return React.createElement("Frame", {
		Size = UDim2.fromOffset(400, 500),
		Position = UDim2.new(1, -420, 0, 20),
		BackgroundColor3 = Color3.fromRGB(30, 30, 30),
		BorderSizePixel = 0,
	}, {
		UICorner = React.createElement("UICorner", {
			CornerRadius = UDim.new(0, 8),
		}),
		
		Title = React.createElement("Frame", {
			Size = UDim2.new(1, -50, 0, 40),
			BackgroundColor3 = Color3.fromRGB(40, 40, 40),
			BorderSizePixel = 0,
		}, {
			UICorner = React.createElement("UICorner", {
				CornerRadius = UDim.new(0, 8),
			}),
			
			TitleLabel = React.createElement("TextLabel", {
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
				Text = "Shop - Wave " .. wave,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 20,
				Font = Enum.Font.GothamBold,
			}),
		}),
		
		CloseButton = React.createElement("TextButton", {
			Size = UDim2.new(0, 40, 0, 40),
			Position = UDim2.new(1, -40, 0, 0),
			BackgroundColor3 = Color3.fromRGB(200, 50, 50),
			BorderSizePixel = 0,
			Text = "×",
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextSize = 24,
			Font = Enum.Font.GothamBold,
			AutoButtonColor = false,
			[React.Event.Activated] = function()
				_G.ShopUIData.isVisible = false
				_G.ShopUIData.updateTime = tick()
				print("[ShopUI] ✅ UI closed")
			end,
		}, {
			UICorner = React.createElement("UICorner", {
				CornerRadius = UDim.new(0, 8),
			}),
		}),
		
		CoinsLabel = React.createElement("TextLabel", {
			Size = UDim2.new(1, -20, 0, 30),
			Position = UDim2.new(0, 10, 0, 50),
			BackgroundTransparency = 1,
			Text = "Coins: " .. coins,
			TextColor3 = Color3.fromRGB(255, 215, 0),
			TextSize = 18,
			Font = Enum.Font.GothamBold,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		
		ScrollingFrame = React.createElement("ScrollingFrame", {
			Size = UDim2.new(1, -20, 1, -90),
			Position = UDim2.new(0, 10, 0, 90),
			BackgroundColor3 = Color3.fromRGB(25, 25, 25),
			BorderSizePixel = 0,
			ScrollBarThickness = 6,
			CanvasSize = UDim2.new(0, 0, 0, #offers * 85),
		}, {
			UICorner = React.createElement("UICorner", {
				CornerRadius = UDim.new(0, 6),
			}),
			
			UIListLayout = React.createElement("UIListLayout", {
				Padding = UDim.new(0, 5),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		}, offerItems),
	})
end

return ShopUI
