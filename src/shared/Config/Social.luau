--!strict
--[[
	C(이벤트·서비스) 설정 — 숫자·종류 이름은 전부 여기서 관리한다 (코드에 직접 적지 않는다)
	"임시값"은 밸런스 테스트 전 숫자. 바꿀 때는 이 파일만 고치면 된다.

	목차
	  1. 열거형 (종류 이름)  AnnounceKind, MultiplierKind, PassName
	  2. 게임패스            Passes
	  3. 서버 공지           Announce, Banner
	  4. 광맥 붕괴           Collapse   (광산별 주기·경보 길이는 Config/Mines.luau 의 collapse)
	  5. 붕괴 카운트다운 HUD  CollapseHud
	  6. 출석 보상           DailyLogin
	  7. 서버 부스트         ServerBoost
	  8. 리더보드            Leaderboard
	  9. 튜토리얼            Tutorial

	쓰는 법
	  local Social = require(ReplicatedStorage.Shared.Config.Social)
	  Announcer.announce("...", Social.AnnounceKind.Collapse)
	  Payments.HasPass(player, Social.PassName.BigBag)
]]

-- ───────── 1. 열거형 ─────────
-- Luau 에는 enum 키워드가 없어서, "이름 = 같은 문자열" 고정 테이블 + 문자열 유니온 타입으로 흉내 낸다.
-- 문자열을 직접 쓰면 오타가 나도 조용히 지나가지만, Social.AnnounceKind.Colapse 처럼 틀리면 바로 에러가 난다.

export type AnnounceKind = "Legendary" | "Boost" | "Collapse" | "Info"
local AnnounceKind = table.freeze({
	Legendary = "Legendary" :: AnnounceKind, -- 전설 광물 발견 (금색)
	Boost = "Boost" :: AnnounceKind,         -- 서버 부스트 (파랑)
	Collapse = "Collapse" :: AnnounceKind,   -- 붕괴 경보·결과 (빨강)
	Info = "Info" :: AnnounceKind,           -- 그 밖의 안내 (회색)
})

export type MultiplierKind = "MineSpeed" | "SellPrice"
local MultiplierKind = table.freeze({
	MineSpeed = "MineSpeed" :: MultiplierKind, -- 채굴 속도 (A가 읽음)
	SellPrice = "SellPrice" :: MultiplierKind, -- 판매가 (B가 읽음)
})

export type PassName = "FastMining" | "BigBag" | "AutoMine"
local PassName = table.freeze({
	FastMining = "FastMining" :: PassName,
	BigBag = "BigBag" :: PassName,
	AutoMine = "AutoMine" :: PassName,
})

-- ───────── 2. 게임패스 ─────────
-- id         : 크리에이터 대시보드에서 패스를 만든 뒤 받은 숫자. 0 이면 아직 안 만든 패스 (항상 미보유 취급)
-- price      : 로벅스 가격 기록용 (실제 가격은 대시보드에서). 기획서: 50 / 150 / 400 / 1,000 처럼 넓게
-- multiplier : 배수 효과. Payments.GetMultiplier 가 보유한 패스의 배수를 곱한다
-- 기획서 "수익 모델": 첫 버전은 게임패스 2~3개 + 서버 부스트 1개. 전부 임시값.

export type Pass = {
	id: number,
	displayName: string,
	price: number,
	multiplier: { [MultiplierKind]: number }?,
}

local Passes: { [PassName]: Pass } = table.freeze({
	FastMining = { id = 0, displayName = "채굴 속도 2배", price = 150, multiplier = { MineSpeed = 2 } },
	BigBag = { id = 0, displayName = "가방 확장 (+20kg)", price = 50 }, -- 25~50 로벅스 첫 결제 상품 (기획서 원칙). 늘어나는 무게는 B (D-027, 판매소 가방 늘리기와 따로 더해짐)
	AutoMine = { id = 0, displayName = "자동 채굴", price = 400 },
})

-- ───────── 3. 서버 공지 ─────────

local Announce = table.freeze({
	maxLength = 80,         -- 배너 한 줄 글자 수. 넘으면 … 으로 자름
	duplicateWindow = 1.0,  -- 같은 문구가 이 시간(초) 안에 또 오면 무시 (도배 방지)
})

local Banner = table.freeze({
	showTime = 3.5,         -- 배너 하나가 떠 있는 시간(초)
	fadeTime = 0.25,        -- 나타나고 사라지는 시간(초)
	maxQueue = 5,           -- 밀린 공지가 이보다 많으면 오래된 것부터 버림 (붕괴 직전 몰릴 때 대비)
	topMargin = 8,          -- 화면 위에서 띄우는 거리(px)
	height = 40,
	cornerRadius = 10,
	strokeThickness = 2,
	padding = 16,
	backgroundTransparency = 0.15,
	textSize = 18,
	textSizeSmall = 14,     -- 화면 폭이 smallScreenWidth 보다 좁을 때 (폰)
	smallScreenWidth = 700,
	displayOrder = 50,      -- 다른 HUD 보다 위
	-- 종류별 모양
	styles = table.freeze({
		Legendary = { bg = Color3.fromRGB(70, 45, 10), stroke = Color3.fromRGB(255, 200, 60), icon = "✨" },
		Boost = { bg = Color3.fromRGB(20, 45, 80), stroke = Color3.fromRGB(90, 180, 255), icon = "🚀" },
		Collapse = { bg = Color3.fromRGB(80, 15, 15), stroke = Color3.fromRGB(255, 80, 60), icon = "⚠️" },
		Info = { bg = Color3.fromRGB(25, 25, 30), stroke = Color3.fromRGB(200, 200, 210), icon = "📢" },
	} :: { [AnnounceKind]: { bg: Color3, stroke: Color3, icon: string } }),
})

