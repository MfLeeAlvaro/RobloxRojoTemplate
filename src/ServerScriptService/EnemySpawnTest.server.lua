--========================================================
-- EnemySpawnerTest (SERVER)
-- DISABLED: Test script - no automatic spawning
-- Spawns enemies into workspace.Enemies for testing combat
--========================================================

-- DISABLED: Test script disabled - no automatic enemy spawning
print("[EnemySpawnTest] DISABLED - Test script is disabled")

--[[
-- Original code commented out below
local ServerStorage = game:GetService("ServerStorage")

local enemyFolder = workspace:FindFirstChild("Enemies") or Instance.new("Folder")
enemyFolder.Name = "Enemies"
enemyFolder.Parent = workspace

-- Gets correct half-height of a model using its bounding box
local function getModelHalfHeight(model: Model): number
	local _, size = model:GetBoundingBox()
	return size.Y / 2
end


local templates = ServerStorage:WaitForChild("EnemyTemplates")

-- Pick ANY gridfloor in workspace for testing
local function findAnyGrid()
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("BasePart") and d.Name == "Gridfloor" then
			return d
		end
	end
	return nil
end

local GRID_SIZE = 5
local GRID_ROWS = 10
local GRID_COLS = 10

local function cellToWorldCFrame(row, col, yOffset, hitGrid: BasePart)
	local halfX = hitGrid.Size.X / 2
	local halfZ = hitGrid.Size.Z / 2
	local centerX = (-halfX) + (col - 0.5) * GRID_SIZE
	local centerZ = (-halfZ) + (row - 0.5) * GRID_SIZE
	local worldCenter = hitGrid.CFrame:PointToWorldSpace(Vector3.new(centerX, 0, centerZ))
	local topY = hitGrid.Position.Y + (hitGrid.Size.Y / 2)
	return CFrame.new(worldCenter.X, topY + (yOffset or 2), worldCenter.Z)
end

local function spawnEnemy(enemyName, row, col, grid)
	local template = templates:FindFirstChild(enemyName)
	if not template then
		warn("Missing enemy template:", enemyName)
		return
	end

	local e = template:Clone()
	e.Parent = enemyFolder
	e:SetAttribute("IsEnemy", true)

	local primary =
		e:FindFirstChild("HumanoidRootPart", true)
		or e.PrimaryPart
		or e:FindFirstChildWhichIsA("BasePart", true)

	local yOffset = 2
	if primary and primary:IsA("BasePart") then
		e.PrimaryPart = primary
		yOffset = primary.Size.Y / 2
	end

	e:PivotTo(cellToWorldCFrame(row, col, yOffset, grid))
end

task.wait(3)

local grid = findAnyGrid()
if not grid then
	warn("No Gridfloor found.")
	return
end

-- Spawn 5 enemies in rows 6-10 (enemy side)
local enemyNames = {}
for _, child in ipairs(templates:GetChildren()) do
	if child:IsA("Model") then
		table.insert(enemyNames, child.Name)
	end
end
if #enemyNames == 0 then
	warn("No enemy models in ServerStorage.EnemyTemplates")
	return
end

for i = 1, 5 do
	local row = math.random(6, 10)
	local col = math.random(1, 10)
	local pick = enemyNames[math.random(1, #enemyNames)]
	spawnEnemy(pick, row, col, grid)
end

print("✅ Spawned test enemies")
--]]