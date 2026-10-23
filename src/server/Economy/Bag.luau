--!strict
--[[
	가방·판매소 (B 담당, D-020)
	캔 광물을 가방에 담으며 값을 확정하고, 허브 판매소 Counter에서 한 번에 판다.

	흐름
		OreMined (A) ──▶ 값 확정 · 가방에 담기 ──▶ OreBagged (C 랭킹)
		판매소 Counter 프롬프트 ──▶ 가방 전부 판매 · 코인 ──▶ OreSold (C 랭킹·퀘스트)
		PlayerEscaped (C) ──▶ 가방 가치 = 탈출 수확 ──▶ HaulSecured (C 랭킹) + 탈출 보너스
		PlayerTrapped (C) ──▶ 가방 일부 차감
		DailyLoginClaimed / QuestCompleted (C) ──▶ 보상 코인

	UI용으로 플레이어 속성 BagCount, BagCapacity, BagValue, EconomyNotice(한 줄 알림) 를 서버가 갱신한다 (Remote 없이 복제됨).
]]

local RS = game:GetService("ReplicatedStorage")

local Shared = RS:WaitForChild("Shared")
local Events = require(Shared:WaitForChild("Events"))
local EventBus = require(Shared:WaitForChild("EventBus"))
local Mines = require(Shared:WaitForChild("Config"):WaitForChild("Mines"))
local Economy = require(Shared.Config:WaitForChild("Economy"))
local Social = require(Shared.Config:WaitForChild("Social"))
local PlayerData = require(script.Parent.PlayerData)
-- C의 조회 함수 (패스 보유, 판매가 배수)
local Payments = require(script.Parent.Parent:WaitForChild("Social"):WaitForChild("Payments"))

-- 광물 이름 → 기본가. 광물표 원본은 Mines.luau (A)
local baseValue: { [string]: number } = {}
for _, m in Mines.list do
	for _, o in m.ores do
		baseValue[o.name] = o.value
	end
end

local Bag = {}

function Bag.capacity(player: Player): number
	local extra = if Payments.HasPass(player, Social.PassName.BigBag) then Economy.BIG_BAG_EXTRA else 0
	return Economy.BAG_CAPACITY + extra
end

local function bagValue(data: PlayerData.Data): number
	local sum = 0
	for _, item in data.bag do
		sum += item.value
	end
	return sum
end

