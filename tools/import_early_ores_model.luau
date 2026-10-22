--[[
	1~3스테이지 광물 18종 — 직접 모델링 버전 (Studio 명령창에서 실행)
	그림 텍스처 버전은 tools/import_early_ores.luau. 두 버전을 나란히 비교하려고 따로 둔다.

	순서
	1) 블렌더에서 tools/blender/build_early_ores_model.py → ~/Downloads/CollapseMine/EarlyOresModel.fbx
	2) Studio 가져오기(Ctrl+M) → Workspace.EarlyOresModel
	3) 이 스크립트 → ServerStorage.OreModels.Stage01M~03M.<키> 틀, 견본 Workspace.EarlyOreModelPreview
	   (그림 버전 견본 바로 뒤 줄에 세워 비교)

	MeshPart 이름 규칙: EM_<광석>_<재질>. 색·재질은 아래 LOOK 표. 연출(반짝임·조명·오라)은 그림 버전과 같은 등급 규칙. 임시값.
]]

local CHS = game:GetService("ChangeHistoryService")
local SS = game:GetService("ServerStorage")

local function c3(r, g, b) return Color3.fromRGB(r, g, b) end
local M = Enum.Material

-- 재질 → { 색, Roblox 재질, 투명도, 반사 }
local LOOK = {
	CoalRock = { c3(32, 32, 36), M.Slate, 0, 0.05 },
	CopperRock = { c3(105, 92, 80), M.Rock, 0, 0 },
	CopperMetal = { c3(210, 115, 55), M.Metal, 0, 0.15 },
	CopperPatina = { c3(70, 180, 130), M.SmoothPlastic, 0, 0 },
	QuartzBase = { c3(110, 110, 115), M.Rock, 0, 0 },
	QuartzCrystal = { c3(235, 240, 255), M.Glass, 0.25, 0.1 },
	AmberBody = { c3(255, 150, 30), M.Glass, 0.2, 0.05 },
	AmberLeaf = { c3(90, 55, 20), M.SmoothPlastic, 0, 0 },
	AmberBase = { c3(105, 100, 95), M.Rock, 0, 0 },
	PearlCup = { c3(220, 210, 190), M.Limestone, 0, 0 },
	Pearl = { c3(250, 245, 235), M.SmoothPlastic, 0, 0.25 },
	LanternIron = { c3(95, 62, 42), M.CorrodedMetal, 0, 0 },
	LanternGlass = { c3(255, 210, 150), M.Glass, 0.45, 0 },
	LanternFlame = { c3(255, 140, 40), M.Neon, 0, 0 },
	IronRock = { c3(135, 95, 85), M.Rock, 0, 0 },
	IronMetal = { c3(85, 88, 98), M.Metal, 0, 0.1 },
	TinRock = { c3(55, 45, 40), M.Basalt, 0, 0 },
	TinCrystal = { c3(175, 175, 185), M.Metal, 0, 0.2 },
	SilverRock = { c3(110, 105, 100), M.Rock, 0, 0 },
	SilverMetal = { c3(225, 230, 240), M.Metal, 0, 0.35 },
	MagnetiteBase = { c3(70, 65, 62), M.Rock, 0, 0 },
	MagnetiteCrystal = { c3(28, 28, 38), M.Metal, 0, 0.25 },
	PlatinumMetal = { c3(232, 235, 242), M.Metal, 0, 0.4 },
	WatchBrass = { c3(205, 160, 70), M.Metal, 0, 0.25 },
	WatchFace = { c3(245, 236, 210), M.SmoothPlastic, 0, 0 },
	WatchInk = { c3(40, 30, 25), M.SmoothPlastic, 0, 0 },
	LimeRock = { c3(228, 218, 192), M.Limestone, 0, 0 },
	LimeHole = { c3(150, 138, 115), M.Limestone, 0, 0 },
	CalciteCrystal = { c3(255, 190, 125), M.Glass, 0.2, 0.05 },
	AzuriteRock = { c3(70, 66, 72), M.Slate, 0, 0 },
	AzuriteCrystal = { c3(30, 70, 220), M.Glass, 0.05, 0.1 },
	MalachiteStone = { c3(40, 165, 95), M.Marble, 0, 0.1 },
	Shell = { c3(228, 228, 235), M.SmoothPlastic, 0, 0.1 },
	WaterPearlGem = { c3(150, 225, 255), M.Glass, 0.1, 0.3 },
	WaterDrop = { c3(190, 230, 255), M.Glass, 0.4, 0.2 },
	Paper = { c3(222, 190, 140), M.Fabric, 0, 0 },
	Ink = { c3(95, 62, 40), M.SmoothPlastic, 0, 0 },
	InkRed = { c3(200, 40, 30), M.SmoothPlastic, 0, 0 },
}

