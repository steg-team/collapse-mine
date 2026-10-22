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
