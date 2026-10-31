--[[
	허브 건물마다 NPC 한 명씩 (Studio 명령창에서 실행)
	판매소 = 상인, 제작소 = 대장장이, 랭킹판 = 기록관, 창고 = 창고지기

	마켓 아이템으로 입힌다 (docs/reference/roblox-avatar-and-platform.md 4·8장)
	  - 몸: 로블록스 기본 신체 번들(다이나믹 헤드·눈썹·속눈썹)을 HumanoidDescription에 풀어 넣음.
	    번들에 딸린 탱크톱·반바지는 빼고, 우리가 머리·모자를 고른 역할은 번들 머리카락도 뺌
	  - 옷·모자·수염: 카탈로그 에셋 id (AvatarEditorService:SearchCatalogAsync로 고름, Roblox 공식 아이템 우선)
	    레이어드 옷(셔츠·조끼·재킷·바지)은 적힌 순서대로 안쪽 → 바깥
	  - Players:CreateHumanoidModelFromDescriptionAsync(R15)

	편집 모드 주의: 만든 직후엔 관절(AnimationConstraint)이 안 풀려 머리가 몸에서 7스터드 떨어져 있고(목이 늘어나 보임)
	액세서리도 제자리에 없다. 그래서 solve()로 뿌리에서부터 부착점(Attachment)끼리 맞춰 각 파트·액세서리를 직접 옮긴 뒤
	전부 고정(Anchored)한다. 움직이지 않는 NPC (맵에 스크립트를 두지 않는 규칙).

	HUBS에 있는 허브마다, 그 허브에 있는 건물만 세운다. 다시 실행하면 Hub/Npcs를 지우고 새로 만든다.
]]

local HUBS = { "CollapseMine", "CollapseMine_iron", "CollapseMine_groundwater", "CollapseMine_lava" }
local SCALE = 1.1 -- 계산대가 플레이어 키에 맞춰져 있어 조금 크게

local BODY_ANDI = 993 -- 기본 신체 - 앤디
local BODY_RILEY = 979 -- 기본 신체 - 라일리

