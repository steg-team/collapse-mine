--[[
	허브 건물 3개(판매소·제작소·랭킹판)를 짓는 스크립트 (Studio 명령창에서 실행)

	셋 다 같은 나무 가판대였던 것을, 멀리서 봐도 무슨 건물인지 알 수 있게 다시 짓는다.
	- 판매소(Shop): 줄무늬 차양, 저울, 광석 상자, 금화 더미
	- 제작소(Workshop): 돌 대장간, 굴뚝 연기, 화덕 불, 모루, 곡괭이 걸이
	- 랭킹판(Leaderboard): 3칸 게시판 + 트로피 (docs/decisions.md D-009 랭킹 3종)

	기능 연결 지점 (B·C 담당이 프롬프트·UI를 붙일 곳)
	- 각 건물의 `Counter` 파트: 판매·제작 상호작용 위치
	- 랭킹판 `Board_BestHaul`, `Board_BestOre`, `Board_TotalEarned` 파트의 SurfaceGui 안 `Rows` 프레임에
	  `Row1`~`Row5` TextLabel이 있다. 서버에서 Text만 바꾸면 된다.

	다시 실행하면 기존 건물은 ServerStorage.OldHubBuildingsBackup 으로 옮기고 새로 짓는다.
	허브 바닥 y=1 기준. 건물 로컬 앞면은 -Z이고, ORIGINS의 회전으로 광장을 바라보게 놓는다.
]]

local CHS = game:GetService("ChangeHistoryService")
local SS = game:GetService("ServerStorage")

local hub = workspace.CollapseMine.Hub
-- 건물 자리 (바닥 중앙, 앞면이 바라보는 방향). 셋이 광장을 ㄷ자로 둘러싸고 스폰·광산 입구 쪽을 본다
local ORIGINS = {
	Workshop = CFrame.new(0, 1, 116),                                         -- 안쪽 가운데, 남쪽(입구)을 봄
	Shop = CFrame.new(-58, 1, 90) * CFrame.Angles(0, math.rad(-90), 0),       -- 서쪽, 광장(+X)을 봄
	Leaderboard = CFrame.new(58, 1, 90) * CFrame.Angles(0, math.rad(90), 0),  -- 동쪽, 광장(-X)을 봄
}

-- 색
local WOOD = Color3.fromRGB(122, 84, 52)
local WOOD_DARK = Color3.fromRGB(78, 52, 34)
local STONE = Color3.fromRGB(120, 116, 110)
local STONE_DARK = Color3.fromRGB(84, 80, 76)
local IRON = Color3.fromRGB(60, 60, 66)
local GOLD = Color3.fromRGB(240, 190, 60)
local ROOF_RED = Color3.fromRGB(150, 62, 48)
local ROOF_DARK = Color3.fromRGB(70, 58, 52)
local ROOF_BLUE = Color3.fromRGB(52, 74, 120)
local CLOTH_A = Color3.fromRGB(196, 58, 52)
local CLOTH_B = Color3.fromRGB(238, 228, 205)
local FIRE = Color3.fromRGB(255, 160, 70)

local rec = CHS:TryBeginRecording("BuildHubBuildings")

-- 기존 건물 백업
local backup = SS:FindFirstChild("OldHubBuildingsBackup") or Instance.new("Folder")
backup.Name = "OldHubBuildingsBackup"
backup.Parent = SS
for _, n in ipairs({ "Shop", "Workshop", "Leaderboard" }) do
	local old = hub:FindFirstChild(n)
	if old then
		local prev = backup:FindFirstChild(n)
		if prev then prev:Destroy() end
		old.Parent = backup
	end
end

local function part(parent, name, size, cf, color, mat, shape)
	local p = Instance.new("Part")
	p.Name = name
	if shape then p.Shape = shape end
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.Color = color
	p.Material = mat
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end
local VERT = CFrame.Angles(0, 0, math.rad(90)) -- 원통 축을 세로로

local function addFire(p, size, range)
	local f = Instance.new("Fire")
	f.Size, f.Heat = size, size * 1.5
	f.Color, f.SecondaryColor = FIRE, Color3.fromRGB(255, 220, 120)
	f.Parent = p
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness = FIRE, range, 1.8
	l.Parent = p
end

