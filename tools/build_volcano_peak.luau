--[[
	용암 광산 입구 산 꼭대기를 화산으로 (Studio 명령창에서 실행, T-006)
	build_cave_entrance.luau(THEME lava)로 산을 지은 뒤 한 번 실행한다.

	1) 가장 높은 봉우리 둘레를 매끈한 원뿔(화산)로 다듬는다
	   - 반지름 13~62: 위를 깎고 원뿔 표면을 덮음 (꼭대기 근처는 용암 균열)
	   - 반지름 62~120: 원뿔이 땅보다 높은 곳만 채움 (입구 앞면 z 26보다 앞은 건드리지 않음)
	2) 꼭대기를 파서 분화구 + 빛나는 용암(네온 원판), 연기 기둥, 튀는 불티
	3) 분화구 가장자리에서 여러 갈래로 흘러내리는 용암 줄기 (네온 띠를 표면에 이어 붙임)
	   - CrackedLava 지형만으로는 낮에 어두운 분홍빛이라 흐르는 느낌이 안 나서 네온을 씀
	   - 사인파로 구불구불, 아래로 갈수록 가늘고 노랑 → 주황 → 빨강으로 식음
	   - 12 넘게 뚝 떨어지는 절벽에서 멈추고 끝에 빛나는 덩어리
	다시 실행하면 원뿔을 또 깎으니, 줄기만 다시 그릴 때는 STREAMS_ONLY = true.
]]

local HUB_NAME = "CollapseMine_lava"
local SEARCH = { minX = 1650, maxX = 1950, minZ = -137, maxZ = 30 } -- 산 범위 (입구 (1800,0,38) 뒤)
local FRONT_LIMIT_Z = 26 -- 이보다 앞(허브 쪽)은 지형을 안 건드림
local RIM_Y = 242 -- 분화구 가장자리 높이
local SLOPE = 1.45 -- 원뿔 기울기 (높이 / 거리)
local STOP_Y = 64
local STREAMS_ONLY = false
local STREAMS = { -- deg: 0 = +Z(허브 쪽), phase: 구불구불 모양
	{ deg = -22, width = 5, phase = 0.0 }, { deg = 24, width = 4.4, phase = 1.7 }, { deg = -55, width = 4, phase = 3.1 },
	{ deg = 80, width = 3.2, phase = 4.4 }, { deg = -96, width = 3.2, phase = 2.2 }, { deg = 150, width = 3, phase = 5.0 },
	{ deg = 205, width = 3, phase = 0.9 }, { deg = 2, width = 3.4, phase = 3.8 }, { deg = 52, width = 3, phase = 2.6 },
}

local CHS = game:GetService("ChangeHistoryService")
local T = workspace.Terrain
local M = Enum.Material
local LAVA = Color3.fromRGB(255, 110, 25)
local LAVA_HOT = Color3.fromRGB(255, 200, 70)
local LAVA_COOL = Color3.fromRGB(200, 45, 20)

local terrainOnly = RaycastParams.new()
terrainOnly.FilterType = Enum.RaycastFilterType.Include
terrainOnly.FilterDescendantsInstances = { T }
local function ground(x: number, z: number): RaycastResult?
	return workspace:Raycast(Vector3.new(x, 420, z), Vector3.new(0, -420, 0), terrainOnly)
end

local rec = CHS:TryBeginRecording("BuildVolcanoPeak")
local hub = workspace[HUB_NAME].Hub
local folder = hub:FindFirstChild("Volcano")

-- 꼭대기 찾기 (다시 그릴 때는 분화구 용암 자리)
local c: Vector3
if folder and folder:FindFirstChild("CraterLava") then
	c = folder.CraterLava.Position
else
	local best, bestY = nil, -math.huge
	for x = SEARCH.minX, SEARCH.maxX, 4 do
		for z = SEARCH.minZ, SEARCH.maxZ, 4 do
			local h = ground(x, z)
			if h and h.Position.Y > bestY then best, bestY = h.Position, h.Position.Y end
		end
		task.wait()
	end
	c = assert(best, "산이 없음")
end

local ops = 0
local function tick() ops += 1 if ops % 50 == 0 then task.wait() end end

