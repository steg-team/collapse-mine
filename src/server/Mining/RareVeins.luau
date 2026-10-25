--!strict
--[[
	숨은 희귀 광맥 (A, D-036)

	광산마다 벽 속에 보이지 않는 광맥 자리를 몇 개 둔다 (파트·광석 없음, 좌표만 서버에 있음).
	- 근처를 파면 "파다가 발견" 확률이 크게 오른다 (MiningServer.rollDigFind가 chanceAt으로 물어봄).
	- 카나리아(B)는 nearest로 가장 가까운 광맥까지 거리만 받는다. 위치는 클라이언트에 보내지 않는다 (보안 규칙).
	- 광맥 하나에서 yield개 나오면 사라지고 같은 광산 다른 자리에 새로 생긴다.
	- 붕괴(CollapseOccurred) 때는 그 광산 광맥을 전부 새 자리로 옮긴다.
	숫자는 Config/Mines.luau RARE_VEINS (임시값).

	자리 정하기: 광산의 방(Rooms, 입구 방 제외) 중 하나를 고른다 (붕괴 위험 큰 방일수록 자주).
	방 가운데서 아무 방향으로 수평 레이를 쏴 벽 표면을 찾고, 그 방향으로 벽 속 wallDepth만큼 들어간 자리.
	맨 아래 지층 방에서 deepCount개, 나머지 지층에서 count - deepCount개.

	조회 함수 (B가 0.5초마다 부름)
	  RareVeins.nearest(mineId: string, position: Vector3) -> number?
	    가장 가까운 살아 있는 광맥 중심까지 거리(스터드). 그 광산에 광맥이 없으면 nil
]]

local RS = game:GetService("ReplicatedStorage")

local Shared = RS:WaitForChild("Shared")
local Mines = require(Shared:WaitForChild("Config"):WaitForChild("Mines"))
local Events = require(Shared:WaitForChild("Events"))
local EventBus = require(Shared:WaitForChild("EventBus"))

local CFG = Mines.RARE_VEINS
local MAX_TRIES = 20 -- 자리 하나 찾을 때 레이를 쏴 보는 횟수 (방이 열린 쪽이면 벽을 못 찾음)

type Vein = { pos: Vector3, left: number, deep: boolean }
type RoomInfo = { floor: Vector3, radius: number, weight: number }
type Field = { rooms: { RoomInfo }, deepRooms: { RoomInfo }, veins: { Vein } }

local RareVeins = {}
local fields: { [string]: Field } = {}
local rng = Random.new()

local terrainOnly = RaycastParams.new()
terrainOnly.FilterType = Enum.RaycastFilterType.Include
terrainOnly.FilterDescendantsInstances = { workspace.Terrain }

