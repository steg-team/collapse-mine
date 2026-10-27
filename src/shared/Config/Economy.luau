--!strict
-- 경제 밸런스 숫자 (B 담당). "임시값"은 밸런스 테스트 전 숫자다.
-- 숫자 출처: 공유 기획(곡괭이·가방·광물 도감 탭)과 D-044. 광물 기본가 = 2 × 2.2^(스테이지 − 1) × 등급 배수 (Mines.luau value)
--
-- 레시피 = 업그레이드 하나의 값: { coins, ores = { 광물 = 개수 }, grades = { 등급 = 개수 } }.
-- ores는 그 광물, grades는 그 등급이면 어느 광산 것이든. 곡괭이·가방·카나리아가 같은 꼴이라
-- 확인·차감(Bag.pay), 전부 팔기 때 남길 재료(materialNeeds), 프롬프트 문구가 한 가지 방식으로 읽는다.

export type Recipe = { coins: number, ores: { [string]: number }?, grades: { [string]: number }? }

local Economy = {
	-- 붕괴 때 갇히면(또는 경보 중 광산 안에서 접속을 끊으면) 가방 무게에서 잃는 비율 (D-029, 임시값)
	-- 전부 잃으면 어린 유저가 이탈하므로 일부만 (기획서 "광맥 붕괴 이벤트")
	TRAPPED_BAG_LOSS = 0.5,

	-- 가방은 무게(kg) 하나로 잰다 (D-027). 광물 무게 = OreMined 의 weight (A, 평균 1kg 남짓)
	-- 한도까지는 그대로, 넘으면 무거울수록 느려지고, 한도 × BAG_HARD_LIMIT 를 넘으면 더 안 담긴다 (임시값)
	BAG_HARD_LIMIT = 1.5,
	-- 공유 기획 가방 12단계는 광물 개수(칸)로 적혀 있다. 우리 가방은 무게라서 칸 × 이 값 = kg
	BAG_KG_PER_SLOT = 1.5,
	-- "가방 확장" 게임패스(BigBag): 모든 단계 한도 × 이 값 (공유 기획 가방 탭)
	BIG_BAG_MULT = 2,
	-- 가방 단계 (D-028, D-044). 1단계가 시작. 판매소 "가방 늘리기"로 한 단계씩. stage = 그 광산에 갈 수 있어야(곡괭이 단계) 살 수 있음.
	-- 값 = 해금 스테이지 다음 곡괭이 코인의 40% + 그 광산 일반·고급 광물. 리버스하면 1단계로.
	-- 공유 기획 4단계(65칸, 5스테이지, 29K)부터는 그 광산이 생기면 한 줄씩 붙인다 (임시값)
	BAG_LEVELS = table.freeze({
		{ slots = 20 },
		{ slots = 30, stage = 1, coins = 140, ores = { Coal = 15, Quartz = 2 } },
		{ slots = 45, stage = 3, coins = 4400, ores = { Limestone = 15, Azurite = 2 } },
	}),
	-- 한도 × BAG_HARD_LIMIT 일 때 걸음 속도 배수. 완전히 멈추지는 않게 (임시값)
	BAG_MIN_SPEED = 0.6,

	-- 압력 등급 이름 (OreMined 계약의 pressure 값 → 화면 문구). 알림·인벤토리 공용
	PRESSURE_NAME = table.freeze({ Low = "상압", High = "고압", Extreme = "초고압" }),

	-- 판매가 = 기본가(Mines 광물표 value) × 무게 × 압력 배수 (기획서 "무게와 압력 등급")
	-- 키는 OreMined 계약의 pressure 값 (임시값)
	PRESSURE_MULT = table.freeze({
		Low = 1, -- 상압
		High = 2, -- 고압
		Extreme = 5, -- 초고압 (공유 기획 A-05)
	}),

	-- 판매소·제작소 Counter에서 이 거리 밖이면 거부 (ProximityPrompt 거리 + 여유)
	SELL_REACH = 16,

	-- 곡괭이 단계 (D-021, D-044). 단계 = Mines.luau 의 requiredPickaxe (= 갈 수 있는 광산).
	-- 다음 곡괭이 = 공유 기획 코인 + 바로 전 광산 광물을 등급 골고루 (일반 20·10, 고급 5, 희귀 2, 에픽 1). 한 광산을 골고루 파야 넘어간다.
	-- 이름은 핵심 재료인 에픽 광물 이름 ("동굴 진주 곡괭이가 필요해요" = 동굴 진주를 찾으면 된다). 첫 곡괭이만 "낡은 곡괭이".
	-- 5단계(4스테이지 다음)는 4스테이지 광산·광물이 정해지면 한 줄. 숫자는 모두 임시값
	-- enhanceCost = 강화 기본 비용 = 다음 곡괭이 코인의 5% (4단계는 공유 기획 4스테이지 다음 곡괭이 28K 기준). Economy.enhanceCost 참고
	PICKAXES = table.freeze({
		{ name = "낡은 곡괭이", coins = 0, enhanceCost = 18 },
		{ name = "동굴 진주 곡괭이", coins = 350, ores = { Coal = 20, Copper = 10, Quartz = 5, Amber = 2, CavePearl = 1 }, enhanceCost = 65 },
		{ name = "백금 곡괭이", coins = 1300, ores = { Iron = 20, Tin = 10, Silver = 5, Magnetite = 2, Platinum = 1 }, enhanceCost = 550 },
		{ name = "물빛 진주 곡괭이", coins = 11000, ores = { Limestone = 20, Calcite = 10, Azurite = 5, Malachite = 2, WaterPearl = 1 }, enhanceCost = 1400 },
	}),
	-- 단계마다 강화 상한. 다음 단계를 만들면 강화는 0부터 (임시값)
	ENHANCE_MAX = 5,

	-- 광산 카나리아 (D-023, D-044). 저장값 data.canary는 0부터, 화면에는 +1 해서 Lv1~5 (공유 기획 "등급 1~5, 20→60").
	-- range = 희귀 광맥·희귀 이상 광물을 알아채는 거리(스터드). 다음 레벨은 코인 + 희귀(어느 광산이든), 위쪽은 에픽도.
	-- 코인 = 그 단계 광산 다음 곡괭이 코인의 30%. 숫자는 모두 임시값
	CANARY = table.freeze({
		[0] = { range = 20 },
		{ range = 30, coins = 100, grades = { ["희귀"] = 2 } },
		{ range = 40, coins = 400, grades = { ["희귀"] = 4 } },
		{ range = 50, coins = 3300, grades = { ["희귀"] = 6, ["에픽"] = 1 } },
		{ range = 60, coins = 8400, grades = { ["희귀"] = 8, ["에픽"] = 2 } },
	}),
	-- 카나리아가 반응하는 등급
	CANARY_DETECT_GRADES = table.freeze({ ["희귀"] = true, ["에픽"] = true, ["전설"] = true, ["신화"] = true, ["???"] = true }),
	-- 카나리아 울음소리 (Roblox 무료 소리 에셋). 바꾸려면 id만 갈면 된다
	CANARY_CHIRP_SOUND = "rbxassetid://0",

	-- 기획서 "광물 등급" 테두리 색 (인벤토리·도감 창)
	GRADE_COLOR = table.freeze({
		["일반"] = Color3.fromRGB(170, 170, 170),
		["고급"] = Color3.fromRGB(90, 200, 90),
		["희귀"] = Color3.fromRGB(80, 150, 255),
		["에픽"] = Color3.fromRGB(180, 100, 255),
		["전설"] = Color3.fromRGB(255, 160, 40),
		["신화"] = Color3.fromRGB(255, 70, 70),
		["???"] = Color3.fromRGB(235, 235, 235),
	}),

	-- 리버스 (D-024): 가장 좋은 곡괭이 + 코인을 내고 코인·곡괭이·가방을 처음으로. 대신 판매가가 영구로 오른다.
	-- 필요 코인 = coins × (지금까지 리버스 횟수 + 1). 판매가 배수 = 1 + sellBonus × 리버스 횟수. 숫자는 모두 임시값
	REBIRTH = table.freeze({
		needTier = 4,
		coins = 28000,
		sellBonus = 0.25,
	}),
}

