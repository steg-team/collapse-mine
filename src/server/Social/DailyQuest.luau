--!strict
-- 일일 퀘스트 (C 담당, D-032)
-- 하루에 Config/Social.luau DailyQuest.pool 에서 count 개를 랜덤으로 뽑아 준다 (플레이어·날마다 다르게).
-- 게임 이벤트(OreMined·OreSold·PlayerEscaped·StageEntered)로 진행이 오르고, 다 채우면 퀘스트 창에서 받는다.
--
-- 저장: C 칸 data.social.quests = { day = 날 번호, list = { { id, progress, claimed } } }
-- 지급: 코인은 B가 QuestCompleted(player, questId, { coins }) 를 받아서 준다
-- 통신: Remotes.DailyQuest (RemoteFunction) — "get" 목록 조회, "claim", questId 받기
-- 받을 퀘스트 수는 플레이어 속성 QuestClaimable 로도 올린다 (📜 버튼 빨간 점)

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")

local Shared = RS:WaitForChild("Shared")
local Events = require(Shared:WaitForChild("Events"))
local EventBus = require(Shared:WaitForChild("EventBus"))
local Social = require(Shared:WaitForChild("Config"):WaitForChild("Social"))
local Mines = require(Shared:WaitForChild("Config"):WaitForChild("Mines"))
local PlayerData = require(SSS:WaitForChild("Server"):WaitForChild("Economy"):WaitForChild("PlayerData"))
local SocialRemotes = require(script.Parent:WaitForChild("SocialRemotes"))
local Announcer = require(script.Parent:WaitForChild("Announcer"))

local CONFIG = Social.DailyQuest
local SECONDS_PER_DAY = 86400
local remote = SocialRemotes.get("DailyQuest", "RemoteFunction") :: RemoteFunction

type Quest = { id: string, progress: number, claimed: boolean }
type Saved = { day: number, list: { Quest } }

-- 퀘스트 정의 찾기 (id → 정의)
local defs: { [string]: Social.QuestDef } = {}
for _, d in CONFIG.pool do defs[d.id] = d end

-- 광물 id → 등급 (OreMined 에는 등급이 없어서 광물표에서 찾는다)
local gradeOf: { [string]: string } = {}
for _, mine in Mines.list do
	for _, ore in mine.ores do gradeOf[ore.name] = ore.grade end
end

-- 하루 번호 (출석과 같은 기준으로 바뀜)
local function dayIndex(): number
	return (os.time() + Social.DailyLogin.dayOffsetHours * 3600) // SECONDS_PER_DAY
end

-- 오늘 퀘스트 뽑기. 같은 사람·같은 날이면 항상 같은 결과 (서버를 옮겨도 목록이 안 바뀜)
local function rollToday(userId: number, day: number): { Quest }
	local rng = Random.new(userId * 1000 + day)
	local ids = {}
	for _, d in CONFIG.pool do table.insert(ids, d.id) end
	local list: { Quest } = {}
	for _ = 1, math.min(CONFIG.count, #ids) do
		local id = table.remove(ids, rng:NextInteger(1, #ids)) :: string
		table.insert(list, { id = id, progress = 0, claimed = false })
	end
	return list
end

local function getQuests(player: Player): { Quest }?
	local data = PlayerData.get(player)
	if not data then return nil end
	local today = dayIndex()
	local saved = data.social.quests
	if typeof(saved) ~= "table" or saved.day ~= today then
		saved = { day = today, list = rollToday(player.UserId, today) } -- 새 날
		data.social.quests = saved
	end
	return (saved :: Saved).list
end

local function claimableCount(list: { Quest }): number
	local n = 0
	for _, q in list do
		local d = defs[q.id]
		if d and not q.claimed and q.progress >= d.target then n += 1 end
	end
	return n
end

local function publish(player: Player)
	local list = getQuests(player)
	player:SetAttribute("QuestClaimable", if list then claimableCount(list) else 0)
end

-- 이벤트 하나가 오면 맞는 퀘스트들 진행을 올린다
local function addProgress(player: Player, eventName: string, amount: number, oreId: string?, pressure: string?)
	local list = getQuests(player)
	if not list then return end
	for _, q in list do
		local d = defs[q.id]
		if d and d.event == eventName and not q.claimed and q.progress < d.target then
			if d.grades and not (oreId and table.find(d.grades, gradeOf[oreId] or "")) then continue end
			if d.pressures and not (pressure and table.find(d.pressures, pressure)) then continue end
			q.progress = math.min(d.target, q.progress + amount)
			if q.progress >= d.target then
				Announcer.announceTo(player, `퀘스트 완료! 📜에서 보상을 받으세요`, Social.AnnounceKind.Info)
			end
		end
	end
	publish(player)
end

EventBus.On(Events.PlayerDataLoaded, publish)
EventBus.On(Events.OreMined, function(player: Player, oreId: string, _weight: number, pressure: string)
	addProgress(player, "OreMined", 1, oreId, pressure)
end)
EventBus.On(Events.OreSold, function(player: Player, _oreId: string, _count: number, total: number)
	addProgress(player, "OreSold", math.floor(total), nil, nil)
end)
EventBus.On(Events.PlayerEscaped, function(player: Player)
	addProgress(player, "PlayerEscaped", 1, nil, nil)
end)
EventBus.On(Events.StageEntered, function(player: Player)
	addProgress(player, "StageEntered", 1, nil, nil)
end)

-- 클라이언트에 보내는 목록 (문구·목표·보상까지 채워서)
local function view(player: Player)
	local list = getQuests(player)
	if not list then return nil end
	local out = {}
	for _, q in list do
		local d = defs[q.id]
		if d then
			table.insert(out, {
				id = q.id,
				text = (d.text:gsub("{n}", tostring(d.target))),
				progress = q.progress,
				target = d.target,
				reward = d.reward,
				claimed = q.claimed,
			})
		end
	end
	local nextDayAt = (dayIndex() + 1) * SECONDS_PER_DAY - Social.DailyLogin.dayOffsetHours * 3600
	return { quests = out, nextDayAt = nextDayAt }
end

local function claim(player: Player, questId: string)
	local list = getQuests(player)
	if not list then return end
	for _, q in list do
		local d = defs[q.id]
		if q.id == questId and d and not q.claimed and q.progress >= d.target then
			q.claimed = true -- 먼저 표시하고 이벤트 (연타해도 한 번만)
			EventBus.Fire(Events.QuestCompleted, player, q.id, { coins = d.reward })
			Announcer.announceTo(player, `퀘스트 보상 +{d.reward} 코인`, Social.AnnounceKind.Info)
		end
	end
	publish(player)
end

remote.OnServerInvoke = function(player: Player, action: any, questId: any)
	-- 클라이언트가 보낸 값은 타입부터 확인 (AGENTS.md 보안 규칙)
	if action == "claim" and typeof(questId) == "string" then
		claim(player, questId)
	end
	return view(player)
end

for _, player in Players:GetPlayers() do publish(player) end

-- Studio 테스트: Command Bar 에서 workspace:SetAttribute("QuestTest", true) → 지금 퀘스트 전부 완료 상태로
if game:GetService("RunService"):IsStudio() then
	workspace:GetAttributeChangedSignal("QuestTest"):Connect(function()
		if not workspace:GetAttribute("QuestTest") then return end
		workspace:SetAttribute("QuestTest", nil)
		for _, player in Players:GetPlayers() do
			local list = getQuests(player)
			if list then
				for _, q in list do
					local d = defs[q.id]
					if d then q.progress = d.target end
				end
				publish(player)
			end
		end
	end)
end

return table.freeze({})