-- 앞쪽에 매다는 간판 (앞면에 글자)
local function sign(parent, base, y, z, w, title, sub, bg)
	local board = part(parent, "Sign", Vector3.new(w, 3.6, 0.5), base * CFrame.new(0, y, z), bg or WOOD, Enum.Material.WoodPlanks)
	part(parent, "SignFrame", Vector3.new(w + 0.8, 4.4, 0.3), base * CFrame.new(0, y, z + 0.35), WOOD_DARK, Enum.Material.Wood)
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 40
	sg.LightInfluence = 0.2
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, sub and 0.68 or 1)
	t.TextScaled = true
	t.Font = Enum.Font.GothamBlack
	t.TextColor3 = Color3.fromRGB(255, 236, 190)
	t.TextStrokeTransparency = 0.4
	t.Text = title
	t.Parent = sg
	if sub then
		local s = Instance.new("TextLabel")
		s.BackgroundTransparency = 1
		s.Position = UDim2.fromScale(0, 0.64)
		s.Size = UDim2.fromScale(1, 0.32)
		s.TextScaled = true
		s.Font = Enum.Font.GothamBold
		s.TextColor3 = Color3.fromRGB(235, 210, 165)
		s.Text = sub
		s.Parent = sg
	end
	sg.Parent = board
	return board
end

-- 박공 지붕 (용마루가 X 방향)
local function gableRoof(parent, base, w, d, y, pitch, color, mat)
	local a = math.rad(pitch)
	local half = d / 2
	local slab = half / math.cos(a) + 0.8
	local rise = math.tan(a) * half
	for _, s in ipairs({ -1, 1 }) do
		part(parent, "Roof", Vector3.new(w, 0.8, slab), base * CFrame.new(0, y + rise / 2, s * half / 2) * CFrame.Angles(s * a, 0, 0), color, mat)
	end
	part(parent, "RoofRidge", Vector3.new(w + 0.4, 0.9, 0.9), base * CFrame.new(0, y + rise + 0.2, 0), WOOD_DARK, Enum.Material.Wood)
	return y + rise
end

local function logPost(parent, base, x, z, h, color)
	part(parent, "Post", Vector3.new(h, 1.3, 1.3), base * CFrame.new(x, h / 2, z) * VERT, color or WOOD_DARK, Enum.Material.Wood, Enum.PartType.Cylinder)
end

local function crate(parent, base, x, z, s, oreColor)
	part(parent, "Crate", Vector3.new(s, s, s), base * CFrame.new(x, s / 2, z), WOOD, Enum.Material.WoodPlanks)
	part(parent, "CrateBand", Vector3.new(s + 0.1, 0.3, s + 0.1), base * CFrame.new(x, s * 0.8, z), WOOD_DARK, Enum.Material.Wood)
	if oreColor then
		for i = 1, 4 do
			local ox, oz = (i % 2 == 0 and 0.25 or -0.25) * s, (i > 2 and 0.25 or -0.25) * s
			local ore = part(parent, "CrateOre", Vector3.new(s * 0.45, s * 0.4, s * 0.45), base * CFrame.new(x + ox, s + 0.1, z + oz) * CFrame.Angles(i, i * 0.7, 0), oreColor, Enum.Material.Slate)
			ore.CanCollide = false
		end
	end
end

local function newModel(name)
	local m = Instance.new("Model")
	m.Name = name
	return m, ORIGINS[name]
end

