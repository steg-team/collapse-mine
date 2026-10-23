# 결정 기록 (Decision Log)

기획·구조에서 정한 것을 시간순으로 남깁니다. **지운 결정도 지우지 말고** 상태만 `폐기`로 바꾸고 이유를 적습니다.
AI 에이전트는 구현 전에 이 문서와 `game-design.md`를 읽고, 둘이 충돌하면 이 문서의 최신 결정을 따릅니다.

형식

```
## D-번호 제목
- 날짜 / 상태(채택·보류·폐기) / 결정한 사람
- 결정:
- 이유:
- 영향: (바뀌는 코드·맵·문서)
```

---

## D-001 맵은 개미굴 모양 대각선 동굴

- 2026-10-21 / 채택 / 이우진
- 결정: 원형으로 파 내려가는 구덩이 대신, 땅 속 개미굴 모양 동굴로 한다. 입구 경사로 → 허브 방 무리 → 대각선으로 내려가는 나선 굴 여러 갈래, 굴 중간중간 방 여러 개.
- 이유: 수직굴은 붕괴 때 올라올 방법이 없다. 대각선 경사로면 걸어서 탈출할 수 있어서 "붕괴 직전 출구로 달리기"가 성립한다.
- 영향: 맵은 Terrain 동굴(`tools/generate_ant_cave.luau`, 이후 D-006에서 `generate_mine.luau`로 대체). 처음 만든 원통 광산과 매달린 개미굴은 `ServerStorage` 백업으로 보관.

## D-002 광맥과 약한 지반

- 2026-10-21 / 채택 / 이우진
- 결정: 굴과 방 주변에 광맥(광석)을 몰아두고, 광맥 근처는 지반이 약해 붕괴 위험을 높인다.
- 이유: 땅을 직접 파는 게임이라 길이 다 뚫려 있으면 파는 재미가 없다. "좋은 광물은 위험한 곳에"라는 위험-보상 구조를 만든다.
- 영향: 방 구역 파트 `Rooms/*`에 `CollapseRisk` 속성, 광석 `Ores/*`에 `OreValue`·`Hardness`. 붕괴 판정 구현 시 사용.

## D-003 코드는 Rojo + Git, 맵은 팀 크리에이트

- 2026-10-21 / 채택 / 이우진
- 결정: 스크립트는 레포 `src/`가 원본이고 Rojo로 Studio에 동기화한다. 맵과 모델은 팀 크리에이트 플레이스에서 관리하고, 생성 스크립트만 `tools/`에 둔다. 레포는 GitHub 조직 `steg-team` 소유.
- 이유: 3명이 동시에 코드를 만지면 Studio만으로는 이력·리뷰가 안 된다. 조직 소유로 두면 특정 개인에게 묶이지 않는다.
- 영향: `default.project.json`, `AGENTS.md`, `CLAUDE.md`

## D-004 브랜치는 main + 개인/기능 브랜치, dev 없음

- 2026-10-21 / 채택 / 이우진
- 결정: `main`은 PR로만 머지한다. 작업은 개인 브랜치(`leewoojin` 등)나 기능 브랜치에서 한다. 별도 `dev` 브랜치는 두지 않는다.
- 이유: 깃은 형상관리 목적이고, 로블록스 배포는 Studio 게시라 스테이징 브랜치가 필요 없다. 테스트 환경이 필요해지면 브랜치 대신 테스트용 플레이스를 따로 둔다.
- 영향: `AGENTS.md` Git 흐름

## D-005 기획서는 레포에서 관리

- 2026-10-21 / 채택 / 이우진
- 결정: 기획서 원본을 `docs/game-design.md`로 옮겨 Git으로 관리한다. 기획 변경은 PR로 올리고 3명 모두 리뷰한다.
- 이유: 3명과 각자의 AI가 같은 방향을 보고 만들어야 하고, 기획이 바뀌면 그 이력이 남아야 한다.
- 영향: `docs/`, `AGENTS.md`, `CLAUDE.md`, `CODEOWNERS`

## D-006 곡괭이 등급마다 다른 광산

