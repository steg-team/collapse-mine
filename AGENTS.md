# AGENTS.md — 붕괴 광산 (Collapse Mine)

AI 코딩 에이전트(Claude Code, Codex, Cursor, Copilot 등)가 이 레포에서 작업할 때 따르는 규칙입니다.
사람 팀원도 같은 규칙을 따릅니다. 설치·작업 흐름은 `README.md`를 보세요.

## 게임 한 줄 요약

서버 전체가 함께 광산을 파 내려가다, 붕괴 카운트다운이 시작되면 "더 캘까, 지금 탈출할까"를 고르는 로블록스 채굴 게임.

## 기획 문서가 기준 (작업 전에 반드시 읽기)

- **[`docs/game-design.md`](docs/game-design.md)**: 게임 기획서. 단일 원본.
- **[`docs/decisions.md`](docs/decisions.md)**: 결정 기록. 기획서와 충돌하면 여기의 최신 결정이 우선.
- 기능을 만들기 전에 두 문서에서 해당 부분을 읽고, 그 방향대로 만듭니다.
- 사용자 요청이 기획과 다르면 **구현 전에 차이를 알리고** 기획서를 고칠지 묻습니다. 기획을 몰래 바꾸는 구현을 하지 않습니다.
- 기획이 바뀌면 코드보다 문서를 먼저 고칩니다 (`docs/` 수정 PR, 3명 리뷰, `decisions.md`에 새 항목).
- 기획에 없는 숫자(확률, 가격, 시간)는 임시값으로 넣고 PR 설명에 "임시값"이라고 적습니다.

## 관리 방식 (가장 중요)

| 대상 | 어디서 관리 | 비고 |
|---|---|---|
| 스크립트(코드) | 이 레포 `src/` → Rojo로 Studio에 동기화 | 진실의 원천은 레포 |
| 맵(지형, 허브, 광석, 방, 램프), 곡괭이 모델, `ReplicatedStorage.Remotes` | Studio 팀 크리에이트 플레이스 | Rojo가 건드리지 않음 |
| 맵·모델을 만드는 스크립트 | `tools/` | Rojo 동기화 대상 아님. Studio 명령창에서 실행 |

- Rojo는 **레포 → Studio 단방향**입니다. Studio에서 스크립트를 직접 고치면 다음 동기화 때 덮어써집니다. 코드는 반드시 `src/`에서 고치세요.
- `default.project.json`이 매핑하는 곳 밖(`Workspace`, `StarterPack` 등)에 스크립트를 만들지 마세요. 필요하면 매핑을 먼저 추가합니다.
- `.rbxl`, `.rbxlx`, `.rbxm` 파일은 커밋하지 않습니다.

## 폴더 구조와 Rojo 매핑

```
src/server/  → ServerScriptService.Server
  Core/        공용 기반 코드 (B)
  Mining/      채굴 코어 (A)
  Economy/     경제·성장 (B)
  Social/      소셜·이벤트 (C)
src/client/  → StarterPlayer.StarterPlayerScripts.Client
  Mining/ Economy/ Social/
src/shared/  → ReplicatedStorage.Shared
  Events.luau  기능 간 이벤트 계약
tools/       Studio 명령창용 생성 스크립트 (동기화 안 됨)
docs/        기획서, 결정 기록 (동기화 안 됨)
```

파일 이름 규칙 (Rojo)
- `*.server.luau` → Script
- `*.client.luau` → LocalScript
- 그 외 `*.luau` → ModuleScript
- 폴더 안의 `init.luau` / `init.server.luau` / `init.client.luau` → 폴더 자체가 그 스크립트가 됨

## 담당과 경계

| 담당 | 기능 | 폴더 |
|---|---|---|
| A | 채굴 코어: 캐릭터, 채굴 판정·손맛, 곡괭이 성능(파워·속도·강화 효과), 광물 155개 데이터·출현 확률·압력 등급, 광맥 생성·재생, OreSpot·포털, 붕괴 때 통로 막힘, 희귀 광물 연출 | `Mining/` |
| B | 경제: 인벤토리, 가방, 상점, 곡괭이 제작·강화 비용, 광물 판매가, 가격 밸런스, 광산 카나리아, 리버스, 데이터 저장, 공용 코드 | `Economy/`, `Core/`, `shared/` |
| C | 이벤트·서비스: 광맥 붕괴 이벤트(타이머·경보·갇힘·탈출 보상), 서버 공지, 게임패스·부스트·결제, 리더보드, 출석·퀘스트, 튜토리얼, 친구 초대 | `Social/` |

