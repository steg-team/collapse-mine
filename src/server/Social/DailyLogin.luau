--!strict
-- 출석 보상 (C 담당, D-016)
-- 7일 주기. 하루 빠지면 1일차부터. 출석판에서 버튼을 눌러 받는다.
--
-- 저장: PlayerData 의 data.social.daily = { lastClaimDay = 마지막으로 받은 날 번호, streak = 그날이 몇 일차였는지 }
--       (B 규칙: C는 data.social 칸만 쓴다, D-014)
-- 지급: 코인은 B가 DailyLoginClaimed 를 받아서 넣는다. C는 "받았다"는 사실만 기록하고 이벤트를 쏜다.
-- 통신: Remotes.DailyLogin (RemoteFunction) — "get" 상태 조회, "claim" 받기 (tools/create_social_remotes.luau)

local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")

local Shared = RS:WaitForChild("Shared")
local Events = require(Shared:WaitForChild("Events"))
local EventBus = require(Shared:WaitForChild("EventBus"))
local Social = require(Shared:WaitForChild("Config"):WaitForChild("Social"))
local PlayerData = require(SSS:WaitForChild("Server"):WaitForChild("Economy"):WaitForChild("PlayerData"))
local Announcer = require(script.Parent:WaitForChild("Announcer"))

local CONFIG = Social.DailyLogin
local CYCLE = #CONFIG.rewards -- 주기 길이 (보상 개수 = 7일)
local SECONDS_PER_DAY = 86400

local remote = RS:WaitForChild("Remotes"):WaitForChild("DailyLogin") :: RemoteFunction

type Daily = { lastClaimDay: number, streak: number }

-- 클라이언트에 보내는 출석판 상태
export type State = {
	day: number,           -- 오늘 받을(또는 이미 받은) 일차 1~7
	canClaim: boolean,     -- 오늘 아직 안 받았으면 true
	rewards: { number },   -- 1~7일차 보상
	nextDayAt: number,     -- 다음 날이 시작되는 시각 (os.time 기준, "다음 보상까지 n시간" 표시용)
}

local lastClaimAt: { [Player]: number } = {}

-- 오늘이 몇 번째 날인지 (1970-01-01 부터). 날 번호가 1 차이 나면 연속 출석
local function dayIndex(t: number): number
	return (t + CONFIG.dayOffsetHours * 3600) // SECONDS_PER_DAY
end

local function getDaily(player: Player): Daily?
	local data = PlayerData.get(player)
	if not data then return nil end -- 저장 데이터 로드 전
	local daily = data.social.daily
	if typeof(daily) ~= "table" then
		daily = { lastClaimDay = -1, streak = 0 } -- 처음 접속
		data.social.daily = daily
	end
	return daily :: Daily
end

local function stateOf(daily: Daily): State
	local now = os.time()
	local today = dayIndex(now)
	local day, canClaim
	if daily.lastClaimDay == today then
		day, canClaim = daily.streak, false            -- 오늘 이미 받음
	elseif daily.lastClaimDay == today - 1 then
		day, canClaim = daily.streak % CYCLE + 1, true -- 어제 받았으면 다음 일차 (7일차 다음은 1일차)
	else
		day, canClaim = 1, true                        -- 처음이거나 하루 이상 빠짐
	end
	local nextDayAt = (today + 1) * SECONDS_PER_DAY - CONFIG.dayOffsetHours * 3600
	return { day = day, canClaim = canClaim, rewards = CONFIG.rewards, nextDayAt = nextDayAt }
end

local function claim(player: Player): State?
	-- 연타 방지 (같은 프레임에 두 번 와도 한 번만)
	local t = os.clock()
	if lastClaimAt[player] and t - lastClaimAt[player] < CONFIG.claimCooldown then return nil end
	lastClaimAt[player] = t

	local daily = getDaily(player)
	if not daily then return nil end
	local state = stateOf(daily)
	if not state.canClaim then return state end

	-- 저장 먼저 바꾸고 이벤트를 쏜다 (이벤트 처리 중에 다시 claim 이 와도 이미 받은 상태)
	daily.lastClaimDay = dayIndex(os.time())
	daily.streak = state.day
	local coins = CONFIG.rewards[state.day]
	EventBus.Fire(Events.DailyLoginClaimed, player, state.day, { coins = coins })
	Announcer.announceTo(player, `출석 {state.day}일차! +{coins} 코인`, Social.AnnounceKind.Info)
	return stateOf(daily)
end

remote.OnServerInvoke = function(player: Player, action: any): State?
	-- 클라이언트가 보낸 값은 타입부터 확인 (AGENTS.md 보안 규칙)
	if action == "get" then
		local daily = getDaily(player)
		return daily and stateOf(daily)
	elseif action == "claim" then
		return claim(player)
	end
	return nil
end

game:GetService("Players").PlayerRemoving:Connect(function(player) lastClaimAt[player] = nil end)

return table.freeze({})
