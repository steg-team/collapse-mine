--[[
	스테이지 이동 임시 포탈 — 허브 입구 오른쪽 절벽 벽(화로와 랭킹판 사이)에 다른 스테이지로 가는 포탈 2개.
	Studio 명령창에서 실행 (Edit 모드). 다시 실행하면 예전 포탈은 지우고 새로 만든다.

	- 밟으면 그 스테이지 허브의 MineSpawn으로 (MineTravel: 태그 StagePortal, 속성 MineId = 가는 스테이지)
	- 그 스테이지 광산의 requiredPickaxe 미만이면 안 간다
	- 스테이지 사이 텔레포트 UI(D-017)가 생기기 전까지 쓰는 임시 포탈. UI가 생기면 지워도 된다
	- 허브 3개 모두 입구 오른쪽 벽 앞(허브 기준 x 42, 56 / 지하수 허브는 폭포 피해 55, 66, z 50)에 "나머지 두 스테이지"로 가는 포탈을 둔다
]]

local CHS = game:GetService("ChangeHistoryService")
local CS = game:GetService("CollectionService")

local HUBS = {
	{ folder = "CollapseMine", id = "basic", dx = 0 },
	{ folder = "CollapseMine_iron", id = "iron", dx = -900 },
	-- 지하수 허브는 입구 오른쪽(x +44)에 폭포·물웅덩이가 있어서 그보다 바깥으로
	{ folder = "CollapseMine_groundwater", id = "groundwater", dx = 900, slots = { 55, 66 } },
}
local STAGES = {
	basic = { name = "기본 광산", tier = 1, color = Color3.fromRGB(255, 170, 70) },
	iron = { name = "철광 갱도", tier = 2, color = Color3.fromRGB(255, 110, 60) },
	groundwater = { name = "지하수 동굴", tier = 3, color = Color3.fromRGB(80, 200, 255) },
}
local SLOTS_X = { 42, 56 } -- 허브 기준 x
local Z = 50 -- 절벽 앞면이 z 45~48 (광장은 +z 쪽)이라 그보다 광장 쪽에 세운다
local FLOOR_Y = 1.5

local function part(props: { [string]: any }, parent: Instance): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in props do (p :: any)[k] = v end
	p.Parent = parent
	return p
end

local function buildPortal(parent: Instance, x: number, targetId: string)
	local st = STAGES[targetId]
	local m = Instance.new("Model")
	m.Name = "StagePortal_" .. targetId
	local wood = Color3.fromRGB(90, 60, 40)
	local W, H = 8, 10
	-- 바닥 발판
	part({ Name = "Pad", Size = Vector3.new(W + 2, 0.6, 4), CFrame = CFrame.new(x, FLOOR_Y + 0.3, Z + 1), Material = Enum.Material.Slate, Color = Color3.fromRGB(70, 70, 75) }, m)
	-- 기둥 둘 + 윗보
	for _, sx in { -1, 1 } do
		part({ Name = "Post", Size = Vector3.new(1, H, 1), CFrame = CFrame.new(x + sx * (W / 2), FLOOR_Y + 0.6 + H / 2, Z), Material = Enum.Material.Wood, Color = wood }, m)
	end
	part({ Name = "Beam", Size = Vector3.new(W + 2, 1.2, 1.4), CFrame = CFrame.new(x, FLOOR_Y + 0.6 + H + 0.6, Z), Material = Enum.Material.Wood, Color = wood }, m)
	-- 빛나는 막 (밟는 판정). 사람 몸통이 지나가게 두껍게, 충돌은 끔
	local field = part({
		Name = "Field", Size = Vector3.new(W - 1, H - 0.5, 2), CFrame = CFrame.new(x, FLOOR_Y + 0.6 + H / 2, Z + 0.3),
		Material = Enum.Material.Neon, Color = st.color, Transparency = 0.45, CanCollide = false, CastShadow = false,
	}, m)
	field:SetAttribute("MineId", targetId)
	CS:AddTag(field, "StagePortal")
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = st.color, 14, 1.2
	light.Parent = field
	-- 간판: 가는 곳 + 필요한 곡괭이
	local sign = part({ Name = "Sign", Size = Vector3.new(W + 1, 2.4, 0.3), CFrame = CFrame.new(x, FLOOR_Y + 0.6 + H + 2.6, Z + 0.5), Material = Enum.Material.Wood, Color = Color3.fromRGB(60, 40, 28) }, m)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back -- 광장(+z) 쪽
	gui.CanvasSize = Vector2.new(360, 96)
	gui.LightInfluence = 0
	gui.Parent = sign
	local function label(text: string, y: number, h: number, size: number)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Size = UDim2.new(1, 0, h, 0)
		l.Position = UDim2.new(0, 0, y, 0)
		l.Font = Enum.Font.GothamBold
		l.TextSize = size
		l.TextColor3 = Color3.fromRGB(255, 240, 210)
		l.Text = text
		l.Parent = gui
	end
	label("→ " .. st.name, 0.05, 0.55, 40)
	label(("곡괭이 %d단계 이상"):format(st.tier), 0.6, 0.35, 24)
	m.Parent = parent
end

local rec = CHS:TryBeginRecording("BuildStagePortals")
for _, h in HUBS do
	local hubFolder = workspace:FindFirstChild(h.folder)
	local hub = hubFolder and hubFolder:FindFirstChild("Hub")
	if not hub then
		warn("[StagePortals] 허브 없음: " .. h.folder)
		continue
	end
	local old = hub:FindFirstChild("StagePortals")
	if old then old:Destroy() end
	local folder = Instance.new("Folder")
	folder.Name = "StagePortals"
	local i = 0
	for _, targetId in { "basic", "iron", "groundwater" } do
		if targetId ~= h.id then
			i += 1
			buildPortal(folder, h.dx + (h.slots or SLOTS_X)[i], targetId)
		end
	end
	folder.Parent = hub
	task.wait()
end
if rec then CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
print("[StagePortals] 허브 3곳에 스테이지 포탈 생성")
