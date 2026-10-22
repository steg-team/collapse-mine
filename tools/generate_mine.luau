--[[
	광산 생성기 — src/shared/Config/Mines.luau 의 설정 한 줄을 읽어 개미굴 동굴 광산을 짓는다.
	(Studio 보기 → 명령창에서 실행. Rojo 동기화 대상 아님)

	사용법
	  1) 아래 MINE_ID를 만들 광산 id로 바꾼다.
	  2) 실행하면 백그라운드로 생성이 돌고, 끝나면 출력 창에 "[Mine] 완료"가 찍힌다.
	     진행 상황: workspace.Mines.<id> 의 GenStatus / GenProgress 속성.
	  3) 같은 id로 다시 실행하면 그 광산만 지우고 새로 짓는다. seed를 바꾸면 다른 모양.

	만들어지는 것 (workspace.Mines.<id>)
	  Ores/      광석 (태그 "Ore", 속성 MineId·Ore·DisplayName·Grade·OreValue·Hardness·Layer)
             설정에 model이 있으면 ServerStorage.OreModels의 광물 틀(Model)을 복사, 없으면 색 돌 파트
	  Rooms/     투명 방 구역 (속성 RoomType=Entrance/Hub/Side/End, Layer, CollapseRisk)
	  Lights/    램프
	  Entrance   허브에서 오면 도착하는 자리 (투명 파트)
	  ExitPoint  밟으면 허브로 돌아가는 발판 (태그 "MineExit")
]]

local MINE_ID = "basic"

