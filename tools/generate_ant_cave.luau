--[[
	개미굴 동굴 맵 생성기 (Studio 명령창 / 플러그인에서 실행, Rojo 동기화 대상 아님)

	하는 일
	  1) 광산 영역(반경 88)을 지층별 지형으로 다시 채움
	  2) 입구 경사로 → 중앙 허브 방 + 주변 방 3개 → 나선형 대각선 굴 5갈래를 파냄
	  3) 굴 중간 옆방, 갈래 끝 막다른 방을 만들고 광석(Ores)과 방 구역(Rooms)을 배치
	  4) workspace.CollapseMine.Lights의 램프를 방·굴에 재배치

	필요한 것
	  workspace.CollapseMine.AntNestInfo (Configuration)
	    - L1~L5_Hardness 속성 (지층별 경도)
	  workspace.CollapseMine.Lights (램프 파트 1개 이상)

	SEED만 바꾸면 다른 모양이 나옴. 실행 전 Ctrl+S 권장 (Ctrl+Z로 되돌릴 수 있음)
]]

local SEED = 5

local CHS = game:GetService("ChangeHistoryService")
local rec = CHS:TryBeginRecording("AntCave_Generate")
local T = workspace.Terrain
local cm = workspace.CollapseMine
local cfg = cm.AntNestInfo
local AIR = Enum.Material.Air
local rng = Random.new(SEED)
cfg:SetAttribute("Seed", SEED)
cfg:SetAttribute("Type", "TerrainCave")

-- 1) 지층별로 다시 채우기 ------------------------------------------------
local R = 88
local function band(top, bottom, mat)
	T:FillCylinder(CFrame.new(0, (top + bottom) / 2, 0), top - bottom, R, mat)
end
band(-152, -266, Enum.Material.Air)
band(-4, -24, Enum.Material.Ground)      -- 1 흙층
band(-24, -48, Enum.Material.Slate)      -- 2 바위층
band(-48, -72, Enum.Material.Rock)       -- 3 수정층
band(-72, -96, Enum.Material.Basalt)     -- 4 심층암
band(-96, -152, Enum.Material.CrackedLava) -- 5 용암층
T:FillCylinder(CFrame.new(0, -2, 0), 4, 52, Enum.Material.Grass)

-- 공용 -------------------------------------------------------------------
local lampSpots, ops = {}, 0
local function tick() ops += 1 if ops % 20 == 0 then task.wait() end end
local function ball(p, r) T:FillBall(p, r, AIR); tick() end

local function corridor(a, b)
	local d = (b - a).Magnitude
	local n = math.max(1, math.ceil(d / 2))
	for i = 0, n do
		ball(a:Lerp(b, i / n) + Vector3.new(0, 4.5, 0), 5)
	end
end

local ORE = {
	{name = "Copper",   value = 5,   color = Color3.fromRGB(200, 115, 60),  mat = Enum.Material.Metal},
	{name = "Iron",     value = 12,  color = Color3.fromRGB(190, 185, 180), mat = Enum.Material.Metal},
	{name = "Crystal",  value = 30,  color = Color3.fromRGB(110, 200, 255), mat = Enum.Material.Neon},
	{name = "Gold",     value = 70,  color = Color3.fromRGB(255, 200, 60),  mat = Enum.Material.Foil},
	{name = "Obsidian", value = 150, color = Color3.fromRGB(150, 60, 210),  mat = Enum.Material.Glass},
}
local function layerAt(y)
	if y > -24 then return 1 elseif y > -48 then return 2 elseif y > -72 then return 3 elseif y > -96 then return 4 end
	return 5
end

local oresF = cm:FindFirstChild("Ores") or Instance.new("Folder")
oresF.Name = "Ores"; oresF:ClearAllChildren(); oresF.Parent = cm
local roomsF = cm:FindFirstChild("Rooms") or Instance.new("Folder")
roomsF.Name = "Rooms"; roomsF:ClearAllChildren(); roomsF.Parent = cm

local function ores(c, Rr, count, mult)
	for _ = 1, count do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = Rr - rng:NextNumber(0.5, 2)
		local pos = c + Vector3.new(math.cos(a) * d, rng:NextNumber(1, 6), math.sin(a) * d)
		local L = layerAt(pos.Y)
		local o = ORE[L]
		local p = Instance.new("Part")
		p.Name = o.name
		local s = rng:NextNumber(2.5, 4.5)
		p.Size = Vector3.new(s, s * rng:NextNumber(0.7, 1.3), s * rng:NextNumber(0.7, 1.3))
		p.CFrame = CFrame.new(pos) * CFrame.Angles(rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28))
		p.Anchored = true
		p.Material, p.Color = o.mat, o.color
		p:SetAttribute("Vein", true)
		p:SetAttribute("Ore", o.name)
		p:SetAttribute("OreValue", o.value * mult)
		p:SetAttribute("Layer", L)
		p:SetAttribute("Hardness", cfg:GetAttribute("L" .. L .. "_Hardness"))
		p.Parent = oresF
	end
end

