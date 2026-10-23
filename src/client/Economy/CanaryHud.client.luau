--!strict
-- 광산 카나리아 HUD (B 담당, D-023)
-- 화면 오른쪽에 카나리아 상태 한 줄. 광산 안에서만 보인다.
--   - 희귀 이상 광물이 탐지 범위 안에 있으면 "짹짹!" + 거리 (가까울수록 빨리 깜빡임)
--   - 내가 있는 광산이 붕괴 경보 중이면 불안해한다 (C의 ReplicatedStorage.CollapseState, CollapseHud와 같은 출처)
-- 광석은 원래 클라이언트에도 보이는 파트라, 탐지를 클라이언트에서 해도 새로 드러나는 정보가 없다 (보상과 무관한 힌트).

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

-- 깜빡임 속도 (0이면 안 깜빡임). 상태는 UPDATE마다, 깜빡임은 매 프레임
local blinkSpeed = 0
RunService.Heartbeat:Connect(function()
	label.TextTransparency = if blinkSpeed > 0 then 0.4 * (1 + math.sin(os.clock() * blinkSpeed)) / 2 else 0
end)

while true do
	task.wait(UPDATE)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local mine = root and Mines.findAreaAt(root.Position)
	if not root or not mine then
		gui.Enabled = false
		continue
	end
	gui.Enabled = true

	local level = player:GetAttribute("CanaryLevel") or 0
	local spec = Economy.CANARY[level] or Economy.CANARY[0]
	local collapseAt = stateFolder:GetAttribute(mine.id)
	local dist = nearestRare(root.Position, spec.range)

	if typeof(collapseAt) == "number" then
		label.Text = "🐤 카나리아가 불안해해요! 어서 나가요"
		label.TextColor3 = Color3.fromRGB(255, 110, 100)
		blinkSpeed = 14
	elseif dist then
		label.Text = `🐤 짹짹! 희귀 광물이 {math.floor(dist)}m 안에 있어요`
		label.TextColor3 = Color3.fromRGB(255, 220, 90)
		-- 가까울수록 빨리 깜빡여서 방향을 찾게 한다
		blinkSpeed = 4 + 12 * (1 - dist / spec.range)
	else
		label.Text = `🐤 조용해요 · 탐지 {spec.range}m`
		label.TextColor3 = Color3.fromRGB(200, 200, 200)
		blinkSpeed = 0
	end
end
