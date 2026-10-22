--[[
	"별이 떨어진 곳" 광석 6종 — 그림 텍스처 버전 (Studio 명령창에서 실행)

	흐름 (docs/decisions.md D-010)
	1) 제미나이로 광석 그림 6장 (회색 배경, 하나씩) → ~/Downloads/CollapseMine/ref/starfall_<n>_<광석>.png
	2) 블렌더 tools/blender/build_starfall_from_images.py
	   - 그림 실루엣을 부풀린 로우폴리 메시 (앞에서 보면 그림 그대로, UV = 그림 좌표)
	   - 색 그림(가장자리 메움)·빛 마스크(용암·별가루·결정 등 밝은 부분만 흰색) → ~/Downloads/CollapseMine/tex/
	   - 메시 → ~/Downloads/CollapseMine/StarfallOresTex.fbx
	3) 텍스처 업로드 → 아래 TEX 표의 asset id
	4) Studio 가져오기(Ctrl+M)로 StarfallOresTex.fbx → Workspace.StarfallOresTex
	5) 이 스크립트 → MeshPart마다 SurfaceAppearance(ColorMap + 빛 마스크) 입히고
	   ServerStorage.OreModels.Starfall.<광석> 교체, 견본 Workspace.StarfallOrePreview 다시 세움

	SurfaceAppearance는 게임 중 스크립트로 못 바꾼다. 붕괴 연출로 빛을 바꿀 땐 PointLight·파티클을 쓴다.
]]

local CHS = game:GetService("ChangeHistoryService")
local SS = game:GetService("ServerStorage")

-- 업로드한 텍스처 (색, 빛 마스크)와 빛 설정
local TEX = {
	Meteor = { color = "rbxassetid://134241722558727", emissive = "rbxassetid://95048005145837", tint = Color3.fromRGB(255, 110, 40), strength = 6, name = "운석 파편", light = Color3.fromRGB(255, 120, 40) },
	Stardust = { color = "rbxassetid://125437902966120", emissive = "rbxassetid://83988083128437", tint = Color3.fromRGB(190, 210, 255), strength = 5, name = "별가루 원석", light = Color3.fromRGB(150, 170, 255), sparkle = Color3.fromRGB(255, 245, 210) },
	Nebula = { color = "rbxassetid://102566986297514", emissive = "rbxassetid://75223251550845", tint = Color3.fromRGB(255, 220, 255), strength = 4, name = "성운석", light = Color3.fromRGB(220, 110, 255), sparkle = Color3.fromRGB(255, 180, 240) },
	Comet = { color = "rbxassetid://73760121685478", emissive = "rbxassetid://81844538546795", tint = Color3.fromRGB(150, 220, 255), strength = 3, name = "혜성 핵", light = Color3.fromRGB(120, 210, 255), sparkle = Color3.fromRGB(200, 240, 255) },
	Crystal = { color = "rbxassetid://103760830304057", emissive = "rbxassetid://137175958281655", tint = Color3.fromRGB(255, 240, 180), strength = 3, name = "별빛 결정", light = Color3.fromRGB(255, 235, 140), sparkle = Color3.fromRGB(255, 250, 200) },
	Star = { color = "rbxassetid://99664460948925", emissive = "rbxassetid://98677624245263", tint = Color3.fromRGB(255, 210, 90), strength = 3, name = "떨어진 별", light = Color3.fromRGB(255, 210, 80), sparkle = Color3.fromRGB(255, 230, 120) },
}
local ORDER = { "Meteor", "Stardust", "Nebula", "Comet", "Crystal", "Star" }
local PREVIEW_ORIGIN = CFrame.new(1000, 600, 0) -- 하늘 진열대 (_OreStage)

local function sparkles(parent, color)
	local pe = Instance.new("ParticleEmitter")
	pe.Name = "Sparkle"
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Color = ColorSequence.new(color)
	pe.LightEmission = 1
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
	pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	pe.Lifetime = NumberRange.new(0.8, 1.6)
	pe.Rate = 5
	pe.Speed = NumberRange.new(0.3, 0.8)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Parent = parent
end

-- 오라 (임시값). 광석 몸통(Hitbox)에 붙는다. 입자는 게임 중 켜고 끌 수 있어서
-- 나중에 클라이언트에서 가까운 광석만 켜거나 붕괴 때 세게 하는 식으로 조절한다.
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"

