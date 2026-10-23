--!strict
-- 경제 밸런스 숫자 (B 담당). "임시값"은 밸런스 테스트 전 숫자다.

local Economy = {
	-- 붕괴 때 갇히면(또는 경보 중 광산 안에서 접속을 끊으면) 가방에서 잃는 비율 (임시값)
	-- 전부 잃으면 어린 유저가 이탈하므로 일부만 (기획서 "광맥 붕괴 이벤트")
	TRAPPED_BAG_LOSS = 0.5,

	-- 가방 칸 수. 꽉 차면 더 캐도 안 담긴다 → 허브에 팔러 올라오는 이유 (임시값)
	BAG_CAPACITY = 20,
	-- "가방 확장" 게임패스(BigBag)로 늘어나는 칸 (임시값)
	BIG_BAG_EXTRA = 20,

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
}

return table.freeze(Economy)
