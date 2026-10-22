--[[
	1~3스테이지 광물 18종 — 그림 텍스처 버전, 앞·옆 턴어라운드 그림 사용 (Studio 명령창에서 실행)
	광물 목록·등급: 기획서 "광물 도감 전체" (1. 흙 동굴, 2. 철광 갱도, 3. 지하수 동굴)

	흐름 (별이 떨어진 곳과 같음, tools/import_starfall_tex.luau 참고)
	1) 제미나이 그림 18장(ref/ore_*.png)을 첨부해 같은 물건의 "앞 | 옆" 턴어라운드 시트 18장 → ref/turn_<번호>_<이름>.png
	2) 블렌더: tools/blender/build_ores_turnaround.py → 텍스처 tex/TT_<키>_Color.png(왼쪽 반 앞, 오른쪽 반 옆),
	   빛 나는 광물만 _Emissive.png, 메시 EarlyOresTurn.fbx (메시 이름 TT_<키>)
	3) 텍스처 업로드 → 아래 ORES 표의 color / emissive
	4) Studio 가져오기(Ctrl+M)로 EarlyOresTurn.fbx → Workspace.EarlyOresTurn
	5) 이 스크립트 → ServerStorage.OreModels.Stage01~03.<키> 틀, 견본 Workspace.EarlyOrePreview (하늘 진열대 옆)

	오라·빛 세기는 임시값. 등급이 높을수록 연출을 세게 (희귀: 반짝임, 에픽: + 조명, 전설: + 오라·외곽선).
]]

local CHS = game:GetService("ChangeHistoryService")
local SS = game:GetService("ServerStorage")

local function c3(r, g, b) return Color3.fromRGB(r, g, b) end

-- set: 템플릿 폴더, grade: 기획서 등급, glow: 조명·반짝임 색, emissive: 빛 마스크(있는 광물만)
local ORES = {
	{ key = "Coal", name = "석탄", set = "Stage01", grade = "일반", color = "rbxassetid://80461029430297", glow = c3(120, 120, 130) },
	{ key = "Copper", name = "구리", set = "Stage01", grade = "일반", color = "rbxassetid://110264352650404", glow = c3(255, 150, 80) },
	{ key = "Quartz", name = "석영", set = "Stage01", grade = "고급", color = "rbxassetid://96902817991930", glow = c3(235, 240, 255) },
	{ key = "Amber", name = "호박석", set = "Stage01", grade = "희귀", color = "rbxassetid://121588518350131", emissive = "rbxassetid://135387617344031", tint = c3(255, 170, 60), strength = 2, glow = c3(255, 170, 60) },
	{ key = "CavePearl", name = "동굴 진주", set = "Stage01", grade = "에픽", color = "rbxassetid://99250308122949", emissive = "rbxassetid://89022014529954", tint = c3(255, 245, 225), strength = 1.5, glow = c3(255, 240, 220) },
	{ key = "Lantern", name = "광부의 녹슨 등불", set = "Stage01", grade = "전설", color = "rbxassetid://139968422731890", emissive = "rbxassetid://131164126995684", tint = c3(255, 160, 60), strength = 5, glow = c3(255, 150, 50) },
	{ key = "Iron", name = "철", set = "Stage02", grade = "일반", color = "rbxassetid://132515889961135", glow = c3(200, 140, 120) },
	{ key = "Tin", name = "주석", set = "Stage02", grade = "일반", color = "rbxassetid://74272577891781", glow = c3(190, 190, 200) },
	{ key = "Silver", name = "은", set = "Stage02", grade = "고급", color = "rbxassetid://115213268152057", glow = c3(230, 235, 245) },
	{ key = "Magnetite", name = "자철석", set = "Stage02", grade = "희귀", color = "rbxassetid://121422086747493", glow = c3(120, 150, 255) },
	{ key = "Platinum", name = "백금", set = "Stage02", grade = "에픽", color = "rbxassetid://109492223873840", glow = c3(240, 245, 255) },
	{ key = "PocketWatch", name = "감독관의 회중시계", set = "Stage02", grade = "전설", color = "rbxassetid://110488569711919", glow = c3(255, 210, 110) },
	{ key = "Limestone", name = "석회석", set = "Stage03", grade = "일반", color = "rbxassetid://104917930480040", glow = c3(240, 230, 200) },
	{ key = "Calcite", name = "방해석", set = "Stage03", grade = "일반", color = "rbxassetid://77236192916109", glow = c3(255, 200, 130) },
	{ key = "Azurite", name = "남동석", set = "Stage03", grade = "고급", color = "rbxassetid://131138258257320", glow = c3(70, 110, 255) },
	{ key = "Malachite", name = "공작석", set = "Stage03", grade = "희귀", color = "rbxassetid://126725318348771", glow = c3(80, 220, 140) },
	{ key = "WaterPearl", name = "물빛 진주", set = "Stage03", grade = "에픽", color = "rbxassetid://118724425714039", emissive = "rbxassetid://84033556526061", tint = c3(170, 235, 255), strength = 2, glow = c3(140, 220, 255) },
	{ key = "WetMap", name = "젖은 광산 지도", set = "Stage03", grade = "전설", color = "rbxassetid://97188951383413", glow = c3(255, 220, 150) },
}
local RANK = { ["일반"] = 1, ["고급"] = 2, ["희귀"] = 3, ["에픽"] = 4, ["전설"] = 5 }
local PREVIEW_ORIGIN = CFrame.new(1000, 600, 20) -- 별이 떨어진 곳 진열대 앞쪽

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

