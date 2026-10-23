--[[
	광산 출구 — 입구 방 벽의 갱도 문에서 비탈 굴을 타고 지표까지 걸어 올라가,
	풀밭 위 바위 언덕에 뚫린 동굴 아가리로 "진짜 밖"이 보이는 출구를 만든다.
	(Studio 보기 → 명령창에서 실행. Rojo 동기화 대상 아님)

	허브 쪽 광산 입구(tools/build_cave_entrance.luau + 블렌더 장식)와 짝을 맞춘 분위기:
	  방 쪽: 나무 갱도 문틀 + "출구" 명판 + 화살표 표지판 + 레일 + 횃불
	  굴:   비탈(약 22도)로 지표까지, 벽에 횃불
	  밖:   풀밭 위로 솟은 바위 언덕에 동굴 아가리 + 나무 문틀. 아가리 너머로 하늘이 보인다
	출구 판정(ExitPoint, 태그 MineExit)은 아가리 바로 안쪽에서 굴 단면 전체를 막는 투명 상자.
	밟으면 허브로 이동 (MineTravel). 판정을 놓쳐도 밖으로 못 나가게 아가리 바깥에 투명 벽.

	광산을 tools/generate_mine.luau로 다시 생성하면 이 스크립트도 다시 실행한다.
	다시 실행하면 이전 ExitGate를 지우고 새로 만든다. Ctrl+Z로 되돌릴 수 있다.
]]

local MINE_ID = "basic"
local EXIT_DIR = Vector3.new(1, 0, 0) -- 출구 굴이 뻗는 방향 (generate_mine이 도착 지점을 입구 방 -X쪽, 옛 출구 발판을 +X쪽에 둠)

