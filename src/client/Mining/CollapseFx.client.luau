--!strict
-- 붕괴 연출 (A, D-040) — 갇힌 사람 화면에만 (서버가 Remotes.CollapseFx로 알려 줌)
-- 허브로 옮겨지기 전 몇 초 동안: 화면 흔들림, 주변에 돌 떨어짐, 먼지, 무너지는 소리.
-- 마지막에 화면이 어두워지고, 허브로 옮겨진 뒤 밝아진다. 숫자는 Config/Mines.luau COLLAPSE_FX
-- 돌은 이 클라이언트에만 생기는 파트라 다른 사람·서버에 영향이 없다.

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local Mines = require(RS:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Mines"))
local CFG = Mines.COLLAPSE_FX
local remote = RS:WaitForChild("Remotes"):WaitForChild("CollapseFx") :: RemoteEvent

local rng = Random.new()
local playing = false

local terrainOnly = RaycastParams.new()
terrainOnly.FilterType = Enum.RaycastFilterType.Include
terrainOnly.FilterDescendantsInstances = { workspace.Terrain }

local ROCK_COLORS = { Color3.fromRGB(105, 95, 85), Color3.fromRGB(80, 75, 70), Color3.fromRGB(125, 110, 95) }

-- 화면을 덮는 검은 판 (마지막 페이드용)
local function makeFade(): (ScreenGui, Frame)
	local gui = Instance.new("ScreenGui")
	gui.Name = "CollapseFade"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 50
	gui.ResetOnSpawn = false
	local f = Instance.new("Frame")
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = Color3.new(0, 0, 0)
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")
	return gui, f
end

-- 플레이어 둘레에 돌 하나. 천장(위 레이)에서 떨어뜨리고, 천장이 없으면 머리 위 14
local function dropRock(origin: Vector3)
	local a = rng:NextNumber(0, math.pi * 2)
	local d = rng:NextNumber(2, CFG.rockRadius)
	local base = origin + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
	local up = workspace:Raycast(base, Vector3.new(0, 30, 0), terrainOnly)
	local top = if up then up.Position - Vector3.new(0, 1.5, 0) else base + Vector3.new(0, 14, 0)
	local s = rng:NextNumber(CFG.rockSize.Min, CFG.rockSize.Max)
	local p = Instance.new("Part")
	p.Name = "CollapseRock"
	p.Size = Vector3.new(s, s * rng:NextNumber(0.6, 1), s * rng:NextNumber(0.7, 1.1))
	p.CFrame = CFrame.new(top) * CFrame.Angles(rng:NextNumber(0, 6.3), rng:NextNumber(0, 6.3), rng:NextNumber(0, 6.3))
	p.Material = Enum.Material.Slate
	p.Color = ROCK_COLORS[rng:NextInteger(1, #ROCK_COLORS)]
	p.CanTouch, p.CanQuery = false, false
	p.Massless = true
	p.Parent = workspace
	p.AssemblyLinearVelocity = Vector3.new(0, -rng:NextNumber(5, 20), 0)
	Debris:AddItem(p, 5)
end

-- 먼지: 플레이어 둘레에서 피어오르는 연기
local function makeDust(root: BasePart): Part
	local p = Instance.new("Part")
	p.Name = "CollapseDust"
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
	p.Transparency = 1
	p.Size = Vector3.new(CFG.rockRadius * 2, 1, CFG.rockRadius * 2)
	p.CFrame = CFrame.new(root.Position - Vector3.new(0, 2, 0))
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(150, 135, 115))
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.45), NumberSequenceKeypoint.new(1, 1) })
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 9) })
	e.Lifetime = NumberRange.new(1.5, 2.5)
	e.Rate = 45
	e.Speed = NumberRange.new(1, 4)
	e.SpreadAngle = Vector2.new(60, 60)
	e.EmissionDirection = Enum.NormalId.Top
	e.Parent = p
	p.Parent = workspace
	return p
end

local function play(duration: number)
	if playing then return end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not root or not hum then return end
	playing = true
	duration = math.clamp(duration, 0.5, 10)

	local sound = Instance.new("Sound")
	sound.SoundId = CFG.soundId
	sound.Volume = CFG.soundVolume
	sound.Parent = SoundService
	sound:Play()
	Debris:AddItem(sound, duration + 6)

	local dust = makeDust(root)
	local gui, fade = makeFade()

	-- 흔들림: Humanoid.CameraOffset을 매 프레임 흔든다 (카메라 스크립트를 건드리지 않아도 됨)
	local t0 = os.clock()
	local nextRock = 0
	local conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		local k = math.clamp(t / duration, 0, 1)
		local amp = CFG.shake * (0.4 + 0.6 * k) -- 끝으로 갈수록 세짐
		hum.CameraOffset = Vector3.new(rng:NextNumber(-amp, amp), rng:NextNumber(-amp, amp) * 0.7, rng:NextNumber(-amp, amp) * 0.4)
		if t >= nextRock then
			nextRock = t + CFG.rockInterval
			local r = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if r then dropRock(r.Position) end
		end
	end)

	-- 마지막에 어두워짐 (허브로 옮겨지는 순간을 가림)
	task.delay(math.max(0, duration - CFG.fadeTime), function()
		TweenService:Create(fade, TweenInfo.new(CFG.fadeTime), { BackgroundTransparency = 0 }):Play()
	end)

	task.delay(duration, function()
		conn:Disconnect()
		hum.CameraOffset = Vector3.zero
		local e = dust:FindFirstChildOfClass("ParticleEmitter")
		if e then e.Enabled = false end
		Debris:AddItem(dust, 3)
		-- 서버가 허브로 옮긴 뒤 밝아짐
		task.wait(0.3)
		local tw = TweenService:Create(fade, TweenInfo.new(CFG.fadeTime), { BackgroundTransparency = 1 })
		tw:Play()
		tw.Completed:Wait()
		gui:Destroy()
		playing = false
	end)
end

remote.OnClientEvent:Connect(function(mineId, duration)
	if typeof(mineId) ~= "string" or typeof(duration) ~= "number" then return end
	play(duration)
end)