local RS = game:GetService("ReplicatedStorage")
local CS = game:GetService("CollectionService")
local CHS = game:GetService("ChangeHistoryService")
local Mines = require(RS:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Mines"))

local M = Mines.get(MINE_ID)
assert(M, "Mines 설정에 없는 id: " .. MINE_ID)

local T = workspace.Terrain
local AIR = Enum.Material.Air
local O = M.origin
local C = M.cave
local rng = Random.new(C.seed)
local S = C.roomScale or 1 -- 방 크기·높이 배율 (굴 폭은 tunnelRadius)

-- 폴더 준비 ------------------------------------------------------------------
local minesRoot = workspace:FindFirstChild("Mines") or Instance.new("Folder")
minesRoot.Name = "Mines"
minesRoot.Parent = workspace
-- 예전 광산(광석·방·램프)은 지우지 않고 ServerStorage.MineBackups로 옮긴다 (지형은 따로 백업해야 함)
local old = minesRoot:FindFirstChild(M.id)
if old then
	local bk = game:GetService("ServerStorage"):FindFirstChild("MineBackups") or Instance.new("Folder")
	bk.Name = "MineBackups"
	bk.Parent = game:GetService("ServerStorage")
	old.Name = M.id .. "_" .. os.date("%m%d_%H%M")
	old.Parent = bk
end
local root = Instance.new("Folder")
root.Name = M.id
root:SetAttribute("MineId", M.id)
root:SetAttribute("GenStatus", "running")
root:SetAttribute("GenProgress", 0)
root.Parent = minesRoot
local oresF = Instance.new("Folder"); oresF.Name = "Ores"; oresF.Parent = root
local roomsF = Instance.new("Folder"); roomsF.Name = "Rooms"; roomsF.Parent = root
local lightsF = Instance.new("Folder"); lightsF.Name = "Lights"; lightsF.Parent = root

local ops = 0
local function tick()
	ops += 1
	if ops % 15 == 0 then task.wait() end
end

local function flat(v: Vector3) return Vector3.new(v.X, 0, v.Z) end
local function distFromCenter(p: Vector3) return (flat(p) - flat(O)).Magnitude end
local function depthOf(y) return M.top - y end

-- 광석은 굴을 다 판 뒤에 박는다. 굴을 파는 도중에 박으면 나중에 지나가는 굴이 벽을 지워 광석이 공중에 뜬다.
-- 그래서 여기서는 자리(pos)와 벽 쪽 방향(dir)만 모아 둔다.
-- 광석 종류·크기는 따로 만든 oreRng로 정해서, 광석 표를 바꿔도 굴 모양(rng 순서)은 그대로 유지된다.
local oreRng = Random.new(C.seed + 1000)
local oreRequests = {}
local function makeOre(pos: Vector3, valueMult: number, dir: Vector3?)
	table.insert(oreRequests, { pos = pos, mult = valueMult, dir = dir })
end

local terrainOnly = RaycastParams.new()
terrainOnly.FilterType = Enum.RaycastFilterType.Include
terrainOnly.FilterDescendantsInstances = { T }

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

-- 모아 둔 자리마다: 벽 쪽(살짝 아래)으로 쏴서 맞은 땅 표면에 박는다
local function placeOre(req)
	local dir: Vector3 = req.dir or Vector3.new(oreRng:NextNumber(-1, 1), 0, oreRng:NextNumber(-1, 1))
	if dir.Magnitude < 0.01 then dir = Vector3.xAxis end
	local castDir = (flat(dir).Unit + Vector3.new(0, -0.35, 0)).Unit
	local hit = workspace:Raycast(req.pos - castDir * 3, castDir * 12, terrainOnly)
	if hit then placeAtWall(oreRng, hit, req.mult) end
end

local function lamp(pos: Vector3, range: number)
	local p = Instance.new("Part")
	p.Name = "Lamp"
	p.Size = Vector3.new(1.2, 1.6, 1.2)
	p.Position = pos
	p.Anchored, p.CanCollide = true, false
	p.Material = Enum.Material.Neon
	p.Color = Color3.fromRGB(255, 200, 130)
	local l = Instance.new("PointLight")
	l.Range, l.Brightness, l.Color = range, 1.4, Color3.fromRGB(255, 210, 150)
	l.Parent = p
	p.Parent = lightsF
end

-- 굴: 바닥점 a → b 사이를 공 모양으로 파냄 (바닥 높이 = 점의 y)
local TR = C.tunnelRadius
local function carveAt(floor: Vector3)
	T:FillBall(floor + Vector3.new(0, TR - 0.5, 0), TR, AIR); tick()
end
local function corridor(a: Vector3, b: Vector3)
	local n = math.max(1, math.ceil((b - a).Magnitude / 2))
	for i = 0, n do carveAt(a:Lerp(b, i / n)) end
end

-- 방: 바닥 평평한 원통 + 낮은 돔
local rooms = {}
local function room(c: Vector3, R: number, kind: string)
	T:FillCylinder(CFrame.new(c + Vector3.new(0, 5 * S, 0)), 10 * S, R, AIR); tick()
	T:FillCylinder(CFrame.new(c + Vector3.new(0, 11 * S, 0)), 4 * S, R * 0.65, AIR); tick()
	local frac = math.clamp(depthOf(c.Y) / (M.top - M.bottom), 0, 1)
	local risk = (kind == "Entrance" or kind == "Hub") and 0 or (0.05 + 0.25 * frac + (kind == "End" and 0.1 or 0))
	local _, li = Mines.layerAt(M, c.Y)
	local m = Instance.new("Part")
	m.Name = "Room_" .. kind
	m.Size = Vector3.new(R * 2, 12 * S, R * 2)
	m.Position = c + Vector3.new(0, 6 * S, 0) -- 바닥 = Position.Y - Size.Y / 2
	m.Anchored, m.CanCollide, m.CanQuery, m.Transparency = true, false, false, 1
	m:SetAttribute("Room", true)
	m:SetAttribute("MineId", M.id)
	m:SetAttribute("RoomType", kind)
	m:SetAttribute("Layer", li)
	m:SetAttribute("CollapseRisk", math.floor(risk * 100) / 100)
	m.Parent = roomsF
	local n = (kind == "Side" and rng:NextInteger(4, 6)) or (kind == "End" and rng:NextInteger(7, 10)) or (kind == "Hub" and 2) or 0
	for _ = 1, n do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = R - rng:NextNumber(0.5, 2)
		makeOre(c + Vector3.new(math.cos(a) * d, rng:NextNumber(1, 6) * S, math.sin(a) * d), kind == "End" and 2 or 1, Vector3.new(math.cos(a), 0, math.sin(a)))
	end
	lamp(c + Vector3.new(0, 9 * S, 0), math.max(24, R * 2.2))
	table.insert(rooms, { c = c, R = R, kind = kind })
end

-- 1) 땅 채우기 ---------------------------------------------------------------
local FR = M.radius + 20
T:FillCylinder(CFrame.new(O + Vector3.new(0, (0 + M.top) / 2, 0)), -M.top, FR, Enum.Material.Grass); tick()
for _, L in M.layers do
	T:FillCylinder(CFrame.new(O + Vector3.new(0, (L.top + L.bottom) / 2, 0)), L.top - L.bottom, FR, L.material); tick()
	task.wait()
