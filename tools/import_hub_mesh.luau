--[[
	블렌더에서 만든 허브 건물 메시를 기존 건물 자리에 끼워 넣는 스크립트 (Studio 명령창에서 실행)

	순서
	1) 블렌더에서 tools/blender/build_<건물>.py 실행 → ~/Downloads/CollapseMine/<건물>.fbx
	2) Studio 파일 → 가져오기(Ctrl+M)로 FBX를 가져옴 (크기 단위: 스터드). Workspace에 <건물> 모델이 생김
	3) 이 스크립트 실행. Workspace에 가져온 건물이 있는 것만 교체한다

	하는 일
	- 가져온 MeshPart를 건물 자리(바닥 중앙)에 놓고, 이름(접두사_재질)을 보고 Roblox 재질·색·충돌을 입힌다
	- 기존 Hub.<건물>에서 기능 부품(keep)만 새 모델로 옮기고, 나머지 옛 외형은
	  ServerStorage.OldHubBuildingsBackup.<건물>_Parts 로 백업한다
	- 건물별 마무리(after): 불·연기·조명·간판을 새 메시에 맞춘다
	- MeshPart 충돌 정밀도는 스크립트로 못 바꾼다. 문제가 있으면 가져오기 창에서 바꾸거나 투명 충돌 파트를 둔다

	좌표: 블렌더 (x, y, z) → Roblox 건물 로컬 (-x, z, y). 앞면은 -Z.
]]

local CHS = game:GetService("ChangeHistoryService")
local SS = game:GetService("ServerStorage")

-- 재질 이름 → { 색, Roblox 재질, 충돌 }
local LOOK = {
	Stone = { Color3.fromRGB(128, 124, 118), Enum.Material.Slate, true },
	StoneDark = { Color3.fromRGB(92, 88, 84), Enum.Material.Slate, true },
	StoneLight = { Color3.fromRGB(176, 170, 160), Enum.Material.Slate, true },
	Wood = { Color3.fromRGB(135, 95, 60), Enum.Material.Wood, true },
	WoodDark = { Color3.fromRGB(88, 60, 40), Enum.Material.Wood, true },
	Roof = { Color3.fromRGB(78, 66, 60), Enum.Material.Slate, false },
	RoofRed = { Color3.fromRGB(150, 62, 48), Enum.Material.Slate, false },
	Brick = { Color3.fromRGB(150, 82, 64), Enum.Material.Concrete, true },
	ClothRed = { Color3.fromRGB(190, 55, 50), Enum.Material.Fabric, false },
	ClothCream = { Color3.fromRGB(236, 226, 200), Enum.Material.Fabric, false },
	ClothBlue = { Color3.fromRGB(55, 80, 150), Enum.Material.Fabric, false },
	ClothGreen = { Color3.fromRGB(55, 115, 65), Enum.Material.Fabric, false },
	ClothPurple = { Color3.fromRGB(105, 60, 140), Enum.Material.Fabric, false },
	Iron = { Color3.fromRGB(62, 62, 68), Enum.Material.Metal, false },
	Copper = { Color3.fromRGB(196, 115, 62), Enum.Material.Metal, false },
	Steel = { Color3.fromRGB(170, 175, 185), Enum.Material.Metal, false },
	Gold = { Color3.fromRGB(240, 190, 60), Enum.Material.Metal, false },
	Coal = { Color3.fromRGB(34, 34, 38), Enum.Material.Slate, false },
	-- 수정은 Neon으로 스스로 빛나게 (밤·동굴 분위기 포인트)
	Gem = { Color3.fromRGB(90, 215, 240), Enum.Material.Neon, false },
	Amethyst = { Color3.fromRGB(180, 100, 240), Enum.Material.Neon, false },
	Glass = { Color3.fromRGB(255, 200, 120), Enum.Material.Neon, false },
	Ember = { Color3.fromRGB(255, 120, 40), Enum.Material.Neon, false },
	Water = { Color3.fromRGB(60, 110, 150), Enum.Material.Glass, false },
}

local function light(parent, color, range, brightness)
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness = color, range, brightness
	l.Parent = parent
	return l
end

-- 보이지 않는 조명 파트 (메시 안에 불빛만 두고 싶을 때)
local function lightAnchor(model, name, cf, color, range, brightness)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = Vector3.new(0.4, 0.4, 0.4)
	p.CFrame = cf
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Transparency = 1
	p.Parent = model
	light(p, color, range, brightness)
	return p
