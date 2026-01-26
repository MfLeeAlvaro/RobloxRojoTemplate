-- HelperPlacementServer: Handles placing helpers in the world (no buying, just placement)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

-- RemoteEvents
local helperShopEvent = ReplicatedStorage:FindFirstChild("HelperShopEvent")
if not helperShopEvent then
	helperShopEvent = Instance.new("RemoteEvent")
	helperShopEvent.Name = "HelperShopEvent"
	helperShopEvent.Parent = ReplicatedStorage
end

-- Get helper templates
local templatesFolder = ServerStorage:WaitForChild("HelperTemplates")

-- Get available helper types from ServerStorage
local function getAvailableHelpers()
	local helpers = {}
	for _, child in ipairs(templatesFolder:GetChildren()) do
		if child:IsA("Model") then
			-- Direct model
			table.insert(helpers, child.Name)
		elseif child:IsA("Folder") then
			-- Folder - look for a model inside it
			local model = child:FindFirstChildOfClass("Model")
			if model then
				table.insert(helpers, child.Name)
			else
				-- If no model found, check if folder itself can be used (contains parts)
				local hasParts = false
				for _, descendant in ipairs(child:GetDescendants()) do
					if descendant:IsA("BasePart") or descendant:IsA("Model") then
						hasParts = true
						break
					end
				end
				if hasParts then
					table.insert(helpers, child.Name)
				end
			end
		end
	end
	table.sort(helpers)
	return helpers
end

-- Send available helpers list to client
local function sendHelpersList(player: Player)
	local helpers = getAvailableHelpers()
	print("[HelperPlacementServer] Sending helpers list to", player.Name, "- Count:", #helpers)
	
	helperShopEvent:FireClient(player, "HelpersList", {
		helpers = helpers,
	})
end

-- Handle placing a helper
local function handlePlace(player: Player, helperName: string, position: Vector3, gridId: string)
	-- Validate template exists
	local template = templatesFolder:FindFirstChild(helperName)
	if not template then
		helperShopEvent:FireClient(player, "PlaceResult", {
			success = false,
			message = "Helper template not found: " .. helperName,
		})
		return
	end
	
	-- Clone the template
	local helper = template:Clone()
	helper.Name = helperName .. "_" .. player.Name .. "_" .. os.time()
	
	-- If it's a folder, we need to find the actual model inside it
	local modelToPosition = helper
	if helper:IsA("Folder") then
		-- Look for a Model inside the folder
		modelToPosition = helper:FindFirstChildOfClass("Model")
		if not modelToPosition then
			-- If no model, the folder itself might be the template
			modelToPosition = helper
		end
	end
	
	-- Find the primary part or HumanoidRootPart
	local primaryPart = nil
	if modelToPosition:IsA("Model") then
		primaryPart = modelToPosition:FindFirstChild("HumanoidRootPart") or modelToPosition.PrimaryPart
	end
	
	if not primaryPart then
		-- Try to find any BasePart in the helper
		for _, part in ipairs(helper:GetDescendants()) do
			if part:IsA("BasePart") then
				primaryPart = part
				break
			end
		end
	end
	
	-- Position the helper
	if primaryPart then
		helper:PivotTo(CFrame.new(position))
	elseif modelToPosition:IsA("Model") then
		-- Fallback: try to set primary part CFrame
		modelToPosition:SetPrimaryPartCFrame(CFrame.new(position))
	else
		-- Last resort: just parent it (position might be set by parts inside)
		warn("[HelperPlacementServer] Could not find primary part for", helperName)
	end
	
	helper.Parent = workspace
	
	print("[HelperPlacementServer] Placed", helperName, "for", player.Name, "at", position)
	
	helperShopEvent:FireClient(player, "PlaceResult", {
		success = true,
		message = "Placed " .. helperName .. "!",
	})
end

-- Remote event handler
helperShopEvent.OnServerEvent:Connect(function(player, action, data)
	if action == "RequestHelpers" then
		sendHelpersList(player)
		return
	end
	
	if action == "Place" then
		local helperName = data and data.helperName
		local position = data and data.position
		local gridId = data and data.gridId
		
		if typeof(helperName) == "string" and typeof(position) == "Vector3" then
			handlePlace(player, helperName, position, gridId or "")
		end
		return
	end
end)

-- Send helpers list when player joins
Players.PlayerAdded:Connect(function(player)
	task.wait(0.5)
	sendHelpersList(player)
end)

print("✅ HelperPlacementServer loaded")
local helpers = getAvailableHelpers()
print("Available helpers (" .. #helpers .. "): " .. table.concat(helpers, ", "))

-- Debug: Print structure
print("[DEBUG] HelperTemplates children:")
for _, child in ipairs(templatesFolder:GetChildren()) do
	print("  - " .. child.Name .. " (" .. child.ClassName .. ")")
	if child:IsA("Folder") then
		local model = child:FindFirstChildOfClass("Model")
		if model then
			print("    -> Contains Model: " .. model.Name)
		else
			print("    -> No Model found, checking descendants...")
			local partCount = 0
			for _, desc in ipairs(child:GetDescendants()) do
				if desc:IsA("BasePart") or desc:IsA("Model") then
					partCount = partCount + 1
				end
			end
			print("    -> Found " .. partCount .. " parts/models in descendants")
		end
	end
end

-- Also send to existing players
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(function()
		task.wait(0.5)
		sendHelpersList(player)
	end)
end