- 2026-10-21 / 채택 / 이우진
- 결정: 광산을 여러 개 만들고, 곡괭이 등급을 올리면 다음 광산이 열린다. 한 장소 안에 허브 하나와 광산 여러 개를 따로 짓고, 허브 포탈로 오간다. 광산은 설정 파일 한 줄로 추가한다. 붕괴는 광산마다 따로, 시간을 엇갈리게 둔다.
- 이유: 맵 하나를 깊게만 파면 금방 끝나고 성장 동기가 약하다. 곡괭이마다 새 광산이 열리면 업그레이드할 이유가 확실하다. 한 장소에 두면 공지·리더보드·붕괴를 서버 전체가 공유한다.
- 영향: `src/shared/Config/Mines.luau`, `tools/generate_mine.luau`(구 `generate_ant_cave.luau` 대체), `MiningServer`, `MineTravel`, 허브 포탈. 첫 개미굴(허브 바로 아래, 지층 5개)은 폐기하고 메움 — 오브젝트는 `ServerStorage.FirstCaveBackup`.

## D-007 기본 광산은 얕고 아주 넓게

- 2026-10-21 / 채택 / 이우진
- 결정: 기본 광산은 반경 약 350, 깊이 약 120(지층 2개), 굴 12갈래 + 곁가지. 처음 목표는 방 40~50개였으나 "더 크게" 요청에 따라 곁가지를 그대로 두어 실제 생성 결과는 방 약 150개(옆방 111, 끝방 35), 광석 약 970개, 램프 약 240개 (seed 7).
- 이유: 첫 광산이 좁으면 금방 끝난다. 깊은 층 테마는 다음 광산이 맡으므로 기본 광산은 깊이 대신 넓이로 플레이 시간을 만든다.
- 영향: `src/shared/Config/Mines.luau`의 `basic` 설정. 플레이 테스트 후 방·광석이 너무 많으면 `cave.subBranchChance`, `roomSpacing`을 줄여 재생성.

## D-008 광산 입구는 웅장하게

- 2026-10-21 / 채택 / 이우진
- 결정: 시작 지점은 사방을 절벽으로 둘러싸 낙사를 막고, 광산 입구마다 뒤에 거대한 산(뾰족한 봉우리, 눈 덮인 정상)과 깔때기 모양의 거대한 동굴 아가리를 둔다. 화로, 사슬에 매단 대형 표지판, 갱도 문틀, 레일·광차로 장식한다. 광산마다 테마(바위, 용암 등)를 바꾼다.
- 이유: 용암 동굴 등 광산이 계속 늘어날 텐데, 입구가 장엄해야 "저기 가보고 싶다"는 동기가 생긴다. 허브 바깥이 낭떠러지라 절벽으로 막아야 한다.
- 영향: `tools/build_hub_cliffs.luau`, `tools/build_cave_entrance.luau`, `Hub/Boundary`, `Hub/MinePortals`

## D-009 랭킹은 깊이 대신 수확 기준 3종

- 2026-10-21 / 채택 / 이우진
- 결정: 허브 리더보드의 "깊이 순위"를 없애고 랭킹 3종을 둔다. ① 최고 탈출 수확(붕괴 한 번에 살아서 들고 나온 광물 가치, 주간 초기화, 메인) ② 최고 광물(한 덩이 최고가 = 무게 × 압력 등급, 전체 기간) ③ 누적 수입(지금까지 번 코인, 전체 기간). 허브 판매소·제작소·랭킹판 디자인도 새로 짓는다.
- 이유: 광산이 곡괭이 등급별로 나뉘고(D-006) 기본 광산이 얕아져서(D-007) 깊이는 누구나 금방 바닥에 닿거나 곡괭이 등급과 같아진다. 게임의 핵심인 "더 캘까, 지금 탈출할까"를 잘한 사람이 1등이 되게 한다. 주간 초기화로 신규 유저도 도전할 수 있게 한다.
- 영향: `docs/game-design.md` 허브 표, `tools/build_hub_buildings.luau`, `Hub/Leaderboard`(Board_BestHaul·Board_BestOre·Board_TotalEarned). 최고 탈출 수확은 붕괴 이벤트(`CollapseEnded`)가 생긴 뒤 집계 가능. 구현은 C 담당.

## D-010 새 광산 "별이 떨어진 곳" 광석 6종