end

local BUILDINGS = {
	Workshop = {
		prefix = "WS",
		origin = CFrame.new(0, 1, 116),
		keep = { Counter = true, CounterTop = true, Blueprint = true, Sign = true, SignFrame = true,
			Brazier = true, BrazierArm = true, BrazierEmber = true, SmokeSource = true, ForgeCoals = true },
		after = function(model, mesh, origin)
			local ember, coals = mesh:FindFirstChild("WS_Ember"), model:FindFirstChild("ForgeCoals")
			if ember and coals then
				coals.CFrame = ember.CFrame + Vector3.new(0, 0.3, 0)
				coals.Transparency = 1
			end
			local brick, smoke = mesh:FindFirstChild("WS_Brick"), model:FindFirstChild("SmokeSource")
			if brick and smoke then
				smoke.Position = Vector3.new(brick.Position.X, brick.Position.Y + brick.Size.Y / 2 + 1.5, brick.Position.Z)
			end
			-- 간판은 처마와 겹치지 않게 앞 보 아래로
			for _, n in ipairs({ "Sign", "SignFrame" }) do
				local p = model:FindFirstChild(n)
				if p then p.Position = (origin * CFrame.new(0, 12.3, -9.6 + (n == "SignFrame" and 0.35 or 0))).Position end
			end
			model.PrimaryPart = model:FindFirstChild("Counter")
		end,
	},
	Shop = {
		prefix = "SH",
		origin = CFrame.new(-58, 1, 90) * CFrame.Angles(0, math.rad(-90), 0),
		keep = { Counter = true, CounterTop = true, Sign = true, SignFrame = true, Lantern = true },
		after = function(model, mesh, origin)
			-- 등불: 메시 등불 유리(Neon) 자리로 옮기고 원래 네모 불빛은 숨김
			local i = 0
			for _, p in model:GetChildren() do
				if p.Name == "Lantern" then
					i += 1
					p.CFrame = origin * CFrame.new(i == 1 and -9.8 or 9.8, 10, -7.5)
					p.Transparency = 1
				end
			end
			-- 간판: 차양이 앞을 가려서 앞쪽 지붕 위에 기둥 두 개로 세워 둠 (눕혀 두면 허브에서 잘 안 보임)
			local SIGN_Y = 19.2 -- 간판 가운데 높이 (지붕 경사면 16.4 위로 띄움)
			for _, n in ipairs({ "Sign", "SignFrame" }) do
				local p = model:FindFirstChild(n)
				if p then
					p.CFrame = origin * CFrame.new(0, SIGN_Y, -5.4 + (n == "SignFrame" and 0.25 or 0))
				end
			end
			for _, old in model:GetChildren() do
				if old.Name == "SignPost" then old:Destroy() end
			end
			for _, sx in ipairs({ -4.8, 4.8 }) do
				local post = Instance.new("Part")
				post.Name = "SignPost"
				post.Size = Vector3.new(0.5, SIGN_Y - 15.6, 0.5)
				post.CFrame = origin * CFrame.new(sx, (SIGN_Y + 15.6) / 2 - 0.9, -5.0)
				post.Anchored = true
				post.Color, post.Material = Color3.fromRGB(88, 60, 40), Enum.Material.Wood
				post.Parent = model
			end
			-- 수정 진열 상자·지붕 금화에 은은한 빛
			lightAnchor(model, "GemLight", origin * CFrame.new(8.8, 3, -8.6), Color3.fromRGB(90, 215, 240), 10, 1.2)
			lightAnchor(model, "AmethystLight", origin * CFrame.new(-8.8, 3, -8.6), Color3.fromRGB(180, 100, 240), 10, 1.2)
			lightAnchor(model, "CoinLight", origin * CFrame.new(0, 21.5, -3), Color3.fromRGB(255, 205, 90), 16, 1.0)
			model.PrimaryPart = model:FindFirstChild("Counter")
		end,
	},
	Leaderboard = {
		prefix = "LB",
		origin = CFrame.new(58, 1, 90) * CFrame.Angles(0, math.rad(90), 0),
		keep = { Board_BestHaul = true, Board_BestOre = true, Board_TotalEarned = true, Sign = true, SignFrame = true, TorchEmber = true },
		after = function(model, mesh, origin)
			for _, p in model:GetChildren() do
				if p.Name == "TorchEmber" then p.Transparency = 1 end -- 메시 숯이 대신 보이고 불·빛만 남김
			end
			lightAnchor(model, "TrophyLight", origin * CFrame.new(0, 27, 3.1), Color3.fromRGB(255, 205, 90), 22, 1.6)
			lightAnchor(model, "GemLight", origin * CFrame.new(11.5, 2.5, -4.3), Color3.fromRGB(90, 215, 240), 12, 1.4)
			lightAnchor(model, "AmethystLight", origin * CFrame.new(-11.5, 2.5, -4.3), Color3.fromRGB(180, 100, 240), 12, 1.4)
			model.PrimaryPart = model:FindFirstChild("Board_BestHaul")
		end,
	},
}

