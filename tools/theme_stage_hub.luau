--[[
	스테이지 허브 테마 입히기 — tools/copy_stage_hub.luau로 복사한 허브(기본 허브와 같은 눈 덮인 산)를
	스테이지 분위기에 맞게 바꾼다. Studio 명령창에서 실행.

	water (지하수 동굴):
	  - 산·절벽 재질: 바위 → 젖은 짙은 판석, 판석 → 석회암 줄무늬, 눈 → 빙하(푸른빛)
	  - 입구 양옆(화로 바깥 x ±44) 산 앞면 앞에 곧게 떨어지는 지형 물 폭포 두 줄기 + 물방울·물보라 입자 + 아래 물웅덩이
	    (파트 물판으로도 해 봤는데 조각조각 끊겨 보여서 지형 물로 함. 화로(±32)를 덮지 않게 바깥으로)
	  - 입구 화로·횃불 불빛을 푸른색으로
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
		T:FillBlock(CFrame.new(head.X, (head.Y + 2) / 2, head.Z + 1.7), Vector3.new(6, head.Y + 2, 4), Enum.Material.Water)
		for _, pt in folder:GetChildren() do
			if pt.Name == "Stream" and math.abs(pt.Position.X - head.X) < 8 then
				pt.CFrame = CFrame.new(head.X, head.Y, head.Z + 3)
			end
		end
	end
end

-- 4) 입구 불빛 색
local portal = hub.Hub.MinePortals:FindFirstChild("Portal_" .. MINE_ID)
if portal then
	for _, d in portal:GetDescendants() do
		if d:IsA("Fire") then
			d.Color, d.SecondaryColor = TH.fire, TH.fire2
		elseif d:IsA("PointLight") or d:IsA("SpotLight") or d:IsA("SurfaceLight") then
			d.Color = TH.fire
		elseif d:IsA("BasePart") and d.Material == Enum.Material.Neon and (d.Name == "Ember" or d.Name == "Embers" or d.Name:find("Glass")) then
			d.Color = TH.ember
		elseif d:IsA("MeshPart") and (d.Name == "EN_Ember" or d.Name == "EN_Glass") then
			d.Color = TH.ember
		end
	end
end

if rec then CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
print("[ThemeStageHub] " .. MINE_ID .. " → " .. THEME)
