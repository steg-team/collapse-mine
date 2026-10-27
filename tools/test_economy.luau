--[[
	경제(B) 회귀 테스트 — Studio에서 Play 중에 실행
	쓰는 법: Play(F5) → 플레이어가 들어온 뒤, 서버 쪽 명령창(Command Bar)에 이 파일 내용을 붙여 넣고 실행.
	결과는 출력 창에 "[EconomyTest] ✅ 이름" / "❌ 이름 (자세히)" 와 마지막 요약 한 줄.

	왜 임시 Script를 만드나: 명령창에서 require 하면 게임이 쓰는 모듈과 다른 사본이 생긴다.
	ServerScriptService 안 Script에서 require 해야 실제로 돌고 있는 Bag·PlayerData를 시험한다.
	테스트 전 저장 데이터를 복사해 두고 끝나면 되돌린다 (Studio는 어차피 저장 안 됨).

	돈이 걸린 규칙을 고쳤으면 이걸 돌려서 전부 ✅인지 보고 PR에 적는다.
]]

local s = Instance.new("Script")
s.Name = "EconomyTest"
s.Source = [==[
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Events = require(RS.Shared.Events)
local EventBus = require(RS.Shared.EventBus)
local Economy = require(RS.Shared.Config.Economy)
local Eco = game.ServerScriptService.Server.Economy
local PlayerData = require(Eco.PlayerData)
local Bag = require(Eco.Bag)
local Workshop = require(Eco.Workshop)

local p = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
local t0 = os.clock()
while not PlayerData.get(p) and os.clock() - t0 < 15 do task.wait(0.2) end
local data = PlayerData.get(p)
if not data then warn("[EconomyTest] 데이터를 못 불러와서 중단") return end

local passed, failed = 0, 0
local function check(name, ok, detail)
	if ok then passed += 1; print("[EconomyTest] ✅ " .. name)
	else failed += 1; warn(`[EconomyTest] ❌ {name} ({tostring(detail)})`) end
end
local function deepCopy(t) local c = {} for k, v in t do c[k] = if type(v) == "table" then deepCopy(v) else v end return c end
local function mine(ore, weight, pressure) EventBus.Fire(Events.OreMined, p, ore, weight, pressure or "Low") end
local function settle() task.wait(0.1) end -- EventBus는 Deferred: 받는 쪽이 같은 프레임 조금 뒤에 돈다
local function reset()
	data.bag = {}; data.coins = 0; data.pickaxe = { tier = 1, enhance = 0 }; data.canary = 0
	data.rebirths = 0; data.bagLevel = 0; data.codex = {}; data.canaryUses = { day = 0, count = 0 }
	Bag.sync(p)
end

local backup = deepCopy(data)
local tutorial = p:GetAttribute("TutorialActive")
p:SetAttribute("TutorialActive", false)

-- 1. 판매가 = 기본가 × 무게 × 압력 배수
reset()
local coalBase = Bag.priceOf("Coal", 1, "Low")
check("판매가 공식 (석탄 2kg 고압)", Bag.priceOf("Coal", 2, "High") == math.max(1, math.floor(coalBase * 2 * Economy.PRESSURE_MULT.High + 0.5)), Bag.priceOf("Coal", 2, "High"))
check("모르는 광물·압력은 값 없음", Bag.priceOf("NoSuchOre", 1, "Low") == nil and Bag.priceOf("Coal", 1, "Weird") == nil)

-- 2. 담기: 이상한 무게는 거절 (NaN이 저장되면 코인이 영구히 깨짐), 정상은 담기고 도감 기록
mine("Coal", 0 / 0); mine("Coal", math.huge); mine("Coal", -1); settle()
check("NaN·무한대·음수 무게 거절", #data.bag == 0, #data.bag)
mine("Coal", 1.5, "High"); settle()
check("정상 광물 담김", #data.bag == 1 and data.bag[1].value == Bag.priceOf("Coal", 1.5, "High"), #data.bag)
check("도감 키 Coal·Coal|High", data.codex.Coal == true and data.codex["Coal|High"] == true)

-- 3. 무게 한도: 한도 × BAG_HARD_LIMIT 넘으면 안 담김
reset()
local cap = Bag.capacity(p)
mine("Coal", cap * Economy.BAG_HARD_LIMIT - 1); mine("Coal", 2); settle()
check("최대 무게 넘으면 거절", #data.bag == 1, #data.bag)

-- 4. 전부 팔기: 다음 곡괭이·가방·카나리아 재료는 싼 것부터 필요한 만큼 남김 (D-037, D-044)
reset()
local needs = Economy.materialNeeds(1, 0, 0)
local quartzNeed = 0
for _, n in needs do quartzNeed += (n.recipe.ores and n.recipe.ores.Quartz or 0) end
check("materialNeeds(1, 0, 0) = 곡괭이·가방·카나리아, 석영 7", #needs == 3 and quartzNeed == 7, `{#needs}, {quartzNeed}`)
for w = 1, 8 do mine("Quartz", w * 0.5) end
mine("Iron", 1); settle()
-- C의 튜토리얼이 OreMined 를 받으면 TutorialActive 를 다시 켤 수 있어서, 팔기 바로 전에 끈다
p:SetAttribute("TutorialActive", false)
local earned, kept = Bag.sellAll(p)
local heaviest = 0
for _, it in data.bag do heaviest = math.max(heaviest, it.weight) end
check("전부 팔기가 싼 석영 7개 남김 (가장 무거운 석영·철은 팖)", kept == 7 and heaviest == 3.5, `{kept} {heaviest}`)
check("판 금액 = 코인 증가", earned > 0 and data.coins == earned, `{earned} / {data.coins}`)
p:SetAttribute("TutorialActive", true)
local earned2 = Bag.sellAll(p)
check("튜토리얼 중엔 재료도 팖", earned2 > 0 and #data.bag == 0, #data.bag)
p:SetAttribute("TutorialActive", false)

-- 5. 갇힘 차감: 무게 절반을 넘지 않음, 1개면 안 잃음 (D-029)
local worst = 0
for _ = 1, 200 do
	data.bag = {}
	local total = 0
	for _ = 1, math.random(2, 12) do
		local w = math.random(10, 300) / 100
		total += w
		table.insert(data.bag, { ore = "Coal", weight = w, pressure = "Low", value = 1 })
	end
	PlayerData.loseBag(data)
	local left = 0
	for _, it in data.bag do left += it.weight end
	worst = math.max(worst, (total - left) / total)
end
check("갇힘 손실 ≤ 50% (200회)", worst <= Economy.TRAPPED_BAG_LOSS + 1e-9, worst)
data.bag = { { ore = "Coal", weight = 5, pressure = "Low", value = 1 } }
PlayerData.loseBag(data)
check("광물 1개면 안 잃음", #data.bag == 1)

-- 6. 갇힘 차감은 한 경보에 한 번 (경보 중 죽음 → 붕괴 PlayerTrapped 중복 방지, D-039)
reset()
data.bag = {}
for _ = 1, 10 do table.insert(data.bag, { ore = "Coal", weight = 1, pressure = "Low", value = 1 }) end
local first = PlayerData.trapLoss(p, "basic")
local afterFirst = #data.bag
local second = PlayerData.trapLoss(p, "basic")
check("같은 경보 두 번째 차감은 건너뜀", first and not second and #data.bag == afterFirst, `{first} {second} {#data.bag}`)
EventBus.Fire(Events.CollapseWarning, "basic", os.time() + 60); settle()
check("다음 경보가 시작되면 다시 차감 가능", PlayerData.trapLoss(p, "basic") == true)
EventBus.Fire(Events.CollapseWarning, "basic", os.time() + 60); settle() -- 다음 테스트를 위해 표시 지움

-- 7. 탈출 보너스: 이상한 값은 무시
reset()
EventBus.Fire(Events.PlayerEscaped, p, "basic", nil); EventBus.Fire(Events.PlayerEscaped, p, "basic", 0 / 0); settle()
check("탈출 보너스 nil·NaN 무시", data.coins == 0, data.coins)
EventBus.Fire(Events.PlayerEscaped, p, "basic", 20); settle()
check("탈출 보너스 지급", data.coins == 20, data.coins)

-- 8. 가방 늘리기: 모자라면 모자란 것을 전부 알려 주고 아무것도 안 뺌, 다 있으면 코인·광물 차감 + 한도 증가 (D-044)
reset()
local bag2 = Economy.BAG_LEVELS[2]
mine("Coal", 1); settle()
local ok1, why = Bag.upgrade(p)
check("가방 늘리기 실패 안내에 코인·석탄·석영 전부", not ok1 and why:find("코인") and why:find("석탄") and why:find("석영") and #data.bag == 1, why)
data.coins = bag2.coins
for _ = 1, bag2.ores.Coal - 1 do mine("Coal", 1) end
for _ = 1, bag2.ores.Quartz do mine("Quartz", 1) end
settle()
local before = Bag.capacity(p)
local ok2 = Bag.upgrade(p)
check("가방 늘리기 성공 (코인·광물 차감, 한도 증가)", ok2 and data.coins == 0 and #data.bag == 0 and Bag.capacity(p) == bag2.slots * Economy.BAG_KG_PER_SLOT and Bag.capacity(p) > before, `{ok2} {data.coins} bag={#data.bag} cap={Bag.capacity(p)}`)
local ok3, why3 = Bag.upgrade(p)
check("다음 가방은 그 광산 곡괭이가 있어야", not ok3 and why3:find("곡괭이"), why3)

-- 9. 곡괭이 제작: 재료 부족 실패, 성공하면 코인·재료(등급 골고루) 차감, 강화 0
reset()
data.coins = Economy.PICKAXES[2].coins
local okA = Workshop.craft(p)
for oreId, n in Economy.PICKAXES[2].ores do
	for _ = 1, n do mine(oreId, 1) end
end
mine("Iron", 1); settle()
local okB = Workshop.craft(p)
check("제작 (재료 부족 실패 → 성공)", not okA and okB and data.pickaxe.tier == 2 and data.coins == 0 and #data.bag == 1, `{okA} {okB} tier={data.pickaxe.tier} bag={#data.bag}`)

-- 10. 리버스: 코인·곡괭이·가방·가방 단계 초기화, 도감·카나리아 유지, 판매가 배수 +0.25
reset()
data.pickaxe.tier = Economy.REBIRTH.needTier
data.coins = Economy.REBIRTH.coins + 123
data.bagLevel = 2; data.canary = 1; data.codex.Coal = true
table.insert(data.bag, { ore = "Coal", weight = 1, pressure = "Low", value = 1 })
local okR = Workshop.rebirth(p)
check("리버스 초기화", okR and data.coins == 0 and data.pickaxe.tier == 1 and #data.bag == 0 and data.bagLevel == 0 and data.rebirths == 1, `coins={data.coins} tier={data.pickaxe.tier}`)
check("리버스 후 도감·카나리아 유지, 배수 ×1.25", data.canary == 1 and data.codex.Coal == true and p:GetAttribute("SellMultiplier") == 1.25, p:GetAttribute("SellMultiplier"))

-- 10-2. 카나리아 펫 (D-045): Lv4 광물 바꾸기(같은 광산 한 등급 위, 하루 횟수), Lv5 갇힘 보호
reset()
for _ = 1, 10 do mine("Coal", 1) end
settle()
local okT0 = Bag.transmute(p, "Coal")
data.canary = Economy.CANARY_PERKS.transmute
local okT1 = Bag.transmute(p, "Coal")
check("광물 바꾸기: Lv4 전엔 안 됨, 석탄 10 → 석영 1", not okT0 and okT1 and #data.bag == 1 and data.bag[1].ore == "Quartz", `{okT0} {okT1} {#data.bag} {data.bag[1] and data.bag[1].ore}`)
check("에픽은 못 만듦 (희귀 → 에픽 없음)", not Bag.transmute(p, "Amber"))
data.canaryUses.count = Economy.CANARY_TRANSMUTE_DAILY
for _ = 1, 10 do mine("Coal", 1) end
settle()
check("하루 횟수를 넘으면 안 됨", not Bag.transmute(p, "Coal"))
data.canary = Economy.CANARY_PERKS.guard
local worstG = 0
for _ = 1, 200 do
	data.bag = {}
	local total = 0
	for _ = 1, math.random(2, 12) do
		local w = math.random(10, 300) / 100
		total += w
		table.insert(data.bag, { ore = "Coal", weight = w, pressure = "Low", value = 1 })
	end
	PlayerData.loseBag(data)
	local left = 0
	for _, it in data.bag do left += it.weight end
	worstG = math.max(worstG, (total - left) / total)
end
check("갇힘 보호면 손실 ≤ 35%", worstG <= Economy.CANARY_GUARD_LOSS + 1e-9, worstG)

-- 11. 코인은 음수가 되지 않고 정수
check("코인 정수·0 이상", data.coins >= 0 and data.coins == math.floor(data.coins), data.coins)

-- 되돌리기
for k in data do data[k] = nil end
for k, v in backup do data[k] = v end
p:SetAttribute("TutorialActive", tutorial)
-- 화면용 속성도 되돌린다 (제작·리버스·카나리아가 바꿔 놓은 채로 남지 않게)
p:SetAttribute("PickaxeTier", data.pickaxe.tier)
p:SetAttribute("PickaxeEnhance", data.pickaxe.enhance)
p:SetAttribute("CanaryLevel", data.canary)
p:SetAttribute("BagLevel", data.bagLevel)
p:SetAttribute("Rebirths", data.rebirths)
PlayerData.addCoins(p, 0)
Bag.sync(p)
print(`[EconomyTest] 끝: 통과 {passed} / 실패 {failed}`)
script:Destroy()
]==]
s.Parent = game:GetService("ServerScriptService")
