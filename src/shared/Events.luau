--[[
	기능 간 이벤트 계약 (기획서 "기능 간 이벤트 계약" 표 기준)
	서로의 코드를 직접 건드리지 않고 이 이름으로만 주고받는다.
	이벤트를 바꾸거나 추가할 때는 관련 담당자 모두 리뷰.
]]

local Events = {
	-- A → B : 광물 종류, 무게, 압력 등급
	OreMined = "OreMined",
	-- A → C : 플레이어, 광물, 깊이
	LegendaryFound = "LegendaryFound",
	-- B → A : 플레이어, 곡괭이 등급
	PickaxeUpgraded = "PickaxeUpgraded",
	-- C → A, B : 남은 시간, 탈출 여부
	CollapseStarted = "CollapseStarted",
	CollapseEnded = "CollapseEnded",
	-- B → C : 구매자, 부스트 종류
	BoostPurchased = "BoostPurchased",
}

return table.freeze(Events)
