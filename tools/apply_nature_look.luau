--[[
	허브를 "레이저 태그 템플릿" 느낌으로: 이끼 낀 바닥·풀, 자갈 길, 진짜 바위 메시, 고사리 (Studio 명령창에서 실행, A)

	원본: 로블록스 공식 Laser Tag 템플릿. 어떻게 만든 건지는 tools/art_nature_look.md.
	요점: 지형 재질 자체는 평범한 Grass·Ground·Sand인데, MaterialService에서 재질을 사진 텍스처(MaterialVariant)로
	덮어써서(override) 진짜 같은 바닥이 된다. 그 위에 SurfaceAppearance를 입힌 바위·풀 메시를 흩어 놓는다.

	단계 (위 표의 켜기/끄기로 고름)
	1. MATERIALS: MaterialService에 텍스처 재질 6개를 만든다 (없을 때만)
	2. OVERRIDES: 지형 재질 → 텍스처 재질 덮어쓰기. **장소 전체에 적용**된다 (광산 안도). 그래서 광산 벽에 쓰는
	   Ground·Slate·Basalt·Limestone·Rock은 건드리지 않고, 광산에 안 쓰는 재질(Mud·LeafyGrass·Sand)을 허브 전용으로 쓴다.
	   Grass는 허브 절벽 위·광산 지표에만 있어서 덮어써도 된다.
	3. REPAINT: 허브 마당 흙(Ground) → Mud(이끼 흙)로, 마당 가장자리에 MossStones·Stones 얼룩
	4. SCATTER: 허브 풀밭·마당 가장자리에 고사리·호스타, 절벽 밑에 바위 메시 (Hub/Nature 폴더, 다시 실행하면 새로 깔림)
	5. LIGHTING: 템플릿 조명(대기·색보정·블룸). 광산 어둠과 맞물리니 기본은 끔

	되돌리기: Ctrl+Z, 또는 Hub/Nature 폴더 삭제 + MaterialService 덮어쓰기 칸 비우기
]]

local RUN = {
	MATERIALS = true,
	OVERRIDES = true,
	REPAINT = true,
	SCATTER = true,
	LIGHTING = false,
}

-- 허브 세 개 (D-019: 기본 허브 x 0, 철광 -900, 지하수 +900). 마당 = tools/hub_yard_ground.luau와 같은 범위
local HUBS = {
	{ folder = "CollapseMine", dx = 0 },
	{ folder = "CollapseMine_iron", dx = -900 },
	{ folder = "CollapseMine_groundwater", dx = 900 },
}
local YARD_MIN, YARD_MAX = Vector3.new(-92, -12, 36), Vector3.new(92, 8, 146)
local PLAZA_MIN, PLAZA_MAX = Vector3.new(-72, -12, 60), Vector3.new(72, 8, 128) -- 건물 앞 돌바닥 광장 (흩뿌리기 제외)
local SCATTER_AREA_MIN, SCATTER_AREA_MAX = Vector3.new(-140, -20, 0), Vector3.new(140, 70, 190) -- 절벽 위까지
local FOLIAGE_COUNT = 140 -- 허브 하나당 (임시값)
local ROCK_COUNT = 18

-- 템플릿 원본 에셋 (로블록스 공식 템플릿 것)
local MATERIALS = {
	{ name = "MossGrass", base = Enum.Material.Grass, c = 13703366674, n = 13316888753, r = 13316888800, m = 13280829022 },
	{ name = "Moss", base = Enum.Material.Ground, c = 13703366674, n = 13316888753, r = 13316888800, m = 13280829022 },
	{ name = "MossStones", base = Enum.Material.LeafyGrass, c = 13703391879, n = 13326201011, r = 13326200502, m = 13326199923 },
	{ name = "Stones", base = Enum.Material.Sand, c = 13326348142, n = 13326227645, r = 13326227505, m = 13326226958 },
	{ name = "StrataNoisy", base = Enum.Material.Salt, c = 13413097425, n = 13413097894, r = 13413097878 },
	{ name = "Walkway", base = Enum.Material.Snow, c = 13742044281, n = 13742043635, r = 13742042805, m = 13701714303 },
}
-- 지형 재질 → 텍스처 재질. 광산 벽 재질(Ground·Slate·Basalt·Limestone·Rock)·눈 덮인 봉우리(Snow)는 일부러 뺐다
local OVERRIDES = {
	[Enum.Material.Grass] = "MossGrass",
	[Enum.Material.Mud] = "Moss", -- 허브 마당 흙을 Mud로 칠해서 씀 (Ground는 광산 흙층이라 그대로)
	[Enum.Material.LeafyGrass] = "MossStones",
	[Enum.Material.Sand] = "Stones",
}

