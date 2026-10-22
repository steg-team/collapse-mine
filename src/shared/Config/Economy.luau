--!strict
-- 경제 밸런스 숫자 (B 담당). "임시값"은 밸런스 테스트 전 숫자다.

local Economy = {
	-- 붕괴 때 갇히면(또는 경보 중 광산 안에서 접속을 끊으면) 가방에서 잃는 비율 (임시값)
	-- 전부 잃으면 어린 유저가 이탈하므로 일부만 (기획서 "광맥 붕괴 이벤트")
	TRAPPED_BAG_LOSS = 0.5,
}

return table.freeze(Economy)
