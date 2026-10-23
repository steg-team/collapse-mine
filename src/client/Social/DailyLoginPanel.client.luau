--!strict
-- 출석판 UI (C 담당, D-016)
-- 화면 왼쪽 📅 버튼을 누르면 7칸 출석판이 열리고, 오늘 칸의 "받기"로 보상을 받는다.
-- 받을 보상이 있으면 접속하자마자 자동으로 열린다 (openOnJoin).
-- 판정·저장은 전부 서버(DailyLogin.luau). 클라이언트는 그리기만 한다.
-- 숫자·색은 Config/Social.luau 의 DailyLogin.

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local Social = require(RS:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Social"))
local CONFIG = Social.DailyLogin
local remote = RS:WaitForChild("Remotes"):WaitForChild("DailyLogin") :: RemoteFunction
local player = Players.LocalPlayer

type State = { day: number, canClaim: boolean, rewards: { number }, nextDayAt: number }

local function corner(parent: Instance, r: number?)
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or CONFIG.cornerRadius); c.Parent = parent
end

local function text(parent: Instance, s: string, size: number): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamBold
	l.TextSize = size
	l.TextColor3 = Color3.new(1, 1, 1)
	l.Text = s
	l.Parent = parent
	return l
end

-- ───── UI 만들기 ─────
local gui = Instance.new("ScreenGui")
gui.Name = "DailyLogin"
gui.ResetOnSpawn = false
gui.DisplayOrder = CONFIG.displayOrder
gui.Parent = player:WaitForChild("PlayerGui")

-- 왼쪽 열기 버튼
local openButton = Instance.new("TextButton")
openButton.Name = "Open"
openButton.AnchorPoint = Vector2.new(0, 0.5)
openButton.Position = UDim2.new(0, CONFIG.buttonMargin, 0.5, 0)
openButton.Size = UDim2.fromOffset(CONFIG.buttonSize, CONFIG.buttonSize)
openButton.BackgroundColor3 = CONFIG.panelColor
openButton.Text = "📅"
openButton.TextSize = CONFIG.titleSize
openButton.Parent = gui
corner(openButton)

-- 빨간 점: 받을 보상이 있다는 표시
local dot = Instance.new("Frame")
dot.Size = UDim2.fromOffset(12, 12)
dot.Position = UDim2.new(1, -10, 0, -2)
dot.BackgroundColor3 = Color3.fromRGB(230, 50, 40)
dot.Visible = false
dot.Parent = openButton
corner(dot, 6)

-- 출석판
local cols = #CONFIG.rewards
local panelWidth = cols * CONFIG.cellWidth + (cols - 1) * CONFIG.cellGap + CONFIG.panelPadding * 2
local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(panelWidth, CONFIG.cellHeight + 140)
panel.BackgroundColor3 = CONFIG.panelColor
panel.Visible = false
panel.Parent = gui
corner(panel)
-- 폰처럼 좁은 화면에서는 판 전체를 줄인다
local scale = Instance.new("UIScale"); scale.Parent = panel
local function fitToScreen()
	local w = workspace.CurrentCamera.ViewportSize.X
	scale.Scale = math.min(1, (w - 24) / panelWidth)
end
fitToScreen()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitToScreen)

local title = text(panel, "출석 보상", CONFIG.titleSize)
title.Size = UDim2.new(1, 0, 0, 40)
title.Position = UDim2.fromOffset(0, 8)

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.fromOffset(32, 32)
closeButton.Position = UDim2.new(1, -40, 0, 8)
closeButton.BackgroundTransparency = 1
closeButton.Text = "X" -- ✕ 기호도 폰트에 없어서 깨짐
closeButton.TextSize = CONFIG.titleSize
closeButton.TextColor3 = Color3.new(1, 1, 1)
closeButton.Parent = panel