local function emitter(parent, name, props)
	local pe = Instance.new("ParticleEmitter")
	pe.Name = name
	pe.LightEmission = 1
	pe.LockedToPart = false
	for k, v in props do pe[k] = v end
	pe.Parent = parent
	return pe
end

local function ns(a, b) return NumberSequence.new({ NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(1, b) }) end
local function fade(a) return NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, a), NumberSequenceKeypoint.new(1, 1) }) end

local AURA = {
	Meteor = function(body)
		emitter(body, "AuraHeat", { Texture = SMOKE, Color = ColorSequence.new(Color3.fromRGB(255, 120, 40), Color3.fromRGB(120, 30, 10)),
			Size = ns(1.2, 2.4), Transparency = fade(0.75), Lifetime = NumberRange.new(1.2, 2), Rate = 6,
			Speed = NumberRange.new(0.6, 1.2), SpreadAngle = Vector2.new(25, 25), Acceleration = Vector3.new(0, 1, 0), RotSpeed = NumberRange.new(-30, 30) })
		emitter(body, "AuraEmbers", { Texture = FIRE, Color = ColorSequence.new(Color3.fromRGB(255, 170, 60)),
			Size = ns(0.18, 0), Transparency = ns(0, 1), Lifetime = NumberRange.new(0.8, 1.4), Rate = 8,
			Speed = NumberRange.new(1.5, 3), SpreadAngle = Vector2.new(35, 35), Acceleration = Vector3.new(0, 2, 0) })
	end,
	Stardust = function(body)
		emitter(body, "AuraDust", { Texture = SPARK, Color = ColorSequence.new(Color3.fromRGB(200, 215, 255)),
			Size = ns(0.25, 0), Transparency = ns(0.1, 1), Lifetime = NumberRange.new(1.5, 2.5), Rate = 10,
			Speed = NumberRange.new(0.2, 0.5), SpreadAngle = Vector2.new(180, 180), RotSpeed = NumberRange.new(-90, 90) })
	end,
	Nebula = function(body)
		emitter(body, "AuraMist", { Texture = SMOKE, Color = ColorSequence.new(Color3.fromRGB(255, 120, 220), Color3.fromRGB(140, 90, 255)),
			Size = ns(1.5, 3), Transparency = fade(0.7), Lifetime = NumberRange.new(2, 3), Rate = 4,
			Speed = NumberRange.new(0.3, 0.6), SpreadAngle = Vector2.new(180, 180), RotSpeed = NumberRange.new(-20, 20), Acceleration = Vector3.new(0, 0.3, 0) })
	end,
	Comet = function(body, mesh)
		-- 일렁이는 빛막: 몸체를 조금 키운 복사본에 ForceField 재질
		local shell = mesh:Clone()
		shell.Name = "AuraShell"
		for _, c in shell:GetChildren() do c:Destroy() end
		shell.Material = Enum.Material.ForceField
		shell.Color = Color3.fromRGB(110, 200, 255)
		shell.Size = mesh.Size * 1.15
		shell.CFrame = mesh.CFrame
		shell.CanCollide, shell.CanQuery, shell.CanTouch = false, false, false
		shell.Parent = mesh.Parent
		emitter(body, "AuraTail", { Texture = SMOKE, Color = ColorSequence.new(Color3.fromRGB(170, 230, 255)),
			Size = ns(0.8, 0.2), Transparency = fade(0.6), Lifetime = NumberRange.new(1, 1.6), Rate = 8,
			Speed = NumberRange.new(1, 1.5), SpreadAngle = Vector2.new(10, 10), EmissionDirection = Enum.NormalId.Left })
	end,
	Crystal = function(body)
		emitter(body, "AuraGlint", { Texture = SPARK, Color = ColorSequence.new(Color3.fromRGB(255, 250, 210)),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.9), NumberSequenceKeypoint.new(1, 0) }),
			Transparency = ns(0, 0.4), Lifetime = NumberRange.new(0.4, 0.6), Rate = 2,
			Speed = NumberRange.new(0, 0), SpreadAngle = Vector2.new(180, 180), Rotation = NumberRange.new(0, 45) })
	end,
	Star = function(body, mesh)
		emitter(body, "AuraGold", { Texture = SMOKE, Color = ColorSequence.new(Color3.fromRGB(255, 220, 110), Color3.fromRGB(255, 160, 40)),
			Size = ns(1.4, 2.8), Transparency = fade(0.7), Lifetime = NumberRange.new(1.5, 2.5), Rate = 6,
			Speed = NumberRange.new(0.5, 1), SpreadAngle = Vector2.new(30, 30), Acceleration = Vector3.new(0, 0.8, 0), RotSpeed = NumberRange.new(-30, 30) })
		emitter(body, "AuraRays", { Texture = SPARK, Color = ColorSequence.new(Color3.fromRGB(255, 235, 150)),
			Size = ns(0.3, 0), Transparency = ns(0, 1), Lifetime = NumberRange.new(1, 2), Rate = 10,
			Speed = NumberRange.new(0.5, 1.5), SpreadAngle = Vector2.new(180, 180) })
		-- 가장 희귀한 광석이라 외곽선으로 멀리서도 보이게
		local hl = Instance.new("Highlight")
		hl.Name = "AuraOutline"
		hl.FillTransparency = 1
		hl.OutlineColor = Color3.fromRGB(255, 215, 90)
		hl.OutlineTransparency = 0.2
		hl.DepthMode = Enum.HighlightDepthMode.Occluded
		hl.Adornee = mesh.Parent
		hl.Parent = mesh.Parent
	end,
}