- 다른 담당 폴더의 코드를 직접 고치지 마세요. 필요하면 이슈나 PR 코멘트로 요청합니다.
- 기능끼리는 **`src/shared/Events.luau`의 이벤트로만** 주고받습니다. 이벤트를 추가·변경하면 관련 담당 모두에게 리뷰를 받습니다.
- 리뷰어는 `.github/CODEOWNERS`에 지정돼 있습니다.

현재 이벤트 계약

| 이벤트 | 방향 | 담는 정보 |
|---|---|---|
| `PlayerDataLoaded` | B → 전체 | 플레이어 (저장 데이터 로드 완료) |
| `OreMined` | A → B, C | 광물 종류, 무게, 압력 등급 |
| `LegendaryFound` | A → C | 플레이어, 광물, 광산, 깊이 |
| `StageEntered` | A → C | 플레이어, 광산 |
| `OreBagged` | B → C | 플레이어, 광물, 확정 가격 (최고 광물 랭킹) |
| `OreSold` | B → C | 플레이어, 광물, 개수, 판매액 (누적 수입 랭킹) |
| `HaulSecured` | B → C | 플레이어, 광산, 탈출 수확 가치 (최고 탈출 수확 랭킹) |
| `PickaxeUpgraded` | B → A, C | 플레이어, 곡괭이 단계, 강화 단계 |
| `CollapseWarning` | C → A, B | 광산, 붕괴 시각 (경보·카운트다운 시작) |
| `CollapseOccurred` | C → A, B | 광산 (실제 붕괴) |
| `PlayerEscaped` / `PlayerTrapped` | C → B | 플레이어, 광산 (탈출 보너스 / 가방 차감) |
| `QuestCompleted` / `DailyLoginClaimed` | C → B | 플레이어, 보상 |

이벤트가 아닌 조회 함수 (C 제공): `Monetization.HasPass`, `Monetization.GetMultiplier`(패스+부스트 배수, A 채굴 속도·B 판매가), `Collapse.GetRemainingTime`(A 압력 등급). 인자 형식은 `Events.luau` 주석 참고.

## 보안 규칙 (어기면 PR 반려)

- 확률, 판매가, 보상, 결제 검증은 **서버에서만** 계산합니다. 클라이언트가 보낸 값(위치, 대상, 수량)은 모두 검증합니다: 타입, 거리, 쿨다운, 소유 여부.
- RemoteEvent 핸들러는 첫 줄에서 인자 타입부터 확인합니다 (`typeof(x) ~= "Vector3" then return end` 식).
- 플레이어끼리 로벅스나 현금 가치가 있는 거래를 만들지 않습니다 (로블록스 규정 위반).
- 랜덤 상품을 팔면 확률을 공개합니다.

## 코드 규칙

- 언어: Luau. 새 파일은 맨 위에 `--!strict`를 권장합니다 (기존 파일은 점진적으로).
- 서비스는 `game:GetService("이름")`으로 가져오고 파일 맨 위에 모읍니다.
- 들여쓰기는 탭. 상수는 `UPPER_SNAKE_CASE`, 지역 변수·함수는 `camelCase`, 모듈 테이블은 `PascalCase`.
- 주석은 한국어로, "왜"를 적습니다.
- `wait()`, `spawn()`, `delay()` 대신 `task.wait()`, `task.spawn()`, `task.delay()`.
- 반복 루프나 무거운 생성 작업에는 `task.wait()`를 넣어 Studio·서버가 멈추지 않게 합니다.
- 밸런스 숫자(확률, 가격, 경도)는 코드에 흩뿌리지 말고 `shared/` 아래 데이터 모듈로 모읍니다.

## 맵 사실관계 (현재 플레이스 기준)

