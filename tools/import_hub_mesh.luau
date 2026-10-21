--[[
	블렌더에서 만든 허브 건물 메시를 기존 건물 자리에 끼워 넣는 스크립트 (Studio 명령창에서 실행)

	순서
	1) 블렌더에서 tools/blender/build_<건물>.py 실행 → ~/Downloads/CollapseMine/<건물>.fbx
	2) Studio 파일 → 가져오기(Ctrl+M)로 FBX를 가져옴 (크기 단위: 스터드). Workspace에 <건물> 모델이 생김
	3) 아래 BUILDING, PREFIX, ORIGIN을 맞추고 이 스크립트 실행

	하는 일
	- 가져온 MeshPart를 ORIGIN(바닥 중앙)에 놓고, 이름(접두사_재질)을 보고 Roblox 재질·색·충돌을 입힌다
	- 기존 Hub.<건물>에서 기능 부품(KEEP)만 새 모델로 옮기고, 나머지 옛 외형은
	  ServerStorage.OldHubBuildingsBackup.<건물>_Parts 로 백업한다
	- MeshPart 충돌은 스크립트로 정밀도를 못 바꾼다. 문제가 있으면 가져오기 창에서 바꾸거나 투명 충돌 파트를 둔다
]]

local CHS = game:GetService("ChangeHistoryService")
local SS = game:GetService("ServerStorage")

local BUILDING = "Workshop"
local PREFIX = "WS"
local ORIGIN = CFrame.new(0, 1, 96) -- tools/build_hub_buildings.luau 의 건물 중심, 광장 윗면 y=1

-- 재질 이름 → { 색, Roblox 재질, 충돌 }
local LOOK = {
	Stone = { Color3.fromRGB(128, 124, 118), Enum.Material.Slate, true },
	StoneDark = { Color3.fromRGB(92, 88, 84), Enum.Material.Slate, true },
	Wood = { Color3.fromRGB(135, 95, 60), Enum.Material.Wood, true },
	WoodDark = { Color3.fromRGB(88, 60, 40), Enum.Material.Wood, true },
	Roof = { Color3.fromRGB(78, 66, 60), Enum.Material.Slate, false },
	Brick = { Color3.fromRGB(150, 82, 64), Enum.Material.Concrete, true },
	Iron = { Color3.fromRGB(62, 62, 68), Enum.Material.Metal, false },
	Copper = { Color3.fromRGB(196, 115, 62), Enum.Material.Metal, false },
	Steel = { Color3.fromRGB(170, 175, 185), Enum.Material.Metal, false },
	Gold = { Color3.fromRGB(240, 190, 60), Enum.Material.Metal, false },
	Gem = { Color3.fromRGB(90, 200, 220), Enum.Material.Glass, false },
	Ember = { Color3.fromRGB(255, 120, 40), Enum.Material.Neon, false },
	Water = { Color3.fromRGB(60, 110, 150), Enum.Material.Glass, false },
}

-- 옛 모델에서 살릴 기능 부품 (상호작용·간판·불·연기)
local KEEP = {
	Counter = true, CounterTop = true, Blueprint = true, Sign = true, SignFrame = true,
	Brazier = true, BrazierArm = true, BrazierEmber = true, SmokeSource = true, ForgeCoals = true,
}

local hub = workspace.CollapseMine.Hub
local imported = assert(workspace:FindFirstChild(BUILDING), "Workspace에 가져온 " .. BUILDING .. " 모델이 없음")
local old = hub:FindFirstChild(BUILDING)

local rec = CHS:TryBeginRecording("ImportHubMesh " .. BUILDING)
imported:PivotTo(ORIGIN)

local model = Instance.new("Model")
model.Name = BUILDING
local meshFolder = Instance.new("Folder")
meshFolder.Name = "Mesh"
meshFolder.Parent = model
for _, mp in imported:GetDescendants() do
	if mp:IsA("MeshPart") then
		local key = mp.Name:gsub("^" .. PREFIX .. "_", "")
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

if old then
	for _, p in old:GetChildren() do
		if KEEP[p.Name] then p.Parent = model end
	end
	local bk = SS:FindFirstChild("OldHubBuildingsBackup") or Instance.new("Folder")
	bk.Name = "OldHubBuildingsBackup"
	bk.Parent = SS
	local prev = bk:FindFirstChild(BUILDING .. "_Parts")
	if prev then prev:Destroy() end
	old.Name = BUILDING .. "_Parts"
	old.Parent = bk
end

-- 제작소: 불·연기를 새 화덕·굴뚝 위치에 맞추고, 간판은 처마와 겹치지 않게 앞 보 아래로
if BUILDING == "Workshop" then
	local ember = meshFolder:FindFirstChild(PREFIX .. "_Ember")
	local coals = model:FindFirstChild("ForgeCoals")
	if ember and coals then
		coals.CFrame = ember.CFrame + Vector3.new(0, 0.3, 0)
		coals.Transparency = 1
	end
	local brick = meshFolder:FindFirstChild(PREFIX .. "_Brick")
	local smoke = model:FindFirstChild("SmokeSource")
	if brick and smoke then
		smoke.Position = Vector3.new(brick.Position.X, brick.Position.Y + brick.Size.Y / 2 + 1.5, brick.Position.Z)
	end
	for _, n in ipairs({ "Sign", "SignFrame" }) do
		local p = model:FindFirstChild(n)
		if p then
			p.Position = (ORIGIN * CFrame.new(0, 12.3, -9.6 + (n == "SignFrame" and 0.35 or 0))).Position
		end
	end
end

model.PrimaryPart = model:FindFirstChild("Counter")
model.Parent = hub
if rec then CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
print(("[ImportHubMesh] %s 교체 완료 (MeshPart %d개)"):format(BUILDING, #meshFolder:GetChildren()))
