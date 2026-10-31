--[[
	4스테이지 용암 광산 광물 6종 → 광물 틀 (ServerStorage.OreModels.Stage04.<키>). Studio 명령창에서 실행.

	만든 방법 (tools/ai_ore_models.md와 같은 흐름)
	  1) Studio MCP generate_mesh로 모양 생성 → Workspace.AIOrePreview04.<키> (아래 ORES의 asset id로 다시 꺼낼 수 있음)
	  2) generate_texture로 색 다시 칠하기 (프롬프트에 색을 강하게)
	  3) 이 스크립트: 견본을 복사해 Body(MeshPart, 충돌 끔) + 투명 Hitbox(PrimaryPart, 몸통의 90%) +
	     속성(DisplayName, Grade, Source=RobloxAI) + 등급 연출(희귀 반짝임, 에픽 조명, 전설 오라·외곽선)을 붙인다.
	     피벗은 바닥 가운데. 같은 키가 있으면 바꾼다.
	다시 칠한 텍스처는 생성 에셋에 없고 틀에만 있으므로 원본은 플레이스의 광물 틀이다.
]]

local ORES = {
	-- key, 표시 이름, 등급, 모양 에셋 id, 크기 배수(가로, 세로) — 우라늄은 너무 가늘어서 옆으로 넓힘
	{ key = "LavaStone", name = "용암석", grade = "일반", asset = 98846309308692 },
	{ key = "Sulfur", name = "유황", grade = "일반", asset = 112802065087044 },
	{ key = "Obsidian", name = "흑요석", grade = "고급", asset = 121745688438230 },
	{ key = "Uranium", name = "우라늄", grade = "희귀", asset = 122745790330329, widen = 1.9, glow = Color3.fromRGB(120, 255, 90) },
	{ key = "FireRuby", name = "화염 루비", grade = "에픽", asset = 107506822113236, glow = Color3.fromRGB(255, 70, 40) },
	{ key = "MeltedHelmet", name = "녹은 광부 헬멧", grade = "전설", asset = 120285491531323, glow = Color3.fromRGB(255, 190, 90) },
}

local CHS = game:GetService("ChangeHistoryService")
local SS = game:GetService("ServerStorage")
local src = assert(workspace:FindFirstChild("AIOrePreview04"), "견본 폴더 Workspace.AIOrePreview04가 없음")
local root = SS:FindFirstChild("OreModels") or Instance.new("Folder")
root.Name = "OreModels"
root.Parent = SS
local dest = root:FindFirstChild("Stage04") or Instance.new("Folder")
dest.Name = "Stage04"
dest.Parent = root

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local rec = CHS:TryBeginRecording("ImportLavaOres")
for _, o in ORES do
	local sample = src:FindFirstChild(o.key)
	if not sample then
		warn("견본 없음: " .. o.key)
		continue
	end
	local body: MeshPart? = nil
	for _, d in sample:GetDescendants() do
		if d:IsA("MeshPart") then body = d break end
	end
	assert(body, o.key .. ": MeshPart 없음")

	local m = Instance.new("Model")
	m.Name = o.key
	local b = body:Clone()
	b.Name = "Body"
	b.Anchored, b.CanCollide, b.CanTouch, b.CanQuery = true, false, false, false
	if o.widen then
		b.Size = Vector3.new(b.Size.X * o.widen, b.Size.Y, b.Size.Z * o.widen)
	end
	-- 몸통을 원점 위에 세운다 (피벗 = 바닥 가운데)
	b.CFrame = CFrame.new(0, b.Size.Y / 2, 0) * body.CFrame.Rotation
	b.Parent = m

	local hit = Instance.new("Part")
	hit.Name = "Hitbox"
	hit.Size = b.Size * 0.9
	hit.CFrame = CFrame.new(0, b.Size.Y / 2, 0)
	hit.Transparency = 1
	hit.Anchored, hit.CanCollide = true, true
	hit.Parent = m
	m.PrimaryPart = hit
	m.WorldPivot = CFrame.new()

	m:SetAttribute("DisplayName", o.name)
	m:SetAttribute("Grade", o.grade)
	m:SetAttribute("Source", "RobloxAI")

	-- 등급 연출 (1~3스테이지 틀과 같은 값)
	if o.grade == "희귀" or o.grade == "에픽" or o.grade == "전설" then
		local s = Instance.new("ParticleEmitter")
		s.Name = "Sparkle"
		s.Texture = SPARKLE
		s.Rate = (o.grade == "희귀") and 3 or 6
		s.Lifetime = NumberRange.new(0.6, 1.2)
		s.Speed = NumberRange.new(0.5, 1.5)
		s.SpreadAngle = Vector2.new(180, 180)
		s.Size = NumberSequence.new(0.35, 0)
		s.LightEmission = 1
		s.Color = ColorSequence.new(o.glow or Color3.new(1, 1, 1))
		s.Parent = hit
	end
	if o.glow and (o.grade == "희귀" or o.grade == "에픽" or o.grade == "전설") then
		local l = Instance.new("PointLight")
		l.Color = o.glow
		l.Brightness = (o.grade == "희귀") and 0.8 or 1.2
		l.Range = 9
		l.Parent = hit
	end
	if o.grade == "전설" then
		local a = Instance.new("ParticleEmitter")
		a.Name = "Aura"
		a.Texture = SMOKE
		a.Rate = 5
		a.Lifetime = NumberRange.new(1, 1.6)
		a.Speed = NumberRange.new(0.3, 0.8)
		a.Size = NumberSequence.new(1.6, 2.4)
		a.Transparency = NumberSequence.new(0.6, 1)
		a.LightEmission = 0.8
		a.Color = ColorSequence.new(o.glow)
		a.Parent = hit
		local h = Instance.new("Highlight")
		h.Name = "AuraOutline"
		h.FillTransparency = 1
		h.OutlineColor = o.glow
		h.Parent = m
	end

	local old = dest:FindFirstChild(o.key)
	if old then old:Destroy() end
	m.Parent = dest
	print(("[LavaOres] %s %s %s"):format(o.key, o.name, tostring(b.Size)))
end
if rec then CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
print("[LavaOres] 완료 → ServerStorage.OreModels.Stage04")
