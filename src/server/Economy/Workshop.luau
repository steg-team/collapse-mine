--!strict
--[[
	제작소: 곡괭이 제작(다음 단계)·강화 (B 담당, D-021), 카나리아 키우기 (D-023), 리버스 (D-024)
	허브 Workshop/Counter 프롬프트 네 개 (Counter.prompt) ("CraftPrompt" E, "EnhancePrompt" F, "CanaryPrompt" G, "RebirthPrompt" R 3초).
	비용은 Config/Economy.luau PICKAXES·CANARY (레시피, 확인·차감은 Bag.pay). 곡괭이 성능(파워·속도·강화 효과)은 A가 PickaxeUpgraded·속성을 받아 정한다.
]]

local RS = game:GetService("ReplicatedStorage")

local Shared = RS:WaitForChild("Shared")
local Events = require(Shared:WaitForChild("Events"))
local EventBus = require(Shared:WaitForChild("EventBus"))
local Economy = require(Shared:WaitForChild("Config"):WaitForChild("Economy"))
local PlayerData = require(script.Parent.PlayerData)
local Bag = require(script.Parent.Bag)
local Counter = require(script.Parent.Counter)

local Workshop = {}

local function coinsOf(player: Player): number
	local data = PlayerData.get(player)
	return data and data.coins or 0
end

local function upgraded(player: Player, data: PlayerData.Data)
	player:SetAttribute("PickaxeTier", data.pickaxe.tier)
	player:SetAttribute("PickaxeEnhance", data.pickaxe.enhance)
	EventBus.Fire(Events.PickaxeUpgraded, player, data.pickaxe.tier, data.pickaxe.enhance)
end

-- 다음 단계 곡괭이 제작. 실패하면 이유를 돌려준다
function Workshop.craft(player: Player): (boolean, string)
	local data = PlayerData.get(player)
	if not data then
		return false, "데이터를 불러오는 중이에요"
	end
	local nextTier = data.pickaxe.tier + 1
	local spec = Economy.PICKAXES[nextTier]
	if not spec then
		return false, "가장 좋은 곡괭이예요"
	end
	local ok, why = Bag.pay(player, spec)
	if not ok then
		return false, why :: string
	end
	data.pickaxe.tier = nextTier
	data.pickaxe.enhance = 0
	upgraded(player, data)
	return true, `{spec.name}를 만들었어요`
end

-- 지금 곡괭이 강화 +1
function Workshop.enhance(player: Player): (boolean, string)
	local data = PlayerData.get(player)
	if not data then
		return false, "데이터를 불러오는 중이에요"
	end
	local p = data.pickaxe
	if p.enhance >= Economy.ENHANCE_MAX then
		return false, "강화가 최대예요. 다음 곡괭이를 만들어 보세요"
	end
	local cost = Economy.enhanceCost(p.tier, p.enhance)
	if coinsOf(player) < cost then
		return false, `코인이 {cost - coinsOf(player)} 부족해요`
	end
	PlayerData.addCoins(player, -cost)
	p.enhance += 1
	upgraded(player, data)
	return true, `+{p.enhance} 강화 성공`
end

-- 카나리아 다음 레벨 (탐지 범위가 넓어짐)
function Workshop.feedCanary(player: Player): (boolean, string)
	local data = PlayerData.get(player)
	if not data then
		return false, "데이터를 불러오는 중이에요"
	end
	local spec = Economy.CANARY[data.canary + 1]
	if not spec then
		return false, "카나리아가 다 컸어요"
	end
	local ok, why = Bag.pay(player, spec :: any)
	if not ok then
		return false, why :: string
	end
	data.canary += 1
	player:SetAttribute("CanaryLevel", data.canary)
	return true, `카나리아가 Lv{data.canary + 1}이 됐어요 (탐지 {spec.range}m)`
end

-- 리버스: 코인·곡괭이·가방(내용과 늘린 단계)을 처음으로 되돌리고 판매가 보너스를 영구히 얻는다.
-- 카나리아·도감·기록·C의 social 칸은 그대로 둔다 (쌓은 수집과 랭킹은 잃지 않게)
function Workshop.rebirth(player: Player): (boolean, string)
	local data = PlayerData.get(player)
	if not data then
		return false, "데이터를 불러오는 중이에요"
	end
	local R = Economy.REBIRTH
	if data.pickaxe.tier < R.needTier then
		return false, `{Economy.PICKAXES[R.needTier].name}가 있어야 리버스할 수 있어요`
	end
	local need = R.coins * (data.rebirths + 1)
	if data.coins < need then
		return false, `코인이 {need - data.coins} 부족해요`
	end
	data.rebirths += 1
	data.bag = {}
	data.bagLevel = 0
	player:SetAttribute("BagLevel", 0)
	PlayerData.addCoins(player, -data.coins)
	data.pickaxe.tier = 1
	data.pickaxe.enhance = 0
	player:SetAttribute("Rebirths", data.rebirths)
	Bag.sync(player)
	upgraded(player, data)
	return true, `리버스 {data.rebirths}회! 판매가가 영구히 ×{Bag.rebirthMult(data)}`
end

function Workshop.start()
	Counter.prompt("Workshop", "CraftPrompt", "다음 곡괭이 만들기", function(player)
		local _, msg = Workshop.craft(player)
		Counter.notify(player, msg)
	end)
	Counter.prompt("Workshop", "EnhancePrompt", "곡괭이 강화", function(player)
		local _, msg = Workshop.enhance(player)
		Counter.notify(player, msg)
	end, Enum.KeyCode.F)
	Counter.prompt("Workshop", "CanaryPrompt", "카나리아 키우기", function(player)
		local _, msg = Workshop.feedCanary(player)
		Counter.notify(player, msg)
	end, Enum.KeyCode.G)
	Counter.prompt("Workshop", "RebirthPrompt", "리버스 (초기화)", function(player)
		local _, msg = Workshop.rebirth(player)
		Counter.notify(player, msg)
	end, Enum.KeyCode.R, 3) -- 되돌릴 수 없으니 길게 눌러야 한다
end

return Workshop
