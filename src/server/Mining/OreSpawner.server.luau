--!strict
-- 광석 랜덤 배치 + 붕괴 뒤 광맥 재생 (A)
--
-- 벽에 보이는 광석(일반·고급)은 맵에 박힌 자리 그대로 쓰고, 그 자리들을 "벽 표면 자리"로 기억한다.
-- 땅 속에 묻는 광석(Mines 설정 buried.grades)은 서버가 켜질 때마다 벽 표면 자리 중 아무 데나 골라
-- 그 뒤 흙 속에 새로 묻는다. 그래서 서버마다 위치가 달라 외워서 캐러 갈 수 없다.
-- 맵 생성기(tools/generate_mine.luau)가 미리 묻어 둔 광석은 Studio 확인용이라 시작할 때 치운다.
--
-- 붕괴(CollapseOccurred)가 나면 그 광산의 묻힌 광석을 전부 새 자리로 다시 묻고,
-- 캐서 비어 있는 벽 광석 자리도 다시 채운다 ("붕괴가 끝이 아니라 다음 광맥의 시작", game-design 광맥 재생).

local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
local CS = game:GetService("CollectionService")

local Shared = RS:WaitForChild("Shared")
local Mines = require(Shared:WaitForChild("Config"):WaitForChild("Mines"))
local Events = require(Shared:WaitForChild("Events"))
local EventBus = require(Shared:WaitForChild("EventBus"))

local Terrain = workspace.Terrain
local rng = Random.new()

local terrainOnly = RaycastParams.new()
terrainOnly.FilterType = Enum.RaycastFilterType.Include
terrainOnly.FilterDescendantsInstances = { Terrain }

-- 벽 표면 자리: cf = 표면에 바닥을 붙인 자리 (UpVector = 굴 쪽), mult = 가치 배율(끝방 2배)
type Anchor = { cf: CFrame, mult: number, ore: Instance? }
type Field = { mine: Mines.Mine, ores: Folder, anchors: { Anchor } }
local fields: { [string]: Field } = {}

local function isBuriedGrade(m: Mines.Mine, o: Mines.Ore): boolean
	return m.buried ~= nil and table.find(m.buried.grades, o.grade) ~= nil
end

