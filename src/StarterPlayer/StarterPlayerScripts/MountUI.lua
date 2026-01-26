local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local RootUI = require(ReplicatedStorage.Shared.RootUI)

return function()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local container = Instance.new("ScreenGui")
	container.Name = "React"
	container.IgnoreGuiInset = true
	container.ResetOnSpawn = false
	container.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	container.ClipToDeviceSafeArea = false
	container.Parent = playerGui

	local root = ReactRoblox.createRoot(container)
	
	-- Track last update times to only re-render when state changes
	local lastShopUpdate = 0
	local lastHelperUpdate = 0
	local lastWaveUpdate = 0
	
	-- Render function that creates a new app element each time
	local function renderApp()
		local app = React.createElement(RootUI)
		root:render(app)
	end
	
	-- Initial render
	renderApp()
	
	-- Re-render only when global state actually changes
	-- This is more efficient than re-rendering every frame
	task.spawn(function()
		while true do
			task.wait(0.1)
			
			local shopData = _G.ShopUIData
			local helperData = _G.HelperPlacementData
			local waveData = _G.StartWaveUIData
			
			local shouldRender = false
			
			if shopData and shopData.updateTime and shopData.updateTime ~= lastShopUpdate then
				lastShopUpdate = shopData.updateTime
				shouldRender = true
			end
			
			if helperData and helperData.updateTime and helperData.updateTime ~= lastHelperUpdate then
				lastHelperUpdate = helperData.updateTime
				shouldRender = true
			end
			
			if waveData and waveData.updateTime and waveData.updateTime ~= lastWaveUpdate then
				lastWaveUpdate = waveData.updateTime
				shouldRender = true
			end
			
			if shouldRender then
				renderApp()
			end
		end
	end)
end
