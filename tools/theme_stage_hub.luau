--[[
	스테이지 허브 테마 입히기 — tools/copy_stage_hub.luau로 복사한 허브(기본 허브와 같은 눈 덮인 산)를
	스테이지 분위기에 맞게 바꾼다. Studio 명령창에서 실행.

	water (지하수 동굴):
	  - 산·절벽 재질: 바위 → 젖은 짙은 판석, 판석 → 석회암 줄무늬, 눈 → 빙하(푸른빛)
	  - 입구 양옆(화로 바깥 x ±44) 산 앞면 앞에 곧게 떨어지는 지형 물 폭포 두 줄기 + 물방울·물보라 입자 + 아래 물웅덩이
	    (파트 물판으로도 해 봤는데 조각조각 끊겨 보여서 지형 물로 함. 화로(±32)를 덮지 않게 바깥으로)
	  - 입구 화로·횃불 불빛을 푸른색으로 (범위를 줄여 산 전체가 파랗게 물들지 않게)
	  - 제미나이 시안(2026-10-23)을 대충 따라: 입구 둘레 밝은 회색 돌 테두리, 턱 윗면 이끼, 입구 안쪽 벽 파란 수정,
	    폭포 뒤 빈틈 바위로 메움, 오른쪽 폭포는 높은 바위 처마 밑에서 쏟아지게
	  ※ 복사본 허브에 한 번만 실행. 다시 돌리면 2)의 재질 바꾸기가 또 적용돼(판석→석회암) 산 전체가 바뀐다
	공통:
	  - 입구 산 오른쪽 어깨 앞면에 구멍(아래가 빈 바위 처마)처럼 보이는 곳을 바위로 메움 (SHOULDER_FILL)

	HUB_X  = 허브 복사본이 기본 허브에서 옮겨진 x (copy_stage_hub.luau의 dx)
]]

local MINE_ID = "groundwater"
local HUB_X = 900
local THEME = "water"

local CHS = game:GetService("ChangeHistoryService")
local T = workspace.Terrain
local hub = assert(workspace:FindFirstChild("CollapseMine_" .. MINE_ID), "허브 복사본이 없음 (copy_stage_hub 먼저)")
local MOUTH = Vector3.new(HUB_X, 0, 38) -- 입구 바닥 가운데 (기본 허브 (0, 0, 38)에서 옮긴 자리)

local THEMES = {
	water = {
		replace = {
			{ Enum.Material.Slate, Enum.Material.Limestone }, -- 순서 중요: 판석을 먼저 석회암으로 바꾼 뒤
			{ Enum.Material.Rock, Enum.Material.Slate }, -- 바위를 판석으로
			{ Enum.Material.Snow, Enum.Material.Glacier },
		},
		fire = Color3.fromRGB(80, 200, 255),
		fire2 = Color3.fromRGB(190, 240, 255),
		ember = Color3.fromRGB(90, 210, 255),
		waterfalls = true,
		lightRange = 16, lightBrightness = 1, -- 입구 불빛(범위 55·22)이 산 앞면 전체를 파랗게 물들여서 줄임. 파란빛은 입구 둘레만
		frame = Enum.Material.Concrete, -- 입구 둘레 밝은 회색 돌 테두리 (시안: 어두운 산에 밝은 돌 아치. 석회암은 누런색이라 콘크리트)
		-- 폭포 뒤가 비어 물기둥이 산 앞에 떠 보여서, 물 뒤 빈칸을 바위로 메움 (MOUTH 기준 상대 좌표 min, max)
		fallBacking = {
			{ Vector3.new(-50, 0, -10), Vector3.new(-38, 56, 10) },
			{ Vector3.new(38, 0, -6), Vector3.new(50, 80, 10) },
		},
		-- 오른쪽 폭포는 위가 바위라 연못 대신 높은 바위 처마 밑에서 쏟아지게 (x, 물 머리 높이)
		springs = { { x = 44, top = 80 } },
		moss = { chance = 0.4, from = { Enum.Material.Slate, Enum.Material.Limestone } }, -- 턱 윗면 이끼
		crystals = Color3.fromRGB(90, 200, 255), -- 입구 안쪽 벽 파란 수정
		-- 왼쪽 폭포는 풀밭 턱(y 56) 연못 → 물길 → 폭포 머리. 오른쪽은 위가 바위라 그대로
		sources = {
			{ pond = Vector3.new(-58, 56, -7), path = { Vector3.new(-52, 56, 0), Vector3.new(-47, 56, 6), Vector3.new(-44, 56, 11) } },
		},
	},
}
local TH = assert(THEMES[THEME], "없는 테마")

