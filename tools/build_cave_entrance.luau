--[[
	광산 입구 산 + 거대한 동굴 입구를 짓는 스크립트 (Studio 명령창에서 실행)

	허브 절벽 벽 자리에 뾰족한 봉우리가 솟은 산을 쌓고, 앞면 절벽 아래에 깔때기 모양의 거대한 동굴 입구를 뚫는다.
	입구 양옆 화로, 사슬에 매단 대형 표지판, 안쪽 갱도 문틀·레일·광차·등불을 배치하고,
	안쪽 어둠 속에 이동 판정(태그 "MinePortal")을 둔다. (이동 처리: src/server/Mining/MineTravel.server.luau)

	먼저 tools/build_hub_cliffs.luau 로 허브 절벽 링을 만든 뒤 실행한다.

	MINE_ID   광산 id (Shared.Config.Mines)
	MOUTH     입구 바닥 중심 = 산 앞면 위치 (월드 좌표)
	FACING    입구가 바라보는 방향(도). 0이면 +Z 쪽(허브)을 바라봄
	THEME     "basic" | "lava" (아래 THEMES)
	PEAK      가장 높은 봉우리 높이
	SEED      산 모양 랜덤

	주의: 허브 경계벽(Hub/Boundary)은 절벽 안쪽 면에서 약 37 뒤에 있다.
	      이동 판정은 그보다 앞(FIELD_DEPTH)에 둬야 걸어 들어갈 수 있다.
	BUILD_TERRAIN  false면 지형(산·입구)은 그대로 두고 장식만 다시 배치한다.
	장식은 레이로 실제 바닥·벽을 찾아 그 위에 붙인다 (지형 표면 높이는 칸 단위라 계산값과 다르다).
	같은 MINE_ID로 다시 실행하면 지형은 덮어쓰고 장식 파트는 다시 만든다.
]]

local MINE_ID = "basic"
local MOUTH = Vector3.new(0, 0, 38)
local FACING = 0
local THEME = "basic"
local PEAK = 220
local SEED = 21
local BUILD_TERRAIN = true

local THEMES = {
	basic = {
		body = Enum.Material.Rock, accent = Enum.Material.Slate, low = Enum.Material.Grass,
		top = Enum.Material.Snow, topFrom = 150, floor = Enum.Material.Ground,
		light = Color3.fromRGB(255, 175, 95), fire = true,
	},
	lava = {
		body = Enum.Material.Basalt, accent = Enum.Material.CrackedLava, low = Enum.Material.Basalt,
		top = Enum.Material.CrackedLava, topFrom = 170, floor = Enum.Material.Basalt,
		light = Color3.fromRGB(255, 90, 40), fire = true,
	},
}

local RS = game:GetService("ReplicatedStorage")
local CS = game:GetService("CollectionService")
local CHS = game:GetService("ChangeHistoryService")
local Mines = require(RS.Shared.Config.Mines)
local M = assert(Mines.get(MINE_ID), "Mines 설정에 없는 id")
local TH = assert(THEMES[THEME], "없는 테마")

local T = workspace.Terrain
local rng = Random.new(SEED)
local CF = CFrame.new(MOUTH) * CFrame.Angles(0, math.rad(FACING), 0)
local ROT = CF.Rotation
local function W(x, y, z) return CF:PointToWorldSpace(Vector3.new(x, y, z)) end

local ops = 0
local function tick() ops += 1 if ops % 30 == 0 then task.wait() end end

-- 로컬 좌표: +z = 허브 쪽, z=0 = 산 앞면(입구), -z = 산 속
local HALF_W = 150          -- 산 좌우 반폭
local BACK = -175           -- 산 뒤 끝
local FACE_H = 72           -- 앞면 절벽 높이
local FACE_SLOPE = 2.3      -- 앞면에서 뒤로 갈수록 오르는 기울기
local STEP = 4

-- 입구 크기 (앞 → 안쪽으로 좁아짐)
local MW, MH = 46, 56       -- 앞 아가리 폭·높이
local TW, TH2 = 26, 22      -- 안쪽 갱도 폭·높이
local LENGTH = 56           -- 입구 깊이
local FIELD_DEPTH = 30      -- 이동 판정 위치 (경계벽보다 앞)
local RAIL_X = -9           -- 레일·광차는 한쪽으로 (가운데는 사람이 지나가는 길)