------------------------------------------------------------------ 판매소
do
	local m, b = newModel("Shop")
	part(m, "Floor", Vector3.new(24, 1, 16), b * CFrame.new(0, 0.5, 0), WOOD, Enum.Material.WoodPlanks)
	part(m, "BackWall", Vector3.new(24, 11, 1), b * CFrame.new(0, 6.5, 7.5), WOOD, Enum.Material.WoodPlanks)
	for _, x in ipairs({ -11.4, 11.4 }) do
		part(m, "SideWall", Vector3.new(1, 11, 8), b * CFrame.new(x, 6.5, 3.5), WOOD, Enum.Material.WoodPlanks)
	end
	for _, x in ipairs({ -11.4, 11.4 }) do
		logPost(m, b, x, -7.4, 12)
		logPost(m, b, x, 7.4, 12)
	end
	part(m, "Beam", Vector3.new(24, 1, 1), b * CFrame.new(0, 12, -7.4), WOOD_DARK, Enum.Material.Wood)
	gableRoof(m, b, 27, 18, 12.4, 28, ROOF_RED, Enum.Material.WoodPlanks)

	-- 줄무늬 차양
	for i = 0, 7 do
		local x = -10.5 + i * 3
		part(m, "Awning", Vector3.new(3, 0.25, 5), b * CFrame.new(x, 10.6, -9.6) * CFrame.Angles(math.rad(-22), 0, 0), (i % 2 == 0) and CLOTH_A or CLOTH_B, Enum.Material.Fabric)
	end

	-- 계산대 + 저울
	local counter = part(m, "Counter", Vector3.new(16, 3.6, 2.6), b * CFrame.new(0, 2.8, -4.5), WOOD_DARK, Enum.Material.WoodPlanks)
	part(m, "CounterTop", Vector3.new(16.6, 0.4, 3.2), b * CFrame.new(0, 4.8, -4.5), WOOD, Enum.Material.Wood)
	part(m, "ScalePost", Vector3.new(0.4, 3.4, 0.4), b * CFrame.new(-3, 6.7, -4.5), GOLD, Enum.Material.Metal)
	part(m, "ScaleBeam", Vector3.new(4, 0.3, 0.3), b * CFrame.new(-3, 8.3, -4.5), GOLD, Enum.Material.Metal)
	for _, dx in ipairs({ -1.8, 1.8 }) do
		part(m, "ScaleString", Vector3.new(0.1, 1.6, 0.1), b * CFrame.new(-3 + dx, 7.4, -4.5), IRON, Enum.Material.Metal)
		part(m, "ScalePan", Vector3.new(0.2, 1.6, 1.6), b * CFrame.new(-3 + dx, 6.55, -4.5) * VERT, GOLD, Enum.Material.Metal, Enum.PartType.Cylinder)
	end
	-- 금화 더미
	for i = 0, 4 do
		part(m, "Coins", Vector3.new(0.3, 1.1 - i * 0.12, 1.1 - i * 0.12), b * CFrame.new(3 + (i % 2) * 0.15, 5.15 + i * 0.3, -4.5) * VERT, GOLD, Enum.Material.Metal, Enum.PartType.Cylinder)
	end
	part(m, "CoinSack", Vector3.new(1.8, 1.8, 1.8), b * CFrame.new(5.5, 5.8, -4.3), Color3.fromRGB(170, 140, 95), Enum.Material.Fabric, Enum.PartType.Ball)

	-- 광석 상자 (석탄·구리·철)
	crate(m, b, -9, -10.5, 2.6, Color3.fromRGB(40, 40, 44))
	crate(m, b, -6.3, -10.8, 2.2, Color3.fromRGB(196, 110, 60))
	crate(m, b, 8.5, -10.5, 2.6, Color3.fromRGB(170, 160, 150))
	-- 뒤쪽 선반 위 광석
	part(m, "Shelf", Vector3.new(18, 0.4, 1.6), b * CFrame.new(0, 7.2, 6.4), WOOD_DARK, Enum.Material.Wood)
	for i = 0, 5 do
		local c = ({ Color3.fromRGB(40, 40, 44), Color3.fromRGB(196, 110, 60), Color3.fromRGB(150, 160, 170) })[i % 3 + 1]
		part(m, "ShelfOre", Vector3.new(1.4, 1.2, 1.2), b * CFrame.new(-7.5 + i * 3, 8, 6.4) * CFrame.Angles(0, i, 0.4), c, Enum.Material.Slate)
	end

	sign(m, b, 14.2, -9.4, 13, "💰 판매소", "광물 판매", WOOD)
	-- 입구 등불
	for _, x in ipairs({ -12.6, 12.6 }) do
		local lamp = part(m, "Lantern", Vector3.new(0.9, 1.2, 0.9), b * CFrame.new(x, 9.2, -8.2), Color3.fromRGB(255, 200, 110), Enum.Material.Neon)
		local l = Instance.new("PointLight"); l.Color, l.Range, l.Brightness = FIRE, 16, 1.4; l.Parent = lamp
	end
	m.PrimaryPart = counter
	m.Parent = hub
end
task.wait()

