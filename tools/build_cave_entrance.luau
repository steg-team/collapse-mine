--[[
	허브에 광산 동굴 입구를 짓는 스크립트 (Studio 명령창에서 실행)

	허브를 향해 열린 U자 절벽을 지형으로 쌓고, 안쪽 절벽 벽에 동굴 입구를 뚫는다.
	입구 안쪽 어둠 속에 이동 판정(태그 "MinePortal")을 둬서 걸어 들어가면 광산으로 이동한다.
	(이동 처리: src/server/Mining/MineTravel.server.luau)

	MINE_ID   광산 id (Shared.Config.Mines)
	MOUTH     동굴 입구 바닥 중심 (월드 좌표)
	FACING    입구가 바라보는 방향(도). 0이면 +Z 쪽(허브 광장)을 바라봄
	SEED      절벽 모양 랜덤

	같은 MINE_ID로 다시 실행하면 이전 입구 장식(파트)은 지우고 다시 만든다. 지형은 덮어쓴다.
]]

local MINE_ID = "basic"
local MOUTH = Vector3.new(0, 0, 40)
local FACING = 0
local SEED = 3

local RS = game:GetService("ReplicatedStorage")
local CS = game:GetService("CollectionService")
local CHS = game:GetService("ChangeHistoryService")
local Mines = require(RS.Shared.Config.Mines)
local M = assert(Mines.get(MINE_ID), "Mines 설정에 없는 id")

local T = workspace.Terrain
local rng = Random.new(SEED)
local CF = CFrame.new(MOUTH) * CFrame.Angles(0, math.rad(FACING), 0)
local function W(x, y, z) return CF:PointToWorldSpace(Vector3.new(x, y, z)) end

local rec = CHS:TryBeginRecording("BuildCaveEntrance " .. MINE_ID)

-- 이전 장식 정리 ---------------------------------------------------------------
local hub = workspace.CollapseMine.Hub
local portals = hub:FindFirstChild("MinePortals") or Instance.new("Folder")
portals.Name = "MinePortals"; portals.Parent = hub
local old = portals:FindFirstChild("Portal_" .. MINE_ID)
if old then old:Destroy() end
local model = Instance.new("Model")
model.Name = "Portal_" .. MINE_ID

-- 1) U자 절벽 ------------------------------------------------------------------
-- 로컬 좌표: +z = 허브 쪽(입구 앞), -z = 절벽 뒤
local INNER_HALF = 26   -- 골짜기 안쪽 폭의 절반
local OUTER_HALF = 50
local BACK = -46        -- 절벽 뒤 끝
local SIDE_FRONT = 24   -- 양옆 절벽이 앞으로 나오는 끝
local STEP = 4

local function inCliff(x, z)
	local ax = math.abs(x)
	if ax > OUTER_HALF or z < BACK then return false end
	if z <= 0 then return true end                         -- 뒤쪽 벽 (입구가 뚫릴 면)
	return ax >= INNER_HALF and z <= SIDE_FRONT            -- 양옆 벽
end

local ops = 0
for x = -OUTER_HALF, OUTER_HALF, STEP do
	for z = BACK, SIDE_FRONT, STEP do
		if inCliff(x, z) then
			-- 안쪽 면에 가까울수록 높고, 바깥·앞 끝은 낮게 비탈
			local n = math.noise(x / 22, z / 22, SEED) * 9 + math.noise(x / 7, z / 7, SEED + 7) * 3
			local edgeOut = math.min(OUTER_HALF - math.abs(x), z - BACK) -- 바깥 가장자리까지 거리
			local h = 34 + n
			h = math.min(h, 10 + edgeOut * 1.6)
			if z > 0 then h = math.min(h, 12 + (SIDE_FRONT - z) * 1.4) end
			h = math.max(h, 6)
			local c = W(x, h / 2 - 2, z)
			T:FillBlock(CFrame.new(c) * CF.Rotation, Vector3.new(STEP, h + 4, STEP), Enum.Material.Rock)
			T:FillBlock(CFrame.new(W(x, h - 0.5, z)) * CF.Rotation, Vector3.new(STEP, 3, STEP), Enum.Material.Grass)
			ops += 1
			if ops % 40 == 0 then task.wait() end
		end
	end
