--!strict
-- 벽 광석 관리 + 붕괴 뒤 광맥 재생 (A)
--
-- 벽에 보이는 광석(일반·고급)은 맵에 박힌 자리 그대로 쓰고, 그 자리들을 "벽 표면 자리"로 기억한다.
-- 희귀 이상(Mines 설정 digFinds.grades)은 미리 묻지 않는다: 지형을 팔 때마다 확률로 나온다 (MiningServer).
-- 예전 방식으로 맵에 미리 묻어 둔 광석(속성 Buried)이 남아 있으면 시작할 때 치운다.
--
-- 붕괴(CollapseOccurred) 뒤 oreRegrowDelay초가 지나면 캐서 비어 있는 벽 광석 자리를 다시 채운다
-- ("붕괴가 끝이 아니라 다음 광맥의 시작", game-design 광맥 재생).

local RS = game:GetService("ReplicatedStorage")

local Shared = RS:WaitForChild("Shared")
local Mines = require(Shared:WaitForChild("Config"):WaitForChild("Mines"))
local Events = require(Shared:WaitForChild("Events"))
local EventBus = require(Shared:WaitForChild("EventBus"))
local OreFactory = require(script.Parent:WaitForChild("OreFactory"))

local rng = Random.new()

local terrainOnly = RaycastParams.new()
terrainOnly.FilterType = Enum.RaycastFilterType.Include
terrainOnly.FilterDescendantsInstances = { workspace.Terrain }

-- 벽 표면 자리: cf = 표면에 바닥을 붙인 자리 (UpVector = 굴 쪽), mult = 가치 배율(끝방 2배), ore = 지금 박힌 광석
type Anchor = { cf: CFrame, mult: number, ore: Instance? }
type Field = { mine: Mines.Mine, ores: Folder, anchors: { Anchor } }
local fields: { [string]: Field } = {}

-- 캐서 비어 있는 벽 광석 자리 다시 채우기. 플레이어가 벽을 파냈으면 지금 표면을 다시 찾는다
local function refillWalls(f: Field)
	local filled = 0
	for i, a in f.anchors do
		if a.ore and a.ore.Parent then continue end
		local up = a.cf.UpVector
		local hit = workspace:Raycast(a.cf.Position + up * 3, -up * 12, terrainOnly)
		if hit then
			local cf = OreFactory.surfaceCFrame(hit)
			local o = OreFactory.pick(f.mine, cf.Position.Y, false, rng)
			a.ore = if o then OreFactory.spawn(f.mine, f.ores, o, cf, a.mult, rng, "Wall") else nil
			if a.ore then filled += 1 end
		end
		if i % 25 == 0 then task.wait() end
	end
	print(("[OreSpawner] %s: 벽 광석 %d자리 다시 채움"):format(f.mine.id, filled))
end

-- 광산 하나 준비: 지금 벽에 있는 광석 자리 기억 + 예전에 미리 묻어 둔 광석 치우기
local function setup(m: Mines.Mine)
	local root = workspace:WaitForChild("Mines", 30)
	local folder = root and root:WaitForChild(m.id, 30)
	local ores = folder and folder:WaitForChild("Ores", 30)
	if not ores or not ores:IsA("Folder") then
		warn("[OreSpawner] 광산 없음: " .. m.id)
		return
	end
	local f: Field = { mine = m, ores = ores, anchors = {} }
	local byName: { [string]: Mines.Ore } = {}
	for _, o in m.ores do byName[o.name] = o end
	for _, o in ores:GetChildren() do
		if o:GetAttribute("Buried") then
			o:Destroy()
		elseif o:IsA("Model") then
			-- 가치 배율 = 실제 가치 / 설정 가치 (끝방 광석은 2배)
			local def = byName[o:GetAttribute("Ore") or ""]
			local mult = if def and def.value > 0 then math.max(1, math.floor((o:GetAttribute("OreValue") or def.value) / def.value + 0.5)) else 1
			o:SetAttribute("Origin", "Wall")
			table.insert(f.anchors, { cf = o:GetPivot(), mult = mult, ore = o })
		end
	end
	fields[m.id] = f
end

for _, m in Mines.list do
	task.spawn(setup, m)
end

-- 붕괴 뒤 광맥 재생 (Events.luau: CollapseOccurred(mineId) — A는 광맥 재생 타이머 시작)
EventBus.On(Events.CollapseOccurred, function(mineId: string)
	local f = fields[mineId]
	if not f then return end
	task.delay(f.mine.oreRegrowDelay or 5, refillWalls, f)
end)