local rec = CHS:TryBeginRecording("BuildMineMountain " .. MINE_ID)

if BUILD_TERRAIN then
-- 1) 봉우리 배치 -------------------------------------------------------------
local peaks = { { x = rng:NextNumber(-15, 15), z = -95, h = PEAK, r = 150 } }
for i = 1, 7 do
	local side = (i % 2 == 0) and 1 or -1
	table.insert(peaks, {
		x = side * rng:NextNumber(30, HALF_W - 25),
		z = rng:NextNumber(BACK + 30, -35),
		h = PEAK * rng:NextNumber(0.5, 0.85),
		r = rng:NextNumber(80, 130),
	})
end

local function ridged(x, z)
	-- 능선 노이즈 (0~1, 뾰족한 등성이)
	local n = 1 - math.abs(math.noise(x / 55, z / 55, SEED))
	local n2 = 1 - math.abs(math.noise(x / 21, z / 21, SEED + 9))
	return n * n * 0.7 + n2 * 0.3
end

local function heightAt(x, z)
	local h = 0
	for _, p in peaks do
		local d = math.sqrt((x - p.x) ^ 2 + (z - p.z) ^ 2)
		if d < p.r then
			h = math.max(h, p.h * (1 - d / p.r) ^ 1.35)
		end
	end
	h = h * (0.75 + 0.45 * ridged(x, z)) + math.noise(x / 9, z / 9, SEED + 3) * 4
	-- 앞면: 깎아지른 절벽에서 시작해 뒤로 오름
	h = math.min(h, FACE_H + (-z) * FACE_SLOPE + math.noise(x / 14, 3, SEED) * 8)
	-- 좌우·뒤 가장자리는 낮게
	h = math.min(h, 24 + (HALF_W - math.abs(x)) * 2.2, 24 + (z - BACK) * 2.2)
	return math.max(h, 36)
end

-- 2) 산 쌓기 -----------------------------------------------------------------
for x = -HALF_W, HALF_W, STEP do
	for z = BACK, 0, STEP do
		local h = heightAt(x, z)
		T:FillBlock(CFrame.new(W(x, h / 2 - 6, z)) * ROT, Vector3.new(STEP, h + 12, STEP), TH.body); tick()
		if h >= TH.topFrom then
			T:FillBlock(CFrame.new(W(x, h - 3, z)) * ROT, Vector3.new(STEP, 6, STEP), TH.top); tick()
		elseif h < 70 then
			T:FillBlock(CFrame.new(W(x, h - 1, z)) * ROT, Vector3.new(STEP, 3, STEP), TH.low); tick()
		end
	end
end
-- 바위 띠 (색이 다른 층). 앞면 가까이는 둥근 덩어리로 튀어나와 어색하므로 산 속 깊은 곳에만
for i = 1, 60 do
	local x, z = rng:NextNumber(-HALF_W + 10, HALF_W - 10), rng:NextNumber(BACK + 15, -40)
	T:FillBall(W(x, heightAt(x, z) * rng:NextNumber(0.4, 0.85), z), rng:NextNumber(6, 12), TH.accent); tick()
end

-- 3) 앞면 절벽 다듬기 (입구 둘레는 비움) -----------------------------------------
for i = 1, 140 do
	local x = rng:NextNumber(-HALF_W + 6, HALF_W - 6)
	local y = rng:NextNumber(4, FACE_H + 10)
	local nearMouth = math.abs(x) < MW / 2 + 10 and y < MH + 12
	if not nearMouth then
		T:FillBall(W(x, y, rng:NextNumber(-1, 4)), rng:NextNumber(4, 9), TH.body); tick()
	end
end
-- 입구 위 처마 바위
for i = 1, 9 do
	local a = (i - 1) / 8 * math.pi
	T:FillBall(W(math.cos(a) * (MW / 2 + 3), math.sin(a) * (MH - MW / 2) + MW / 2 * math.sin(a) + 6, rng:NextNumber(2, 5)), rng:NextNumber(5, 8), TH.body); tick()
end

