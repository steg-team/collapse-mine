--!strict
-- 허브 랭킹판 3종 (C 담당, D-009 · D-030)
--   Board_BestHaul    최고 탈출 수확 — 이번 주, 붕괴 한 번에 살아서 들고 나온 가방 가치 (월요일마다 초기화)
--   Board_BestOre     최고 광물     — 전체 기간, 한 덩이 최고가
--   Board_TotalEarned 누적 수입     — 전체 기간, 지금까지 판매로 번 코인
--
-- 점수 원본은 B 가 정한다 (D-020): OreBagged·OreSold·HaulSecured 이벤트와 PlayerData 의 data.stats.
-- 주간 수확만 B 가 따로 안 들고 있어서 C 칸(data.social.weeklyHaul)에 이번 주 최고값을 적어 둔다.
--
-- 흐름: 점수가 바뀌면 "올릴 값"만 기억 → flushInterval 마다 OrderedDataStore 에 올림
--       refreshInterval 마다 상위 5명을 읽어 모든 허브(이름이 CollapseMine 으로 시작하는 폴더)의 판에 그림
-- DataStore 가 안 되면(Studio 기본) 지금 서버에 있는 사람들끼리 순위를 보여준다.

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local DataStoreService = game:GetService("DataStoreService")

local Shared = RS:WaitForChild("Shared")
local Events = require(Shared:WaitForChild("Events"))
local EventBus = require(Shared:WaitForChild("EventBus"))
local Social = require(Shared:WaitForChild("Config"):WaitForChild("Social"))
local PlayerData = require(SSS:WaitForChild("Server"):WaitForChild("Economy"):WaitForChild("PlayerData"))

local CONFIG = Social.Leaderboard
local SECONDS_PER_DAY = 86400

type BoardId = "Board_BestHaul" | "Board_BestOre" | "Board_TotalEarned"
local BOARDS: { BoardId } = { "Board_BestHaul", "Board_BestOre", "Board_TotalEarned" }

-- 이번 주 번호. 1970-01-01 이 목요일이라 +3 하면 월요일마다 바뀐다
local function weekIndex(): number
	local day = (os.time() + CONFIG.weekOffsetHours * 3600) // SECONDS_PER_DAY
	return (day + 3) // 7
end

-- 판마다 쓸 OrderedDataStore 이름. 주간판은 주가 바뀌면 이름이 바뀌어서 저절로 0부터 시작한다
local function storeName(board: BoardId): string
	local v = `v{CONFIG.storeVersion}`
	if board == "Board_BestHaul" then return `LB_BestHaul_{v}_W{weekIndex()}` end
	if board == "Board_BestOre" then return `LB_BestOre_{v}` end
	return `LB_TotalEarned_{v}`
end

-- 플레이어별 지금 점수 (판 → 값). DataStore 에 올릴 값이자, DataStore 가 안 될 때 서버 내 순위의 재료
local scores: { [number]: { [BoardId]: number } } = {}   -- UserId → 점수
local dirty: { [number]: { [BoardId]: boolean } } = {}   -- 아직 안 올린 것
local names: { [number]: string } = {}                   -- UserId → 이름 (조회 결과 캐시)

local function setScore(userId: number, board: BoardId, value: number)
	value = math.floor(value) -- OrderedDataStore 는 정수만
	local s = scores[userId] or {}
	scores[userId] = s
	if s[board] == value then return end
	s[board] = value
	local d = dirty[userId] or {}
	dirty[userId] = d
	d[board] = true
end

-- 이번 주 최고 탈출 수확 (C 칸). 주가 바뀌었으면 0부터
local function weeklyHaul(player: Player): number
	local data = PlayerData.get(player)
	if not data then return 0 end
	local w = data.social.weeklyHaul
	if typeof(w) ~= "table" or w.week ~= weekIndex() then return 0 end
	return w.best
end

