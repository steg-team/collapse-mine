--!strict
-- 광맥 붕괴 이벤트 (C 담당, 기획서 "차별화: 광맥 붕괴 이벤트", D-013)
--
-- 흐름 (광산마다 따로, Config/Mines.luau 의 collapse 설정)
--   대기 ── interval 범위에서 랜덤 ──▶ 경보(warning 초, 카운트다운) ──▶ 붕괴
--                                │                              ├─ 아직 광산 안: 갇힘 → 3초 뒤 허브로
--                                └─ 경보 중 광산에 있던 사람 ────┴─ 이미 나감: 탈출 성공 + 보너스
--
-- 내보내는 이벤트 (Events.luau): CollapseWarning, CollapseOccurred, PlayerEscaped, PlayerTrapped
-- 조회 함수: Collapse.GetRemainingTime(mineId) — A가 압력 등급 계산에 사용
--
-- 시간은 workspace:GetServerTimeNow() 기준. 클라이언트도 같은 시계를 볼 수 있어서 카운트다운 UI를 맞추기 쉽다.

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = RS:WaitForChild("Shared")
local Events = require(Shared:WaitForChild("Events"))
local EventBus = require(Shared:WaitForChild("EventBus"))
local Mines = require(Shared:WaitForChild("Config"):WaitForChild("Mines"))
local Social = require(Shared:WaitForChild("Config"):WaitForChild("Social"))
local Config = Social.Collapse
local Kind = Social.AnnounceKind
local Announcer = require(script.Parent:WaitForChild("Announcer"))

type State = {
	phase: "idle" | "warning",
	collapseAt: number,    -- 다음 붕괴 시각
	warningLen: number,    -- 이번 경보 길이 (테스트 때는 짧게)
	announced: { [number]: boolean }, -- 이번 경보에서 이미 띄운 공지 (30초, 10초 …)
	-- 경보 중 광산에 있었던 플레이어 → 마지막으로 광산 안에서 본 시각
	participants: { [Player]: number },
	-- 경보 중 광산 안에서 죽은 플레이어. 리셋하면 허브에서 부활해 "광산 밖"이 되므로,
	-- 이걸 따로 기록하지 않으면 리셋만으로 탈출 성공 + 최대 보너스를 받는다 (리셋 꼼수)
	diedInside: { [Player]: boolean },
}

local states: { [string]: State } = {}

-- 붕괴 주기를 뽑을 난수 (매번 같은 패턴이면 플레이어가 외워버리므로 랜덤)
local rng = Random.new()

-- 광산 설정의 범위(interval) 안에서 이번 주기 길이를 뽑는다
local function rollInterval(mine: Mines.Mine): number
	return rng:NextNumber(mine.collapse.interval.Min, mine.collapse.interval.Max)
end

-- 클라이언트 카운트다운 UI용: ReplicatedStorage.CollapseState 의 속성 <광산id> = 붕괴 시각 (경보 중일 때만, 아니면 nil)
local stateFolder = RS:FindFirstChild("CollapseState") or Instance.new("Folder")
stateFolder.Name = "CollapseState"
stateFolder.Parent = RS

local function now(): number
	return workspace:GetServerTimeNow()
end

local function rootOf(player: Player): BasePart?
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function isInside(player: Player, mine: Mines.Mine): boolean
	local root = rootOf(player)
	-- findAreaAt: 출구 비탈 굴(지표 위)까지 광산 안으로 본다. 출구 게이트에 닿아 허브로 가야 탈출
	return root ~= nil and Mines.findAreaAt(root.Position) == mine
end