local CS = game:GetService("CollectionService")
local CHS = game:GetService("ChangeHistoryService")
local SS = game:GetService("ServerStorage")
local RS = game:GetService("ReplicatedStorage")
local Mines = require(RS:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Mines"))

local M = assert(Mines.get(MINE_ID), "Mines 설정에 없는 id")
local root = workspace:WaitForChild("Mines"):WaitForChild(MINE_ID)
local roomPart = root.Rooms:FindFirstChild("Room_Entrance")
local arrival = root:FindFirstChild("Entrance")
local pad = root:FindFirstChild("ExitPoint")
assert(roomPart and arrival and pad, "입구 방·도착 지점·출구 발판 중 없는 게 있음. 광산을 먼저 생성")

local T = workspace.Terrain
local AIR = Enum.Material.Air
local SURFACE_Y = 0 -- 지표(잔디 윗면). generate_mine이 top~0을 잔디로 채움

local terrainOnly = RaycastParams.new()
terrainOnly.FilterType = Enum.RaycastFilterType.Include
terrainOnly.FilterDescendantsInstances = { T }

-- 방 바닥 중심과 반경. 가로 위치는 광산 중심(generate_mine이 입구 방을 거기 판다),
-- 높이·반경은 방 표시 파트 (아랫면 = 바닥, 지름 = 2R)
-- 표시 파트를 기준으로 방향을 재면 파트가 조금만 밀려도 출구가 엉뚱한 쪽으로 나서, 방향은 고정값을 쓴다
local center = Vector3.new(M.origin.X, roomPart.Position.Y - roomPart.Size.Y / 2, M.origin.Z)
local R = roomPart.Size.X / 2
local fwd = EXIT_DIR.Unit

-- 문 기준 좌표계 G: 원점 = 문 바닥 가운데, -Z(LookVector) = 굴 안쪽, +Z = 방 쪽, +X = 오른쪽
-- 바닥 높이는 실제 지형 표면에 맞춘다 (방 바닥 y보다 지형이 1~2 높게 덮여 있음)
local gateFloor = center + fwd * (R - 1)
local floorHit = workspace:Raycast(gateFloor + Vector3.new(0, 4, 0), Vector3.new(0, -10, 0), terrainOnly)
if floorHit then gateFloor = Vector3.new(gateFloor.X, floorHit.Position.Y, gateFloor.Z) end
-- 지형 칸(4스터드) 경계에 맞춰야 바닥이 평평하게 채워진다 (안 맞추면 바닥이 1~2 솟아 레일이 묻힘)
gateFloor = Vector3.new(gateFloor.X, math.floor(gateFloor.Y / 4 + 0.5) * 4, gateFloor.Z)
local G = CFrame.lookAt(gateFloor, gateFloor + fwd)
local function L(x, y, z) return G * CFrame.new(x, y, z) end

-- 비탈: 문 뒤 평지 FLAT 다음, RAMP 길이 동안 RISE만큼 올라 지표에 닿는다
local RISE = SURFACE_Y - gateFloor.Y
local FLAT = 7
local RAMP = math.max(36, RISE / math.tan(math.rad(22))) -- 22도 정도 (걸어 오르기 편하게)
local Z_TOP = -(FLAT + RAMP) -- 비탈이 끝나는 z (여기서 바닥 = 지표)
local PITCH = math.atan2(RISE, RAMP)
local function floorAt(z: number): number -- 문 기준 z에서 굴 바닥 높이
	if z > -FLAT then return 0 end
	if z < Z_TOP then return RISE end
	return (-z - FLAT) / RAMP * RISE
end
-- 비탈 위 한 점의 CFrame (비탈을 따라 기울임)
local function onRamp(x: number, up: number, z: number): CFrame
	return L(x, floorAt(z), z) * CFrame.Angles(PITCH, 0, 0) * CFrame.new(0, up, 0)
end
local MOUTH_Z = Z_TOP - 6 -- 동굴 아가리 문틀 자리 (지표 위)

-- 굴 크기: 좁아 보이지 않게 넉넉히 (사람 키 약 5)
local W = 16 -- 굴 폭
local H = 12 -- 굴 높이
-- 문 자리 천장 한계: 지표 바로 아래 잔디 칸(top~0)은 남긴다
local CEIL = math.min(H + 3, (M.top - 1) - gateFloor.Y)

local rec = CHS:TryBeginRecording("BuildMineExit")
local old = root:FindFirstChild("ExitGate")
if old then old:Destroy() end
local model = Instance.new("Model")
model.Name = "ExitGate"

-- 1) 지형: 채우기를 먼저 다 하고 파기를 나중에 (채우기가 판 굴을 다시 막지 않게) -----------
local floorMat = Enum.Material.Ground
local h0 = workspace:Raycast(center + Vector3.new(0, 2, 0), Vector3.new(0, -8, 0), terrainOnly)
if h0 then floorMat = h0.Material end
local rot = G - G.Position
local rampMid = -(FLAT + RAMP / 2)
local rampLen = math.sqrt(RAMP * RAMP + RISE * RISE) + 4

-- 채우기
-- (a) 문 위쪽 잔디 칸(top~0): 예전 실행에서 너무 높게 판 자리 메우기
T:FillBlock(CFrame.new(gateFloor.X, M.top / 2, gateFloor.Z) * rot * CFrame.new(0, 0, -2), Vector3.new(W + 12, -M.top, 22), Enum.Material.Grass)
-- (b) 지표 위 바위 언덕 (풀밭에서 솟은 둔덕).
-- 비탈 천장(바닥 + H)이 지표 위로 올라오는 구간 전체를 덮어야 굴 지붕이 남는다.
-- 안 덮으면 지붕 없는 도랑이 돼서 풀밭으로 뛰어나갈 수 있다. 언덕 꼭대기 ≈ 지표 + H + 4
local hillFrom = math.min(0, -(FLAT + RAMP * (RISE - H - 2) / RISE) + 6) -- 천장이 지표에 닿는 z (+여유)
local mound = L(0, RISE, MOUTH_Z + 3)
for z = hillFrom, MOUTH_Z + 3, -6 do
	T:FillBall(L(0, RISE + 3, z).Position, W / 2 + 8, Enum.Material.Rock)
