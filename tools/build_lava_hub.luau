--[[
	4스테이지 용암 광산 허브 (Workspace.CollapseMine_lava) — Studio 명령창에서 실행. T-006

	1~3스테이지 허브는 기본 허브를 통째로 복사했지만(copy_stage_hub.luau), 용암 광산은 허브를 더 크게 하려고
	지형은 새로 짓고 건물만 기본 허브에서 복사해 넓게 다시 놓는다.

	순서
	  1) 이 스크립트 → 분지 바닥·절벽(현무암, 꼭대기 붉은 균열)·용암 웅덩이·경계벽·건물
	  2) tools/build_cave_entrance.luau (MINE_ID "lava", MOUTH (1800,0,38), THEME "lava", HUB_NAME "CollapseMine_lava")
	     → 남쪽 벽에 산과 동굴 아가리, 포탈
	  3) tools/generate_mine.luau (MINE_ID "lava") → tools/build_mine_exit.luau (MINE_ID "lava")

	크기: 분지 안쪽 반폭 88×52 → 116×66 (남쪽 벽은 입구 z 38에 그대로 맞추고 북·동·서로 넓힘)
	건물 배치는 기본 허브 배치를 입구(z 38)를 기준으로 가로 1.3배, 세로 1.27배로 벌린 자리
	같은 설정으로 다시 실행하면 지형은 덮어쓰고, 예전 허브 폴더는 ServerStorage로 옮긴다(_old).
]]

local MINE_ID = "lava"
local HUB_X = 1800
local CENTER = Vector3.new(HUB_X, 0, 104)
local HALF_X, HALF_Z = 116, 66
local THICK = 44
local HEIGHT = 54
local POWER = 4
local STEP = 4
local SEED = 41
local SPREAD_X, SPREAD_Z, ANCHOR_Z = 1.3, 1.27, 38

local CHS = game:GetService("ChangeHistoryService")
local SS = game:GetService("ServerStorage")
local T = workspace.Terrain
local rng = Random.new(SEED)
local M = Enum.Material

local ops = 0
local function tick() ops += 1 if ops % 40 == 0 then task.wait() end end

local function shape(x: number, z: number)
	local dx, dz = x - CENTER.X, z - CENTER.Z
	local s = math.abs(dx / HALF_X) ^ POWER + math.abs(dz / HALF_Z) ^ POWER
	local r = s ^ (1 / POWER)
	local len = math.sqrt(dx * dx + dz * dz)
	local dOut = (r > 0) and len * (1 - 1 / r) or -math.huge
	return r, dOut
end
local function boundaryPoint(t: number)
	local c, s = math.cos(t), math.sin(t)
	local k = (math.abs(c / HALF_X) ^ POWER + math.abs(s / HALF_Z) ^ POWER) ^ (-1 / POWER)
	return CENTER.X + c * k, CENTER.Z + s * k, c, s
end

local rec = CHS:TryBeginRecording("BuildLavaHub")

-- 0) 예전 허브 폴더 치우기 -------------------------------------------------------
local name = "CollapseMine_" .. MINE_ID
local old = workspace:FindFirstChild(name)
if old then
	old.Name = name .. "_old"
	old.Parent = SS
end
local root = Instance.new("Folder")
root.Name = name
root:SetAttribute("MineId", MINE_ID)
local hub = Instance.new("Folder")
hub.Name = "Hub"
hub.Parent = root

-- 1) 지형: 바닥 + 절벽 ------------------------------------------------------------
local minX, maxX = CENTER.X - HALF_X - THICK - 8, CENTER.X + HALF_X + THICK + 8
local minZ, maxZ = CENTER.Z - HALF_Z - THICK - 8, CENTER.Z + HALF_Z + THICK + 8
for x = minX, maxX, STEP do
	for z = minZ, maxZ, STEP do
		local r, dOut = shape(x, z)
		if r < 1 then
			-- 분지 안: 위는 비우고 바닥은 현무암, 군데군데 판암
			T:FillBlock(CFrame.new(x, 50, z), Vector3.new(STEP, 100, STEP), M.Air); tick()
			local n = math.noise(x / 18, z / 18, SEED)
			T:FillBlock(CFrame.new(x, -6, z), Vector3.new(STEP, 12, STEP), (n > 0.35) and M.Slate or M.Basalt); tick()
		elseif dOut <= THICK then -- r >= 1: 절벽
			local n = math.noise(x / 26, z / 26, SEED) * 12 + math.noise(x / 8, z / 8, SEED + 3) * 3
			local h = HEIGHT + n
			h = math.min(h, 10 + (THICK - dOut) * 2.4) -- 바깥쪽은 비탈
			h = math.max(h, 8)
			T:FillBlock(CFrame.new(x, h / 2 - 6, z), Vector3.new(STEP, h + 12, STEP), M.Basalt); tick()
			-- 꼭대기는 식은 용암 균열 (붉게 빛남)
			T:FillBlock(CFrame.new(x, h - 1, z), Vector3.new(STEP, 3, STEP), M.CrackedLava); tick()
		end
	end
