--[[
	광산의 광석만 새로 박기 — 굴(지형)은 그대로 두고 Ores 폴더만 바꾼다.
	(Studio 보기 → 명령창에서 실행. Rojo 동기화 대상 아님)

	언제 쓰나
	  광물표(src/shared/Config/Mines.luau의 ores)나 광물 틀(ServerStorage.OreModels)을 바꿨는데
	  광산 전체를 다시 생성하기는 싫을 때. 예전 광석 자리마다 가장 가까운 벽을 찾아 새 광석을 박는다.

	사용법
	  1) MINE_ID를 고친다.
	  2) 실행. 예전 Ores 폴더는 ServerStorage.OreBackups.<id>_<시각>으로 옮겨 둔다 (되돌리려면 다시 옮기면 됨).
	  3) Ctrl+Z로도 되돌릴 수 있다.

	광석 배치 규칙은 tools/generate_mine.luau의 placeOre와 같다. 한쪽을 고치면 다른 쪽도 맞춘다.
]]

local MINE_ID = "basic"

local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
local CS = game:GetService("CollectionService")
local CHS = game:GetService("ChangeHistoryService")
local Mines = require(RS:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Mines"))

local M = Mines.get(MINE_ID)
assert(M, "Mines 설정에 없는 id: " .. MINE_ID)
local root = workspace:FindFirstChild("Mines") and workspace.Mines:FindFirstChild(M.id)
assert(root and root:FindFirstChild("Ores"), "광산이 아직 없음. tools/generate_mine.luau로 먼저 생성")

local T = workspace.Terrain
local rng = Random.new(M.cave.seed + 2000)

local terrainOnly = RaycastParams.new()
terrainOnly.FilterType = Enum.RaycastFilterType.Include
terrainOnly.FilterDescendantsInstances = { T }

-- 예전 광석 자리에서 가장 가까운 땅 표면 (옆 8방향, 살짝 아래로 기울임)
-- 예전 광석은 중심이 벽 속에 묻힌 경우가 많다. 땅 속에서 쏜 레이는 아무것도 못 맞히므로
-- 바깥 공중(10스터드 밖)에서 광석 자리 쪽으로 거꾸로 쏴서, 굴 쪽을 보는 표면을 찾는다.
local function nearestWall(pos: Vector3): RaycastResult?
	local best: RaycastResult? = nil
	local bestDist = math.huge
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		local dir = (Vector3.new(math.cos(a), -0.35, math.sin(a))).Unit
		local hit = workspace:Raycast(pos - dir * 3, dir * 12, terrainOnly) -- 광석 자리가 공중일 때
			or workspace:Raycast(pos - dir * 10, dir * 10.5, terrainOnly) -- 광석 자리가 벽 속일 때
		if hit then
			local dist = (hit.Position - pos).Magnitude
			if dist < bestDist then best, bestDist = hit, dist end
		end
	end
	return best
end

-- 끝방 광석은 가치 2배 (생성기와 같은 규칙)
local endRooms = {}
for _, r in root.Rooms:GetChildren() do
	if r:GetAttribute("RoomType") == "End" then table.insert(endRooms, r) end
end
local function inEndRoom(p: Vector3): boolean
	for _, r in endRooms do
		local rel = p - r.Position
		if Vector3.new(rel.X, 0, rel.Z).Magnitude <= r.Size.X / 2 + 1 and math.abs(rel.Y) <= r.Size.Y / 2 + 2 then return true end
	end
	return false
end

local rec = CHS:TryBeginRecording("Replace mine ores: " .. M.id)

-- 예전 광석 백업
local oldOres = root.Ores
local spots = {}
for _, o in oldOres:GetChildren() do
	if o:GetAttribute("Buried") then continue end -- 땅 속 광석 자리는 벽 위치가 아님
	local p = if o:IsA("Model") then o:GetPivot().Position elseif o:IsA("BasePart") then o.Position else nil
	if p then table.insert(spots, p) end
end
local backups = SS:FindFirstChild("OreBackups") or Instance.new("Folder")
backups.Name = "OreBackups"
backups.Parent = SS
oldOres.Name = M.id .. "_" .. os.date("%m%d_%H%M")
oldOres.Parent = backups

local oresF = Instance.new("Folder")
oresF.Name = "Ores"
oresF.Parent = root

-- ── 광석 박기 공통 (tools/generate_mine.luau 와 tools/replace_mine_ores.luau 에 똑같이 들어 있음. 한쪽을 고치면 다른 쪽도) ──
-- 벽 표면에는 묻는 등급(M.buried.grades)이 아닌 광물만 보이게 박고,
-- 묻는 등급은 벽 표면에서 depth만큼 땅 속에 숨겨서 지형을 파야만 나오게 한다.
-- 묻힌 광석은 빛·반짝임·외곽선을 꺼 둔다 (MiningServer가 처음 맞을 때 다시 켬).
local function isBuriedGrade(o): boolean
	return M.buried ~= nil and table.find(M.buried.grades, o.grade) ~= nil
end

local function pickFrom(r: Random, y: number, wantBuried: boolean)
	local d = M.top - y
	local total, pool = 0, {}
	for _, o in M.ores do
		if d >= o.minDepth and isBuriedGrade(o) == wantBuried then total += o.weight; table.insert(pool, o) end
	end
	if #pool == 0 then return nil end
	local n = r:NextNumber(0, total)
	for _, o in pool do
		n -= o.weight
		if n <= 0 then return o end
	end
	return pool[#pool]
end

local function findTemplate(path: string?): Model?
	if not path then return nil end
	local node: Instance? = game:GetService("ServerStorage"):FindFirstChild("OreModels")
	for part in string.gmatch(path, "[^/]+") do
		node = node and node:FindFirstChild(part)
	end
	return (node and node:IsA("Model")) and node or nil
end

-- 묻힌 광석이 흙에 완전히 덮였는지: 상자 꼭짓점·가운데가 모두 꽉 찬 지형 칸 안인지
-- (벽이 얇으면 옆 굴로 삐져나올 수 있어서 확인)
local function isCovered(inst: PVInstance): boolean
	local cf, size = inst:GetBoundingBox()
	for _, sx in { -0.5, 0, 0.5 } do
		for _, sy in { -0.5, 0.5 } do
			for _, sz in { -0.5, 0.5 } do
				local p = cf:PointToWorldSpace(Vector3.new(sx * size.X, sy * size.Y, sz * size.Z))
				local lo = Vector3.new(math.floor(p.X / 4) * 4, math.floor(p.Y / 4) * 4, math.floor(p.Z / 4) * 4)
				local mats, occ = workspace.Terrain:ReadVoxels(Region3.new(lo, lo + Vector3.new(4, 4, 4)), 4)
				if mats[1][1][1] == Enum.Material.Air or occ[1][1][1] < 0.99 then return false end
			end
		end
	end
	return true
end

local function spawnOre(r: Random, o, surfaceCf: CFrame, up: Vector3, mult: number, buried: boolean)
	local inst: PVInstance
	local cf = surfaceCf
	local tpl = findTemplate(o.model)
	if tpl then
		local m = tpl:Clone()
		m:ScaleTo(r:NextNumber(1.1, 1.5))
		if buried then
			local _, size = m:GetBoundingBox()
			cf = cf - up * (size.Y + r:NextNumber(M.buried.depth.Min, M.buried.depth.Max))
		end
		m:PivotTo(cf)
		if buried then
			-- 덮이지 않았으면 4씩 더 깊이, 두 번 해도 안 되면 이 자리는 포기
			local tries = 0
			while not isCovered(m) do
				tries += 1
				if tries > 2 then m:Destroy(); return nil end
				cf = cf - up * 4
				m:PivotTo(cf)
			end
		end
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then d.Anchored = true end
			if buried and (d:IsA("Light") or d:IsA("ParticleEmitter") or d:IsA("Highlight") or d:IsA("Fire")) then
				d.Enabled = false
			end
		end
		inst = m
	else
		-- 틀이 없는 광물은 색 돌덩이
		local p = Instance.new("Part")
		local s = r:NextNumber(2.5, 4.5)
		p.Size = Vector3.new(s, s * r:NextNumber(0.7, 1.3), s * r:NextNumber(0.7, 1.3))
		if buried then cf = cf - up * (s + r:NextNumber(M.buried.depth.Min, M.buried.depth.Max)) end
		p.CFrame = cf * CFrame.new(0, p.Size.Y * 0.3, 0) * CFrame.Angles(r:NextNumber(0, 6.28), r:NextNumber(0, 6.28), r:NextNumber(0, 6.28))
		p.Anchored = true
		p.Material, p.Color = o.material, o.color
		inst = p
	end
	local layer, li = Mines.layerAt(M, cf.Position.Y)
	inst.Name = o.name
	inst:SetAttribute("Vein", true)
	inst:SetAttribute("MineId", M.id)
	inst:SetAttribute("Ore", o.name)
	inst:SetAttribute("DisplayName", o.displayName)
	inst:SetAttribute("Grade", o.grade)
	inst:SetAttribute("OreValue", o.value * mult)
	inst:SetAttribute("Hardness", layer.hardness + o.hardness - 1)
	inst:SetAttribute("Layer", li)
	if buried then inst:SetAttribute("Buried", true) end
	CS:AddTag(inst, "Ore")
	inst.Parent = oresF
	return inst
end

-- 벽 표면 한 점(hit)에: 보이는 광석 하나 + 확률로 그 뒤 땅 속에 묻힌 광석 하나
local function placeAtWall(r: Random, hit: RaycastResult, mult: number): number
	local up = hit.Normal
	local base = hit.Position - up * 0.35 -- 조금 파묻어서 벽에서 자라난 것처럼
	local cross = up:Cross(Vector3.yAxis)
	local look = cross.Magnitude > 0.1 and cross.Unit or Vector3.xAxis
	local surfaceCf = CFrame.fromMatrix(base, look, up) * CFrame.Angles(0, r:NextNumber(0, math.pi * 2), 0)
	local n = 0
	local o = pickFrom(r, base.Y, false)
	if o and spawnOre(r, o, surfaceCf, up, mult, false) then n += 1 end
	if M.buried and r:NextNumber() < M.buried.chance then
		local b = pickFrom(r, base.Y, true)
		if b and spawnOre(r, b, surfaceCf, up, mult, true) then n += 1 end
	end
	return n
end
-- ── 광석 박기 공통 끝 ──


local placed, skipped = 0, 0
for i, spot in spots do
	local hit = nearestWall(spot)
	if hit then
		placed += placeAtWall(rng, hit, inEndRoom(hit.Position) and 2 or 1)
	else
		skipped += 1
	end
	if i % 25 == 0 then task.wait() end
end

root:SetAttribute("Ores", placed)
if rec then CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end

local counts = {}
for _, o in oresF:GetChildren() do counts[o.Name] = (counts[o.Name] or 0) + 1 end
local parts = {}
for _, o in M.ores do table.insert(parts, ("%s %d"):format(o.displayName, counts[o.name] or 0)) end
print(("[Ores] %s: 광석 %d개 박음 (벽 못 찾아 건너뜀 %d) — %s. 예전 광석은 ServerStorage.OreBackups.%s"):format(
	M.id, placed, skipped, table.concat(parts, ", "), oldOres.Name))