-- 4) 거대한 입구 뚫기 (깔때기) ---------------------------------------------------
local function carveSlice(z, w, h)
	-- 아래 네모 + 위 반원 (아치)
	local boxH = math.max(2, h - w / 2)
	T:FillBlock(CFrame.new(W(0, boxH / 2 - 1, z)) * ROT, Vector3.new(w, boxH + 2, 2.5), Enum.Material.Air)
	T:FillCylinder(CFrame.new(W(0, boxH - 1, z)) * ROT * CFrame.Angles(math.rad(90), 0, 0), 2.5, w / 2, Enum.Material.Air)
	tick()
end
for z = 12, -LENGTH, -2 do
	local t = math.clamp(-z / LENGTH, 0, 1)
	local k = t ^ 0.6
	carveSlice(z, MW + (TW - MW) * k, MH + (TH2 - MH) * k)
end
-- 바닥 (흙길)
T:FillBlock(CFrame.new(W(0, -3, (14 - LENGTH) / 2)) * ROT, Vector3.new(MW + 6, 6, LENGTH + 14), TH.floor)
-- 아가리 앞 바닥에 흩어진 바위
for i = 1, 8 do
	local s = (i % 2 == 0) and 1 or -1
	T:FillBall(W(s * rng:NextNumber(MW / 2 - 4, MW / 2 + 10), rng:NextNumber(-1, 2), rng:NextNumber(2, 14)), rng:NextNumber(2.5, 5), TH.body)
end
task.wait()

end

-- 5) 장식 ---------------------------------------------------------------------
local hub = workspace.CollapseMine.Hub
local portals = hub:FindFirstChild("MinePortals") or Instance.new("Folder")
portals.Name = "MinePortals"; portals.Parent = hub
local old = portals:FindFirstChild("Portal_" .. MINE_ID)
if old then old:Destroy() end
local model = Instance.new("Model")
model.Name = "Portal_" .. MINE_ID

-- 지형만 맞는 레이 (장식 파트는 무시)
local terrainOnly = RaycastParams.new()
terrainOnly.FilterType = Enum.RaycastFilterType.Include
terrainOnly.FilterDescendantsInstances = { T }
-- 바닥 높이(로컬 y): 위에서 아래로 쏴서 첫 지형
local function floorY(x, z, from)
	local o = W(x, from or 14, z)
	local h = workspace:Raycast(o, Vector3.new(0, -60, 0), terrainOnly)
	return h and (h.Position.Y - MOUTH.Y) or 0
end
-- 입구 중심선에서 옆(side=±1)으로 쏴서 벽까지 거리
local function wallDist(z, y, side)
	local o = W(0, y, z)
	local dir = ROT:VectorToWorldSpace(Vector3.new(side, 0, 0))
	local h = workspace:Raycast(o, dir * 60, terrainOnly)
	return h and h.Distance or 30
end
-- 바닥에서 위로 쏴서 천장 높이(로컬 y)
local function ceilY(x, z, fromY)
	local o = W(x, fromY, z)
	local h = workspace:Raycast(o, Vector3.new(0, 120, 0), terrainOnly)
	return h and (h.Position.Y - MOUTH.Y) or 200
end

local function part(name, size, x, y, z, color, mat, shape, extraRot)
	local p = Instance.new("Part")
	p.Name = name
	if shape then p.Shape = shape end
	p.Size = size
	p.CFrame = CFrame.new(W(x, y, z)) * ROT * (extraRot or CFrame.identity)
	p.Anchored = true
	p.Color = color
	p.Material = mat
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end
local wood = Color3.fromRGB(105, 72, 44)
local woodDark = Color3.fromRGB(74, 50, 32)
local iron = Color3.fromRGB(70, 70, 76)
local stone = Color3.fromRGB(110, 106, 100)

local function light(p, range, bright)
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness, l.Shadows = TH.light, range, bright, true
	l.Parent = p
end

-- 화로 (입구 양옆): 자리를 비우고 바닥 위에 세움
for _, s in ipairs({ -1, 1 }) do
	local x, z = s * (MW / 2 + 9), 10
	local g0 = floorY(x, z, 40)
	T:FillCylinder(CFrame.new(W(x, g0 + 14, z)), 26, 6, Enum.Material.Air)
	local g = floorY(x, z, 40)
	part("BrazierBase", Vector3.new(6, 4, 6), x, g + 2, z, stone, Enum.Material.Cobblestone)
	part("BrazierPillar", Vector3.new(3, 9, 3), x, g + 8.5, z, stone, Enum.Material.Cobblestone)
	part("BrazierBowl", Vector3.new(3, 7, 7), x, g + 14, z, iron, Enum.Material.Metal, Enum.PartType.Cylinder, CFrame.Angles(0, 0, math.rad(90)))
	local coal = part("Embers", Vector3.new(5.5, 1, 5.5), x, g + 15.2, z, Color3.fromRGB(255, 120, 40), Enum.Material.Neon)
	if TH.fire then
		local f = Instance.new("Fire")
		f.Size, f.Heat = 10, 14
		f.Color, f.SecondaryColor = TH.light, Color3.fromRGB(255, 220, 120)
		f.Parent = coal
	end
	light(coal, 55, 2.4)