-- 저장 데이터에서 세 점수를 다시 읽어 반영
local function refreshFromData(player: Player)
	local data = PlayerData.get(player)
	if not data then return end
	setScore(player.UserId, "Board_TotalEarned", data.stats.totalEarned)
	setScore(player.UserId, "Board_BestOre", data.stats.bestOre)
	setScore(player.UserId, "Board_BestHaul", weeklyHaul(player))
end

-- ───── 점수가 바뀌는 순간 ─────

EventBus.On(Events.PlayerDataLoaded, function(player: Player)
	names[player.UserId] = player.Name
	refreshFromData(player)
end)

-- OreBagged 는 B 가 bestOre 를 갱신한 뒤에 쏜다.
-- OreSold 는 광물 종류마다 쏘고 totalEarned 는 그 다음에 한꺼번에 더하므로(Bag.luau), 같은 프레임 끝까지 미뤘다가 읽는다
EventBus.On(Events.OreBagged, function(player: Player) refreshFromData(player) end)
EventBus.On(Events.OreSold, function(player: Player) task.defer(refreshFromData, player) end)

EventBus.On(Events.HaulSecured, function(player: Player, _mineId: string, haul: number)
	local data = PlayerData.get(player)
	if not data then return end
	local week = weekIndex()
	local w = data.social.weeklyHaul
	if typeof(w) ~= "table" or w.week ~= week then
		w = { week = week, best = 0 } -- 새 주
		data.social.weeklyHaul = w
	end
	w.best = math.max(w.best, math.floor(haul))
	refreshFromData(player)
end)

-- ───── DataStore 올리기 ─────

local storeOk = true -- 한 번이라도 실패하면 서버 내 순위로 표시 (Studio 기본: API 꺼짐)

local function flush()
	for userId, boards in dirty do
		for board in boards do
			local value = scores[userId] and scores[userId][board]
			if value then
				local ok, err = pcall(function()
					DataStoreService:GetOrderedDataStore(storeName(board)):SetAsync(tostring(userId), value)
				end)
				if not ok then
					storeOk = false
					warn(`[Leaderboard] 점수 저장 실패 ({board}): {err}`)
				end
			end
		end
		dirty[userId] = nil
	end
end

-- ───── 순위 읽기 ─────

type Entry = { userId: number, value: number }

local function readTop(board: BoardId): { Entry }?
	if not storeOk then return nil end
	local ok, result = pcall(function()
		local pages = DataStoreService:GetOrderedDataStore(storeName(board)):GetSortedAsync(false, CONFIG.rows)
		return pages:GetCurrentPage()
	end)
	if not ok then
		storeOk = false
		warn(`[Leaderboard] 순위 읽기 실패 ({board}): {result}`)
		return nil
	end
	local list: { Entry } = {}
	for _, e in result do
		table.insert(list, { userId = tonumber(e.key) :: number, value = e.value })
	end
	return list
end

-- DataStore 가 안 될 때: 지금 서버에 있는 사람들끼리
local function localTop(board: BoardId): { Entry }
	local list: { Entry } = {}
	for userId, s in scores do
		if s[board] and s[board] > 0 then table.insert(list, { userId = userId, value = s[board] }) end
	end
	table.sort(list, function(a, b) return a.value > b.value end)
	while #list > CONFIG.rows do table.remove(list) end
	return list
end

local function nameOf(userId: number): string
	if names[userId] then return names[userId] end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	names[userId] = if ok then name else "???"
	return names[userId]
end

