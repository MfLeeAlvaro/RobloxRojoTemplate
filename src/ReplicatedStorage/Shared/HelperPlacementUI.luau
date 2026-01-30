-- HelperPlacementUI.luau - Chunky Arcade Brick/Stud Style
-- Supports TWO modes:
-- 1. Placement Mode: Select helper, click grid to place (existing functionality)
-- 2. Shop Mode: Buy helper from HoboSeller (NEW - randomized shop with reroll)

-- CRITICAL: Set up globals IMMEDIATELY so they're available even if module errors later
-- These will be replaced with real implementations once functions are defined
local shopFunctionsReady = false

local function stubOpenShop(price, helpersList)
	warn("[HelperPlacementUI] OpenHelperShop called before module fully loaded, waiting...")
	-- Wait for functions to be ready (max 2 seconds)
	local stubRef = _G.OpenHelperShop
	for i = 1, 20 do
		task.wait(0.1)
		if shopFunctionsReady then
			-- Real function should have replaced this stub by now
			local realFunc = _G.OpenHelperShop
			if realFunc and realFunc ~= stubRef then
				return realFunc(price, helpersList)
			end
		end
	end
	warn("[HelperPlacementUI] Failed to initialize OpenHelperShop after waiting")
	return nil
end

local function stubCloseShop()
	warn("[HelperPlacementUI] CloseHelperShop called before module fully loaded, waiting...")
	-- Wait for functions to be ready (max 2 seconds)
	local stubRef = _G.CloseHelperShop
	for i = 1, 20 do
		task.wait(0.1)
		if shopFunctionsReady then
			-- Real function should have replaced this stub by now
			local realFunc = _G.CloseHelperShop
			if realFunc and realFunc ~= stubRef then
				return realFunc()
			end
		end
	end
	warn("[HelperPlacementUI] Failed to initialize CloseHelperShop after waiting")
	return nil
end

_G.OpenHelperShop = stubOpenShop
_G.CloseHelperShop = stubCloseShop

-- Confirm module is loading
print("[HelperPlacementUI] Module loading - globals set up")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local React = require(ReplicatedStorage.Packages.React)

local player = Players.LocalPlayer
local mouse = player:GetMouse()

-- Constants
local GRID_SIZE = 5
local SLOTS_VISIBLE = 6
local SLOT_WIDTH = 140
local SLOT_HEIGHT = 180

-- ===== LAYOUT CONSTANTS =====
local PADDING = 16
local SHADOW_DX = 5
local SHADOW_DY = 5
local SHADOW_TRANSPARENCY = 0.45

-- Grid cell sizes (account for shadow offsets)
local SLOT_CELL_W = SLOT_WIDTH + SHADOW_DX
local SLOT_CELL_H = SLOT_HEIGHT + SHADOW_DY

-- ===== CHUNKY ARCADE STYLE THEME =====

-- Get stud texture from ReplicatedStorage or use placeholder
local function getStudTextureId()
	-- Use WaitForChild with timeout to avoid infinite yields
	local uiAssets = ReplicatedStorage:WaitForChild("UIAssets", 5)
	if not uiAssets then
		warn("[HelperPlacementUI] UIAssets not found in ReplicatedStorage (timeout after 5s)")
		return "rbxassetid://0"
	end
	
	local textures = uiAssets:WaitForChild("Textures", 5)
	if not textures then
		warn("[HelperPlacementUI] Textures folder not found in UIAssets (timeout after 5s)")
		return "rbxassetid://0"
	end
	
	local studsTile = textures:WaitForChild("StudsTile", 5)
	if not studsTile then
		warn("[HelperPlacementUI] StudsTile not found in Textures folder (timeout after 5s)")
		return "rbxassetid://0"
	end
	
	local id = nil
	-- Handle different types
	if studsTile:IsA("ImageLabel") or studsTile:IsA("ImageButton") then
		id = studsTile.Image
	elseif studsTile:IsA("Decal") then
		id = studsTile.Texture
	elseif studsTile:IsA("StringValue") then
		id = studsTile.Value
	end
	
	if typeof(id) == "string" and id ~= "" and id ~= "rbxassetid://0" then
		return id
	end
	
	warn("[HelperPlacementUI] StudsTile texture is empty/placeholder. Set texture on ReplicatedStorage/UIAssets/Textures/StudsTile")
	return "rbxassetid://0"
end

-- Get pixel font from ReplicatedStorage or use placeholder
local function _getPixelFontId()
	-- Try to find a Font asset in UIAssets
	local uiAssets = ReplicatedStorage:FindFirstChild("UIAssets")
	if not uiAssets then
		return nil
	end
	
	-- Check for StringValue with font ID (easiest method)
	local fontValue = uiAssets:FindFirstChild("PixelFontId")
	if fontValue and fontValue:IsA("StringValue") and fontValue.Value ~= "" then
		return fontValue.Value
	end
	
	-- Check for Fonts folder with Font asset
	local fontsFolder = uiAssets:FindFirstChild("Fonts")
	if fontsFolder then
		local pixelFont = fontsFolder:FindFirstChild("PixelFont")
		if pixelFont then
			-- If it's a StringValue with asset ID
			if pixelFont:IsA("StringValue") then
				return pixelFont.Value
			end
			-- If it's a Font instance, get the Face ID
			if pixelFont:GetAttribute("FontId") then
				return pixelFont:GetAttribute("FontId")
			end
		end
	end
	
	return nil
end

local THEME = {
	-- Stud texture (loaded from ReplicatedStorage or placeholder)
	STUD_TEXTURE_ID = getStudTextureId(),
	
	-- ===== STUD SCALE SYSTEM (CONSISTENT EVERYWHERE) =====
	STUD_BASE_PX = 48, -- Base stud size matching "GIFTS!" UI style
	STUD_SCALE = {
		Panel = 1.00, -- main big background
		Tile = 1.00, -- shop cards
		Button = 1.00, -- buy / reroll / close
		Viewport = 1.00,-- inner viewport bg
	},
	
	-- Outline colors
	OUTLINE_BLACK = Color3.fromRGB(0, 0, 0),
	
	-- Shadow settings (using constants)
	SHADOW_TRANSPARENCY = SHADOW_TRANSPARENCY,
	
	-- Text settings
	TEXT_STROKE_THICKNESS = 2,
	TEXT_FONT = Enum.Font.Code, -- Pixelated font for arcade/LEGO style
	
	-- Custom pixel font asset ID (loaded from ReplicatedStorage or set manually)
	-- To use a custom pixel font:
	-- Option 1: Place a Font asset in ReplicatedStorage/UIAssets/Fonts/PixelFont
	-- Option 2: Place a StringValue named "PixelFontId" in ReplicatedStorage/UIAssets with the asset ID
	-- Option 3: Set PIXEL_FONT_ID manually below (e.g., "rbxassetid://1234567890")
	PIXEL_FONT_ID = "rbxassetid://12187371840", -- Custom pixel font asset ID
	
	-- Tile colors mapped from rarity (bright saturated colors)
	TILE_COLORS = {
		Common = Color3.fromRGB(100, 200, 100), -- Bright green
		Uncommon = Color3.fromRGB(100, 255, 150), -- Mint green
		Rare = Color3.fromRGB(100, 150, 255), -- Bright blue
		Epic = Color3.fromRGB(255, 150, 50), -- Orange
		Legendary = Color3.fromRGB(255, 220, 100), -- Gold
		Mythic = Color3.fromRGB(255, 100, 255), -- Magenta (for rainbow gradient)
	},
	
	-- Panel colors
	PANEL_BG = Color3.fromRGB(80, 90, 105), -- Lighter grey background
	PANEL_OUTLINE_THICKNESS = 4,
	
	-- Button colors
	BUTTON_GREEN = Color3.fromRGB(100, 200, 100),
	BUTTON_RED = Color3.fromRGB(200, 50, 50),
	BUTTON_BLUE = Color3.fromRGB(100, 150, 255),
	BUTTON_OUTLINE_THICKNESS = 4,
	
	-- Tile settings
	TILE_OUTLINE_THICKNESS = 3,
	TILE_CORNER_RADIUS = 6, -- Brick-like rounding
	
	-- Title colors
	TITLE_YELLOW = Color3.fromRGB(255, 255, 100),
	WARNING_RED = Color3.fromRGB(255, 100, 100),
}

-- Create pixel font face once globally
local Font = Font
local PIXEL_FACE = Font.new("rbxassetid://12187371840", Enum.FontWeight.Regular, Enum.FontStyle.Normal)

-- Debug: Print stud texture ID
print("[HelperPlacementUI] Using Stud texture:", THEME.STUD_TEXTURE_ID)

-- Lazy refresh helper (guarantees we always get the real Image ID)
local function getStudId()
	if THEME.STUD_TEXTURE_ID == "rbxassetid://0" then
		THEME.STUD_TEXTURE_ID = getStudTextureId()
	end
	return THEME.STUD_TEXTURE_ID
end

-- Helper rarity mapping
local HELPER_RARITIES = {
	Appraiser = "Common",
	Indigenous = "Uncommon",
	MagicHobo = "Rare",
	MuscularHobo = "Uncommon",
	Thrower = "Epic",
	Tweaker = "Legendary",
}

