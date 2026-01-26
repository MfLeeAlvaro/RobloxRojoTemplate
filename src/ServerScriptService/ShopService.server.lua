--========================================================
-- ShopService (SERVER)
-- Sends ShopUpdate to ShopClient UI, handles Buy, tracks inventory on Player attributes.
-- Exposes _G.ShopService.Send(player) and _G.ShopService.NextWave()
--========================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local TEMPLATES_FOLDER = ServerStorage:WaitForChild("HelperTemplates")

-- RemoteEvent: ShopEvent (ShopClient expects this)
local shopEvent = ReplicatedStorage:FindFirstChild("ShopEvent")
if not shopEvent then
	shopEvent = Instance.new("RemoteEvent")
	shopEvent.Name = "ShopEvent"
	shopEvent.Parent = ReplicatedStorage
end

--========================
-- CONFIG
--========================
local SHOP_SLOTS = 5

-- You can add more units here anytime.
local UNIT_POOL = {
	{ name = "MagicHobo",  cost = 100, weight = 60 },
	{ name = "Appraiser",  cost = 150, weight = 30 },
	{ name = "Indigenous", cost = 200, weight = 10 },
}

-- Costs lookup
local COST_BY_NAME = {}
for _, u in ipairs(UNIT_POOL) do
	COST_BY_NAME[u.name] = u.cost
end

--========================
-- STATE
--========================
local currentWave = 1
local currentShopByUserId = {} -- [userId] = { offers = {..}, wave = number }

--========================
-- COINS
--========================
local function getCoins(player: Player): number
	local ls = player:FindFirstChild("leaderstats")
	local coins = ls and ls:FindFirstChild("Coins")
	if coins and coins:IsA("IntValue") then
		return coins.Value
	end

	local v = player:GetAttribute("Coins")
	if typeof(v) == "number" then
		return v
	end
	return 0
end

local function setCoins(player: Player, newValue: number)
	local ls = player:FindFirstChild("leaderstats")
	local coins = ls and ls:FindFirstChild("Coins")
	if coins and coins:IsA("IntValue") then
		coins.Value = newValue
		return
	end
	player:SetAttribute("Coins", newValue)
end

--========================
-- INVENTORY (Player attributes)
-- Inv_<UnitName> = number
--========================
local function ensureInventoryAttributes(player: Player)
	for _, u in ipairs(UNIT_POOL) do
		local key = "Inv_" .. u.name
		if player:GetAttribute(key) == nil then
			player:SetAttribute(key, 0)
		end
	end
end

local function addInventory(player: Player, unitName: string, amount: number)
	local key = "Inv_" .. unitName
	local cur = player:GetAttribute(key)
	if typeof(cur) ~= "number" then cur = 0 end
	player:SetAttribute(key, cur + amount)
end

local function getInventorySnapshot(player: Player)
	local snap = {}
	for _, u in ipairs(UNIT_POOL) do
		local key = "Inv_" .. u.name
		local cur = player:GetAttribute(key)
		if typeof(cur) ~= "number" then cur = 0 end
		snap[u.name] = cur
	end
	return snap
end

--========================
-- SHOP ROLLING
--========================
local function weightedPick(): string
	local total = 0
	for _, u in ipairs(UNIT_POOL) do total += u.weight end

	local r = math.random() * total
	local acc = 0
	for _, u in ipairs(UNIT_POOL) do
		acc += u.weight
		if r <= acc then
			return u.name
		end
	end
	return UNIT_POOL[1].name
end

local function rollOffers()
	local offers = table.create(SHOP_SLOTS)
	for i = 1, SHOP_SLOTS do
		offers[i] = weightedPick()
	end
	return offers
end

local function setShopForPlayer(player: Player, wave: number)
	currentShopByUserId[player.UserId] = {
		wave = wave,
		offers = rollOffers(),
	}
end

local function getShopForPlayer(player: Player)
	local state = currentShopByUserId[player.UserId]
	if not state then
		setShopForPlayer(player, currentWave)
		state = currentShopByUserId[player.UserId]
	end
	return state
end

local function sendShopToPlayer(player: Player)
	ensureInventoryAttributes(player)

	local state = getShopForPlayer(player)

	shopEvent:FireClient(player, "ShopUpdate", {
		wave = state.wave or currentWave,
		offers = state.offers,
		costs = COST_BY_NAME,
		coins = getCoins(player),
		inventory = getInventorySnapshot(player),
	})
end

--========================
-- PUBLIC API
--========================
local ShopService = {}

function ShopService.Send(player: Player)
	-- Re-send current data (UI refresh)
	sendShopToPlayer(player)
end

function ShopService.NextWave()
	currentWave += 1
	for _, plr in ipairs(Players:GetPlayers()) do
		setShopForPlayer(plr, currentWave) -- reroll each wave
		sendShopToPlayer(plr)
	end
end

function ShopService.Reroll(player: Player)
	-- Optional manual reroll if you ever want it (you can ignore this)
	local state = getShopForPlayer(player)
	state.offers = rollOffers()
	sendShopToPlayer(player)
end

_G.ShopService = ShopService

--========================
-- PLAYER HOOKS
--========================
Players.PlayerAdded:Connect(function(player)
	ensureInventoryAttributes(player)
	setShopForPlayer(player, currentWave)
	sendShopToPlayer(player)
end)

Players.PlayerRemoving:Connect(function(player)
	currentShopByUserId[player.UserId] = nil
end)

--========================
-- REMOTE HANDLER
--========================
shopEvent.OnServerEvent:Connect(function(player, action, payload)
	if action == "RequestShop" then
		sendShopToPlayer(player)
		return
	end

	if action == "Buy" then
		if typeof(payload) ~= "table" then return end
		local unitName = payload.unitName
		if typeof(unitName) ~= "string" then return end

		-- Validate unit exists in ServerStorage templates
		local template = TEMPLATES_FOLDER:FindFirstChild(unitName)
		if not template or not template:IsA("Model") then
			shopEvent:FireClient(player, "BuyResult", { ok = false, msg = "Invalid unit." })
			sendShopToPlayer(player)
			return
		end

		local cost = COST_BY_NAME[unitName]
		if typeof(cost) ~= "number" then
			shopEvent:FireClient(player, "BuyResult", { ok = false, msg = "Unit has no cost set." })
			sendShopToPlayer(player)
			return
		end

		local coins = getCoins(player)
		if coins < cost then
			shopEvent:FireClient(player, "BuyResult", { ok = false, msg = "Not enough coins." })
			sendShopToPlayer(player)
			return
		end

		-- Buy
		setCoins(player, coins - cost)
		addInventory(player, unitName, 1)

		shopEvent:FireClient(player, "BuyResult", { ok = true, msg = ("Bought %s"):format(unitName) })
		sendShopToPlayer(player)
		return
	end

	-- Optional reroll (if you add a button later)
	if action == "Reroll" then
		ShopService.Reroll(player)
		return
	end
end)

print("✅ ShopService loaded (reworked)")