-- 갇힌 플레이어를 보낼 허브 스폰. 스테이지마다 허브가 따로 있다 (#17, Mines 설정의 hub = 허브 폴더 이름)
-- hub 칸이 아직 없으면 기본 허브(Workspace.CollapseMine)
local DEFAULT_HUB = "CollapseMine"
local function hubSpawn(mine: Mines.Mine): CFrame?
	local hubName = (mine :: any).hub or DEFAULT_HUB
	local root = workspace:FindFirstChild(hubName) or workspace:FindFirstChild(DEFAULT_HUB)
	local hub = root and root:FindFirstChild("Hub")
	local sp = hub and hub:FindFirstChild("MineSpawn")
	return if sp and sp:IsA("BasePart") then sp.CFrame + Vector3.new(0, Config.spawnHeight, 0) else nil
end

local function startWarning(mine: Mines.Mine, st: State, warningLen: number)
	st.phase = "warning"
	st.warningLen = warningLen
	st.collapseAt = now() + warningLen
	st.announced = {}
	st.participants = {}
	st.diedInside = {}
	stateFolder:SetAttribute(mine.id, st.collapseAt)

	EventBus.Fire(Events.CollapseWarning, mine.id, st.collapseAt)
	Announcer.announce(`{mine.name} 붕괴까지 {math.floor(warningLen)}초! 출구로 탈출하세요`, Kind.Collapse)
end

local function escapeBonus(st: State, lastInside: number): number
	-- 붕괴에 가까이 나올수록 1에 가까움
	local remaining = st.collapseAt - lastInside
	local t = math.clamp(1 - remaining / math.max(st.warningLen, 1), 0, 1) -- 경보 길이 0일 때 0으로 나누기 방지
	return math.floor(Config.escapeBonusMin + (Config.escapeBonusMax - Config.escapeBonusMin) * t)
end

local function doCollapse(mine: Mines.Mine, st: State)
	local escaped, trapped = 0, 0
	local trappedPlayers: { Player } = {}

	EventBus.Fire(Events.CollapseOccurred, mine.id)

	for player, lastInside in st.participants do
		if player.Parent == nil then continue end -- 나간 플레이어
		if isInside(player, mine) or st.diedInside[player] then
			trapped += 1
			table.insert(trappedPlayers, player)
			EventBus.Fire(Events.PlayerTrapped, player, mine.id)
			Announcer.announceTo(player, "광산에 갇혔습니다! 수확 일부를 잃었어요", Kind.Collapse)
		else
			escaped += 1
			local bonus = escapeBonus(st, lastInside)
			EventBus.Fire(Events.PlayerEscaped, player, mine.id, bonus)
			Announcer.announceTo(player, `탈출 성공! 보너스 +{bonus}`, Kind.Info)
		end
	end

	Announcer.announce(`{mine.name}이(가) 무너졌습니다! 탈출 {escaped}명 · 갇힘 {trapped}명`, Kind.Collapse)

	-- 갇힌 사람은 잠깐 뒤 허브로 (A가 통로를 막아서 걸어 나올 수 없으므로)
	task.delay(Config.trappedTeleportDelay, function()
		local cf = hubSpawn(mine)
		if not cf then
			warn(`[Collapse] {mine.id} 광산의 허브 스폰(Hub.MineSpawn)을 찾지 못해 갇힌 플레이어를 옮기지 못함`)
			return
		end
		for _, player in trappedPlayers do
			local root = rootOf(player)
			if root and isInside(player, mine) then root.CFrame = cf end
		end
	end)

	-- 다음 주기 시작
	st.phase = "idle"
	st.participants = {}
	st.diedInside = {}
	st.collapseAt = now() + rollInterval(mine)
	stateFolder:SetAttribute(mine.id, nil)
end

local function tick()
	local t = now()
	for _, mine in Mines.list do
		local st = states[mine.id]
		if st.phase == "idle" then
			if t >= st.collapseAt - mine.collapse.warning then
				startWarning(mine, st, math.max(st.collapseAt - t, 0))
			end
		else
			-- 경보 중: 광산 안에 있는 사람을 참가자로 기록 (경보 중에 새로 들어온 사람 포함)
			for _, player in Players:GetPlayers() do
				if isInside(player, mine) then
					st.participants[player] = t
					-- 죽었다가 부활해서 다시 광산에 들어왔으면, 이번엔 정말 걸어 나와야 탈출로 친다
					local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
					if humanoid and humanoid.Health > 0 then st.diedInside[player] = nil end
				end
			end
			-- 남은 시간 공지 (30초, 10초 …)
			local remaining = st.collapseAt - t
			for _, sec in Config.announceAt do
				if remaining <= sec and not st.announced[sec] and sec < st.warningLen then
					st.announced[sec] = true
					Announcer.announce(`{mine.name} 붕괴 {sec}초 전!`, Kind.Collapse)
				end
			end
			if remaining <= 0 then doCollapse(mine, st) end
		end
	end
end

local Collapse = {}

-- 붕괴까지 남은 초. 경보 중이 아니면 nil.
-- 경보 중인 광산에서 죽은 적이 있으면 그 광산 id (아니면 nil)
-- B(PlayerData)가 퇴장 때 물어본다: 광산 안에서 리셋 → 허브에서 부활 → 붕괴 전에 나가기로 차감을 피하는 것 방지 (#18)
-- 이벤트(PlayerTrapped)로 보내지 않는 이유: 퇴장 순서상 B가 먼저 데이터를 내려놓으면 이벤트를 받아도 차감할 수 없다
function Collapse.DiedInsideMine(player: Player): string?
	for mineId, st in states do
		if st.phase == "warning" and st.diedInside[player] then return mineId end
	end
	return nil
end

function Collapse.GetRemainingTime(mineId: string): number?
	local st = states[mineId]
	if not st or st.phase ~= "warning" then return nil end
	return math.max(st.collapseAt - now(), 0)
end

-- 시작: 광산마다 첫 붕괴 시각을 정하고 루프를 돈다
for _, mine in Mines.list do
	states[mine.id] = {
		phase = "idle",
		collapseAt = now() + mine.collapse.offset + rollInterval(mine),
		warningLen = mine.collapse.warning,
		announced = {},
		participants = {},
		diedInside = {},
	}
end

-- 경보 중 광산 안에서 죽으면 갇힘으로 친다 (리셋 꼼수 방지)
local function onDied(player: Player, root: BasePart?)
	if not root then return end
	local mine = Mines.findAreaAt(root.Position)
	local st = mine and states[mine.id]
	if mine and st and st.phase == "warning" then
		st.participants[player] = now()
		st.diedInside[player] = true
	end
end

local function watchCharacter(player: Player, char: Model)
	local humanoid = char:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then return end
	humanoid.Died:Connect(function()
		-- 죽은 순간의 위치로 판정 (부활하면 허브로 옮겨지기 전에)
		onDied(player, char:FindFirstChild("HumanoidRootPart") :: BasePart?)
	end)
end

local function watchPlayer(player: Player)
	player.CharacterAdded:Connect(function(char) watchCharacter(player, char) end)
	if player.Character then task.spawn(watchCharacter, player, player.Character) end
end
Players.PlayerAdded:Connect(watchPlayer)
-- 이 모듈보다 먼저 들어온 플레이어 (Studio 테스트에서 흔함)
for _, player in Players:GetPlayers() do watchPlayer(player) end

Players.PlayerRemoving:Connect(function(player)
	for _, st in states do
		st.participants[player] = nil
		st.diedInside[player] = nil
	end
end)

-- Studio 테스트: Command Bar 에서 workspace:SetAttribute("CollapseTest", "basic") → 바로 짧은 경보 시작
-- (Command Bar 에서 require 한 모듈은 게임 쪽과 따로라서, 속성으로 신호를 준다)
if RunService:IsStudio() then
	workspace:GetAttributeChangedSignal("CollapseTest"):Connect(function()
		local id = workspace:GetAttribute("CollapseTest")
		workspace:SetAttribute("CollapseTest", nil)
		local mine = typeof(id) == "string" and Mines.get(id)
		local st = mine and states[(mine :: Mines.Mine).id]
		if mine and st and st.phase == "idle" then
			startWarning(mine, st, Config.testWarning)
		end
	end)
end

task.spawn(function()
	while true do
		task.wait(Config.tickInterval)
		local ok, err = pcall(tick)
		if not ok then warn("[Collapse] " .. tostring(err)) end -- 한 번 에러로 붕괴 루프 전체가 멈추지 않게
	end
end)

return table.freeze(Collapse)