local cells: { { frame: Frame, stroke: UIStroke, status: TextLabel } } = {}
for i, coins in CONFIG.rewards do
	local cell = Instance.new("Frame")
	cell.Size = UDim2.fromOffset(CONFIG.cellWidth, CONFIG.cellHeight)
	cell.Position = UDim2.fromOffset(CONFIG.panelPadding + (i - 1) * (CONFIG.cellWidth + CONFIG.cellGap), 56)
	cell.BackgroundColor3 = CONFIG.cellColor
	cell.Parent = panel
	corner(cell, 8)
	local stroke = Instance.new("UIStroke"); stroke.Thickness = 3; stroke.Transparency = 1; stroke.Parent = cell
	local dayLabel = text(cell, `{i}일차`, CONFIG.textSize - 2)
	dayLabel.Size = UDim2.new(1, 0, 0, 24); dayLabel.Position = UDim2.fromOffset(0, 4)
	-- 🪙(코인 이모지)는 로블록스 폰트에 없어서 □로 깨짐 → 오래된 이모지 💰 사용
	local coinLabel = text(cell, `💰\n{coins}`, CONFIG.textSize)
	coinLabel.Size = UDim2.new(1, 0, 0, 40); coinLabel.Position = UDim2.fromOffset(0, 28)
	local status = text(cell, "", CONFIG.textSize)
	status.Size = UDim2.new(1, 0, 0, 20); status.Position = UDim2.new(0, 0, 1, -24)
	cells[i] = { frame = cell, stroke = stroke, status = status }
end

local claimButton = Instance.new("TextButton")
claimButton.AnchorPoint = Vector2.new(0.5, 1)
claimButton.Position = UDim2.new(0.5, 0, 1, -16)
claimButton.Size = UDim2.fromOffset(180, 44)
claimButton.Font = Enum.Font.GothamBold
claimButton.TextSize = CONFIG.titleSize - 2
claimButton.TextColor3 = Color3.new(1, 1, 1)
claimButton.Parent = panel
corner(claimButton, 10)

-- ───── 상태 그리기 ─────
local state: State? = nil

local function hoursLeft(nextDayAt: number): string
	local sec = math.max(0, nextDayAt - os.time())
	return `{sec // 3600}시간 {sec % 3600 // 60}분`
end

local function render()
	local s = state
	if not s then return end
	dot.Visible = s.canClaim
	-- 오늘까지 받은 칸: 오늘 받았으면 day 까지, 아직이면 day-1 까지
	local claimedUpTo = if s.canClaim then s.day - 1 else s.day
	for i, c in cells do
		local claimed = i <= claimedUpTo
		local isToday = i == s.day
		c.frame.BackgroundColor3 = if claimed then CONFIG.claimedColor else CONFIG.cellColor
		c.status.Text = if claimed then "✓" else ""
		c.stroke.Color = CONFIG.todayColor
		c.stroke.Transparency = if isToday and s.canClaim then 0 else 1
	end
	if s.canClaim then
		claimButton.Text = `{s.day}일차 받기`
		claimButton.BackgroundColor3 = CONFIG.buttonColor
		claimButton.AutoButtonColor = true
	else
		claimButton.Text = `다음 보상까지 {hoursLeft(s.nextDayAt)}`
		claimButton.BackgroundColor3 = CONFIG.disabledColor
		claimButton.AutoButtonColor = false
	end
end

local function fetch(action: string): State?
	local ok, result = pcall(remote.InvokeServer, remote, action)
	if ok and typeof(result) == "table" then return result :: State end
	return nil
end

local function refresh()
	state = fetch("get") or state
	render()
end

openButton.Activated:Connect(function()
	panel.Visible = not panel.Visible
	if panel.Visible then refresh() end
end)
closeButton.Activated:Connect(function() panel.Visible = false end)

local claiming = false
claimButton.Activated:Connect(function()
	if claiming or not (state and state.canClaim) then return end
	claiming = true
	state = fetch("claim") or state
	render()
	claiming = false
end)

-- 접속 직후: 저장 데이터가 로드될 때까지 몇 번 물어본다 (로드 전엔 서버가 nil)
task.spawn(function()
	for _ = 1, 20 do
		local s = fetch("get")
		if s then
			state = s
			render()
			if s.canClaim and CONFIG.openOnJoin then panel.Visible = true end
			return
		end
		task.wait(1)
	end
end)

-- 열려 있는 동안 "다음 보상까지 n시간" 갱신 + 날이 바뀌면 다시 받기 가능 상태로
while true do
	task.wait(30)
	if state and not state.canClaim and os.time() >= state.nextDayAt then
		refresh()
	elseif panel.Visible then
		render()
	end
end