-- 창고 (새 건물, 옛 외형 없음): 광장 북서쪽 빈 자리에서 광장 가운데를 본다. 맡기는 기능은 B (이슈 #59) — 여기선 Counter 자리만
BUILDINGS.Storage = {
	prefix = "Storage",
	origin = CFrame.lookAt(Vector3.new(-50, 1, 128), Vector3.new(-14, 1, 98)),
	keep = {},
	after = function(model, mesh, origin)
		-- 맡기는 창구 (블렌더 (5.5, -7.6, 2.3) → Roblox 로컬 (-5.5, 2.3, -7.6))
		local counter = Instance.new("Part")
		counter.Name = "Counter"
		counter.Size = Vector3.new(5, 2.6, 2)
		counter.CFrame = origin * CFrame.new(-5.5, 2.3, -7.6)
		counter.Anchored, counter.CanCollide = true, true
		counter.Transparency = 1
		counter.Parent = model
		-- 간판: 문 위 나무판에 글자
		local sign = Instance.new("Part")
		sign.Name = "Sign"
		sign.Size = Vector3.new(8, 2, 0.4)
		sign.CFrame = origin * CFrame.new(3, 9.2, -7.4)
		sign.Anchored, sign.CanCollide = true, false
		sign.Color, sign.Material = Color3.fromRGB(88, 60, 40), Enum.Material.Wood
		sign.Parent = model
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.Parent = sign
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = "📦 창고"
		label.TextScaled = true
		label.Font = Enum.Font.GothamBlack
		label.TextColor3 = Color3.fromRGB(255, 226, 160)
		label.Parent = gui
		-- 처마 아래 등불 두 개 (블렌더 x ±8.7)
		for _, x in { -8.7, 8.7 } do
			lightAnchor(model, "LanternLight", origin * CFrame.new(x, 8, -8.5), Color3.fromRGB(255, 190, 110), 14, 1.2)
		end
		model.PrimaryPart = counter
	end,
}

local hub = workspace.CollapseMine.Hub
local bk = SS:FindFirstChild("OldHubBuildingsBackup") or Instance.new("Folder")
bk.Name = "OldHubBuildingsBackup"
bk.Parent = SS

local rec = CHS:TryBeginRecording("ImportHubMesh")
for name, cfg in pairs(BUILDINGS) do
	local imported = workspace:FindFirstChild(name)
	if imported and imported:IsA("Model") then
		imported:PivotTo(cfg.origin)
		local model = Instance.new("Model")
		model.Name = name
		local meshFolder = Instance.new("Folder")
		meshFolder.Name = "Mesh"
		meshFolder.Parent = model
		for _, mp in imported:GetDescendants() do
			if mp:IsA("MeshPart") then
				local key = mp.Name:gsub("^" .. cfg.prefix .. "_", "")
				local l = LOOK[key]
				if l then
					mp.Color, mp.Material, mp.CanCollide = l[1], l[2], l[3]
				else
					mp.CanCollide = false
				end
				if key == "Water" then mp.Transparency = 0.25 end
				mp.Anchored = true
				mp.Parent = meshFolder
			end
		end
		imported:Destroy()

		local old = hub:FindFirstChild(name)
		if old then
			for _, p in old:GetChildren() do
				if cfg.keep[p.Name] then p.Parent = model end
			end
			local prev = bk:FindFirstChild(name .. "_Parts")
			if prev then prev:Destroy() end
			old.Name = name .. "_Parts"
			old.Parent = bk
		end
		cfg.after(model, meshFolder, cfg.origin)
		model.Parent = hub
		print(("[ImportHubMesh] %s 교체 완료 (MeshPart %d개)"):format(name, #meshFolder:GetChildren()))
	end
end
if rec then CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
