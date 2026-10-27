--!strict
--[[
	가방·판매소 (B 담당, D-020, 무게 D-027)
	캔 광물을 가방에 담으며 값을 확정하고, 허브 판매소에서 판다. 가방은 무게(kg) 하나로 잰다.

	흐름
		OreMined (A) ──▶ 값 확정 · 가방에 담기 ──▶ OreBagged (C 랭킹)
		판매소 Counter 프롬프트·인벤토리 창 ──▶ 재료 남기고 전부 / 종류별 판매 · 코인 ──▶ OreSold (C 랭킹·퀘스트) (D-037)
		판매소 Counter "가방 늘리기" ──▶ 코인으로 무게 한도 +kg (D-028)
		인벤토리 창 ──▶ 한 개 버리기 (광산 안에서 가볍게 탈출)
		PlayerEscaped (C) ──▶ 광산을 나올 때 들고 있던 가치 = 탈출 수확 ──▶ HaulSecured (C 랭킹) + 탈출 보너스 (D-039)
		PlayerTrapped (C) · 경보 중 광산 안에서 죽음 ──▶ 가방 일부 차감, 한 경보에 한 번 (PlayerData.trapLoss, D-039)
		DailyLoginClaimed / QuestCompleted (C) ──▶ 보상 코인

	플레이어 속성 (서버가 갱신, Remote 없이 복제됨)
		BagCount, BagKg, BagCapacity(kg), BagValue(배수 곱하기 전)  — 가방 HUD·인벤토리
		SellMultiplier(패스·부스트 × 리버스), HasBigBag  — 배수 표시·가방 가득 안내 (D-038)
		CodexCount  — 도감 새 기록 점 (D-035)
		BagSpeedMultiplier (1 → BAG_MIN_SPEED)  — A가 걸음 속도에 곱한다
		EconomyNotice / EconomyNoticeAt  — 한 줄 알림 (Counter.notify)
	가방 목록·도감·판매·버리기는 Remotes.Bag (아래 onBagRemote).
]]

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local Shared = RS:WaitForChild("Shared")
local Events = require(Shared:WaitForChild("Events"))
local EventBus = require(Shared:WaitForChild("EventBus"))
local Mines = require(Shared:WaitForChild("Config"):WaitForChild("Mines"))
local Economy = require(Shared.Config:WaitForChild("Economy"))
local Social = require(Shared.Config:WaitForChild("Social"))
local PlayerData = require(script.Parent.PlayerData)
local Counter = require(script.Parent.Counter)
-- C의 조회 함수 (패스 보유, 판매가 배수)
local Payments = require(script.Parent.Parent:WaitForChild("Social"):WaitForChild("Payments"))
-- C의 조회 함수 (경보 중인지: 탈출 수확·경보 중 죽음 차감, D-039)
local Collapse = require(script.Parent.Parent:WaitForChild("Social"):WaitForChild("Collapse"))

-- 광물 이름 → 기본가·화면 이름. 광물표 원본은 Mines.luau (A)
local baseValue: { [string]: number } = {}
local displayName: { [string]: string } = {}
local gradeOf: { [string]: string } = {}
for _, m in Mines.list do
	for _, o in m.ores do
		baseValue[o.name] = o.value
		displayName[o.name] = o.displayName
		gradeOf[o.name] = o.grade
	end