-- 산 어깨 메울 자리 (입구 MOUTH 기준 상대 좌표, 반경). 입구 산 오른쪽 어깨 앞면에 뚫린 구멍(아래가 빈 바위 처마)
-- 기본 허브 산에서 그대로 복사된 것. 지형을 칸 단위로 훑어서 찾은 자리
local SHOULDER_FILL = {
	{ Vector3.new(118, 62, 3), 14 },
	{ Vector3.new(136, 33, 2), 12 },
	{ Vector3.new(143, 59, 1), 12 },
}

local rec = CHS:TryBeginRecording("ThemeStageHub " .. MINE_ID)

-- 1) 잘린 어깨 메우기 (재질 바꾸기 전에 바위로)
for _, s in SHOULDER_FILL do
	T:FillBall(MOUTH + s[1], s[2], Enum.Material.Rock)
end
task.wait()

-- 2) 재질 바꾸기 (허브 복사 범위 전체, 64칸씩 나눠서)
local x0, x1 = HUB_X - 160, HUB_X + 160
for cx = x0, x1 - 1, 64 do
	for cz = -152, 187, 68 do
		local region = Region3.new(Vector3.new(cx, -40, cz), Vector3.new(math.min(cx + 64, x1), 232, math.min(cz + 68, 188))):ExpandToGrid(4)
		for _, pair in TH.replace do
			T:ReplaceMaterial(region, 4, pair[1], pair[2])
		end
		task.wait()
	end
end

