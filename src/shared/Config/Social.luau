--!strict
--[[
	C(이벤트·서비스) 설정 — 숫자·종류 이름은 전부 여기서 관리한다 (코드에 직접 적지 않는다)
	"임시값"은 밸런스 테스트 전 숫자. 바꿀 때는 이 파일만 고치면 된다.

	목차
	  1. 열거형 (종류 이름)  AnnounceKind, MultiplierKind, PassName
	  2. 게임패스            Passes
	  3. 서버 공지           Announce, Banner
	  4. 광맥 붕괴           Collapse   (광산별 주기·경보 길이는 Config/Mines.luau 의 collapse)

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
	BigBag = { id = 0, displayName = "가방 확장", price = 50 },   -- 25~50 로벅스 첫 결제 상품 (기획서 원칙). 몇 칸 늘릴지는 B
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

return table.freeze({
	AnnounceKind = AnnounceKind,
	MultiplierKind = MultiplierKind,
	PassName = PassName,
	Passes = Passes,
	Announce = Announce,
	Banner = Banner,
	Collapse = Collapse,
})
