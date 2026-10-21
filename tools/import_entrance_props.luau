--[[
	블렌더 입구 장식(EntranceProps.fbx)을 기본 광산 입구에 끼우는 스크립트 (Studio 명령창에서 실행)

	순서
	1) 블렌더에서 tools/blender/build_entrance_props.py 실행 → ~/Downloads/CollapseMine/EntranceProps.fbx
	2) Studio 파일 → 가져오기(Ctrl+M)로 가져옴. Workspace에 EntranceProps 모델이 생김
	3) 이 스크립트 실행

	하는 일
	- 메시를 입구 원점(MOUTH)에 놓고 재질을 입혀 Hub.MinePortals.Portal_basic.Mesh 에 넣는다
	- 기능 부품은 남긴다: Sign(글자판), Field(이동 판정), Darkness(어둠), 화로 불 Embers, 벽 횃불 불(Ember)
	  · 횃불 불은 새 횃불 끝(TORCH_TIP)으로 옮기고 원래 네모는 숨긴다 (불·빛만 남김)
	- 나머지 옛 파트 장식은 ServerStorage.OldPortalPartsBackup 으로 옮긴다
]]

local CHS = game:GetService("ChangeHistoryService")
local SS = game:GetService("ServerStorage")

local MINE_ID = "basic"
local MOUTH = CFrame.new(0, 0, 38)
local TORCH_TIP = Vector3.new(2.05, 2.75, 0) -- build_entrance_props.py 와 같은 값 (횃불 원점 기준 밖으로, 위로)

local LOOK = {
	Stone = { Color3.fromRGB(128, 124, 118), Enum.Material.Slate, true },
	StoneDark = { Color3.fromRGB(92, 88, 84), Enum.Material.Slate, true },
	StoneLight = { Color3.fromRGB(176, 170, 160), Enum.Material.Slate, true },
	Wood = { Color3.fromRGB(135, 95, 60), Enum.Material.Wood, true },
	WoodDark = { Color3.fromRGB(88, 60, 40), Enum.Material.Wood, true },
	Iron = { Color3.fromRGB(62, 62, 68), Enum.Material.Metal, false },
	Steel = { Color3.fromRGB(170, 175, 185), Enum.Material.Metal, false },
	Gold = { Color3.fromRGB(240, 190, 60), Enum.Material.Metal, false },
	Copper = { Color3.fromRGB(196, 115, 62), Enum.Material.Metal, false },
	Coal = { Color3.fromRGB(34, 34, 38), Enum.Material.Slate, false },
	ClothCream = { Color3.fromRGB(236, 226, 200), Enum.Material.Fabric, false },
	Gem = { Color3.fromRGB(90, 215, 240), Enum.Material.Neon, false },
	Glass = { Color3.fromRGB(255, 200, 120), Enum.Material.Neon, false },
	Ember = { Color3.fromRGB(255, 120, 40), Enum.Material.Neon, false },
}
local KEEP = { Sign = true, Field = true, Darkness = true, Embers = true }

local imported = assert(workspace:FindFirstChild("EntranceProps"), "Workspace에 EntranceProps 모델이 없음")
local portal = workspace.CollapseMine.Hub.MinePortals["Portal_" .. MINE_ID]

local rec = CHS:TryBeginRecording("ImportEntranceProps")
imported:PivotTo(MOUTH)

local old = portal:FindFirstChild("Mesh")
if old then old:Destroy() end
local meshFolder = Instance.new("Folder")
meshFolder.Name = "Mesh"
for _, mp in imported:GetDescendants() do
	if mp:IsA("MeshPart") then
		local l = LOOK[mp.Name:gsub("^EN_", "")]
		if l then
			mp.Color, mp.Material, mp.CanCollide = l[1], l[2], l[3]
		else
			mp.CanCollide = false
		end
		mp.Anchored = true
		mp.Parent = meshFolder
	end
end
imported:Destroy()

local backup = SS:FindFirstChild("OldPortalPartsBackup") or Instance.new("Folder")
backup.Name = "OldPortalPartsBackup"
backup.Parent = SS
local bin = Instance.new("Folder")
bin.Name = "Portal_" .. MINE_ID .. "_" .. os.date("%Y%m%d_%H%M")
bin.Parent = backup

local torchFires = Instance.new("Folder")
torchFires.Name = "TorchFires"
torchFires.Parent = portal
for _, c in portal:GetChildren() do
	if c == meshFolder or c == torchFires then continue end
	if c.Name == "WallTorch" then
		-- 횃불 원점 = 벽판 중심에서 0.12 벽 쪽 (tools/build_cave_entrance.luau 의 buildTorch)
		local plate, ember = c:FindFirstChild("Plate"), c:FindFirstChild("Ember")
		if plate and ember then
			local origin = plate.CFrame * CFrame.new(-0.12, 0, 0)
			ember.CFrame = origin * CFrame.new(TORCH_TIP)
			ember.Transparency = 1
			ember.Parent = torchFires
		end
		c.Parent = bin
	elseif KEEP[c.Name] then
		if c.Name == "Embers" then c.Transparency = 1 end -- 메시 숯이 보이고 불·빛만 남김
	else
		c.Parent = bin
	end
end

-- 첫 문틀에 매단 등불 빛
local lamp = Instance.new("Part")
lamp.Name = "GateLamp"
lamp.Size = Vector3.new(0.4, 0.4, 0.4)
lamp.CFrame = MOUTH * CFrame.new(0, 19.1, -20.8)
lamp.Anchored, lamp.CanCollide, lamp.CanQuery, lamp.CanTouch = true, false, false, false
lamp.Transparency = 1
local pl = Instance.new("PointLight")
pl.Color, pl.Range, pl.Brightness = Color3.fromRGB(255, 190, 110), 20, 1.4
pl.Parent = lamp
lamp.Parent = portal

meshFolder.Parent = portal
if rec then CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
print(("[ImportEntranceProps] 메시 %d개, 횃불 불 %d개, 백업 %s"):format(#meshFolder:GetChildren(), #torchFires:GetChildren(), bin:GetFullName()))
