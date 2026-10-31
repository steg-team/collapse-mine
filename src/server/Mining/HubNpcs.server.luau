--!strict
--[[
	허브 건물 NPC (상인·대장장이·기록관·창고지기)

	tools/place_hub_npcs.luau가 허브마다 놓아 둔 자리표(태그 "HubNpc", 투명 파트, 발바닥 자리)에
	서버가 게임이 시작될 때 마켓 아이템을 입힌 캐릭터를 세운다.

	왜 실행 중에 만드나: 편집 모드에서 HumanoidDescription으로 몸을 만들면 다이나믹 헤드·레이어드 옷이
	제자리에 붙지 않는다(목이 늘어나고 옷이 떨어져 나감). 공식 Homestore 템플릿도 마네킹을 서버에서
	CreateHumanoidModelFromDescriptionAsync로 만든다 (docs/reference/roblox-avatar-and-platform.md 8장).

	자리표 속성
	  Title  머리 위 이름 / Body 몸 번들 id / Items 에셋 id 목록("1,2,3", 레이어드 옷은 안쪽부터)
	  Shoes  신발 번들 id / Skin 피부색 / Scale 크기 배수
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local AssetService = game:GetService("AssetService")
local MarketplaceService = game:GetService("MarketplaceService")

local TAG = "HubNpc"
local IDLE_ANIMATION = "rbxassetid://507766388" -- 로블록스 기본 R15 대기 동작 (가만히 숨쉬기)

-- 에셋 종류 번호(AssetTypeId) → 붙이는 자리
local ACCESSORY_TYPE: { [number]: Enum.AccessoryType } = {
	[8] = Enum.AccessoryType.Hat, [41] = Enum.AccessoryType.Hair, [42] = Enum.AccessoryType.Face,
	[43] = Enum.AccessoryType.Neck, [44] = Enum.AccessoryType.Shoulder, [45] = Enum.AccessoryType.Front,
	[46] = Enum.AccessoryType.Back, [47] = Enum.AccessoryType.Waist,
	[64] = Enum.AccessoryType.TShirt, [65] = Enum.AccessoryType.Shirt, [66] = Enum.AccessoryType.Pants,
	[67] = Enum.AccessoryType.Jacket, [68] = Enum.AccessoryType.Sweater, [69] = Enum.AccessoryType.Shorts,
	[70] = Enum.AccessoryType.LeftShoe, [71] = Enum.AccessoryType.RightShoe, [72] = Enum.AccessoryType.DressSkirt,
	[76] = Enum.AccessoryType.Eyebrow, [77] = Enum.AccessoryType.Eyelash,
}
local LAYERED: { [number]: boolean } = {
	[64] = true, [65] = true, [66] = true, [67] = true, [68] = true, [69] = true,
	[70] = true, [71] = true, [72] = true, [76] = true, [77] = true,
}
-- 몸 파트 (79 = 다이나믹 헤드)
local BODY_PART: { [number]: string } = {
	[17] = "Head", [79] = "Head", [27] = "Torso", [28] = "RightArm", [29] = "LeftArm", [30] = "LeftLeg", [31] = "RightLeg",
}
local BASIC_CLOTHES: { [number]: boolean } = { [64] = true, [65] = true, [66] = true, [69] = true }

local typeCache: { [number]: number | false } = {}
local function assetType(id: number): number?
	if typeCache[id] == nil then
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(id)
		end)
		typeCache[id] = if ok and info then info.AssetTypeId else false
	end
	local t = typeCache[id]
	return if t then t else nil
end

local function parseIds(s: string?): { number }
	local out = {}
	for part in string.gmatch(s or "", "%d+") do
		table.insert(out, tonumber(part) :: number)
	end
	return out
end

local function describe(marker: BasePart): HumanoidDescription
	local d = Instance.new("HumanoidDescription")
	local accessories = {}
	local order = 1
	local function add(id: number, skipBasicClothes: boolean)
		local t = assetType(id)
		if not t then
			return
		end
		if BODY_PART[t] then
			(d :: any)[BODY_PART[t]] = id
		elseif t == 78 then
			d.MoodAnimation = id
		elseif ACCESSORY_TYPE[t] then
			-- 몸 번들에 딸린 기본 탱크톱·반바지는 빼고 우리가 고른 옷을 입힌다
			if skipBasicClothes and BASIC_CLOTHES[t] then
				return
			end
			table.insert(accessories, {
				AssetId = id,
				AccessoryType = ACCESSORY_TYPE[t],
				IsLayered = LAYERED[t] == true,
				Order = if LAYERED[t] then order else nil,
			})
			if LAYERED[t] then
				order += 1
			end
		end
	end
	local function addBundle(bundleId: number?, skipBasicClothes: boolean)
		if not bundleId or bundleId == 0 then
			return
		end
		local ok, details = pcall(function()
			return AssetService:GetBundleDetailsAsync(bundleId)
		end)
		if not ok or not details then
			return
		end
		for _, item in details.Items do
			if item.Type == "Asset" then
				add(item.Id, skipBasicClothes)
			end
		end
	end

	addBundle(marker:GetAttribute("Body") :: number?, true)
	for _, id in parseIds(marker:GetAttribute("Items") :: string?) do
		add(id, false)
	end
	addBundle(marker:GetAttribute("Shoes") :: number?, false)
	d:SetAccessories(accessories, true)
	local skin = marker:GetAttribute("Skin")
	if typeof(skin) == "Color3" then
		d.HeadColor, d.TorsoColor = skin, skin
		d.LeftArmColor, d.RightArmColor = skin, skin
		d.LeftLegColor, d.RightLegColor = skin, skin
	end
	return d
end

local function nameTag(model: Model, text: string)
	local head = model:FindFirstChild("Head")
	if not head then
		return
	end
	local bb = Instance.new("BillboardGui")
	bb.Name = "NameTag"
	bb.Size = UDim2.fromOffset(140, 34)
	bb.StudsOffset = Vector3.new(0, 2.4, 0)
	bb.MaxDistance = 45
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 235, 190)
	label.TextStrokeTransparency = 0.3
	label.Text = text
	label.Parent = bb
	bb.Parent = head
