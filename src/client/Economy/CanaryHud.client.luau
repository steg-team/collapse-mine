--!strict
-- 광산 카나리아 HUD (B 담당, D-023)
-- 화면 오른쪽에 카나리아 상태 한 줄. 광산 안에서만 보인다.
--   - 숨은 희귀 광맥이 탐지 범위 안이면 "짹짹! 희귀 광맥이 n m 안에" (D-036, 서버가 거리만 CanaryVeinDistance 속성으로 보냄)
--   - 이미 드러난 희귀 이상 광석이 범위 안이면 "짹짹!" + 거리. 둘 다 가까울수록 빨리 깜빡임
--   - 내가 있는 광산이 붕괴 경보 중이면 불안해한다 (C의 ReplicatedStorage.CollapseState, CollapseHud와 같은 출처)
-- 광석은 원래 클라이언트에도 보이는 파트라, 탐지를 클라이언트에서 해도 새로 드러나는 정보가 없다 (보상과 무관한 힌트).
-- 어깨 위 새(서버가 붙인 Character.Canary)도 같은 상태로 움직인다: 조용하면 살랑, 짹짹이면 깡충 + 울음, 불안하면 떤다.
-- 움직임(Seat Weld C0)과 소리는 내 화면에서 내 새에만 (다른 사람 새까지 울면 시끄럽다)
-- 출구 안내 (D-045, Lv3부터): 붕괴 경보 중이면 상태 줄 아래에 출구 방향 화살표와 거리 (출구 발판 = 태그 MineExit, A).
-- 화살표는 직선 방향이라 굴을 따라가는 길과 다를 수 있다. 위아래로 꼬인 굴이 없어서(지표→바닥 비탈) 이 정도로 충분하다

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local CS = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Config = RS:WaitForChild("Shared"):WaitForChild("Config")
local Economy = require(Config:WaitForChild("Economy"))
local Mines = require(Config:WaitForChild("Mines"))

local player = Players.LocalPlayer
local stateFolder = RS:WaitForChild("CollapseState")

local UPDATE = 0.4

-- UI (코드로 만들어서 Studio 수작업 없이 Rojo 만으로 동작하게)
local gui = Instance.new("ScreenGui")
gui.Name = "CanaryHud"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

-- 오른쪽 맨 위는 플레이어 목록·부스트 타이머(C)가 쓰므로 조금 아래
local label = Instance.new("TextLabel")
label.AnchorPoint = Vector2.new(1, 0)
label.Position = UDim2.new(1, -12, 0.28, 0)
label.Size = UDim2.new(0, 0, 0, 0)
label.AutomaticSize = Enum.AutomaticSize.XY
label.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
label.BackgroundTransparency = 0.35
label.Font = Enum.Font.GothamBold
label.TextSize = 17
label.TextColor3 = Color3.new(1, 1, 1)
label.Parent = gui
local pad = Instance.new("UIPadding")
pad.PaddingLeft = UDim.new(0, 10)
pad.PaddingRight = UDim.new(0, 10)
pad.PaddingTop = UDim.new(0, 5)
pad.PaddingBottom = UDim.new(0, 5)
pad.Parent = label
Instance.new("UICorner").Parent = label

local guide = Instance.new("Frame")
guide.Name = "ExitGuide"
guide.AnchorPoint = Vector2.new(1, 0)
guide.Position = UDim2.new(1, -12, 0.28, 40)
guide.Size = UDim2.fromOffset(150, 40)
guide.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
guide.BackgroundTransparency = 0.35
guide.Visible = false
guide.Parent = gui
Instance.new("UICorner").Parent = guide
local arrow = Instance.new("TextLabel")
arrow.BackgroundTransparency = 1
arrow.Position = UDim2.fromOffset(6, 2)
arrow.Size = UDim2.fromOffset(36, 36)
arrow.Font = Enum.Font.GothamBold
arrow.TextSize = 28
arrow.Text = "⬆"
arrow.TextColor3 = Color3.fromRGB(120, 255, 140)
arrow.Parent = guide
local guideText = Instance.new("TextLabel")
guideText.BackgroundTransparency = 1
guideText.Position = UDim2.fromOffset(44, 0)
guideText.Size = UDim2.new(1, -48, 1, 0)
guideText.Font = Enum.Font.GothamBold
guideText.TextSize = 16
guideText.TextXAlignment = Enum.TextXAlignment.Left
guideText.TextColor3 = Color3.new(1, 1, 1)
guideText.Parent = guide

local function position(ore: Instance): Vector3
	return if ore:IsA("Model") then ore:GetPivot().Position else (ore :: BasePart).Position
end

-- 탐지 범위 안에서 가장 가까운 희귀 이상 광물까지 거리 (없으면 nil)
local function nearestRare(from: Vector3, range: number): number?
	local best: number? = nil
	for _, ore in CS:GetTagged("Ore") do
		if Economy.CANARY_DETECT_GRADES[ore:GetAttribute("Grade")] and ore:IsDescendantOf(workspace) then
			local d = (position(ore) - from).Magnitude
			if d <= range and (not best or d < best) then
				best = d
			end
		end
	end
	return best
end

local chirp = Instance.new("Sound")
chirp.SoundId = Economy.CANARY_CHIRP_SOUND
chirp.Volume = 0.4
chirp.Parent = gui -- PlayerGui 안 소리는 위치 없이 나에게만 들린다

