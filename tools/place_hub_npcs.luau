--[[
	허브 건물마다 NPC 한 명씩 (Studio 명령창에서 실행)
	판매소 = 상인(초록 납작 모자, 동전 자루), 제작소 = 대장장이(가죽 모자·고글, 앞치마, 망치),
	랭킹판 = 기록관(검은 실크햇, 두루마리), 창고 = 창고지기(노란 안전모, 서류판).

	- 몸은 Players:CreateHumanoidModelFromDescription(R15)로 만들고 몸 색으로 옷을 표현한다.
	- 모자는 Roblox AI로 만든 메시 (ServerStorage.NpcParts.HardHat/SmithCap/MerchantCap/TopHat)를 Accessory로 씌운다.
	- 손에 든 물건·앞치마는 파트. 움직이지 않게 HumanoidRootPart를 고정(Anchored)하고 팔 관절 각도로 자세만 잡는다.
	  (워크스페이스에 스크립트를 두지 않는 규칙 때문에 대기 애니메이션은 없음)
	- 머리 위에 역할 이름표 (가까이 갔을 때만).
	- 위치는 건물 피벗 기준 (건물 LookVector = 광장 쪽 앞). 바닥 높이는 레이로 찾는다.
	HUBS에 있는 허브마다, 그 허브에 있는 건물만 세운다. 다시 실행하면 Hub/Npcs를 지우고 새로 만든다.
]]

local HUBS = { "CollapseMine", "CollapseMine_iron", "CollapseMine_groundwater", "CollapseMine_lava" }
local NPC_SCALE = 1.15 -- 계산대가 플레이어 키에 맞춰져 있어 NPC를 조금 크게 (계산대 위로 가슴이 보이게)

local Players = game:GetService("Players")
local SS = game:GetService("ServerStorage")
local CHS = game:GetService("ChangeHistoryService")
local parts = assert(SS:FindFirstChild("NpcParts"), "ServerStorage.NpcParts가 없음 (모자 메시)")

local SKIN = { Color3.fromRGB(234, 184, 146), Color3.fromRGB(204, 142, 105), Color3.fromRGB(160, 110, 80), Color3.fromRGB(245, 205, 172) }

-- 역할별 모양. offset = 건물 피벗 기준 (오른쪽, 앞) 스터드, face = 바라볼 방향(건물 앞 기준 회전 도)
local ROLES = {
	Shop = {
		title = "상인", hat = "MerchantCap", hatScale = 1.25, hatY = 0.35, skin = 1,
		shirt = Color3.fromRGB(170, 60, 50), pants = Color3.fromRGB(70, 55, 45), shoes = Color3.fromRGB(45, 35, 30),
		offset = Vector2.new(0, -2.6), face = 0, prop = "CoinSack",
	},
	Workshop = {
		title = "대장장이", hat = "SmithCap", hatScale = 1.25, hatY = 0.3, skin = 3,
		shirt = Color3.fromRGB(120, 110, 100), pants = Color3.fromRGB(55, 50, 48), shoes = Color3.fromRGB(35, 30, 28),
		offset = Vector2.new(0, -2.6), face = 0, prop = "Hammer", apron = true,
	},
	Leaderboard = {
		title = "기록관", hat = "TopHat", hatScale = 1.0, hatY = 0.55, skin = 4,
		shirt = Color3.fromRGB(40, 50, 90), pants = Color3.fromRGB(30, 30, 38), shoes = Color3.fromRGB(20, 20, 22),
		offset = Vector2.new(-11, 5), face = -35, prop = "Scroll",
	},
	Storage = {
		title = "창고지기", hat = "HardHat", hatScale = 1.35, hatY = 0.35, skin = 2,
		shirt = Color3.fromRGB(230, 130, 40), pants = Color3.fromRGB(60, 75, 110), shoes = Color3.fromRGB(50, 40, 32),
		offset = Vector2.new(-4.5, 3.5), face = 20, prop = "Clipboard",
	},
}

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1 = a, b
	w.Parent = a
