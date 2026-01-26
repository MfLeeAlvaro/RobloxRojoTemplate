-- StartWaveUI.luau - React component for wave control
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local React = require(ReplicatedStorage.Packages.React)

-- RemoteEvents
local startWaveEvent = ReplicatedStorage:FindFirstChild("StartWaveEvent")
if not startWaveEvent then
	startWaveEvent = Instance.new("RemoteEvent")
	startWaveEvent.Name = "StartWaveEvent"
	startWaveEvent.Parent = ReplicatedStorage
end

local waveUpdateEvent = ReplicatedStorage:FindFirstChild("WaveUpdateEvent")
if not waveUpdateEvent then
	waveUpdateEvent = Instance.new("RemoteEvent")
	waveUpdateEvent.Name = "WaveUpdateEvent"
	waveUpdateEvent.Parent = ReplicatedStorage
end

-- Global state (like ShopUI pattern)
_G.StartWaveUIData = _G.StartWaveUIData or {
	waveNumber = 0,
	isActive = false,
	isVisible = true,
	updateTime = 0,
}

-- Listen for wave updates
waveUpdateEvent.OnClientEvent:Connect(function(waveNum, active)
	_G.StartWaveUIData.waveNumber = waveNum
	_G.StartWaveUIData.isActive = active
	_G.StartWaveUIData.updateTime = tick()
end)

-- Keyboard toggle: Escape closes this UI
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	
	if input.KeyCode == Enum.KeyCode.Escape then
		_G.StartWaveUIData.isVisible = false
		_G.StartWaveUIData.updateTime = tick()
		print("[StartWaveUI] ✅ UI closed via Escape key")
	end
end)

-- Handle start wave button
local function handleStartWave()
	print("[StartWaveUI] ✅ Start Wave button clicked - firing StartWaveEvent")
	startWaveEvent:FireServer()
end

-- StartWaveUI React Component
local function StartWaveUI()
	-- Get current state from global
	local data = _G.StartWaveUIData or {}
	local waveNumber = data.waveNumber or 0
	local isActive = data.isActive
	local isVisible = data.isVisible ~= false -- Default to true
	
	-- Don't render if not visible
	if not isVisible then
		return nil
	end
	
	return React.createElement("Frame", {
		Size = UDim2.fromOffset(200, 80),
		Position = UDim2.new(1, -220, 0, 20),
		BackgroundColor3 = Color3.fromRGB(30, 30, 30),
		BorderSizePixel = 0,
	}, {
		UICorner = React.createElement("UICorner", {
			CornerRadius = UDim.new(0, 8),
		}),
		
		Title = React.createElement("Frame", {
			Size = UDim2.new(1, -40, 0, 30),
			BackgroundColor3 = Color3.fromRGB(40, 40, 40),
			BorderSizePixel = 0,
		}, {
			UICorner = React.createElement("UICorner", {
				CornerRadius = UDim.new(0, 8),
			}),
			
			TitleLabel = React.createElement("TextLabel", {
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundTransparency = 1,
				Text = "Wave Control",
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 16,
				Font = Enum.Font.GothamBold,
			}),
		}),
		
		CloseButton = React.createElement("TextButton", {
			Size = UDim2.new(0, 30, 0, 30),
			Position = UDim2.new(1, -30, 0, 0),
			BackgroundColor3 = Color3.fromRGB(200, 50, 50),
			BorderSizePixel = 0,
			Text = "×",
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextSize = 20,
			Font = Enum.Font.GothamBold,
			AutoButtonColor = false,
			[React.Event.Activated] = function()
				_G.StartWaveUIData.isVisible = false
				_G.StartWaveUIData.updateTime = tick()
				print("[StartWaveUI] ✅ UI closed")
			end,
		}, {
			UICorner = React.createElement("UICorner", {
				CornerRadius = UDim.new(0, 8),
			}),
		}),
		
		WaveLabel = React.createElement("TextLabel", {
			Size = UDim2.new(1, -20, 0, 20),
			Position = UDim2.new(0, 10, 0, 35),
			BackgroundTransparency = 1,
			Text = "Wave: " .. waveNumber,
			TextColor3 = Color3.fromRGB(200, 200, 200),
			TextSize = 14,
			Font = Enum.Font.Gotham,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		
		StartButton = React.createElement("TextButton", {
			Size = UDim2.new(1, -20, 0, 30),
			Position = UDim2.new(0, 10, 1, -35),
			BackgroundColor3 = isActive and Color3.fromRGB(200, 100, 50) or Color3.fromRGB(50, 150, 50),
			BorderSizePixel = 0,
			Text = isActive and "Wave Active" or "Start Wave",
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextSize = 14,
			Font = Enum.Font.GothamBold,
			AutoButtonColor = false,
			[React.Event.Activated] = handleStartWave,
		}, {
			UICorner = React.createElement("UICorner", {
				CornerRadius = UDim.new(0, 4),
			}),
		}),
	})
end

return StartWaveUI