end

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
	-- 화면 표시용: 지금 판매가 배수(패스·부스트 × 리버스)와 가방 확장 패스 보유 (가방 가득 안내에서 패스 버튼을 숨김)
	player:SetAttribute("SellMultiplier", math.floor(Bag.sellMult(player, data) * 100 + 0.5) / 100)
	player:SetAttribute("HasBigBag", Payments.HasPass(player, Social.PassName.BigBag))
	-- 도감 칸 수 (압력별 키 "Coal|High"만 센다). 늘면 클라이언트가 도감 버튼에 새 기록 점을 띄운다
	local codexCount = 0
	for key in data.codex do
		if string.find(key, "|", 1, true) then
			codexCount += 1
		end
	end
	player:SetAttribute("CodexCount", codexCount)
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
	-- 무게가 NaN·무한대면 값과 코인이 NaN이 되어 저장 데이터가 영구히 깨진다. 다른 모듈에서 온 값도 확인한다
	if not data or typeof(weight) ~= "number" or not (weight > 0 and weight < math.huge) then
		return
	end
	if bagKg(data) + weight > Bag.capacity(player) * Economy.BAG_HARD_LIMIT then
		-- 너무 무거움: 안 담긴다. 조용히 사라지면 답답하니 알려 준다
		Counter.notify(player, "가방이 너무 무거워요! 팔거나 버리세요")
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
		Counter.notify(player, `📖 도감 새 기록: {displayName[oreId] or oreId} ({Economy.PRESSURE_NAME[pressure] or pressure})`)
	end
	data.stats.bestOre = math.max(data.stats.bestOre, value)
	Bag.sync(player)
	EventBus.Fire(Events.OreBagged, player, oreId, value)
end

-- 리버스로 영구히 오른 판매가 배수
function Bag.rebirthMult(data: PlayerData.Data): number
	return 1 + data.rebirths * Economy.REBIRTH.sellBonus
end

-- 최종 판매가 배수 = 패스·부스트(C) × 리버스 보너스(B)
function Bag.sellMult(player: Player, data: PlayerData.Data): number
	return Payments.GetMultiplier(player, Social.MultiplierKind.SellPrice) * Bag.rebirthMult(data)
end

-- 판매 알림 뒤에 붙이는 배수 " (판매가 ×2)". 배수가 1이면 빈 문자열
local function multText(player: Player): string
	local data = PlayerData.get(player)
	local m = data and Bag.sellMult(player, data) or 1
	return if m > 1 then ` (판매가 ×{string.format("%g", math.floor(m * 100 + 0.5) / 100)})` else ""
end

-- 가방에서 이미 빼낸 광물들을 판다. 판매가 = 담을 때 확정한 값 × 판매가 배수
local function sell(player: Player, data: PlayerData.Data, items: { PlayerData.BagItem }): number
	local mult = Bag.sellMult(player, data)
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