local ORES = {
	{ key = "Coal", name = "석탄", set = "Stage01M", grade = "일반", glow = c3(120, 120, 130) },
	{ key = "Copper", name = "구리", set = "Stage01M", grade = "일반", glow = c3(255, 150, 80) },
	{ key = "Quartz", name = "석영", set = "Stage01M", grade = "고급", glow = c3(235, 240, 255) },
	{ key = "Amber", name = "호박석", set = "Stage01M", grade = "희귀", glow = c3(255, 170, 60) },
	{ key = "CavePearl", name = "동굴 진주", set = "Stage01M", grade = "에픽", glow = c3(255, 240, 220) },
	{ key = "Lantern", name = "광부의 녹슨 등불", set = "Stage01M", grade = "전설", glow = c3(255, 150, 50) },
	{ key = "Iron", name = "철", set = "Stage02M", grade = "일반", glow = c3(200, 140, 120) },
	{ key = "Tin", name = "주석", set = "Stage02M", grade = "일반", glow = c3(190, 190, 200) },
	{ key = "Silver", name = "은", set = "Stage02M", grade = "고급", glow = c3(230, 235, 245) },
	{ key = "Magnetite", name = "자철석", set = "Stage02M", grade = "희귀", glow = c3(120, 150, 255) },
	{ key = "Platinum", name = "백금", set = "Stage02M", grade = "에픽", glow = c3(240, 245, 255) },
	{ key = "PocketWatch", name = "감독관의 회중시계", set = "Stage02M", grade = "전설", glow = c3(255, 210, 110) },
	{ key = "Limestone", name = "석회석", set = "Stage03M", grade = "일반", glow = c3(240, 230, 200) },
	{ key = "Calcite", name = "방해석", set = "Stage03M", grade = "일반", glow = c3(255, 200, 130) },
	{ key = "Azurite", name = "남동석", set = "Stage03M", grade = "고급", glow = c3(70, 110, 255) },
	{ key = "Malachite", name = "공작석", set = "Stage03M", grade = "희귀", glow = c3(80, 220, 140) },
	{ key = "WaterPearl", name = "물빛 진주", set = "Stage03M", grade = "에픽", glow = c3(140, 220, 255) },
	{ key = "WetMap", name = "젖은 광산 지도", set = "Stage03M", grade = "전설", glow = c3(255, 220, 150) },
}
local RANK = { ["일반"] = 1, ["고급"] = 2, ["희귀"] = 3, ["에픽"] = 4, ["전설"] = 5 }
local PREVIEW_ORIGIN = CFrame.new(1000, 600, 40) -- 그림 버전 견본(z 20~32) 뒤

local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local function ns(a, b) return NumberSequence.new({ NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(1, b) }) end
local function fade(a) return NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, a), NumberSequenceKeypoint.new(1, 1) }) end
local function emitter(parent, name, props)
	local pe = Instance.new("ParticleEmitter")
	pe.Name = name
	pe.LightEmission = 1
	for k, v in props do pe[k] = v end
	pe.Parent = parent
end

