--!strict
-- 붕괴 카운트다운 HUD (C 담당, D-013)
-- 경보 중인 광산 안에 있을 때만 화면 위쪽에 "붕괴까지 0:42"를 크게 띄운다.
-- 남은 시간이 dangerSeconds 아래면 빨갛게 깜빡여서 "지금 나가야 한다"를 느끼게 한다.
--
-- 데이터: 서버 Collapse.luau 가 ReplicatedStorage.CollapseState 의 속성 <광산 id> 에 붕괴 시각을 올린다
--         (경보 중일 때만 값이 있고, 시각은 workspace:GetServerTimeNow() 기준이라 클라이언트 시계와 맞음).
-- 숫자·색은 Config/Social.luau 의 CollapseHud.

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local Shared = RS:WaitForChild("Shared")
local Mines = require(Shared:WaitForChild("Config"):WaitForChild("Mines"))
local Social = require(Shared:WaitForChild("Config"):WaitForChild("Social"))
local CONFIG = Social.CollapseHud

local player = Players.LocalPlayer
local stateFolder = RS:WaitForChild("CollapseState")

-- UI (코드로 만들어서 Studio 수작업 없이 Rojo 만으로 동작하게)
local gui = Instance.new("ScreenGui")
gui.Name = "CollapseHud"
gui.ResetOnSpawn = false
gui.DisplayOrder = CONFIG.displayOrder
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local label = Instance.new("TextLabel")
label.Name = "Countdown"
label.AnchorPoint = Vector2.new(0.5, 0)
label.Position = UDim2.new(0.5, 0, 0, CONFIG.topMargin)
label.Size = UDim2.new(0, 0, 0, 0)
label.AutomaticSize = Enum.AutomaticSize.XY
label.BackgroundTransparency = 1
label.Font = Enum.Font.GothamBlack
label.TextColor3 = CONFIG.color
label.Parent = gui

local stroke = Instance.new("UIStroke")
stroke.Thickness = CONFIG.strokeThickness
stroke.Color = CONFIG.strokeColor
stroke.Parent = label

local function fitToScreen()
	local w = workspace.CurrentCamera.ViewportSize.X
	label.TextSize = if w < Social.Banner.smallScreenWidth then CONFIG.textSizeSmall else CONFIG.textSize
end
fitToScreen()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitToScreen)

-- 42 → "0:42"
local function formatTime(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", s // 60, s % 60)
end

-- 지금 내가 있는 광산 (광산 밖이면 nil)
local function currentMine(): Mines.Mine?
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root and Mines.findAreaAt(root.Position) -- 출구 굴(지표 위)에서도 계속 보이게
end

while true do
	task.wait(CONFIG.updateInterval)

	local mine = currentMine()
	local collapseAt = mine and stateFolder:GetAttribute(mine.id)
	if typeof(collapseAt) ~= "number" then
		gui.Enabled = false
		continue
	end

	local remaining = collapseAt - workspace:GetServerTimeNow()
	label.Text = `⚠️ 붕괴까지 {formatTime(remaining)}`
	if remaining <= CONFIG.dangerSeconds then
		-- 위험 구간: 빨강 + 깜빡임 (투명도를 사인파로 흔든다)
		label.TextColor3 = CONFIG.dangerColor
		label.TextTransparency = 0.35 * (1 + math.sin(os.clock() * CONFIG.pulseSpeed)) / 2
	else
		label.TextColor3 = CONFIG.color
		label.TextTransparency = 0
	end
	gui.Enabled = true
end
