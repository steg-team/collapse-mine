--[[
	용암 광산 입구 산 꼭대기를 화산으로 (Studio 명령창에서 실행, T-006)
	build_cave_entrance.luau(THEME lava)로 산을 지은 뒤 한 번 실행한다.

	1) 가장 높은 봉우리 둘레를 매끈한 원뿔(화산)로 다듬는다
	   - 반지름 13~62: 위를 깎고 원뿔 표면을 덮음 (꼭대기 근처는 용암 균열)
	   - 반지름 62~120: 원뿔이 땅보다 높은 곳만 채움 (입구 앞면 z 26보다 앞은 건드리지 않음)
	2) 꼭대기를 파서 분화구 + 빛나는 용암(네온 원판), 연기 기둥, 튀는 불티
	3) 흘러내리는 용암 줄기 (Beam): 분화구 가장자리에서 여러 갈래 + 입구 양옆(FACE_X) 앞 절벽을 타고 땅까지
	   - 표면을 따라 부착점을 놓고 Beam으로 이어 부드럽게 휘고, 흐르는 텍스처가 아래로 움직임
	   - 처음엔 네온 파트를 이어 붙였는데 네모 판때기를 덕지덕지 붙인 것처럼 보여서 바꿈
	   - 광장에서는 앞 절벽에 가려 꼭대기 줄기가 안 보여서 앞면 줄기를 따로 둠 (절벽은 허브 쪽에서 수평 레이로 면을 찾음)
	   - 사인파로 구불구불, 아래로 갈수록 가늘고 노랑 → 주황 → 빨강으로 식음
	다시 실행하면 원뿔을 또 깎으니, 줄기만 다시 그릴 때는 STREAMS_ONLY = true.
]]

local HUB_NAME = "CollapseMine_lava"
local SEARCH = { minX = 1650, maxX = 1950, minZ = -137, maxZ = 30 } -- 산 범위 (입구 (1800,0,38) 뒤)
local FRONT_LIMIT_Z = 26 -- 이보다 앞(허브 쪽)은 지형을 안 건드림
local RIM_Y = 242 -- 분화구 가장자리 높이
local SLOPE = 1.45 -- 원뿔 기울기 (높이 / 거리)
local STOP_Y = 64
local STREAMS_ONLY = false
local FACE_X = { 1752, 1849, 1716, 1886 } -- 앞면 줄기 x (입구 1777~1823·화로 ±32 피함). 앞 둘은 굵게
local FLOW_TEXTURE = "rbxassetid://98653713678604" -- tools/textures/lava_flow.png 를 올린 이미지 (다시 올리면 id 바꾸기)
local BEAM_SPACING = 7 -- 부착점 간격(스터드). 좁으면 조각마다 텍스처가 반복돼 줄무늬가 보임
local BEAM_WIDTH = 1.7 -- 줄기 폭 배수
local FLOW_HOT, FLOW_MID, FLOW_COOL = Color3.fromRGB(255, 205, 90), Color3.fromRGB(255, 135, 35), Color3.fromRGB(230, 65, 25)
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

-- 3) 용암 줄기 (Beam): 꼭대기 줄기 + 앞면 줄기
-- 네모 파트를 이어 붙이면 판때기처럼 보여서, 표면을 따라 부착점을 놓고 그 사이를 Beam으로 잇는다.
--   부착점: X축 = 흐르는 방향, Y축 = 지면 법선 → Beam이 지면에 납작하게 눕고 CurveSize로 부드럽게 휨
--   텍스처: tools/textures/lava_flow.png (가로 이음새 없음, 가장자리는 구불구불 투명) → Stretch로 조각마다 한 장
--   TextureSpeed로 아래로 흐르는 움직임. 앞면 줄기는 바위 위라 붉은 후광(Halo) Beam을 한 겹 더 (하늘을 배경으로 하면 보라색이 돼서 꼭대기 줄기는 뺌)
local old = folder:FindFirstChild("FlowAnchor")
if old then old:Destroy() end
for _, q in folder:GetChildren() do
	if q.Name == "LavaFlow" or q.Name == "FlowTip" or q.Name == "FaceFlow" then q:Destroy() end
end
local anchor = Instance.new("Part")
anchor.Name = "FlowAnchor"
anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = true, false, false, false
anchor.Transparency = 1
anchor.Size = Vector3.one
anchor.CFrame = CFrame.new(c)
anchor.Parent = folder

local function faceHit(x: number, y: number): RaycastResult?
	return workspace:Raycast(Vector3.new(x, y, 140), Vector3.new(0, 0, -260), terrainOnly)
end
local paths = {}
for _, st in STREAMS do -- 꼭대기: 분화구 가장자리에서 바깥으로, 절벽(12 넘게 뚝)에서 멈춤
	local base = math.rad(st.deg)
	local function at(rr: number)
		local ang = base + math.sin(rr / 13 + st.phase) * 0.22 + math.sin(rr / 5.5 + st.phase * 2) * 0.05
		return c.X + math.sin(ang) * rr, c.Z + math.cos(ang) * rr
	end
	local pts, r = {}, 15
	local h0 = ground(at(r))
	local prev = h0 and h0.Position
	if h0 then table.insert(pts, { pos = h0.Position, n = h0.Normal }) end
	for _ = 1, 220 do
		if not prev then break end
		r += 1.5
		local h = ground(at(r))
		if not h or h.Position.Y < STOP_Y or (prev.Y - h.Position.Y) > 12 then break end
		table.insert(pts, { pos = h.Position, n = h.Normal })
		prev = h.Position
	end
	table.insert(paths, { pts = pts, width = st.width, halo = false })