end

-- 2) 안쪽 벽: 튀어나온 바위 + 벽을 타고 흘러내린 용암 줄기 -----------------------
for _ = 1, 200 do
	local bx, bz, c, s = boundaryPoint(rng:NextNumber(0, math.pi * 2))
	local mat = (rng:NextNumber() < 0.3) and M.Slate or M.Basalt
	T:FillBall(Vector3.new(bx + c * rng:NextNumber(0, 3), rng:NextNumber(3, HEIGHT - 4), bz + s * rng:NextNumber(0, 3)), rng:NextNumber(4, 8), mat); tick()
end
local streams = {}
local terrainOnly = RaycastParams.new()
terrainOnly.FilterType = Enum.RaycastFilterType.Include
terrainOnly.FilterDescendantsInstances = { T }
for _ = 1, 12 do
	-- 남쪽 벽(입구 쪽)은 피한다. 실제 벽 면을 레이로 찾아 면에 붙여 흘러내리게 한다
	local t
	repeat t = rng:NextNumber(0, math.pi * 2) until math.sin(t) > -0.45
	local bx, bz, c, s = boundaryPoint(t)
	local y = HEIGHT - rng:NextNumber(2, 10)
	local wob = 0
	while y > 0 do
		local hit = workspace:Raycast(Vector3.new(bx - c * 12, y, bz - s * 12), Vector3.new(c, 0, s) * 30, terrainOnly)
		if hit then
			wob += rng:NextNumber(-0.5, 0.5)
			T:FillBall(hit.Position + Vector3.new(-s * wob, 0, c * wob), 2.2, M.CrackedLava); tick()
		end
		y -= 1.6
	end
	table.insert(streams, Vector3.new(bx - c * 3, 0, bz - s * 3))
end

-- 3) 용암 웅덩이 (네온 판 + 불티·김 + 빛), 둘레는 현무암 턱 ----------------------
local decor = Instance.new("Folder")
decor.Name = "LavaDecor"
decor.Parent = hub
local LAVA = Color3.fromRGB(255, 96, 20)
local function lavaPool(pos: Vector3, rx: number)
	for a = 0, math.pi * 2, math.pi / 10 do
		T:FillBall(pos + Vector3.new(math.cos(a) * (rx + 1), -0.5, math.sin(a) * (rx + 1)), rng:NextNumber(2.2, 3.4), M.Basalt); tick()
	end
	T:FillCylinder(CFrame.new(pos + Vector3.new(0, -1, 0)), 2, rx + 0.5, M.Air)
	local p = Instance.new("Part")
	p.Name = "LavaPool"
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(0.6, rx * 2 + 1, rx * 2 + 1)
	p.CFrame = CFrame.new(pos + Vector3.new(0, -0.9, 0)) * CFrame.Angles(0, 0, math.rad(90))
	p.Material = M.Neon
	p.Color = LAVA
	p.Anchored, p.CanCollide = true, true
	p.Parent = decor
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness = LAVA, rx * 2.5 + 10, 1.6
	l.Parent = p
	local e = Instance.new("ParticleEmitter")
	e.Name = "Embers"
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Rate = 6
	e.Lifetime = NumberRange.new(1.5, 3)
	e.Speed = NumberRange.new(2, 5)
	e.SpreadAngle = Vector2.new(25, 25)
	e.EmissionDirection = Enum.NormalId.Right -- 실린더는 X축이 위
	e.Size = NumberSequence.new(0.3, 0)
	e.LightEmission = 1
	e.Color = ColorSequence.new(Color3.fromRGB(255, 200, 80), Color3.fromRGB(255, 70, 20))
	e.Parent = p
	local h = Instance.new("ParticleEmitter")
	h.Name = "Heat"
	h.Texture = "rbxasset://textures/particles/smoke_main.dds"
	h.Rate = 2
	h.Lifetime = NumberRange.new(3, 5)
	h.Speed = NumberRange.new(1, 2)
	h.EmissionDirection = Enum.NormalId.Right
	h.Size = NumberSequence.new(3, 7)
	h.Transparency = NumberSequence.new(0.75, 1)
	h.Color = ColorSequence.new(Color3.fromRGB(90, 70, 60))
	h.Parent = p
	return p
end
-- 광장 양옆 앞쪽 모서리와 뒤쪽 모서리 (건물·길을 피한 자리, 기본 허브 기준 상대 좌표)
lavaPool(Vector3.new(HUB_X - 92, 0, 58), 9)
lavaPool(Vector3.new(HUB_X + 92, 0, 60), 10)
lavaPool(Vector3.new(HUB_X - 30, 0, 160), 6)
lavaPool(Vector3.new(HUB_X + 60, 0, 156), 7)
-- 벽 용암 줄기 아래 작은 웅덩이
for _, s in streams do
	if math.abs(s.X - HUB_X) < HALF_X - 4 then
		lavaPool(s, 3)
	end
