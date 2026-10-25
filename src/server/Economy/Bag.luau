--!strict
--[[
	가방·판매소 (B 담당, D-020, 무게 D-027)
	캔 광물을 가방에 담으며 값을 확정하고, 허브 판매소에서 판다. 가방은 무게(kg) 하나로 잰다.

	흐름
		OreMined (A) ──▶ 값 확정 · 가방에 담기 ──▶ OreBagged (C 랭킹)
		판매소 Counter 프롬프트·인벤토리 창 ──▶ 전부 또는 종류별 판매 · 코인 ──▶ OreSold (C 랭킹·퀘스트)
		판매소 Counter "가방 늘리기" ──▶ 코인으로 무게 한도 +kg (D-028)
		인벤토리 창 ──▶ 한 개 버리기 (광산 안에서 가볍게 탈출)
		PlayerEscaped (C) ──▶ 가방 가치 = 탈출 수확 ──▶ HaulSecured (C 랭킹) + 탈출 보너스
		PlayerTrapped (C) ──▶ 가방 일부 차감
		DailyLoginClaimed / QuestCompleted (C) ──▶ 보상 코인

	플레이어 속성 (서버가 갱신, Remote 없이 복제됨)
		BagCount, BagKg, BagCapacity(kg), BagValue, EconomyNotice(한 줄 알림)  — B의 HUD용
		BagSpeedMultiplier (1 → BAG_MIN_SPEED)  — A가 걸음 속도에 곱한다
	가방 목록·판매·버리기는 Remotes.Bag (아래 onBagRemote).
]]

local Players = game:GetService("Players")
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

-- 광물 이름 → 기본가·화면 이름. 광물표 원본은 Mines.luau (A)
local baseValue: { [string]: number } = {}
local displayName: { [string]: string } = {}
for _, m in Mines.list do
	for _, o in m.ores do
		baseValue[o.name] = o.value
		displayName[o.name] = o.displayName
	end
end
local PRESSURE_TEXT = { Low = "상압", High = "고압", Extreme = "초고압" }

local Bag = {}

-- 무게 한도 (kg). 이걸 넘으면 느려지고, × BAG_HARD_LIMIT 를 넘으면 더 안 담긴다
function Bag.capacity(player: Player): number
	local kg = Economy.BAG_MAX_KG
	if Payments.HasPass(player, Social.PassName.BigBag) then
		kg += Economy.BIG_BAG_EXTRA_KG
	end
	local data = PlayerData.get(player)
	for i = 1, data and data.bagLevel or 0 do
		kg += Economy.BAG_UPGRADES[i].kg
	end
	return kg
end

-- 판매소 "가방 늘리기" 한 단계. 실패하면 이유를 돌려준다
function Bag.upgrade(player: Player): (boolean, string)
	local data = PlayerData.get(player)
	if not data then
		return false, "데이터를 불러오는 중이에요"
	end
	local spec = Economy.BAG_UPGRADES[data.bagLevel + 1]
	if not spec then
		return false, "가방이 가장 커요"
	end
	if data.coins < spec.coins then
		return false, `코인이 {spec.coins - data.coins} 부족해요`
	end
	PlayerData.addCoins(player, -spec.coins)
	data.bagLevel += 1
	player:SetAttribute("BagLevel", data.bagLevel)
	Bag.sync(player)
	return true, `가방이 {Bag.capacity(player)}kg이 됐어요`
end

local function bagKg(data: PlayerData.Data): number
	local sum = 0
	for _, item in data.bag do
		sum += item.weight
	end
	return sum
end