- 2026-10-22 / 채택(광석 모델만, 광산 순서·곡괭이·가치는 미정) / 이우진
- 결정: 밤하늘·운석 테마 광산 "별이 떨어진 곳"을 후보로 두고, 광석 6종의 모델을 먼저 만든다. 운석 파편 · 별가루 원석 · 성운석 · 혜성 핵 · 별빛 결정 · 떨어진 별. 가치 임시값(낮은 순): 330M · 530M · 830M · 2B · 5B · 17B.
- 이유: 빛나는 광석은 멀리서도 눈에 띄어 "저기 가 보고 싶다"는 동기를 만든다. 모델을 먼저 만들어 두면 광산을 지을 때 바로 쓸 수 있다.
- 영향: `tools/blender/build_starfall_ores.py`, `tools/import_starfall_ores.luau`, `ServerStorage.OreModels.Starfall`. 광산 위치·지층·광물표는 광산을 지을 때 `src/shared/Config/Mines.luau`에 추가. 광석이 Part가 아니라 모델이라 광산 생성기·채굴 판정(`Hitbox` 파트 기준)도 그때 맞춘다. 가치 단위(M, B)는 경제 설계(B 담당)와 맞춰 확정.
- 보강 (2026-10-22): 참고 이미지(제미나이 그림)에 맞춰 모양을 다시 잡음. 성운석("swirling purple, magenta pink and electric blue cosmic clouds with tiny stars")·별가루 원석("deep navy space stone with scattered tiny white star dots")의 무늬는 Studio AI 텍스처로 입힘. 혜성 핵은 ForceField 빛 구슬, 떨어진 별은 Foil 금빛, 결정은 Glass + 조명. 견본은 Workspace.StarfallOrePreview (하늘 진열대 `_OreStage`, (1000, 600, 0)), 확인 후 지워도 됨.
- 보강 2 (2026-10-22): 모양을 직접 만드는 대신 **그림 자체를 텍스처로** 쓰는 방식으로 바꿈. 그림 실루엣을 부풀린 로우폴리 메시 + SurfaceAppearance(ColorMap = 그림, EmissiveMask = 용암·별 등 밝은 부분). 옆면은 그림 안쪽 무늬 조각을 둘러 입힘. 생성: `tools/blender/build_starfall_from_images.py` → `tools/import_starfall_tex.luau`. 광석마다 오라(입자·ForceField 빛막·Highlight)를 붙임(임시값). 입자가 많으니 광산에 뿌릴 땐 가까운 광석만 켜는 클라이언트 처리가 필요. Tripo 등 이미지→3D 서비스는 무료 플랜에서 내보내기·상업 이용이 막혀 보류.

## D-011 역할 분담 최신화와 이벤트 계약 정리

- 2026-10-22 / 채택 (팀 리뷰 대기) / C 담당
- 결정:
  - 역할 분담을 공유 기획서(Claude 문서) 기준으로 맞춘다. 게임패스·부스트·결제는 B → **C**, 광산 카나리아는 A → **B**, 광맥 재생은 B → **A**, 곡괭이는 성능 A / 비용 B로 나눈다 ("성능은 A, 돈은 B").
  - 이벤트 계약을 `src/shared/Events.luau` 기준으로 다시 정한다. `CollapseStarted`/`CollapseEnded` → `CollapseWarning`(경보)/`CollapseOccurred`(실제 붕괴) + `PlayerEscaped`/`PlayerTrapped`. `BoostPurchased` 이벤트는 없애고 C의 조회 함수 `Monetization.HasPass`/`GetMultiplier`로 대체. 붕괴까지 남은 시간은 `Collapse.GetRemainingTime`으로 조회.
  - D-009 랭킹 3종 집계를 위해 B → C 이벤트 `OreBagged`(광물 확정 가격), `OreSold`(판매액), `HaulSecured`(탈출 수확 가치)를 추가. 그 밖에 `PlayerDataLoaded`, `StageEntered`, `QuestCompleted`, `DailyLoginClaimed` 추가.
- 이유: 레포 문서가 공유 기획서보다 오래된 버전이었다. "일어난 일"은 이벤트로, "지금 상태"(패스 보유, 배수, 남은 시간)는 조회 함수로 나누면 상태를 여러 곳에서 따로 들고 있다가 어긋날 일이 없다. 붕괴는 카운트다운이 끝나는 순간이 곧 붕괴라 시작·종료를 나눌 필요가 없다.
- 영향: `src/shared/Events.luau`, `AGENTS.md`·`game-design.md` 역할·이벤트 표, `CODEOWNERS` 주석. 이벤트를 쏘고 받는 `src/shared/EventBus.luau` 추가(C 작성). `Core/`·`shared/`는 특정 담당 없이 0단계 공통 기반으로 두고 3명 리뷰 (공유 기획서에 B의 "공용 코드" 담당 표기가 없음). `친구 초대`(C)와 `리버스`(B)는 공유 기획서에 담당 표기가 없어 기존대로 둔다.
- 보강 (2026-10-22): 결제 모듈 이름을 `Monetization` → `Payments`로 바꿈 (읽기 쉬운 이름). 이벤트 인자 `stageId`(number) → `mineId`(string, `Config/Mines.luau`의 광산 id)로 바꿈. 레포의 광산 id가 문자열이라서.