-- offset = 건물 피벗 기준 (오른쪽, 앞) 스터드, face = 바라볼 방향(건물 앞 기준 회전 도)
local ROLES = {
	Shop = {
		title = "상인", body = BODY_ANDI, skin = Color3.fromRGB(234, 184, 146), shoes = 883, -- 워크 부츠 - 브라운
		items = {
			100202592246873, -- 브라운 숏 레이어드 헤어
			114177575858105, -- 갈색 가죽 모자
			103395143072346, -- 갈색 콧수염
			95560507602223, -- 흰 셔츠 + 갈색 정장 조끼
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
		noBundleHair = true, -- 번들 머리가 헬멧을 덮어서
		items = {
			1609609, -- 광부 헬멧 (Roblox)
			91010650782683, -- 흰 셔츠
			127189956586914, -- 데님 작업복
			18863614932, -- 오렌지 건설 조끼 (레이어드)
		},
		offset = Vector2.new(-4.5, 3.5), face = 20,
	},
}

local Players = game:GetService("Players")
local MPS = game:GetService("MarketplaceService")
local AssetService = game:GetService("AssetService")
local CHS = game:GetService("ChangeHistoryService")

-- 에셋 종류 번호(AssetTypeId) → 붙이는 자리
local ACC = {
	[8] = Enum.AccessoryType.Hat, [41] = Enum.AccessoryType.Hair, [42] = Enum.AccessoryType.Face,
	[43] = Enum.AccessoryType.Neck, [44] = Enum.AccessoryType.Shoulder, [45] = Enum.AccessoryType.Front,
	[46] = Enum.AccessoryType.Back, [47] = Enum.AccessoryType.Waist,
	[64] = Enum.AccessoryType.TShirt, [65] = Enum.AccessoryType.Shirt, [66] = Enum.AccessoryType.Pants,
	[67] = Enum.AccessoryType.Jacket, [68] = Enum.AccessoryType.Sweater, [69] = Enum.AccessoryType.Shorts,
	[70] = Enum.AccessoryType.LeftShoe, [71] = Enum.AccessoryType.RightShoe, [72] = Enum.AccessoryType.DressSkirt,
	[76] = Enum.AccessoryType.Eyebrow, [77] = Enum.AccessoryType.Eyelash,
}
local LAYERED = { [64] = true, [65] = true, [66] = true, [67] = true, [68] = true, [69] = true, [70] = true, [71] = true, [72] = true, [76] = true, [77] = true }
local BODY = { [17] = "Head", [79] = "Head", [27] = "Torso", [28] = "RightArm", [29] = "LeftArm", [30] = "LeftLeg", [31] = "RightLeg" }
local BASIC_CLOTHES = { [64] = true, [65] = true, [66] = true, [69] = true }

local cache = {}
local function typeOf(id: number): number?
	if cache[id] == nil then
		local ok, info = pcall(function() return MPS:GetProductInfo(id) end)
		cache[id] = ok and info.AssetTypeId or false
	end
	return cache[id] or nil
end

local function describe(role): HumanoidDescription
	local d = Instance.new("HumanoidDescription")
	local accs, order = {}, 1
	local function add(id: number, fromBundle: boolean)
		local t = typeOf(id)
		if not t then warn("[HubNpcs] 에셋 정보 못 읽음: " .. id) return end
		if BODY[t] then
			(d :: any)[BODY[t]] = id
		elseif t == 78 then
			d.MoodAnimation = id
		elseif ACC[t] then
			if fromBundle and (BASIC_CLOTHES[t] or (t == 41 and role.noBundleHair)) then return end
			table.insert(accs, { AssetId = id, AccessoryType = ACC[t], IsLayered = LAYERED[t] == true, Order = LAYERED[t] and order or nil })
			if LAYERED[t] then order += 1 end
		end
	end
	local function addBundle(bid: number)
		local ok, det = pcall(function() return AssetService:GetBundleDetailsAsync(bid) end)
		if not ok then warn("[HubNpcs] 번들 못 읽음: " .. bid) return end
		for _, it in det.Items do
			if it.Type == "Asset" then add(it.Id, true) end
		end
	end
	addBundle(role.body)
	for _, id in role.items do add(id, false) end
	addBundle(role.shoes)
	d:SetAccessories(accs, true)
	local s = role.skin
	d.HeadColor, d.TorsoColor, d.LeftArmColor, d.RightArmColor, d.LeftLegColor, d.RightLegColor = s, s, s, s, s, s
	return d
end

-- 편집 모드에선 관절이 안 풀리니 뿌리부터 부착점끼리 맞춰 파트·액세서리를 제자리로 옮긴다
local function solve(m: Model)
	local root = m:FindFirstChild("HumanoidRootPart") :: BasePart
	local done = { [root] = true }
	local changed = true
	while changed do
		changed = false
		for _, j in m:GetDescendants() do
			if j:IsA("AnimationConstraint") then
				local a0, a1 = j.Attachment0, j.Attachment1
				local p0 = a0 and a0.Parent
				local p1 = a1 and a1.Parent
				if p0 and p1 and p1:IsA("BasePart") and done[p0] and not done[p1] then
					p1.CFrame = a0.WorldCFrame * a1.CFrame:Inverse()
					done[p1] = true
					changed = true
				end
			elseif j:IsA("Motor6D") then
				local p0, p1 = j.Part0, j.Part1
				if p0 and p1 and done[p0] and not done[p1] then
					p1.CFrame = p0.CFrame * j.C0 * j.C1:Inverse()
					done[p1] = true
					changed = true
				end
			end
		end
	end
	local atts = {}
	for _, p in m:GetChildren() do
		if p:IsA("BasePart") then
			for _, a in p:GetChildren() do
				if a:IsA("Attachment") then atts[a.Name] = a end
			end
		end
	end
	for _, acc in m:GetChildren() do
		if acc:IsA("Accessory") then
			local h = acc:FindFirstChild("Handle") :: BasePart?
			if h then
				for _, a in h:GetChildren() do
					if a:IsA("Attachment") and atts[a.Name] then
						h.CFrame = atts[a.Name].WorldCFrame * a.CFrame:Inverse()
						break
					end
				end
			end
		end
	end
end

local function nameTag(m: Model, text: string)
	local bb = Instance.new("BillboardGui")
	bb.Name = "NameTag"
	bb.Size = UDim2.fromOffset(140, 34)
	bb.StudsOffset = Vector3.new(0, 2.6, 0)
	bb.MaxDistance = 45
	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.fromScale(1, 1)
	tl.BackgroundTransparency = 1
	tl.Font = Enum.Font.GothamBold
	tl.TextScaled = true
	tl.TextColor3 = Color3.fromRGB(255, 235, 190)
	tl.TextStrokeTransparency = 0.3
	tl.Text = text
	tl.Parent = bb
	bb.Parent = m:FindFirstChild("Head")
end

local function feetY(m: Model): number
	local low = math.huge
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") and (p.Name == "LeftFoot" or p.Name == "RightFoot") then
			low = math.min(low, p.Position.Y - p.Size.Y / 2)
		end
	end
	return low
end

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.RespectCanCollide = false

-- 역할마다 한 번만 만들고 허브마다 복사
local rec = CHS:TryBeginRecording("PlaceHubNpcs")
local templates = {}
for key, role in ROLES do
	local m = Players:CreateHumanoidModelFromDescriptionAsync(describe(role), Enum.HumanoidRigType.R15)
	m.Name = "Npc_" .. role.title
	local animate = m:FindFirstChild("Animate")
	if animate then animate:Destroy() end
	(m:FindFirstChildOfClass("Humanoid") :: Humanoid).DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	solve(m)
	m:ScaleTo(SCALE)
	nameTag(m, role.title)
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = p.Name == "HumanoidRootPart" -- 사람이 겹쳐 지나가지 않게 몸통 하나만
		end
	end
	templates[key] = m
end

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

		local npc = templates[bName]:Clone()
		-- 모델 앞(-Z)이 건물 앞 방향(+face)을 보게
		local facing = CFrame.lookAt(Vector3.zero, fwd) * CFrame.Angles(0, math.rad(role.face), 0)
		npc:PivotTo(CFrame.new(spot) * facing.Rotation)
		npc:PivotTo(npc:GetPivot() + Vector3.new(0, groundY - feetY(npc), 0))
		npc.Parent = folder
		count += 1
		task.wait()
	end
end
for _, m in templates do m:Destroy() end
if rec then CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
print(("[HubNpcs] NPC %d명 배치"):format(count))