end
local function part(name: string, size: Vector3, color: Color3, mat: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	if shape then p.Shape = shape end
	p.Size = size
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	return p
end

-- 손에 든 물건 (오른손 기준으로 붙임)
local PROPS = {}
function PROPS.Hammer(hand: BasePart, model: Model)
	local handle = part("HammerHandle", Vector3.new(0.25, 2.2, 0.25), Color3.fromRGB(110, 75, 45), Enum.Material.Wood)
	handle.CFrame = hand.CFrame * CFrame.new(0, -0.2, -0.3) * CFrame.Angles(math.rad(-80), 0, 0)
	local head = part("HammerHead", Vector3.new(0.5, 0.5, 1.1), Color3.fromRGB(80, 80, 88), Enum.Material.Metal)
	head.CFrame = handle.CFrame * CFrame.new(0, 1.05, 0) * CFrame.Angles(math.rad(90), 0, 0)
	handle.Parent, head.Parent = model, model
	weld(hand, handle); weld(handle, head)
end
function PROPS.CoinSack(hand: BasePart, model: Model)
	local sack = part("CoinSack", Vector3.new(1.1, 1.1, 1.1), Color3.fromRGB(150, 110, 70), Enum.Material.Fabric, Enum.PartType.Ball)
	sack.CFrame = hand.CFrame * CFrame.new(0, -0.7, 0)
	local tie = part("SackTie", Vector3.new(0.5, 0.3, 0.5), Color3.fromRGB(120, 85, 50), Enum.Material.Fabric)
	tie.CFrame = sack.CFrame * CFrame.new(0, 0.55, 0)
	local sign = part("CoinMark", Vector3.new(0.5, 0.5, 0.1), Color3.fromRGB(240, 195, 60), Enum.Material.Neon, Enum.PartType.Cylinder)
	sign.CFrame = sack.CFrame * CFrame.new(0, 0, -0.55) * CFrame.Angles(0, math.rad(90), 0)
	sign.Size = Vector3.new(0.1, 0.5, 0.5)
	for _, p in { sack, tie, sign } do p.Parent = model; weld(hand, p) end
	-- 다른 손엔 금화 하나
end
function PROPS.Scroll(hand: BasePart, model: Model)
	local roll = part("Scroll", Vector3.new(1.4, 0.35, 0.35), Color3.fromRGB(235, 220, 180), Enum.Material.Fabric, Enum.PartType.Cylinder)
	roll.CFrame = hand.CFrame * CFrame.new(0, -0.3, -0.2) * CFrame.Angles(0, math.rad(90), 0)
	local sheet = part("ScrollSheet", Vector3.new(0.05, 1.1, 1.2), Color3.fromRGB(245, 235, 205), Enum.Material.Fabric)
	sheet.CFrame = roll.CFrame * CFrame.new(0, -0.6, 0)
	local seal = part("Seal", Vector3.new(0.12, 0.3, 0.3), Color3.fromRGB(180, 30, 30), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	seal.CFrame = roll.CFrame * CFrame.new(0, -0.9, 0)
	for _, p in { roll, sheet, seal } do p.Parent = model; weld(hand, p) end
end
function PROPS.Clipboard(hand: BasePart, model: Model)
	local board = part("Clipboard", Vector3.new(1.0, 1.3, 0.1), Color3.fromRGB(150, 110, 70), Enum.Material.Wood)
	board.CFrame = hand.CFrame * CFrame.new(0, 0.1, -0.5) * CFrame.Angles(math.rad(-30), 0, 0)
	local paper = part("Paper", Vector3.new(0.85, 1.05, 0.04), Color3.fromRGB(245, 245, 240))
	paper.CFrame = board.CFrame * CFrame.new(0, -0.05, -0.07)
	local clip = part("Clip", Vector3.new(0.5, 0.15, 0.15), Color3.fromRGB(180, 180, 190), Enum.Material.Metal)
	clip.CFrame = board.CFrame * CFrame.new(0, 0.6, -0.08)
	for _, p in { board, paper, clip } do p.Parent = model; weld(hand, p) end
end

local function hatAccessory(name: string, scale: number, y: number): Accessory
	local tpl = assert(parts:FindFirstChild(name), "모자 메시 없음: " .. name) :: MeshPart
	local h = tpl:Clone()
	h.Name = "Handle"
	h.Size = h.Size * scale
	h.Anchored, h.CanCollide, h.Massless = false, false, true
	local a = Instance.new("Attachment")
	a.Name = "HatAttachment"
	a.Position = Vector3.new(0, -h.Size.Y / 2 + y, 0) -- 모자 바닥보다 조금 위 = 머리 꼭대기에 눌러 씀
	a.Parent = h
	local acc = Instance.new("Accessory")
	acc.Name = name
	h.Parent = acc
	return acc
end

local function makeNpc(role, skin: Color3): Model
	local d = Instance.new("HumanoidDescription")
	d.HeadColor = skin
	d.LeftArmColor, d.RightArmColor = role.shirt, role.shirt
	d.TorsoColor = role.shirt
	d.LeftLegColor, d.RightLegColor = role.pants, role.pants
	local m = Players:CreateHumanoidModelFromDescription(d, Enum.HumanoidRigType.R15)
	m.Name = "Npc_" .. role.title
	local anim = m:FindFirstChild("Animate")
	if anim then anim:Destroy() end
	-- 손은 피부색, 발은 신발색
	for _, n in { "LeftHand", "RightHand" } do (m:FindFirstChild(n) :: BasePart).Color = skin end
	for _, n in { "LeftFoot", "RightFoot" } do (m:FindFirstChild(n) :: BasePart).Color = role.shoes end
	local bc = m:FindFirstChildOfClass("BodyColors")
	if bc then bc:Destroy() end -- 위에서 칠한 색을 BodyColors가 덮어쓰지 않게
	local hum = m:FindFirstChildOfClass("Humanoid") :: Humanoid
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum:AddAccessory(hatAccessory(role.hat, role.hatScale, role.hatY))
	if role.apron then
		local ut = m:FindFirstChild("UpperTorso") :: BasePart
		local lt = m:FindFirstChild("LowerTorso") :: BasePart
		local a1 = part("Apron", Vector3.new(1.6, 1.5, 0.12), Color3.fromRGB(95, 60, 35), Enum.Material.Fabric)
		a1.CFrame = ut.CFrame * CFrame.new(0, -0.15, -ut.Size.Z / 2 - 0.05)
		local a2 = part("ApronLow", Vector3.new(1.7, 1.3, 0.12), Color3.fromRGB(95, 60, 35), Enum.Material.Fabric)
		a2.CFrame = lt.CFrame * CFrame.new(0, -0.6, -lt.Size.Z / 2 - 0.05)
		a1.Parent, a2.Parent = m, m
		weld(ut, a1); weld(lt, a2)
	end
	-- 오른팔을 앞으로 조금 들어 물건을 든 자세.
	-- 요즘 리그 관절은 AnimationConstraint라 C0을 못 바꾸고 편집 모드에선 Transform도 안 먹어서,
	-- 팔 파트를 어깨·팔꿈치를 축으로 직접 돌린 뒤 전부 고정(Anchored)한다
	local torsoRot = (m:FindFirstChild("UpperTorso") :: BasePart).CFrame.Rotation
	local function swing(names: { string }, pivot: Vector3, rot: CFrame)
		local r = torsoRot * rot * torsoRot:Inverse()
		for _, n in names do
			local p = m:FindFirstChild(n) :: BasePart
			p.CFrame = CFrame.new(pivot) * r * CFrame.new(-pivot) * p.CFrame
		end
	end
	local shoulder = ((m:FindFirstChild("RightUpperArm") :: BasePart):FindFirstChild("RightShoulderRigAttachment") :: Attachment).WorldPosition
	swing({ "RightUpperArm", "RightLowerArm", "RightHand" }, shoulder, CFrame.Angles(math.rad(30), 0, math.rad(8)))
	local elbow = ((m:FindFirstChild("RightLowerArm") :: BasePart):FindFirstChild("RightElbowRigAttachment") :: Attachment).WorldPosition
	swing({ "RightLowerArm", "RightHand" }, elbow, CFrame.Angles(math.rad(40), 0, 0))
	-- 이름표
	local head = m:FindFirstChild("Head") :: BasePart
	local bb = Instance.new("BillboardGui")
	bb.Name = "NameTag"
	bb.Size = UDim2.fromOffset(140, 34)
	bb.StudsOffset = Vector3.new(0, 2.6, 0)
	bb.MaxDistance = 45
	bb.AlwaysOnTop = false
	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.fromScale(1, 1)
	tl.BackgroundTransparency = 1
	tl.Font = Enum.Font.GothamBold
	tl.TextScaled = true
	tl.TextColor3 = Color3.fromRGB(255, 235, 190)
	tl.TextStrokeTransparency = 0.3
	tl.Text = role.title
	tl.Parent = bb
	bb.Parent = head
	return m
end

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.RespectCanCollide = false

local rec = CHS:TryBeginRecording("PlaceHubNpcs")
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
		local npc = makeNpc(role, SKIN[role.skin])
		params.FilterDescendantsInstances = { npc, folder }
		-- 지붕·차양에 맞지 않게 건물 바닥 바로 위에서 쏜다. 장식 바닥이 충돌 꺼짐일 수 있어 충돌은 무시하고,
		-- 투명 파트(계산대 판정 Counter 등)는 건너뛴다
		local ignore = { npc, folder }
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
		local hrp = npc:FindFirstChild("HumanoidRootPart") :: BasePart
		local hum = npc:FindFirstChildOfClass("Humanoid") :: Humanoid
		local look = CFrame.lookAt(Vector3.zero, fwd) * CFrame.Angles(0, math.rad(role.face), 0)
		npc:ScaleTo(NPC_SCALE)
		npc:PivotTo(CFrame.new(spot.X, groundY + hum.HipHeight + hrp.Size.Y / 2, spot.Z) * look.Rotation)
		-- 편집 모드에선 AccessoryWeld가 모자를 머리로 옮겨 주지 않으니 직접 맞춘다
		for _, acc in npc:GetChildren() do
			if acc:IsA("Accessory") then
				local h = acc:FindFirstChild("Handle") :: BasePart
				local a = h:FindFirstChild("HatAttachment") :: Attachment
				local ha = (npc:FindFirstChild("Head") :: BasePart):FindFirstChild("HatAttachment") :: Attachment
				h.CFrame = ha.WorldCFrame * a.CFrame:Inverse()
			end
		end
		PROPS[role.prop](npc:FindFirstChild("RightHand") :: BasePart, npc)
		for _, p in npc:GetDescendants() do
			if p:IsA("BasePart") then p.Anchored = true end
		end
		npc.Parent = folder
		count += 1
		task.wait()
	end
end
if rec then CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
print(("[HubNpcs] NPC %d명 배치"):format(count))
