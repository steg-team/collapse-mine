--!strict
-- 발견 연출 중 캔 사람 화면 흔들림 (A, D-041). 팡파르·빛기둥은 서버(MineSounds)가 그 자리에 만든다.
-- 서버가 Remotes.MiningFx("legendary")로 알려 준다. 세기·길이는 Config/MiningSounds.luau LEGENDARY_FX

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local S = require(RS:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("MiningSounds"))
local remote = RS:WaitForChild("Remotes"):WaitForChild("MiningFx") :: RemoteEvent

local rng = Random.new()
local shaking = false

local function shake(amp: number, duration: number)
	if shaking then return end
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	shaking = true
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local k = 1 - (os.clock() - t0) / duration -- 처음 세게, 점점 약하게
		if k <= 0 then
			conn:Disconnect()
			hum.CameraOffset = Vector3.zero
			shaking = false
			return
		end
		local a = amp * k
		hum.CameraOffset = Vector3.new(rng:NextNumber(-a, a), rng:NextNumber(-a, a), 0)
	end)
end

remote.OnClientEvent:Connect(function(kind)
	if kind == "legendary" then
		shake(S.LEGENDARY_FX.shake, S.LEGENDARY_FX.shakeTime)
	end
end)
