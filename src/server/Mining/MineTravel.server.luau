-- 허브 ↔ 광산 이동
--   허브 포탈 (태그 "MinePortal", 속성 MineId) 을 밟으면 → 해당 광산 입구 방
--   광산 출구 발판 (태그 "MineExit", 속성 MineId) 을 밟으면 → 그 광산 스테이지의 허브 스폰
--   스테이지마다 허브가 따로 있다 (Mines 설정의 hub = Workspace 폴더 이름, D-019)
-- 곡괭이 등급이 모자라면 들어가지 못한다 (Mines 설정의 requiredPickaxe).

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local CS = game:GetService("CollectionService")

local Shared = RS:WaitForChild("Shared")
local Mines = require(Shared:WaitForChild("Config"):WaitForChild("Mines"))
local Events = require(Shared:WaitForChild("Events"))
local EventBus = require(Shared:WaitForChild("EventBus"))

local COOLDOWN = 2
local lastTravel = {}

Players.PlayerRemoving:Connect(function(plr) lastTravel[plr] = nil end)

local function playerFromHit(hit: BasePart)
	local char = hit:FindFirstAncestorOfClass("Model")
	local plr = char and Players:GetPlayerFromCharacter(char)
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if plr and root then return plr, root end
	return nil, nil
end

local function ready(plr)
	local now = os.clock()
	if lastTravel[plr] and now - lastTravel[plr] < COOLDOWN then return false end
	lastTravel[plr] = now
	return true
end

-- 광산 스테이지의 허브 스폰. 설정에 hub가 없거나 못 찾으면 기본 허브
local function hubSpawn(mineId: string?): CFrame?
	local mine = mineId and Mines.get(mineId)
	local folder = (mine and mine.hub and workspace:FindFirstChild(mine.hub)) or workspace:FindFirstChild("CollapseMine")
	local hub = folder and folder:FindFirstChild("Hub")
	local sp = hub and hub:FindFirstChild("MineSpawn")
	return sp and (sp.CFrame + Vector3.new(0, 4, 0)) or nil
end

local function mineEntrance(id: string): CFrame?
	local folder = workspace:FindFirstChild("Mines") and workspace.Mines:FindFirstChild(id)
	local e = folder and folder:FindFirstChild("Entrance")
	return e and (e.CFrame + Vector3.new(0, 4, 0)) or nil
end

local function bindPortal(part: BasePart)
	part.Touched:Connect(function(hit)
		local plr, root = playerFromHit(hit)
		if not plr or not ready(plr) then return end
		local id = part:GetAttribute("MineId")
		local mine = id and Mines.get(id)
		if not mine then return end
		if (plr:GetAttribute("PickaxeTier") or 1) < mine.requiredPickaxe then
			-- TODO(C·UI): 잠김 안내 표시
			return
		end
		local cf = mineEntrance(id)
		if cf then
			root.CFrame = cf
			-- (player, mineId) — Events.luau 계약. C의 튜토리얼·퀘스트
			EventBus.Fire(Events.StageEntered, plr, id)
		end
	end)
end

local function bindExit(part: BasePart)
	part.Touched:Connect(function(hit)
		local plr, root = playerFromHit(hit)
		if not plr or not ready(plr) then return end
		local cf = hubSpawn(part:GetAttribute("MineId"))
		if cf then root.CFrame = cf end
	end)
end

for _, p in CS:GetTagged("MinePortal") do bindPortal(p) end
CS:GetInstanceAddedSignal("MinePortal"):Connect(bindPortal)
for _, p in CS:GetTagged("MineExit") do bindExit(p) end
CS:GetInstanceAddedSignal("MineExit"):Connect(bindExit)
