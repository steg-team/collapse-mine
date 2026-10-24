--!strict
-- 튜토리얼 진행 (C 담당, D-031)
-- 단계 목록은 Config/Social.luau 의 Tutorial.steps. 각 단계는 정해진 게임 이벤트가 오면 넘어간다
--   StageEntered(A) → OreMined(A) → OreSold(B) → 붕괴 팁("알겠어요")
-- 진행 상황은 C 칸 data.social.tutorial = 지금 단계 번호 (단계 수보다 크면 끝). 서버가 판정하고 클라이언트는 그리기만.
-- 통신: Remotes.Tutorial (RemoteEvent)
--   서버 → 클라: (stepIndex, total)   stepIndex 가 total 보다 크면 끝
--   클라 → 서버: "next"(manual 단계 확인) / "skip"(건너뛰기)

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")

local Shared = RS:WaitForChild("Shared")
local Events = require(Shared:WaitForChild("Events"))
local EventBus = require(Shared:WaitForChild("EventBus"))
local Social = require(Shared:WaitForChild("Config"):WaitForChild("Social"))
local PlayerData = require(SSS:WaitForChild("Server"):WaitForChild("Economy"):WaitForChild("PlayerData"))
local SocialRemotes = require(script.Parent:WaitForChild("SocialRemotes"))

local CONFIG = Social.Tutorial
local STEPS = CONFIG.steps
local DONE = #STEPS + 1

local remote = SocialRemotes.get("Tutorial", "RemoteEvent") :: RemoteEvent

-- 다른 UI 가 튜토리얼 중인지 알 수 있게 플레이어 속성으로도 올린다 (출석판 자동 열기를 미루는 데 씀)
local function publish(player: Player, step: number)
	player:SetAttribute("TutorialActive", step <= #STEPS)
end

local function getStep(player: Player): number?
	local data = PlayerData.get(player)
	if not data then return nil end
	local step = data.social.tutorial
	if typeof(step) ~= "number" then
		-- 처음: 이미 돈을 번 적이 있으면(튜토리얼 이전부터 하던 사람) 건너뛴다
		step = if CONFIG.skipIfEarned and data.stats.totalEarned > 0 then DONE else 1
		data.social.tutorial = step
	end
	publish(player, step :: number)
	return step :: number
end

local function setStep(player: Player, step: number)
	local data = PlayerData.get(player)
	if not data then return end
	data.social.tutorial = step
	publish(player, step)
	remote:FireClient(player, step, #STEPS)
end

-- 지금 단계가 이 이벤트로 끝나는 단계면 다음으로
local function advanceOn(eventName: string)
	return function(player: Player)
		local step = getStep(player)
		if step and step <= #STEPS and STEPS[step].done == eventName then
			setStep(player, step + 1)
		end
	end
end

EventBus.On(Events.PlayerDataLoaded, function(player: Player)
	local step = getStep(player)
	if step then remote:FireClient(player, step, #STEPS) end
end)
EventBus.On(Events.StageEntered, advanceOn("StageEntered"))
EventBus.On(Events.OreMined, advanceOn("OreMined"))
EventBus.On(Events.OreSold, advanceOn("OreSold"))

remote.OnServerEvent:Connect(function(player: Player, action: any)
	-- 클라이언트가 보낸 값은 타입부터 확인 (AGENTS.md 보안 규칙)
	local step = getStep(player)
	if not step or step > #STEPS then return end
	if action == "skip" then
		setStep(player, DONE)
	elseif action == "next" and STEPS[step].manual then
		setStep(player, step + 1)
	end
end)

-- 이 모듈보다 먼저 데이터가 로드된 플레이어 (Studio 테스트에서 흔함)
for _, player in Players:GetPlayers() do
	local step = getStep(player)
	if step then remote:FireClient(player, step, #STEPS) end
end

-- Studio 테스트: Command Bar 에서 workspace:SetAttribute("TutorialReset", true) → 모두 1단계부터
if game:GetService("RunService"):IsStudio() then
	workspace:GetAttributeChangedSignal("TutorialReset"):Connect(function()
		if workspace:GetAttribute("TutorialReset") then
			workspace:SetAttribute("TutorialReset", nil)
			for _, player in Players:GetPlayers() do setStep(player, 1) end
		end
	end)
end

return table.freeze({})