if not STREAMS_ONLY then
	-- 1) 원뿔
	for x = c.X - 64, c.X + 64, 2 do
		for z = c.Z - 64, math.min(c.Z + 64, FRONT_LIMIT_Z), 2 do
			local r = Vector2.new(x - c.X, z - c.Z).Magnitude
			if r >= 13 and r <= 62 then
				local target = RIM_Y - math.max(0, r - 17) * SLOPE + math.noise(x / 9, z / 9, 7) * 2
				if r < 17 then target = RIM_Y - (17 - r) * 1.2 end -- 분화구 안쪽 벽
				T:FillBlock(CFrame.new(x, target + 30, z), Vector3.new(2, 60, 2), M.Air)
				T:FillBlock(CFrame.new(x, target - 4, z), Vector3.new(2, 8, 2), (r < 26) and M.CrackedLava or M.Basalt)
				tick()
			end
		end
	end
	for x = c.X - 120, c.X + 120, 4 do
		for z = c.Z - 120, math.min(c.Z + 120, FRONT_LIMIT_Z), 4 do
			local r = Vector2.new(x - c.X, z - c.Z).Magnitude
			if r > 60 and r <= 120 then
				local target = RIM_Y - (r - 17) * SLOPE + math.noise(x / 13, z / 13, 8) * 4
				local h = ground(x, z)
				local gy = h and h.Position.Y or 0
				if target > gy + 1 then
					T:FillBlock(CFrame.new(x, (gy + target) / 2 - 1, z), Vector3.new(4, target - gy + 2, 4), M.Basalt)
					tick()
				end
			end
		end
	end
	-- 2) 분화구
	T:FillBall(Vector3.new(c.X, RIM_Y + 8, c.Z), 20, M.Air)
	T:FillCylinder(CFrame.new(c.X, RIM_Y - 13, c.Z), 4, 13, M.CrackedLava)
	task.wait(0.2)

	if folder then folder:Destroy() end
	folder = Instance.new("Folder")
	folder.Name = "Volcano"
	local floor = ground(c.X, c.Z)
	local pool = Instance.new("Part")
	pool.Name = "CraterLava"
	pool.Shape = Enum.PartType.Cylinder
	pool.Size = Vector3.new(1, 27, 27)
	pool.CFrame = CFrame.new(c.X, (floor and floor.Position.Y or RIM_Y - 9) + 0.6, c.Z) * CFrame.Angles(0, 0, math.rad(90))
	pool.Material = M.Neon
	pool.Color = LAVA
	pool.Anchored, pool.CanCollide, pool.CastShadow = true, false, false
	pool.Parent = folder
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = LAVA, 60, 3
	light.Parent = pool
	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "Plume"
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.EmissionDirection = Enum.NormalId.Right -- 실린더 X축 = 위
	smoke.Rate = 5
	smoke.Lifetime = NumberRange.new(9, 13)
	smoke.Speed = NumberRange.new(7, 11)
	smoke.SpreadAngle = Vector2.new(10, 10)
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 12), NumberSequenceKeypoint.new(1, 40) })
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
	smoke.Color = ColorSequence.new(Color3.fromRGB(60, 52, 50), Color3.fromRGB(140, 135, 130))
	smoke.Acceleration = Vector3.new(2, 0.5, 0)
	smoke.Parent = pool
	local embers = Instance.new("ParticleEmitter")
	embers.Name = "Embers"
	embers.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	embers.EmissionDirection = Enum.NormalId.Right
	embers.Rate = 25
	embers.Lifetime = NumberRange.new(2, 4)
	embers.Speed = NumberRange.new(14, 26)
	embers.SpreadAngle = Vector2.new(30, 30)
	embers.Acceleration = Vector3.new(0, -12, 0)
	embers.Size = NumberSequence.new(1, 0)
	embers.LightEmission = 1
	embers.Color = ColorSequence.new(LAVA_HOT, LAVA)
	embers.Parent = pool
	folder.Parent = hub
end

-- 3) 용암 줄기
for _, q in folder:GetChildren() do
	if q.Name == "LavaFlow" or q.Name == "FlowTip" then q:Destroy() end
end
local function seg(a: Vector3, b: Vector3, w: number, col: Color3)
	local s = Instance.new("Part")
	s.Name = "LavaFlow"
	s.Size = Vector3.new(w, 0.8, (b - a).Magnitude + 1)
	s.CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.new(0, 0.35, 0)
	s.Material = M.Neon
	s.Color = col
	s.Anchored, s.CanCollide, s.CastShadow = true, false, false
	s.Parent = folder
end
for si, st in STREAMS do
	local base = math.rad(st.deg)
	local function at(rr: number)
		local ang = base + math.sin(rr / 13 + st.phase) * 0.22 + math.sin(rr / 5.5 + st.phase * 2) * 0.05
		return c.X + math.sin(ang) * rr, c.Z + math.cos(ang) * rr
	end
	local r = 17
	local x0, z0 = at(r)
	local h0 = ground(x0, z0)
	if not h0 then continue end
	local pos = h0.Position
	local topY = pos.Y
	for step = 1, 220 do
		r += 1.5
		local x, z = at(r)
		local h = ground(x, z)
		if not h then break end
		local np = h.Position
		if np.Y < STOP_Y or (pos.Y - np.Y) > 12 then break end
		local t = math.clamp((topY - np.Y) / (topY - STOP_Y), 0, 1)
		local w = st.width * (1 - 0.4 * t) * (0.85 + 0.3 * math.noise(r / 7, si))
		local col = LAVA_HOT:Lerp(LAVA, math.min(1, t * 2)):Lerp(LAVA_COOL, math.max(0, t * 2 - 1))
		seg(pos, np, w, col)
		pos = np
		if step % 15 == 0 then task.wait() end
	end
	local tip = Instance.new("Part")
	tip.Name = "FlowTip"
	tip.Shape = Enum.PartType.Ball
	tip.Size = Vector3.new(3.4, 3.4, 3.4)
	tip.CFrame = CFrame.new(pos)
	tip.Material = M.Neon
	tip.Color = LAVA_COOL
	tip.Anchored, tip.CanCollide = true, false
	tip.Parent = folder
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness = LAVA, 18, 1.5
	l.Parent = tip
end

if rec then CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
print("[Volcano] 완료: 꼭대기 " .. tostring(c))