end

local function spawnNpc(marker: Instance)
	if not marker:IsA("BasePart") or marker:GetAttribute("Spawned") then
		return
	end
	marker:SetAttribute("Spawned", true)
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescriptionAsync(describe(marker), Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then
		warn("[HubNpcs] NPC를 못 만듦:", marker:GetFullName(), model)
		return
	end
	local title = (marker:GetAttribute("Title") :: string?) or "NPC"
	model.Name = "Npc_" .. title
	local animate = model:FindFirstChild("Animate")
	if animate then
		animate:Destroy() -- 걷기·점프 동작 스크립트는 필요 없음, 대기 동작만 직접 튼다
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.BreakJointsOnDeath = false
	local scale = marker:GetAttribute("Scale")
	if typeof(scale) == "number" and scale > 0 then
		model:ScaleTo(scale)
	end

	-- 자리표(발바닥 자리)에 세운다: 방향은 자리표, 높이는 발바닥 기준
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	model:PivotTo(marker.CFrame * CFrame.new(0, 20, 0))
	local lowest = math.huge
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and (p.Name == "LeftFoot" or p.Name == "RightFoot") then
			lowest = math.min(lowest, p.Position.Y - p.Size.Y / 2)
		end
	end
	if lowest < math.huge then
		model:PivotTo(model:GetPivot() - Vector3.new(0, lowest - marker.Position.Y, 0))
	end
	root.Anchored = true -- 뿌리만 고정: 관절은 살아 있어 대기 동작이 돈다
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.CanCollide = p == root
		end
	end
	nameTag(model, title)
	model.Parent = marker.Parent

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	local anim = Instance.new("Animation")
	anim.AnimationId = IDLE_ANIMATION
	local track = (animator :: Animator):LoadAnimation(anim)
	track.Looped = true
	track:Play()
end

for _, marker in CollectionService:GetTagged(TAG) do
	task.spawn(spawnNpc, marker)
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(function(marker)
	task.spawn(spawnNpc, marker)
end)