-- 깜빡임 속도 (0이면 안 깜빡임). 상태는 UPDATE마다, 깜빡임·새 움직임은 매 프레임
local blinkSpeed = 0
local mood = "none" -- none(광산 밖) / quiet / chirp / anxious
local chirpGap = 2 -- 울음 간격(초). 가까울수록 짧다
local nextChirp = 0
local baseC0: { [Weld]: CFrame } = setmetatable({} :: any, { __mode = "k" }) -- 서버가 정한 원래 자리
local exitPos: Vector3? = nil -- 출구 안내 대상 (경보 중·Lv3 이상일 때만)

-- 내 광산의 출구 발판 중 가장 가까운 것
local function nearestExit(mineId: string, from: Vector3): Vector3?
	local best: Vector3?, bestD = nil, math.huge
	for _, p in CS:GetTagged("MineExit") do
		if p:IsA("BasePart") and p:GetAttribute("MineId") == mineId then
			local d = (p.Position - from).Magnitude
			if d < bestD then
				best, bestD = p.Position, d
			end
		end
	end
	return best
end

RunService.Heartbeat:Connect(function()
	local t = os.clock()
	local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	guide.Visible = exitPos ~= nil and rootPart ~= nil
	if exitPos and rootPart then
		-- 화면 기준 방향: 카메라 앞이 위(0도), 오른쪽이 시계 방향
		local cam = workspace.CurrentCamera.CFrame
		local dir = exitPos - rootPart.Position
		local flat = Vector3.new(dir.X, 0, dir.Z)
		arrow.Rotation = math.deg(math.atan2(flat:Dot(cam.RightVector), flat:Dot(cam.LookVector)))
		guideText.Text = `출구 {math.floor(flat.Magnitude)}m`
	end
	label.TextTransparency = if blinkSpeed > 0 then 0.4 * (1 + math.sin(t * blinkSpeed)) / 2 else 0

	local bird = player.Character and player.Character:FindFirstChild("Canary")
	local seat = bird and bird:FindFirstChild("Seat", true) :: Weld?
	if seat then
		local base = baseC0[seat] or seat.C0
		baseC0[seat] = base
		local off
		if mood == "anxious" then
			off = CFrame.new(math.sin(t * 40) * 0.04, 0, 0) * CFrame.Angles(0, 0, math.sin(t * 33) * 0.15)
		elseif mood == "chirp" then
			off = CFrame.new(0, math.abs(math.sin(t * blinkSpeed * 0.5)) * 0.18, 0)
		else
			off = CFrame.new(0, math.sin(t * 2) * 0.02, 0)
		end
		seat.C0 = base * off
	end

	if (mood == "chirp" or mood == "anxious") and t >= nextChirp then
		chirp.PlaybackSpeed = if mood == "anxious" then 1.5 else 1
		chirp.TimePosition = 0
		chirp:Play()
		task.delay(Economy.CANARY_CHIRP_LENGTH / chirp.PlaybackSpeed, function()
			chirp:Stop()
		end)
		nextChirp = t + chirpGap
	end
end)

while true do
	task.wait(UPDATE)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local mine = root and Mines.findAreaAt(root.Position)
	if not root or not mine then
		gui.Enabled = false
		mood = "none"
		exitPos = nil
		continue
	end
	gui.Enabled = true

	local level = player:GetAttribute("CanaryLevel") or 0
	local spec = Economy.CANARY[level] or Economy.CANARY[0]
	local collapseAt = stateFolder:GetAttribute(mine.id)
	local dist = nearestRare(root.Position, spec.range)
	local vein = player:GetAttribute("CanaryVeinDistance")

	exitPos = if typeof(collapseAt) == "number" and level >= Economy.CANARY_PERKS.guide then nearestExit(mine.id, root.Position) else nil
	if typeof(collapseAt) == "number" then
		label.Text = if exitPos then "🐤 불안해요! 출구로 안내할게요" else "🐤 카나리아가 불안해해요! 어서 나가요"
		label.TextColor3 = Color3.fromRGB(255, 110, 100)
		blinkSpeed = 14
		mood, chirpGap = "anxious", 0.7
	elseif typeof(vein) == "number" and (not dist or vein < dist) then
		label.Text = `🐤 짹짹! 희귀 광맥이 {vein}m 안에 있어요. 그쪽을 파 보세요`
		label.TextColor3 = Color3.fromRGB(255, 220, 90)
		blinkSpeed = 4 + 12 * (1 - math.min(vein / spec.range, 1))
		mood, chirpGap = "chirp", 0.6 + 2.4 * math.min(vein / spec.range, 1)
	elseif dist then
		label.Text = `🐤 짹짹! 희귀 광물이 {math.floor(dist)}m 안에 있어요`
		label.TextColor3 = Color3.fromRGB(255, 220, 90)
		-- 가까울수록 빨리 깜빡여서 방향을 찾게 한다
		blinkSpeed = 4 + 12 * (1 - dist / spec.range)
		mood, chirpGap = "chirp", 0.6 + 2.4 * dist / spec.range
	else
		label.Text = `🐤 조용해요 · 탐지 {spec.range}m`
		label.TextColor3 = Color3.fromRGB(200, 200, 200)
		blinkSpeed = 0
		mood = "quiet"
	end
end