## D-012 기본 광산 광물을 1스테이지 6종 모델로

- 2026-10-22 / 채택 (팀 리뷰 대기) / 이우진 (A)
- 결정: 기본 광산(`basic`)의 광물표를 석탄·구리·아연·철에서 공유 기획서 1스테이지 "흙 동굴" 6종으로 바꾼다. 석탄(일반) · 구리(일반) · 석영(고급) · 호박석(희귀) · 동굴 진주(에픽) · 광부의 녹슨 등불(전설). 가치 임시값 2 · 5 · 15 · 45 · 140 · 480, 확률·경도·나오는 깊이도 임시값 (`src/shared/Config/Mines.luau`).
- 광석은 색 파트 대신 `ServerStorage.OreModels.Stage01`의 광물 틀(Roblox AI 생성, `tools/ai_ore_models.md`)을 복사해 굴 벽·바닥에 바닥면을 붙여 박는다. 설정의 `model` 칸이 틀 경로이고, 틀이 없으면 예전처럼 색 파트를 만든다.
- 채굴 판정은 맞은 파트가 속한 광석 모델(태그 `Ore`)을 찾아 깎는다. 맞을 때마다 조금씩 작아지고, 경도만큼 때리면 깨진다.
- 이유: 레포 문서가 공유 기획서보다 오래된 광물표였다 (D-011과 같은 이유). 모델 광석이 멀리서도 등급이 보여 캐고 싶어진다.
- 영향: `tools/generate_mine.luau`(광석을 굴을 다 판 뒤 박음, 광석용 난수를 따로 써서 광물표를 바꿔도 굴 모양 유지), `src/server/Mining/MiningServer.server.luau`. 팀 플레이스에서 광산을 다시 생성해야 반영된다. 판매가 단위는 경제 설계(B)와 맞춰 확정.
- 보강 (2026-10-22): 굴·방이 좁아 보여서 기본 광산을 크게 다시 생성 (굴 반경 5 → 7, 방 크기·높이 1.4배 `cave.roomScale`, 임시값). 희귀·에픽·전설 광물은 벽 표면에 아예 안 나오고 **땅 속에만 묻혀서 지형을 파야 나오게** 함 (`buried`: 벽 광석 자리마다 35% 확률로 그 뒤 4~9스터드 흙 속에 하나, 묻힌 동안 빛·반짝임 꺼짐, 처음 맞히면 켜짐). 출구는 입구 방 벽의 갱도 문 → 비탈 굴 → 풀밭 위 바위 언덕의 동굴 아가리 (`tools/build_mine_exit.luau`). 예전 광산은 `ServerStorage.MineBackups`(광석·방 폴더 + 지형 TerrainRegion).
- 보강 2 (2026-10-23): 희귀·에픽·전설은 미리 묻지 않고 **지형을 팔 때마다 확률로** 판 자리 벽에 드러난다 (`digFinds.chance`, 지표 0.4% → 바닥 1.2%, 등불 weight 0.2, 임시값). 그 깊이의 minDepth를 만족하는 광물 중 weight로 뽑음. 미리 묻는 방식은 여럿이 파면 금방 바닥나서 버림. 벽 광석(일반·고급)은 붕괴(`CollapseOccurred`) 뒤 `oreRegrowDelay`초에 빈 자리를 다시 채운다 (`OreSpawner`, 광맥 재생의 첫 버전. "오래 비울수록 더 깊고 비싼 광맥"은 아직). 광석 만들기 공통 코드는 `src/server/Mining/OreFactory.luau`.
- 보강 3 (2026-10-22): **길바닥은 못 판다** (`src/server/Mining/FloorGuard.luau`). 바닥을 파서 구멍을 내면 붕괴 때 출구로 가는 길이 끊기기 때문. 서버 시작 때 지형을 훑어 평평한 바닥 표면 칸과 그 아래 한 칸을 보호하고, 파는 공이 닿으면 위로 올린다. 굴 벽(비탈)은 보호하지 않아서 옆으로 새 굴을 내는 건 된다. 

## D-013 붕괴 판정 규칙