-- 전부 팔기에서 남길 광물: 다음 곡괭이 재료와 카나리아 먹이를 필요한 개수만큼 (D-037).
-- 제작소(Workshop.pick)처럼 값이 싼 것부터 남긴다. 비싸게 캔 건 팔리고, 제작소는 남긴 걸 그대로 쓴다
local function reserved(data: PlayerData.Data): { [PlayerData.BagItem]: boolean }
	local keep: { [PlayerData.BagItem]: boolean } = {}
	local function hold(match: (PlayerData.BagItem) -> boolean, need: number)
		local found = {}
		for _, item in data.bag do
			if match(item) and not keep[item] then
				table.insert(found, item)
			end
		end
		table.sort(found, function(a, b)
			return a.value < b.value
		end)
		for i = 1, math.min(need, #found) do
			keep[found[i]] = true
		end
	end
	local ores, rare = Economy.materialNeeds(data.pickaxe.tier, data.canary)
	for oreId, need in ores do
		hold(function(item)
			return item.ore == oreId
		end, need)
	end
	hold(function(item)
		return gradeOf[item.ore] == Economy.CANARY_FEED_GRADE
	end, rare)
	return keep
end

-- 재료를 남기고 전부 판다. 판 금액, 남긴 개수
function Bag.sellAll(player: Player): (number, number)
	local data = PlayerData.get(player)
	if not data or #data.bag == 0 then
		return 0, 0
	end
	-- 튜토리얼 중(C의 TutorialActive)에는 남기지 않는다. 처음 캔 게 석영뿐이면 아무것도 안 팔려서
	-- "판매소에서 팔아 보세요"(OreSold) 단계가 끝나지 않는다
	local keep = if player:GetAttribute("TutorialActive") == true then {} else reserved(data)
	local sold, kept = {}, {}
	for _, item in data.bag do
		table.insert(if keep[item] then kept else sold, item)
	end
	if #sold == 0 then
		return 0, #kept
	end
	data.bag = kept
	return sell(player, data, sold), #kept
end

-- 전부 팔기 결과 문구 (판매소 프롬프트·인벤토리 창 공통)
local function sellAllNotice(player: Player, earned: number, kept: number): string
	if earned > 0 then
		local sold = `{earned} 코인에 팔았어요{multText(player)}`
		return if kept > 0 then `{sold} · 재료 {kept}개는 남겼어요` else sold
	end
	return if kept > 0 then "재료만 남았어요. 인벤토리에서 따로 팔 수 있어요" else "가방이 비어 있어요"
end

-- 인벤토리 창은 같은 광물·같은 압력끼리 한 줄로 묶어 보여 준다. 체크한 묶음들("Coal|High" 키)만 판다 (D-043).
-- 다다음 곡괭이·카나리아처럼 전부 팔기 규칙이 모르는 목표용 재료는 체크를 안 하면 남는다
function Bag.sellGroups(player: Player, keys: { [string]: boolean }): number
	local data = PlayerData.get(player)
	if not data then
		return 0
	end
	local sold, kept = {}, {}
	for _, item in data.bag do
		table.insert(if keys[item.ore .. "|" .. item.pressure] then sold else kept, item)
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

-- 인벤토리 창 (클라이언트 → 서버). Remotes.Bag (RemoteFunction)
--   "get"                     → 가방 목록 { {ore, weight, pressure, value} }
--   "codex"                   → 도감 { ["Coal"] = true, ["Coal|High"] = true, ... }
--   "sellSelected", { "Coal|High", ... } → 체크한 묶음들 판매 (판매소 근처만), 판 금액 (D-043)
--   "sellAll"                 → 재료(다음 곡괭이·카나리아 먹이)를 남기고 전부 판매 (판매소 근처만), 판 금액
--   "drop", oreId, pressure   → 그 묶음에서 한 개 버리기 (어디서나)
-- 결과 문구는 Counter.notify 로 HUD 알림 줄에 띄운다
-- Remote가 없으면 서버가 만든다 (Studio 수작업 없이 Rojo만으로 동작하게)
local REMOTE_COOLDOWN = 0.15
-- 탈출 수확용: 경보 중 광산 안에서 마지막으로 들고 있던 가치 (D-039)
local CARRY_POLL = 0.5
local carried: { [Player]: { mineId: string, value: number } } = {}
local lastCall: { [Player]: number } = {}

local MAX_SELECTED = 200 -- 묶음 수 상한 (광물 × 압력 칸 수보다 넉넉히. 큰 표를 보내 서버를 붙잡는 것 방지)

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
			Counter.notify(player, "한 개 버렸어요")
		end
		return nil
	end
	if not Counter.isNear(player, "Shop") then
		Counter.notify(player, "판매소에서만 팔 수 있어요")
		return nil
	end
	local earned = 0
	if action == "sellSelected" then
		-- 이 함수의 oreId 자리에 키 목록이 온다
		local list = oreId
		if typeof(list) ~= "table" or #list == 0 or #list > MAX_SELECTED then
			return nil
		end
		local keys: { [string]: boolean } = {}
		for i = 1, #list do -- 배열 부분만 본다 (해시 칸에 큰 표를 숨겨 보내도 돌지 않게)
			local key = list[i]
			if typeof(key) ~= "string" or #key > 64 then
				return nil
			end
			keys[key] = true
		end
		earned = Bag.sellGroups(player, keys)
	elseif action == "sellAll" then
		local kept
		earned, kept = Bag.sellAll(player)
		Counter.notify(player, sellAllNotice(player, earned, kept))
		return earned
	end
	Counter.notify(player, if earned > 0 then `{earned} 코인에 팔았어요{multText(player)}` else "팔 광물이 없어요")
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

	-- 갇힘: 경보 중 광산 안에서 죽었으면 이미 차감했으니 건너뛴다 (PlayerData.trapLoss가 한 번만)
	EventBus.On(Events.PlayerTrapped, function(player: Player, mineId: string)
		if PlayerData.trapLoss(player, mineId) then
			Bag.sync(player)
		end
		carried[player] = nil
	end)

	-- 탈출 수확 = 광산을 나올 때 들고 있던 가치 (D-039). 붕괴 순간의 가방으로 재면, 먼저 나와서 판 사람은 0이 된다
	EventBus.On(Events.PlayerEscaped, function(player: Player, mineId: string, bonus: number)
		local data = PlayerData.get(player)
		local c = carried[player]
		carried[player] = nil
		if not data then
			return
		end
		local haul = if c and c.mineId == mineId then c.value else bagValue(data)
		if haul > 0 then
			data.stats.bestHaul = math.max(data.stats.bestHaul, haul)
			EventBus.Fire(Events.HaulSecured, player, mineId, haul)
		end
		if typeof(bonus) == "number" and bonus > 0 and bonus < math.huge then
			PlayerData.addCoins(player, bonus)
		end
	end)

	-- 경보 중 광산 안에 있는 동안 들고 있는 가치를 적어 둔다 (탈출 수확용).
	-- 경보 중 광산 안에서 죽으면(리셋 포함) 그 자리에서 갇힘 차감: 허브에서 부활해 붕괴 전에 팔아 버리면 차감을 피할 수 있었다.
	-- 캐릭터가 지워질 때(부활 직전) 판정한다. 죽은 몸은 광산 안에 남아 있다
	task.spawn(function()
		while true do
			task.wait(CARRY_POLL)
			for _, player in Players:GetPlayers() do
				local data = PlayerData.get(player)
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				local mine = root and Mines.findAreaAt(root.Position)
				if data and mine and Collapse.GetRemainingTime(mine.id) ~= nil then
					carried[player] = { mineId = mine.id, value = bagValue(data) }
				end
			end
		end
	end)
	local function watchDeath(player: Player)
		player.CharacterRemoving:Connect(function(char)
			local humanoid = char:FindFirstChildOfClass("Humanoid")
			local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
			local mine = root and Mines.findAreaAt(root.Position)
			if humanoid and humanoid.Health <= 0 and mine and Collapse.GetRemainingTime(mine.id) ~= nil then
				if PlayerData.trapLoss(player, mine.id) then
					Bag.sync(player)
					Counter.notify(player, "붕괴 경보 중 광산에서 쓰러져서 가방 일부를 잃었어요")
				end
			end
		end)
	end
	Players.PlayerAdded:Connect(watchDeath)
	for _, player in Players:GetPlayers() do
		watchDeath(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		carried[player] = nil
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

	-- 패스·부스트가 바뀌면 가방 한도·판매가 배수 표시를 다시 계산한다.
	-- C의 Payments가 패스 조회를 마치거나 부스트가 켜지고 꺼질 때 SellPriceMultiplier 를 올린다 (접속 직후 가방 확장 반영도 이것으로).
	-- 가방 확장 패스는 배수가 아니라서 속성이 안 바뀌므로 구매 완료를 따로 듣는다 (Payments 캐시가 갱신된 뒤에 읽게 defer)
	local function watch(player: Player)
		player.AttributeChanged:Connect(function(attr)
			if attr == "SellPriceMultiplier" or attr == "TestPass_BigBag" then
				Bag.sync(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, _passId, purchased)
		if purchased then
			task.defer(Bag.sync, player)
		end
	end)

	Counter.prompt("Shop", "SellPrompt", "재료 빼고 전부 팔기", function(player)
		Counter.notify(player, sellAllNotice(player, Bag.sellAll(player)))
	end)
	Counter.prompt("Shop", "BagUpgradePrompt", "가방 늘리기", function(player)
		local _, msg = Bag.upgrade(player)
		Counter.notify(player, msg)
	end, Enum.KeyCode.F)

end

return Bag
