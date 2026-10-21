--[[
	허브 절벽 벽에 광산 동굴 입구를 뚫는 스크립트 (Studio 명령창에서 실행)

	먼저 tools/build_hub_cliffs.luau 로 허브를 둘러싼 절벽을 만든 뒤 실행한다.
	입구 뒤쪽에 바위를 한 덩어리 보강하고(절벽이 얇거나 없어도 입구가 서도록), 둥근 갱도 입구를 뚫고,
	지지대·레일·등불·표지판을 단다. 입구 안쪽 어둠 속에 이동 판정(태그 "MinePortal")을 둔다.
	(이동 처리: src/server/Mining/MineTravel.server.luau)

	MINE_ID   광산 id (Shared.Config.Mines)
	MOUTH     입구 바닥 중심 (절벽 안쪽 면 위치, 월드 좌표)
	FACING    입구가 바라보는 방향(도). 0이면 +Z 쪽을 바라봄 (허브 남쪽 벽에 뚫을 때)

	같은 MINE_ID로 다시 실행하면 이전 입구 장식(파트)은 지우고 다시 만든다.
]]

local MINE_ID = "basic"
local MOUTH = Vector3.new(0, 0, 40)
local FACING = 0

local RS = game:GetService("ReplicatedStorage")
local CS = game:GetService("CollectionService")
local CHS = game:GetService("ChangeHistoryService")
local Mines = require(RS.Shared.Config.Mines)
local M = assert(Mines.get(MINE_ID), "Mines 설정에 없는 id")

local T = workspace.Terrain
local CF = CFrame.new(MOUTH) * CFrame.Angles(0, math.rad(FACING), 0)
local function W(x, y, z) return CF:PointToWorldSpace(Vector3.new(x, y, z)) end
local function box(x, y, z, size, mat) T:FillBlock(CFrame.new(W(x, y, z)) * CF.Rotation, size, mat) end

local rec = CHS:TryBeginRecording("BuildCaveEntrance " .. MINE_ID)

local hub = workspace.CollapseMine.Hub
local portals = hub:FindFirstChild("MinePortals") or Instance.new("Folder")
portals.Name = "MinePortals"; portals.Parent = hub
local old = portals:FindFirstChild("Portal_" .. MINE_ID)
if old then old:Destroy() end
local model = Instance.new("Model")
model.Name = "Portal_" .. MINE_ID

-- 로컬 좌표: +z = 허브 쪽(입구 앞), -z = 절벽 속
local MOUTH_W, MOUTH_H, DEPTH = 24, 20, 34

-- 1) 입구 뒤 바위 보강 (입구 둘레가 얇게 뚫리지 않도록)
box(0, (MOUTH_H + 10) / 2 - 4, -DEPTH / 2, Vector3.new(MOUTH_W + 20, MOUTH_H + 14, DEPTH + 6), Enum.Material.Rock)
-- 입구 위 바위 처마 (튀어나온 지붕 느낌)
for _, x in ipairs({-10, -4, 2, 8}) do
	T:FillBall(W(x, MOUTH_H + 3, 1), 5.5, Enum.Material.Rock)
end
task.wait()

-- 2) 입구 뚫기: 아래는 네모, 위는 둥근 천장
box(0, MOUTH_H / 2 - 2, (10 - DEPTH) / 2, Vector3.new(MOUTH_W, MOUTH_H - 2, DEPTH + 10), Enum.Material.Air)
for z = 10, -DEPTH, -3 do
	T:FillBall(W(0, MOUTH_H - 7, z), MOUTH_W / 2, Enum.Material.Air)
end
-- 바닥 (흙길)
box(0, -2.5, (12 - DEPTH) / 2, Vector3.new(MOUTH_W + 4, 5, DEPTH + 12), Enum.Material.Ground)
task.wait()