-- Original rarity colors (kept for viewport lighting)
local RARITY_COLORS = {
	Common = {
		primary = Color3.fromHex("#E3E8F0"),
		secondary = Color3.fromHex("#B9C3D6"),
		shadow = Color3.fromHex("#6F7C96"),
	},
	Uncommon = {
		primary = Color3.fromHex("#4DFFE3"),
		secondary = Color3.fromHex("#2DDDCB"),
		shadow = Color3.fromHex("#0E6F6A"),
	},
	Rare = {
		primary = Color3.fromHex("#5CBFFF"),
		secondary = Color3.fromHex("#2D8CFF"),
		shadow = Color3.fromHex("#0D3F8C"),
	},
	Epic = {
		primary = Color3.fromHex("#9A86FF"),
		secondary = Color3.fromHex("#6B4BFF"),
		shadow = Color3.fromHex("#2A157A"),
	},
	Legendary = {
		primary = Color3.fromHex("#FFF1C1"),
		secondary = Color3.fromHex("#FFD97A"),
		shadow = Color3.fromHex("#8A6A1E"),
	},
	Mythic = {
		primary = Color3.fromHex("#FF6E7A"),
		secondary = Color3.fromHex("#FF3B5C"),
		shadow = Color3.fromHex("#6F0D1F"),
	},
}

-- Get tile color for rarity
local function getTileColor(helperName)
	local rarityName = HELPER_RARITIES[helperName] or "Common"
	local rc = RARITY_COLORS[rarityName] or RARITY_COLORS.Common
	-- More neutral + darker to reduce saturation while keeping rarity identity
	return rc.secondary:lerp(Color3.fromRGB(20, 20, 24), 0.45)
end

-- Check if rarity should use rainbow gradient
local function isRainbowRarity(helperName)
	local rarityName = HELPER_RARITIES[helperName] or "Common"
	return rarityName == "Legendary" or rarityName == "Mythic"
end

-- Get rarity colors for a helper (for viewport lighting)
local function getRarityColors(helperName)
	local rarityName = HELPER_RARITIES[helperName] or "Common"
	return RARITY_COLORS[rarityName] or RARITY_COLORS.Common
end

-- ===== STYLE HELPERS =====

-- Stud size helper: get consistent stud pixel size for a given UI element kind
local function studPx(kind)
	local base = THEME.STUD_BASE_PX or 48
	local scale = (THEME.STUD_SCALE and THEME.STUD_SCALE[kind]) or 1
	return math.max(8, math.floor(base * scale + 0.5))
end

-- Add offset to UDim2 position (preserves Scale, adds to Offset)
local function addOffset(pos, dx, dy)
	return UDim2.new(
		pos.X.Scale,
		pos.X.Offset + dx,
		pos.Y.Scale,
		pos.Y.Offset + dy
	)
end

-- Create shadow frame (standalone, not a child of foreground)
local function createShadowFrame(props)
	local size = props.Size
	local basePosition = props.BasePosition
	local anchorPoint = props.AnchorPoint or Vector2.new(0, 0)
	local cornerRadius = props.CornerRadius or UDim.new(0, THEME.TILE_CORNER_RADIUS)
	local zIndex = props.ZIndex or 1
	
	-- Shadow position = base position + offset
	local shadowPosition = addOffset(basePosition, SHADOW_DX, SHADOW_DY)
	
	return React.createElement("Frame", {
		Size = size,
		Position = shadowPosition,
		AnchorPoint = anchorPoint,
		BackgroundColor3 = THEME.OUTLINE_BLACK,
		BackgroundTransparency = SHADOW_TRANSPARENCY,
		BorderSizePixel = 0,
		Active = false,
		Selectable = false,
		ZIndex = zIndex - 1,
	}, {
		UICorner = React.createElement("UICorner", {
			CornerRadius = cornerRadius,
		}),
	})
end

-- Create stud mask overlay (clips to edges and respects rounded corners)
-- Uses proper tiling, pixel-perfect sizing, and pixelated resampling
local function createStudMaskOverlay(props)
	local transparency = props.transparency or 0.25
	local tilePx = props.tilePx or studPx("Tile")
	local z = props.zIndex or 2
	local cornerRadius = props.cornerRadius or UDim.new(0, THEME.TILE_CORNER_RADIUS)
	local strokePx = props.strokePx or 0
	
	-- NEW: allow overlay to extend outside parent padding (to cancel UIPadding)
	local inset = props.insetPx or 0
	
	-- Extract corner radius in pixels (if it's an offset, use that; if scale, approximate)
	local cornerRadiusPx = 0
	if cornerRadius.Offset > 0 then
		cornerRadiusPx = cornerRadius.Offset
	elseif cornerRadius.Scale > 0 then
		-- Approximate: assume typical UI size, but prefer explicit offset
		cornerRadiusPx = 0
	end
	
	-- Compute dynamic overscan to ensure studs cover edges + rounded corners + stroke
	-- Overscan must be large enough that the tiled image extends beyond the clip region
	local overscan = math.max(
		10,
		math.ceil(tilePx * 0.6),
		math.ceil(strokePx * 1.5),
		math.ceil(cornerRadiusPx * 1.2)
	)
	
	return React.createElement("Frame", {
		Size = UDim2.new(1, inset * 2, 1, inset * 2), -- Extend outward to cancel padding
		Position = UDim2.new(0, -inset, 0, -inset), -- Offset outward to cancel padding
		BackgroundTransparency = 1,
		ClipsDescendants = true, -- Clip studs to edges
		ZIndex = z,
	}, {
		UICorner = React.createElement("UICorner", {
			CornerRadius = cornerRadius,
		}),
		StudOverlay = React.createElement("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5), -- Center the tiled image
			Position = UDim2.new(0.5, 0, 0.5, 0), -- Centered position
			Size = UDim2.new(1, overscan * 2, 1, overscan * 2), -- Oversized to reach edges
			BackgroundTransparency = 1,
			Image = getStudId(),
			ImageTransparency = transparency,
			ImageColor3 = Color3.fromRGB(255, 255, 255), -- White (no tint)
			ScaleType = Enum.ScaleType.Tile, -- MUST be Tile, not Stretch/Fit
			TileSize = UDim2.fromOffset(tilePx, tilePx), -- Pixel-perfect tile size (must match texture resolution)
			ResampleMode = Enum.ResamplerMode.Pixelated, -- Lock to pixel grid, prevent blur
			ZIndex = z,
		}),
		-- Subtle overlay to further reduce stud contrast (above studs, below content)
		ContrastOverlay = React.createElement("Frame", {
			Size = UDim2.new(1, 0, 1, 0),
			Position = UDim2.new(0, 0, 0, 0),
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),
			BackgroundTransparency = 0.82, -- MUCH lighter (0.3 was crushing everything)
			BorderSizePixel = 0,
			ZIndex = z, -- Same level as studs, will render on top due to order
		}),
	})
end

-- Legacy function for backwards compatibility (uses mask overlay)
local function _createStudOverlay(transparency, tilePx, tint, z)
	return createStudMaskOverlay({
		transparency = transparency,
		tilePx = tilePx or studPx("Tile"),
		tint = tint,
		zIndex = z,
	})
end

-- Create plastic bevel effect (top highlight + bottom shade)
local function createPlasticBevel()
	return React.createElement("Frame", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		ZIndex = 6,
	}, {
		TopHighlight = React.createElement("Frame", {
			Size = UDim2.new(1, -8, 0, 10),
			Position = UDim2.new(0, 4, 0, 4),
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BackgroundTransparency = 0.90,
			BorderSizePixel = 0,
			ZIndex = 6,
		}, {
			UICorner = React.createElement("UICorner", {
				CornerRadius = UDim.new(0, 4),
			}),
		}),
		BottomShade = React.createElement("Frame", {
			Size = UDim2.new(1, -8, 0, 12),
			Position = UDim2.new(0, 4, 1, -16),
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),
			BackgroundTransparency = 0.92,
			BorderSizePixel = 0,
			ZIndex = 6,
		}, {
			UICorner = React.createElement("UICorner", {
				CornerRadius = UDim.new(0, 4),
			}),
		}),
	})
end

-- Create outlined text label with pixelated font
local function createOutlinedText(props)
	local textColor = props.TextColor3 or Color3.fromRGB(255, 255, 255)
	local strokeColor = props.StrokeColor or THEME.OUTLINE_BLACK
	
	-- Use provided FontFace or default to global pixel font
	local face = props.FontFace or PIXEL_FACE
	
	-- Build props table with all common properties
	local textLabelProps = {
		Size = props.Size,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		BackgroundTransparency = 1,
		Text = props.Text,
		TextColor3 = textColor,
		TextSize = props.TextSize or 14,
		
		-- IMPORTANT: apply custom font
		FontFace = face,
		
		-- IMPORTANT: do NOT set Font at all (avoid overriding)
		-- Font = ...  <-- removed to let FontFace fully control it
		
		TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left,
		TextYAlignment = props.TextYAlignment or Enum.TextYAlignment.Center,
		TextScaled = props.TextScaled or false,
		ZIndex = props.ZIndex or 3,
	}
	
	-- Add LayoutOrder if provided
	if props.LayoutOrder then
		textLabelProps.LayoutOrder = props.LayoutOrder
	end
	
	return React.createElement("TextLabel", textLabelProps, {
		TextStroke = React.createElement("UIStroke", {
			Color = strokeColor,
			Thickness = THEME.TEXT_STROKE_THICKNESS,
			Transparency = 0,
		}),
	})
end

