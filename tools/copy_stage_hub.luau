--[[
	스테이지 허브 복사 — 기본 허브(Workspace.CollapseMine: 절벽 분지 + 판매소·제작소·랭킹판 + 입구 산·동굴)를
	통째로 복사해서 다른 광산 스테이지의 허브를 만든다 (D-018). Studio 명령창에서 실행.

	- 지형(절벽·산·입구 굴)은 Terrain:CopyRegion → PasteRegion으로, 오브젝트는 폴더를 복제해 같은 만큼 옮긴다.
	- 복사본 이름은 CollapseMine_<광산 id>, 속성 MineId. Mines 설정의 hub 칸과 이름을 맞춘다.
	- 입구 포탈은 Portal_<id>로 이름을 바꾸고, 이동 판정의 MineId·간판 글자(광산 이름, 곡괭이 단계)를 바꾼다.
	- 복사본의 SpawnLocation은 끈다 (새로 들어온 사람은 기본 허브에서만 생기게). 출구·텔레포트가 MineSpawn 위치로 옮겨 준다.
	- 같은 id로 다시 실행하면 예전 복사본 폴더는 ServerStorage로 옮기고(이름 _old) 지형은 덮어쓴다.

	STAGES의 dx = 기본 허브에서 옆으로 옮길 거리. 광산 중심 X와 맞춰서 허브가 자기 광산 바로 위쪽(북쪽)에 오게 했다.
]]

local STAGES = {
	{ id = "iron", name = "철광 갱도", tier = 2, dx = -900 },
	{ id = "groundwater", name = "지하수 동굴", tier = 3, dx = 900 },
}

local CHS = game:GetService("ChangeHistoryService")
local SS = game:GetService("ServerStorage")
local T = workspace.Terrain

-- 기본 허브 지형 범위 (칸 좌표, 4스터드): x -160..160, y -40..232, z -152..188
-- 절벽 분지(중심 (0,0,90))와 입구 산(입구 (0,0,38) 뒤로 175, 봉우리 220)이 다 들어간다
local SRC_MIN = Vector3int16.new(-40, -10, -38)
local SRC_MAX = Vector3int16.new(40, 58, 47)

local rec = CHS:TryBeginRecording("CopyStageHubs")
local region = T:CopyRegion(Region3int16.new(SRC_MIN, SRC_MAX))
workspace.CollapseMine:SetAttribute("MineId", "basic")

for _, d in STAGES do
	assert(d.dx % 4 == 0, "dx는 4의 배수 (지형 칸)")
	T:PasteRegion(region, Vector3int16.new(SRC_MIN.X + d.dx / 4, SRC_MIN.Y, SRC_MIN.Z), true)
	task.wait()

	local name = "CollapseMine_" .. d.id
	local old = workspace:FindFirstChild(name)
	if old then
		old.Name = name .. "_old"
		old.Parent = SS
	end

	local hub = workspace.CollapseMine:Clone()
	hub.Name = name
	hub:SetAttribute("MineId", d.id)
	local off = Vector3.new(d.dx, 0, 0)
	for _, c in hub:GetDescendants() do
		if c:IsA("BasePart") then c.CFrame += off end
	end
	for _, c in hub:GetDescendants() do
		if c:IsA("SpawnLocation") then
			c.Enabled = false
			c.Neutral = false
		end
	end
	local p = hub.Hub.MinePortals:FindFirstChild("Portal_basic")
	if p then
		p.Name = "Portal_" .. d.id
		for _, c in p:GetDescendants() do
			if c:GetAttribute("MineId") then c:SetAttribute("MineId", d.id) end
			if c:IsA("TextLabel") then
				if c.Text == "기본 광산" then c.Text = d.name end
				if string.find(c.Text, "곡괭이") then c.Text = ("곡괭이 %d단계 이상"):format(d.tier) end
			end
		end
	end
	hub.Parent = workspace
	print(("[StageHub] %s 완성 (기본 허브에서 x %+d)"):format(name, d.dx))
	task.wait()
end

if rec then CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
