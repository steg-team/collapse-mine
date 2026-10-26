-- 허브 ↔ 광산 이동
--   허브 포탈 (태그 "MinePortal", 속성 MineId) 을 밟으면 → 해당 광산 입구 방
--   광산 출구 발판 (태그 "MineExit", 속성 MineId) 을 밟으면 → 그 광산 스테이지의 허브 스폰
--   스테이지마다 허브가 따로 있다 (Mines 설정의 hub = Workspace 폴더 이름, D-019)
--   스테이지 사이는 🗺️ 광산 지도 → Remotes.StageTravel → 그 스테이지 허브 스폰 (D-042, 광산 안에서는 못 씀)
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

-- 광산 지도로 스테이지 이동 (D-042): 클라이언트 🗺️ 지도에서 고른 스테이지의 허브 스폰으로.
-- 클라이언트가 보낸 건 광산 id 하나뿐이고, 갈 수 있는지는 전부 서버가 다시 본다 (보안 규칙)
-- 돌려주는 값: { ok: boolean, message: string }
local remotes = RS:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = RS
end
local travelRemote = remotes:FindFirstChild("StageTravel") :: RemoteFunction?
if not travelRemote then
	local f = Instance.new("RemoteFunction")
	f.Name = "StageTravel"
	f.Parent = remotes
	travelRemote = f
end
local lastMapTravel: { [Player]: number } = {}
Players.PlayerRemoving:Connect(function(plr) lastMapTravel[plr] = nil end)

local PICKAXE_NAMES = { "나무 곡괭이", "돌 곡괭이", "철 곡괭이", "금 곡괭이", "최상위 곡괭이" } -- 안내 문구용 (B의 PICKAXES 이름과 같게)

;(travelRemote :: RemoteFunction).OnServerInvoke = function(plr: Player, mineId: any)
	if typeof(mineId) ~= "string" then return { ok = false, message = "잘못된 요청이에요" } end
	local mine = Mines.get(mineId)
	if not mine then return { ok = false, message = "아직 갈 수 없는 광산이에요" } end
	local char = plr.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not root or not hum or hum.Health <= 0 then return { ok = false, message = "잠시 후 다시 해 주세요" } end
	-- 광산 안에서는 못 씀: 붕괴 때 지도로 빠져나가면 탈출 판정(D-013)이 무너진다
	if Mines.findAreaAt(root.Position) then
		return { ok = false, message = "광산 안에서는 지도를 쓸 수 없어요. 출구로 나가세요" }
	end
	local tier = tonumber(plr:GetAttribute("PickaxeTier")) or 1
	if tier < mine.requiredPickaxe then
		local need = PICKAXE_NAMES[mine.requiredPickaxe] or (`곡괭이 {mine.requiredPickaxe}단계`)
		return { ok = false, message = `{need}가 필요해요` }
	end
	local now = os.clock()
	if lastMapTravel[plr] and now - lastMapTravel[plr] < Mines.STAGE_MAP.cooldown then
		return { ok = false, message = "잠시 후 다시 해 주세요" }
	end
	local cf = hubSpawn(mineId)
	if not cf then return { ok = false, message = "이동할 곳을 찾지 못했어요" } end
	lastMapTravel[plr] = now
	lastTravel[plr] = now -- 도착하자마자 포탈·출구 판정이 겹치지 않게
	root.CFrame = cf
	return { ok = true, message = `{mine.name}(으)로 왔어요` }
end

for _, p in CS:GetTagged("MinePortal") do bindPortal(p) end
CS:GetInstanceAddedSignal("MinePortal"):Connect(bindPortal)
for _, p in CS:GetTagged("MineExit") do bindExit(p) end
CS:GetInstanceAddedSignal("MineExit"):Connect(bindExit)
