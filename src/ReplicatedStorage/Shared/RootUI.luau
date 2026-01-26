local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)

-- Safely require components with error handling
local ShopUI, shopUIError
local HelperPlacementUI, helperUIError
local StartWaveUI, waveUIError

local shopUISuccess = pcall(function()
	ShopUI = require(ReplicatedStorage.Shared.ShopUI)
end)

local helperUISuccess = pcall(function()
	HelperPlacementUI = require(ReplicatedStorage.Shared.HelperPlacementUI)
end)

local waveUISuccess = pcall(function()
	StartWaveUI = require(ReplicatedStorage.Shared.StartWaveUI)
end)

local function RootUI()
	-- Build children array
	local children = {}
	
	-- Try creating components (only if they loaded successfully)
	if shopUISuccess and ShopUI then
		local shopSuccess, shopElement = pcall(function()
			return React.createElement(ShopUI)
		end)
		if shopSuccess and shopElement then
			table.insert(children, shopElement)
		end
	end
	
	if helperUISuccess and HelperPlacementUI then
		local helperSuccess, helperElement = pcall(function()
			return React.createElement(HelperPlacementUI)
		end)
		if helperSuccess and helperElement then
			table.insert(children, helperElement)
		end
	end
	
	if waveUISuccess and StartWaveUI then
		local waveSuccess, waveElement = pcall(function()
			return React.createElement(StartWaveUI)
		end)
		if waveSuccess and waveElement then
			table.insert(children, waveElement)
		end
	end
	
	-- Use a Frame as container - Frame fills the entire screen
	return React.createElement("Frame", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
	}, children)
end

return RootUI
