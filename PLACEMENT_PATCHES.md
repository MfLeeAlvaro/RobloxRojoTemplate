# Placement Script Patches for HelperRespawnManager

These patches add the required `PlaceRow`, `PlaceCol`, and `HelperType` attributes to helper placement scripts.

## Patch 1: HelperPlacement.server.lua

**Location:** After line 492 (after setting IslandId attribute)

**Add this code:**

```lua
	-- Calculate row/col from position for HelperRespawnManager
	local function worldToCellForGrid(worldPos, grid)
		if not grid then return nil, nil end
		local localPos = grid.CFrame:PointToObjectSpace(worldPos)
		local halfX = grid.Size.X / 2
		local halfZ = grid.Size.Z / 2
		if localPos.X < -halfX or localPos.X > halfX or localPos.Z < -halfZ or localPos.Z > halfZ then
			return nil, nil
		end
		local x01 = localPos.X + halfX
		local z01 = localPos.Z + halfZ
		local GRID_SIZE = 5
		local col = math.floor(x01 / GRID_SIZE) + 1
		local row = math.floor(z01 / GRID_SIZE) + 1
		return row, col
	end
	
	local placeRow, placeCol = worldToCellForGrid(hitCFrame.Position, targetGrid)
	if placeRow and placeCol then
		helper:SetAttribute("PlaceRow", placeRow)
		helper:SetAttribute("PlaceCol", placeCol)
	end
	
	-- Set HelperType for HelperRespawnManager
	helper:SetAttribute("HelperType", helperName)
```

## Patch 2: GridHelperSpawnerServer.server.lua

**Location:** After line 513 (after setting SpawnCol attribute)

**Add this code:**

```lua
	-- Also set PlaceRow/PlaceCol (HelperRespawnManager uses these)
	unit:SetAttribute("PlaceRow", row)
	unit:SetAttribute("PlaceCol", col)
	
	-- Set HelperType for HelperRespawnManager (alias of UnitType)
	unit:SetAttribute("HelperType", helperName)
```

## Patch 3: HelperShopServer.server.lua (if used)

**Location:** After line 112 (after helper.Parent = workspace)

**Add this code:**

```lua
	-- Calculate row/col from position for HelperRespawnManager
	local function worldToCellForGrid(worldPos, gridId)
		-- Find grid from GridId string
		local parts = {}
		for part in gridId:gmatch("[^.]+") do
			table.insert(parts, part)
		end
		local current = workspace
		for _, partName in ipairs(parts) do
			current = current:FindFirstChild(partName)
			if not current then return nil, nil end
		end
		if not current or not current:IsA("BasePart") or current.Name ~= "Gridfloor" then
			return nil, nil
		end
		local grid = current
		local localPos = grid.CFrame:PointToObjectSpace(worldPos)
		local halfX = grid.Size.X / 2
		local halfZ = grid.Size.Z / 2
		if localPos.X < -halfX or localPos.X > halfX or localPos.Z < -halfZ or localPos.Z > halfZ then
			return nil, nil
		end
		local x01 = localPos.X + halfX
		local z01 = localPos.Z + halfZ
		local GRID_SIZE = 5
		local col = math.floor(x01 / GRID_SIZE) + 1
		local row = math.floor(z01 / GRID_SIZE) + 1
		return row, col
	end
	
	if data and data.gridId then
		local placeRow, placeCol = worldToCellForGrid(position, data.gridId)
		if placeRow and placeCol then
			helper:SetAttribute("PlaceRow", placeRow)
			helper:SetAttribute("PlaceCol", placeCol)
		end
	end
	
	-- Set HelperType for HelperRespawnManager
	helper:SetAttribute("HelperType", helperName)
```

## Summary

These patches ensure that:
1. `PlaceRow` and `PlaceCol` attributes are set when helpers are placed
2. `HelperType` attribute is set (matching the template name)
3. HelperRespawnManager can track and respawn helpers correctly

**Note:** GridHelperSpawnerServer already sets `SpawnRow` and `SpawnCol`, but we add `PlaceRow`/`PlaceCol` as aliases for consistency, and `HelperType` for template name tracking.
