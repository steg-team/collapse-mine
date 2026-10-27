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
	data.rebirths = 0; data.bagLevel = 0; data.codex = {}
	Bag.sync(p)
end

local backup = deepCopy(data)
local tutorial = p:GetAttribute("TutorialActive")
p:SetAttribute("TutorialActive", false)

-- 1. 판매가 = 기본가 × 무게 × 압력 배수
reset()
local coalBase = Bag.priceOf("Coal", 1, "Low")
check("판매가 공식 (석탄 2kg 고압)", Bag.priceOf("Coal", 2, "High") == math.max(1, math.floor(coalBase * 2 * 1.5 + 0.5)), Bag.priceOf("Coal", 2, "High"))
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

-- 4. 전부 팔기: 다음 곡괭이 재료·카나리아 먹이는 싼 것부터 필요한 만큼 남김 (D-037)
reset()
local ores, rare = Economy.materialNeeds(1, 0)
check("materialNeeds(1, 0) = 석영 3 + 희귀 2", ores.Quartz == 3 and rare == 2, `{ores.Quartz}, {rare}`)
for _, w in { 1, 2, 0.5, 3 } do mine("Quartz", w) end
mine("Coal", 1); settle()
-- C의 튜토리얼이 OreMined 를 받으면 TutorialActive 를 다시 켤 수 있어서, 팔기 바로 전에 끈다
p:SetAttribute("TutorialActive", false)
local earned, kept = Bag.sellAll(p)
local keptW = {}
for _, it in data.bag do table.insert(keptW, it.weight) end
table.sort(keptW)
check("전부 팔기가 싼 석영 3개 남김", kept == 3 and keptW[1] == 0.5 and keptW[2] == 1 and keptW[3] == 2, table.concat(keptW, ","))
check("판 금액 = 코인 증가", earned > 0 and data.coins == earned, `{earned} / {data.coins}`)
p:SetAttribute("TutorialActive", true)
local earned2 = Bag.sellAll(p)
check("튜토리얼 중엔 재료도 팖", earned2 > 0 and #data.bag == 0, #data.bag)
p:SetAttribute("TutorialActive", false)

-- 4-2. 선택 판매: 체크한 묶음(광물|압력)만 팔고 나머지는 재료든 아니든 그대로 (D-043)
reset()
mine("Coal", 1, "High"); mine("Coal", 1, "Low"); mine("Quartz", 1); settle()
local picked = Bag.sellGroups(p, { ["Coal|High"] = true })
check("선택 판매는 체크한 묶음만", picked > 0 and #data.bag == 2 and data.coins == picked, `{picked} bag={#data.bag}`)

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

-- 8. 가방 늘리기: 코인 모자라면 실패, 성공하면 차감·한도 증가
reset()
local ok1 = Bag.upgrade(p)
data.coins = Economy.BAG_UPGRADES[1].coins
local before = Bag.capacity(p)
local ok2 = Bag.upgrade(p)
check("가방 늘리기 (코인 부족 실패 → 성공)", not ok1 and ok2 and data.coins == 0 and Bag.capacity(p) == before + Economy.BAG_UPGRADES[1].kg, `{ok1} {ok2} {data.coins}`)

-- 9. 곡괭이 제작: 재료 부족 실패, 성공하면 코인·재료 차감, 강화 0
reset()
data.coins = Economy.PICKAXES[2].coins
local okA = Workshop.craft(p)
for _ = 1, 3 do mine("Quartz", 1) end
mine("Coal", 1); settle()
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

-- 11. 코인은 음수가 되지 않고 정수
check("코인 정수·0 이상", data.coins >= 0 and data.coins == math.floor(data.coins), data.coins)

-- 되돌리기
for k in data do data[k] = nil end
for k, v in backup do data[k] = v end
p:SetAttribute("TutorialActive", tutorial)
PlayerData.addCoins(p, 0)
Bag.sync(p)
print(`[EconomyTest] 끝: 통과 {passed} / 실패 {failed}`)
script:Destroy()
]==]
s.Parent = game:GetService("ServerScriptService")