end
local last = M.layers[#M.layers]
T:FillCylinder(CFrame.new(O + Vector3.new(0, M.bottom - 6, 0)), 12, FR, last.material); tick()
root:SetAttribute("GenProgress", 0.1)

-- 2) 입구 방 + 허브 방 무리 ---------------------------------------------------
-- 입구 방 천장(바닥 + 13S)이 지표 아래 지형 한 칸(4)을 남기게
local entranceFloor = Vector3.new(O.X, M.top - math.ceil(13 * S + 3), O.Z)
room(entranceFloor, 16 * S, "Entrance")

local entrance = Instance.new("Part")
entrance.Name = "Entrance"
entrance.Size = Vector3.new(6, 1, 6)
entrance.CFrame = CFrame.new(entranceFloor + Vector3.new(-6, 0.5, 0))
entrance.Anchored, entrance.CanCollide, entrance.CanQuery, entrance.Transparency = true, false, false, 1
entrance:SetAttribute("MineId", M.id)
entrance.Parent = root

local exitPad = Instance.new("Part")
exitPad.Name = "ExitPoint"
exitPad.Size = Vector3.new(7, 0.6, 7)
exitPad.CFrame = CFrame.new(entranceFloor + Vector3.new(7, 0.3, 0))
exitPad.Anchored, exitPad.CanCollide = true, false
exitPad.Material = Enum.Material.Neon
exitPad.Color = Color3.fromRGB(90, 220, 120)
exitPad:SetAttribute("MineId", M.id)
CS:AddTag(exitPad, "MineExit")
local bb = Instance.new("BillboardGui")
bb.Size = UDim2.fromOffset(160, 40); bb.StudsOffset = Vector3.new(0, 4, 0); bb.MaxDistance = 60
local tl = Instance.new("TextLabel")
tl.Size = UDim2.fromScale(1, 1); tl.BackgroundTransparency = 1; tl.TextScaled = true
tl.Font = Enum.Font.GothamBold; tl.TextColor3 = Color3.new(1, 1, 1); tl.TextStrokeTransparency = 0.4
tl.Text = "출구 · 허브로"
tl.Parent = bb; bb.Parent = exitPad
exitPad.Parent = root

local hubs = { { c = entranceFloor } }
for i = 1, C.hubRooms do
	local ang = (i - 1) / C.hubRooms * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
	local c = entranceFloor + Vector3.new(math.cos(ang) * 42 * S, -4 - 3 * i, math.sin(ang) * 42 * S)
	corridor(entranceFloor, c)
	room(c, rng:NextNumber(10, 13) * S, "Hub")
	table.insert(hubs, { c = c })
end
root:SetAttribute("GenProgress", 0.2)

-- 3) 굴 갈래 -----------------------------------------------------------------
-- 바닥이 지층 범위를 벗어나지 않게
local minFloor = M.bottom + 8
local maxFloor = M.top - (TR * 2 + 4) -- 굴 천장이 지표 아래 지형 한 칸(4)을 남기게