end

-- 안쪽 절벽 면을 울퉁불퉁하게 (튀어나온 바위)
local function bump(x, y, z, r, mat)
	T:FillBall(W(x, y, z), r, mat or Enum.Material.Rock)
end
for i = 1, 90 do
	local side = rng:NextInteger(1, 3)
	local y = rng:NextNumber(2, 28)
	local dent = rng:NextNumber() < 0.3 -- 30%는 파인 홈, 나머지는 튀어나온 바위
	local mat = dent and Enum.Material.Air or Enum.Material.Rock
	local r = dent and rng:NextNumber(2.5, 4.5) or rng:NextNumber(3.5, 7.5)
	if side == 1 then -- 뒤쪽 벽 면 (입구 주변은 비움)
		local x = rng:NextNumber(-INNER_HALF + 2, INNER_HALF - 2)
		if math.abs(x) > 13 or y > 22 then bump(x, y, rng:NextNumber(0, 3) + (dent and 2 or 0), r, mat) end
	else -- 양옆 벽 면
		local s = side == 2 and -1 or 1
		bump(s * (INNER_HALF + rng:NextNumber(-2, 1) - (dent and 2 or 0)), y * 0.8, rng:NextNumber(2, SIDE_FRONT - 3), r, mat)
	end
	if i % 10 == 0 then task.wait() end
end
-- 바위 사이사이 판암 무늬
for i = 1, 14 do
	bump(rng:NextNumber(-OUTER_HALF + 6, OUTER_HALF - 6), rng:NextNumber(8, 28), rng:NextNumber(BACK + 6, -4), rng:NextNumber(4, 7), Enum.Material.Slate)
end

-- 골짜기 바닥은 평평한 잔디로 정리
T:FillBlock(CFrame.new(W(0, -2, SIDE_FRONT / 2 + 2)) * CF.Rotation, Vector3.new(INNER_HALF * 2 - 4, 4, SIDE_FRONT), Enum.Material.Grass)
T:FillBlock(CFrame.new(W(0, 6, SIDE_FRONT / 2 + 3)) * CF.Rotation, Vector3.new(INNER_HALF * 2 - 6, 12, SIDE_FRONT - 2), Enum.Material.Air)

-- 2) 동굴 입구 뚫기 ------------------------------------------------------------
local MOUTH_W, MOUTH_H, DEPTH = 14, 12, 24
-- 절벽 면이 칸 단위로 2~4스터드 앞까지 나오므로 입구는 면 앞(+8)까지 뚫는다
T:FillBlock(CFrame.new(W(0, MOUTH_H / 2 - 1, (8 - DEPTH) / 2)) * CF.Rotation, Vector3.new(MOUTH_W, MOUTH_H, DEPTH + 8), Enum.Material.Air)
for z = 8, -DEPTH, -3 do
	T:FillBall(W(0, MOUTH_H - 3, z), MOUTH_W / 2, Enum.Material.Air) -- 둥근 천장
end
-- 입구 바닥 (흙)
T:FillBlock(CFrame.new(W(0, -2.5, (10 - DEPTH) / 2)) * CF.Rotation, Vector3.new(MOUTH_W + 2, 5, DEPTH + 10), Enum.Material.Ground)

-- 3) 장식 파트 -----------------------------------------------------------------
local function part(name, size, x, y, z, color, mat, rotY)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = CFrame.new(W(x, y, z)) * CF.Rotation * CFrame.Angles(0, math.rad(rotY or 0), 0)
	p.Anchored = true
	p.Color = color
	p.Material = mat
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end
local wood = Color3.fromRGB(105, 72, 44)
local woodDark = Color3.fromRGB(80, 55, 34)
-- 갱도 지지대 (입구 + 안쪽 한 세트)
for _, z in ipairs({4.5, -8}) do
	part("Post", Vector3.new(1.4, 11, 1.4), -5.6, 5.5, z, wood, Enum.Material.WoodPlanks)
	part("Post", Vector3.new(1.4, 11, 1.4), 5.6, 5.5, z, wood, Enum.Material.WoodPlanks)
	part("Beam", Vector3.new(13.5, 1.4, 1.6), 0, 11.4, z, woodDark, Enum.Material.WoodPlanks)