-- 방: 바닥이 평평한 원통 + 낮은 돔. Room 파트(투명)에 붕괴 위험도 저장
local function room(c, Rr, kind)
	T:FillCylinder(CFrame.new(c + Vector3.new(0, 5, 0)), 10, Rr, AIR); tick()
	T:FillCylinder(CFrame.new(c + Vector3.new(0, 11, 0)), 4, Rr * 0.65, AIR); tick()
	local frac = math.clamp(-c.Y / 150, 0, 1)
	local risk = (kind == "Hub") and 0 or (0.05 + 0.25 * frac + (kind == "End" and 0.1 or 0))
	local m = Instance.new("Part")
	m.Name = "Room_" .. kind
	m.Size = Vector3.new(Rr * 2, 12, Rr * 2)
	m.Position = c + Vector3.new(0, 6, 0)
	m.Anchored, m.CanCollide, m.CanQuery, m.Transparency = true, false, false, 1
	m:SetAttribute("Room", true)
	m:SetAttribute("RoomType", kind)
	m:SetAttribute("Layer", layerAt(c.Y))
	m:SetAttribute("CollapseRisk", math.floor(risk * 100) / 100)
	m.Parent = roomsF
	if kind == "Side" then ores(c, Rr, rng:NextInteger(3, 5), 1)
	elseif kind == "End" then ores(c, Rr, rng:NextInteger(6, 8), 2)
	elseif kind == "Hub" then ores(c, Rr, 2, 1) end
	table.insert(lampSpots, c + Vector3.new(0, 9, 0))
end

-- 2) 입구 → 허브 방 무리 -------------------------------------------------
local A = Vector3.new(0, -20, 0)
corridor(Vector3.new(0, -2.5, 54), Vector3.new(0, -20, 12)) -- 스폰 앞 입구 경사로
room(A, 14, "Hub")
local hubs = {{c = A}}
for i, ang in ipairs({math.rad(100), math.rad(220), math.rad(340)}) do
	local c = Vector3.new(math.cos(ang) * 27, -20 - 7 * i, math.sin(ang) * 27)
	corridor(A, c)
	room(c, 10, "Hub")
	table.insert(hubs, {c = c})
end
corridor(hubs[2].c, hubs[3].c)

-- 3) 나선형 대각선 굴 5갈래 (경사 약 31도, 걸어서 오르내림 가능) ---------
local depths = {-144, -138, -118, -96, -76}
for i = #depths, 2, -1 do local j = rng:NextInteger(1, i); depths[i], depths[j] = depths[j], depths[i] end
for b = 1, 5 do
	local a0 = math.rad(18 + (b - 1) * 72)
	local axis = Vector3.new(math.cos(a0) * 41, 0, math.sin(a0) * 41)
	local hr = rng:NextNumber(14, 17)
	local phi = a0 + math.pi
	local dir = (rng:NextNumber() < 0.5) and 1 or -1
	local S2 = axis + Vector3.new(math.cos(phi) * hr, 0, math.sin(phi) * hr)
	local best, bd = nil, math.huge
	for _, h in ipairs(hubs) do
		local d = (Vector3.new(h.c.X, 0, h.c.Z) - S2).Magnitude
		if d < bd then best, bd = h, d end
	end
	local P = Vector3.new(S2.X, best.c.Y - math.min(10, bd * 0.45), S2.Z)
	corridor(best.c, P)
	local lastRoomY = P.Y
	local gap = rng:NextNumber(20, 26)
	local step = 0
	while P.Y > depths[b] do
		phi += dir * 2.5 / hr
		local np = axis + Vector3.new(math.cos(phi) * hr, 0, math.sin(phi) * hr)
		P = Vector3.new(np.X, P.Y - 1.5, np.Z)
		ball(P + Vector3.new(0, 4.5, 0), 5)
		step += 1
		if step % 30 == 0 then table.insert(lampSpots, P + Vector3.new(0, 8, 0)) end
		local u = Vector3.new(math.cos(phi), 0, math.sin(phi))
		local radial = Vector3.new(math.cos(a0), 0, math.sin(a0))
		if lastRoomY - P.Y >= gap and u:Dot(radial) > 0.55 and P.Y > depths[b] + 10 then
			local c = P + u * 15
			corridor(P, c)
			room(c, rng:NextNumber(8, 10), "Side")
			lastRoomY = P.Y
			gap = rng:NextNumber(20, 26)
		end
	end
	local u = Vector3.new(math.cos(phi), 0, math.sin(phi))
	local c = P + u * 8
	corridor(P, c)
	room(c, 11, "End")
end

-- 4) 램프 배치 -----------------------------------------------------------
local lamps = {}
for _, p in ipairs(cm.Lights:GetChildren()) do if p:IsA("BasePart") then table.insert(lamps, p) end end
local template = lamps[1]
for i, pos in ipairs(lampSpots) do
	local lp = lamps[i]
	if not lp then lp = template:Clone(); lp.Parent = cm.Lights end
	lp.Position = pos
	local pl = lp:FindFirstChildOfClass("PointLight")
	if pl then pl.Range = 30 end
end
for i = #lampSpots + 1, #lamps do lamps[i]:Destroy() end

if rec then CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
print(("[AntCave] 완료: 광석 %d개, 방 %d개, 램프 %d개"):format(#oresF:GetChildren(), #roomsF:GetChildren(), #lampSpots))
