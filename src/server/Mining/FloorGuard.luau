--!strict
-- 길바닥 보호 (A): 광산 굴·방·출구 비탈의 원래 바닥은 곡괭이로 못 파게 한다.
--
-- 왜: 바닥을 파서 구멍을 내면 붕괴 때 출구까지 걸어 올라갈 길이 끊긴다.
-- 어떻게: 서버가 켜질 때(지형이 아직 원래 모양일 때) 광산 지형을 훑어서
--   "위가 비고 옆이 다 찬 지형 칸"(= 평평한 바닥 표면 칸)과 그 바로 아래 칸을 보호 칸으로 기억한다.
--   굴 벽은 비탈이라 옆이 비어 있어서 보호 안 됨 → 벽을 옆으로 파서 새 굴을 내는 건 된다.
--   채굴(MiningServer)이 지형을 팔 때 파는 공이 보호 칸에 닿으면 공을 위로 올려서 바닥은 남긴다.
--   그래서 길에서 옆으로 새 굴은 팔 수 있지만, 길바닥 아래로는 못 판다.
-- 지표(광산 top 근처)는 MiningServer의 지표 보호가 따로 막으니 여기선 뺀다.

local Mines = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Mines"))

local Terrain = workspace.Terrain
local VOXEL = 4
local CHUNK = 32 -- 한 번에 읽는 가로·세로 칸 수 (지형 읽기 한도 안에서)
local SURFACE_OCC = 0.05 -- 이보다 덜 차 있으면 빈 칸으로 봄

local FloorGuard = {}

-- 광산 id → 보호 칸 집합 (키 = 칸 좌표 문자열 대신 숫자 하나로 묶은 값)
local protected: { [string]: { [number]: boolean } } = {}
local readyFlags: { [string]: boolean } = {}

-- 칸 좌표 (x, y, z) 를 숫자 하나로. 각 축 -4096~4095 칸이면 충분 (±16k 스터드)
local function key(x: number, y: number, z: number): number
	return ((x + 4096) * 8192 + (y + 4096)) * 8192 + (z + 4096)
end

local function voxelOf(v: number): number
	return math.floor(v / VOXEL)
end

-- 광산 하나 훑기. 서버 시작 때 한 번 (몇 초 걸려서 task.wait로 나눠 돎)
function FloorGuard.build(m: Mines.Mine)
	local set: { [number]: boolean } = {}
	local r = m.radius + 24 -- 출구 비탈처럼 광산 밖으로 조금 나간 길도 포함
	local x0, x1 = voxelOf(m.origin.X - r), voxelOf(m.origin.X + r)
	local z0, z1 = voxelOf(m.origin.Z - r), voxelOf(m.origin.Z + r)
	local y0 = voxelOf(m.bottom - 12)
	local yTop = voxelOf(m.top - VOXEL) -- 지표 바로 아래 칸까지만 (지표는 따로 보호)
	local count = 0
	for cx = x0, x1, CHUNK do
		for cz = z0, z1, CHUNK do
			local ex, ez = math.min(cx + CHUNK - 1, x1), math.min(cz + CHUNK - 1, z1)
			-- 위 칸이 비었는지 + 옆 칸이 차 있는지 봐야 해서 위로 한 칸, 옆으로 한 칸씩 더 읽음
			local region = Region3.new(
				Vector3.new((cx - 1) * VOXEL, y0 * VOXEL, (cz - 1) * VOXEL),
				Vector3.new((ex + 2) * VOXEL, (yTop + 2) * VOXEL, (ez + 2) * VOXEL)
			)
			local _, occ = Terrain:ReadVoxels(region, VOXEL)
			local sx, sy, sz = occ.Size.X, occ.Size.Y, occ.Size.Z
			local function solid(ix: number, iy: number, iz: number): boolean
				return occ[ix][iy][iz] > SURFACE_OCC
			end
			for ix = 2, sx - 1 do
				for iz = 2, sz - 1 do
					for iy = 1, sy - 1 do
						-- 바닥 = 위가 비고, 동서남북 같은 높이가 다 차 있는 칸 (굴 벽 비탈은 옆이 비어 있어서 빠짐)
						if solid(ix, iy, iz) and not solid(ix, iy + 1, iz) and iy + y0 - 1 <= yTop
							and solid(ix - 1, iy, iz) and solid(ix + 1, iy, iz) and solid(ix, iy, iz - 1) and solid(ix, iy, iz + 1)
						then
							local vx, vy, vz = cx + ix - 2, y0 + iy - 1, cz + iz - 2
							set[key(vx, vy, vz)] = true
							set[key(vx, vy - 1, vz)] = true -- 표면 칸 아래 한 칸도 (바닥 두께)
							count += 1
						end
					end
				end
			end
			task.wait()
		end
	end
	protected[m.id] = set
	readyFlags[m.id] = true
	print(("[FloorGuard] %s: 바닥 표면 %d칸 보호"):format(m.id, count))
end

function FloorGuard.isReady(mineId: string): boolean
	return readyFlags[mineId] == true
end

-- 이 지점의 지형 칸이 보호 칸인지 (광석 스포너가 길바닥 밑에 광석을 안 묻게 쓸 수 있음)
function FloorGuard.isProtected(mineId: string, p: Vector3): boolean
	local set = protected[mineId]
	return set ~= nil and set[key(voxelOf(p.X), voxelOf(p.Y), voxelOf(p.Z))] == true
end

-- 파는 공(center, radius)이 보호 칸에 닿으면 공 중심을 위로 올린 값을 돌려준다.
-- 공이 보호 칸 윗면 위로 완전히 떠야 바닥이 안 깎인다. 올린 뒤 또 닿을 수 있어서 몇 번 반복.
function FloorGuard.clampDig(mineId: string, center: Vector3, radius: number): Vector3
	local set = protected[mineId]
	if not set then return center end
	local c = center
	for _ = 1, 4 do
		local top: number? = nil
		local vx0, vx1 = voxelOf(c.X - radius), voxelOf(c.X + radius)
		local vy0, vy1 = voxelOf(c.Y - radius), voxelOf(c.Y + radius)
		local vz0, vz1 = voxelOf(c.Z - radius), voxelOf(c.Z + radius)
		for vx = vx0, vx1 do
			for vz = vz0, vz1 do
				for vy = vy0, vy1 do
					if set[key(vx, vy, vz)] then
						-- 공과 칸 상자가 실제로 겹치는지 (가장 가까운 점까지 거리)
						local lo = Vector3.new(vx, vy, vz) * VOXEL
						local hi = lo + Vector3.new(VOXEL, VOXEL, VOXEL)
						local near = Vector3.new(math.clamp(c.X, lo.X, hi.X), math.clamp(c.Y, lo.Y, hi.Y), math.clamp(c.Z, lo.Z, hi.Z))
						if (near - c).Magnitude < radius then
							local t = hi.Y
							if not top or t > top then top = t end
						end
					end
				end
			end
		end
		if not top then return c end
		c = Vector3.new(c.X, top + radius, c.Z)
	end
	return c
end

return FloorGuard
