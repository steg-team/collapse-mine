# 자연 바닥·풀·바위 룩 — 로블록스 Laser Tag 템플릿에서 배운 것

로블록스 공식 **Laser Tag 템플릿**의 바닥·풀·바위가 예뻐서(2026-10-31) 어떻게 만든 건지 뜯어보고, 우리 허브에 옮기는 도구를 만들었다: [`apply_nature_look.luau`](apply_nature_look.luau).
에셋은 전부 로블록스 공식 템플릿 것이라 다른 플레이스에서도 id로 불러 쓸 수 있다.

## 핵심: 지형은 평범한 재질 + MaterialService 덮어쓰기

지형 칸 자체는 그냥 `Grass`·`Ground`·`Sand` 같은 기본 재질이다. **MaterialService가 그 재질을 사진 텍스처로 통째로 덮어써서**(`SetBaseMaterialOverride`) 진짜 같은 땅이 된다. 지형 재질 색은 전부 흰색(1,1,1)이라 텍스처 색이 그대로 보인다.

| 지형 재질 | → 텍스처 재질 (MaterialVariant) | 보이는 모습 | Color / Normal / Roughness / Metalness |
|---|---|---|---|
| Grass | MossGrass | 이끼 낀 풀밭 | 13703366674 / 13316888753 / 13316888800 / 13280829022 |
| Ground | Moss | 이끼 흙 | (MossGrass와 같은 텍스처) |
| LeafyGrass | MossStones | 이끼 낀 돌바닥 | 13703391879 / 13326201011 / 13326200502 / 13326199923 |
| Sand | Stones | 자갈 | 13326348142 / 13326227645 / 13326227505 / 13326226958 |
| Salt | StrataNoisy | 결이 보이는 암벽 | 13413097425 / 13413097894 / 13413097878 / — |
| Snow | Walkway | 다져진 길 | 13742044281 / 13742043635 / 13742042805 / 13701714303 |

전부 `StudsPerTile = 10`. 건물 바닥은 지형이 아니라 파트에 `MaterialVariant = "MetalPanels"`·콘크리트 텍스처를 입힘.

## 바위와 풀은 SurfaceAppearance 메시

| 이름 | Mesh | SurfaceAppearance Color / Normal / Roughness | 템플릿 크기·배치 |
|---|---|---|---|
| RockSmall | 13491576237 | 13610891836 / 13610891373 / 13610891043 | 24×11×16 기준, 15~40 폭으로 키워 땅에 반쯤 묻음 |
| RockLarge | 13537671238 | 13610824138 / 13610823377 / 13610822782 | 6×15×5 기준, 50 높이까지 키워 절벽처럼 |
| Fern_A | 13676363152 | 13762934712 / 13674996849 / 13674996487 (풀 셋 공용) | 고사리, 충돌 끔 |
| Fern_C | 13676689934 | 〃 | 낮은 고사리 |
| Hostas_A | 13681432221 | 〃 | 작은 잎 덤불, 가장 많이 깔림 |

- 파트 색은 흰색에 가깝게(0.97). 바위는 Anchored·충돌 켬, 풀은 충돌 끔.
- 템플릿에는 바위 69개, 풀 113개가 손으로 배치돼 있다. 우리는 레이캐스트로 흩뿌린다.
- 먼지 입자: 텍스처 14302399641, Rate 150 (분위기용, 아직 안 옮김).

## 조명 (템플릿 값)

- Atmosphere: Density 0.285, Offset 0.65, Color (0.78, 0.78, 0.78), Decay (0.88, 1, 1), Glare 0.3, Haze 2
- ColorCorrection: Contrast 0.08
- Bloom: Intensity 1.5, Size 56, Threshold 2
- Lighting: Brightness 3, ClockTime 8.7, OutdoorAmbient (98, 107, 77), Ambient (32, 42, 44)

## 우리 플레이스에 옮길 때 주의

- **덮어쓰기는 장소 전체에 걸린다.** 광산 벽에 쓰는 `Ground`(흙층)·`Slate`·`Basalt`·`Limestone`·`Rock`, 입구 봉우리 `Snow`를 덮어쓰면 광산 안과 산까지 바뀐다.
- 그래서 도구는 광산에 안 쓰는 재질을 허브 전용으로 쓴다: 허브 마당 흙을 `Ground` → `Mud`로 다시 칠하고 `Mud`를 Moss로 덮어쓴다. `Grass`는 허브 절벽 위·광산 지표에만 있어서 MossGrass로 덮어써도 된다.
- 암벽(StrataNoisy)을 허브 절벽에 쓰고 싶으면 절벽을 `Rock` → `Salt`로 다시 칠해야 한다 (Rock은 지하수 광산 아래층에도 씀).