-- 등급별 연출
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

local imported = assert(workspace:FindFirstChild("EarlyOresTurn"), "Workspace에 EarlyOresTurn 모델이 없음 (FBX 가져오기 먼저)")
local rec = CHS:TryBeginRecording("ImportEarlyOres")

local root = SS:FindFirstChild("OreModels") or Instance.new("Folder")
root.Name = "OreModels"; root.Parent = SS
local preview = workspace:FindFirstChild("EarlyOrePreview")
if preview then preview:Destroy() end
preview = Instance.new("Model"); preview.Name = "EarlyOrePreview"

local done = {}
for i, o in ipairs(ORES) do
	local mp
	for _, d in imported:GetDescendants() do
		if d:IsA("MeshPart") and d.Name:match("TT_" .. o.key .. "$") then mp = d end
	end
	if mp then
		for _, c in mp:GetChildren() do if c:IsA("SurfaceAppearance") then c:Destroy() end end
		local sa = Instance.new("SurfaceAppearance")
		sa.ColorMapContent = Content.fromUri(o.color)
		if o.emissive and o.emissive ~= "" then
			sa.EmissiveMaskContent = Content.fromUri(o.emissive)
			sa.EmissiveStrength = o.strength
			sa.EmissiveTint = o.tint
		end
		sa.Parent = mp
		mp.Name = "Body"
		mp.TextureID = ""
		mp.Color = Color3.new(1, 1, 1)
		mp.Material = Enum.Material.SmoothPlastic
		mp.Anchored, mp.CanCollide = true, false

		local m = Instance.new("Model")
		m.Name = o.key
		m:SetAttribute("DisplayName", o.name)
		m:SetAttribute("Grade", o.grade)
		mp.Parent = m
		local cf, size = m:GetBoundingBox()
		local body = Instance.new("Part")
		body.Name = "Hitbox"
		body.Size = size * 0.9
		body.CFrame = cf
		body.Transparency = 1
		body.Anchored, body.CanCollide = true, true
		body.Parent = m
		m.PrimaryPart = body
		-- PrimaryPart가 있으면 WorldPivot 대신 PivotOffset이 피벗 → 바닥 가운데로
		body.PivotOffset = body.CFrame:ToObjectSpace(CFrame.new(cf.Position.X, cf.Position.Y - size.Y / 2, cf.Position.Z))
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
		table.insert(done, o.key)
	end
end
imported:Destroy()
preview.Parent = workspace
if rec then CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
print("[EarlyOres] " .. #done .. "종 → ServerStorage.OreModels.Stage01~03")
