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
	if typeof(target) == "Instance" and target:IsA("BasePart") and CS:HasTag(target, "Ore") then
		if (target.Position - root.Position).Magnitude > REACH + 4 then return end
		local hp = target:GetAttribute("HP") or target:GetAttribute("Hardness") or 1
		hp -= 1
		if hp <= 0 then
			plr.leaderstats.Coins.Value += target:GetAttribute("OreValue") or 0
			target:Destroy()
		else
			target:SetAttribute("HP", hp)
			target.Transparency = math.min(0.6, target.Transparency + 0.1)
		end
		return
	end

	-- 지형: 광산 영역 안, 지표 아래만
	if target == Terrain then
		local mine = Mines.findAt(hitPos)
		if not mine or hitPos.Y > mine.top - 1 then return end
		local _, li = Mines.layerAt(mine, hitPos.Y)
		Terrain:FillBall(hitPos, digRadius(li), Enum.Material.Air)
	end
end)
