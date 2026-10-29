# 붕괴 광산 (Collapse Mine)

로블록스 채굴 게임. 코드는 **Rojo + Git**, 맵은 **Studio 팀 크리에이트**로 관리합니다.

- 방향: [`docs/direction.md`](docs/direction.md) · 기획서: [`docs/game-design.md`](docs/game-design.md) · 결정 기록: [`docs/README.md`](docs/README.md) (팀 T- / 담당별 A-·B-·C- / 예전 D-)
- AI 에이전트 규칙: [`AGENTS.md`](AGENTS.md), [`CLAUDE.md`](CLAUDE.md)

## 폴더 구조

```
src/
  server/   → ServerScriptService.Server
    Core/       공통 기반 코드 (0단계)
    Mining/     채굴 코어 (A)
    Economy/    경제·성장 (B)
    Social/     소셜·이벤트 (C)
  client/   → StarterPlayer.StarterPlayerScripts.Client
    Mining/ Economy/ Social/
  shared/   → ReplicatedStorage.Shared
    Events.luau  기능 간 이벤트 계약
```

- `*.server.luau` = Script, `*.client.luau` = LocalScript, 그 외 `.luau` = ModuleScript
- 맵(지형, 허브, 광석, 방), 곡괭이 모델, `ReplicatedStorage.Remotes`는 Rojo가 건드리지 않습니다. 팀 크리에이트에서 직접 수정하세요.

## 처음 한 번 설정 (Windows)

1. **Rokit 설치** (Rojo 버전 관리 도구)
   PowerShell에서:
   ```powershell
   Invoke-RestMethod https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.ps1 | Invoke-Expression
   ```
2. **레포 받기 + 도구 설치**
   ```powershell
   git clone https://github.com/steg-team/collapse-mine.git
   cd collapse-mine
   rokit install
   ```
3. **Studio 플러그인 설치**
   ```powershell
   rojo plugin install
   ```
4. VS Code를 쓰면 확장 **Rojo**, **Luau Language Server** 설치 추천

## 작업 흐름

1. `main`에서 새 브랜치 만들기: `git checkout -b feat/기능이름`
2. `rojo serve` 실행 → Studio 상단 **Rojo** 플러그인에서 **Connect**
3. VS Code에서 코드 수정 → 저장하면 Studio에 바로 반영
4. 커밋 → push → GitHub에서 PR → 올린 사람이 직접 `main`에 머지 (다른 담당에 영향이 있으면 PR에 멘션)

### 주의

- **같은 플레이스에 두 사람이 동시에 `rojo serve`로 연결하지 마세요.** 서로 코드를 덮어씁니다.
  코드 테스트는 각자 로컬 복사본 플레이스(파일 → 다른 이름으로 저장)에서 하고,
  팀 크리에이트 플레이스에는 머지된 `main`만 연결해서 반영합니다.
- 확률, 판매가, 결제 검증은 **서버 코드에서만** 처리합니다.
- 이벤트를 추가·변경할 때는 `src/shared/Events.luau`를 고치고 관련 담당자 모두에게 PR 멘션으로 알립니다.

## 담당

| 담당 | 기능 | 폴더 |
|---|---|---|
| A | 플레이어 + 광산 + 채굴 | `Mining/` |
| B | 경제 | `Economy/` |
| C | 이벤트·서비스 | `Social/` |


## tools/ (Studio에서 직접 실행하는 스크립트)

Rojo로 동기화되지 않습니다. Studio **보기 → 명령창**에 내용을 붙여넣어 실행하세요. 실행 전 Ctrl+S 권장, Ctrl+Z로 되돌릴 수 있습니다.

| 파일 | 하는 일 |
|---|---|
| `generate_mine.luau` | `src/shared/Config/Mines.luau`의 광산 설정 하나를 읽어 개미굴 광산을 지정 위치에 생성. 맨 위 `MINE_ID`만 바꿔서 실행 |
| `build_hub_cliffs.luau` | 시작 지점(허브)을 둘러싼 절벽 링 + 절벽 위 보이지 않는 경계벽 (낙사 방지). 입구보다 먼저 실행 |
| `build_hub_buildings.luau` | 허브 건물 3개: 판매소(차양·저울), 제작소(대장간·굴뚝), 랭킹판(3칸 게시판·트로피). 기존 건물은 `ServerStorage.OldHubBuildingsBackup`으로 옮김 |
| `blender/build_workshop.py` | (블렌더) 제작소 외형을 만들어 `~/Downloads/CollapseMine/Workshop.fbx`로 내보냄. 재질별로 합쳐 `WS_<재질>` 이름으로 남김 |
| `blender/build_shop.py`, `blender/build_leaderboard.py` | (블렌더) 판매소·랭킹판 외형. 공통 도우미는 `blender/rbx_common.py` |
| `blender/build_entrance_props.py` + `import_entrance_props.luau` | 광산 입구 장식(화로·갱도 문틀·레일·광차·벽 횃불·간판 테두리)을 블렌더 메시로 교체. 간판 글자·이동 판정·불은 Roblox 파트 유지 |
| `import_hub_mesh.luau` | 가져온 FBX 건물을 허브 자리에 끼우고 Roblox 재질을 입힘. 계산대·간판·불 같은 기능 부품은 옛 모델에서 옮겨 옴 |
| `build_cave_entrance.luau` | 허브 절벽 자리에 광산 입구 산(봉우리 최고 약 220, 눈 덮인 정상)과 거대한 동굴 입구(앞 46×56 → 안쪽 26×22 깔때기)를 만들고 화로·사슬 표지판·갱도 문틀·레일·광차·등불 배치, 안쪽에 이동 판정. `MINE_ID`, `MOUTH`, `FACING`, `THEME`(basic/lava), `PEAK`를 바꿔 광산마다 실행 |
| `build_pickaxe_model.luau` | `StarterPack.Pickaxe` 모델과 `ReplicatedStorage.Remotes.MineHit` 생성 |

### 새 광산 추가 순서

1. `src/shared/Config/Mines.luau`에 항목 추가 (위치는 다른 광산·허브와 겹치지 않게) → PR
2. Rojo로 Studio에 반영된 상태에서 `tools/generate_mine.luau`의 `MINE_ID`를 바꿔 실행
3. `tools/build_cave_entrance.luau`로 허브 절벽 벽에 동굴 입구 배치 (다른 입구와 겹치지 않게 위치·방향 지정)
4. `docs/game-design.md` 광산 구성 표 갱신