local function decorate(o, body, model)
	local r = RANK[o.grade]
	if r >= 3 then
		emitter(body, "Sparkle", { Texture = SPARK, Color = ColorSequence.new(o.glow), Size = ns(0.3, 0), Transparency = ns(0.2, 1),
			Lifetime = NumberRange.new(0.8, 1.6), Rate = r >= 4 and 6 or 3, Speed = NumberRange.new(0.3, 0.8), SpreadAngle = Vector2.new(180, 180) })
	end
	if r >= 4 then
		local l = Instance.new("PointLight")
		l.Color, l.Range, l.Brightness = o.glow, 9, 1.2
		l.Parent = body
	end
	if r >= 5 then
		emitter(body, "Aura", { Texture = SMOKE, Color = ColorSequence.new(o.glow), Size = ns(1.3, 2.6), Transparency = fade(0.75),
			Lifetime = NumberRange.new(1.5, 2.5), Rate = 5, Speed = NumberRange.new(0.4, 0.9), SpreadAngle = Vector2.new(30, 30),
			Acceleration = Vector3.new(0, 0.6, 0), RotSpeed = NumberRange.new(-30, 30) })
		local hl = Instance.new("Highlight")
		hl.Name = "AuraOutline"
		hl.FillTransparency = 1
		hl.OutlineColor = o.glow
		hl.OutlineTransparency = 0.3
		hl.DepthMode = Enum.HighlightDepthMode.Occluded
		hl.Adornee = model
		hl.Parent = model
	end
end

local imported = assert(workspace:FindFirstChild("EarlyOresModel"), "Workspace에 EarlyOresModel 모델이 없음 (FBX 가져오기 먼저)")
local rec = CHS:TryBeginRecording("ImportEarlyOresModel")

local byOre = {}
for _, mp in imported:GetDescendants() do
	if mp:IsA("MeshPart") then
		local ore, mat = mp.Name:match("^EM_(%a+)_(%a+)$")
		local l = mat and LOOK[mat]
		if ore and l then
			mp.Color, mp.Material, mp.Transparency, mp.Reflectance = l[1], l[2], l[3], l[4]
			mp.Anchored, mp.CanCollide = true, false
			mp.Name = mat
			byOre[ore] = byOre[ore] or {}
			table.insert(byOre[ore], mp)
		end
	end
end

local root = SS:FindFirstChild("OreModels") or Instance.new("Folder")
root.Name = "OreModels"; root.Parent = SS
local preview = workspace:FindFirstChild("EarlyOreModelPreview")
if preview then preview:Destroy() end
preview = Instance.new("Model"); preview.Name = "EarlyOreModelPreview"

local count = 0
for i, o in ipairs(ORES) do
	local parts = byOre[o.key]
	if parts then
		local m = Instance.new("Model")
		m.Name = o.key
		m:SetAttribute("DisplayName", o.name)
		m:SetAttribute("Grade", o.grade)
		for _, p in parts do p.Parent = m end
		local cf, size = m:GetBoundingBox()
		local body = Instance.new("Part")
		body.Name = "Hitbox"
		body.Size = size * 0.9
		body.CFrame = cf
		body.Transparency = 1
		body.Anchored, body.CanCollide = true, true
		body.Parent = m
		m.PrimaryPart = body
		body.PivotOffset = body.CFrame:ToObjectSpace(CFrame.new(cf.Position.X, cf.Position.Y - size.Y / 2, cf.Position.Z))
		if o.key == "Lantern" then
			local l = Instance.new("PointLight")
			l.Color, l.Range, l.Brightness = c3(255, 160, 70), 12, 1.6
			l.Parent = m:FindFirstChild("LanternFlame") or body
		end
		decorate(o, body, m)
		m:PivotTo(CFrame.new())

		local folder = root:FindFirstChild(o.set) or Instance.new("Folder")
		folder.Name = o.set; folder.Parent = root
		local old = folder:FindFirstChild(o.key)
		if old then old:Destroy() end
		m.Parent = folder

		local c = m:Clone()
		local row, col = (i - 1) // 6, (i - 1) % 6
		c:PivotTo(PREVIEW_ORIGIN * CFrame.new(-15 + col * 6, 0, row * 6))
		c.Parent = preview
		count += 1
	end
end
imported:Destroy()
preview.Parent = workspace
if rec then CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
print("[EarlyOresModel] " .. count .. "종 → ServerStorage.OreModels.Stage01M~03M")
