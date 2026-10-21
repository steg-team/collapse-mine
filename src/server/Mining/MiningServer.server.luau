local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local ev = RS:WaitForChild("Remotes"):WaitForChild("MineHit")
local Terrain = workspace.Terrain
local Ores = workspace:WaitForChild("CollapseMine"):WaitForChild("Ores")

local REACH = 14          -- 캐릭터에서 이 거리 안만 캘 수 있음
local COOLDOWN = 0.3
local SURFACE_Y = -4      -- 이보다 위(지표·광장)는 못 팜
local lastHit = {}

Players.PlayerAdded:Connect(function(plr)
	local ls = Instance.new("Folder"); ls.Name = "leaderstats"; ls.Parent = plr
	local coins = Instance.new("IntValue"); coins.Name = "Coins"; coins.Parent = ls
end)
Players.PlayerRemoving:Connect(function(plr) lastHit[plr] = nil end)

local function layerRadius(y)
	-- 깊을수록 단단해서 한 번에 파이는 양이 줄어듦
	if y > -24 then return 3.4 elseif y > -48 then return 3.0 elseif y > -72 then return 2.6 elseif y > -96 then return 2.2 end
	return 1.9
end

local function swing(tool)
	local a = Instance.new("StringValue"); a.Name = "toolanim"; a.Value = "Slash"; a.Parent = tool
	game:GetService("Debris"):AddItem(a, 0.2)
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
	if typeof(target) == "Instance" and target:IsA("BasePart") and target:IsDescendantOf(Ores) then
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

	-- 지형
	if target == Terrain and hitPos.Y < SURFACE_Y then
		Terrain:FillBall(hitPos, layerRadius(hitPos.Y), Enum.Material.Air)
	end
end)
