--!strict
-- 광석 랜덤 배치 + 붕괴 뒤 광맥 재생 (A)
--
-- 벽에 보이는 광석(일반·고급)은 맵에 박힌 자리 그대로 쓰고, 그 자리들을 "벽 표면 자리"로 기억한다.
-- 땅 속에 묻는 광석(Mines 설정 buried.grades)은 서버가 켜질 때마다 광산 흙 전체(굴 밖 꽉 찬 땅)의
-- 아무 데나 buried.count개 랜덤으로 묻는다. 서버마다 위치가 달라 외워서 캐러 갈 수 없고,
-- 어디를 파든 가끔 나온다. 깊을수록 비싼 광물(설정 minDepth)이 섞인다.
-- 예전에 맵에 미리 묻어 둔 광석(속성 Buried)이 있으면 시작할 때 치운다.
--
-- 붕괴(CollapseOccurred)가 나면 그 광산의 묻힌 광석을 전부 새 자리로 다시 묻고,
-- 캐서 비어 있는 벽 광석 자리도 다시 채운다 ("붕괴가 끝이 아니라 다음 광맥의 시작", game-design 광맥 재생).

local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
local CS = game:GetService("CollectionService")

local Shared = RS:WaitForChild("Shared")
local Mines = require(Shared:WaitForChild("Config"):WaitForChild("Mines"))
local Events = require(Shared:WaitForChild("Events"))
local FloorGuard = require(script.Parent:WaitForChild("FloorGuard"))
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

-- 광석 하나 만들기. 벽 광석은 surfaceCf(표면에 바닥을 붙인 자리), 묻는 광석은 흙 속 한 점. 실패하면 nil
local function spawnOre(f: Field, o: Mines.Ore, surfaceCf: CFrame, mult: number, buried: boolean): Model?
	local tpl = findTemplate(o.model)
	if not tpl then return nil end
	local m = f.mine
	local model = tpl:Clone()
	model:ScaleTo(rng:NextNumber(1.1, 1.5))
	local cf = surfaceCf * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	model:PivotTo(cf)
	-- 묻는 광석은 흙에 완전히 덮여야 함 (굴이나 플레이어가 판 구멍에 걸치면 이 자리는 포기)
	if buried and not isCovered(model) then
		model:Destroy()
		return nil
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

-- 묻힌 광석 전부 새 자리로: 광산 원기둥 안 아무 점이나 뽑아서, 흙 속이고 길바닥 바로 밑이 아니면 묻는다
local function reburyAll(f: Field)
	for _, o in f.ores:GetChildren() do
		if o:GetAttribute("Origin") == "Buried" then o:Destroy() end
	end
	local m = f.mine
	if not m.buried then return end
	local want = m.buried.count
	local yLo, yHi = m.bottom + 6, m.top - 10 -- 지표 바로 밑·바닥 끝은 피함
	local placed, attempts = 0, 0
	while placed < want and attempts < want * 5 do
		attempts += 1
		-- 원 안에 고르게 (반지름에 sqrt)
		local ang = rng:NextNumber(0, math.pi * 2)
		local rad = (m.radius - 12) * math.sqrt(rng:NextNumber())
		local p = m.origin + Vector3.new(math.cos(ang) * rad, 0, math.sin(ang) * rad)
		p = Vector3.new(p.X, rng:NextNumber(yLo, yHi), p.Z)
		-- 길바닥 밑(보호 칸 근처)엔 묻지 않음: 바닥을 못 파니 영영 못 캐는 광석이 됨
		local underFloor = FloorGuard.isProtected(m.id, p + Vector3.new(0, 4, 0)) or FloorGuard.isProtected(m.id, p + Vector3.new(0, 8, 0))
		local o = not underFloor and pickOre(m, p.Y, true) or nil
		if o then
			local cf = CFrame.new(p) * CFrame.Angles(rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28))
			if spawnOre(f, o, cf, 1, true) then placed += 1 end
		end
		if attempts % 25 == 0 then task.wait() end
	end
	print(("[OreSpawner] %s: 묻힌 광석 %d개 새로 묻음 (시도 %d)"):format(m.id, placed, attempts))
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
	-- 길바닥 정보(FloorGuard, MiningServer가 훑음)가 준비되면 묻기 (최대 60초 기다림)
	local t0 = os.clock()
	while not FloorGuard.isReady(m.id) and os.clock() - t0 < 60 do task.wait(0.5) end
	reburyAll(f)
end

for _, m in Mines.list do
	task.spawn(setup, m)
end

-- 붕괴 뒤 광맥 재생 (Events.luau: CollapseOccurred(stageId) — A는 광맥 재생 타이머 시작)
EventBus.On(Events.CollapseOccurred, function(stageId: number)
	for _, f in fields do
		if f.mine.order == stageId then
			task.delay(if f.mine.buried then f.mine.buried.regrowDelay else 5, function()
				reburyAll(f)
				refillWalls(f)
			end)
		end
	end
end)
