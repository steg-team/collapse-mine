--[[
	기능 간 이벤트 계약 (기획서 "기능 간 이벤트 계약" 표 기준, D-011)
	서로의 코드를 직접 건드리지 않고 이 이름으로만 주고받는다.
	이벤트를 바꾸거나 추가할 때는 관련 담당자 모두 리뷰.

	규칙
	- 이벤트 = "방금 이런 일이 일어났다" 알림. 이름은 대상 + 과거형 동사 (PascalCase).
	- "지금 상태가 어때?"는 이벤트가 아니라 담당 모듈의 조회 함수로 묻는다 (맨 아래 참고).
	- 인자는 아래 주석의 순서 그대로 넘긴다. 플레이어 대상 이벤트는 첫 인자가 player.
	- mineId 는 Config/Mines.luau 의 광산 id (예: "basic").
	- 서버 내부 이벤트만 여기 둔다. 클라이언트 UI용 Remote는 각 담당 폴더에서 관리.
]]

local Events = {
	-- ───────── 공통 ─────────

	-- B → 전체 : 저장 데이터 로드 완료. 이 신호 이후에 플레이어 데이터를 읽는다.
	-- (player)
	PlayerDataLoaded = "PlayerDataLoaded",

	-- ───────── A: 채굴 ─────────

	-- A → B, C : 광물 획득 (B는 가방에 넣고 가격 계산, C는 퀘스트 진행)
	-- (player, oreId: string, weight: number, pressure: "Low" | "High" | "Extreme")
	OreMined = "OreMined",

	-- A → C : 전설 이상 광물 발견 (C가 서버 전체 공지)
	-- (player, oreId: string, mineId: string, depth: number)
	LegendaryFound = "LegendaryFound",

	-- A → C : 광산 입장 완료 (C의 튜토리얼·퀘스트)
	-- (player, mineId: string)
	StageEntered = "StageEntered",

	-- ───────── B: 경제 ─────────

	-- B → C : 캔 광물을 가방에 넣으며 가격 확정 (C의 "최고 광물" 랭킹, D-009)
	-- (player, oreId: string, value: number)
	OreBagged = "OreBagged",

	-- B → C : 광물 판매 (C의 퀘스트·"누적 수입" 랭킹, D-009)
	-- (player, oreId: string, count: number, totalPrice: number)
	OreSold = "OreSold",

	-- B → C : 탈출로 수확 확정 (C의 "최고 탈출 수확" 랭킹, D-009)
	-- PlayerEscaped를 받은 B가 가방 가치를 계산해서 쏜다.
	-- (player, mineId: string, haulValue: number)
	HaulSecured = "HaulSecured",

	-- B → A, C : 곡괭이 구매·강화 (A는 성능 갱신, C는 퀘스트·튜토리얼)
	-- (player, pickaxeTier: number, enhanceLevel: number)
	PickaxeUpgraded = "PickaxeUpgraded",

	-- ───────── C: 붕괴 ─────────

	-- C → A, B : 붕괴 경보, 카운트다운 시작 (B의 카나리아 불안 연출 등)
	-- (mineId: string, endsAt: number) -- endsAt = 붕괴 시각 (workspace:GetServerTimeNow() 기준)
	CollapseWarning = "CollapseWarning",

	-- C → A, B : 카운트다운 종료, 실제 붕괴 (A는 통로 막힘 + 광맥 재생 타이머 시작)
	-- 직후 C가 플레이어별로 PlayerEscaped / PlayerTrapped 를 쏜다.
	-- (mineId: string)
	CollapseOccurred = "CollapseOccurred",

	-- C → B : 붕괴 전에 탈출 성공 (B는 수확 확정 후 HaulSecured, 탈출 보너스 지급)
	-- (player, mineId: string, bonus: number)
	PlayerEscaped = "PlayerEscaped",

	-- C → B : 붕괴 때 갇힘 (B는 가방 일부 차감, 비율은 B가 결정)
	-- (player, mineId: string)
	PlayerTrapped = "PlayerTrapped",

	-- ───────── C: 서비스 ─────────

	-- C → B : 퀘스트 완료, 보상 지급 요청
	-- (player, questId: string, reward: { coins: number?, items: { [string]: number }? })
	QuestCompleted = "QuestCompleted",

	-- C → B : 출석 보상 지급 요청
	-- (player, streak: number, reward: { coins: number?, items: { [string]: number }? })
	DailyLoginClaimed = "DailyLoginClaimed",
}

--[[
	이벤트가 아닌 조회 함수 (C 제공) — "지금 상태"가 필요할 때 직접 호출

	Payments.HasPass(player, passName: string) -> boolean
		게임패스 보유 여부. 입장 시 캐시, 게임 중 구매 시 갱신되므로 매번 호출해도 됨.

	Payments.GetMultiplier(player, kind: "MineSpeed" | "SellPrice") -> number
		패스 + 부스트를 합친 최종 배수. 부스트가 만료되면 자동으로 1.
		A는 채굴 속도, B는 판매가 계산할 때 호출. (예전 BoostPurchased 이벤트 대체)
		클라이언트는 플레이어 속성 MineSpeedMultiplier / SellPriceMultiplier 로 같은 값을 읽는다 (서버가 자동 갱신).

	Collapse.GetRemainingTime(mineId: string) -> number?
		붕괴까지 남은 초. 경보 중이 아니면 nil. A가 압력 등급 계산에 사용.

	Collapse.DiedInsideMine(player) -> string?
		경보 중인 광산 안에서 죽은(리셋 포함) 적이 있으면 그 광산 id. B가 퇴장 때 차감 판정에 사용.
]]

--[[
	이벤트가 아닌 조회 함수 (B 제공, D-014)

	PlayerData.get(player) -> Data?
		저장 데이터 표 (ServerScriptService.Server.Economy.PlayerData). PlayerDataLoaded 전·퇴장 후엔 nil.
		쓰기는 B만, C는 data.social 칸만 쓴다.
]]

return table.freeze(Events)