-- 3) 폭포 + 물웅덩이: 입구 양옆, 산 앞면에 붙여서
if TH.waterfalls then
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Include
	rp.FilterDescendantsInstances = { T }
	local old = hub.Hub:FindFirstChild("Waterfalls")
	if old then old:Destroy() end
	local folder = Instance.new("Folder")
	folder.Name = "Waterfalls"
	local function emitterPart(name: string, size: Vector3, cf: CFrame): Part
		local a = Instance.new("Part")
		a.Name, a.Size, a.CFrame, a.Transparency = name, size, cf, 1
		a.Anchored, a.CanCollide, a.CanQuery = true, false, false
		a.Parent = folder
		return a
	end
	for _, sx in { -44, 44 } do
		-- 앞면이 들쭉날쭉해서 높이마다 붙이면 물이 끊긴 덩어리가 된다 → 가장 앞으로 나온 면 바로 앞에 곧은 물기둥 하나
		local hits = {}
		local zFront = -math.huge
		for y = 4, 80, 4 do
			local hit = workspace:Raycast(MOUTH + Vector3.new(sx, y, 80), Vector3.new(0, 0, -120), rp)
			if hit then
				hits[y] = hit.Position.Z
				zFront = math.max(zFront, hit.Position.Z)
			end
		end
		-- 물이 시작하는 높이: 앞면이 물기둥 바로 뒤에 붙어 있는 가장 높은 곳 (바위에서 물이 나오는 것처럼)
		local top = 4
		for y = 80, 4, -4 do
			if hits[y] and hits[y] >= zFront - 3 then
				top = y
				break
			end
		end
		local z = zFront + 1.5
		T:FillBlock(CFrame.new(MOUTH.X + sx, (top + 2) / 2, z), Vector3.new(6, top + 2, 4), Enum.Material.Water)
		T:FillBlock(CFrame.new(MOUTH.X + sx, top, z - 3), Vector3.new(6, 4, 4), Enum.Material.Water) -- 시작점 홈
		local lowest = { y = 2, pos = Vector3.new(MOUTH.X + sx, 2, z + 1.5), n = Vector3.zAxis, top = top }
		if lowest then
			-- 바닥 물보라
			local splash = emitterPart("Splash", Vector3.new(7, 0.2, 2), CFrame.new(lowest.pos.X, 2.2, lowest.pos.Z) + lowest.n * 2)
			local e = Instance.new("ParticleEmitter")
			e.Texture = "rbxasset://textures/particles/smoke_main.dds"
			e.Color = ColorSequence.new(Color3.fromRGB(230, 245, 255))
			e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
			e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 5) })
			e.Lifetime, e.Rate, e.Speed = NumberRange.new(1, 1.8), 18, NumberRange.new(2, 4)
			e.SpreadAngle, e.EmissionDirection = Vector2.new(40, 40), Enum.NormalId.Top
			e.Parent = splash
			-- 위에서 떨어지는 물방울 줄기
			local stream = emitterPart("Stream", Vector3.new(6, 0.2, 0.2), CFrame.new(MOUTH.X + sx, lowest.top, lowest.pos.Z + 0.7))
			local d = Instance.new("ParticleEmitter")
			d.Color, d.LightEmission = ColorSequence.new(Color3.fromRGB(200, 235, 255)), 0.3
			d.Transparency, d.Size = NumberSequence.new(0.3), NumberSequence.new(0.35)
			d.Lifetime, d.Rate, d.Speed = NumberRange.new(2.5, 3), 60, NumberRange.new(0, 1)
			d.Acceleration, d.EmissionDirection = Vector3.new(0, -30, 0), Enum.NormalId.Bottom
			d.Parent = stream
		end
		-- 물웅덩이 (지형 물): 폭포 아래 앞쪽
		local floor = workspace:Raycast(MOUTH + Vector3.new(sx, 20, 14), Vector3.new(0, -40, 0), rp)
		if floor then
			local c = Vector3.new(MOUTH.X + sx, floor.Position.Y, MOUTH.Z + 12)
			T:FillBlock(CFrame.new(c + Vector3.new(0, -1.5, 0)), Vector3.new(12, 4, 10), Enum.Material.Air)
			T:FillBlock(CFrame.new(c + Vector3.new(0, -2, 0)), Vector3.new(12, 3, 10), Enum.Material.Water)
		end
		task.wait()
	end
	folder.Parent = hub.Hub

	-- 폭포 머리: 풀밭 턱 위 연못에서 물길이 흘러와 떨어지게 (MOUTH 기준 상대 좌표, 물 높이 waterY)
	-- 물길이 닿는 높이 위쪽 물기둥은 지우고, 그 높이부터 떨어지게 다시 세운다
	for _, src in TH.sources or {} do
		local pond = MOUTH + src.pond
		T:FillCylinder(CFrame.new(pond + Vector3.new(0, 2, 0)), 6, 7, Enum.Material.Air)
		T:FillCylinder(CFrame.new(pond + Vector3.new(0, -1.5, 0)), 3, 7, Enum.Material.Water)
		local pts = { pond }
		for _, rel in src.path do table.insert(pts, MOUTH + rel) end
		for i = 1, #pts - 1 do
			local a, b = pts[i], pts[i + 1]
			local cf = CFrame.lookAt((a + b) / 2, b)
			local len = (b - a).Magnitude + 3
			T:FillBlock(cf * CFrame.new(0, 2.5, 0), Vector3.new(5, 5, len), Enum.Material.Air)
			T:FillBlock(cf * CFrame.new(0, -1, 0), Vector3.new(5, 3, len), Enum.Material.Water)
		end
		local head = pts[#pts]
		T:ReplaceMaterial(Region3.new(head + Vector3.new(-6, 4, -5), head + Vector3.new(6, 40, 9)):ExpandToGrid(4), 4, Enum.Material.Water, Enum.Material.Air)
		-- 넓고 두껍게 뒤 바위에 붙여서 (얇으면 물길 끝에서 꺾여 떨어지는 ㄱ자에 바위와 틈이 생김) + 꺾이는 모서리를 둥글게
		T:FillBlock(CFrame.new(head.X + 1, (head.Y + 2) / 2, head.Z), Vector3.new(10, head.Y + 2, 8), Enum.Material.Water)
		T:FillBall(head + Vector3.new(0, -1, 1), 5, Enum.Material.Water)
		for _, pt in folder:GetChildren() do
			if pt.Name == "Stream" and math.abs(pt.Position.X - head.X) < 8 then
				pt.CFrame = CFrame.new(head.X, head.Y, head.Z + 3)
			end
		end
	end
end

-- 3.5) 입구 둘레 테두리·이끼·수정·폭포 뒤 바위 (제미나이 시안을 대충 따라감)
local rpT = RaycastParams.new()
rpT.FilterType = Enum.RaycastFilterType.Include
rpT.FilterDescendantsInstances = { T }
for _, b in TH.fallBacking or {} do
	-- 빈칸(Air)만 바위로. 물 칸은 건드리지 않는다
	local r = Region3.new(MOUTH + b[1], MOUTH + b[2]):ExpandToGrid(4)
	local mats, occ = T:ReadVoxels(r, 4)
	for x = 1, mats.Size.X do
		for y = 1, mats.Size.Y do
			for z = 1, mats.Size.Z do
				if mats[x][y][z] == Enum.Material.Air then
					mats[x][y][z] = Enum.Material.Slate
					occ[x][y][z] = 1
				end
			end
		end
	end
	T:WriteVoxels(r, 4, mats, occ)
	task.wait()