- 2026-10-22 / 채택 (팀 리뷰 대기) / C 담당
- 결정:
  - 광산마다 `Config/Mines.luau`의 `collapse = { interval, warning, offset }`대로 대기 → 경보(카운트다운) → 붕괴를 반복한다. 붕괴가 끝나면 그 시점부터 다음 주기를 센다.
  - 붕괴 주기 `interval`은 `NumberRange`(예: 8~12분)이고 매 주기 그 안에서 랜덤으로 뽑는다. 주기가 일정하면 플레이어가 타이밍을 외워 긴장감이 줄어든다. 주기 숫자는 광산 설정 한 곳에만 둔다 (D-006 "광산 하나 = 설정 한 줄").
  - **탈출 성공** = 경보 중에 광산 안에 있었던(경보 중 새로 들어온 사람 포함) 플레이어가 붕괴 순간 광산 밖에 있으면. 늦게 나올수록 보너스가 크다 (최소~최대 코인, `Config/Social.luau`).
  - **갇힘** = 붕괴 순간 광산 안. `PlayerTrapped`를 쏘고(가방 차감은 B), 3초 뒤 허브 스폰으로 옮긴다.
  - 서버 공지: 경보 시작, 남은 30초·10초, 붕괴 순간(탈출·갇힘 인원). 정밀 카운트다운 HUD는 다음 작업. 클라이언트는 `ReplicatedStorage.CollapseState`의 속성 `<광산 id>`(붕괴 시각, 서버 시계)로 카운트다운을 그릴 수 있다.
  - "광산 안"은 `Mines.findAreaAt(위치)`로 판정한다 (광산 반경 안이면 지표 위 포함). 출구 비탈 굴이 지표 위까지 올라가서, 지표 아래만 보는 `findAt`(채굴 가능 판정용)으로는 출구 게이트에 닿기 전에 탈출로 판정됐다 (2026-10-23 수정). 광산 밖으로 나가는 길은 출구 게이트(→ 허브)뿐이다.
- 이유: 갇힌 사람을 그대로 두면 막힌 통로 안에서 못 나온다. 경보 전에 이미 나간 사람에게 보너스를 주면 "끝까지 버티기"의 의미가 없다.
- 영향: `src/server/Social/Collapse.luau`, `src/shared/Config/Social.luau`(C 설정 한 파일, 숫자 전부 임시값).
- 보강 (2026-10-23): **경보 중 광산 안에서 죽으면 갇힘**으로 친다. 리셋하면 허브에서 부활해 "광산 밖"으로 판정돼, 리셋만으로 탈출 성공 + 최대 보너스를 받는 꼼수가 있었다. 부활 후 다시 광산에 들어와 걸어 나오면 탈출로 인정한다.

## D-014 플레이어 데이터 저장

- 2026-10-22 / 채택 (팀 리뷰 대기) / B 담당
- 결정:
  - 플레이어당 DataStore 키 하나(`Player_<UserId>`)에 모든 저장 데이터를 담는다. 세션 잠금·자동 저장은 ProfileStore(loleris, MIT)를 `src/server/Economy/ProfileStore.luau`로 가져와 쓴다.
  - 저장 칸: `coins`, `pickaxe`(tier·enhance), `canary`, `rebirths`, `bag`(광물마다 ore·weight·pressure·value, 가방 = 인벤토리), `codex`(도감), `stats`(totalEarned·bestOre·bestHaul), `social`(C 전용 칸, 구조는 C가 정함), 스키마 버전 `v`. 게임패스는 저장하지 않고 매번 조회한다.
  - 붕괴 경보 중에 광산 안에서 접속을 끊으면 갇힘과 같은 비율로 가방을 차감한다. 평소 접속 끊김은 가방을 그대로 둔다.
  - `PlayerTrapped`를 받으면 같은 비율로 가방을 차감하고, `PlayerEscaped`를 받으면 보너스 코인을 준다.
  - 다른 기능은 `PlayerDataLoaded` 이후 `PlayerData.get(player)`로 읽는다. 쓰기는 B가 하고, C는 `social` 칸만 쓴다.
- 이유: 서버를 옮길 때 데이터가 덮어써지거나 복제되는 것을 막으려면 세션 잠금이 필요하고, 직접 짜면 버그가 곧 데이터 유실이다. 키를 하나로 두면 저장이 한 번에 처리돼 칸끼리 어긋나지 않는다. 경보 중 접속 끊기로 갇힘 차감을 피하는 꼼수를 막되, 평소 튕김에는 손해가 없게 한다.
- 영향: `src/server/Economy/PlayerData.luau`, `EconomyInit.server.luau`, `src/shared/Config/Economy.luau`(갇힘 차감 비율, 임시값), `Events.luau` 조회 함수 주석. 코인은 당분간 `leaderstats.Coins` 값을 저장한다 (A의 채굴 코드가 직접 더하는 동안). Studio에서 실제로 저장하려면 게임 설정 → 보안 → "Studio에서 API 서비스 사용"을 켠다 (꺼져 있으면 저장 없이 돌아감).

