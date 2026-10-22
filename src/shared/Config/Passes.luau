--!strict
-- 게임패스 목록 (C 담당). 패스를 추가할 때는 이 파일에 한 줄 넣으면 된다.
--
-- id         : 로블록스 크리에이터 대시보드에서 패스를 만든 뒤 받은 숫자. 0 이면 아직 안 만든 패스 (항상 미보유 취급)
-- price      : 로벅스 가격. 실제 가격은 대시보드에서 정하고, 여기는 기록용 (기획서: 50 / 150 / 400 / 1,000처럼 넓게)
-- multiplier : 배수 효과. Payments.GetMultiplier 가 보유한 패스의 배수를 곱해서 돌려준다
--
-- 기획서 "수익 모델": 첫 버전은 게임패스 2~3개 + 서버 부스트 1개. 가격·배수는 전부 임시값.

export type Pass = {
	id: number,
	displayName: string,
	price: number,
	multiplier: { [string]: number }?,
}

local Passes: { [string]: Pass } = {
	-- 채굴 속도 2배 (A가 GetMultiplier(player, "MineSpeed") 로 읽음)
	FastMining = {
		id = 0,
		displayName = "채굴 속도 2배",
		price = 150,
		multiplier = { MineSpeed = 2 },
	},
	-- 가방 확장 (B가 HasPass(player, "BigBag") 로 읽어서 가방 칸 수를 늘림. 몇 칸 늘릴지는 B가 정함)
	BigBag = {
		id = 0,
		displayName = "가방 확장",
		price = 50, -- 25~50 로벅스짜리 첫 결제 상품을 꼭 둔다 (기획서 원칙)
	},
	-- 자동 채굴 (A가 HasPass(player, "AutoMine") 로 읽음)
	AutoMine = {
		id = 0,
		displayName = "자동 채굴",
		price = 400,
	},
}

return table.freeze(Passes)