end
for _, s in TH.springs or {} do
	local x = MOUTH.X + s.x
	local z = MOUTH.Z + 12.5 -- 물기둥 앞면 z (폭포 만들 때 잰 자리)
	T:FillBlock(CFrame.new(x, (58 + s.top) / 2, z), Vector3.new(6, s.top - 58 + 4, 4), Enum.Material.Water)
	-- 머리 위 바위 처마 + 윗면 풀, 양옆 둥글게
	T:FillBlock(CFrame.new(x, s.top + 6, z - 2.5), Vector3.new(16, 8, 14), Enum.Material.Slate)
	T:FillBlock(CFrame.new(x, s.top + 10.5, z - 2.5), Vector3.new(16, 1, 14), Enum.Material.Grass)
	T:FillBall(Vector3.new(x - 8, s.top + 4, z - 0.5), 5, Enum.Material.Slate)
	T:FillBall(Vector3.new(x + 8, s.top + 4, z - 0.5), 5, Enum.Material.Slate)
	T:FillBlock(CFrame.new(x, s.top - 1, z), Vector3.new(6, 4, 5), Enum.Material.Water)
	for _, pt in (hub.Hub:FindFirstChild("Waterfalls") or hub.Hub):GetChildren() do
		if pt.Name == "Stream" and math.abs(pt.Position.X - x) < 8 then
			pt.CFrame = CFrame.new(x, s.top + 1, z + 1.5)
		end
	end
end
if TH.frame then
	-- 입구 앞면(z 30~62) 둘레만 밝은 돌로. 그 안쪽 굴 벽은 어두운 판석 그대로라 입구가 도드라진다
	local r = Region3.new(MOUTH + Vector3.new(-36, 0, -8), MOUTH + Vector3.new(36, 64, 24)):ExpandToGrid(4)
	T:ReplaceMaterial(r, 4, Enum.Material.Slate, TH.frame)
	task.wait()