-- ───────── 4. 광맥 붕괴 (D-013) ─────────

local Collapse = table.freeze({
	announceAt = table.freeze({ 30, 10 }), -- 경보 중 이 남은 시간(초)에 공지. 경보 시작·붕괴 순간 공지는 따로
	escapeBonusMin = 5,       -- 탈출 보너스(코인): 경보 시작 직후 나가면 최소
	escapeBonusMax = 50,      --                    붕괴 직전에 나가면 최대
	trappedTeleportDelay = 3, -- 갇힌 플레이어를 허브로 옮기기까지(초). 붕괴 연출을 잠깐 보여주려고
	spawnHeight = 4,          -- 허브 스폰 파트 위로 띄워서 내려놓는 높이 (끼임 방지, MineTravel 과 같은 값)
	tickInterval = 0.25,      -- 광산 안 위치 확인 간격(초). 짧을수록 정확하지만 서버 부담
	testWarning = 15,         -- Studio 테스트(workspace 속성 CollapseTest)용 경보 길이(초)
})

-- ───────── 5. 붕괴 카운트다운 HUD ─────────
-- 경보 중인 광산 안에 있을 때만 화면 위쪽(공지 배너 아래)에 "붕괴까지 0:42"를 크게 띄운다.

local CollapseHud = table.freeze({
	dangerSeconds = 10,     -- 남은 시간이 이 아래면 빨갛게 깜빡임
	updateInterval = 0.1,   -- 숫자·위치 확인 간격(초)
	topMargin = 56,         -- 화면 위에서 띄우는 거리(px). 공지 배너(위 8 + 높이 40) 바로 아래
	textSize = 34,
	textSizeSmall = 24,     -- 폰 (Banner.smallScreenWidth 보다 좁을 때)
	strokeThickness = 2,
	pulseSpeed = 6,         -- 위험 구간 깜빡임 속도 (클수록 빠름)
	color = Color3.fromRGB(255, 210, 90),      -- 평소 (노랑)
	dangerColor = Color3.fromRGB(255, 70, 50), -- 위험 구간 (빨강)
	strokeColor = Color3.fromRGB(30, 10, 5),
	displayOrder = 49,      -- 공지 배너(50) 바로 아래 층
})

-- ───────── 6. 출석 보상 (D-016) ─────────
-- 7일 주기. 하루라도 빠지면 1일차부터 다시. 출석판 UI에서 버튼을 눌러 받는다.
-- 코인 지급은 B가 DailyLoginClaimed 이벤트를 받아서 한다.

local DailyLogin = table.freeze({
	-- 1~7일차 보상 코인 (임시값). 7일차를 크게 둬서 "끝까지 채우고 싶게"
	rewards = table.freeze({ 10, 20, 30, 50, 70, 100, 200 }),
	-- 하루가 바뀌는 시각을 UTC 기준 몇 시간 미룰지. 0 = UTC 자정 = 한국 오전 9시
	dayOffsetHours = 0,
	claimCooldown = 1,       -- 받기 버튼 연타 방지(초)

	-- UI
	openOnJoin = true,       -- 받을 보상이 있으면 접속하자마자 출석판을 띄움
	buttonSize = 56,         -- 화면 왼쪽 출석 버튼 크기(px)
	buttonMargin = 12,
	cellWidth = 72,          -- 출석판 칸 하나
	cellHeight = 92,
	cellGap = 8,
	panelPadding = 16,
	cornerRadius = 12,
	titleSize = 22,
	textSize = 16,
	panelColor = Color3.fromRGB(30, 26, 22),
	cellColor = Color3.fromRGB(60, 52, 44),
	todayColor = Color3.fromRGB(255, 200, 60),     -- 오늘 받을 칸 테두리
	claimedColor = Color3.fromRGB(70, 140, 80),    -- 받은 칸
	buttonColor = Color3.fromRGB(255, 180, 40),
	disabledColor = Color3.fromRGB(90, 90, 90),
	displayOrder = 40,
})

-- ───────── 7. 서버 부스트 (D-018) ─────────
-- 개발자 상품(로벅스, 여러 번 구매 가능)을 사면 서버 전체가 일정 시간 채굴 속도 2배.
-- 부스트 중에 또 사면 배수는 그대로, 시간만 연장 (배수를 겹치면 밸런스가 깨지므로).
-- 서버마다 따로이고 저장하지 않는다 (그 서버가 닫히면 끝).

