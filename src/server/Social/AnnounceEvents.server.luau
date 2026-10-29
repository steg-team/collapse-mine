--!strict
-- 다른 기능이 쏜 이벤트를 받아서 서버 공지로 바꾼다 (C 담당)
-- 공지 문구는 여기 한 곳에서 관리한다. 문구를 바꾸고 싶으면 이 파일만 고치면 된다.

local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")

local Shared = RS:WaitForChild("Shared")
local Events = require(Shared:WaitForChild("Events"))
local EventBus = require(Shared:WaitForChild("EventBus"))
local Social = require(Shared:WaitForChild("Config"):WaitForChild("Social"))
local Mines = require(Shared:WaitForChild("Config"):WaitForChild("Mines"))
local Announcer = require(SSS:WaitForChild("Server"):WaitForChild("Social"):WaitForChild("Announcer"))

-- 광산 설정(Config/Mines.luau)에서 광물을 찾는다. 공지에 id("Lantern") 대신 표시 이름·등급을 쓰기 위해
local function findOre(mineId: string, oreId: string): Mines.Ore?
	local mine = Mines.get(mineId)
	if not mine then return nil end
	for _, ore in mine.ores do
		if ore.name == oreId then return ore end
	end
	return nil
end

-- 전설 이상 광물 발견 (A → C)
EventBus.On(Events.LegendaryFound, function(player: Player, oreId: string, mineId: string, _depth: number)
	local ore = findOre(mineId, oreId)
	-- 설정에 없는 광물이면 id 라도 보여준다 (광물표가 바뀌는 중일 수 있음)
	local oreName = if ore then ore.displayName else oreId
	local grade = if ore then ore.grade else "전설"
	Announcer.announce(`{player.DisplayName}님이 {grade} 광물 [{oreName}]을(를) 발견했습니다!`, Social.AnnounceKind.Legendary)
end)

-- ───── 성장 공지: 곡괭이 제작·리버스 (B → C, 이슈 #48, C-002) ─────
-- B는 제작·강화·리버스 모두 PickaxeUpgraded(player, tier, enhance) 하나로 보낸다. 그래서 직전 상태와 비교해 구분한다
--   리버스: 플레이어 속성 Rebirths 가 늘었음 (B가 이벤트보다 먼저 속성을 바꿈) → 서버 전체
--   제작:   tier 가 올라감 → serverMinTier 이상이면 서버 전체, 아니면 본인만
--   강화:   enhance 만 바뀜 → 공지 안 함
local Players = game:GetService("Players")
local Economy = require(Shared:WaitForChild("Config"):WaitForChild("Economy"))
local GROWTH = Social.GrowthAnnounce

local lastTier: { [Player]: number } = {}
local lastRebirths: { [Player]: number } = {}

local function remember(player: Player)
	lastTier[player] = player:GetAttribute("PickaxeTier") or 1
	lastRebirths[player] = player:GetAttribute("Rebirths") or 0
end

-- 곡괭이 이름은 B 설정에서 (A의 Pickaxe.name 과 같은 원본)
local function pickaxeName(tier: number): string
	local p = Economy.PICKAXES[tier]
	return if p then p.name else `곡괭이 {tier}단계`
end

EventBus.On(Events.PlayerDataLoaded, remember)
Players.PlayerRemoving:Connect(function(player)
	lastTier[player] = nil
	lastRebirths[player] = nil
end)
for _, player in Players:GetPlayers() do remember(player) end

EventBus.On(Events.PickaxeUpgraded, function(player: Player, tier: number, _enhance: number)
	local prevTier = lastTier[player] or 1
	local prevRebirths = lastRebirths[player] or 0
	local rebirths = player:GetAttribute("Rebirths") or 0
	remember(player)
	lastTier[player] = tier -- 속성보다 이벤트 값이 정확 (같은 프레임이라 속성이 늦을 수도 있음)

	if typeof(rebirths) == "number" and rebirths > prevRebirths then
		Announcer.announce(`{player.DisplayName}님이 리버스 {rebirths}회를 달성했어요!`, Social.AnnounceKind.Growth)
	elseif tier > prevTier then
		local text = `{player.DisplayName}님이 {pickaxeName(tier)}를 만들었어요!`
		if tier >= GROWTH.serverMinTier then
			Announcer.announce(text, Social.AnnounceKind.Growth)
		else
			Announcer.announceTo(player, text, Social.AnnounceKind.Growth)
		end
	end
end)

-- Studio 테스트: Command Bar 에서 workspace:SetAttribute("GrowthTest", 3) → 3단계 곡괭이 제작 공지, "rebirth" → 리버스 공지
-- (실제로 만들려면 재료·코인이 많이 필요해서 문구·색만 확인용)
if game:GetService("RunService"):IsStudio() then
	workspace:GetAttributeChangedSignal("GrowthTest"):Connect(function()
		local v = workspace:GetAttribute("GrowthTest")
		if v == nil then return end
		workspace:SetAttribute("GrowthTest", nil)
		local player = Players:GetPlayers()[1]
		if not player then return end
		if v == "rebirth" then
			Announcer.announce(`{player.DisplayName}님이 리버스 1회를 달성했어요!`, Social.AnnounceKind.Growth)
		elseif typeof(v) == "number" then
			local text = `{player.DisplayName}님이 {pickaxeName(v)}를 만들었어요!`
			if v >= GROWTH.serverMinTier then Announcer.announce(text, Social.AnnounceKind.Growth) else Announcer.announceTo(player, text, Social.AnnounceKind.Growth) end
		end
	end)
end