## D-015 PR은 올린 사람이 직접 머지

- 2026-10-22 / 채택 / 이우진
- 결정: 리뷰 필수 규칙과 `.github/CODEOWNERS`(자동 리뷰 요청)를 없앤다. 각자 올린 PR은 본인이 직접 머지한다. 다른 담당 폴더·`shared/`·`Core/`·`docs/`·이벤트 계약을 건드리면 PR에 해당 담당을 멘션해서 알린다. main과 충돌이 나면 올린 사람이 푼다.
- 이유: 3명이 서로 리뷰를 기다리느라 머지가 밀리고, 자동 리뷰 요청이 매번 쌓였다. `main` 브랜치 보호도 꺼져 있어 리뷰가 실제로 막는 역할을 하지 않았다.
- 영향: `AGENTS.md`, `README.md`, `docs/README.md`, `game-design.md`의 협업 규칙.

## D-016 출석 보상

- 2026-10-23 / 채택 / C 담당
- 결정:
  - **7일 주기**. 날마다 보상이 커지고 7일차가 가장 크다. 하루라도 빠지면 1일차부터 다시. 7일차 다음 날은 1일차.
  - 화면 왼쪽 📅 버튼 → **출석판 UI에서 "받기" 버튼**으로 받는다. 받을 보상이 있으면 접속하자마자 자동으로 열리고, 버튼에 빨간 점이 뜬다.
  - 하루는 UTC 자정(한국 오전 9시)에 바뀐다 (`dayOffsetHours`로 조정).
  - 저장은 B의 `PlayerData`에서 C 전용 칸 `data.social.daily = { lastClaimDay, streak }`. 판정은 전부 서버.
  - 코인 지급은 **B가 `DailyLoginClaimed(player, streak, { coins })`를 받아서** 한다 (C는 기록과 이벤트만).
  - 보상 숫자는 `Config/Social.luau`의 `DailyLogin.rewards` (10·20·30·50·70·100·200, 임시값).
- 이유: 기획서 "Creator Rewards: 붕괴 카운트다운, 출석 보상으로 체류 시간 확보". 연속을 끊으면 처음부터라 매일 들어올 이유가 생긴다.
- 영향: `src/server/Social/DailyLogin.luau`, `src/client/Social/DailyLoginPanel.client.luau`, `Config/Social.luau`, `tools/create_social_remotes.luau`(`Remotes.DailyLogin` RemoteFunction 추가 — 팀 플레이스에서 다시 실행 필요).

## D-017 2·3스테이지 광산 추가, 광산 이동은 텔레포트

- 2026-10-23 / 채택 / 이우진 (A)
- 결정: 공유 기획서 2·3스테이지대로 광산 두 개를 추가한다. `iron` 철광 갱도(중심 (-900, 0, -900), 돌 곡괭이, 지층 갱도 바위·철광층, 철·주석·은·자철석·백금·감독관의 회중시계), `groundwater` 지하수 동굴(중심 (900, 0, -900), 철 곡괭이, 지층 석회암·젖은 암반, 석회석·방해석·남동석·공작석·물빛 진주·젖은 광산 지도). 굴 모양 규칙·파다가 발견·길바닥 보호·출구는 기본 광산과 같다. 붕괴는 3분씩 엇갈리게(offset 0·180·360). 가치·확률·경도는 임시값이고 판매가 단위는 B와 맞춰 확정.
- 광산 사이 이동은 허브에 광산마다 입구를 내지 않고 **텔레포트**로 한다 (텔레포트 UI는 다음 작업). 레포 기획서의 2·3번 예시(철·금 / 수정 동굴 사파이어·루비)는 이걸로 대체.
- 이유: 광물 모델이 이미 있고 공유 기획서가 최신이다. 허브 남쪽 절벽에 산을 여러 개 붙이면 기본 광산 입구를 덮는다.
- 영향: `src/shared/Config/Mines.luau`, `game-design.md` 광산 표. 팀 플레이스에 `tools/generate_mine.luau`·`tools/build_mine_exit.luau`로 생성 (MINE_ID = "iron", "groundwater").

## D-018 서버 부스트

