--[[
	"별이 떨어진 곳" 광석 6종 메시를 광석 모델 틀로 정리하는 스크립트 (Studio 명령창에서 실행)

	순서
	1) 블렌더에서 tools/blender/build_starfall_ores.py 실행 → ~/Downloads/CollapseMine/StarfallOres.fbx
	2) Studio 가져오기(Ctrl+M)로 가져옴. Workspace에 StarfallOres 모델이 생김
	3) 이 스크립트 실행 → ServerStorage.OreModels.Starfall.<광석> 모델 6개
	   (SHOW_PREVIEW = true면 허브 광장 앞에 견본을 한 줄로 세워 보여 줌)

	MeshPart 이름 규칙: SF_<광석>_<재질>. 빛·반짝임은 블렌더에서 안 넘어오니 여기서 Neon·PointLight·ParticleEmitter로 입힌다.
	광석 모델을 실제 광산에 뿌리고 캐게 하는 건 광산 생성기·채굴 코드 쪽 일 (아직 Part 광석만 지원).
]]

local CHS = game:GetService("ChangeHistoryService")
local SS = game:GetService("ServerStorage")

local SHOW_PREVIEW = true
local PREVIEW_ORIGIN = CFrame.new(-25, 2, 66) -- 허브 광장 앞쪽, 오른쪽(+X)으로 한 줄

-- 광석 순서·표시 이름 (가치는 docs/decisions.md D-010 임시값)
local ORES = {
	{ key = "Meteor", name = "운석 파편" },
	{ key = "Stardust", name = "별가루 원석" },
	{ key = "Nebula", name = "성운석" },
	{ key = "Comet", name = "혜성 핵" },
	{ key = "Crystal", name = "별빛 결정" },
	{ key = "Star", name = "떨어진 별" },
}

-- 재질 → { 색, Roblox 재질, 투명도 }
local LOOK = {
	MeteorRock = { Color3.fromRGB(52, 40, 34), Enum.Material.Basalt, 0 },
	MeteorLava = { Color3.fromRGB(255, 110, 30), Enum.Material.Neon, 0 },
	StardustRock = { Color3.fromRGB(26, 32, 70), Enum.Material.Slate, 0 },
	StardustSpeck = { Color3.fromRGB(255, 245, 210), Enum.Material.Neon, 0 },
	NebulaBase = { Color3.fromRGB(80, 34, 120), Enum.Material.Glass, 0 },
	NebulaPink = { Color3.fromRGB(250, 110, 210), Enum.Material.Neon, 0 },
	NebulaBlue = { Color3.fromRGB(90, 130, 255), Enum.Material.Neon, 0 },
	CometIce = { Color3.fromRGB(190, 230, 255), Enum.Material.Ice, 0 },
	CometGlow = { Color3.fromRGB(120, 210, 255), Enum.Material.Neon, 0.35 },
	CrystalShard = { Color3.fromRGB(255, 240, 150), Enum.Material.Neon, 0 },
	CrystalBase = { Color3.fromRGB(56, 52, 66), Enum.Material.Slate, 0 },
	StarGold = { Color3.fromRGB(255, 200, 50), Enum.Material.Foil, 0 },
	StarCore = { Color3.fromRGB(255, 245, 170), Enum.Material.Neon, 0 },
	StarRock = { Color3.fromRGB(50, 44, 40), Enum.Material.Basalt, 0 },
}

-- 광석별 빛과 반짝임
local GLOW = {
	Meteor = { light = Color3.fromRGB(255, 120, 40), range = 10, sparkle = nil },
	Stardust = { light = Color3.fromRGB(150, 170, 255), range = 8, sparkle = Color3.fromRGB(255, 245, 210) },
	Nebula = { light = Color3.fromRGB(220, 110, 255), range = 10, sparkle = Color3.fromRGB(255, 180, 240) },
	Comet = { light = Color3.fromRGB(120, 210, 255), range = 12, sparkle = Color3.fromRGB(200, 240, 255) },
	Crystal = { light = Color3.fromRGB(255, 235, 140), range = 14, sparkle = Color3.fromRGB(255, 250, 200) },
	Star = { light = Color3.fromRGB(255, 210, 80), range = 16, sparkle = Color3.fromRGB(255, 230, 120) },
}

local function sparkles(parent, color)
	local pe = Instance.new("ParticleEmitter")
	pe.Name = "Sparkle"
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Color = ColorSequence.new(color)
	pe.LightEmission = 1
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
	pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	pe.Lifetime = NumberRange.new(0.8, 1.6)
	pe.Rate = 6
	pe.Speed = NumberRange.new(0.3, 0.8)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Parent = parent
end

local imported = assert(workspace:FindFirstChild("StarfallOres"), "Workspace에 StarfallOres 모델이 없음")
local rec = CHS:TryBeginRecording("ImportStarfallOres")

local root = SS:FindFirstChild("OreModels") or Instance.new("Folder")
root.Name = "OreModels"
root.Parent = SS
local old = root:FindFirstChild("Starfall")
if old then old:Destroy() end
local folder = Instance.new("Folder")
folder.Name = "Starfall"
folder.Parent = root

local byOre = {}
for _, mp in imported:GetDescendants() do
	if mp:IsA("MeshPart") then
		local ore, mat = mp.Name:match("^SF_(%a+)_(%a+)$")
		if ore and LOOK[mat] then
			local l = LOOK[mat]
			mp.Color, mp.Material, mp.Transparency = l[1], l[2], l[3]
			mp.Anchored, mp.CanCollide = true, false
			mp.Name = mat
			byOre[ore] = byOre[ore] or {}
			table.insert(byOre[ore], mp)
		end
	end
end

local preview = workspace:FindFirstChild("StarfallOrePreview")
if preview then preview:Destroy() end
if SHOW_PREVIEW then
	preview = Instance.new("Model")
	preview.Name = "StarfallOrePreview"
end

for i, info in ipairs(ORES) do
	local parts = byOre[info.key]
	if parts then
		local m = Instance.new("Model")
		m.Name = info.key
		m:SetAttribute("DisplayName", info.name)
		for _, p in parts do p.Parent = m end
		-- 바닥 가운데를 피벗으로: 캐서 놓을 때 땅에 딱 붙게
		local cf, size = m:GetBoundingBox()
		local pivot = CFrame.new(cf.Position.X, cf.Position.Y - size.Y / 2, cf.Position.Z)
		local body = Instance.new("Part")
		body.Name = "Hitbox" -- 채굴 판정·클릭용 투명 몸통 (메시 사이 틈 때문에)
		body.Size = size * 0.9
		body.CFrame = cf
		body.Transparency = 1
		body.Anchored, body.CanCollide = true, true
		body.Parent = m
		m.PrimaryPart = body
		m.WorldPivot = pivot
		local glow = GLOW[info.key]
		local l = Instance.new("PointLight")
		l.Color, l.Range, l.Brightness = glow.light, glow.range, 1.6
		l.Parent = body
		if glow.sparkle then sparkles(body, glow.sparkle) end
		m:PivotTo(CFrame.new())
		m.Parent = folder
		if preview then
			local c = m:Clone()
			c:PivotTo(PREVIEW_ORIGIN * CFrame.new((i - 1) * 6, 0, 0))
			c.Parent = preview
		end
	end
end
imported:Destroy()
if preview then preview.Parent = workspace end
if rec then CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
print(("[StarfallOres] %d종 → %s"):format(#folder:GetChildren(), folder:GetFullName()))