-- 1234567 → "1,234,567"
local function comma(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

-- ───── 판에 그리기 ─────

-- 허브 폴더마다 (CollapseMine, CollapseMine_iron, ...) 그 판의 Rows 프레임
local function rowsFrames(board: BoardId): { Instance }
	local list = {}
	for _, hub in workspace:GetChildren() do
		if hub:IsA("Folder") or hub:IsA("Model") then
			if hub.Name:sub(1, 12) == "CollapseMine" then
				local part = hub:FindFirstChild(board, true)
				local gui = part and part:FindFirstChildOfClass("SurfaceGui")
				local rows = gui and gui:FindFirstChild("Rows")
				if rows then table.insert(list, rows) end
			end
		end
	end
	return list
end

-- 판의 한 줄: 왼쪽 "1.  이름"(길면 … 로 잘림), 오른쪽 점수 — 줄(Row) 안에 글자 칸 두 개를 만들어 쓴다
-- 판을 만든 도구의 줄은 TextScaled 라 내용 길이에 따라 글씨 크기가 들쭉날쭉해서, 고정 크기 글자 칸으로 바꾼다
local function cell(row: TextLabel, name: string, x: number, width: number, align: Enum.TextXAlignment): TextLabel
	local l = row:FindFirstChild(name) :: TextLabel?
	if not l then
		local n = Instance.new("TextLabel")
		n.Name = name
		n.BackgroundTransparency = 1
		n.Position = UDim2.fromScale(x, 0)
		n.Size = UDim2.fromScale(width, 1)
		n.TextXAlignment = align
		n.TextTruncate = Enum.TextTruncate.AtEnd
		n.Parent = row
		l = n
	end
	local label = l :: TextLabel
	label.Font = row.Font
	label.TextColor3 = row.TextColor3 -- 1~3등 메달 색은 판을 만들 때 줄에 칠해 둔 색
	label.TextSize = CONFIG.rowTextSize
	return label
end

local function setRow(row: TextLabel, left: string, right: string)
	row.Text = "" -- 줄 자체 글자는 비우고 칸 두 개로 그린다
	local nameW = 1 - CONFIG.valueWidth
	cell(row, "NameText", 0, nameW, Enum.TextXAlignment.Left).Text = left
	cell(row, "ValueText", nameW, CONFIG.valueWidth - 0.03, Enum.TextXAlignment.Right).Text = right
end

local function draw(board: BoardId, entries: { Entry })
	for _, rows in rowsFrames(board) do
		for r = 1, CONFIG.rows do
			local label = rows:FindFirstChild(`Row{r}`)
			if label and label:IsA("TextLabel") then
				local e = entries[r]
				if e then
					setRow(label, `  {r}.  {nameOf(e.userId)}`, comma(e.value))
				else
					setRow(label, `  {r}.  {CONFIG.emptyText}`, "")
				end
			end
		end
	end
end

local function refreshBoards()
	for _, board in BOARDS do
		draw(board, readTop(board) or localTop(board))
	end
end

-- ───── 시작 ─────

for _, player in Players:GetPlayers() do refreshFromData(player) end
Players.PlayerRemoving:Connect(function(player)
	-- 나가기 전에 한 번 더 읽어 둔다 (데이터가 아직 있으면). 올리기는 flush 가 한다
	refreshFromData(player)
end)

task.spawn(function()
	local sinceFlush = 0
	while true do
		local ok, err = pcall(refreshBoards)
		if not ok then warn("[Leaderboard] " .. tostring(err)) end
		task.wait(CONFIG.refreshInterval)
		sinceFlush += CONFIG.refreshInterval
		if sinceFlush >= CONFIG.flushInterval then
			sinceFlush = 0
			pcall(flush)
		end
	end
end)

-- 서버가 닫힐 때 남은 점수 올리기
game:BindToClose(function()
	pcall(flush)
end)

-- Studio 테스트: Command Bar 에서 workspace:SetAttribute("LeaderboardTest", true) → 1분 기다리지 않고 바로 다시 그리기
if game:GetService("RunService"):IsStudio() then
	workspace:GetAttributeChangedSignal("LeaderboardTest"):Connect(function()
		if workspace:GetAttribute("LeaderboardTest") then
			workspace:SetAttribute("LeaderboardTest", nil)
			pcall(flush)
			refreshBoards()
		end
	end)
end

return table.freeze({})
