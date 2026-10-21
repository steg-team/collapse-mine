# 붕괴 광산 (Collapse Mine)

로블록스 채굴 게임. 코드는 **Rojo + Git**, 맵은 **Studio 팀 크리에이트**로 관리합니다.

## 폴더 구조

```
src/
  server/   → ServerScriptService.Server
    Core/       공용 기반 코드 (B)
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
4. 커밋 → push → GitHub에서 PR → 다른 담당자 리뷰 후 `main`에 머지

### 주의

- **같은 플레이스에 두 사람이 동시에 `rojo serve`로 연결하지 마세요.** 서로 코드를 덮어씁니다.
  코드 테스트는 각자 로컬 복사본 플레이스(파일 → 다른 이름으로 저장)에서 하고,
  팀 크리에이트 플레이스에는 머지된 `main`만 연결해서 반영합니다.
- 확률, 판매가, 결제 검증은 **서버 코드에서만** 처리합니다.
- 이벤트를 추가·변경할 때는 `src/shared/Events.luau`를 고치고 관련 담당자 모두 리뷰합니다.

## 담당

| 담당 | 기능 | 폴더 |
|---|---|---|
| A | 채굴 코어 | `Mining/` |
| B | 경제·성장 | `Economy/`, `Core/`, `shared/` |
| C | 소셜·이벤트 | `Social/` |

폴더별 리뷰어는 `.github/CODEOWNERS`에서 지정합니다.

## tools/ (Studio에서 직접 실행하는 스크립트)

Rojo로 동기화되지 않습니다. Studio **보기 → 명령창**에 내용을 붙여넣어 실행하세요. 실행 전 Ctrl+S 권장, Ctrl+Z로 되돌릴 수 있습니다.

| 파일 | 하는 일 |
|---|---|
| `generate_ant_cave.luau` | 개미굴 동굴 맵(입구, 허브 방, 나선 대각선 굴 5갈래, 옆방·끝방, 광석, 방 구역, 램프) 생성. `SEED`만 바꾸면 다른 모양 |
| `build_pickaxe_model.luau` | `StarterPack.Pickaxe` 모델과 `ReplicatedStorage.Remotes.MineHit` 생성 |