end

-- 레일 + 침목: 4스터드 토막마다 바닥 높이에 맞춤 (안쪽으로 갈수록 좁아지는 벽에 닿지 않게 x를 당김)
for z = 24, -LENGTH + 4, -4 do
	local g = floorY(RAIL_X, z)
	local maxX = wallDist(z, g + 2, RAIL_X < 0 and -1 or 1) - 5
	local rx = math.sign(RAIL_X) * math.min(math.abs(RAIL_X), maxX)
	for _, dx in ipairs({ -2.2, 2.2 }) do
		part("Rail", Vector3.new(0.5, 0.5, 4.3), rx + dx, g + 0.55, z, Color3.fromRGB(95, 95, 102), Enum.Material.Metal)
	end
	part("Sleeper", Vector3.new(6.4, 0.4, 1.2), rx, g + 0.2, z, woodDark, Enum.Material.Wood)
	part("Sleeper", Vector3.new(6.4, 0.4, 1.2), rx, g + 0.2, z - 2, woodDark, Enum.Material.Wood)
end

-- 광차
do
	local z0 = 17
	local g = floorY(RAIL_X, z0)
	local cart = Instance.new("Model"); cart.Name = "MineCart"; cart.Parent = model
	local function cp(name, size, x, y, z, color, mat, shape)
		local p = part(name, size, x, g + y, z, color, mat, shape); p.Parent = cart; return p
	end
	cp("CartBody", Vector3.new(5, 3, 7), RAIL_X, 3.1, z0, Color3.fromRGB(95, 70, 50), Enum.Material.WoodPlanks)
	cp("CartRim", Vector3.new(5.4, 0.5, 7.4), RAIL_X, 4.7, z0, iron, Enum.Material.Metal)
	for _, x in ipairs({ RAIL_X - 2.5, RAIL_X + 2.5 }) do
		for _, dz in ipairs({ -2, 2 }) do
			cp("Wheel", Vector3.new(0.6, 2, 2), x, 1.5, z0 + dz, iron, Enum.Material.Metal, Enum.PartType.Cylinder)
		end
	end
	for _ = 1, 5 do
		local o = cp("CartOre", Vector3.new(1.6, 1.4, 1.6), RAIL_X + rng:NextNumber(-1.5, 1.5), 5.1, z0 + rng:NextNumber(-2.5, 2.5), Color3.fromRGB(200, 115, 60), Enum.Material.Metal)
		o.CFrame *= CFrame.Angles(rng:NextNumber(0, 3), rng:NextNumber(0, 3), 0)
	end
end

-- 안쪽 갱도 문틀 2세트: 실제 벽 안쪽, 천장 아래에 맞춤
for _, z in ipairs({ -FIELD_DEPTH + 10, -FIELD_DEPTH + 2 }) do
	local g = floorY(0, z)
	local px = math.min(wallDist(z, g + 6, -1), wallDist(z, g + 6, 1)) - 2.2
	local top = math.min(ceilY(-px, z, g + 2), ceilY(px, z, g + 2))
	local ph = math.clamp(top - g - 3, 8, 30)
	part("GatePost", Vector3.new(3, ph, 3), -px, g + ph / 2, z, wood, Enum.Material.WoodPlanks)
	part("GatePost", Vector3.new(3, ph, 3), px, g + ph / 2, z, wood, Enum.Material.WoodPlanks)
	part("GateBeam", Vector3.new(px * 2 + 3, 3, 3.4), 0, g + ph + 1.2, z, woodDark, Enum.Material.WoodPlanks)
	part("GateBrace", Vector3.new(2, 9, 2), -px + 3, g + ph - 3.2, z, woodDark, Enum.Material.WoodPlanks, nil, CFrame.Angles(0, 0, math.rad(-40)))
	part("GateBrace", Vector3.new(2, 9, 2), px - 3, g + ph - 3.2, z, woodDark, Enum.Material.WoodPlanks, nil, CFrame.Angles(0, 0, math.rad(40)))
