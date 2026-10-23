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