local ServerBoost = table.freeze({
	productId = 0,           -- 크리에이터 대시보드 → 개발자 상품을 만든 뒤 받은 숫자. 0 이면 구매 창이 안 뜸
	displayName = "서버 채굴 2배",
	price = 99,              -- 로벅스 가격 기록용 (실제 가격은 대시보드에서). 임시값
	duration = 30 * 60,      -- 한 번 살 때 늘어나는 시간(초)
	multiplier = table.freeze({ MineSpeed = 2 }) :: { [MultiplierKind]: number },
	receiptHistory = 50,     -- 중복 지급 방지용으로 저장해 두는 최근 영수증 개수

	-- UI
	buttonOffset = 68,       -- 출석 📅 버튼 아래로 얼마나 띄울지(px)
	timerTopMargin = 8,      -- 오른쪽 위 남은 시간 표시
	timerRightMargin = 12,
	timerTextSize = 18,
	timerColor = Color3.fromRGB(120, 200, 255),
})

-- ───────── 8. 리더보드 (D-030) ─────────
-- 허브마다 있는 랭킹판 3개 (Hub/Leaderboard 의 Board_BestHaul · Board_BestOre · Board_TotalEarned)
-- 모든 서버 통합 순위 (OrderedDataStore). 저장이 안 되는 환경(Studio 기본)에서는 지금 서버 사람들끼리 순위.

local Leaderboard = table.freeze({
	rows = 5,                -- 랭킹판 줄 수 (판에 Row1~Row5 가 있음)
	refreshInterval = 60,    -- 순위를 다시 읽어 판에 그리는 간격(초). DataStore 읽기 제한 때문에 너무 짧게 하지 않는다
	flushInterval = 60,      -- 바뀐 점수를 DataStore 에 올리는 간격(초)
	weekOffsetHours = 9,     -- 주간 순위가 바뀌는 시각: 월요일 0시 + 이 시간대 (9 = 한국 월요일 0시)
	storeVersion = 1,        -- 순위를 통째로 새로 시작하고 싶으면 올린다 (DataStore 이름이 바뀜)
	emptyText = "—",
	rowTextSize = 30,        -- 판 한 줄 글씨 크기(px). 판은 40px/스터드, 한 줄 높이 약 54px
	valueWidth = 0.32,       -- 오른쪽 점수 칸 폭 (줄 폭의 비율). 이름이 길면 이 앞에서 … 로 잘림
})

-- ───────── 9. 튜토리얼 (D-031) ─────────
-- 처음 온 플레이어에게 한 바퀴를 안내한다: 포탈 → 캐기 → 팔기 → 붕괴 팁.
-- 단계는 게임 이벤트가 오면 자동으로 넘어간다 (done = 그 이벤트 이름). manual 단계는 "알겠어요" 버튼으로 끝.
-- target = 화살표를 띄울 곳 (클라이언트가 찾음): "portal" 기본 광산 포탈, "sell" 광산 안이면 출구·허브면 판매소

export type TutorialStep = { text: string, done: string?, manual: boolean?, target: string? }

local Tutorial = table.freeze({
	steps = table.freeze({
		{ text = "포탈로 들어가서 광산에 가 보세요", done = "StageEntered", target = "portal" },
		{ text = "광석을 클릭해서 캐 보세요. 캔 광물은 가방에 담겨요", done = "OreMined" },
		{ text = "출구로 나가서 허브 판매소에서 가방을 팔아 보세요", done = "OreSold", target = "sell" },
		{ text = "⚠️ 붕괴 경보가 울리면 시간 안에 출구로 탈출하세요! 갇히면 가방 무게의 절반을 잃어요. 대신 늦게 나올수록 보너스가 커요", manual = true },
	} :: { TutorialStep }),
	-- 이미 판매로 돈을 번 적이 있는 플레이어는 튜토리얼 없이 시작 (튜토리얼이 생기기 전부터 하던 사람)
	skipIfEarned = true,

	-- UI
	topMargin = 104,          -- 화면 위에서 띄우는 거리(px). 공지 배너·붕괴 카운트다운 아래
	width = 460,
	textSize = 18,
	padding = 14,
	cornerRadius = 12,
	panelColor = Color3.fromRGB(30, 26, 22),
	accentColor = Color3.fromRGB(255, 200, 60),  -- 단계 번호·화살표·테두리
	markerHeight = 6,         -- 목표 위에 띄우는 화살표 높이(스터드)
	displayOrder = 45,
})

return table.freeze({
	AnnounceKind = AnnounceKind,
	MultiplierKind = MultiplierKind,
	PassName = PassName,
	Passes = Passes,
	Announce = Announce,
	Banner = Banner,
	Collapse = Collapse,
	CollapseHud = CollapseHud,
	DailyLogin = DailyLogin,
	ServerBoost = ServerBoost,
	Leaderboard = Leaderboard,
	Tutorial = Tutorial,
})
