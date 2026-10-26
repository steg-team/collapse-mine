-- 채굴 판정 (모든 광산 공통). 광산 범위·지층은 Shared.Config.Mines 설정을 따른다.

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local CS = game:GetService("CollectionService")
local Debris = game:GetService("Debris")

local Shared = RS:WaitForChild("Shared")
local Mines = require(Shared:WaitForChild("Config"):WaitForChild("Mines"))
local Pickaxe = require(Shared:WaitForChild("Config"):WaitForChild("Pickaxe"))
local Events = require(Shared:WaitForChild("Events"))
local EventBus = require(Shared:WaitForChild("EventBus"))
local FloorGuard = require(script.Parent:WaitForChild("FloorGuard"))
local OreFactory = require(script.Parent:WaitForChild("OreFactory"))
local RareVeins = require(script.Parent:WaitForChild("RareVeins"))
local MineSounds = require(script.Parent:WaitForChild("MineSounds"))
local ev = RS:WaitForChild("Remotes"):WaitForChild("MineHit")
local Terrain = workspace.Terrain

local REACH = 14       -- 캐릭터에서 이 거리 안만 캘 수 있음
-- 휘두르는 간격·데미지는 곡괭이 단계·강화·채굴 속도 배수로 정해진다 (Config/Pickaxe.luau, D-026)
local SURFACE_CRUST = 4 -- 지표(광산 top) 아래 이만큼은 절대 안 파임 = 지형 한 칸
local lastHit = {}
local rng = Random.new()

local terrainOnly = RaycastParams.new()
terrainOnly.FilterType = Enum.RaycastFilterType.Include
terrainOnly.FilterDescendantsInstances = { workspace.Terrain }

-- 이 등급 이상을 캐면 LegendaryFound (C가 서버 전체 공지)
local LEGENDARY_GRADES = { ["전설"] = true, ["신화"] = true, ["???"] = true }

-- 붕괴까지 남은 시간 조회 (C의 Collapse.GetRemainingTime). C 모듈이 Remotes 등을 기다리느라 늦게 뜰 수 있어서
-- 채굴이 그걸 기다리며 멈추지 않게 따로 불러 둔다. 못 불러온 동안은 "경보 아님"으로 친다
local Collapse = nil
task.spawn(function()
	local social = SSS:WaitForChild("Server"):WaitForChild("Social", 30)
	local mod = social and social:WaitForChild("Collapse", 30)
	if mod then
		local ok, m = pcall(require, mod)
		if ok then Collapse = m else warn("[MiningServer] Collapse 불러오기 실패: " .. tostring(m)) end
	end
end)

-- 압력 등급 (Mines.PRESSURE, D-025): 붕괴 직전 → 초고압, 경보 중이거나 깊은 곳 → 고압, 나머지 상압
local function pressureAt(mine: Mines.Mine?, y: number): string
	if not mine then return "Low" end
	local remaining = Collapse and Collapse.GetRemainingTime(mine.id)
	if remaining and remaining <= Mines.PRESSURE.extremeSeconds then return "Extreme" end
	local depthRatio = (mine.top - y) / (mine.top - mine.bottom)
	if remaining or depthRatio >= Mines.PRESSURE.highDepth then return "High" end
	return "Low"
end

-- 무게 배수 (Mines.ORE_WEIGHT). 끝방처럼 가치를 높여 박은 광석은 그 배수만큼 무겁게
local function weightOf(mine: Mines.Mine?, ore: Instance): number
	local w = rng:NextNumber(Mines.ORE_WEIGHT.Min, Mines.ORE_WEIGHT.Max)
	if mine then
		local name = ore:GetAttribute("Ore")
		for _, o in mine.ores do
			if o.name == name and o.value > 0 then
				w *= math.max(1, (ore:GetAttribute("OreValue") or o.value) / o.value)
				break
			end
		end
	end
	return math.floor(w * 100 + 0.5) / 100
end

