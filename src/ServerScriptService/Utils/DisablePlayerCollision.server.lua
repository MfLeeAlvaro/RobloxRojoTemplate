-- DisablePlayerCollision.server.lua
-- Utility function to prevent players from colliding with NPCs (helpers and enemies)

-- Disable collision for all parts in a model
-- This prevents players from getting stuck or pushed by NPCs
local function disablePlayerCollision(model)
	if not model or not model:IsA("Model") then
		return
	end
	
	-- Disable collision for all BaseParts in the model (including descendants)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanTouch = false
		end
	end
	
	-- Also disable collision for the model's PrimaryPart if it exists
	if model.PrimaryPart and model.PrimaryPart:IsA("BasePart") then
		model.PrimaryPart.CanCollide = false
		model.PrimaryPart.CanTouch = false
	end
	
	-- Also handle HumanoidRootPart specifically (common in NPCs)
	local hrp = model:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		hrp.CanCollide = false
		hrp.CanTouch = false
	end
	
	-- Also disable collision for any parts added later
	local function onDescendantAdded(descendant)
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanTouch = false
		end
	end
	
	model.DescendantAdded:Connect(onDescendantAdded)
end

-- Export function globally so other scripts can use it
_G.DisablePlayerCollision = disablePlayerCollision

-- Auto-disable collision for all existing and new helpers/enemies
local workspace = game:GetService("Workspace")

-- Track if connections are already set up (prevent duplicates)
local connectionsSetup = false

-- Function to setup folder monitoring
local function setupFolderMonitoring()
	if connectionsSetup then
		return -- Already set up, don't create duplicate connections
	end
	
	-- Wait for folders to exist (create if needed)
	local helpersFolder = workspace:FindFirstChild("Helpers")
	if not helpersFolder then
		helpersFolder = Instance.new("Folder")
		helpersFolder.Name = "Helpers"
		helpersFolder.Parent = workspace
	end
	
	local enemiesFolder = workspace:FindFirstChild("Enemies")
	if not enemiesFolder then
		enemiesFolder = Instance.new("Folder")
		enemiesFolder.Name = "Enemies"
		enemiesFolder.Parent = workspace
	end
	
	-- Disable collision for existing NPCs
	for _, helper in ipairs(helpersFolder:GetChildren()) do
		if helper:IsA("Model") then
			disablePlayerCollision(helper)
		end
	end
	
	for _, enemy in ipairs(enemiesFolder:GetChildren()) do
		if enemy:IsA("Model") then
			disablePlayerCollision(enemy)
		end
	end
	
	-- Auto-disable collision for new NPCs added to folders
	helpersFolder.ChildAdded:Connect(function(child)
		if child:IsA("Model") then
			task.wait(0.1) -- Wait a moment for model to fully load
			disablePlayerCollision(child)
		end
	end)
	
	enemiesFolder.ChildAdded:Connect(function(child)
		if child:IsA("Model") then
			task.wait(0.1) -- Wait a moment for model to fully load
			disablePlayerCollision(child)
		end
	end)
	
	-- Also monitor workspace for NPCs that might be spawned there (shop helpers)
	-- Only check for helpers (OwnerUserId), not enemies (enemies go directly to enemiesFolder)
	workspace.ChildAdded:Connect(function(child)
		if child:IsA("Model") then
			-- Only check for helpers (has OwnerUserId) - enemies go directly to enemiesFolder
			local ownerId = child:GetAttribute("OwnerUserId")
			
			if ownerId then
				task.wait(0.1) -- Wait a moment for model to fully load
				disablePlayerCollision(child)
			end
		end
	end)
	
	connectionsSetup = true
	print("[DisablePlayerCollision] ✅ Initialized - collision disabled for all NPCs")
end

-- Setup monitoring (run immediately and also after a delay to catch any that spawn early)
setupFolderMonitoring()
task.spawn(function()
	task.wait(1) -- Wait a bit for other scripts to initialize
	-- Just disable collision for existing NPCs, don't recreate connections
	local helpersFolder = workspace:FindFirstChild("Helpers")
	local enemiesFolder = workspace:FindFirstChild("Enemies")
	
	if helpersFolder then
		for _, helper in ipairs(helpersFolder:GetChildren()) do
			if helper:IsA("Model") then
				disablePlayerCollision(helper)
			end
		end
	end
	
	if enemiesFolder then
		for _, enemy in ipairs(enemiesFolder:GetChildren()) do
			if enemy:IsA("Model") then
				disablePlayerCollision(enemy)
			end
		end
	end
end)

return disablePlayerCollision
