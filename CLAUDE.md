# CLAUDE.md

이 레포의 공통 규칙은 `AGENTS.md`에 있습니다. 반드시 먼저 따르세요.

@AGENTS.md

## Claude 전용 메모

### 시작할 때
- 기능 작업 전에 `docs/direction.md`, `docs/decisions-team.md`, 자기 담당 `docs/decisions-<담당>.md`를 읽습니다. 예전 결정은 `docs/decisions.md`, 세부 기획은 `docs/game-design.md`.
- 새 결정은 사용자 담당 파일(또는 회의 결정이면 `decisions-team.md`)에만 씁니다. 다른 담당 결정 파일은 고치지 않습니다.

### 응답
- 사용자와는 한국어로 대화합니다.
- 결정이 필요한 갈림길에서만 묻고, 나머지는 합리적인 기본값으로 진행한 뒤 무엇을 골랐는지 한 줄로 알립니다.

### Roblox Studio MCP로 작업할 때
- 코드 변경은 **레포 파일을 고치는 것이 기본**입니다. Studio에 직접 스크립트를 넣었다면 같은 내용을 `src/`에도 반영하고 커밋합니다.
- 맵·모델 생성처럼 Studio에서만 할 수 있는 작업은 실행한 코드를 `tools/`에 스크립트로 남깁니다 (팀원이 재실행할 수 있게).
- `execute_luau` 전에 `get_studio_state`로 모드를 확인합니다. Play 중이면 Edit 데이터모델을 쓸 수 없습니다. 사용자가 테스트 중일 수 있으니 멈추기 전에 알립니다.
- 변경은 `ChangeHistoryService:TryBeginRecording` / `FinishRecording`으로 감싸 Ctrl+Z로 되돌릴 수 있게 합니다.
- 큰 루프나 대량 생성은 청크마다 `task.wait()`. 한 번에 큰 서브트리를 `Parent`에 붙이지 않습니다.
- 지우기 전에 백업합니다 (`ServerStorage`로 이동). 사용자 확인 없이 맵을 통째로 삭제하지 않습니다.
- 결과 확인은 `screen_capture`로 합니다. **`camera_position` 인자는 화면이 엉뚱하게 찍히는 경우가 있으니**, `execute_luau`로 `workspace.CurrentCamera.CFrame`을 먼저 옮긴 뒤 인자 없이 찍습니다.
- 지하·넓은 맵은 화면으로 잘 안 보이고 렌더 거리 제한도 있으니, 좌표를 뽑아 평면도로 그리거나(방·램프 위치) 레이캐스트·`ReadVoxels`로 확인합니다. `ReadVoxels`는 칸 경계에 맞춘 영역(4스터드 격자)으로 읽어야 정확합니다.
- 플레이 중 `HumanoidRootPart.CFrame`을 바꾸는 테스트는 출구 발판 같은 Touched 판정을 건드릴 수 있으니 위치를 잘 고릅니다.
- 작업 후 사용자에게 Ctrl+S 저장을 안내합니다.

### Git
- 작업 브랜치에서 커밋하고 push합니다. `main`에 직접 push하지 않습니다.
- PR 설명에는 무엇을 왜 바꿨는지, Studio에서 따로 해야 할 일(맵 재생성, 모델 교체 등)이 있으면 그것도 적습니다.