-- 코인 칸(leaderstats)과 곡괭이 단계 속성은 B(PlayerData)가 만든다 (#50). 불러오기 전엔 속성이 nil이라 Pickaxe.stats가 1로 읽는다

-- 서버가 켜질 때(지형이 원래 모양일 때) 광산마다 길바닥을 훑어 둔다
for _, m in Mines.list do
	task.spawn(FloorGuard.build, m)
end

Players.PlayerRemoving:Connect(function(plr) lastHit[plr] = nil end)

-- 지층이 깊을수록 단단해서 한 번에 파이는 양이 줄어듦
-- 지형 칸(voxel)이 4스터드라 반경 4 아래로는 거의 안 파인다 (임시값)
local function digRadius(layerIndex: number)
	return math.max(3.8, 5.2 - (layerIndex - 1) * 0.7)
end

local function swing(tool)
	local a = Instance.new("StringValue"); a.Name = "toolanim"; a.Value = "Slash"; a.Parent = tool
	Debris:AddItem(a, 0.2)
end

-- 파다가 발견: 지형을 한 번 팔 때마다 확률로 희귀 이상 광물이 판 자리 벽에 드러난다 (Mines 설정 digFinds).
-- 미리 묻어 두지 않아서 광산이 바닥나지 않고, 어디를 파든 기회가 같다. 깊을수록 확률이 높다.
-- 확률·광물 뽑기는 서버에서만 (보안 규칙)
local function rollDigFind(mine: Mines.Mine, center: Vector3, r: number, digDir: Vector3)
	local f = mine.digFinds
	if not f then return end
	local t = math.clamp((mine.top - center.Y) / (mine.top - mine.bottom), 0, 1)
	-- 숨은 희귀 광맥 근처면 광맥 확률 (D-036), 밖이면 깊이에 따른 기본 확률
	local veinChance, vein = RareVeins.chanceAt(mine.id, center)
	local chance = veinChance or (f.chance.Min + (f.chance.Max - f.chance.Min) * t)
	if rng:NextNumber() >= chance then return end
	local o = OreFactory.pick(mine, center.Y, true, rng)
	if not o then return end -- 얕아서 나올 수 있는 광물이 없음
	local folder = workspace:FindFirstChild("Mines") and workspace.Mines:FindFirstChild(mine.id)
	local ores = folder and folder:FindFirstChild("Ores")
	if not ores then return end
	task.spawn(function()
		task.wait() -- 방금 판 지형이 레이캐스트에 반영된 뒤
		-- 판 방향의 안쪽 벽, 없으면 바닥
		local dir = if digDir.Magnitude > 0.1 then digDir.Unit else Vector3.new(0, -1, 0)
		local hit = workspace:Raycast(center, dir * (r + 4), terrainOnly)
			or workspace:Raycast(center, Vector3.new(0, -(r + 4), 0), terrainOnly)
		if hit then
			OreFactory.spawn(mine, ores, o, OreFactory.surfaceCFrame(hit), 1, rng, "DigFind")
			MineSounds.rareRevealed(hit.Position) -- 희귀 이상이 드러남 (D-041)
			if vein then RareVeins.consume(mine.id, vein) end -- 광맥에서 나온 것만 광맥을 깎는다
		end
	end)
end

ev.OnServerEvent:Connect(function(plr, target, hitPos)
	if typeof(hitPos) ~= "Vector3" then return end
	local char = plr.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local tool = char and char:FindFirstChildOfClass("Tool")
	if not root or not tool or tool.Name ~= "Pickaxe" then return end
	local stats = Pickaxe.stats(plr)
	local now = os.clock()
	if lastHit[plr] and now - lastHit[plr] < stats.cooldown * Pickaxe.SERVER_TOLERANCE then return end
	lastHit[plr] = now
	if (hitPos - root.Position).Magnitude > REACH then return end
	swing(tool)

	-- 광석: 경도(Hardness) = 파워 1로 깨는 타수. 곡괭이 파워만큼 HP가 깎인다
	-- 광석은 파트 하나(예전 방식)거나 광물 틀 모델(태그·속성이 모델에 있음). 모델이면 맞은 파트에서 모델을 찾는다.
	local ore: Instance? = nil
	if typeof(target) == "Instance" and target:IsA("BasePart") then
		if CS:HasTag(target, "Ore") then
			ore = target
		else
			local m = target:FindFirstAncestorWhichIsA("Model")
			if m and CS:HasTag(m, "Ore") then ore = m end
		end
	end
	if ore then
		local orePos = if ore:IsA("Model") then ore:GetPivot().Position else (ore :: BasePart).Position
		if (orePos - root.Position).Magnitude > REACH + 4 then return end
		local maxHp = ore:GetAttribute("Hardness") or 1
		local hp = ore:GetAttribute("HP") or maxHp
		hp -= stats.power
		if hp <= 1e-6 then
			-- 코인은 여기서 주지 않는다: 가방에 담고(B) 판매소에서 팔 때 들어간다 (D-020). 값 계산도 B
			local mine = Mines.findAt(orePos) or Mines.get(ore:GetAttribute("MineId") or "")
			-- (player, oreId, weight, pressure) — Events.luau 계약
			EventBus.Fire(Events.OreMined, plr, ore:GetAttribute("Ore") or ore.Name, weightOf(mine, ore), pressureAt(mine, orePos.Y))
			MineSounds.oreBreak(orePos)
			if LEGENDARY_GRADES[ore:GetAttribute("Grade")] then
				-- 발견 연출: 팡파르·빛기둥·화면 흔들림 (기획서 "발견 연출", D-041). 공지는 C
				local first = if ore:IsA("Model") then ore:FindFirstChildWhichIsA("BasePart", true) else ore
				MineSounds.legendary(plr, orePos, if first and first:IsA("BasePart") then first.Color else nil)
				local mineId = mine and mine.id or (ore:GetAttribute("MineId") or "")
				local depth = mine and math.max(0, math.floor(mine.top - orePos.Y)) or 0
				-- (player, oreId, mineId: string, depth) — Events.luau 계약 (PR #6에서 stageId → mineId)
				EventBus.Fire(Events.LegendaryFound, plr, ore:GetAttribute("Ore") or ore.Name, mineId, depth)
			end
			ore:Destroy()
		else
			ore:SetAttribute("HP", hp)
			MineSounds.oreHit(orePos)
			if ore:IsA("Model") then
				-- 맞을수록 조금씩 작아져서 "깎이는" 느낌 (처음 크기의 최대 30%까지)
				local base = ore:GetAttribute("BaseScale")
				if base == nil then base = ore:GetScale(); ore:SetAttribute("BaseScale", base) end
				ore:ScaleTo(base * (1 - 0.3 * (1 - hp / maxHp)))
			else
				local p = ore :: BasePart
				p.Transparency = math.min(0.6, p.Transparency + 0.1)
			end
		end
		return
	end

	-- 지형: 광산 영역 안, 지표 아래만
	if target == Terrain then
		local mine = Mines.findAt(hitPos)
		if not mine or hitPos.Y > mine.top - 1 then return end
		local layer, li = Mines.layerAt(mine, hitPos.Y)
		local r = digRadius(li) + stats.digBonus
		-- 파내는 공이 지표·바닥을 뚫지 않게 공 중심을 안쪽으로 당긴다.
		-- 굴 천장이 지표에서 몇 스터드밖에 안 돼서, 위를 파면 공 윗부분이 잔디까지 뚫고 밖으로 탈출할 수 있었다.
		-- 지형 칸이 4스터드라 공 끝이 칸 경계(top - SURFACE_CRUST)를 넘지 않아야 위 칸이 남는다.
		local center = Vector3.new(
			hitPos.X,
			math.clamp(hitPos.Y, mine.bottom + r, mine.top - SURFACE_CRUST - r),
			hitPos.Z
		)
		-- 길바닥(굴·방·출구 비탈의 원래 바닥)은 못 파게: 공이 바닥에 닿으면 위로 올림 (FloorGuard)
		-- 바닥 정보를 다 읽기 전(서버 켜진 직후 몇 초)엔 아예 안 파이게
		if not FloorGuard.isReady(mine.id) then return end
		center = FloorGuard.clampDig(mine.id, center, r)
		if center.Y > mine.top - SURFACE_CRUST - r then return end -- 올리다 지표 보호선을 넘으면 포기
		Terrain:FillBall(center, r, Enum.Material.Air)
		MineSounds.terrainHit(hitPos, layer.material) -- 흙은 둔탁, 바위는 맑게 (D-041)
		rollDigFind(mine, center, r, center - root.Position)
	end
end)