local function walkBranch(start: Vector3, heading: number, targetFloor: number, maxLen: number, depth: number)
	local P = start
	local h = heading
	local len = 0
	local nextRoomAt = rng:NextNumber(C.roomSpacing.Min, C.roomSpacing.Max)
	local side = (rng:NextNumber() < 0.5) and 1 or -1
	local steps = 0
	while len < maxLen do
		-- 방향: 흔들림 + 바깥 경계에서 안쪽으로, 중심 근처에선 바깥으로
		h += rng:NextNumber(-0.14, 0.14)
		local rel = flat(P) - flat(O)
		local d = rel.Magnitude
		local outAng = math.atan2(rel.Z, rel.X)
		local diff = (outAng - h + math.pi) % (2 * math.pi) - math.pi
		if d > M.radius - 45 then
			h += (diff > 0 and -0.25 or 0.25) -- 바깥을 향하면 꺾기
			if math.abs(diff) < 1.2 then h += (diff > 0 and -0.3 or 0.3) end
		elseif d < 70 and steps > 8 then
			h += diff * 0.15
		end
		local dy = 0
		if P.Y > targetFloor + 0.5 then dy = -0.9 elseif P.Y < targetFloor - 0.5 then dy = 0.6 else dy = rng:NextNumber(-0.15, 0.15) end
		local np = P + Vector3.new(math.cos(h) * 3, dy, math.sin(h) * 3)
		np = Vector3.new(np.X, math.clamp(np.Y, minFloor, maxFloor), np.Z)
		P = np
		carveAt(P)
		len += 3
		steps += 1
		if steps % 9 == 0 then
			-- 굴 벽에 가끔 광석
			local perp = Vector3.new(-math.sin(h), 0, math.cos(h)) * (rng:NextNumber() < 0.5 and 1 or -1)
			if rng:NextNumber() < 0.5 then makeOre(P + perp * (TR - 0.6) + Vector3.new(0, rng:NextNumber(1.5, 4), 0), 1, perp) end
		end
		if steps % 22 == 0 then lamp(P + Vector3.new(0, TR * 2 - 1.5, 0), 26) end
		if len >= nextRoomAt and len < maxLen - 20 then
			local perp = Vector3.new(-math.sin(h), 0, math.cos(h)) * side
			side = -side
			local R = rng:NextNumber(8, 12) * S
			local rc = P + perp * (R + 6)
			if distFromCenter(rc) < M.radius - R - 8 then
				corridor(P, rc)
				room(rc, R, "Side")
				if depth == 0 and rng:NextNumber() < C.subBranchChance then
					local subH = math.atan2(perp.Z, perp.X) + rng:NextNumber(-0.5, 0.5)
					local subTarget = math.clamp(targetFloor - rng:NextNumber(5, 25), minFloor, maxFloor)
					walkBranch(rc, subH, subTarget, maxLen * rng:NextNumber(0.35, 0.55), 1)
				end
			end
			nextRoomAt = len + rng:NextNumber(C.roomSpacing.Min, C.roomSpacing.Max)
		end
		if d > M.radius - 20 then break end
	end
	local perp = Vector3.new(math.cos(h), 0, math.sin(h))
	local ec = P + perp * 6
	if distFromCenter(ec) > M.radius - 16 then ec = P end
	corridor(P, ec)
	room(ec, rng:NextNumber(11, 14) * S, "End")
end

for b = 1, C.branches do
	local ang = (b - 1) / C.branches * math.pi * 2 + rng:NextNumber(-0.15, 0.15)
	-- 가장 가까운 허브 방에서 출발
	local dir = Vector3.new(math.cos(ang), 0, math.sin(ang))
	local best, bs = hubs[1], -math.huge
	for _, hb in hubs do
		local s = (flat(hb.c) - flat(O)):Dot(dir)
		if s > bs then best, bs = hb, s end
	end
	local target = rng:NextNumber(minFloor, maxFloor - 15)
	walkBranch(best.c, ang, target, rng:NextNumber(M.radius * 0.75, M.radius * 1.05), 0)
	root:SetAttribute("GenProgress", 0.2 + 0.8 * b / C.branches)
end

-- 4) 광석 박기 (굴을 다 판 뒤) ------------------------------------------------
for i, req in oreRequests do
	placeOre(req)
	if i % 25 == 0 then task.wait() end
end

-- 마무리 ---------------------------------------------------------------------
local counts = {}
for _, r in rooms do counts[r.kind] = (counts[r.kind] or 0) + 1 end
root:SetAttribute("Rooms", #rooms)
root:SetAttribute("Ores", #oresF:GetChildren())
root:SetAttribute("GenStatus", "done")
root:SetAttribute("GenProgress", 1)
print(("[Mine] 완료 %s: 방 %d개 (옆방 %d, 끝방 %d), 광석 %d개, 램프 %d개"):format(
	M.id, #rooms, counts.Side or 0, counts.End or 0, #oresF:GetChildren(), #lightsF:GetChildren()))
pcall(function() CHS:SetWaypoint("Mine generated: " .. M.id) end)