-- 가방이 바뀔 때마다 부른다 (클라이언트 HUD가 속성을 읽음)
function Bag.sync(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return
	end
	player:SetAttribute("BagCount", #data.bag)
	player:SetAttribute("BagCapacity", Bag.capacity(player))
	player:SetAttribute("BagValue", bagValue(data))
end

-- 판매가 = 기본가 × 무게 × 압력 배수. 서버에서만 계산 (보안 규칙)
function Bag.priceOf(oreId: string, weight: number, pressure: string): number?
	local base = baseValue[oreId]
	local mult = Economy.PRESSURE_MULT[pressure]
	if not base or not mult then
		return nil
	end
	return math.max(1, math.floor(base * weight * mult + 0.5))
end

local function onOreMined(player: Player, oreId: string, weight: number, pressure: string)
	local data = PlayerData.get(player)
	if not data or typeof(weight) ~= "number" or weight <= 0 then
		return
	end
	if #data.bag >= Bag.capacity(player) then
		return -- 꽉 참: 안 담긴다. HUD가 "가득"을 보여 준다
	end
	local value = Bag.priceOf(oreId, weight, pressure)
	if not value then
		warn(`[Bag] 모르는 광물·압력: {oreId}, {pressure}`)
		return
	end
	table.insert(data.bag, { ore = oreId, weight = weight, pressure = pressure, value = value })
	data.codex[oreId] = true
	data.stats.bestOre = math.max(data.stats.bestOre, value)
	Bag.sync(player)
	EventBus.Fire(Events.OreBagged, player, oreId, value)
end

-- 가방 전부 판매. 판매소 프롬프트에서 부른다. 판 금액을 돌려준다
function Bag.sellAll(player: Player): number
	local data = PlayerData.get(player)
	if not data or #data.bag == 0 then
		return 0
	end
	local mult = Payments.GetMultiplier(player, Social.MultiplierKind.SellPrice)
	local perOre: { [string]: { count: number, total: number } } = {}
	for _, item in data.bag do
		local s = perOre[item.ore] or { count = 0, total = 0 }
		s.count += 1
		s.total += item.value
		perOre[item.ore] = s
	end
	data.bag = {}

	local earned = 0
	for oreId, s in perOre do
		local total = math.floor(s.total * mult + 0.5)
		earned += total
		EventBus.Fire(Events.OreSold, player, oreId, s.count, total)
	end
	data.stats.totalEarned += earned
	PlayerData.addCoins(player, earned)
	Bag.sync(player)
	return earned
end

-- 화면 아래 HUD에 한 줄 알림 (판매 결과, 제작 실패 이유 등). 같은 문구가 연달아 와도 다시 뜨게 시각도 같이 올린다
function Bag.notify(player: Player, text: string)
	player:SetAttribute("EconomyNotice", text)
	player:SetAttribute("EconomyNoticeAt", os.clock())
end

-- 허브마다 있는 건물(Shop, Workshop)의 Counter에 프롬프트를 붙인다 (스테이지별 허브, #17).
-- 이름이 CollapseMine 으로 시작하는 폴더의 Hub/<building>/Counter. 클라이언트는 name으로 찾아 문구를 바꾼다
function Bag.counterPrompt(building: string, name: string, actionText: string, onTriggered: (Player) -> (), key: Enum.KeyCode?)
	for _, hub in workspace:GetChildren() do
		local root = hub.Name:sub(1, 12) == "CollapseMine" and hub:FindFirstChild("Hub")
		local house = root and root:FindFirstChild(building)
		local counter = house and house:FindFirstChild("Counter")
		if counter and counter:IsA("BasePart") and not counter:FindFirstChild(name) then
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = name
			prompt.ActionText = actionText
			prompt.HoldDuration = 0.3
			prompt.MaxActivationDistance = 10
			prompt.RequiresLineOfSight = false
			prompt.KeyboardKeyCode = key or Enum.KeyCode.E -- 한 Counter에 프롬프트가 둘이면 키를 다르게
			prompt.Parent = counter
			prompt.Triggered:Connect(function(player: Player)
				-- 프롬프트 거리는 클라이언트가 판정하므로 서버에서 한 번 더 잰다
				local char = player.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
				if hrp and (hrp.Position - counter.Position).Magnitude <= Economy.SELL_REACH then
					onTriggered(player)
				end
			end)
		end
	end
end

local function rewardCoins(player: Player, _id: any, reward: { coins: number? }?)
	if typeof(reward) == "table" and typeof(reward.coins) == "number" and reward.coins > 0 then
		PlayerData.addCoins(player, reward.coins)
	end
end

function Bag.start()
	EventBus.On(Events.PlayerDataLoaded, Bag.sync)
	EventBus.On(Events.OreMined, onOreMined)

	EventBus.On(Events.PlayerTrapped, function(player: Player)
		local data = PlayerData.get(player)
		if data then
			PlayerData.loseBag(data)
			Bag.sync(player)
		end
	end)

	EventBus.On(Events.PlayerEscaped, function(player: Player, mineId: string, bonus: number)
		local data = PlayerData.get(player)
		if not data then
			return
		end
		local haul = bagValue(data)
		if haul > 0 then
			data.stats.bestHaul = math.max(data.stats.bestHaul, haul)
			EventBus.Fire(Events.HaulSecured, player, mineId, haul)
		end
		PlayerData.addCoins(player, bonus)
	end)

	-- 아이템 보상은 아이템 기능이 생기면 받는다 (지금은 코인만)
	EventBus.On(Events.DailyLoginClaimed, rewardCoins)
	EventBus.On(Events.QuestCompleted, rewardCoins)

	Bag.counterPrompt("Shop", "SellPrompt", "가방 전부 팔기", function(player)
		local earned = Bag.sellAll(player)
		Bag.notify(player, if earned > 0 then `{earned} 코인에 팔았어요` else "가방이 비어 있어요")
	end)

end

return Bag