end

-- 벽 횃불: 실제 벽에서 조금 띄워서 (나무 받침 + 불)
for z = 6, -LENGTH + 10, -9 do
	local g = floorY(0, z)
	local y = g + 8
	for _, s in ipairs({ -1, 1 }) do
		local d = wallDist(z, y, s)
		if d < 40 then
			local x = s * (d - 1.3)
			part("TorchBracket", Vector3.new(0.6, 3, 0.6), x, y - 1.2, z, woodDark, Enum.Material.Wood, nil, CFrame.Angles(0, 0, math.rad(s * 20)))
			local head = part("TorchHead", Vector3.new(1, 1, 1), x - s * 0.5, y + 0.6, z, Color3.fromRGB(255, 150, 60), Enum.Material.Neon)
			if TH.fire then
				local f = Instance.new("Fire")
				f.Size, f.Heat = 2.5, 6
				f.Color, f.SecondaryColor = TH.light, Color3.fromRGB(255, 220, 120)
				f.Parent = head
			end
			light(head, 22, 1.6)
		end
	end
end

-- 사슬에 매단 대형 표지판 (아가리 천장 아래)
do
	local g = floorY(0, 6)
	local top = ceilY(0, 6, g + 4)
	local signY = math.min(MH - 16, top - 10)
	local sign = part("Sign", Vector3.new(28, 7, 1), 0, signY, 6, wood, Enum.Material.WoodPlanks)
	part("SignFrame", Vector3.new(29.5, 8.5, 0.6), 0, signY, 5.3, woodDark, Enum.Material.WoodPlanks)
	for _, x in ipairs({ -10, 10 }) do
		local cTop = ceilY(x, 6, signY + 4)
		local len = math.max(1, cTop - (signY + 3.5))
		part("Chain", Vector3.new(0.5, len, 0.5), x, signY + 3.5 + len / 2, 6, iron, Enum.Material.DiamondPlate)
	end
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Back
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 30
	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.fromScale(1, 0.66)
	tl.BackgroundTransparency = 1
	tl.TextScaled = true
	tl.Font = Enum.Font.GothamBlack
	tl.TextColor3 = Color3.fromRGB(255, 228, 180)
	tl.TextStrokeTransparency = 0.6
	tl.Text = M.name
	tl.Parent = sg
	local sub = Instance.new("TextLabel")
	sub.Position = UDim2.fromScale(0, 0.64)
	sub.Size = UDim2.fromScale(1, 0.3)
	sub.BackgroundTransparency = 1
	sub.TextScaled = true
	sub.Font = Enum.Font.GothamBold
	sub.TextColor3 = Color3.fromRGB(230, 200, 160)
	sub.Text = "곡괭이 " .. M.requiredPickaxe .. "단계 이상"
	sub.Parent = sg
	sg.Parent = sign
end

-- 이동 판정 + 어둠
do
	local g = floorY(0, -FIELD_DEPTH)
	local wl, wr = wallDist(-FIELD_DEPTH, g + 4, -1), wallDist(-FIELD_DEPTH, g + 4, 1)
	local w = wl + wr + 2
	local h = ceilY(0, -FIELD_DEPTH, g + 2) - g + 1
	local field = part("Field", Vector3.new(w, h, 2), (wr - wl) / 2, g + h / 2, -FIELD_DEPTH, Color3.new(0, 0, 0), Enum.Material.SmoothPlastic)
	field.Transparency = 1
	field.CanCollide = false
	field:SetAttribute("MineId", MINE_ID)
	CS:AddTag(field, "MinePortal")
	model.PrimaryPart = field
	local gv = floorY(0, -LENGTH + 1)
	local veil = part("Darkness", Vector3.new(TW + 6, TH2 + 6, 1), 0, gv + TH2 / 2, -LENGTH + 1, Color3.fromRGB(4, 4, 6), Enum.Material.SmoothPlastic)
	veil.CanCollide = false
end

model.Parent = portals
if rec then CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
print(("[MineMountain] %s 완료 (지형 작업 %d회)"):format(model:GetFullName(), ops))