end
T:FillBall(mound.Position, W / 2 + 10, Enum.Material.Rock)
T:FillBall((mound * CFrame.new(W / 2, 3, 5)).Position, 9, Enum.Material.Rock)
T:FillBall((mound * CFrame.new(-W / 2, 2, 4)).Position, 9, Enum.Material.Rock)
-- (c) 굴 바닥: 예전 평평한 굴(바닥 0)을 비탈 아래로 메움
T:FillBlock(L(0, -2, -(FLAT / 2) + 1), Vector3.new(W + 4, 4, FLAT + 2), floorMat)
T:FillBlock(onRamp(0, -4, rampMid), Vector3.new(W + 4, 8, rampLen), floorMat)
-- (d) 아가리 앞 풀밭 바닥 고르기
T:FillBlock(L(0, RISE - 2, MOUTH_Z - 7), Vector3.new(W + 8, 4, 16), Enum.Material.Grass)
task.wait()

-- 파기
-- (e) 문 앞 공간: 방 가장자리 천장이 낮아서 문틀이 들어가게 넓고 높게
T:FillBlock(L(0, CEIL / 2, 2), Vector3.new(W + 10, CEIL, 9), AIR)
-- (f) 굴: 평지 + 비탈
local h1 = math.min(H, CEIL)
T:FillBlock(L(0, h1 / 2, -(FLAT / 2) + 1), Vector3.new(W, h1, FLAT + 2), AIR)
T:FillBlock(onRamp(0, H / 2, rampMid), Vector3.new(W, H, rampLen), AIR)
-- (g) 언덕을 관통하는 아가리 통로 + 아가리 앞 트임
T:FillBlock(L(0, RISE + H / 2, MOUTH_Z + 4), Vector3.new(W, H, 22), AIR)
T:FillBlock(L(0, RISE + H / 2 + 1, MOUTH_Z - 10), Vector3.new(W + 8, H + 2, 12), AIR)
task.wait(0.2) -- 방금 바꾼 지형이 레이캐스트에 반영되도록

-- 2) 파트 도우미 ------------------------------------------------------------------
local WOOD = Color3.fromRGB(135, 95, 60)
local WOOD_DARK = Color3.fromRGB(88, 60, 40)
local IRON = Color3.fromRGB(62, 62, 68)
local STEEL = Color3.fromRGB(170, 175, 185)

local function part(name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material, collide: boolean?, shape: Enum.PartType?)
	local p = Instance.new("Part")
	p.Name = name
	if shape then p.Shape = shape end
	p.Size, p.CFrame = size, cf
	p.Anchored = true
	p.CanCollide = collide == true
	p.Color, p.Material = color, mat
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

-- 3) 문틀: 방 쪽 문, 굴 안 문, 지표 아가리 문 --------------------------------------
local function frame(base: CFrame, half: number, h: number)
	for _, s in { -1, 1 } do
		part("GatePost", Vector3.new(1.6, h, 1.6), base * CFrame.new(s * half, h / 2, 0), WOOD, Enum.Material.Wood, true)
		part("PostBand", Vector3.new(1.75, 0.35, 1.75), base * CFrame.new(s * half, 1.2, 0), IRON, Enum.Material.Metal)
		local a = Vector3.new(s * half, h - 3, 0)
		local b = Vector3.new(s * (half - 3), h - 0.2, 0)
		part("GateBrace", Vector3.new(0.7, 0.7, (b - a).Magnitude), base * CFrame.lookAt((a + b) / 2, b), WOOD_DARK, Enum.Material.Wood)
	end
	part("GateBeam", Vector3.new(half * 2 + 3, 1.4, 1.8), base * CFrame.new(0, h + 0.5, 0), WOOD, Enum.Material.Wood, true)
	for i = -3, 3 do
		part("BeamCog", Vector3.new(0.7, 0.6, 2.1), base * CFrame.new(i * (half / 3.2), h + 1.5, 0), WOOD_DARK, Enum.Material.Wood)
	end
end
-- 문 높이: 문 자리 천장(CEIL) 아래에 들보·토막까지 들어가게
local GATE_H = math.min(H - 1.5, CEIL - 2.2)
frame(L(0, 0, 0), W / 2 - 0.5, GATE_H)
frame(L(0, 0, -5), W / 2 - 1.2, GATE_H - 0.5)
frame(L(0, RISE, MOUTH_Z), W / 2 - 1, H - 2)