------------------------------------------------------------------ 제작소 (가운데, 가장 큼)
do
	local m, b = newModel("Workshop")
	part(m, "Floor", Vector3.new(28, 1, 18), b * CFrame.new(0, 0.5, 0), STONE, Enum.Material.Cobblestone)
	-- 뒷벽: 아래는 돌, 위는 나무
	part(m, "BackWallStone", Vector3.new(28, 5, 1.4), b * CFrame.new(0, 3.5, 8.3), STONE_DARK, Enum.Material.Cobblestone)
	part(m, "BackWallWood", Vector3.new(28, 8, 1), b * CFrame.new(0, 10, 8.4), WOOD_DARK, Enum.Material.WoodPlanks)
	for _, x in ipairs({ -13.4, 13.4 }) do
		part(m, "SideWall", Vector3.new(1.2, 13, 9), b * CFrame.new(x, 7.5, 4), STONE_DARK, Enum.Material.Cobblestone)
		logPost(m, b, x, -8.4, 14)
	end
	part(m, "Beam", Vector3.new(28, 1.2, 1.2), b * CFrame.new(0, 14, -8.4), WOOD_DARK, Enum.Material.Wood)
	gableRoof(m, b, 31, 20, 14.4, 30, ROOF_DARK, Enum.Material.Slate)

	-- 굴뚝 + 연기
	local chim = part(m, "Chimney", Vector3.new(4, 26, 4), b * CFrame.new(-9, 13, 6.5), STONE_DARK, Enum.Material.Brick)
	part(m, "ChimneyCap", Vector3.new(4.8, 0.8, 4.8), b * CFrame.new(-9, 26.4, 6.5), STONE, Enum.Material.Cobblestone)
	local smokeSrc = part(m, "SmokeSource", Vector3.new(1, 1, 1), b * CFrame.new(-9, 27.2, 6.5), STONE, Enum.Material.SmoothPlastic)
	smokeSrc.Transparency = 1; smokeSrc.CanCollide = false
	local smoke = Instance.new("Smoke")
	smoke.Color, smoke.Opacity, smoke.RiseVelocity, smoke.Size = Color3.fromRGB(90, 88, 86), 0.25, 6, 4
	smoke.Parent = smokeSrc

	-- 화덕 (굴뚝 아래)
	part(m, "Forge", Vector3.new(7, 4, 5), b * CFrame.new(-8.5, 3, 4.5), STONE, Enum.Material.Cobblestone)
	part(m, "ForgeHood", Vector3.new(6, 3, 4), b * CFrame.new(-8.5, 8.5, 5) , STONE_DARK, Enum.Material.Brick)
	local coals = part(m, "ForgeCoals", Vector3.new(5, 0.6, 3.4), b * CFrame.new(-8.5, 5.2, 4.3), Color3.fromRGB(255, 110, 40), Enum.Material.Neon)
	addFire(coals, 4, 24)

	-- 모루
	part(m, "AnvilStump", Vector3.new(2.4, 2.2, 2.2), b * CFrame.new(1, 2.1, -1) * VERT, WOOD_DARK, Enum.Material.Wood, Enum.PartType.Cylinder)
	part(m, "AnvilWaist", Vector3.new(1.4, 1.2, 1.2), b * CFrame.new(1, 3.8, -1), IRON, Enum.Material.Metal)
	part(m, "AnvilTop", Vector3.new(3.2, 1, 1.6), b * CFrame.new(1, 4.9, -1), IRON, Enum.Material.Metal)
	part(m, "AnvilHorn", Vector3.new(1.4, 0.7, 1), b * CFrame.new(-1.2, 5, -1) * CFrame.Angles(0, 0, math.rad(-12)), IRON, Enum.Material.Metal)
	part(m, "Hammer", Vector3.new(0.3, 0.3, 2), b * CFrame.new(1.4, 5.55, -1.2) * CFrame.Angles(0, 0.4, 0), WOOD, Enum.Material.Wood)
	part(m, "HammerHead", Vector3.new(0.8, 0.6, 0.6), b * CFrame.new(1.8, 5.6, -2.1) * CFrame.Angles(0, 0.4, 0), IRON, Enum.Material.Metal)

	-- 물통
	part(m, "QuenchTub", Vector3.new(2, 2.6, 2.6), b * CFrame.new(-3.5, 2, 1) * VERT, WOOD, Enum.Material.WoodPlanks, Enum.PartType.Cylinder)
	part(m, "QuenchWater", Vector3.new(0.2, 2.2, 2.2), b * CFrame.new(-3.5, 3.2, 1) * VERT, Color3.fromRGB(60, 110, 150), Enum.Material.Glass, Enum.PartType.Cylinder)

	-- 뒷벽 곡괭이 걸이 (등급별 머리 색)
	part(m, "ToolRack", Vector3.new(12, 0.6, 0.8), b * CFrame.new(5, 11.5, 7.6), WOOD, Enum.Material.Wood)
	local heads = { Color3.fromRGB(120, 110, 100), Color3.fromRGB(196, 110, 60), Color3.fromRGB(170, 175, 185), Color3.fromRGB(240, 190, 60), Color3.fromRGB(90, 200, 220) }
	for i, c in ipairs(heads) do
		local x = 0.5 + (i - 1) * 2.4
		part(m, "RackHandle", Vector3.new(0.35, 4.2, 0.35), b * CFrame.new(x, 9.2, 7.5), WOOD, Enum.Material.Wood)
		part(m, "RackHead", Vector3.new(2.2, 0.45, 0.45), b * CFrame.new(x, 11.1, 7.3), c, Enum.Material.Metal)
	end

	-- 계산대
	local counter = part(m, "Counter", Vector3.new(10, 3.6, 2.6), b * CFrame.new(6, 2.8, -5.5), WOOD_DARK, Enum.Material.WoodPlanks)
	part(m, "CounterTop", Vector3.new(10.6, 0.4, 3.2), b * CFrame.new(6, 4.8, -5.5), WOOD, Enum.Material.Wood)
	part(m, "Blueprint", Vector3.new(3, 0.1, 2), b * CFrame.new(5, 5.05, -5.5) * CFrame.Angles(0, 0.2, 0), Color3.fromRGB(70, 110, 170), Enum.Material.SmoothPlastic)

	-- 쇠 장식 간판
	sign(m, b, 16.6, -10.4, 15, "🔨 제작소", "곡괭이 제작 · 강화", Color3.fromRGB(95, 66, 44))
	for _, x in ipairs({ -15, 15 }) do
		local brazier = part(m, "Brazier", Vector3.new(1.2, 2.4, 2.4), b * CFrame.new(x, 10.6, -9) * VERT, IRON, Enum.Material.Metal, Enum.PartType.Cylinder)
		part(m, "BrazierArm", Vector3.new(1.6, 0.3, 0.3), b * CFrame.new(x + (x > 0 and -1 or 1), 10, -9), IRON, Enum.Material.Metal)
		local ember = part(m, "BrazierEmber", Vector3.new(0.2, 2, 2), b * CFrame.new(x, 11.3, -9) * VERT, Color3.fromRGB(255, 120, 40), Enum.Material.Neon, Enum.PartType.Cylinder)
		addFire(ember, 3, 18)
		brazier.CanCollide = false
	end
	m.PrimaryPart = counter
	m.Parent = hub
