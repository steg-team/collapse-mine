# B(경제) 인계 문서

B 담당 기능이 지금 어디까지 됐고, 다른 담당이 무엇을 붙이면 되는지 적는다. 바뀔 때마다 이 문서를 고친다.
다른 담당에게 할 일이 생기면 여기 적는 것과 별개로 GitHub 이슈(라벨 `담당-A`/`담당-C`)를 연다. B에게 요청할 일은 라벨 `담당-B` 이슈로 남겨 달라.
규칙의 근거는 `decisions.md` D-014(데이터 저장), D-020(가방·판매소), D-021(곡괭이 제작·강화), D-022(인벤토리 창·코인 원본), D-023(광산 카나리아), D-024(리버스), D-027(가방 무게), D-028(가방 늘리기).

## 지금 되는 것

| 기능 | 파일 | 상태 |
|---|---|---|
| 데이터 저장 | `src/server/Economy/PlayerData.luau` | 동작. ProfileStore, 세션 잠금 |
| 가방 담기 | `src/server/Economy/Bag.luau` | 동작. A의 `OreMined`(#26)로 채굴과 연결됨. 무게(kg) 한도, 넘으면 느려짐 (D-027) |
| 판매소 | `Bag.luau` (`Bag.sellAll`) | 동작. 허브 `Shop/Counter`에 "가방 전부 팔기" 프롬프트 |
| 가방 HUD | `src/client/Economy/BagHud.client.luau` | 동작. 화면 아래 "가방 3/20 · 120 코인어치", 누르면 인벤토리 창 |
| 가방 늘리기 | `Bag.upgrade` | 동작. 판매소 "가방 늘리기"(F), 30kg → 최대 80kg. 리버스하면 처음으로 |
| 인벤토리 창 | `src/client/Economy/InventoryPanel.client.luau` | 동작. 가방 버튼·B 키. 판매소 근처면 한 개씩/전부 팔기 (`Remotes.Bag`) |
| 탈출 수확·보너스 | `Bag.luau` | `PlayerEscaped` → `HaulSecured` + 보너스 코인 |
| 갇힘 차감 | `Bag.luau`, `PlayerData.luau` | 갇힘·경보 중 광산 안 퇴장 → 가방 무게의 절반까지 (D-029) |
| 출석·퀘스트 코인 | `Bag.luau` | `DailyLoginClaimed`·`QuestCompleted`의 `reward.coins` 지급 |
| 곡괭이 제작·강화 | `src/server/Economy/Workshop.luau` | 동작. 제작소 Counter "다음 곡괭이 만들기"(E)·"곡괭이 강화"(F) |
| 광산 카나리아 | `src/client/Economy/CanaryHud.client.luau`, `Workshop.feedCanary` | 동작. 광산 안 오른쪽 상태 줄, 제작소 "카나리아 키우기"(G). 새 모델·소리는 아직 |
| 리버스 | `Workshop.rebirth` | 동작. 제작소 "리버스"(R 3초). 코인·곡괭이·가방 초기화, 판매가 영구 배수 |
| 한 줄 알림 | `Bag.notify`, `BagHud` | 판매 결과·제작 실패 이유를 화면 아래에 3초 |

## A 담당께

- 채굴 → 가방은 #26(D-025)으로 연결됐다. 광석이 깨지면 `OreMined`만 오고, 코인은 B가 판매 때 준다.
- `leaderstats.Coins`는 화면 표시용 사본이다. 코인을 바꿀 일이 생기면 직접 고치지 말고 B에 말해 달라 (원본은 `data.coins`, `PlayerData.addCoins`).
- 곡괭이: B가 제작·강화하면 `PickaxeUpgraded(player, tier, enhance)`가 오고, 플레이어 속성 `PickaxeTier`·`PickaxeEnhance`도 바뀐다. 리버스하면 `(player, 1, 0)`.
- **걸음 속도 (D-027, A 할 일, 이슈 #37)**: B가 플레이어 속성 `BagSpeedMultiplier`(1 → 0.6)를 갱신한다. 가방이 30kg을 넘으면 1보다 작아진다. 캐릭터 걸음 속도에 곱해 달라. 예:
  ```lua
  local function apply() humanoid.WalkSpeed = BASE_WALK * (player:GetAttribute("BagSpeedMultiplier") or 1) end
  player:GetAttributeChangedSignal("BagSpeedMultiplier"):Connect(apply)
  ```
  부스트 등 다른 속도 효과와 겹치면 A 쪽에서 한 곳에서 곱해 주면 된다.
- `oreId`가 `Mines.luau` 광물표에 없는 이름이면 B가 경고만 찍고 담지 않는다.

## C 담당께

- 판매가 배수 `GetMultiplier(player, "SellPrice")`, 가방 확장 `HasPass(player, "BigBag")`를 B가 읽는다. 게임 중에 BigBag을 사면 다음 광물을 담을 때부터 칸이 늘어난다.
- `OreBagged`의 값은 판매 배수를 곱하기 전, `OreSold`의 판매액은 곱한 뒤다.
- 카나리아 HUD가 `ReplicatedStorage.CollapseState`의 광산 속성(붕괴 시각)을 읽는다. 이름이나 형식을 바꾸면 알려 달라.
- `Collapse.DiedInsideMine`(#21)을 B가 쓴다. C의 `PlayerRemoving`이 먼저 지울 수 있어서, 캐릭터가 지워지는 순간(퇴장 때 `PlayerRemoving`보다 먼저) 읽어 둔다. 리셋 후 퇴장 4→2 확인.

## 아직 안 된 것 (B 다음 작업 순서)

1. 카나리아 새 모델(어깨 위)·울음소리: 모델이 생기면.
2. 곡괭이 5단계·용암 광산: 광산 설정이 생기면 `PICKAXES`에 한 줄.

## 로컬 테스트 방법

1. 로컬 복사본 플레이스를 열고 `tools/create_social_remotes.luau`를 한 번 실행한다. `Remotes`가 없으면 C의 Collapse·Payments가 멈추고, 그걸 쓰는 B도 같이 멈춘다.
2. `rojo serve` → Rojo 플러그인 Connect → Play.
3. 서버 쪽에 임시 Script를 넣고 `EventBus.Fire(Events.OreMined, player, "Coal", 1, "Low")`처럼 쏘면 A 없이 가방을 시험할 수 있다. 판매는 `require(Server.Economy.Bag).sellAll(player)`.