end

-- 바닥 흩어진 현무암 바위
for _ = 1, 40 do
	local x = CENTER.X + rng:NextNumber(-HALF_X, HALF_X)
	local z = CENTER.Z + rng:NextNumber(-HALF_Z, HALF_Z)
	local r = shape(x, z)
	-- 가운데 광장(입구~제작소 길)은 비운다
	if r < 0.92 and math.abs(x - HUB_X) > 34 then
		T:FillBall(Vector3.new(x, 0, z), rng:NextNumber(1.5, 3.5), M.Basalt); tick()
	end
end

-- 4) 경계벽 ----------------------------------------------------------------------
local boundary = Instance.new("Folder")
boundary.Name = "Boundary"
local SEG = 80
local pts = {}
for i = 0, SEG - 1 do
	local bx, bz, c, s = boundaryPoint(i / SEG * math.pi * 2)
	local d = THICK * 0.92
	table.insert(pts, Vector3.new(bx + c * d, 0, bz + s * d))
end
for i = 1, SEG do
	local a, b = pts[i], pts[i % SEG + 1]
	local mid = (a + b) / 2 + Vector3.new(0, 150, 0)
	local w = Instance.new("Part")
	w.Name = "Wall"
	w.Size = Vector3.new(2, 300, (b - a).Magnitude + 2)
	w.CFrame = CFrame.lookAt(mid, mid + (b - a).Unit)
	w.Anchored, w.CanCollide, w.CanQuery, w.CanTouch = true, true, false, false
	w.Transparency = 1
	w.Parent = boundary
end
boundary.Parent = hub

-- 5) 건물: 기본 허브에서 복사해 넓게 놓기 ------------------------------------------
local src = workspace.CollapseMine.Hub
local function spread(p: Vector3): Vector3
	return Vector3.new(HUB_X + p.X * SPREAD_X, p.Y, ANCHOR_Z + (p.Z - ANCHOR_Z) * SPREAD_Z)
end
for _, n in { "Workshop", "Shop", "Leaderboard", "Storage" } do
	local o = src:FindFirstChild(n)
	if o then
		local c = o:Clone()
		local pv = o:GetPivot()
		c:PivotTo(pv.Rotation + spread(pv.Position))
		c.Parent = hub
	end
	task.wait()
end
local plaza = src.Plaza:Clone()
plaza.Size = Vector3.new(plaza.Size.X * SPREAD_X, plaza.Size.Y, plaza.Size.Z * SPREAD_Z)
plaza.CFrame = plaza.CFrame.Rotation + spread(plaza.Position)
plaza.Parent = hub
local spawn = src.MineSpawn:Clone()
spawn.CFrame = spawn.CFrame.Rotation + spread(spawn.Position)
spawn.Enabled, spawn.Neutral = false, false -- 새로 들어온 사람은 기본 허브에서만 생긴다
spawn.Parent = hub

-- 광장은 어두운 판석
plaza.Material = M.Slate
plaza.Color = Color3.fromRGB(62, 58, 60)

-- 흑요석 가시 (검은 유리 뾰족 바위) 무더기를 벽 밑에
for _ = 1, 26 do
	local t = rng:NextNumber(0, math.pi * 2)
	local bx, bz, c, s = boundaryPoint(t)
	if math.sin(t) > -0.5 then
		local d = rng:NextNumber(4, 10)
		local base = Vector3.new(bx - c * d, 0, bz - s * d)
		for _ = 1, rng:NextInteger(2, 4) do
			local h = rng:NextNumber(3, 9)
			local w = rng:NextNumber(0.8, 1.8)
			local p = Instance.new("WedgePart")
			p.Name = "ObsidianSpike"
			p.Size = Vector3.new(w, h, w)
			p.CFrame = CFrame.new(base + Vector3.new(rng:NextNumber(-2, 2), h / 2 - 0.5, rng:NextNumber(-2, 2)))
				* CFrame.Angles(math.rad(rng:NextNumber(-18, 18)), rng:NextNumber(0, 6.28), math.rad(rng:NextNumber(-18, 18)))
			p.Material = M.Glass
			p.Color = Color3.fromRGB(28, 20, 38)
			p.Reflectance = 0.15
			p.Anchored = true
			p.Parent = decor
		end
	end
end

-- 창고 상호작용 판은 아직 B 기능 전 자리표시 (이슈 #59)
root.Parent = workspace
if rec then CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
print(("[LavaHub] 완료: 지형 작업 %d회, 경계벽 %d개 → 이어서 build_cave_entrance (lava)"):format(ops, SEG))