local imported = assert(workspace:FindFirstChild("StarfallOresTex"), "Workspace에 StarfallOresTex 모델이 없음 (FBX 가져오기 먼저)")
local rec = CHS:TryBeginRecording("ImportStarfallTex")

local root = SS:FindFirstChild("OreModels") or Instance.new("Folder")
root.Name = "OreModels"; root.Parent = SS
local folder = root:FindFirstChild("Starfall") or Instance.new("Folder")
folder.Name = "Starfall"; folder.Parent = root
local backup = root:FindFirstChild("Starfall_OldShapes") or Instance.new("Folder")
backup.Name = "Starfall_OldShapes"; backup.Parent = root

local preview = workspace:FindFirstChild("StarfallOrePreview")
if preview then preview:Destroy() end
preview = Instance.new("Model"); preview.Name = "StarfallOrePreview"

local done = {}
for i, key in ipairs(ORDER) do
	local mp
	for _, d in imported:GetDescendants() do
		if d:IsA("MeshPart") and d.Name:match("SFT_" .. key .. "$") then mp = d end
	end
	if mp then
		local t = TEX[key]
		for _, c in mp:GetChildren() do if c:IsA("SurfaceAppearance") then c:Destroy() end end
		local sa = Instance.new("SurfaceAppearance")
		sa.ColorMapContent = Content.fromUri(t.color)
		sa.EmissiveMaskContent = Content.fromUri(t.emissive)
		sa.EmissiveStrength = t.strength
		sa.EmissiveTint = t.tint
		sa.Parent = mp
		mp.Name = "Body"
		mp.TextureID = ""
		mp.Color = Color3.new(1, 1, 1)
		mp.Material = Enum.Material.SmoothPlastic
		mp.Anchored, mp.CanCollide = true, false

		local m = Instance.new("Model")
		m.Name = key
		m:SetAttribute("DisplayName", t.name)
		mp.Parent = m
		-- 메시 사이 틈 없이 캐기·클릭 판정을 받는 투명 몸통
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
		local l = Instance.new("PointLight")
		l.Color, l.Range, l.Brightness = t.light, 10, 1.5
		l.Parent = body
		if t.sparkle then sparkles(body, t.sparkle) end
		if AURA[key] then AURA[key](body, mp) end
		m:PivotTo(CFrame.new())

		local old = folder:FindFirstChild(key)
		if old then
			local prev = backup:FindFirstChild(key)
			if prev then prev:Destroy() end
			old.Parent = backup
		end
		m.Parent = folder
		local c = m:Clone()
		c:PivotTo(PREVIEW_ORIGIN * CFrame.new(-15 + (i - 1) * 6, 0, 0))
		c.Parent = preview
		table.insert(done, key)
	end
end
imported:Destroy()
preview.Parent = workspace
if rec then CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
print("[StarfallTex] " .. table.concat(done, ", ") .. " → " .. folder:GetFullName() .. " (예전 모양은 Starfall_OldShapes)")
