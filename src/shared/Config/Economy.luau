--!strict
-- 경제 밸런스 숫자 (B 담당). "임시값"은 밸런스 테스트 전 숫자다.

local Economy = {
	-- 붕괴 때 갇히면(또는 경보 중 광산 안에서 접속을 끊으면) 가방에서 잃는 비율 (임시값)
	-- 전부 잃으면 어린 유저가 이탈하므로 일부만 (기획서 "광맥 붕괴 이벤트")
	TRAPPED_BAG_LOSS = 0.5,

	-- 가방은 무게(kg) 하나로 잰다 (D-027). 광물 무게 = OreMined 의 weight (A, 평균 1kg 남짓)
	-- 한도까지는 그대로, 넘으면 무거울수록 느려지고, 한도 × BAG_HARD_LIMIT 를 넘으면 더 안 담긴다 (임시값)
	BAG_MAX_KG = 30,
	-- "가방 확장" 게임패스(BigBag)로 늘어나는 무게 (임시값)
	BIG_BAG_EXTRA_KG = 20,
	BAG_HARD_LIMIT = 1.5,
	-- 한도 × BAG_HARD_LIMIT 일 때 걸음 속도 배수. 완전히 멈추지는 않게 (임시값)
	BAG_MIN_SPEED = 0.6,

	-- 판매가 = 기본가(Mines 광물표 value) × 무게 × 압력 배수 (기획서 "무게와 압력 등급")
	-- 키는 OreMined 계약의 pressure 값 (임시값)
	PRESSURE_MULT = table.freeze({
		Low = 1, -- 상압
		High = 1.5, -- 고압
		Extreme = 3, -- 초고압
	}),

	-- 판매소·제작소 Counter에서 이 거리 밖이면 거부 (ProximityPrompt 거리 + 여유)
	SELL_REACH = 16,

	-- 곡괭이 단계 (D-021). 단계 = Mines.luau 의 requiredPickaxe. 다음 단계는 코인 + 가방 속 광물로 만든다.
	-- 재료는 바로 전 광산에서 나오는 고급·에픽 광물 ("팔까, 쓸까"). 숫자는 모두 임시값
	-- enhanceCost = 이 단계에서 강화 1회 기본 비용. n강 → n+1강은 enhanceCost × (n+1)
	PICKAXES = table.freeze({
		{ name = "나무 곡괭이", coins = 0, ores = {}, enhanceCost = 50 },
		{ name = "돌 곡괭이", coins = 300, ores = { Quartz = 3 }, enhanceCost = 300 },
		{ name = "철 곡괭이", coins = 2000, ores = { Silver = 3, Platinum = 1 }, enhanceCost = 1500 },
		{ name = "금 곡괭이", coins = 10000, ores = { Azurite = 3, WaterPearl = 1 }, enhanceCost = 6000 },
	}),
	-- 단계마다 강화 상한. 다음 단계를 만들면 강화는 0부터 (임시값)
	ENHANCE_MAX = 5,

	-- 광산 카나리아 (D-023). 레벨 = data.canary (0부터). range = 희귀 이상 광물을 알아채는 거리(스터드)
	-- 다음 레벨은 제작소에서 코인 + 희귀 등급 광물로 키운다 (기획서 "희귀: 카나리아 성장"). 숫자는 모두 임시값
	CANARY = table.freeze({
		[0] = { range = 20 },
		{ range = 30, coins = 200, rare = 2 },
		{ range = 45, coins = 1000, rare = 4 },
		{ range = 60, coins = 5000, rare = 6 },
	}),
	-- 카나리아가 반응하는 등급 / 키울 때 받는 등급
	CANARY_DETECT_GRADES = table.freeze({ ["희귀"] = true, ["에픽"] = true, ["전설"] = true, ["신화"] = true, ["???"] = true }),
	CANARY_FEED_GRADE = "희귀",

	-- 리버스 (D-024): 가장 좋은 곡괭이 + 코인을 내고 코인·곡괭이·가방을 처음으로. 대신 판매가가 영구로 오른다.
	-- 필요 코인 = coins × (지금까지 리버스 횟수 + 1). 판매가 배수 = 1 + sellBonus × 리버스 횟수. 숫자는 모두 임시값
	REBIRTH = table.freeze({
		needTier = 4,
		coins = 50000,
		sellBonus = 0.25,
	}),
}

return table.freeze(Economy)