- 광산 여러 개 구조 (`docs/decisions.md` D-006). 광산 목록·위치·지층·광물표는 **`src/shared/Config/Mines.luau`가 원본**. 숫자를 코드에 따로 적지 말고 이 설정을 읽습니다.
- 지상 허브: `Workspace.CollapseMine.Hub` (광장, 판매소 `Shop`, 제작소 `Workshop`, 랭킹판 `Leaderboard`, 스폰 `MineSpawn`, 광산 입구 `MinePortals/Portal_<id>`)
  - 배치: 스폰 `MineSpawn` (0, 1.5, 84)을 가운데 두고 제작소(0, 116, 남향)·판매소(-58, 90, 동향)·랭킹판(58, 90, 서향)이 돌바닥 광장을 ㄷ자로 둘러싼다. 광산 입구는 남쪽 (0, 0, 38)
  - 건물 3개는 `tools/build_hub_buildings.luau`(파트 버전) 또는 `tools/blender/build_*.py` + `tools/import_hub_mesh.luau`(블렌더 메시 버전, 현재 사용 중)로 생성. 상호작용(판매·제작)은 각 건물의 `Counter` 파트에, 랭킹 표시는 `Leaderboard/Board_BestHaul`·`Board_BestOre`·`Board_TotalEarned`의 SurfaceGui `Rows/Row1~5` 텍스트를 서버에서 바꿔서 붙인다
  - 허브는 사방이 절벽(높이 40~56)으로 둘러싸인 분지. 절벽 위 바깥쪽에 투명 경계벽(`Hub/Boundary`)이 있어 밖으로 떨어지지 않는다. `tools/build_hub_cliffs.luau`로 생성 (분지 중심 (0,0,90), 안쪽 반폭 88×52)
  - 광산 입구는 입구마다 뒤에 거대한 산(눈 덮인 봉우리)을 두고 앞면 절벽에 깔때기 모양 동굴 아가리(앞 46×56)를 뚫는 방식. 입구가 웅장해야 다음 광산에 가고 싶어진다는 방향 (D-008). `tools/build_cave_entrance.luau`로 생성, `THEME`으로 광산별 분위기(basic, lava). 기본 광산 입구는 남쪽 (0, 0, 38)
  - 새 입구를 낼 때 경계벽이 입구 안쪽을 가로막지 않는지 확인 (경계벽은 절벽 안쪽 면에서 약 37 뒤)
- 광산: `Workspace.Mines.<id>` — `tools/generate_mine.luau`로 생성
  - `Ores/` 광석 (태그 `Ore`, 속성 `MineId`, `Ore`, `DisplayName`, `Grade`, `OreValue`, `Hardness`, `Layer`, 채굴 중 `HP`)
  - `Rooms/` 투명 방 구역 (속성 `RoomType`=Entrance/Hub/Side/End, `Layer`, `CollapseRisk`)
  - `Lights/` 램프, `Entrance` 도착 지점, `ExitPoint` 출구 발판 (태그 `MineExit`)
- 이동: 포탈(태그 `MinePortal`, 속성 `MineId`) → 광산 입구, 출구 발판 → 허브 스폰. 플레이어 속성 `PickaxeTier`가 광산의 `requiredPickaxe` 이상이어야 입장.
- 땅은 Terrain, 굴은 개미굴 모양(입구 방 → 허브 방 → 완만히 내려가며 퍼지는 굴, 옆방·끝방). 수직 구멍은 만들지 않습니다 (걸어서 올라올 수 있어야 함).
- 현재 광산: `basic` 기본 광산 — 중심 (0, 0, -900), 반경 350, 지층 흙(-4~-50)·바위(-50~-125)
- 지표(광산 `top` 위)와 허브는 채굴 불가.
- 이전 맵 백업: `ServerStorage.OldPitBackup`, `HangingNestBackup`, `FirstCaveBackup`, `OldPortalBackup`(나무 아치 포탈)

## Git 흐름

- `main`은 보호 브랜치. 직접 push하지 않고 PR로만 머지합니다.
- 개인 작업 브랜치(예: `leewoojin`) 또는 기능 브랜치(`feat/기능이름`, `fix/버그이름`, `docs/주제`)에서 작업합니다. `dev` 브랜치는 두지 않습니다.
- 커밋 메시지는 한국어, 첫 줄에 무엇을 했는지 요약. 필요하면 빈 줄 뒤에 이유를 적습니다.
- PR은 다른 담당자 1명 이상의 리뷰를 받고 머지합니다.

## 하지 말 것

- Studio에서 스크립트를 직접 수정하고 끝내기 (레포에 반영 안 됨)
- 같은 팀 크리에이트 플레이스에 두 사람이 동시에 `rojo serve` 연결
- 다른 담당 폴더 코드 직접 수정
- 클라이언트에서 보상·확률 계산
- 플레이스 파일, 개인 설정 파일 커밋
- 기획서와 다른 방향으로 구현하고 문서는 그대로 두기