local FOLIAGE = {
	{ name = "Fern_A", mesh = 13676363152, weight = 3 },
	{ name = "Fern_C", mesh = 13676689934, weight = 4 },
	{ name = "Hostas_A", mesh = 13681432221, weight = 4 },
}
local FOLIAGE_SA = { c = 13762934712, n = 13674996849, r = 13674996487 }
local ROCKS = {
	{ name = "RockSmall", mesh = 13491576237, sa = { c = 13610891836, n = 13610891373, r = 13610891043 }, size = Vector3.new(24, 11, 16) },
	{ name = "RockLarge", mesh = 13537671238, sa = { c = 13610824138, n = 13610823377, r = 13610822782 }, size = Vector3.new(6, 15, 5) },
}

-- 템플릿 조명 값
local LIGHTING = {
	Atmosphere = { Density = 0.285, Offset = 0.65, Color = Color3.new(0.78, 0.78, 0.78), Decay = Color3.new(0.88, 1, 1), Glare = 0.3, Haze = 2 },
	ColorCorrection = { Contrast = 0.08 },
	Bloom = { Intensity = 1.5, Size = 56, Threshold = 2 },
}

---------------------------------------------------------------------------
local CHS = game:GetService("ChangeHistoryService")
local MS = game:GetService("MaterialService")
local InsertService = game:GetService("InsertService")
local T = workspace.Terrain
local rng = Random.new(20261031)
local function id(n) return "rbxassetid://" .. n end

local rec = CHS:TryBeginRecording("NatureLook")

if RUN.MATERIALS then
	for _, m in MATERIALS do
		local mv = MS:FindFirstChild(m.name)
		if not mv then
			mv = Instance.new("MaterialVariant")
			mv.Name = m.name
			mv.BaseMaterial = m.base
			mv.ColorMap = id(m.c)
			mv.NormalMap = id(m.n)
			mv.RoughnessMap = id(m.r)
			if m.m then mv.MetalnessMap = id(m.m) end
			mv.StudsPerTile = 10
			mv.Parent = MS
		end
	end
	print("[NatureLook] 텍스처 재질 준비")
end

if RUN.OVERRIDES then
	for mat, name in OVERRIDES do
		MS:SetBaseMaterialOverride(mat, name)
		pcall(function() T:SetMaterialColor(mat, Color3.new(1, 1, 1)) end) -- 텍스처 색이 그대로 보이게 (흰색 = 물들이지 않음)
	end
	print("[NatureLook] 지형 재질 덮어쓰기: Grass→MossGrass, Mud→Moss, LeafyGrass→MossStones, Sand→Stones")
end

local function hubRegion(dx, a, b)
	return Region3.new(a + Vector3.new(dx, 0, 0), b + Vector3.new(dx, 0, 0)):ExpandToGrid(4)
end

if RUN.REPAINT then
	for _, h in HUBS do
		if workspace:FindFirstChild(h.folder) then
			-- 마당 흙 → 이끼 흙 (광산 흙층 Ground와 분리)
			T:ReplaceMaterial(hubRegion(h.dx, YARD_MIN, YARD_MAX), 4, Enum.Material.Ground, Enum.Material.Mud)
			-- 마당 가장자리에 자갈·이끼돌 얼룩 (광장은 피함)
			for _ = 1, 26 do
				local x = rng:NextNumber(YARD_MIN.X + 6, YARD_MAX.X - 6)
				local z = rng:NextNumber(YARD_MIN.Z + 4, YARD_MAX.Z - 4)
				local inPlaza = x > PLAZA_MIN.X and x < PLAZA_MAX.X and z > PLAZA_MIN.Z and z < PLAZA_MAX.Z
				if not inPlaza then
					local mat = if rng:NextNumber() < 0.55 then Enum.Material.LeafyGrass else Enum.Material.Sand
					local r = rng:NextNumber(5, 11)
					local center = Vector3.new(x + h.dx, 0, z)
					-- 땅 표면만 바꾸도록 얇은 원통 영역에서 Mud·Grass만 교체
					local reg = Region3.new(center - Vector3.new(r, 14, r), center + Vector3.new(r, 10, r)):ExpandToGrid(4)
					T:ReplaceMaterial(reg, 4, Enum.Material.Mud, mat)
					T:ReplaceMaterial(reg, 4, Enum.Material.Grass, mat)
				end
				task.wait()
			end
		end
	end
	print("[NatureLook] 허브 마당 다시 칠함")
end