-- 한도까지 1, 한도 × BAG_HARD_LIMIT 에서 BAG_MIN_SPEED 까지 선형으로 느려짐
function Bag.speedMultiplier(kg: number, capacity: number): number
	local over = math.clamp((kg / capacity - 1) / (Economy.BAG_HARD_LIMIT - 1), 0, 1)
	return 1 - over * (1 - Economy.BAG_MIN_SPEED)
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
	local kg, cap = bagKg(data), Bag.capacity(player)
	player:SetAttribute("BagCount", #data.bag)
	player:SetAttribute("BagKg", math.floor(kg * 10 + 0.5) / 10)
	player:SetAttribute("BagCapacity", cap)
	player:SetAttribute("BagValue", bagValue(data))
	player:SetAttribute("BagSpeedMultiplier", Bag.speedMultiplier(kg, cap))
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
	if bagKg(data) + weight > Bag.capacity(player) * Economy.BAG_HARD_LIMIT then
		-- 너무 무거움: 안 담긴다. 조용히 사라지면 답답하니 알려 준다
		Bag.notify(player, "가방이 너무 무거워요! 팔거나 버리세요")
		return
	end
	local value = Bag.priceOf(oreId, weight, pressure)
	if not value then
		warn(`[Bag] 모르는 광물·압력: {oreId}, {pressure}`)
		return
	end
	table.insert(data.bag, { ore = oreId, weight = weight, pressure = pressure, value = value })
	-- 도감 (D-035): 광물 키 "Coal"과 압력별 키 "Coal|High"를 같이 적는다. 처음 보는 조합이면 알린다
	local key = `{oreId}|{pressure}`
	if not data.codex[key] then
		data.codex[oreId] = true
		data.codex[key] = true
		Bag.notify(player, `📖 도감 새 기록: {displayName[oreId] or oreId} ({PRESSURE_TEXT[pressure] or pressure})`)
	end
	data.stats.bestOre = math.max(data.stats.bestOre, value)
	Bag.sync(player)
	EventBus.Fire(Events.OreBagged, player, oreId, value)
end

-- 리버스로 영구히 오른 판매가 배수
function Bag.rebirthMult(data: PlayerData.Data): number
	return 1 + data.rebirths * Economy.REBIRTH.sellBonus
end

-- 가방에서 이미 빼낸 광물들을 판다. 판매가 = 담을 때 확정한 값 × 판매가 배수
local function sell(player: Player, data: PlayerData.Data, items: { PlayerData.BagItem }): number
	-- 패스·부스트(C) × 리버스 보너스(B)
	local mult = Payments.GetMultiplier(player, Social.MultiplierKind.SellPrice) * Bag.rebirthMult(data)
	local perOre: { [string]: { count: number, total: number } } = {}
	for _, item in items do
		local s = perOre[item.ore] or { count = 0, total = 0 }
		s.count += 1
		s.total += item.value
		perOre[item.ore] = s
	end
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

-- 가방 전부 판매. 판 금액을 돌려준다
function Bag.sellAll(player: Player): number
	local data = PlayerData.get(player)
	if not data or #data.bag == 0 then
		return 0
	end
	local items = data.bag
	data.bag = {}
	return sell(player, data, items)
end

-- 인벤토리 창은 같은 광물·같은 압력끼리 한 줄로 묶어 보여 준다. 그 묶음을 판다
function Bag.sellGroup(player: Player, oreId: string, pressure: string): number
	local data = PlayerData.get(player)
	if not data then
		return 0
	end
	local sold, kept = {}, {}
	for _, item in data.bag do
		table.insert(if item.ore == oreId and item.pressure == pressure then sold else kept, item)
	end
	if #sold == 0 then
		return 0
	end
	data.bag = kept
	return sell(player, data, sold)
end

-- 묶음에서 한 개 버리기 (어디서나). 같은 묶음은 1kg당 값이 같으니 가장 무거운 것을 버려 많이 가벼워지게 한다
function Bag.dropOne(player: Player, oreId: string, pressure: string): boolean
	local data = PlayerData.get(player)
	if not data then
		return false
	end
	local pick: number? = nil
	for i, item in data.bag do
		if item.ore == oreId and item.pressure == pressure and (not pick or item.weight > data.bag[pick].weight) then
			pick = i
		end
	end
	if not pick then
		return false
	end
	table.remove(data.bag, pick)
	Bag.sync(player)
	return true
end

-- 화면 아래 HUD에 한 줄 알림 (판매 결과, 제작 실패 이유 등). 같은 문구가 연달아 와도 다시 뜨게 시각도 같이 올린다
function Bag.notify(player: Player, text: string)
	player:SetAttribute("EconomyNotice", text)
	player:SetAttribute("EconomyNoticeAt", os.clock())
end

-- 허브마다 있는 건물(Shop, Workshop)의 Counter (스테이지별 허브, #17). 이름이 CollapseMine 으로 시작하는 폴더의 Hub/<building>/Counter
local function counters(building: string): { BasePart }
	local list = {}
	for _, hub in workspace:GetChildren() do
		local root = hub.Name:sub(1, 12) == "CollapseMine" and hub:FindFirstChild("Hub")
		local house = root and root:FindFirstChild(building)
		local counter = house and house:FindFirstChild("Counter")
		if counter and counter:IsA("BasePart") then
			table.insert(list, counter)
		end
	end
	return list
end

-- 플레이어가 그 건물 Counter 근처인지. 프롬프트·창 버튼은 클라이언트가 띄우므로 서버에서 한 번 더 잰다
function Bag.isNear(player: Player, building: string): boolean
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return false
	end
	for _, counter in counters(building) do
		if (hrp.Position - counter.Position).Magnitude <= Economy.SELL_REACH then
			return true
		end
	end
	return false
end

local PROMPT_GAP = 78 -- 기본 프롬프트 높이(72px) + 여백

-- Counter에 프롬프트를 붙인다. 클라이언트는 name으로 찾아 문구를 바꾼다
function Bag.counterPrompt(building: string, name: string, actionText: string, onTriggered: (Player) -> (), key: Enum.KeyCode?, hold: number?)
	for _, counter in counters(building) do
		if not counter:FindFirstChild(name) then
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = name
			prompt.ActionText = actionText
			prompt.HoldDuration = hold or 0.3
			prompt.MaxActivationDistance = 10
			prompt.RequiresLineOfSight = false
			prompt.KeyboardKeyCode = key or Enum.KeyCode.E -- 한 Counter에 프롬프트가 둘이면 키를 다르게
			prompt.Parent = counter
			-- 같은 Counter의 프롬프트는 같은 자리에 그려져 글자가 겹친다. 위아래로 쌓고 가운데를 Counter에 맞춘다
			local stack = {}
			for _, c in counter:GetChildren() do
				if c:IsA("ProximityPrompt") then
					table.insert(stack, c)
				end
			end
			for i, p in stack do
				p.UIOffset = Vector2.new(0, (i - 1 - (#stack - 1) / 2) * PROMPT_GAP)
			end
			prompt.Triggered:Connect(function(player: Player)
				if Bag.isNear(player, building) then
					onTriggered(player)
				end
			end)
		end
	end
end

-- 인벤토리 창 (클라이언트 → 서버). Remotes.Bag (RemoteFunction)
--   "get"                     → 가방 목록 { {ore, weight, pressure, value} }
--   "codex"                   → 도감 { ["Coal"] = true, ["Coal|High"] = true, ... }
--   "sell", oreId, pressure   → 그 묶음 판매 (판매소 근처만), 판 금액
--   "sellAll"                 → 전부 판매 (판매소 근처만), 판 금액
--   "drop", oreId, pressure   → 그 묶음에서 한 개 버리기 (어디서나)
-- 결과 문구는 Bag.notify 로 HUD 알림 줄에 띄운다
-- Remote가 없으면 서버가 만든다 (Studio 수작업 없이 Rojo만으로 동작하게)
local REMOTE_COOLDOWN = 0.15
local lastCall: { [Player]: number } = {}

local function onBagRemote(player: Player, action: any, oreId: any, pressure: any): any
	if typeof(action) ~= "string" then
		return nil
	end
	local data = PlayerData.get(player)
	if not data then
		return nil
	end
	if action == "get" then
		return data.bag
	elseif action == "codex" then
		return data.codex
	end

	-- 판매·버리기만 연타 제한 (목록 조회는 판매 직후 바로 다시 부르므로 막지 않는다)
	local t = os.clock()
	if lastCall[player] and t - lastCall[player] < REMOTE_COOLDOWN then
		return nil
	end
	lastCall[player] = t
	local group = typeof(oreId) == "string" and typeof(pressure) == "string"
	if action == "drop" then
		if group and Bag.dropOne(player, oreId, pressure) then
			Bag.notify(player, "한 개 버렸어요")
		end
		return nil
	end
	if not Bag.isNear(player, "Shop") then
		Bag.notify(player, "판매소에서만 팔 수 있어요")
		return nil
	end
	local earned = 0
	if action == "sell" then
		if not group then
			return nil
		end
		earned = Bag.sellGroup(player, oreId, pressure)
	elseif action == "sellAll" then
		earned = Bag.sellAll(player)
	end
	Bag.notify(player, if earned > 0 then `{earned} 코인에 팔았어요` else "팔 광물이 없어요")
	return earned
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

	local remotes = RS:FindFirstChild("Remotes") or Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = RS
	local remote = (remotes:FindFirstChild("Bag") or Instance.new("RemoteFunction")) :: RemoteFunction
	remote.Name = "Bag"
	remote.Parent = remotes
	remote.OnServerInvoke = onBagRemote
	Players.PlayerRemoving:Connect(function(player)
		lastCall[player] = nil
	end)

	Bag.counterPrompt("Shop", "SellPrompt", "가방 전부 팔기", function(player)
		local earned = Bag.sellAll(player)
		Bag.notify(player, if earned > 0 then `{earned} 코인에 팔았어요` else "가방이 비어 있어요")
	end)
	Bag.counterPrompt("Shop", "BagUpgradePrompt", "가방 늘리기", function(player)
		local _, msg = Bag.upgrade(player)
		Bag.notify(player, msg)
	end, Enum.KeyCode.F)

end

return Bag