- 2026-10-23 / 채택 / C 담당
- 결정:
  - 개발자 상품(여러 번 구매 가능) 하나: 사면 **서버 전체가 30분 동안 채굴 속도 2배**. 부스트 중에 또 사면 **배수는 그대로, 시간만 30분 연장**.
  - 서버마다 따로이고 저장하지 않는다 (그 서버가 닫히면 끝). 효과는 `Payments.GetMultiplier(player, "MineSpeed")`에 곱해져서 A 코드는 바꿀 필요 없다.
  - 결제는 `Payments.luau`의 `ProcessReceipt` 한 곳에서 처리 (게임 전체에 하나만 둘 수 있음). 처리한 영수증 ID를 `data.social.receipts`에 최근 50개 저장해 같은 영수증을 두 번 지급하지 않는다.
  - 구매 시 서버 공지("OOO님이 서버 전체에 서버 채굴 2배를 선물했습니다!"), 화면 오른쪽 위에 남은 시간, 왼쪽 🚀 버튼으로 구매 창.
- 이유: 기획서 수익 모델 "서버 부스트 구매 시 OOO님이 서버 전체에 2배를 선물 공지", "첫 버전은 게임패스 2~3개 + 서버 부스트 1개". 배수를 겹치면(4배, 8배) 밸런스가 쉽게 깨진다.
- 영향: `src/server/Social/Payments.luau`, `src/client/Social/BoostHud.client.luau`, `Config/Social.luau` ServerBoost (`productId`는 대시보드에서 상품을 만든 뒤 채움, 가격·시간 임시값).

## D-020 가방과 판매소

- 2026-10-23 / 채택 / B 담당
- 결정:
  - 캔 광물(`OreMined`)은 가방에 담는 순간 값을 확정한다: **기본가(`Mines.luau` 광물표 `value`) × 무게 × 압력 배수**, 반올림, 최소 1. 압력 배수는 상압(`Low`) 1 · 고압(`High`) 1.5 · 초고압(`Extreme`) 3 (임시값).
  - `OreMined`의 `weight`는 **무게 배수**(1 = 보통)다. 광물표의 `weight`(출현 확률 가중치)와 다르다.
  - 가방은 20칸, "가방 확장" 패스(BigBag)는 +20칸 (임시값). 꽉 차면 더 캐도 안 담긴다.
  - 판매는 허브 판매소 `Counter`의 프롬프트("가방 전부 팔기")로 **가방을 통째로** 판다. 판매액 = 담을 때 확정한 값 × `Payments.GetMultiplier(player, "SellPrice")`.
  - 탈출(`PlayerEscaped`)하면 그때 가방 전체 가치를 탈출 수확으로 보고 `HaulSecured`를 쏜다.
  - 출석·퀘스트 보상(`DailyLoginClaimed`·`QuestCompleted`)의 코인은 B가 준다. 아이템 보상은 아이템 기능이 생기면.
- 이유: 기획서 "판매가 = 기본가 × 무게 × 압력 배수". 값을 담을 때 확정해야 붕괴 직전에 캔 광물이 비싸다는 게 유지되고, C의 "최고 광물" 랭킹(`OreBagged`)도 같은 값을 쓴다. 가방이 차면 허브로 올라와야 해서 "더 캘까, 나갈까" 고민이 생긴다. 낱개 판매·팔까 말까 고민(제작 재료)은 제작소가 생길 때 붙인다.
- 영향: `src/server/Economy/Bag.luau`, `src/client/Economy/BagHud.client.luau`(화면 아래 가방 표시, 플레이어 속성 `BagCount`·`BagCapacity`·`BagValue`), `Config/Economy.luau`. A는 광석이 깨질 때 `OreMined`를 쏘고 코인 직접 지급을 지워야 한다 (`docs/handoff-B.md`).

## D-021 곡괭이 제작과 강화

- 2026-10-23 / 채택 / B 담당
- 결정:
  - 곡괭이 단계는 광산 입장 등급(`requiredPickaxe`)과 같다: 1 나무 · 2 돌 · 3 철 · 4 금. 다음 단계는 허브 제작소 `Counter`의 "다음 곡괭이 만들기"(E)로 만든다.
  - 제작 비용 = 코인 + 가방 속 광물. 재료는 바로 전 광산의 고급·에픽 광물이다: 돌 300코인 + 석영 3, 철 2000코인 + 은 3 + 백금 1, 금 10000코인 + 남동석 3 + 물빛 진주 1 (임시값). 재료는 같은 광물 중 값이 싼 것부터 쓴다.
  - 강화는 "곡괭이 강화"(F)로 단계마다 +5까지. n강 → n+1강 비용 = 단계별 기본 비용 × (n+1) (나무 50 · 돌 300 · 철 1500 · 금 6000, 임시값). 다음 단계를 만들면 강화는 0부터.
  - 제작·강화하면 `PickaxeUpgraded(player, tier, enhance)`를 쏘고 플레이어 속성 `PickaxeTier`·`PickaxeEnhance`를 갱신한다. 강화가 성능에 주는 효과는 A가 정한다.
  - 실패 이유("석영 2개가 더 필요해요")와 판매 결과는 화면 아래 한 줄 알림으로 보여 준다 (속성 `EconomyNotice`).