-- Create chunky button with shadow, outline, and hover states
local function createChunkyButton(props)
	local size = props.Size
	local position = props.Position
	local backgroundColor = props.BackgroundColor3 or THEME.BUTTON_GREEN
	local text = props.Text or "Button"
	local onClick = props.OnClick
	local cornerRadius = props.CornerRadius or UDim.new(0, THEME.TILE_CORNER_RADIUS)
	local zIndex = props.ZIndex or 3
	local anchorPoint = props.AnchorPoint or Vector2.new(0, 0)
	
	-- Return wrapper Frame with shadow and button as siblings
	return React.createElement("Frame", {
		Size = size,
		Position = position,
		AnchorPoint = anchorPoint,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = zIndex,
	}, {
		-- Shadow (sibling, behind)
		Shadow = createShadowFrame({
			Size = size,
			BasePosition = UDim2.new(0, 0, 0, 0),
			AnchorPoint = anchorPoint,
			CornerRadius = cornerRadius,
			ZIndex = zIndex,
		}),
		
		-- Button (sibling, on top)
		Button = React.createElement("TextButton", {
			Size = UDim2.new(1, 0, 1, 0),
			Position = UDim2.new(0, 0, 0, 0),
			AnchorPoint = anchorPoint,
			BackgroundColor3 = backgroundColor,
			BorderSizePixel = 0,
			Text = "",
			AutoButtonColor = false,
			ZIndex = zIndex,
			[React.Event.Activated] = onClick,
			[React.Event.MouseEnter] = function(button)
				local tween = TweenService:Create(
					button,
					TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{BackgroundColor3 = backgroundColor:lerp(Color3.fromRGB(255, 255, 255), 0.1)}
				)
				tween:Play()
			end,
			[React.Event.MouseLeave] = function(button)
				local tween = TweenService:Create(
					button,
					TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{BackgroundColor3 = backgroundColor}
				)
				tween:Play()
			end,
		}, {
			-- Corner
			UICorner = React.createElement("UICorner", {
				CornerRadius = cornerRadius,
			}),
			
			-- Stud overlay removed for cleaner look (studs only on main panel)
			-- StudOverlay = createStudMaskOverlay({
			-- 	transparency = 0.12,
			-- 	tilePx = studPx("Button"),
			-- 	zIndex = 2,
			-- 	cornerRadius = cornerRadius,
			-- 	strokePx = THEME.BUTTON_OUTLINE_THICKNESS,
			-- }),
			
			-- Outer outline
			Outline = React.createElement("UIStroke", {
				Color = THEME.OUTLINE_BLACK,
				Thickness = THEME.BUTTON_OUTLINE_THICKNESS,
				Transparency = 0,
			}),
			
			-- Plastic bevel (light)
			Bevel = createPlasticBevel(),
			
			-- Text
			ButtonText = createOutlinedText({
				Size = UDim2.new(1, 0, 1, 0),
				Position = UDim2.new(0, 0, 0, 0),
				Text = text,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = props.TextSize or 14,
				Font = props.Font or THEME.TEXT_FONT,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Center,
				ZIndex = zIndex + 1,
			}),
		}),
	})
end

-- Create chunky tile card
local function createChunkyTile(props)
	local size = props.Size
	local position = props.Position
	local backgroundColor = props.BackgroundColor3 or THEME.TILE_COLORS.Common
	local isRainbow = props.IsRainbow or false
	local cornerRadius = UDim.new(0, THEME.TILE_CORNER_RADIUS)
	local zIndex = props.ZIndex or 2
	local anchorPoint = props.AnchorPoint or Vector2.new(0, 0)
	
	local tileContent = {
		-- Corner
		UICorner = React.createElement("UICorner", {
			CornerRadius = cornerRadius,
		}),
		
		-- Background gradient (for rainbow)
		BackgroundGradient = isRainbow and React.createElement("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 100, 100)),
				ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 200, 100)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(100, 255, 100)),
				ColorSequenceKeypoint.new(0.75, Color3.fromRGB(100, 200, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 100, 255)),
			}),
		}) or nil,
		
		-- Stud overlay removed for cleaner look (studs only on main panel)
		-- StudOverlay = createStudMaskOverlay({
		-- 	transparency = 0.18,
		-- 	tilePx = studPx("Tile"),
		-- 	zIndex = 2,
		-- 	cornerRadius = cornerRadius,
		-- 	strokePx = THEME.TILE_OUTLINE_THICKNESS,
		-- }),
		
		-- Outer outline
		Outline = React.createElement("UIStroke", {
			Color = THEME.OUTLINE_BLACK,
			Thickness = THEME.TILE_OUTLINE_THICKNESS,
			Transparency = 0,
		}),
	}
	
	-- Add children
	if props.Children then
		for key, child in pairs(props.Children) do
			tileContent[key] = child
		end
	end
	
	-- Return wrapper Frame with shadow and tile as siblings
	local wrapperProps = {
		Size = size,
		Position = position,
		AnchorPoint = anchorPoint,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = zIndex,
		LayoutOrder = props.LayoutOrder,
	}
	
	-- Add optional event handlers
	if props.OnMouseEnter then
		wrapperProps[React.Event.MouseEnter] = props.OnMouseEnter
	end
	if props.OnMouseLeave then
		wrapperProps[React.Event.MouseLeave] = props.OnMouseLeave
	end
	
	return React.createElement("Frame", wrapperProps, {
		-- Shadow (sibling, behind)
		Shadow = createShadowFrame({
			Size = UDim2.new(1, -SHADOW_DX, 1, -SHADOW_DY), -- Card size, not wrapper size
			BasePosition = UDim2.new(0, 0, 0, 0),
			AnchorPoint = anchorPoint,
			CornerRadius = cornerRadius,
			ZIndex = zIndex,
		}),
		
		-- Tile (sibling, on top)
		Tile = React.createElement("Frame", {
			Size = UDim2.new(1, -SHADOW_DX, 1, -SHADOW_DY), -- Leave room for shadow offset
			Position = UDim2.new(0, 0, 0, 0),
			AnchorPoint = anchorPoint,
			BackgroundColor3 = backgroundColor,
			BorderSizePixel = 0,
			ClipsDescendants = true, -- Prevent bevel spill
			ZIndex = zIndex,
		}, tileContent),
	})
end

-- Sanitize status text
local function sanitizeStatusText(text)
	if typeof(text) ~= "string" then
		return text
	end
	local cleaned = text:gsub("<font.->", ""):gsub("</font>", "")
	return cleaned
end

-- RemoteEvents
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local requestBuyHelper = remotes:WaitForChild("RequestBuyHelper")
local requestPlaceHelper = remotes:WaitForChild("RequestPlaceHelper")
local helperResponse = remotes:WaitForChild("HelperResponse")

-- Shop RemoteEvents
local requestHelperShopPurchase = ReplicatedStorage:FindFirstChild("RequestHelperShopPurchase")
local requestHelperShopList = ReplicatedStorage:FindFirstChild("RequestHelperShopList")
local requestHelperShopReroll = ReplicatedStorage:FindFirstChild("RequestHelperShopReroll")
local getHelperPriceEvent = ReplicatedStorage:FindFirstChild("GetHelperPriceEvent")
local helperResponseEvent = ReplicatedStorage:FindFirstChild("HelperResponseEvent")

-- Global state
_G.HelperPlacementData = _G.HelperPlacementData or {
	availableHelpers = {},
	selectedHelper = nil,
	isPlacing = false,
	isShopMode = false,
	shopHelpers = {},
	shopPrice = 0,
	playerCoins = 0,
	rerollCost = 20,
	statusText = "Loading...",
	statusColor = Color3.fromRGB(200, 200, 200),
	isVisible = false,
	isMinimized = false,
	updateTime = 0,
	currentPage = 1,
}

-- ===== SHOP MODE FUNCTIONS =====

local function randomizeShopHelpers(allHelpers)
	if #allHelpers == 0 then return {} end
	
	local result = {}
	local random = Random.new(tick())
	local totalHelpers = #allHelpers
	
	for i = 1, SLOTS_VISIBLE do
		if totalHelpers > 0 then
			local randomIndex = random:NextInteger(1, totalHelpers)
			table.insert(result, allHelpers[randomIndex])
		end
	end
	
	return result
end

