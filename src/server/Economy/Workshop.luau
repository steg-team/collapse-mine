--!strict
--[[
	제작소: 곡괭이 제작(다음 단계)·강화 (B 담당, D-021)
	허브 Workshop/Counter 프롬프트 두 개 ("CraftPrompt", "EnhancePrompt").
	비용은 Config/Economy.luau PICKAXES. 성능(파워·속도·강화 효과)은 A가 PickaxeUpgraded·속성을 받아 정한다.
]]

local RS = game:GetService("ReplicatedStorage")

local Shared = RS:WaitForChild("Shared")
local Events = require(Shared:WaitForChild("Events"))
local EventBus = require(Shared:WaitForChild("EventBus"))
local Economy = require(Shared:WaitForChild("Config"):WaitForChild("Economy"))
local Mines = require(Shared.Config:WaitForChild("Mines"))
local PlayerData = require(script.Parent.PlayerData)
local Bag = require(script.Parent.Bag)

-- 광물 이름 → 화면에 보일 이름 (실패 안내용)
local displayName: { [string]: string } = {}
for _, m in Mines.list do
	for _, o in m.ores do
		displayName[o.name] = o.displayName
	end
end

local Workshop = {}

local function coinsOf(player: Player): number
	local ls = player:FindFirstChild("leaderstats")
	local coins = ls and ls:FindFirstChild("Coins") :: IntValue?
	return coins and coins.Value or 0
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
	if coinsOf(player) < spec.coins then
		return false, `코인이 {spec.coins - coinsOf(player)} 부족해요`
	end
	-- 재료: 가방에서 값이 싼 것부터 쓴다 (비싸게 캔 건 팔 수 있게 남김)
	local use: { number } = {}
	for oreId, need in spec.ores do
		local found: { number } = {}
		for i, item in data.bag do
			if item.ore == oreId then
				table.insert(found, i)
			end
		end
		if #found < need then
			return false, `{displayName[oreId] or oreId} {need - #found}개가 더 필요해요`
		end
		table.sort(found, function(a, b)
			return data.bag[a].value < data.bag[b].value
		end)
		table.move(found, 1, need, #use + 1, use)
	end

	table.sort(use, function(a, b)
		return a > b
	end) -- 뒤에서부터 지워야 앞 번호가 안 밀린다
	for _, i in use do
		table.remove(data.bag, i)
	end
	PlayerData.addCoins(player, -spec.coins)
	data.pickaxe.tier = nextTier
	data.pickaxe.enhance = 0
	Bag.sync(player)
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
	local cost = Economy.PICKAXES[p.tier].enhanceCost * (p.enhance + 1)
	if coinsOf(player) < cost then
		return false, `코인이 {cost - coinsOf(player)} 부족해요`
	end
	PlayerData.addCoins(player, -cost)
	p.enhance += 1
	upgraded(player, data)
	return true, `+{p.enhance} 강화 성공`
end

function Workshop.start()
	Bag.counterPrompt("Workshop", "CraftPrompt", "다음 곡괭이 만들기", function(player)
		local _, msg = Workshop.craft(player)
		Bag.notify(player, msg)
	end)
	Bag.counterPrompt("Workshop", "EnhancePrompt", "곡괭이 강화", function(player)
		local _, msg = Workshop.enhance(player)
		Bag.notify(player, msg)
	end, Enum.KeyCode.F)
end

return Workshop