-- 강화 n → n+1 비용: 다음 곡괭이 코인의 5%에서 강화가 오를수록 6%까지 (공유 기획 "5~6%")
function Economy.enhanceCost(tier: number, enhance: number): number
	return math.floor(Economy.PICKAXES[tier].enhanceCost * (1 + 0.05 * enhance))
end

-- 가방 무게 한도(kg): 단계 칸 수 × BAG_KG_PER_SLOT, 가방 확장 패스면 × BIG_BAG_MULT
function Economy.bagCapacity(bagLevel: number, hasBigBag: boolean): number
	local level = Economy.BAG_LEVELS[math.clamp(bagLevel + 1, 1, #Economy.BAG_LEVELS)]
	return level.slots * Economy.BAG_KG_PER_SLOT * (if hasBigBag then Economy.BIG_BAG_MULT else 1)
end

-- 레시피를 한 줄로: "350 코인 + 석탄 20 + 구리 10 + 희귀 2" (프롬프트 안내용, 광물은 무거운 개수부터)
local displayName: { [string]: string }? = nil
function Economy.recipeText(recipe: Recipe): string
	if not displayName then
		local names = {}
		for _, m in require(script.Parent:WaitForChild("Mines")).list do
			for _, o in m.ores do
				names[o.name] = o.displayName
			end
		end
		displayName = names
	end
	local names = displayName :: { [string]: string }
	local items: { { string | number } } = {}
	for oreId, n in recipe.ores or {} do
		table.insert(items, { names[oreId] or oreId, n })
	end
	for grade, n in recipe.grades or {} do
		table.insert(items, { grade, n })
	end
	table.sort(items, function(a, b)
		return (a[2] :: number) > (b[2] :: number)
	end)
	local parts = { `{recipe.coins} 코인` }
	for _, it in items do
		table.insert(parts, `{it[1]} {it[2]}`)
	end
	return table.concat(parts, " + ")
end

export type Need = { label: string, icon: string, recipe: Recipe }

-- 바로 다음 업그레이드들의 레시피 (D-037, D-044): 다음 곡괭이, 다음 가방(그 광산에 갈 수 있을 때만), 카나리아 다음 레벨.
-- 서버 "재료 빼고 전부 팔기"(Bag)와 인벤토리 재료 표시가 같이 쓴다. 규칙을 바꿀 땐 여기만 고친다
function Economy.materialNeeds(pickaxeTier: number, canaryLevel: number, bagLevel: number): { Need }
	local out: { Need } = {}
	local pickaxe = Economy.PICKAXES[pickaxeTier + 1]
	if pickaxe then
		table.insert(out, { label = pickaxe.name, icon = "⚒", recipe = pickaxe })
	end
	local bag = Economy.BAG_LEVELS[bagLevel + 2]
	if bag and pickaxeTier >= (bag.stage or 0) then
		table.insert(out, { label = `가방 {bagLevel + 2}단계`, icon = "🎒", recipe = bag :: any })
	end
	local canary = Economy.CANARY[canaryLevel + 1]
	if canary then
		table.insert(out, { label = `카나리아 Lv{canaryLevel + 2}`, icon = "🐤", recipe = canary :: any })
	end
	return out
end

return table.freeze(Economy)