-- 방 목록에서 가중치로 하나
local function pickRoom(list: { RoomInfo }): RoomInfo?
	local total = 0
	for _, r in list do total += r.weight end
	if total <= 0 then return nil end
	local n = rng:NextNumber(0, total)
	for _, r in list do
		n -= r.weight
		if n <= 0 then return r end
	end
	return list[#list]
end

-- 방 둘레 벽 속 자리 하나. 다른 광맥과 너무 붙지 않게 (반경 두 배 이상 떨어지게)
local function findSpot(f: Field, deep: boolean): Vector3?
	local list = if deep and #f.deepRooms > 0 then f.deepRooms else f.rooms
	for _ = 1, MAX_TRIES do
		local room = pickRoom(list)
		if not room then return nil end
		local a = rng:NextNumber(0, math.pi * 2)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local origin = room.floor + Vector3.new(0, rng:NextNumber(2, 6), 0)
		local hit = workspace:Raycast(origin, dir * (room.radius + 30), terrainOnly)
		if hit then
			local pos = hit.Position + dir * rng:NextNumber(CFG.wallDepth.Min, CFG.wallDepth.Max)
			local ok = true
			for _, v in f.veins do
				if (v.pos - pos).Magnitude < CFG.radius * 2 then ok = false break end
			end
			if ok then return pos end
		end
	end
	return nil
end

local function spawnVein(f: Field, deep: boolean)
	local pos = findSpot(f, deep)
	if pos then
		table.insert(f.veins, { pos = pos, left = CFG.yield, deep = deep })
	end
end

-- 그 광산 광맥을 전부 새 자리로
local function reshuffle(f: Field)
	table.clear(f.veins)
	for i = 1, CFG.count do
		spawnVein(f, i <= CFG.deepCount)
	end
end

local function setup(m: Mines.Mine)
	local root = workspace:WaitForChild("Mines", 30)
	local folder = root and root:WaitForChild(m.id, 30)
	local roomsF = folder and folder:WaitForChild("Rooms", 30)
	if not roomsF then
		warn("[RareVeins] 방 목록 없음: " .. m.id)
		return
	end
	local f: Field = { rooms = {}, deepRooms = {}, veins = {} }
	-- 파다가 발견 광물이 나오기 시작하는 깊이. 이보다 얕은 방에 광맥을 두면 아무것도 안 나온다
	local minDig = math.huge
	for _, o in m.ores do
		if m.digFinds and table.find(m.digFinds.grades, o.grade) then minDig = math.min(minDig, o.minDepth) end
	end
	if minDig == math.huge then minDig = 0 end
	for _, inst in roomsF:GetChildren() do
		if not inst:IsA("BasePart") then continue end
		local p = inst :: BasePart
		local floor = p.Position - Vector3.new(0, p.Size.Y / 2, 0) -- 방 표시 파트 바닥 = 방 바닥 (generate_mine)
		if p:GetAttribute("RoomType") ~= "Entrance" and m.top - floor.Y >= minDig then
			local info: RoomInfo = {
				floor = floor,
				radius = p.Size.X / 2,
				weight = 1 + (tonumber(p:GetAttribute("CollapseRisk")) or 0) * CFG.riskWeight,
			}
			if p:GetAttribute("Layer") == #m.layers then
				table.insert(f.deepRooms, info)
			else
				table.insert(f.rooms, info)
			end
		end
	end
	-- 지층이 하나뿐이거나 위층 방이 없으면 있는 방을 같이 쓴다
	if #f.rooms == 0 then f.rooms = f.deepRooms end
	if #f.rooms == 0 then
		warn("[RareVeins] 방이 없음: " .. m.id)
		return
	end
	fields[m.id] = f
	reshuffle(f)
	print(("[RareVeins] %s: 광맥 %d개"):format(m.id, #f.veins))
end

-- 판 공 중심 기준 희귀 이상이 나올 확률. 광맥 밖이면 nil (MiningServer가 기본 확률을 쓴다)
-- 두 번째 값은 그 광맥 (나왔을 때 consume에 넘김)
function RareVeins.chanceAt(mineId: string, center: Vector3): (number?, Vein?)
	local f = fields[mineId]
	if not f then return nil, nil end
	for _, v in f.veins do
		if (v.pos - center).Magnitude <= CFG.radius then
			return CFG.chance, v
		end
	end
	return nil, nil
end

-- 광맥에서 희귀 광물이 하나 나옴. 다 나오면 사라지고 다른 자리에 새로
function RareVeins.consume(mineId: string, vein: Vein)
	local f = fields[mineId]
	if not f then return end
	local i = table.find(f.veins, vein)
	if not i then return end -- 이미 사라진 광맥 (붕괴로 옮겨졌거나, 같은 순간 둘이 마지막 하나를 팠음)
	vein.left -= 1
	if vein.left > 0 then return end
	table.remove(f.veins, i)
	spawnVein(f, vein.deep)
end

function RareVeins.nearest(mineId: string, position: Vector3): number?
	local f = fields[mineId]
	if not f or #f.veins == 0 then return nil end
	local best = math.huge
	for _, v in f.veins do
		local d = (v.pos - position).Magnitude
		if d < best then best = d end
	end
	return best
end

-- 서버가 켜질 때 광산마다 (지형·방이 원래 모양일 때)
for _, m in Mines.list do
	task.spawn(setup, m)
end

-- 붕괴 뒤 그 광산 광맥을 전부 새 자리로 (Events.luau: CollapseOccurred(mineId))
EventBus.On(Events.CollapseOccurred, function(mineId: string)
	local f = fields[mineId]
	if f then reshuffle(f) end
end)

return RareVeins
