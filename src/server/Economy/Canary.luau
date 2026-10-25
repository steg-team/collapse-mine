--!strict
--[[
	광산 카나리아 광맥 감지 (B 담당, D-036)
	0.5초마다 광산 안 플레이어마다 가장 가까운 숨은 희귀 광맥까지 거리를 재서,
	카나리아 탐지 범위 안이면 플레이어 속성 CanaryVeinDistance(스터드), 밖이면 nil 로 둔다. HUD(CanaryHud)가 읽는다.
	광맥 위치는 A의 Mining/RareVeins (서버 전용). 위치는 클라이언트에 보내지 않고 거리만 보낸다 (탐지 범위를 서버가 정함).
	RareVeins 모듈이 아직 없으면 아무것도 하지 않는다 (A 작업 #43 전에도 B가 동작하게).
]]

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local Config = RS:WaitForChild("Shared"):WaitForChild("Config")
local Economy = require(Config:WaitForChild("Economy"))
local Mines = require(Config:WaitForChild("Mines"))

local UPDATE = 0.5

local Canary = {}

function Canary.start()
	task.spawn(function()
		local mining = script.Parent.Parent:WaitForChild("Mining", 30)
		local mod = mining and mining:WaitForChild("RareVeins", 30)
		if not mod then
			return -- 광맥이 아직 없다: 카나리아는 드러난 광석·붕괴 경보만 (CanaryHud)
		end
		local ok, RareVeins = pcall(require, mod)
		if not ok then
			warn("[Canary] RareVeins 불러오기 실패: " .. tostring(RareVeins))
			return
		end
		while true do
			task.wait(UPDATE)
			for _, player in Players:GetPlayers() do
				local char = player.Character
				local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
				local mine = root and Mines.findAreaAt(root.Position)
				local dist: number? = nil
				if root and mine then
					local spec = Economy.CANARY[player:GetAttribute("CanaryLevel") or 0] or Economy.CANARY[0]
					local okCall, d = pcall(RareVeins.nearest, mine.id, root.Position)
					if okCall and typeof(d) == "number" and d <= spec.range then
						dist = math.floor(d)
					end
				end
				if player:GetAttribute("CanaryVeinDistance") ~= dist then
					player:SetAttribute("CanaryVeinDistance", dist)
				end
			end
		end
	end)
end

return Canary