-- 4) 간판 ------------------------------------------------------------------------
local function label(board: BasePart, face: Enum.NormalId, ppS: number, lines: { { any } })
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = ppS
	gui.LightInfluence = 0.3
	local y = 0
	for _, ln in lines do
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Position = UDim2.fromScale(0, y)
		t.Size = UDim2.fromScale(1, ln[2])
		t.Font = ln[3]
		t.TextScaled = true
		t.TextColor3 = Color3.fromRGB(255, 238, 205)
		t.Text = ln[1]
		t.Parent = gui
		y += ln[2]
	end
	gui.Parent = board
end
-- 방 쪽 문 들보 명판 (파트 뒷면 +Z = 방 쪽)
local plaque = part("Sign", Vector3.new(4.6, 1.15, 0.25), L(0, GATE_H + 0.5, 1.02), WOOD_DARK, Enum.Material.Wood)
label(plaque, Enum.NormalId.Back, 60, { { "출구", 1, Enum.Font.GothamBold } })
for _, s in { -1, 1 } do
	part("SignBolt", Vector3.new(0.3, 0.3, 0.15), L(s * 2.05, GATE_H + 0.5, 1.18), Color3.fromRGB(240, 190, 60), Enum.Material.Metal)
end
-- 방에서 문을 볼 때 왼쪽 표지판, 화살표가 문을 가리킴
part("SignPost", Vector3.new(0.6, 6.2, 0.6), L(-(W / 2 + 2), 3.1, 7.5), WOOD, Enum.Material.Wood, true)
local arrowBoard = part("SignBoard", Vector3.new(5.2, 2.4, 0.3), L(-(W / 2 + 1.2), 5.2, 7.85), WOOD, Enum.Material.Wood)
label(arrowBoard, Enum.NormalId.Back, 50, { { "출구 →", 0.6, Enum.Font.GothamBold }, { "허브로 돌아가기", 0.4, Enum.Font.Gotham } })

-- 5) 레일 (문 안쪽 평지에만) -----------------------------------------------------------
-- 지형 바닥이 칸 경계 때문에 조금씩 울퉁불퉁해서, 침목마다 실제 바닥 높이를 재서 얹는다
for z = 3, -5, -2 do
	local top = G:PointToWorldSpace(Vector3.new(0, 4, z))
	local hit = workspace:Raycast(top, Vector3.new(0, -8, 0), terrainOnly)
	local y = hit and (hit.Position.Y - gateFloor.Y) or 0
	part("Sleeper", Vector3.new(3.6, 0.3, 0.8), L(0, y + 0.1, z), WOOD_DARK, Enum.Material.Wood)
	for _, s in { -1, 1 } do
		part("Rail", Vector3.new(0.3, 0.35, 2.05), L(s * 1.15, y + 0.4, z), STEEL, Enum.Material.Metal)
	end
end