-- 메시는 MeshId를 바로 못 넣어서 CreateMeshPartAsync로 만든 뒤 복사해 쓴다
local meshCache = {}
local function meshTemplate(meshId, saIds)
	if meshCache[meshId] then return meshCache[meshId] end
	local ok, mp = pcall(function()
		return InsertService:CreateMeshPartAsync(id(meshId), Enum.CollisionFidelity.Hull, Enum.RenderFidelity.Automatic)
	end)
	if not ok then warn("[NatureLook] 메시 불러오기 실패 " .. meshId .. ": " .. tostring(mp)) return nil end
	mp.Anchored = true
	mp.Color = Color3.new(0.97, 0.97, 0.97)
	local sa = Instance.new("SurfaceAppearance")
	sa.ColorMap, sa.NormalMap, sa.RoughnessMap = id(saIds.c), id(saIds.n), id(saIds.r)
	sa.AlphaMode = Enum.AlphaMode.Transparency -- 고사리 잎 가장자리가 투명
	sa.Parent = mp
	meshCache[meshId] = mp
	return mp
end

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
groundParams.FilterDescendantsInstances = { T }

local GROW_ON = { [Enum.Material.Grass] = true, [Enum.Material.Mud] = true, [Enum.Material.LeafyGrass] = true }

if RUN.SCATTER then
	local function pickFoliage()
		local total = 0
		for _, f in FOLIAGE do total += f.weight end
		local roll = rng:NextNumber() * total
		for _, f in FOLIAGE do roll -= f.weight if roll <= 0 then return f end end
		return FOLIAGE[1]
	end
	for _, h in HUBS do
		local hubFolder = workspace:FindFirstChild(h.folder)
		local hub = hubFolder and hubFolder:FindFirstChild("Hub")
		if hub then
			local old = hub:FindFirstChild("Nature")
			if old then old:Destroy() end
			local nature = Instance.new("Folder")
			nature.Name = "Nature"
			local function ground(x, z)
				local hit = workspace:Raycast(Vector3.new(x + h.dx, 120, z), Vector3.new(0, -200, 0), groundParams)
				return hit
			end
			-- 풀
			local placed = 0
			for _ = 1, FOLIAGE_COUNT * 4 do
				if placed >= FOLIAGE_COUNT then break end
				local x = rng:NextNumber(SCATTER_AREA_MIN.X, SCATTER_AREA_MAX.X)
				local z = rng:NextNumber(SCATTER_AREA_MIN.Z, SCATTER_AREA_MAX.Z)
				local inPlaza = x > PLAZA_MIN.X - 4 and x < PLAZA_MAX.X + 4 and z > PLAZA_MIN.Z - 4 and z < PLAZA_MAX.Z + 4
				local hit = not inPlaza and ground(x, z)
				if hit and GROW_ON[hit.Material] and hit.Normal.Y > 0.8 then
					local f = pickFoliage()
					local tpl = meshTemplate(f.mesh, FOLIAGE_SA)
					if tpl then
						local p = tpl:Clone()
						p.Name = f.name
						p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
						p.Size = p.Size * rng:NextNumber(0.8, 1.4)
						p.CFrame = CFrame.new(hit.Position + Vector3.new(0, p.Size.Y * 0.35, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
						p.Parent = nature
						placed += 1
					end
				end
				if placed % 20 == 0 then task.wait() end
			end
			-- 바위: 마당 가장자리·절벽 밑 (광장·포탈 앞은 피함)
			local rocks = 0
			for _ = 1, ROCK_COUNT * 6 do
				if rocks >= ROCK_COUNT then break end
				local x = rng:NextNumber(YARD_MIN.X - 30, YARD_MAX.X + 30)
				local z = rng:NextNumber(YARD_MIN.Z - 20, YARD_MAX.Z + 30)
				local nearEdge = math.abs(x) > 70 or z > 132 or z < 44
				local nearPortal = math.abs(x) < 30 and z < 60
				local hit = nearEdge and not nearPortal and ground(x, z)
				if hit and hit.Material ~= Enum.Material.Cobblestone then
					local r = ROCKS[if rng:NextNumber() < 0.7 then 1 else 2]
					local tpl = meshTemplate(r.mesh, r.sa)
					if tpl then
						local p = tpl:Clone()
						p.Name = r.name
						p.Size = r.size * rng:NextNumber(0.35, 0.9)
						p.CanCollide = true
						-- 아래 1/3을 땅에 묻어서 떠 보이지 않게
						p.CFrame = CFrame.new(hit.Position + Vector3.new(0, p.Size.Y * 0.2, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), math.rad(rng:NextNumber(-8, 8)))
						p.Parent = nature
						rocks += 1
					end
				end
			end
			nature.Parent = hub
			print(`[NatureLook] {h.folder}: 풀 {placed}개, 바위 {rocks}개`)
			task.wait()
		end
	end
end

if RUN.LIGHTING then
	local L = game:GetService("Lighting")
	for className, props in LIGHTING do
		local e = L:FindFirstChildOfClass(className)
		if not e then
			e = Instance.new(className)
			e.Parent = L
		end
		for k, v in props do e[k] = v end
	end
	print("[NatureLook] 템플릿 조명 적용")
end

if rec then CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
print("[NatureLook] 끝. 마음에 들면 Ctrl+S")