-- 깊이 조건을 만족하는 광물 중 무게(weight)로 하나 뽑기. wantBuried면 묻는 등급만, 아니면 그 밖만
local function pickOre(m: Mines.Mine, y: number, wantBuried: boolean): Mines.Ore?
	local d = m.top - y
	local total, pool = 0, {}
	for _, o in m.ores do
		if d >= o.minDepth and isBuriedGrade(m, o) == wantBuried then
			total += o.weight
			table.insert(pool, o)
		end
	end
	if #pool == 0 then return nil end
	local n = rng:NextNumber(0, total)
	for _, o in pool do
		n -= o.weight
		if n <= 0 then return o end
	end
	return pool[#pool]
end

local function findTemplate(path: string?): Model?
	if not path then return nil end
	local node: Instance? = SS:FindFirstChild("OreModels")
	for part in string.gmatch(path, "[^/]+") do
		node = node and node:FindFirstChild(part)
	end
	return if node and node:IsA("Model") then node else nil
end

-- 묻힌 광석이 흙에 완전히 덮였는지: 상자 꼭짓점·가운데가 모두 꽉 찬 지형 칸 안인지
-- (플레이어가 판 굴이나 얇은 벽 옆 굴로 삐져나오면 안 됨)
local function isCovered(inst: PVInstance): boolean
	local cf, size = inst:GetBoundingBox()
	for _, sx in { -0.5, 0, 0.5 } do
		for _, sy in { -0.5, 0.5 } do
			for _, sz in { -0.5, 0.5 } do
				local p = cf:PointToWorldSpace(Vector3.new(sx * size.X, sy * size.Y, sz * size.Z))
				local lo = Vector3.new(math.floor(p.X / 4) * 4, math.floor(p.Y / 4) * 4, math.floor(p.Z / 4) * 4)
				local mats, occ = Terrain:ReadVoxels(Region3.new(lo, lo + Vector3.new(4, 4, 4)), 4)
				if mats[1][1][1] == Enum.Material.Air or occ[1][1][1] < 0.99 then return false end
			end
		end
	end
	return true
end

local BURY_EFFECTS = { "Light", "ParticleEmitter", "Highlight", "Fire" }
local function isEffect(d: Instance): boolean
	for _, c in BURY_EFFECTS do
		if d:IsA(c) then return true end
	end
	return false
end

-- 광석 하나 만들기. buried면 표면 자리에서 (광석 높이 + depth)만큼 흙 속으로. 실패하면 nil
local function spawnOre(f: Field, o: Mines.Ore, surfaceCf: CFrame, mult: number, buried: boolean): Model?
	local tpl = findTemplate(o.model)
	if not tpl then return nil end
	local m = f.mine
	local up = surfaceCf.UpVector
	local model = tpl:Clone()
	model:ScaleTo(rng:NextNumber(1.1, 1.5))
	local cf = surfaceCf * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	if buried and m.buried then
		local _, size = model:GetBoundingBox()
		cf -= up * (size.Y + rng:NextNumber(m.buried.depth.Min, m.buried.depth.Max))
	end
	model:PivotTo(cf)
	if buried then
		-- 덮이지 않았으면 4씩 더 깊이, 두 번 해도 안 되면 이 자리는 포기
		local tries = 0
		while not isCovered(model) do
			tries += 1
			if tries > 2 then
				model:Destroy()
				return nil
			end
			cf -= up * 4
			model:PivotTo(cf)
		end
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then d.Anchored = true end
		-- 묻혀 있는 동안 빛·반짝임이 새어 나오면 숨긴 의미가 없음 (MiningServer가 처음 맞을 때 켬)
		if buried and isEffect(d) then (d :: any).Enabled = false end
	end
	local layer, li = Mines.layerAt(m, cf.Position.Y)
	model.Name = o.name
	model:SetAttribute("Vein", true)
	model:SetAttribute("MineId", m.id)
	model:SetAttribute("Ore", o.name)
	model:SetAttribute("DisplayName", o.displayName)
	model:SetAttribute("Grade", o.grade)
	model:SetAttribute("OreValue", o.value * mult)
	model:SetAttribute("Hardness", layer.hardness + o.hardness - 1)
	model:SetAttribute("Layer", li)
	model:SetAttribute("Origin", if buried then "Buried" else "Wall")
	if buried then model:SetAttribute("Buried", true) end
	CS:AddTag(model, "Ore")
	model.Parent = f.ores
	return model
end

-- 묻힌 광석 개수: 설정값, 없으면 벽 자리 수 × 0.35
local function buriedCount(f: Field): number
	local b = f.mine.buried
	if not b then return 0 end
	return b.count or math.floor(#f.anchors * 0.35)
end

-- 묻힌 광석 전부 새 자리로
local function reburyAll(f: Field)
	for _, o in f.ores:GetChildren() do
		if o:GetAttribute("Origin") == "Buried" then o:Destroy() end
	end
	if #f.anchors == 0 then return end
	local want = buriedCount(f)
	local placed, attempts = 0, 0
	while placed < want and attempts < want * 6 do
		attempts += 1
		local a = f.anchors[rng:NextInteger(1, #f.anchors)]
		local o = pickOre(f.mine, a.cf.Position.Y, true)
		if o and spawnOre(f, o, a.cf, a.mult, true) then placed += 1 end
		if attempts % 20 == 0 then task.wait() end
	end
	print(("[OreSpawner] %s: 묻힌 광석 %d개 새로 묻음"):format(f.mine.id, placed))
end

-- 캐서 비어 있는 벽 광석 자리 다시 채우기. 플레이어가 벽을 파냈으면 지금 표면을 다시 찾는다
local function refillWalls(f: Field)
	local filled = 0
	for i, a in f.anchors do
		if a.ore and a.ore.Parent then continue end
		local up = a.cf.UpVector
		local hit = workspace:Raycast(a.cf.Position + up * 3, -up * 12, terrainOnly)
		if hit then
			local cross = hit.Normal:Cross(Vector3.yAxis)
			local look = if cross.Magnitude > 0.1 then cross.Unit else Vector3.xAxis
			local cf = CFrame.fromMatrix(hit.Position - hit.Normal * 0.35, look, hit.Normal)
			local o = pickOre(f.mine, cf.Position.Y, false)
			a.ore = o and spawnOre(f, o, cf, a.mult, false) or nil
			if a.ore then filled += 1 end
		end
		if i % 25 == 0 then task.wait() end
	end
	print(("[OreSpawner] %s: 벽 광석 %d자리 다시 채움"):format(f.mine.id, filled))
end

-- 광산 하나 준비: 지금 벽에 있는 광석 자리 기억 + 생성기가 묻어 둔 광석 치우고 새로 묻기
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
	reburyAll(f)
end

for _, m in Mines.list do
	task.spawn(setup, m)
end

-- 붕괴 뒤 광맥 재생 (Events.luau: CollapseOccurred(stageId) — A는 광맥 재생 타이머 시작)
EventBus.On(Events.CollapseOccurred, function(stageId: number)
	for _, f in fields do
		if f.mine.order == stageId then
			task.delay(f.mine.buried and f.mine.buried.regrowDelay or 5, function()
				reburyAll(f)
				refillWalls(f)
			end)
		end
	end
end)