-- 6) 횃불: 벽에 레이를 쏴서 표면에 붙인다. 원점 로컬 +X = 벽에서 밖으로 ----------------
-- (tools/build_cave_entrance.luau의 buildTorch를 간추린 것)
local VERT = CFrame.Angles(0, 0, math.rad(90))
local function torch(origin: CFrame)
	local t = Instance.new("Model")
	t.Name = "WallTorch"
	local function mk(name, size, cf, color, mat, shape)
		local p = part(name, size, cf, color, mat, false, shape)
		p.CastShadow = false
		p.Parent = t
		return p
	end
	mk("Plate", Vector3.new(0.25, 2.4, 1.2), origin * CFrame.new(0.12, 0, 0), IRON, Enum.Material.Metal)
	mk("Arm", Vector3.new(1.4, 0.2, 0.2), origin * CFrame.new(0.95, 0.55, 0), IRON, Enum.Material.Metal)
	mk("Ring", Vector3.new(0.22, 0.85, 0.85), origin * CFrame.new(1.75, 0.55, 0) * VERT, IRON, Enum.Material.Metal, Enum.PartType.Cylinder)
	local base = origin * CFrame.new(1.75, -0.9, 0) * CFrame.Angles(0, 0, math.rad(-8))
	mk("Handle", Vector3.new(2.6, 0.3, 0.3), base * CFrame.new(0, 0.9, 0) * VERT, Color3.fromRGB(92, 58, 34), Enum.Material.Wood, Enum.PartType.Cylinder)
	local top = base * CFrame.new(0, 2.35, 0)
	mk("Cloth", Vector3.new(0.7, 0.6, 0.6), top * CFrame.new(0, 0.3, 0) * VERT, Color3.fromRGB(205, 186, 150), Enum.Material.Fabric, Enum.PartType.Cylinder)
	local head = mk("Ember", Vector3.new(0.12, 0.5, 0.5), top * CFrame.new(0, 0.75, 0) * VERT, Color3.fromRGB(255, 140, 50), Enum.Material.Neon, Enum.PartType.Cylinder)
	local f = Instance.new("Fire")
	f.Size, f.Heat = 2.5, 7
	f.Color, f.SecondaryColor = Color3.fromRGB(255, 150, 60), Color3.fromRGB(255, 220, 120)
	f.Parent = head
	local pl = Instance.new("PointLight")
	pl.Range, pl.Brightness, pl.Color = 20, 1.5, Color3.fromRGB(255, 180, 100)
	pl.Parent = head
	t.Parent = model
end
local torchCount = 0
local function torchOnWall(fromLocal: Vector3, towardLocal: Vector3)
	local from = G:PointToWorldSpace(fromLocal)
	local dir = G:VectorToWorldSpace(towardLocal).Unit
	local h = workspace:Raycast(from, dir * 12, terrainOnly)
	if not h then return end
	local out = Vector3.new(h.Normal.X, 0, h.Normal.Z)
	if out.Magnitude < 0.2 then return end
	torch(CFrame.fromMatrix(h.Position, out.Unit, Vector3.yAxis))
	torchCount += 1
end
for _, s in { -1, 1 } do
	torchOnWall(Vector3.new(s * (W / 2 + 2.5), 5.5, 3), Vector3.new(0, 0, -1)) -- 방 쪽 문 양옆
	for _, z in { -14, -26, -38, -50 } do
		if z > Z_TOP then torchOnWall(Vector3.new(0, floorAt(z) + 5.5, z), Vector3.new(s, 0, 0)) end -- 비탈 양쪽 벽
	end
end

-- 7) 출구 판정과 막는 벽 -----------------------------------------------------------
local backup = SS:FindFirstChild("OldExitBackup") or Instance.new("Folder")
backup.Name = "OldExitBackup"
backup.Parent = SS
for _, c in pad:GetChildren() do
	if c:IsA("BillboardGui") then c.Parent = backup end
end
-- 아가리 문 바로 안쪽에서 굴 단면 전체를 덮는 투명 상자: 누구든 지나가면 닿게 됨
pad.Size = Vector3.new(W, H, 3)
pad.CFrame = L(0, RISE + H / 2, MOUTH_Z + 3)
pad.Transparency = 1
pad.CanCollide, pad.CanQuery, pad.CastShadow = false, false, false
if not CS:HasTag(pad, "MineExit") then CS:AddTag(pad, "MineExit") end
-- 판정을 놓쳐도 풀밭으로 못 나가게 아가리 바로 바깥에 투명 벽
local wall = part("ExitBlocker", Vector3.new(W + 6, H + 4, 1), L(0, RISE + H / 2 + 1, MOUTH_Z - 2), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, true)
wall.Transparency, wall.CanQuery = 1, false

model:SetAttribute("MineId", MINE_ID)
model.Parent = root
if rec then CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
print(("[MineExit] %s 출구 완성: 비탈 %.0f스터드로 %.1f 올라감, 횃불 %d개, 아가리 %s"):format(
	MINE_ID, RAMP, RISE, torchCount, tostring(L(0, RISE, MOUTH_Z).Position)))