- 이유: 기획서 "에픽 이상 광물은 팔면 돈, 모으면 다음 층을 여는 곡괭이" — 재료를 가방에서 쓰게 해서 "팔까, 쓸까"가 생긴다. 다음 광산 재료를 요구하면 순서대로 광산을 거치게 된다. 5단계(최상위)와 용암 광산은 광산이 생기면 추가.
- 영향: `src/server/Economy/Workshop.luau`, `src/client/Economy/WorkshopPrompt.client.luau`(프롬프트에 내 비용 표시), `BagHud`(알림 줄), `Config/Economy.luau` `PICKAXES`·`ENHANCE_MAX`. 곡괭이 모델을 단계별로 바꾸는 건 A.

## D-022 인벤토리 창과 코인 원본

- 2026-10-23 / 채택 / B 담당
- 결정:
  - 화면 아래 가방 버튼(또는 B 키)으로 인벤토리 창을 연다. 캔 광물마다 이름(등급 색)·무게·압력·값을 보여 주고, **판매소 근처에서만** 한 개씩 "팔기" 또는 "전부 팔기"가 켜진다. 판매소 프롬프트("가방 전부 팔기")도 그대로 둔다.
  - 통신은 `Remotes.Bag`(RemoteFunction, 없으면 서버가 만듦): `"get"` 목록, `"sell", index, oreId` 한 개, `"sellAll"` 전부. 판매 거리·금액은 서버가 판정하고, 결과는 화면 아래 알림 줄로 보여 준다.
  - 코인의 원본은 `data.coins`다. `leaderstats.Coins`는 화면 표시용 사본이고, A가 채굴 때 직접 더하는 동안만 그 차이를 `data.coins`로 받아 둔다.
- 이유: 기획서 화면 구성 "아래: 인벤토리 슬롯 (캔 광물, 무게·변이 표시, 가방 용량)". 비싸게 캔 광물은 남기고 싼 것만 팔거나, 제작 재료를 남겨 두려면 낱개 판매가 필요하다 ("팔까, 쓸까").
- 영향: `src/client/Economy/InventoryPanel.client.luau`, `BagHud`(가방 줄이 버튼으로), `Bag.luau`(`sellOne`, `Remotes.Bag`), `PlayerData.addCoins`.

## D-023 광산 카나리아

- 2026-10-23 / 채택 / B 담당
- 결정:
  - 모두 처음부터 카나리아(Lv0)를 갖고 있다. 광산 안에서 화면 오른쪽에 상태 한 줄: 희귀 이상 광물이 탐지 범위 안이면 "짹짹! n m 안에 있어요"(가까울수록 빨리 깜빡임), 그 광산이 붕괴 경보 중이면 "불안해해요! 어서 나가요", 아니면 "조용해요".
  - 탐지 범위 Lv0 20 · Lv1 30 · Lv2 45 · Lv3 60 (스터드). 제작소 "카나리아 키우기"(G)로 키운다: 200·1000·5000 코인 + 희귀 광물 2·4·6개 (모두 임시값). 희귀 광물은 값이 싼 것부터 먹인다.
  - 탐지는 클라이언트에서 한다. 광석은 원래 클라이언트에 보이는 파트라 새로 드러나는 정보가 없고, 보상과 무관한 힌트다. 레벨은 서버가 `data.canary`에 저장하고 플레이어 속성 `CanaryLevel`로 알린다.
  - 새 모델(어깨 위 새)과 울음소리는 아직 없다 (화면 표시만).
- 이유: 기획서 "광산 카나리아: 펫 새가 희귀 광물 근처에서 울고, 등급을 올리면 탐지 범위가 넓어짐, 붕괴가 가까워지면 불안해하며 경보 역할", 광물 등급표 "희귀: 판매, 카나리아 성장".
- 영향: `src/client/Economy/CanaryHud.client.luau`, `Workshop.luau`(`feedCanary`), `WorkshopPrompt`(비용 표시), `Config/Economy.luau` `CANARY`. 붕괴 상태는 C의 `ReplicatedStorage.CollapseState`를 읽는다.
