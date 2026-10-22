--!strict
-- 다른 기능이 쏜 이벤트를 받아서 서버 공지로 바꾼다 (C 담당)
-- 공지 문구는 여기 한 곳에서 관리한다. 문구를 바꾸고 싶으면 이 파일만 고치면 된다.

local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")

local Shared = RS:WaitForChild("Shared")
local Events = require(Shared:WaitForChild("Events"))
local EventBus = require(Shared:WaitForChild("EventBus"))
local Announcer = require(SSS:WaitForChild("Server"):WaitForChild("Social"):WaitForChild("Announcer"))

-- 전설 이상 광물 발견 (A → C)
-- TODO: 광물 이름은 지금 oreId 그대로 나간다. A의 광물 데이터 모듈(155종)이 생기면 표시 이름으로 바꾼다.
EventBus.On(Events.LegendaryFound, function(player: Player, oreId: string, _mineId: string, _depth: number)
	Announcer.announce(`{player.DisplayName}님이 전설 광물 [{oreId}]을(를) 발견했습니다!`, "Legendary")
end)
