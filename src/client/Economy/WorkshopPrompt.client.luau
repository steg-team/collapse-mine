--!strict
-- 제작소·판매소 프롬프트에 "내" 다음 곡괭이·카나리아·리버스·가방 비용을 적는다 (B 담당, D-021, D-023, D-024, D-028)
-- 프롬프트는 서버 Workshop.luau 가 만들고 모두가 같은 것을 보므로, 문구만 클라이언트에서 플레이어별로 바꾼다.
-- 실제 비용 확인·차감은 서버가 한다 (여기 숫자는 안내용).

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local Config = RS:WaitForChild("Shared"):WaitForChild("Config")
local Economy = require(Config:WaitForChild("Economy"))

local player = Players.LocalPlayer

local prompts: { ProximityPrompt } = {}

local function texts(): { [string]: string }
	local tier = player:GetAttribute("PickaxeTier") or 1
	local enhance = player:GetAttribute("PickaxeEnhance") or 0
	local now = Economy.PICKAXES[tier]
	local nextSpec = Economy.PICKAXES[tier + 1]

	local craft = "가장 좋은 곡괭이예요"
	if nextSpec then
		craft = `{nextSpec.name} · {Economy.recipeText(nextSpec)}`
	end

	local enh = `{now and now.name or ""} +{enhance} (최대)`
	if now and enhance < Economy.ENHANCE_MAX then
		enh = `{now.name} +{enhance} → +{enhance + 1} · {Economy.enhanceCost(tier, enhance)} 코인`
	end
	local level = player:GetAttribute("CanaryLevel") or 0
	local nextCanary = Economy.CANARY[level + 1]
	local canary = `카나리아 Lv{level + 1} (다 컸어요)`
	if nextCanary then
		canary = `카나리아 Lv{level + 2} ({Economy.CANARY_PERK_NAME[level + 1]}) · {Economy.recipeText(nextCanary :: any)}`
	end
	local R = Economy.REBIRTH
	local rebirths = player:GetAttribute("Rebirths") or 0
	-- 길면 프롬프트가 옆으로 넓어져 화면을 가린다. 무엇을 잃는지는 ActionText "리버스 (초기화)"와 3초 누르기로 알린다
	local rebirth = `판매가 ×{1 + (rebirths + 1) * R.sellBonus} 영구 · {Economy.PICKAXES[R.needTier].name} + {R.coins * (rebirths + 1)} 코인`

	local bagLevel = player:GetAttribute("BagLevel") or 0
	local nextBag = Economy.BAG_LEVELS[bagLevel + 2]
	local hasBigBag = player:GetAttribute("HasBigBag") == true
	local cap = Economy.bagCapacity(bagLevel, hasBigBag)
	local bag = `{cap}kg (가장 커요)`
	if nextBag then
		local nextCap = Economy.bagCapacity(bagLevel + 1, hasBigBag)
		local lockedBy = if tier < (nextBag.stage or 0) then Economy.PICKAXES[nextBag.stage or 1] else nil
		bag = if lockedBy
			then `{cap}kg → {nextCap}kg · 🔒 {lockedBy.name} 필요`
			else `{cap}kg → {nextCap}kg · {Economy.recipeText(nextBag :: any)}`
	end

	return { CraftPrompt = craft, EnhancePrompt = enh, CanaryPrompt = canary, RebirthPrompt = rebirth, BagUpgradePrompt = bag }
end

local function refresh()
	local byName = texts()
	for _, p in prompts do
		p.ObjectText = byName[p.Name] or ""
	end
end

local function track(inst: Instance)
	if inst:IsA("ProximityPrompt") and texts()[inst.Name] then
		table.insert(prompts, inst)
		refresh()
	end
end

workspace.DescendantAdded:Connect(track)
for _, inst in workspace:GetDescendants() do
	track(inst)
end
player:GetAttributeChangedSignal("PickaxeTier"):Connect(refresh)
player:GetAttributeChangedSignal("PickaxeEnhance"):Connect(refresh)
player:GetAttributeChangedSignal("CanaryLevel"):Connect(refresh)
player:GetAttributeChangedSignal("Rebirths"):Connect(refresh)
player:GetAttributeChangedSignal("BagLevel"):Connect(refresh)
player:GetAttributeChangedSignal("BagCapacity"):Connect(refresh)
player:GetAttributeChangedSignal("HasBigBag"):Connect(refresh)