end
-- 레일
for _, x in ipairs({-1.6, 1.6}) do
	part("Rail", Vector3.new(0.3, 0.3, 30), x, 0.15, -6, Color3.fromRGB(90, 90, 95), Enum.Material.Metal)
end
for z = 8, -20, -3 do
	part("Sleeper", Vector3.new(4.6, 0.25, 0.8), 0, 0.02, z, woodDark, Enum.Material.Wood)
end
-- 등불
for _, x in ipairs({-8.5, 8.5}) do
	part("LanternPost", Vector3.new(0.6, 7, 0.6), x, 3.5, 7, woodDark, Enum.Material.Wood)
	local lamp = part("Lantern", Vector3.new(1.4, 1.8, 1.4), x, 7.6, 7, Color3.fromRGB(255, 190, 110), Enum.Material.Neon)
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness, l.Shadows = Color3.fromRGB(255, 180, 100), 22, 1.6, true
	l.Parent = lamp
end
-- 이동 판정: 입구 안쪽 어둠 속 (보이지 않게)
local field = part("Field", Vector3.new(MOUTH_W - 2, MOUTH_H - 1, 2), 0, MOUTH_H / 2 - 0.5, -DEPTH + 6, Color3.new(0, 0, 0), Enum.Material.SmoothPlastic)
field.Transparency = 1
field.CanCollide = false
field:SetAttribute("MineId", MINE_ID)
CS:AddTag(field, "MinePortal")
-- 더 깊어 보이게 하는 검은 막 (판정 뒤)
local veil = part("Darkness", Vector3.new(MOUTH_W + 2, MOUTH_H + 2, 1), 0, MOUTH_H / 2, -DEPTH + 3, Color3.fromRGB(5, 5, 7), Enum.Material.SmoothPlastic)
veil.CanCollide = false
-- 이름 표지판
local sign = part("Sign", Vector3.new(10, 2.6, 0.5), 0, 13.6, 5.4, wood, Enum.Material.WoodPlanks)
local sg = Instance.new("SurfaceGui")
sg.Face = Enum.NormalId.Back
sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
sg.PixelsPerStud = 40
local tl = Instance.new("TextLabel")
tl.Size = UDim2.fromScale(1, 1)
tl.BackgroundTransparency = 1
tl.TextScaled = true
tl.Font = Enum.Font.GothamBlack
tl.TextColor3 = Color3.fromRGB(255, 230, 190)
tl.Text = M.name
tl.Parent = sg
sg.Parent = sign
for _, x in ipairs({-3.5, 3.5}) do
	part("SignRope", Vector3.new(0.2, 1.6, 0.2), x, 15.7, 5.4, woodDark, Enum.Material.Fabric)
end
-- 등급 안내 (가까이 오면 보임)
local bb = Instance.new("BillboardGui")
bb.Size = UDim2.fromOffset(200, 36)
bb.StudsOffset = Vector3.new(0, 3.4, 0)
bb.MaxDistance = 60
local bl = Instance.new("TextLabel")
bl.Size = UDim2.fromScale(1, 1); bl.BackgroundTransparency = 1; bl.TextScaled = true
bl.Font = Enum.Font.GothamBold; bl.TextColor3 = Color3.new(1, 1, 1); bl.TextStrokeTransparency = 0.4
bl.Text = "곡괭이 " .. M.requiredPickaxe .. "단계 이상"
bl.Parent = bb
bb.Parent = sign

model.PrimaryPart = field
model.Parent = portals

if rec then CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
print("[CaveEntrance] " .. model:GetFullName() .. " 생성")