end
task.wait()

------------------------------------------------------------------ 랭킹판
do
	local m, b = newModel("Leaderboard")
	part(m, "Plinth", Vector3.new(26, 1.6, 8), b * CFrame.new(0, 0.8, 2), STONE, Enum.Material.Cobblestone)
	part(m, "PlinthStep", Vector3.new(22, 0.8, 2.4), b * CFrame.new(0, 0.4, -3.2), STONE, Enum.Material.Cobblestone)

	local boards = {
		{ id = "Board_BestHaul", title = "⭐ 최고 탈출 수확", sub = "이번 주 · 붕괴 한 번에 들고 나온 가치", color = Color3.fromRGB(70, 45, 30) },
		{ id = "Board_BestOre", title = "💎 최고 광물", sub = "전체 기간 · 한 덩이 최고가", color = Color3.fromRGB(40, 52, 78) },
		{ id = "Board_TotalEarned", title = "💰 누적 수입", sub = "전체 기간 · 지금까지 번 코인", color = Color3.fromRGB(44, 66, 44) },
	}
	local W, H = 7.4, 11
	for i, info in ipairs(boards) do
		local x = (2 - i) * 8.2 -- 앞(-Z)에서 볼 때 왼쪽부터 1, 2, 3번
		local panel = part(m, info.id, Vector3.new(W, H, 0.6), b * CFrame.new(x, 1.6 + 1.2 + H / 2, 2), info.color, Enum.Material.WoodPlanks)
		part(m, "PanelFrame", Vector3.new(W + 0.8, H + 0.8, 0.5), b * CFrame.new(x, 1.6 + 1.2 + H / 2, 2.4), WOOD_DARK, Enum.Material.Wood)
		local sg = Instance.new("SurfaceGui")
		sg.Name = "Board"
		sg.Face = Enum.NormalId.Front
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = 40
		sg.LightInfluence = 0.15
		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.BackgroundTransparency = 1
		title.Position = UDim2.fromScale(0.05, 0.02)
		title.Size = UDim2.fromScale(0.9, 0.12)
		title.TextScaled = true
		title.Font = Enum.Font.GothamBlack
		title.TextColor3 = Color3.fromRGB(255, 225, 150)
		title.Text = info.title
		title.Parent = sg
		local sub = Instance.new("TextLabel")
		sub.Name = "Subtitle"
		sub.BackgroundTransparency = 1
		sub.Position = UDim2.fromScale(0.05, 0.14)
		sub.Size = UDim2.fromScale(0.9, 0.06)
		sub.TextScaled = true
		sub.Font = Enum.Font.Gotham
		sub.TextColor3 = Color3.fromRGB(220, 205, 180)
		sub.Text = info.sub
		sub.Parent = sg
		local rows = Instance.new("Frame")
		rows.Name = "Rows"
		rows.BackgroundTransparency = 1
		rows.Position = UDim2.fromScale(0.06, 0.24)
		rows.Size = UDim2.fromScale(0.88, 0.72)
		rows.Parent = sg
		local medals = { Color3.fromRGB(255, 210, 80), Color3.fromRGB(210, 215, 225), Color3.fromRGB(215, 145, 90) }
		for r = 1, 5 do
			local row = Instance.new("TextLabel")
			row.Name = "Row" .. r
			row.BackgroundColor3 = Color3.new(0, 0, 0)
			row.BackgroundTransparency = 0.75
			row.BorderSizePixel = 0
			row.Position = UDim2.fromScale(0, (r - 1) * 0.2)
			row.Size = UDim2.fromScale(1, 0.17)
			row.TextScaled = true
			row.TextXAlignment = Enum.TextXAlignment.Left
			row.Font = Enum.Font.GothamBold
			row.TextColor3 = medals[r] or Color3.fromRGB(235, 230, 220)
			row.Text = ("  %d.  —"):format(r)
			row.Parent = rows
		end
		sg.Parent = panel
	end
	-- 게시판 기둥과 지붕
	for _, x in ipairs({ -12.6, 12.6 }) do
		logPost(m, b, x, 2, 17.6)
	end
	gableRoof(m, b * CFrame.new(0, 0, 2), 28, 4.4, 17.6, 25, ROOF_BLUE, Enum.Material.WoodPlanks)
	-- 트로피
	local tb = b * CFrame.new(0, 19.4, 2)
	part(m, "TrophyBase", Vector3.new(2.6, 1, 2.6), tb * CFrame.new(0, 0.5, 0), WOOD_DARK, Enum.Material.Wood)
	part(m, "TrophyStem", Vector3.new(1.4, 0.6, 0.6), tb * CFrame.new(0, 1.7, 0) * VERT, GOLD, Enum.Material.Metal, Enum.PartType.Cylinder)
	part(m, "TrophyCup", Vector3.new(2.8, 2.8, 2.8), tb * CFrame.new(0, 3.4, 0), GOLD, Enum.Material.Metal, Enum.PartType.Ball)
	part(m, "TrophyRim", Vector3.new(0.4, 2.6, 2.6), tb * CFrame.new(0, 4.5, 0) * VERT, GOLD, Enum.Material.Metal, Enum.PartType.Cylinder)
	for _, s in ipairs({ -1, 1 }) do
		part(m, "TrophyHandle", Vector3.new(0.4, 1.6, 0.4), tb * CFrame.new(s * 1.7, 3.6, 0) * CFrame.Angles(0, 0, math.rad(s * 20)), GOLD, Enum.Material.Metal)
	end
	local glow = Instance.new("PointLight"); glow.Color, glow.Range, glow.Brightness = GOLD, 14, 1.2
	glow.Parent = m.TrophyCup
	-- 양쪽 횃대
	for _, x in ipairs({ -14.6, 14.6 }) do
		part(m, "TorchPole", Vector3.new(9, 0.8, 0.8), b * CFrame.new(x, 4.5, -2) * VERT, WOOD_DARK, Enum.Material.Wood, Enum.PartType.Cylinder)
		part(m, "TorchBowl", Vector3.new(0.8, 2, 2), b * CFrame.new(x, 9.2, -2) * VERT, IRON, Enum.Material.Metal, Enum.PartType.Cylinder)
		local e = part(m, "TorchEmber", Vector3.new(0.2, 1.6, 1.6), b * CFrame.new(x, 9.7, -2) * VERT, Color3.fromRGB(255, 120, 40), Enum.Material.Neon, Enum.PartType.Cylinder)
		addFire(e, 3, 18)
	end
	sign(m, b, 15.7, 1.2, 11, "🏆 랭킹", nil, Color3.fromRGB(60, 50, 90))
	m.PrimaryPart = m.Board_BestHaul
	m.Parent = hub
end

if rec then CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
print("[HubBuildings] 판매소·제작소·랭킹판 완료 (이전 건물은 ServerStorage.OldHubBuildingsBackup)")
