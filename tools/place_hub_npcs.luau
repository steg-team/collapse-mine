--[[
	허브 건물 NPC 자리표 놓기 (Studio 명령창에서 실행)

	건물마다 NPC가 설 자리(발바닥 위치·방향)에 투명 파트(태그 "HubNpc")를 놓고, 입힐 마켓 아이템을 속성으로 적는다.
	실제 캐릭터는 게임이 시작될 때 서버(src/server/Mining/HubNpcs.server.luau)가 만든다.
	(편집 모드에서 만들면 다이나믹 헤드·레이어드 옷이 제자리에 안 붙음. Homestore 마네킹과 같은 방식)

	판매소 = 상인, 제작소 = 대장장이, 랭킹판 = 기록관, 창고 = 창고지기
	아이템은 AvatarEditorService:SearchCatalogAsync로 골랐다 (Roblox 공식 아이템 우선). 바꾸려면 ROLES의 id만 고치고 다시 실행.
	HUBS에 있는 허브마다, 그 허브에 있는 건물만. 다시 실행하면 Hub/Npcs를 지우고 새로 놓는다.
]]

local HUBS = { "CollapseMine", "CollapseMine_iron", "CollapseMine_groundwater", "CollapseMine_lava" }
local SCALE = 1.1 -- 계산대가 플레이어 키에 맞춰져 있어 조금 크게

local BODY_ANDI = 993 -- 기본 신체 - 앤디 (다이나믹 헤드)
local BODY_RILEY = 979 -- 기본 신체 - 라일리

-- items: 레이어드 옷은 적힌 순서대로 안쪽 → 바깥
-- offset = 건물 피벗 기준 (오른쪽, 앞) 스터드, face = 바라볼 방향(건물 앞 기준 회전 도)
local ROLES = {
	Shop = {
		title = "상인", body = BODY_ANDI, skin = Color3.fromRGB(234, 184, 146), shoes = 883, -- 워크 부츠 - 브라운
		items = {
			100202592246873, -- 브라운 숏 레이어드 헤어
			120922875129314, -- 페도라
			103395143072346, -- 갈색 콧수염
			91010650782683, -- 흰 셔츠
			104077780789306, -- 조끼
			6984740059, -- 카고 팬츠 - 브라운 (Roblox)
		},
		offset = Vector2.new(0, -2.6), face = 0,
	},
	Workshop = {
		title = "대장장이", body = BODY_ANDI, skin = Color3.fromRGB(176, 120, 88), shoes = 916, -- 워크 부츠 - 블랙
		items = {
			134025304816175, -- 수염
			14231095072, -- 흰 셔츠
			15187613775, -- 가죽 앞치마
			17115605141, -- 초록 카고 바지
		},
		offset = Vector2.new(0, -2.6), face = 0,
	},
	Leaderboard = {
		title = "기록관", body = BODY_ANDI, skin = Color3.fromRGB(245, 205, 172), shoes = 916,
		items = {
			104862792167614, -- 회색 머리
			835066603, -- 실크해트 (Roblox)
			109182070877540, -- 골드 모노클
			14231095072, -- 흰 셔츠(검은 넥타이)
			78044555785600, -- 갈색 정장 재킷
			6984740059, -- 바지
		},
		offset = Vector2.new(-11, 5), face = -35,
	},
	Storage = {
		title = "창고지기", body = BODY_RILEY, skin = Color3.fromRGB(204, 142, 105), shoes = 882, -- 워크 부츠 - 탠
		items = {
			1609609, -- 광부 헬멧 (Roblox)
			91010650782683, -- 흰 셔츠
			14617453289, -- 오렌지 형광 조끼
			127189956586914, -- 데님 작업복
		},
		offset = Vector2.new(-4.5, 3.5), face = 20,
	},
}

local CS = game:GetService("CollectionService")
local CHS = game:GetService("ChangeHistoryService")

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.RespectCanCollide = false

local rec = CHS:TryBeginRecording("PlaceHubNpcMarkers")
local count = 0
for _, hubName in HUBS do
	local root = workspace:FindFirstChild(hubName)
	local hub = root and root:FindFirstChild("Hub")
	if not hub then continue end
	local old = hub:FindFirstChild("Npcs")
	if old then old:Destroy() end
	local folder = Instance.new("Folder")
	folder.Name = "Npcs"
	folder.Parent = hub
	for bName, role in ROLES do
		local b = hub:FindFirstChild(bName)
		if not b then continue end
		local pv = (b :: Model):GetPivot()
		local fwd = Vector3.new(pv.LookVector.X, 0, pv.LookVector.Z).Unit
		local right = Vector3.new(-fwd.Z, 0, fwd.X)
		local spot = pv.Position + right * role.offset.X + fwd * role.offset.Y
		-- 바닥: 건물 바닥 바로 위에서 쏘고(지붕·차양 피함), 투명 판정 파트(Counter 등)는 건너뜀
		local ignore = { folder }
		local hit
		for _ = 1, 6 do
			params.FilterDescendantsInstances = ignore
			hit = workspace:Raycast(Vector3.new(spot.X, pv.Position.Y + 3, spot.Z), Vector3.new(0, -20, 0), params)
			if hit and hit.Instance:IsA("BasePart") and hit.Instance.Transparency >= 0.95 then
				table.insert(ignore, hit.Instance)
			else
				break
			end
		end
		local groundY = hit and hit.Position.Y or pv.Position.Y
		-- 계산대 뒤(건물 안)는 바닥 메시가 레이에 안 잡힐 때가 있어 건물 바닥 높이(피벗 - 1.2) 밑으로는 안 내려가게
		if role.offset.Y < 0 then groundY = math.max(groundY, pv.Position.Y - 1.2) end

		local ids = {}
		for _, id in role.items do table.insert(ids, tostring(id)) end
		local marker = Instance.new("Part")
		marker.Name = "Npc_" .. role.title
		marker.Size = Vector3.new(2, 0.2, 2)
		-- 파트 앞(-Z)이 NPC가 바라보는 방향
		marker.CFrame = CFrame.lookAt(Vector3.new(spot.X, groundY, spot.Z), Vector3.new(spot.X, groundY, spot.Z) + fwd)
			* CFrame.Angles(0, math.rad(role.face), 0)
		marker.Anchored, marker.CanCollide, marker.CanQuery, marker.CanTouch = true, false, false, false
		marker.Transparency = 1
		marker:SetAttribute("Title", role.title)
		marker:SetAttribute("Body", role.body)
		marker:SetAttribute("Shoes", role.shoes)
		marker:SetAttribute("Items", table.concat(ids, ","))
		marker:SetAttribute("Skin", role.skin)
		marker:SetAttribute("Scale", SCALE)
		CS:AddTag(marker, "HubNpc")
		marker.Parent = folder
		count += 1
	end
end
if rec then CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
print(("[HubNpcs] 자리표 %d개 (Play 하면 서버가 NPC를 세움)"):format(count))
