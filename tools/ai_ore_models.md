# 1~4스테이지 광물 모델 — Roblox AI 생성 버전 (현재 사용 중)

광물 틀: `ServerStorage.OreModels.Stage01~04.<키>` (속성 `DisplayName`, `Grade`, `Source=RobloxAI`, 투명 `Hitbox`가 PrimaryPart, 피벗은 바닥 가운데).
이전 버전(앞·옆 그림 버전)은 `ServerStorage.OreModels._Backup_TurnVersion`, 직접 모델링 버전은 `Stage01M~03M`.

## 만든 방법
1. Studio MCP `generate_mesh` (Roblox AI)로 모양 생성. 프롬프트 끝에 `stylized game asset`.
   한 번에 여러 개를 동시에 보내면 `Too Many Requests`로 실패하니 1~2개씩.
2. `generate_texture` (Quality, 실패하면 Fast)로 색을 다시 칠함. 프롬프트에 색을 강하게 적어야 함
   (예: 공작석 "entirely GREEN", 자철석 "opaque jet-BLACK").
3. 등불은 유리가 불투명하게 칠해져서 유리 자리에 반투명 주황 Neon 구(`GlassGlow`) + PointLight를 넣음.
4. 견본(`Workspace.AIOrePreview`)을 광물 틀로 복사하며 Hitbox·등급 연출(희귀 반짝임, 에픽 조명, 전설 오라+외곽선) 추가.

다시 칠한 텍스처는 생성 에셋에 들어 있지 않고 광물 틀의 SurfaceAppearance/TextureID에만 있다.
그래서 **원본은 플레이스의 광물 틀**이고, 아래 에셋 id는 "칠하기 전 모양"을 다시 꺼낼 때만 쓴다.

| 키 | 이름 | 등급 | 모양 에셋 id |
|---|---|---|---|
| Coal | 석탄 | 일반 | 80840917824598 |
| Copper | 구리 | 일반 | 109312191048927 |
| Quartz | 석영 | 고급 | 78746714763451 |
| Amber | 호박석 | 희귀 | 124870946138731 |
| CavePearl | 동굴 진주 | 에픽 | 109411104895172 |
| Lantern | 광부의 녹슨 등불 | 전설 | (동기 생성, id 없음) |
| Iron | 철 | 일반 | 134885044087222 |
| Tin | 주석 | 일반 | 75890014537576 |
| Silver | 은 | 고급 | 122659488678848 |
| Magnetite | 자철석 | 희귀 | 107376447912481 |
| Platinum | 백금 | 에픽 | 138004123460381 |
| PocketWatch | 감독관의 회중시계 | 전설 | 114962629222929 |
| Limestone | 석회석 | 일반 | 84419075936070 |
| Calcite | 방해석 | 일반 | 139972153322503 |
| Azurite | 남동석 | 고급 | 117668230817850 |
| Malachite | 공작석 | 희귀 | 89097661406032 (세로 2배로 늘림) |
| WaterPearl | 물빛 진주 | 에픽 | 82088913381295 |
| WetMap | 젖은 광산 지도 | 전설 | 95299314794229 |
| LavaStone | 용암석 | 일반 | 98846309308692 |
| Sulfur | 유황 | 일반 | 112802065087044 |
| Obsidian | 흑요석 | 고급 | 121745688438230 |
| Uranium | 우라늄 | 희귀 | 122745790330329 (가로 1.9배로 넓힘) |
| FireRuby | 화염 루비 | 에픽 | 107506822113236 |
| MeltedHelmet | 녹은 광부 헬멧 | 전설 | 120285491531323 |

4스테이지(Stage04)는 `tools/import_lava_ores.luau`로 틀을 만든다 (견본 `Workspace.AIOrePreview04`).

## 남은 일 (A 담당, 레포에서 PR)
- 광산 생성기(`tools/generate_mine.luau`)가 Part 광석 대신 이 틀을 복사해 벽에 박도록.
- 채굴 판정(`src/server/Mining/MiningServer.server.luau`)이 모델 광석의 `Hitbox`를 맞았을 때 캐지도록.