end
if TH.moss then
	-- 윗면(위 칸이 비어 있는 칸)만 확률로 풀. 광장 바닥과 입구 바닥은 빼고. 시드 고정이라 다시 돌려도 같은 자리
	local rng = Random.new(42)
	local from = {}
	for _, m in TH.moss.from do from[m] = true end
	for cx = -96, 95, 32 do
		local r = Region3.new(MOUTH + Vector3.new(cx, 8, -40), MOUTH + Vector3.new(cx + 32, 120, 40)):ExpandToGrid(4)
		local mats, occ = T:ReadVoxels(r, 4)
		local sz = mats.Size
		local changed = false
		for x = 1, sz.X do
			for z = 1, sz.Z do
				for y = 1, sz.Y - 1 do
					if from[mats[x][y][z]] and occ[x][y][z] > 0.5 and mats[x][y + 1][z] == Enum.Material.Air then
						if rng:NextNumber() < TH.moss.chance then
							mats[x][y][z] = Enum.Material.Grass
							changed = true
						end
					end
				end
			end
		end
		if changed then T:WriteVoxels(r, 4, mats, occ) end
		task.wait()
	end
end
if TH.crystals then
	local old = hub.Hub:FindFirstChild("Crystals")
	if old then old:Destroy() end
	local folder = Instance.new("Folder")
	folder.Name = "Crystals"
	local rng = Random.new(7)
	-- 입구 안쪽 양쪽 벽에 몇 무더기. 벽 위치는 입구 가운데서 옆으로 레이캐스트해서 찾는다
	for _, side in { -1, 1 } do
		for _, p in { Vector3.new(0, 2, 40), Vector3.new(0, 10, 34), Vector3.new(0, 4, 26), Vector3.new(0, 18, 30) } do
			local o = Vector3.new(MOUTH.X, p.Y, p.Z)
			local hit = workspace:Raycast(o, Vector3.new(side * 40, 0, 0), rpT)
			if hit then
				local base = hit.Position + hit.Normal * 0.5
				local cluster = Instance.new("Model")
				cluster.Name = "Cluster"
				for i = 1, rng:NextInteger(3, 5) do
					local c = Instance.new("Part")
					c.Name = "Crystal"
					local h = rng:NextNumber(3, 7)
					c.Size = Vector3.new(1.4, h, 1.4)
					c.Material = Enum.Material.Glass
					c.Color = TH.crystals
					c.Transparency = 0.15
					c.Anchored, c.CanCollide = true, false
					c.CastShadow = false
					-- 벽 쪽 밑동에서 바깥(굴 안쪽)과 위로 비스듬히
					local tilt = CFrame.Angles(math.rad(rng:NextNumber(-25, 25)), 0, math.rad(side * rng:NextNumber(10, 40)))
					c.CFrame = CFrame.new(base + Vector3.new(0, 0, rng:NextNumber(-2, 2))) * tilt * CFrame.new(0, h / 2 - 0.5, 0)
					c.Parent = cluster
				end
				local glow = cluster:GetChildren()[1]
				local l = Instance.new("PointLight")
				l.Color, l.Range, l.Brightness = TH.crystals, 9, 0.8
				l.Parent = glow
				cluster.Parent = folder
			end
		end
	end
	folder.Parent = hub.Hub
end

-- 4) 입구 불빛 색
local portal = hub.Hub.MinePortals:FindFirstChild("Portal_" .. MINE_ID)
if portal then
	for _, d in portal:GetDescendants() do
		if d:IsA("Fire") then
			d.Color, d.SecondaryColor = TH.fire, TH.fire2
		elseif d:IsA("PointLight") or d:IsA("SpotLight") or d:IsA("SurfaceLight") then
			d.Color = TH.fire
			if TH.lightRange and d.Range > TH.lightRange then d.Range = TH.lightRange end
			if TH.lightBrightness and d.Brightness > TH.lightBrightness then d.Brightness = TH.lightBrightness end
		elseif d:IsA("BasePart") and d.Material == Enum.Material.Neon and (d.Name == "Ember" or d.Name == "Embers" or d.Name:find("Glass")) then
			d.Color = TH.ember
		elseif d:IsA("MeshPart") and (d.Name == "EN_Ember" or d.Name == "EN_Glass") then
			d.Color = TH.ember
		end
	end
end

if rec then CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
print("[ThemeStageHub] " .. MINE_ID .. " → " .. THEME)