-- 3) 장식 ---------------------------------------------------------------------
local function part(name, size, x, y, z, color, mat)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = CFrame.new(W(x, y, z)) * CF.Rotation
	p.Anchored = true
	p.Color = color
	p.Material = mat
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end
local wood = Color3.fromRGB(105, 72, 44)
local woodDark = Color3.fromRGB(80, 55, 34)
local POST_X = MOUTH_W / 2 - 2
local POST_H = MOUTH_H - 3
-- 갱도 지지대 3세트 (입구, 중간, 안쪽)
for _, z in ipairs({3, -9, -20}) do
	part("Post", Vector3.new(2, POST_H, 2), -POST_X, POST_H / 2, z, wood, Enum.Material.WoodPlanks)
	part("Post", Vector3.new(2, POST_H, 2), POST_X, POST_H / 2, z, wood, Enum.Material.WoodPlanks)
	part("Beam", Vector3.new(POST_X * 2 + 3, 2, 2.2), 0, POST_H + 0.8, z, woodDark, Enum.Material.WoodPlanks)
end
-- 레일
for _, x in ipairs({-2, 2}) do
	part("Rail", Vector3.new(0.4, 0.4, DEPTH + 8), x, 0.2, (10 - DEPTH) / 2, Color3.fromRGB(90, 90, 95), Enum.Material.Metal)
end
for z = 10, -DEPTH + 6, -3 do
	part("Sleeper", Vector3.new(5.6, 0.3, 1), 0, 0.05, z, woodDark, Enum.Material.Wood)
end
-- 등불 (입구 양옆 + 안쪽 벽)
local function lantern(x, y, z, range)
	local lamp = part("Lantern", Vector3.new(1.6, 2.2, 1.6), x, y, z, Color3.fromRGB(255, 190, 110), Enum.Material.Neon)
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness, l.Shadows = Color3.fromRGB(255, 180, 100), range, 1.8, true
	l.Parent = lamp
end
for _, x in ipairs({-(MOUTH_W / 2 + 4), MOUTH_W / 2 + 4}) do
	part("LanternPost", Vector3.new(0.8, 10, 0.8), x, 5, 7, woodDark, Enum.Material.Wood)
	lantern(x, 10.8, 7, 28)
end
for _, x in ipairs({-POST_X + 1.6, POST_X - 1.6}) do
	lantern(x, POST_H - 2, -9, 18)
end
-- 이동 판정: 입구 안쪽 어둠 속 (보이지 않게)
local field = part("Field", Vector3.new(MOUTH_W - 2, MOUTH_H - 2, 2), 0, MOUTH_H / 2 - 1, -DEPTH + 8, Color3.new(0, 0, 0), Enum.Material.SmoothPlastic)
field.Transparency = 1
field.CanCollide = false
field:SetAttribute("MineId", MINE_ID)
CS:AddTag(field, "MinePortal")
-- 더 깊어 보이게 하는 검은 막 (판정 뒤)
local veil = part("Darkness", Vector3.new(MOUTH_W + 2, MOUTH_H + 2, 1), 0, MOUTH_H / 2, -DEPTH + 4, Color3.fromRGB(5, 5, 7), Enum.Material.SmoothPlastic)
veil.CanCollide = false
-- 이름 표지판 (입구 지지대 위)
local sign = part("Sign", Vector3.new(16, 4, 0.6), 0, POST_H + 4.2, 4.4, wood, Enum.Material.WoodPlanks)
local sg = Instance.new("SurfaceGui")
sg.Face = Enum.NormalId.Back
sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
sg.PixelsPerStud = 40
local tl = Instance.new("TextLabel")
tl.Size = UDim2.fromScale(1, 0.68)
tl.BackgroundTransparency = 1
tl.TextScaled = true
tl.Font = Enum.Font.GothamBlack
tl.TextColor3 = Color3.fromRGB(255, 230, 190)
tl.Text = M.name
tl.Parent = sg
local sub = Instance.new("TextLabel")
sub.Position = UDim2.fromScale(0, 0.66)
sub.Size = UDim2.fromScale(1, 0.3)
sub.BackgroundTransparency = 1
sub.TextScaled = true
sub.Font = Enum.Font.GothamBold
sub.TextColor3 = Color3.fromRGB(230, 200, 160)
sub.Text = "곡괭이 " .. M.requiredPickaxe .. "단계 이상"
sub.Parent = sg
sg.Parent = sign
for _, x in ipairs({-5, 5}) do
	part("SignRope", Vector3.new(0.25, 1.4, 0.25), x, POST_H + 2.1, 4.4, woodDark, Enum.Material.Fabric)
end

model.PrimaryPart = field
model.Parent = portals

if rec then CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
print("[CaveEntrance] " .. model:GetFullName() .. " 생성")
