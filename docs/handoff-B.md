# B(경제) 인계 문서

B 담당 기능이 지금 어디까지 됐고, 다른 담당이 무엇을 붙이면 되는지 적는다. 바뀔 때마다 이 문서를 고친다.
규칙의 근거는 `decisions.md` D-014(데이터 저장), D-020(가방·판매소).

## 지금 되는 것

| 기능 | 파일 | 상태 |
|---|---|---|
| 데이터 저장 | `src/server/Economy/PlayerData.luau` | 동작. ProfileStore, 세션 잠금 |
| 가방 담기 | `src/server/Economy/Bag.luau` | 동작. **A가 `OreMined`를 쏘기 전까지는 비어 있음** |
| 판매소 | `Bag.luau` (`Bag.sellAll`) | 동작. 허브 `Shop/Counter`에 "가방 전부 팔기" 프롬프트 |
| 가방 HUD | `src/client/Economy/BagHud.client.luau` | 동작. 화면 아래 "가방 3/20 · 120 코인어치" |
| 탈출 수확·보너스 | `Bag.luau` | `PlayerEscaped` → `HaulSecured` + 보너스 코인 |
| 갇힘 차감 | `Bag.luau`, `PlayerData.luau` | 갇힘·경보 중 광산 안 퇴장 → 가방 절반 |
| 출석·퀘스트 코인 | `Bag.luau` | `DailyLoginClaimed`·`QuestCompleted`의 `reward.coins` 지급 |

## A 담당께: 채굴 → 가방 연결

`src/server/Mining/MiningServer.server.luau`에서 광석이 깨질 때(`hp <= 0`) 두 가지만 바꾸면 된다.

1. 코인 직접 지급 줄을 지운다. 지우지 않으면 캘 때 한 번, 팔 때 또 한 번 코인이 들어간다.
   ```lua
   plr.leaderstats.Coins.Value += ore:GetAttribute("OreValue") or 0
   ```
2. 대신 `OreMined`를 쏜다.
   ```lua
   EventBus.Fire(Events.OreMined, plr, ore:GetAttribute("Ore") or ore.Name, weight, pressure)
   ```
   - `oreId`: `Mines.luau` 광물표의 `name` (예: `"Coal"`). 표에 없는 이름이면 B가 경고만 찍고 담지 않는다.
   - `weight`: **무게 배수**. 1이 보통이고 판매가에 그대로 곱해진다. 예: `rng:NextNumber(0.8, 1.5)` (범위는 A가 정함, 임시값).
   - `pressure`: `"Low"`(상압) / `"High"`(고압) / `"Extreme"`(초고압). 기획서 기준 깊이와 붕괴까지 남은 시간(`Collapse.GetRemainingTime(mineId)`)으로 A가 정한다. 배수는 B가 `Config/Economy.luau`의 `PRESSURE_MULT`로 곱한다 (1 / 1.5 / 3).

로컬 복사본의 광산이 예전 광물(`Zinc` 등)로 되어 있으면 표에 없는 이름이라 안 담긴다. 팀 플레이스는 현재 광물표대로라 상관없다.

## C 담당께

- 판매가 배수 `GetMultiplier(player, "SellPrice")`, 가방 확장 `HasPass(player, "BigBag")`를 B가 읽는다. 게임 중에 BigBag을 사면 다음 광물을 담을 때부터 칸이 늘어난다.
- `OreBagged`의 값은 판매 배수를 곱하기 전, `OreSold`의 판매액은 곱한 뒤다.
- 부탁 (PR #18): 경보 중 광산에서 죽고 허브에서 부활한 뒤 붕괴 전에 나가면 지금은 차감이 안 된다. 나갈 때 `diedInside`면 `PlayerTrapped`를 쏴 주면 B는 고칠 게 없다.

## 아직 안 된 것 (B 다음 작업 순서)

1. 곡괭이 제작·강화: 비용 차감, `data.pickaxe` 갱신, `PickaxeUpgraded` 발사. 제작소 `Workshop/Counter`.
2. 코인을 `data.coins`로 직접 관리: A가 코인 직접 지급을 지우면 `PlayerData.luau`의 leaderstats 연결(ponytail 주석)을 걷어낸다.
3. 낱개 판매·"팔까 말까"(에픽 이상은 제작 재료): 제작이 생기면.
4. 광산 카나리아, 리버스.

## 로컬 테스트 방법

1. 로컬 복사본 플레이스를 열고 `tools/create_social_remotes.luau`를 한 번 실행한다. `Remotes`가 없으면 C의 Collapse·Payments가 멈추고, 그걸 쓰는 B도 같이 멈춘다.
2. `rojo serve` → Rojo 플러그인 Connect → Play.
3. 서버 쪽에 임시 Script를 넣고 `EventBus.Fire(Events.OreMined, player, "Coal", 1, "Low")`처럼 쏘면 A 없이 가방을 시험할 수 있다. 판매는 `require(Server.Economy.Bag).sellAll(player)`.