end
for i, X in FACE_X do -- 앞면: 위쪽 비탈을 따라오다 앞 절벽은 허브 쪽에서 수평 레이로 면을 찾아 땅까지
	local pts, z, last = {}, -20, nil
	while z < 60 do
		local h = ground(X + math.sin(z / 9 + i) * 2.5, z)
		if not h or (last and last.Position.Y - h.Position.Y > 4) then break end
		table.insert(pts, { pos = h.Position, n = h.Normal })
		last = h
		z += 1.5
	end
	local y = last and last.Position.Y or 80
	while y > 0.5 do
		y -= 1.5
		local h = faceHit(X + math.sin(y / 7 + i) * 2.5, y)
		if h then table.insert(pts, { pos = h.Position, n = h.Normal }) end
	end
	table.insert(paths, { pts = pts, width = (i <= 2) and 5.5 or 4.5, halo = true })
end

local function heatColor(t: number): Color3
	return FLOW_HOT:Lerp(FLOW_MID, math.min(1, t * 2.2)):Lerp(FLOW_COOL, math.max(0, t * 2 - 1))
end
for pi, path in paths do
	local raw = path.pts
	if #raw < 3 then continue end
	local pick, acc = { raw[1] }, 0
	for k = 2, #raw do
		acc += (raw[k].pos - raw[k - 1].pos).Magnitude
		if acc >= BEAM_SPACING or k == #raw then
			table.insert(pick, raw[k])
			acc = 0
		end
	end
	local n = #pick
	local atts = {}
	for k = 1, n do
		local p = pick[k]
		local a, b = pick[math.max(1, k - 1)].pos, pick[math.min(n, k + 1)].pos
		local tan = b - a
		if tan.Magnitude < 0.01 then tan = -Vector3.yAxis end
		tan = tan.Unit
		local nrm = p.n - tan * p.n:Dot(tan)
		if nrm.Magnitude < 0.01 then nrm = Vector3.yAxis end
		nrm = nrm.Unit
		local att = Instance.new("Attachment")
		att.Parent = anchor
		att.WorldCFrame = CFrame.fromMatrix(p.pos + nrm * 0.45, tan, nrm, tan:Cross(nrm))
		atts[k] = att
	end
	local topY = pick[1].pos.Y
	for k = 1, n - 1 do
		local p0, p1 = atts[k].WorldPosition, atts[k + 1].WorldPosition
		local horiz = Vector2.new(p1.X - p0.X, p1.Z - p0.Z).Magnitude
		if math.max(p0.Y, p1.Y) < 8 and math.abs(p1.Y - p0.Y) < horiz * 0.5 then continue end -- 바닥에 눕는 끝 조각
		local d = (p1 - p0).Magnitude
		local t0 = math.clamp((topY - pick[k].pos.Y) / math.max(topY - 1, 1), 0, 1)
		local t1 = math.clamp((topY - pick[k + 1].pos.Y) / math.max(topY - 1, 1), 0, 1)
		local function wid(t: number, kk: number): number
			return path.width * BEAM_WIDTH * (1 - 0.35 * t) * (0.85 + 0.35 * math.noise(kk / 3, pi))
		end
		local bm = Instance.new("Beam")
		bm.Attachment0, bm.Attachment1 = atts[k], atts[k + 1]
		bm.Texture = FLOW_TEXTURE
		bm.TextureMode = Enum.TextureMode.Stretch
		bm.TextureLength = 1
		bm.TextureSpeed = 0.35
		bm.LightEmission, bm.LightInfluence, bm.Brightness = 1, 0, 2.5
		bm.FaceCamera = false
		bm.Segments = 8
		bm.CurveSize0, bm.CurveSize1 = d / 3, d / 3
		bm.Width0, bm.Width1 = wid(t0, k), wid(t1, k + 1)
		bm.Color = ColorSequence.new(heatColor(t0), heatColor(t1))
		bm.Parent = anchor
		if path.halo then
			local h = bm:Clone()
			h.Name = "Halo"
			h.Width0 *= 1.8
			h.Width1 *= 1.8
			h.Color = ColorSequence.new(Color3.fromRGB(255, 60, 10))
			h.Transparency = NumberSequence.new(0.6)
			h.Brightness = 1.5
			h.TextureSpeed = 0.2
			h.ZOffset = -0.05
			h.Parent = anchor
		end
	end
	for k = 1, n, 5 do
		local l = Instance.new("PointLight")
		l.Color, l.Range, l.Brightness = FLOW_MID, 14, 1.2
		l.Parent = atts[k]
	end
	task.wait()
end

if rec then CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
print("[Volcano] 완료: 꼭대기 " .. tostring(c))
