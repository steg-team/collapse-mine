--[[
	시작 지점(허브)을 둘러싸는 절벽 링 + 보이지 않는 경계벽 (Studio 명령창에서 실행)

	허브 주변이 낭떠러지라 밖으로 떨어지지 않게, 광장·상점·스폰을 감싸는 분지 모양으로
	절벽을 지형으로 쌓는다. 절벽을 기어 올라가도 밖으로 못 나가도록 꼭대기에 투명한 벽을 둔다.

	분지 안쪽 경계는 둥근 사각형(초타원)이다.
	  CENTER  분지 중심 (y=0 바닥)
	  HALF_X / HALF_Z  안쪽 반폭·반길이
	  THICK   절벽 두께, HEIGHT 안쪽 벽 높이(평균)

	광산 입구는 이 절벽 벽에 tools/build_cave_entrance.luau 로 뚫는다 (이 스크립트를 먼저 실행).
	같은 설정으로 다시 실행하면 지형을 덮어쓰고 경계벽은 다시 만든다.
]]

local CENTER = Vector3.new(0, 0, 90)
local HALF_X = 88
local HALF_Z = 52
local THICK = 40
local HEIGHT = 48
local SEED = 11
local POWER = 4          -- 초타원 지수 (2=타원, 클수록 사각형에 가까움)
local STEP = 4

local CHS = game:GetService("ChangeHistoryService")
local T = workspace.Terrain
local rng = Random.new(SEED)
local rec = CHS:TryBeginRecording("BuildHubCliffs")

-- 경계 판정: r < 1 이면 분지 안, dOut = 안쪽 경계에서 바깥으로 잰 거리(근사)
local function shape(x: number, z: number)
	local dx, dz = x - CENTER.X, z - CENTER.Z
	local s = math.abs(dx / HALF_X) ^ POWER + math.abs(dz / HALF_Z) ^ POWER
	local r = s ^ (1 / POWER)
	local len = math.sqrt(dx * dx + dz * dz)
	local dOut = (r > 0) and len * (1 - 1 / r) or -math.huge
	return r, dOut
end

local ops = 0
local function tick() ops += 1 if ops % 40 == 0 then task.wait() end end

-- 1) 절벽 기둥 ---------------------------------------------------------------
local minX, maxX = CENTER.X - HALF_X - THICK - 8, CENTER.X + HALF_X + THICK + 8
local minZ, maxZ = CENTER.Z - HALF_Z - THICK - 8, CENTER.Z + HALF_Z + THICK + 8
for x = minX, maxX, STEP do
	for z = minZ, maxZ, STEP do
		local r, dOut = shape(x, z)
		if r >= 1 and dOut <= THICK then
			local n = math.noise(x / 26, z / 26, SEED) * 10 + math.noise(x / 8, z / 8, SEED + 3) * 3
			local h = HEIGHT + n
			h = math.min(h, 10 + (THICK - dOut) * 2.4) -- 바깥쪽은 비탈
			h = math.max(h, 8)
			T:FillBlock(CFrame.new(x, h / 2 - 6, z), Vector3.new(STEP, h + 12, STEP), Enum.Material.Rock); tick()
			T:FillBlock(CFrame.new(x, h - 0.5, z), Vector3.new(STEP, 3, STEP), Enum.Material.Grass); tick()
		end
	end
end

-- 2) 안쪽 벽 면 다듬기: 튀어나온 바위, 판암 띠 ---------------------------------
local function boundaryPoint(t: number)
	-- 경계 위의 점 (각도 t)
	local c, s = math.cos(t), math.sin(t)
	local k = (math.abs(c / HALF_X) ^ POWER + math.abs(s / HALF_Z) ^ POWER) ^ (-1 / POWER)
	return CENTER.X + c * k, CENTER.Z + s * k, c, s
end
for i = 1, 160 do
	local t = rng:NextNumber(0, math.pi * 2)
	local bx, bz, c, s = boundaryPoint(t)
	local out = rng:NextNumber(0, 3)
	local y = rng:NextNumber(3, HEIGHT - 4)
	local mat = (rng:NextNumber() < 0.25) and Enum.Material.Slate or Enum.Material.Rock
	T:FillBall(Vector3.new(bx + c * out, y, bz + s * out), rng:NextNumber(4, 8), mat); tick()
end

-- 3) 분지 바닥 정리: 안쪽에 남은 지형 덩어리 제거 + 평평한 잔디 ------------------
for x = minX, maxX, STEP do
	for z = minZ, maxZ, STEP do
		local r, dOut = shape(x, z)
		if r < 1 and dOut < -6 then
			T:FillBlock(CFrame.new(x, 40, z), Vector3.new(STEP, 80, STEP), Enum.Material.Air); tick()
			T:FillBlock(CFrame.new(x, -2, z), Vector3.new(STEP, 4, STEP), Enum.Material.Grass); tick()
		end
	end
end

-- 4) 보이지 않는 경계벽 (절벽 꼭대기 바깥쪽) -------------------------------------
local hub = workspace.CollapseMine.Hub
local oldB = hub:FindFirstChild("Boundary")
if oldB then oldB:Destroy() end
local boundary = Instance.new("Folder")
boundary.Name = "Boundary"
local SEG = 72
local pts = {}
for i = 0, SEG - 1 do
	local t = i / SEG * math.pi * 2
	local bx, bz, c, s = boundaryPoint(t)
	-- 동굴 입구(깊이 약 34)보다 뒤에 와야 입구 안으로 걸어 들어갈 수 있다
	local d = THICK * 0.92
	table.insert(pts, Vector3.new(bx + c * d, 0, bz + s * d))
end
for i = 1, SEG do
	local a, b = pts[i], pts[i % SEG + 1]
	local mid = (a + b) / 2
	local w = Instance.new("Part")
	w.Name = "Wall"
	-- lookAt은 파트의 앞(-Z)을 진행 방향에 맞추므로 길이는 Z축
	w.Size = Vector3.new(2, 300, (b - a).Magnitude + 2)
	w.CFrame = CFrame.lookAt(mid + Vector3.new(0, 150, 0), mid + Vector3.new(0, 150, 0) + (b - a).Unit)
	w.Anchored, w.CanCollide, w.CanQuery, w.CanTouch = true, true, false, false
	w.Transparency = 1
	w.Parent = boundary
end
boundary.Parent = hub

if rec then CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
print(("[HubCliffs] 완료: 지형 작업 %d회, 경계벽 %d개"):format(ops, SEG))
