# 로블록스 아바타·플랫폼 정리 (공식 문서 요약)

> 2026-10-31에 공식 문서를 읽고 우리 게임에 쓸 부분 위주로 정리. 숫자·규칙은 바뀔 수 있으니 실제로 쓸 때는 링크 원문을 다시 확인.
> 원문: [아바타 개요](https://create.roblox.com/docs/ko-kr/avatar) · [플랫폼 개요](https://create.roblox.com/docs/en-us/platform)

## 1. 아바타 = "누구인지" + "무엇을 입는지"

| 축 | 레이어 | Studio 객체 |
|---|---|---|
| 누구인지 (몸) | 형태: 메시 바디 파트 15개 | `MeshPart` (Model 아래) |
| | 리깅: 관절. R15 표준 15개, 고급 리그는 뼈대 최대 37개 추가 | `Bone` |
| | 애니메이션: 이모트(전신), 얼굴 표정(FACS) | `Animation`, `FaceControls` |
| | 부착 지점·케이지: 액세서리 붙는 자리, 옷이 맞춰지는 바깥 경계 | `Attachment`, `WrapTarget` |
| 무엇을 입는지 | 화장: 얼굴 2D | `Decal` |
| | 단단한 액세서리: 모자·무기·소품, 부착 지점에 그대로 붙음 | `Accessory` |
| | 레이어드 액세서리: 재킷·셔츠, 몸에 늘어나 맞음 | `Accessory` + `WrapLayer` |
| | 클래식 의상: 2D 이미지 옷 | `Shirt`, `Pants`, `ShirtGraphic` |

## 2. 몸 사양 (커스텀 캐릭터·NPC 만들 때)

- 바디 파트 15개 이름: `Head_Geo`, `UpperTorso_Geo`, `LowerTorso_Geo`, `Left/RightUpperArm_Geo`, `Left/RightLowerArm_Geo`, `Left/RightHand_Geo`, `Left/RightUpperLeg_Geo`, `Left/RightLowerLeg_Geo`, `Left/RightFoot_Geo`
- 모델링: +Z 앞, +Y 위, 피벗 0,0,0, 변환 고정, I/A/T 포즈. 구멍·뒷면 없게, 사지 끝은 막아서(캡)
- 크기 (전체, 스터드): 최소 1.35 × 3.6 × 0.7 / 최대 보통 8.6 × 9.5 × 2.25 (슬렌더 6 × 9.5 × 2, 클래식 8 × 9.1 × 2)
- 삼각형 예산: 머리 4,000 · 몸통 1,750 · 팔다리 각 1,248 · 합계 10,742. 텍스처 최대 2048²
- 리그 계층: Root > HumanoidRootNode > LowerTorso > UpperTorso > Head·팔 / LowerTorso > 다리. 정점당 뼈 최대 4개
- 부착 지점 이름 (`_Att` 접미사여야 자동 인식)
  - Head: `FaceCenter_Att`, `FaceFront_Att`, `Hat_Att`, `Hair_Att`
  - UpperTorso: `Neck_Att`, `LeftCollar_Att`, `RightCollar_Att`, `BodyBack_Att`, `BodyFront_Att`
  - LowerTorso: `Root_Att`, `WaistFront_Att`, `WaistBack_Att`, `WaistCenter_Att`
  - 팔·손·발: `Left/RightShoulder_Att`, `Left/RightGrip_Att`, `Left/RightFoot_Att`
- 케이지: 몸은 바깥 케이지(`<파트>_OuterCage`)만, 레이어드 옷은 안·바깥 둘 다. 로블록스 템플릿 케이지를 쓰고 정점·UV는 건드리지 않음

## 3. Avatar Setup 도구 (Studio → 아바타 탭)

블렌더·마야에서 만든 메시(.fbx / .obj / .gltf)를 넣으면 **리그·스킨·얼굴 표정 데이터·케이지·15파트 분할·부착 지점**을 자동으로 만들어 준다.
- 프리셋: **Development Avatar** = 게임 안 NPC·시작 캐릭터용 (느슨함, 내 인벤토리로) / **Platform Avatar** = 마켓 판매용 (엄격, 수수료·심사)
- 순서: 가져오기("Upload to Roblox" 끔) → 모델 선택 → 아바타 탭 Avatar Setup → 종류(몸/레이어드/단단한) 지정 → 실행(몇 분) → 걷기·점프·이모트·옷 맞춤 테스트 → 저장
- 주의: 앞 방향 자동 인식이 틀리면 수동 정렬. TextureID보다 SurfaceAppearance. 큰 수정은 다시 블렌더에서. 가져온 메시는 심사 대기가 있을 수 있음

## 4. 게임 안에서 캐릭터 모습 바꾸기

- 장소 전체: Studio **File > Avatar Settings** (옷·액세서리·몸·충돌·애니메이션을 모든 플레이어에게)
- 한 명씩: `HumanoidDescription`
  - 얻기: `Humanoid:GetAppliedDescription()` (지금 모습에서 시작하는 게 안전), `Players:GetHumanoidDescriptionFromUserId()`, `Instance.new`
  - 고치기: `HatAccessory`, `Face`, `HeadColor` 같은 속성, 여러 개는 `SetAccessories()`
  - 적용: `Humanoid:ApplyDescription()`, 스폰할 때는 `Player:LoadCharacterWithHumanoidDescription()` (이때 `Players.CharacterAutoLoads = false`)
  - 조심: 에셋을 직접 바꾸면서 동시에 Description을 적용하면 동작이 꼬일 수 있음. R6에는 몸 크기 값이 안 먹음
- 커스텀 리그(R15 아님)에 레이어드 옷: 몸에 `WrapTarget`, 옷에 `WrapLayer`, 휴머노이드가 없으면 옷에 `Weld`. 커스텀 케이지는 게임 안 전용 (마켓 판매 불가)

## 5. 돈 버는 방법과 수익률

| 방법 | 내용 | 몫 |
|---|---|---|
| [개발자 상품](https://create.roblox.com/docs/en-us/production/monetization/developer-products) | 게임 화폐·부스트·꾸미기를 여러 번 판매. 가장 큰 수입원 | 게임 안 로벅스 판매의 70% |
| 게임패스 | 한 번 사면 영구 | 70% |
| [구독](https://create.roblox.com/docs/en-us/production/monetization/subscriptions) | 매달 혜택 (로벅스 또는 현금) | — |
| [유료 입장](https://create.roblox.com/docs/en-us/production/monetization/paid-access-robux) | 입장료. 팬층이 있을 때 | 현금 판매는 최대 90% |
| [광고](https://create.roblox.com/docs/en-us/production/promotion/advertise) | 게임 안 광고, [보상형 동영상](https://create.roblox.com/docs/en-us/production/promotion/rewarded-video-ads), 빌보드 | — |
| [아바타 아이템](https://create.roblox.com/docs/en-us/marketplace/publish-to-marketplace) | 게임 안이나 마켓에서 액세서리·애니메이션 판매 | 마켓 판매의 30% |
| [크리에이터 리워드](https://create.roblox.com/docs/en-us/creator-rewards) | 플랫폼에 사람을 데려온 만큼 지급 | — |

- 현금 인출(DevEx): 만 13세 이상, 번 로벅스 30,000 이상. 예) 10,000 로벅스 ≈ 38달러
- 모든 수익은 커뮤니티 규칙을 지켜야 받음

## 6. 플랫폼 전체 지도 (더 볼 곳)

- 엔진 API: https://create.roblox.com/docs/en-us/reference/engine · 만들기 가이드: https://create.roblox.com/docs/en-us/creation
- 에셋·게시: https://create.roblox.com/docs/en-us/assets · https://create.roblox.com/docs/en-us/projects/assets · 크리에이터 스토어 https://create.roblox.com/store
- 외부 툴 가져오기(블렌더 등): https://create.roblox.com/docs/en-us/art/overview-dcc
- 오픈 클라우드(웹 API): https://create.roblox.com/docs/en-us/cloud
- 확장(모바일·콘솔·VR·다국어): https://create.roblox.com/docs/en-us/scale
- 3D 아트 자료: https://create.roblox.com/docs/en-us/art · 아바타 참조 파일·마네킹·템플릿: https://create.roblox.com/docs/ko-kr/avatar/resources

## 7. 붕괴 광산에 쓸 만한 것 (아이디어, 결정 아님)

- **광부 NPC** (튜토리얼·판매소 주인): 블렌더 모델 → Avatar Setup **Development Avatar** → 걷기·손짓 애니메이션. 지금 허브 건물을 블렌더로 만드는 흐름(`tools/blender/`)과 같은 길
- **곡괭이를 등에 메기**: 들고 있지 않을 때 곡괭이 모델을 `BodyBackAttachment`에 단단한 액세서리처럼 붙이면 단계별 곡괭이 모델(T-003)이 눈에 보임
- **광부 헬멧·헤드랜턴**: `Hat_Att`에 붙는 단단한 액세서리. 카나리아 Lv2 헤드랜턴(D-045)과 광산 조명 안건에 연결
- **리버스·랭킹 보상 꾸미기**: `HumanoidDescription`으로 게임 안 전용 모자·옷을 입혀 줌 (마켓 판매 없이도 가능)
- **수익**: 기획서의 게임패스·부스트(개발자 상품)가 공식 문서상 가장 큰 수입원. 보상형 동영상 광고(예: 보고 나면 붕괴 때 가방 보호)도 후보