local function openShop(price, helpersList)
	if not helpersList or #helpersList == 0 then
		helpersList = _G.HelperPlacementData.allAvailableHelpers or {}
		
		if #helpersList == 0 and requestHelperShopList then
			requestHelperShopList:FireServer()
		end
	end
	
	_G.HelperPlacementData.isShopMode = true
	_G.HelperPlacementData.shopPrice = price
	_G.HelperPlacementData.shopHelpers = randomizeShopHelpers(helpersList)
	_G.HelperPlacementData.rerollCost = 20
	_G.HelperPlacementData.isVisible = true
	_G.HelperPlacementData.isMinimized = false
	_G.HelperPlacementData.statusText = "Select a helper to purchase"
	_G.HelperPlacementData.statusColor = Color3.fromRGB(200, 200, 200)
	
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local coins = leaderstats:FindFirstChild("Coins")
		if coins then
			_G.HelperPlacementData.playerCoins = coins.Value
		end
	end
	
	_G.HelperPlacementData.updateTime = tick()
	print("[HelperPlacementUI] Shop opened - Price: " .. price .. ", Helpers: " .. #_G.HelperPlacementData.shopHelpers)
end

local function closeShop()
	_G.HelperPlacementData.isShopMode = false
	_G.HelperPlacementData.isVisible = false
	_G.HelperPlacementData.updateTime = tick()
	print("[HelperPlacementUI] Shop closed")
end

local function rerollShop(allHelpers)
	_G.HelperPlacementData.shopHelpers = randomizeShopHelpers(allHelpers)
	_G.HelperPlacementData.updateTime = tick()
	print("[HelperPlacementUI] Shop rerolled")
end

local function requestReroll()
	if not _G.HelperPlacementData.isShopMode then
		return
	end
	
	if not requestHelperShopReroll then
		warn("[HelperPlacementUI] RequestHelperShopReroll RemoteEvent not found!")
		return
	end
	
	requestHelperShopReroll:FireServer()
end

local function purchaseHelper(helperName)
	if not _G.HelperPlacementData.isShopMode then
		return
	end
	
	if not requestHelperShopPurchase then
		warn("[HelperPlacementUI] RequestHelperShopPurchase RemoteEvent not found!")
		return
	end
	
	print("[HelperPlacementUI] Purchasing: " .. helperName)
	requestHelperShopPurchase:FireServer(helperName)
end

-- Replace stub functions with real implementations
shopFunctionsReady = true
_G.OpenHelperShop = openShop
_G.CloseHelperShop = closeShop

-- ===== PLACEMENT MODE FUNCTIONS =====

local gridOwners = {}

local function getAllGridFloors()
	local gridFloors = {}
	local function searchDescendants(parent)
		for _, descendant in ipairs(parent:GetDescendants()) do
			if descendant:IsA("BasePart") and descendant.Name == "Gridfloor" then
				table.insert(gridFloors, descendant)
			end
		end
	end
	searchDescendants(workspace)
	return gridFloors
end

local cachedGridFloors = {}
local function refreshGridFloors()
	cachedGridFloors = getAllGridFloors()
end
refreshGridFloors()

task.spawn(function()
	while true do
		task.wait(5)
		refreshGridFloors()
	end
end)

local gridOwnershipEvent = ReplicatedStorage:FindFirstChild("GridOwnershipEvent")
if gridOwnershipEvent then
	gridOwnershipEvent.OnClientEvent:Connect(function(gridId, ownerUserId)
		gridOwners[gridId] = ownerUserId
	end)
end

local function isGridOwnedByLocalPlayer(gridPart)
	if not gridPart then
		return false
	end
	local gridId = gridPart:GetFullName()
	local ownerId = gridOwners[gridId]
	return ownerId == player.UserId
end

local function getMouseWorldOnAnyGrid()
	local unitRay = mouse.UnitRay
	local origin = unitRay.Origin
	local direction = unitRay.Direction * 1000

	if #cachedGridFloors == 0 then
		refreshGridFloors()
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = cachedGridFloors
	params.IgnoreWater = true

	local result = workspace:Raycast(origin, direction, params)
	if result and result.Instance then
		if result.Instance:IsA("BasePart") and result.Instance.Name == "Gridfloor" then
			return result.Position, result.Instance
		end
	end

	return nil, nil
end

local function snapToGridWorld(position, hitGridPart)
	if not hitGridPart then
		return nil
	end

	local localPos = hitGridPart.CFrame:PointToObjectSpace(position)
	local boardX = hitGridPart.Size.X
	local boardZ = hitGridPart.Size.Z
	local halfX = boardX / 2
	local halfZ = boardZ / 2

	if localPos.X < -halfX or localPos.X > halfX or localPos.Z < -halfZ or localPos.Z > halfZ then
		return nil
	end

	local x01 = localPos.X + halfX
	local z01 = localPos.Z + halfZ

	local col = math.floor(x01 / GRID_SIZE) + 1
	local row = math.floor(z01 / GRID_SIZE) + 1

	local centerX = (-halfX) + (col - 0.5) * GRID_SIZE
	local centerZ = (-halfZ) + (row - 0.5) * GRID_SIZE

	local localCenter = Vector3.new(centerX, 0, centerZ)
	local worldCenter = hitGridPart.CFrame:PointToWorldSpace(localCenter)

	return worldCenter, row, col
end

local function requestHelpersList()
	print("[HelperPlacementUI] Requesting helpers list...")
	requestBuyHelper:FireServer("GetHelpersList")
end

helperResponse.OnClientEvent:Connect(function(action, data)
	if action == "HelpersList" then
		_G.HelperPlacementData.availableHelpers = data.helpers or {}
		_G.HelperPlacementData.statusText = "Select a helper, then click on a grid to place it"
		_G.HelperPlacementData.updateTime = tick()
		print("[HelperPlacementUI] Loaded helper list: " .. #_G.HelperPlacementData.availableHelpers)
	elseif action == "PlaceResult" then
		if data.success then
			_G.HelperPlacementData.statusText = "Placed " .. (data.helperName or "") .. "!"
			_G.HelperPlacementData.statusColor = Color3.fromRGB(100, 255, 100)
			_G.HelperPlacementData.isPlacing = false
			_G.HelperPlacementData.selectedHelper = nil
		else
			_G.HelperPlacementData.statusText = sanitizeStatusText(data.message or "Placement failed")
			_G.HelperPlacementData.statusColor = Color3.fromRGB(255, 100, 100)
		end
		_G.HelperPlacementData.updateTime = tick()
	end
end)

if helperResponseEvent then
	helperResponseEvent.OnClientEvent:Connect(function(success, message)
		if _G.HelperPlacementData.isShopMode then
			if success then
				closeShop()
				print("[HelperPlacementUI] Purchase successful: " .. (message or ""))
			else
				_G.HelperPlacementData.statusText = sanitizeStatusText(message or "Purchase failed")
				_G.HelperPlacementData.statusColor = Color3.fromRGB(255, 100, 100)
				_G.HelperPlacementData.updateTime = tick()
				print("[HelperPlacementUI] Purchase failed: " .. (message or ""))
			end
		end
	end)
end

if requestHelperShopList then
	requestHelperShopList.OnClientEvent:Connect(function(data)
		if data and data.helpers then
			_G.HelperPlacementData.allAvailableHelpers = data.helpers
			
			if _G.HelperPlacementData.isShopMode then
				if #_G.HelperPlacementData.shopHelpers == 0 then
					_G.HelperPlacementData.shopHelpers = randomizeShopHelpers(data.helpers)
					_G.HelperPlacementData.updateTime = tick()
					print("[HelperPlacementUI] Shop populated with helpers after delay")
				else
					rerollShop(data.helpers)
				end
			end
		end
	end)
end

if requestHelperShopReroll then
	requestHelperShopReroll.OnClientEvent:Connect(function(success, message, newRerollCost, helpersData)
		if _G.HelperPlacementData.isShopMode then
			if success then
				if typeof(newRerollCost) == "number" then
					_G.HelperPlacementData.rerollCost = newRerollCost
				end
				
				if helpersData and helpersData.helpers then
					_G.HelperPlacementData.allAvailableHelpers = helpersData.helpers
					rerollShop(helpersData.helpers)
				end
				
				local leaderstats = player:FindFirstChild("leaderstats")
				if leaderstats then
					local coins = leaderstats:FindFirstChild("Coins")
					if coins then
						_G.HelperPlacementData.playerCoins = coins.Value
					end
				end
				
				_G.HelperPlacementData.statusText = "Rerolled!"
				_G.HelperPlacementData.statusColor = Color3.fromRGB(100, 255, 100)
				_G.HelperPlacementData.updateTime = tick()
				print("[HelperPlacementUI] Reroll successful, next cost: " .. (newRerollCost or "unknown"))
			else
				_G.HelperPlacementData.statusText = sanitizeStatusText(message or "Reroll failed")
				_G.HelperPlacementData.statusColor = Color3.fromRGB(255, 100, 100)
				if typeof(newRerollCost) == "number" then
					_G.HelperPlacementData.rerollCost = newRerollCost
				end
				_G.HelperPlacementData.updateTime = tick()
				print("[HelperPlacementUI] Reroll failed: " .. (message or "unknown error"))
			end
		end
	end)
end

if getHelperPriceEvent then
	getHelperPriceEvent.OnClientEvent:Connect(function(price, helperCount)
		if _G.HelperPlacementData.isShopMode then
			_G.HelperPlacementData.shopPrice = price
			_G.HelperPlacementData.updateTime = tick()
		end
	end)
end

task.spawn(function()
	while true do
		task.wait(0.5)
		if _G.HelperPlacementData.isShopMode then
			local leaderstats = player:FindFirstChild("leaderstats")
			if leaderstats then
				local coins = leaderstats:FindFirstChild("Coins")
				if coins then
					_G.HelperPlacementData.playerCoins = coins.Value
					_G.HelperPlacementData.updateTime = tick()
				end
			end
		end
	end
end)

task.spawn(function()
	task.wait(1)
	if not _G.HelperPlacementData.isShopMode then
		requestHelpersList()
	end
end)

local function selectHelper(helperName)
	_G.HelperPlacementData.selectedHelper = helperName
	_G.HelperPlacementData.isPlacing = true
	_G.HelperPlacementData.statusText = "Selected: " .. helperName .. " - Click on grid to place"
	_G.HelperPlacementData.statusColor = Color3.fromRGB(100, 255, 100)
	_G.HelperPlacementData.updateTime = tick()
	print("[HelperPlacementUI] Selected helper: " .. helperName)
end

local function onMouseClick()
	if _G.HelperPlacementData.isShopMode then
		return
	end
	
	if not _G.HelperPlacementData.isPlacing or not _G.HelperPlacementData.selectedHelper then
		return
	end
	
	local hitPosition, hitGridPart = getMouseWorldOnAnyGrid()
	if not hitPosition or not hitGridPart then
		_G.HelperPlacementData.statusText = "No grid found - click on a grid floor"
		_G.HelperPlacementData.statusColor = Color3.fromRGB(255, 100, 100)
		_G.HelperPlacementData.updateTime = tick()
		return
	end
	
	if not isGridOwnedByLocalPlayer(hitGridPart) then
		_G.HelperPlacementData.statusText = "This grid belongs to another player!"
		_G.HelperPlacementData.statusColor = Color3.fromRGB(255, 100, 100)
		_G.HelperPlacementData.updateTime = tick()
		return
	end
	
	local snappedWorld, row, col = snapToGridWorld(hitPosition, hitGridPart)
	if not snappedWorld or not row or not col then
		_G.HelperPlacementData.statusText = "Invalid grid position"
		_G.HelperPlacementData.statusColor = Color3.fromRGB(255, 100, 100)
		_G.HelperPlacementData.updateTime = tick()
		return
	end
	
	local PLAYER_MIN_ROW, PLAYER_MAX_ROW = 1, 5
	if row < PLAYER_MIN_ROW or row > PLAYER_MAX_ROW then
		_G.HelperPlacementData.statusText = "Can't place on enemy side"
		_G.HelperPlacementData.statusColor = Color3.fromRGB(255, 100, 100)
		_G.HelperPlacementData.updateTime = tick()
		return
	end
	
	print("[HelperPlacementUI] Place request fired: " .. _G.HelperPlacementData.selectedHelper)
	requestPlaceHelper:FireServer(_G.HelperPlacementData.selectedHelper, CFrame.new(snappedWorld))
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	
	if input.KeyCode == Enum.KeyCode.B then
		if not _G.HelperPlacementData.isShopMode then
			_G.HelperPlacementData.isVisible = not _G.HelperPlacementData.isVisible
			_G.HelperPlacementData.updateTime = tick()
			print("[HelperPlacementUI] Helper bar " .. (_G.HelperPlacementData.isVisible and "opened" or "closed"))
		end
	elseif input.KeyCode == Enum.KeyCode.Escape then
		if _G.HelperPlacementData.isShopMode then
			closeShop()
		else
			_G.HelperPlacementData.isVisible = false
			_G.HelperPlacementData.updateTime = tick()
		end
		print("[HelperPlacementUI] UI closed via Esc")
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
		onMouseClick()
	end
end)

task.spawn(function()
	local highlight = Instance.new("Part")
	highlight.Name = "HelperPlacementHighlight"
	highlight.Size = Vector3.new(GRID_SIZE * 0.98, 0.5, GRID_SIZE * 0.98)
	highlight.Anchored = true
	highlight.CanCollide = false
	highlight.Transparency = 0.5
	highlight.Color = Color3.fromRGB(0, 255, 0)
	highlight.Material = Enum.Material.Neon
	highlight.Parent = workspace
	
	local selectionBox = Instance.new("SelectionBox")
	selectionBox.LineThickness = 0.1
	selectionBox.Color3 = Color3.fromRGB(0, 255, 0)
	selectionBox.Adornee = highlight
	selectionBox.Parent = highlight
	
	highlight.Transparency = 1
	selectionBox.Transparency = 1
	
	RunService.RenderStepped:Connect(function()
		if _G.HelperPlacementData.isShopMode then
			highlight.Transparency = 1
			selectionBox.Transparency = 1
			return
		end
		
		if not _G.HelperPlacementData.isPlacing or not _G.HelperPlacementData.selectedHelper then
			highlight.Transparency = 1
			selectionBox.Transparency = 1
			return
		end
		
		local hitPosition, hitGridPart = getMouseWorldOnAnyGrid()
		if not hitPosition or not hitGridPart then
			highlight.Transparency = 1
			selectionBox.Transparency = 1
			return
		end
		
		local isOwned = isGridOwnedByLocalPlayer(hitGridPart)
		local snappedWorld, row, _col = snapToGridWorld(hitPosition, hitGridPart)
		
		local PLAYER_MIN_ROW, PLAYER_MAX_ROW = 1, 5
		local isValidRow = row and row >= PLAYER_MIN_ROW and row <= PLAYER_MAX_ROW
		
		if isOwned and isValidRow then
			highlight.Color = Color3.fromRGB(0, 255, 0)
			selectionBox.Color3 = Color3.fromRGB(0, 255, 0)
		else
			highlight.Color = Color3.fromRGB(255, 0, 0)
			selectionBox.Color3 = Color3.fromRGB(255, 0, 0)
		end
		
		if not isOwned then
			_G.HelperPlacementData.statusText = "This grid belongs to another player!"
			_G.HelperPlacementData.statusColor = Color3.fromRGB(255, 100, 100)
		elseif not isValidRow then
			_G.HelperPlacementData.statusText = "Can't place on enemy side"
			_G.HelperPlacementData.statusColor = Color3.fromRGB(255, 100, 100)
		else
			_G.HelperPlacementData.statusText = "Click to place"
			_G.HelperPlacementData.statusColor = Color3.fromRGB(200, 200, 200)
		end
		
		if snappedWorld then
			local floorY = hitGridPart.Position.Y + (hitGridPart.Size.Y / 2)
			highlight.Position = Vector3.new(snappedWorld.X, floorY + 0.25, snappedWorld.Z)
			highlight.Transparency = 0.5
			selectionBox.Transparency = 0
		else
			highlight.Transparency = 1
			selectionBox.Transparency = 1
		end
	end)
end)

-- ===== VIEWPORT ENHANCEMENT FUNCTIONS =====

-- Play idle animation on model (Humanoid or AnimationController)
local function playIdleAnimation(model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local animator = nil
	
	if humanoid then
		animator = humanoid:FindFirstChildOfClass("Animator")
		if not animator then
			animator = Instance.new("Animator")
			animator.Parent = humanoid
		end
	else
		-- Check for AnimationController (for non-humanoid models)
		local animationController = model:FindFirstChildOfClass("AnimationController")
		if animationController then
			animator = animationController:FindFirstChildOfClass("Animator")
			if not animator then
				animator = Instance.new("Animator")
				animator.Parent = animationController
			end
		else
			-- Create AnimationController + Animator for models with joints
			local hasJoints = false
			for _, descendant in ipairs(model:GetDescendants()) do
				if descendant:IsA("Motor6D") or descendant:IsA("WeldConstraint") then
					hasJoints = true
					break
				end
			end
			if hasJoints then
				animationController = Instance.new("AnimationController")
				animationController.Parent = model
				animator = Instance.new("Animator")
				animator.Parent = animationController
			end
		end
	end
	
	if not animator then
		return nil
	end
	
	-- Find idle animation
	local idleAnimation = nil
	
	-- First try: check for Animations folder
	local animationsFolder = model:FindFirstChild("Animations")
	if animationsFolder then
		-- Look for "Idle" animation in folder
		idleAnimation = animationsFolder:FindFirstChild("Idle")
		if not idleAnimation then
			-- Find any animation containing "idle" (case-insensitive)
			for _, child in ipairs(animationsFolder:GetChildren()) do
				if child:IsA("Animation") then
					local nameLower = child.Name:lower()
					if nameLower:find("idle") then
						idleAnimation = child
						break
					end
				end
			end
		end
	end
	
	-- Second try: find Animation named "Idle" or containing "idle" (case-insensitive) anywhere in model
	if not idleAnimation then
		for _, descendant in ipairs(model:GetDescendants()) do
			if descendant:IsA("Animation") then
				local nameLower = descendant.Name:lower()
				if nameLower == "idle" or nameLower:find("idle") then
					idleAnimation = descendant
					break
				end
			end
		end
	end
	
	-- Fallback: use first Animation found
	if not idleAnimation then
		idleAnimation = model:FindFirstChildOfClass("Animation", true)
	end
	
	if not idleAnimation then
		return nil
	end
	
	-- Load and play animation
	local animationTrack = animator:LoadAnimation(idleAnimation)
	if animationTrack then
		animationTrack.Looped = true
		animationTrack.Priority = Enum.AnimationPriority.Idle
		animationTrack:Play()
		return animationTrack
	end
	
	return nil
end

-- Enable all particles, trails, and beams in the model
local function enableViewportEffects(model)
	-- Enable ParticleEmitters, Trails, and Beams
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("ParticleEmitter") then
			descendant.Enabled = true
		elseif descendant:IsA("Trail") then
			descendant.Enabled = true
		elseif descendant:IsA("Beam") then
			descendant.Enabled = true
		end
	end
end

-- Add highlight outline to viewport model
local function addViewportHighlight(model, helperName)
	-- Remove existing highlight if any
	local existingHighlight = model:FindFirstChild("ViewportHighlight")
	if existingHighlight then
		existingHighlight:Destroy()
	end
	
	local rarityColors = getRarityColors(helperName)
	local primaryColor = rarityColors.primary
	
	local highlight = Instance.new("Highlight")
	highlight.Name = "ViewportHighlight"
	highlight.FillTransparency = 1 -- Transparent fill
	highlight.OutlineTransparency = 0 -- Fully visible outline
	highlight.OutlineColor = primaryColor -- Rarity-based color
	highlight.Parent = model
	
	return highlight
end

-- Set hover state for viewport (increases light visibility)
local function setViewportHover(viewportFrame, isHovering, helperName)
	local model = viewportFrame:FindFirstChildOfClass("Model")
	if not model then
		return
	end
	
	local viewportLight = viewportFrame:FindFirstChild("ViewportLight")
	local topLight = viewportFrame:FindFirstChild("TopLight")
	
	if isHovering then
		-- Increase light brightness
		if viewportLight then
			local light = viewportLight:FindFirstChildOfClass("PointLight")
			if light then
				light.Brightness = 7
			end
		end
		if topLight then
			local light = topLight:FindFirstChildOfClass("PointLight")
			if light then
				light.Brightness = 4.5
			end
		end
		
		-- Optional: move camera slightly closer for "pop" effect
		local camera = viewportFrame:FindFirstChild("ViewportCamera")
		if camera and model.PrimaryPart then
			local success, cf, size = pcall(function()
				return model:GetBoundingBox()
			end)
			if success and cf and size then
				local center = cf.Position
				local maxSize = math.max(size.X, size.Y, size.Z)
				local distance = maxSize * 1.2 -- Closer than normal (1.4)
				local currentRotation = viewportFrame:GetAttribute("CameraRotation") or 0
				local rot = CFrame.Angles(0, math.rad(currentRotation), 0)
				local offset = Vector3.new(distance, distance * 0.4, distance)
				local camPos = center + rot:VectorToWorldSpace(offset)
				camera.CFrame = CFrame.lookAt(camPos, center)
			end
		end
	else
		-- Return to normal
		if viewportLight then
			local light = viewportLight:FindFirstChildOfClass("PointLight")
			if light then
				light.Brightness = 5
			end
		end
		if topLight then
			local light = topLight:FindFirstChildOfClass("PointLight")
			if light then
				light.Brightness = 3
			end
		end
		
		-- Return camera to normal distance
		local camera = viewportFrame:FindFirstChild("ViewportCamera")
		if camera and model.PrimaryPart then
			local success, cf, size = pcall(function()
				return model:GetBoundingBox()
			end)
			if success and cf and size then
				local center = cf.Position
				local maxSize = math.max(size.X, size.Y, size.Z)
				local distance = maxSize * 1.4 -- Normal distance
				local currentRotation = viewportFrame:GetAttribute("CameraRotation") or 0
				local rot = CFrame.Angles(0, math.rad(currentRotation), 0)
				local offset = Vector3.new(distance, distance * 0.4, distance)
				local camPos = center + rot:VectorToWorldSpace(offset)
				camera.CFrame = CFrame.lookAt(camPos, center)
			end
		end
	end
end

local function setupViewport(viewportFrame, helperName)
	local currentHelper = viewportFrame:GetAttribute("CurrentHelper")
	if currentHelper == helperName and viewportFrame:GetAttribute("Ready") then
		return
	end
	
	if currentHelper ~= helperName then
		viewportFrame:SetAttribute("Ready", false)
		viewportFrame:SetAttribute("CurrentHelper", nil)
		
		-- Cleanup previous model and effects
		for _, child in ipairs(viewportFrame:GetChildren()) do
			if child.Name == "ViewportCamera" or child.Name == "ViewportLight" or child.Name == "TopLight" or child:IsA("Model") then
				-- Cleanup animation tracks if model
				if child:IsA("Model") then
					local humanoid = child:FindFirstChildOfClass("Humanoid")
					if humanoid then
						local animator = humanoid:FindFirstChildOfClass("Animator")
						if animator then
							for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
								track:Stop()
							end
						end
					end
					local animationController = child:FindFirstChildOfClass("AnimationController")
					if animationController then
						local animator = animationController:FindFirstChildOfClass("Animator")
						if animator then
							for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
								track:Stop()
							end
						end
					end
				end
				child:Destroy()
			end
		end
	end
	
	print("[HelperPlacementUI] Setting up viewport for: " .. helperName)
	
	local rarityColors = getRarityColors(helperName)
	local primaryColor = rarityColors.primary
	local secondaryColor = rarityColors.secondary
	
	local displayFolder = ReplicatedStorage:FindFirstChild("HelperDisplayTemplates")
	if not displayFolder then
		warn("[HelperPlacementUI] ❌ HelperDisplayTemplates folder not found in ReplicatedStorage")
		return
	end
	
	print("[HelperPlacementUI] Found HelperDisplayTemplates folder, looking for: " .. helperName)
	
	local template = displayFolder:FindFirstChild(helperName)
	if not template then
		warn("[HelperPlacementUI] ❌ Display template not found: " .. helperName)
		local available = {}
		for _, child in ipairs(displayFolder:GetChildren()) do
			table.insert(available, child.Name)
		end
		warn("[HelperPlacementUI] Available templates: " .. table.concat(available, ", "))
		return
	end
	
	print("[HelperPlacementUI] ✅ Found template: " .. helperName)
	
	local model = template:Clone()
	local modelToShow = model
	
	if model:IsA("Folder") then
		modelToShow = model:FindFirstChildOfClass("Model")
		if not modelToShow then
			warn("[HelperPlacementUI] No model found in folder: " .. helperName)
			model:Destroy()
			return
		end
	end
	
	if not modelToShow.PrimaryPart then
		local hrp = modelToShow:FindFirstChild("HumanoidRootPart", true)
		if hrp then
			modelToShow.PrimaryPart = hrp
		end
	end
	
	modelToShow.Parent = viewportFrame
	modelToShow:PivotTo(CFrame.Angles(0, math.rad(180), 0))
	
	print("[HelperPlacementUI] ✅ Model to show: " .. modelToShow.Name)
	
	-- Enable particles, trails, and beams
	enableViewportEffects(modelToShow)
	
	-- Add highlight outline
	addViewportHighlight(modelToShow, helperName)
	
	-- Play idle animation
	playIdleAnimation(modelToShow)
	
	task.wait(0.1)
	
	local camera = Instance.new("Camera")
	camera.Name = "ViewportCamera"
	camera.Parent = viewportFrame
	viewportFrame.CurrentCamera = camera
	
	local success, cf, size = pcall(function()
		return modelToShow:GetBoundingBox()
	end)
	
	if not success or not cf or not size then
		warn("[HelperPlacementUI] ❌ Failed to get bounding box for: " .. helperName)
		return
	end
	
	local center = cf.Position
	print("[HelperPlacementUI] Model center: " .. tostring(center) .. ", size: " .. tostring(size))
	
	local maxSize = math.max(size.X, size.Y, size.Z)
	local distance = maxSize * 1.4
	
	camera.CFrame = CFrame.lookAt(center + Vector3.new(distance, distance * 0.4, distance), center)
	
	local lightPart = Instance.new("Part")
	lightPart.Name = "ViewportLight"
	lightPart.Size = Vector3.new(0.1, 0.1, 0.1)
	lightPart.Transparency = 1
	lightPart.Anchored = true
	lightPart.CanCollide = false
	lightPart.Parent = viewportFrame
	
	local light = Instance.new("PointLight")
	light.Brightness = 5
	light.Range = 200
	light.Color = Color3.new(
		(primaryColor.R + 1) / 2,
		(primaryColor.G + 1) / 2,
		(primaryColor.B + 1) / 2
	)
	light.Shadows = false
	light.Parent = lightPart
	
	lightPart.CFrame = camera.CFrame
	
	task.spawn(function()
		while modelToShow.Parent == viewportFrame and lightPart.Parent do
			lightPart.CFrame = camera.CFrame
			task.wait(0.1)
		end
	end)
	
	local topLight = Instance.new("Part")
	topLight.Name = "TopLight"
	topLight.Size = Vector3.new(0.1, 0.1, 0.1)
	topLight.Transparency = 1
	topLight.Anchored = true
	topLight.CanCollide = false
	topLight.Parent = viewportFrame
	
	local topPointLight = Instance.new("PointLight")
	topPointLight.Brightness = 3
	topPointLight.Range = 200
	topPointLight.Color = Color3.new(
		(secondaryColor.R + 1) / 2,
		(secondaryColor.G + 1) / 2,
		(secondaryColor.B + 1) / 2
	)
	topPointLight.Shadows = false
	topPointLight.Parent = topLight
	
	topLight.CFrame = CFrame.new(center + Vector3.new(0, distance * 1.5, 0))
	
	print("[HelperPlacementUI] ✅ Lighting added")
	
	task.spawn(function()
		local rotation = 0
		local offset = Vector3.new(distance, distance * 0.4, distance)
		
		while modelToShow.Parent == viewportFrame and viewportFrame.Parent do
			rotation = (rotation + 1.5) % 360
			viewportFrame:SetAttribute("CameraRotation", rotation)
			local rot = CFrame.Angles(0, math.rad(rotation), 0)
			local camPos = center + rot:VectorToWorldSpace(offset)
			
			camera.CFrame = CFrame.lookAt(camPos, center)
			if lightPart.Parent then
				lightPart.CFrame = camera.CFrame
			end
			task.wait(0.05)
		end
	end)
	
	viewportFrame:SetAttribute("Ready", true)
	viewportFrame:SetAttribute("CurrentHelper", helperName)
	
	print("[HelperPlacementUI] ✅ Viewport fully set up for " .. helperName)
end

-- HelperPlacementUI React Component
local function HelperPlacementUI()
	-- FORCE RE-RENDER WHEN GLOBAL DATA CHANGES
	local _, forceUpdate = React.useState(0)
	React.useEffect(function()
		local last = (_G.HelperPlacementData and _G.HelperPlacementData.updateTime) or 0
		local conn = RunService.Heartbeat:Connect(function()
			local now = (_G.HelperPlacementData and _G.HelperPlacementData.updateTime) or 0
			if now ~= last then
				last = now
				forceUpdate(function(x) return x + 1 end)
			end
		end)
		return function()
			conn:Disconnect()
		end
	end, {})
	
	local data = _G.HelperPlacementData or {}
	local isShopMode = data.isShopMode or false
	local isVisible = data.isVisible ~= false
	local isMinimized = data.isMinimized or false
	
	if not isVisible then
		return nil
	end
	
	local visibleHelpers = {}
	if isShopMode then
		local shopPrice = data.shopPrice or 0
		for _, helperName in ipairs(data.shopHelpers or {}) do
			table.insert(visibleHelpers, {
				name = helperName,
				cost = shopPrice,
			})
		end
	else
		local availableHelpers = data.availableHelpers or {}
		local currentPage = data.currentPage or 1
		local totalHelpers = #availableHelpers
		local _totalPages = math.ceil(totalHelpers / SLOTS_VISIBLE)
		local startIndex = (currentPage - 1) * SLOTS_VISIBLE + 1
		local endIndex = math.min(startIndex + SLOTS_VISIBLE - 1, totalHelpers)
		
		for i = startIndex, endIndex do
			if availableHelpers[i] then
				local helperData = availableHelpers[i]
				local helperName = helperData.name or helperData
				local helperCost = helperData.cost or 0
				table.insert(visibleHelpers, {
					name = helperName,
					cost = helperCost,
				})
			end
		end
	end
	
	local slotItems = {}
	for i, helperInfo in ipairs(visibleHelpers) do
		local helperDataName = helperInfo.name
		local helperCost = helperInfo.cost or 0
		
		local isSelected = not isShopMode and data.selectedHelper == helperDataName
		
		local tileColor = getTileColor(helperDataName)
		local isRainbow = isRainbowRarity(helperDataName)
		
		local viewportName = "Viewport_" .. helperDataName .. "_" .. i
		
		local buttonText = isShopMode and "BUY" or (isSelected and "Selected" or "Select")
		local buttonAction = isShopMode and function()
			purchaseHelper(helperDataName)
		end or function()
			selectHelper(helperDataName)
		end
		
		-- Create hover handlers for tile glow
		local rarityColors = getRarityColors(helperDataName)
		local glowColor = rarityColors.primary
		
		local function onTileMouseEnter(frame)
			-- Find the glow stroke and make it visible
			local tile = frame:FindFirstChild("Tile")
			if tile then
				local glowStroke = tile:FindFirstChild("HoverGlow")
				if glowStroke then
					glowStroke.Color = glowColor
					glowStroke.Transparency = 0.55
				end
			end
		end
		
		local function onTileMouseLeave(frame)
			-- Hide the glow stroke
			local tile = frame:FindFirstChild("Tile")
			if tile then
				local glowStroke = tile:FindFirstChild("HoverGlow")
				if glowStroke then
					glowStroke.Transparency = 1
				end
			end
		end
		
		slotItems[i] = createChunkyTile({
			Size = UDim2.new(0, SLOT_CELL_W, 0, SLOT_CELL_H),
			Position = UDim2.new(0, 0, 0, 0),
			BackgroundColor3 = tileColor,
			IsRainbow = isRainbow,
			LayoutOrder = i,
			ZIndex = 2,
			OnMouseEnter = onTileMouseEnter,
			OnMouseLeave = onTileMouseLeave,
			Children = {
				-- Hover glow effect (added to tile content)
				HoverGlow = React.createElement("UIStroke", {
					Name = "HoverGlow",
					Color = glowColor,
					Thickness = 3,
					Transparency = 1, -- Hidden by default
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				}),
				-- Price text at top-left with proper padding
				CostText = createOutlinedText({
					Size = UDim2.new(1, -PADDING, 0, 20),
					Position = UDim2.new(0, PADDING/2, 0, PADDING/2),
					Text = tostring(helperCost) .. " 🪙",
					TextColor3 = Color3.fromRGB(255, 255, 100),
					TextSize = 13,
					Font = THEME.TEXT_FONT,
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = 4,
				}),
				
				-- ViewportFrame for 3D model - centered vertically, larger
				ViewportContainer = React.createElement("Frame", {
					Size = UDim2.new(1, -PADDING, 0, 110),
					Position = UDim2.new(0, PADDING/2, 0, 30),
					BackgroundColor3 = Color3.fromRGB(70, 80, 95), -- Lighter viewport background
					BorderSizePixel = 0,
					Name = viewportName .. "_Container",
					ZIndex = 10, -- High ZIndex for viewport container
					[React.Event.MouseEnter] = function(frame)
						-- Find the viewport and trigger hover
						task.spawn(function()
							local viewport = frame:FindFirstChild("Viewport")
							if viewport and viewport:IsA("ViewportFrame") then
								setViewportHover(viewport, true, helperDataName)
							end
						end)
					end,
					[React.Event.MouseLeave] = function(frame)
						-- Find the viewport and remove hover
						task.spawn(function()
							local viewport = frame:FindFirstChild("Viewport")
							if viewport and viewport:IsA("ViewportFrame") then
								setViewportHover(viewport, false, helperDataName)
							end
						end)
					end,
				}, {
					UICorner = React.createElement("UICorner", {
						CornerRadius = UDim.new(0, 4),
					}),
					InnerBorder = React.createElement("UIStroke", {
						Color = THEME.OUTLINE_BLACK,
						Thickness = 2,
						Transparency = 0,
					}),
					-- Subtle studs overlay inside viewport (behind model) - very subtle
					Studs = createStudMaskOverlay({
						transparency = 0.80,
						tilePx = studPx("Viewport"),
						zIndex = 1,
						cornerRadius = UDim.new(0, 4),
						strokePx = 2, -- InnerBorder thickness
					}),
					-- ViewportFrame (models render on top)
					Viewport = React.createElement("ViewportFrame", {
						Size = UDim2.new(1, -4, 1, -4),
						Position = UDim2.new(0, 2, 0, 2),
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						Name = "Viewport",
						ZIndex = 10, -- High ZIndex so models render above all UI layers
					}),
				}),
				
				-- Helper name - proper spacing from viewport
				HelperName = createOutlinedText({
					Size = UDim2.new(1, -PADDING, 0, 22),
					Position = UDim2.new(0, PADDING/2, 0, 145),
					Text = helperDataName,
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextSize = 13,
					Font = THEME.TEXT_FONT,
					TextXAlignment = Enum.TextXAlignment.Center,
					ZIndex = 4,
				}),
				
				-- Action button - consistent size and spacing
				ActionButton = createChunkyButton({
					Size = UDim2.new(1, -PADDING, 0, 32),
					Position = UDim2.new(0, PADDING/2, 1, -PADDING/2 - 32),
					BackgroundColor3 = isSelected and Color3.fromRGB(100, 200, 115) or THEME.BUTTON_GREEN,
					Text = buttonText,
					TextSize = 13,
					OnClick = buttonAction,
					ZIndex = 4,
				}),
			},
		})
	end
	
	-- Calculate panel size
	local numSlots = math.min(SLOTS_VISIBLE, #visibleHelpers)
	local gridGap = 10
	local panelWidth = numSlots * SLOT_CELL_W + (numSlots - 1) * gridGap + PADDING * 2
	local panelHeight = isMinimized and 60 or (SLOT_CELL_H + (isShopMode and 170 or 120))
	
	-- Adaptive bottom margin: larger for shop mode (taller panel)
	local bottomMargin = isShopMode and 120 or 40
	
	-- Main panel wrapper (shadow and panel as siblings)
	local mainPanelWrapper = React.createElement("Frame", {
		Size = UDim2.new(0, panelWidth, 0, panelHeight),
		Position = UDim2.new(0.5, 0, 1, -bottomMargin),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Name = "HelperShopBarWrapper",
		ZIndex = 1,
	}, {
		-- Shadow (sibling, behind)
		Shadow = createShadowFrame({
			Size = UDim2.new(0, panelWidth, 0, panelHeight),
			BasePosition = UDim2.new(0.5, 0, 0.5, 0),
			AnchorPoint = Vector2.new(0.5, 0.5),
			CornerRadius = UDim.new(0, 8), -- More brick-like
			ZIndex = 1,
		}),
		
		-- Main panel (sibling, on top)
		MainPanel = React.createElement("Frame", {
			Size = UDim2.new(1, 0, 1, 0),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = THEME.PANEL_BG,
			BorderSizePixel = 0,
			Name = "HelperShopBar",
			ZIndex = 1,
		}, {
		
		-- Padding
		UIPadding = React.createElement("UIPadding", {
			PaddingTop = UDim.new(0, PADDING),
			PaddingBottom = UDim.new(0, PADDING),
			PaddingLeft = UDim.new(0, PADDING),
			PaddingRight = UDim.new(0, PADDING),
		}),
		
		-- Corner
		UICorner = React.createElement("UICorner", {
			CornerRadius = UDim.new(0, 8), -- More brick-like
		}),
		
		-- Stud overlay (chunky studs - big panel studs)
		StudOverlay = createStudMaskOverlay({
			transparency = 0.22,
			tilePx = studPx("Panel"),
			zIndex = 2,
			cornerRadius = UDim.new(0, 8),
			strokePx = THEME.PANEL_OUTLINE_THICKNESS,
			insetPx = PADDING, -- Cancel UIPadding so studs reach edges
		}),
		
		-- Main outline
		Outline = React.createElement("UIStroke", {
			Color = THEME.OUTLINE_BLACK,
			Thickness = THEME.PANEL_OUTLINE_THICKNESS,
			Transparency = 0,
		}),
		
		-- Plastic bevel
		Bevel = createPlasticBevel(),
		
		-- Header area
		HeaderArea = not isMinimized and React.createElement("Frame", {
			Size = UDim2.new(1, 0, 0, 50),
			Position = UDim2.new(0, 0, 0, 0),
			BackgroundTransparency = 1,
			ZIndex = 2,
		}, {
			-- Title area (top-left)
			TitleArea = React.createElement("Frame", {
				Size = UDim2.new(1, -120, 0, 40),
				Position = UDim2.new(0, 0, 0, 0),
				BackgroundTransparency = 1,
				ZIndex = 3,
			}, {
				TitleIcon = createOutlinedText({
					Size = UDim2.new(0, 30, 0, 30),
					Position = UDim2.new(0, 0, 0.5, 0),
					AnchorPoint = Vector2.new(0, 0.5),
					Text = "🎁",
					TextSize = 24,
					Font = Enum.Font.Gotham,
					TextXAlignment = Enum.TextXAlignment.Center,
					ZIndex = 4,
				}),
				TitleText = createOutlinedText({
					Size = UDim2.new(1, -40, 1, 0),
					Position = UDim2.new(0, 35, 0, 0),
					Text = isShopMode and "SHOP!" or "HELPERS!",
					TextColor3 = THEME.TITLE_YELLOW,
					TextSize = 24,
					Font = THEME.TEXT_FONT,
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = 4,
				}),
			}),
			
			-- Header right-side layout (coins + close button)
			HeaderRight = isShopMode and React.createElement("Frame", {
				Size = UDim2.new(0, 230, 0, 40),
				Position = UDim2.new(1, 0, 0, 0),
				AnchorPoint = Vector2.new(1, 0),
				BackgroundTransparency = 1,
				ZIndex = 3,
			}, {
				UIPadding = React.createElement("UIPadding", {
					PaddingRight = UDim.new(0, 0),
					PaddingTop = UDim.new(0, 0),
				}),
				UIListLayout = React.createElement("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Right,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 10),
				}),
				
				CoinsDisplay = React.createElement("Frame", {
					Size = UDim2.new(0, 170, 0, 30),
					BackgroundTransparency = 1,
					LayoutOrder = 1,
					ZIndex = 3,
				}, {
					Pill = React.createElement("Frame", {
						Size = UDim2.new(1, 0, 1, 0),
						BackgroundColor3 = Color3.fromRGB(45, 50, 60),
						BorderSizePixel = 0,
						ZIndex = 2,
					}, {
						UICorner = React.createElement("UICorner", {
							CornerRadius = UDim.new(0, 10),
						}),
						Stroke = React.createElement("UIStroke", {
							Color = THEME.OUTLINE_BLACK,
							Thickness = 2,
						}),
					}),
					CoinsLabel = createOutlinedText({
						Size = UDim2.new(1, 0, 1, 0),
						Position = UDim2.new(0, 0, 0, 0),
						Text = "Coins: " .. (data.playerCoins or 0),
						TextColor3 = Color3.fromRGB(100, 255, 100),
						TextSize = 14,
						Font = THEME.TEXT_FONT,
						TextXAlignment = Enum.TextXAlignment.Right,
						ZIndex = 4,
					}),
				}),
				
				CloseButton = React.createElement("Frame", {
					Size = UDim2.new(0, 40, 0, 40),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					LayoutOrder = 2,
					ZIndex = 3,
				}, {
					Shadow = createShadowFrame({
						Size = UDim2.new(0, 40, 0, 40),
						BasePosition = UDim2.new(0, 0, 0, 0),
						AnchorPoint = Vector2.new(0, 0),
						CornerRadius = UDim.new(0, 6), -- More brick-like
						ZIndex = 3,
					}),
					
					Button = React.createElement("TextButton", {
						Size = UDim2.new(1, 0, 1, 0),
						Position = UDim2.new(0, 0, 0, 0),
						AnchorPoint = Vector2.new(0, 0),
						BackgroundColor3 = THEME.BUTTON_RED,
						BorderSizePixel = 0,
						Text = "",
						AutoButtonColor = false,
						ZIndex = 3,
						[React.Event.Activated] = function()
							if isShopMode then
								closeShop()
							else
								_G.HelperPlacementData.isVisible = false
								_G.HelperPlacementData.updateTime = tick()
							end
							print("[HelperPlacementUI] ✅ UI closed")
						end,
					}, {
						UICorner = React.createElement("UICorner", {
							CornerRadius = UDim.new(0, 6), -- More brick-like
						}),
						Outline = React.createElement("UIStroke", {
							Color = THEME.OUTLINE_BLACK,
							Thickness = THEME.BUTTON_OUTLINE_THICKNESS,
							Transparency = 0,
						}),
						CloseX = createOutlinedText({
							Size = UDim2.new(1, 0, 1, 0),
							Position = UDim2.new(0, 0, 0, 0),
							Text = "×",
							TextColor3 = Color3.fromRGB(255, 255, 255),
							TextSize = 24,
							Font = THEME.TEXT_FONT,
							TextXAlignment = Enum.TextXAlignment.Center,
							TextYAlignment = Enum.TextYAlignment.Center,
							ZIndex = 4,
						}),
					}),
				}),
			}) or nil,
		}) or nil,
		
		-- Price header row (shop mode only, above grid)
		PriceHeader = isShopMode and not isMinimized and React.createElement("Frame", {
			Size = UDim2.new(1, 0, 0, 25),
			Position = UDim2.new(0, 0, 0, 60),
			BackgroundTransparency = 1,
			ZIndex = 2,
		}, {
			PriceLabel = createOutlinedText({
				Size = UDim2.new(0, 200, 1, 0),
				Position = UDim2.new(0, 0, 0, 0),
				Text = "Price: " .. (data.shopPrice or 0) .. " 🪙",
				TextColor3 = Color3.fromRGB(255, 255, 100),
				TextSize = 13,
				Font = THEME.TEXT_FONT,
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 3,
			}),
		}) or nil,
		
		-- Slots container (grid) - centered with UIGridLayout
		SlotsContainer = not isMinimized and React.createElement("Frame", {
			Size = UDim2.new(1, 0, 0, SLOT_CELL_H),
			Position = UDim2.new(0, 0, 0, isShopMode and 95 or 60),
			BackgroundTransparency = 1,
			ZIndex = 2,
		}, {
			UIGridLayout = React.createElement("UIGridLayout", {
				CellSize = UDim2.new(0, SLOT_CELL_W, 0, SLOT_CELL_H),
				CellPadding = UDim2.new(0, gridGap, 0, 0),
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				FillDirectionMaxCells = numSlots,
			}),
		}, slotItems) or nil,
		
		-- Bottom action section (warning + reroll) - centered via UIListLayout
		BottomSection = not isMinimized and isShopMode and React.createElement("Frame", {
			Size = UDim2.new(1, 0, 0, 110),
			Position = UDim2.new(0, 0, 0, (isShopMode and (95 + SLOT_CELL_H + 20) or (60 + SLOT_CELL_H + 20))),
			BackgroundTransparency = 1,
			ZIndex = 3,
		}, {
			UIListLayout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Top,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 10),
			}),
			
			WarningText = createOutlinedText({
				Size = UDim2.new(1, 0, 0, 25),
				Text = "Leaving will RESET your shop!",
				TextColor3 = THEME.WARNING_RED,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Center,
				LayoutOrder = 1,
				FontFace = PIXEL_FACE,
				ZIndex = 4,
			}),
			
			RerollButton = createChunkyButton({
				Size = UDim2.new(0, 250, 0, 45),
				Position = UDim2.new(0, 0, 0, 0), -- layout handles centering
				AnchorPoint = Vector2.new(0, 0),
				BackgroundColor3 = THEME.BUTTON_GREEN,
				Text = "REROLL (" .. (data.rerollCost or 20) .. " 🪙)",
				TextSize = 15,
				OnClick = function()
					requestReroll()
				end,
				ZIndex = 4,
			}),
		}) or nil,
		
		-- Warning text for placement mode
		PlacementWarning = not isMinimized and not isShopMode and createOutlinedText({
			Size = UDim2.new(1, 0, 0, 25),
			Position = UDim2.new(0, 0, 1, -30),
			AnchorPoint = Vector2.new(0, 1),
			Text = "Select a helper, then click on grid to place",
			TextColor3 = THEME.WARNING_RED,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Center,
			FontFace = PIXEL_FACE,
			ZIndex = 2,
		}) or nil,
		}),
	})
	
	-- Setup viewports after render
	task.spawn(function()
		task.wait(0.2)
		local playerGui = player:FindFirstChild("PlayerGui")
		if not playerGui then return end
		
		local shopBar = playerGui:FindFirstChild("HelperShopBar", true)
		if not shopBar then return end
		
		for i, helperInfo in ipairs(visibleHelpers) do
			local helperDataName = helperInfo.name
			
			local viewportName = "Viewport_" .. helperDataName .. "_" .. i
			local viewportContainer = shopBar:FindFirstChild(viewportName .. "_Container", true)
			
			if viewportContainer then
				local viewport = viewportContainer:FindFirstChild("Viewport")
				if viewport and viewport:IsA("ViewportFrame") then
					setupViewport(viewport, helperDataName)
				end
			end
		end
	end)
	
	return mainPanelWrapper
end

return HelperPlacementUI
