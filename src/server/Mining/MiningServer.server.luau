-- 채굴 판정 (모든 광산 공통). 광산 범위·지층은 Shared.Config.Mines 설정을 따른다.

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local CS = game:GetService("CollectionService")
local Debris = game:GetService("Debris")

local Shared = RS:WaitForChild("Shared")
local Mines = require(Shared:WaitForChild("Config"):WaitForChild("Mines"))
local Events = require(Shared:WaitForChild("Events"))
local EventBus = require(Shared:WaitForChild("EventBus"))
local ev = RS:WaitForChild("Remotes"):WaitForChild("MineHit")
local Terrain = workspace.Terrain

local REACH = 14       -- 캐릭터에서 이 거리 안만 캘 수 있음
local COOLDOWN = 0.3
local SURFACE_CRUST = 4 -- 지표(광산 top) 아래 이만큼은 절대 안 파임 = 지형 한 칸
local lastHit = {}

-- 이 등급 이상을 캐면 LegendaryFound (C가 서버 전체 공지)
local LEGENDARY_GRADES = { ["전설"] = true, ["신화"] = true, ["???"] = true }

local function setupPlayer(plr: Player)
	if plr:FindFirstChild("leaderstats") then return end
	local ls = Instance.new("Folder"); ls.Name = "leaderstats"; ls.Parent = plr
	local coins = Instance.new("IntValue"); coins.Name = "Coins"; coins.Parent = ls
	-- 곡괭이 등급 (임시: 업그레이드·저장은 경제 담당이 붙일 예정, PickaxeUpgraded 이벤트)
	if plr:GetAttribute("PickaxeTier") == nil then plr:SetAttribute("PickaxeTier", 1) end
end

Players.PlayerAdded:Connect(setupPlayer)
-- 스크립트보다 먼저 들어온 플레이어 (Studio 테스트에서 흔함)
for _, plr in Players:GetPlayers() do setupPlayer(plr) end
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

ev.OnServerEvent:Connect(function(plr, target, hitPos)
	if typeof(hitPos) ~= "Vector3" then return end
	local char = plr.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local tool = char and char:FindFirstChildOfClass("Tool")
	if not root or not tool or tool.Name ~= "Pickaxe" then return end
	local now = os.clock()
	if lastHit[plr] and now - lastHit[plr] < COOLDOWN then return end
	lastHit[plr] = now
	if (hitPos - root.Position).Magnitude > REACH then return end
	swing(tool)

	-- 광석: 경도(Hardness)만큼 때려야 깨짐
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
		-- 땅 속에 묻혀 있던 광석은 빛·반짝임을 꺼 둔 상태 (생성기). 파서 처음 맞히면 켜서 "찾았다" 느낌
		if ore:GetAttribute("Buried") then
			ore:SetAttribute("Buried", nil)
			for _, d in ore:GetDescendants() do
				if d:IsA("Light") or d:IsA("ParticleEmitter") or d:IsA("Highlight") or d:IsA("Fire") then
					d.Enabled = true
				end
			end
		end
		local maxHp = ore:GetAttribute("Hardness") or 1
		local hp = ore:GetAttribute("HP") or maxHp
		hp -= 1
		if hp <= 0 then
			plr.leaderstats.Coins.Value += ore:GetAttribute("OreValue") or 0
			if LEGENDARY_GRADES[ore:GetAttribute("Grade")] then
				local mine = Mines.findAt(orePos)
				local stageId = mine and mine.order or 0
				local depth = mine and math.max(0, math.floor(mine.top - orePos.Y)) or 0
				-- (player, oreId, stageId, depth) — Events.luau 계약
				EventBus.Fire(Events.LegendaryFound, plr, ore:GetAttribute("Ore") or ore.Name, stageId, depth)
			end
			ore:Destroy()
		else
			ore:SetAttribute("HP", hp)
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
		local _, li = Mines.layerAt(mine, hitPos.Y)
		local r = digRadius(li)
		-- 파내는 공이 지표·바닥을 뚫지 않게 공 중심을 안쪽으로 당긴다.
		-- 굴 천장이 지표에서 몇 스터드밖에 안 돼서, 위를 파면 공 윗부분이 잔디까지 뚫고 밖으로 탈출할 수 있었다.
		-- 지형 칸이 4스터드라 공 끝이 칸 경계(top - SURFACE_CRUST)를 넘지 않아야 위 칸이 남는다.
		local center = Vector3.new(
			hitPos.X,
			math.clamp(hitPos.Y, mine.bottom + r, mine.top - SURFACE_CRUST - r),
			hitPos.Z
		)
		Terrain:FillBall(center, r, Enum.Material.Air)
	end
end)
