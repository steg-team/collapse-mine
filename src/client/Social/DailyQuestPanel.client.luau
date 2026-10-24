--!strict
-- 일일 퀘스트 창 (C 담당, D-032)
-- 화면 왼쪽 📜 버튼(📅·🚀 아래) → 오늘 퀘스트 3개, 진행 막대, "받기" 버튼.
-- 받을 퀘스트가 있으면 버튼에 빨간 점 (서버가 올리는 플레이어 속성 QuestClaimable).
-- 판정·저장은 서버(DailyQuest.luau). 숫자·색은 Config/Social.luau 의 DailyQuest (버튼 모양은 DailyLogin 과 같게).

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local Social = require(RS:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Social"))
local CONFIG = Social.DailyQuest
local LOOK = Social.DailyLogin -- 버튼·창 색과 크기를 출석과 맞춤
local remote = RS:WaitForChild("Remotes"):WaitForChild("DailyQuest") :: RemoteFunction
local player = Players.LocalPlayer

type QuestView = { id: string, text: string, progress: number, target: number, reward: number, claimed: boolean }
type View = { quests: { QuestView }, nextDayAt: number }

local function corner(parent: Instance, r: number)
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r); c.Parent = parent
end

local function text(parent: Instance, s: string, size: number, font: Enum.Font?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = font or Enum.Font.GothamBold
	l.TextSize = size
	l.TextColor3 = Color3.new(1, 1, 1)
	l.Text = s
	l.Parent = parent
	return l
end

local gui = Instance.new("ScreenGui")
gui.Name = "DailyQuest"
gui.ResetOnSpawn = false
gui.DisplayOrder = LOOK.displayOrder
gui.Parent = player:WaitForChild("PlayerGui")

-- 왼쪽 버튼
local openButton = Instance.new("TextButton")
openButton.AnchorPoint = Vector2.new(0, 0.5)
openButton.Position = UDim2.new(0, LOOK.buttonMargin, 0.5, CONFIG.buttonOffset)
openButton.Size = UDim2.fromOffset(LOOK.buttonSize, LOOK.buttonSize)
openButton.BackgroundColor3 = LOOK.panelColor
openButton.Text = "📜"
openButton.TextSize = LOOK.titleSize
openButton.Parent = gui
corner(openButton, LOOK.cornerRadius)

local dot = Instance.new("Frame")
dot.Size = UDim2.fromOffset(12, 12)
dot.Position = UDim2.new(1, -10, 0, -2)
dot.BackgroundColor3 = Color3.fromRGB(230, 50, 40)
dot.Visible = false
dot.Parent = openButton
corner(dot, 6)

local function updateDot()
	dot.Visible = (player:GetAttribute("QuestClaimable") or 0) > 0
end
player:GetAttributeChangedSignal("QuestClaimable"):Connect(updateDot)
updateDot()

-- 창
local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(CONFIG.width, 0)
panel.AutomaticSize = Enum.AutomaticSize.Y
panel.BackgroundColor3 = LOOK.panelColor
panel.Visible = false
panel.Parent = gui
corner(panel, LOOK.cornerRadius)
local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0, 12); pad.PaddingBottom = UDim.new(0, 16)
pad.PaddingLeft = UDim.new(0, 16); pad.PaddingRight = UDim.new(0, 16)
pad.Parent = panel
local layout = Instance.new("UIListLayout"); layout.Padding = UDim.new(0, 8); layout.SortOrder = Enum.SortOrder.LayoutOrder; layout.Parent = panel
local scale = Instance.new("UIScale"); scale.Parent = panel
local function fitToScreen()
	scale.Scale = math.min(1, (workspace.CurrentCamera.ViewportSize.X - 24) / CONFIG.width)
end
fitToScreen()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitToScreen)

local titleBar = Instance.new("Frame")
titleBar.LayoutOrder = 0
titleBar.BackgroundTransparency = 1
titleBar.Size = UDim2.new(1, 0, 0, 36)
titleBar.Parent = panel
local title = text(titleBar, "오늘의 퀘스트", LOOK.titleSize)
title.Size = UDim2.fromScale(1, 1)
local closeButton = Instance.new("TextButton")
closeButton.AnchorPoint = Vector2.new(1, 0)
closeButton.Position = UDim2.fromScale(1, 0)
closeButton.Size = UDim2.fromOffset(32, 32)
closeButton.BackgroundTransparency = 1
closeButton.Text = "X" -- ✕ 는 폰트에 없어서 깨짐
closeButton.TextSize = LOOK.titleSize
closeButton.TextColor3 = Color3.new(1, 1, 1)
closeButton.Parent = titleBar

local footer = text(panel, "", LOOK.textSize - 2, Enum.Font.Gotham)
footer.LayoutOrder = 100
footer.Size = UDim2.new(1, 0, 0, 20)
footer.TextColor3 = Color3.fromRGB(180, 180, 180)

local rows: { Frame } = {}
local current: View? = nil
local busy = false
local render: () -> () -- 아래에서 정의 (줄의 받기 버튼이 먼저 참조하므로 미리 선언)

local function call(action: string, questId: string?): View?
	local ok, result = pcall(remote.InvokeServer, remote, action, questId)
	if ok and typeof(result) == "table" then return result :: View end
	return nil
end

local function makeRow(i: number): Frame
	local row = Instance.new("Frame")
	row.LayoutOrder = i
	row.Size = UDim2.new(1, 0, 0, CONFIG.rowHeight)
	row.BackgroundColor3 = LOOK.cellColor
	row.Parent = panel
	corner(row, 8)

	local name = text(row, "", LOOK.textSize)
	name.Name = "Name"
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Position = UDim2.fromOffset(12, 8)
	name.Size = UDim2.new(1, -130, 0, 20)

	local barBack = Instance.new("Frame")
	barBack.Name = "BarBack"
	barBack.Position = UDim2.fromOffset(12, 36)
	barBack.Size = UDim2.new(1, -130, 0, 14)
	barBack.BackgroundColor3 = Color3.fromRGB(30, 26, 22)
	barBack.Parent = row
	corner(barBack, 7)
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.Size = UDim2.fromScale(0, 1)
	bar.BackgroundColor3 = CONFIG.barColor
	bar.Parent = barBack
	corner(bar, 7)
	local count = text(barBack, "", LOOK.textSize - 4)
	count.Name = "Count"
	count.Size = UDim2.fromScale(1, 1)

	local claim = Instance.new("TextButton")
	claim.Name = "Claim"
	claim.AnchorPoint = Vector2.new(1, 0.5)
	claim.Position = UDim2.new(1, -10, 0.5, 0)
	claim.Size = UDim2.fromOffset(106, 40)
	claim.Font = Enum.Font.GothamBold
	claim.TextSize = LOOK.textSize - 2
	claim.TextColor3 = Color3.new(1, 1, 1)
	claim.Parent = row
	corner(claim, 8)
	claim.Activated:Connect(function()
		local q = current and current.quests[i]
		if busy or not q or q.claimed or q.progress < q.target then return end
		busy = true
		current = call("claim", q.id) or current
		busy = false
		render()
	end)
	return row
end

local function hoursLeft(t: number): string
	local sec = math.max(0, t - os.time())
	return `{sec // 3600}시간 {sec % 3600 // 60}분`
end

render = function()
	local v = current
	if not v then return end
	for i, q in v.quests do
		local row = rows[i] or makeRow(i)
		rows[i] = row
		row.Visible = true
		local done = q.progress >= q.target
		;(row:FindFirstChild("Name") :: TextLabel).Text = q.text
		local barBack = row:FindFirstChild("BarBack") :: Frame
		;(barBack:FindFirstChild("Bar") :: Frame).Size = UDim2.fromScale(math.clamp(q.progress / q.target, 0, 1), 1)
		;(barBack:FindFirstChild("Bar") :: Frame).BackgroundColor3 = if done then CONFIG.doneColor else CONFIG.barColor
		;(barBack:FindFirstChild("Count") :: TextLabel).Text = `{q.progress} / {q.target}`
		local claim = row:FindFirstChild("Claim") :: TextButton
		if q.claimed then
			claim.Text = "✓ 받음"
			claim.BackgroundColor3 = LOOK.claimedColor
			claim.AutoButtonColor = false
		elseif done then
			claim.Text = `받기 💰{q.reward}`
			claim.BackgroundColor3 = LOOK.buttonColor
			claim.AutoButtonColor = true
		else
			claim.Text = `💰{q.reward}`
			claim.BackgroundColor3 = LOOK.disabledColor
			claim.AutoButtonColor = false
		end
	end
	for i = #v.quests + 1, #rows do rows[i].Visible = false end
	footer.Text = `새 퀘스트까지 {hoursLeft(v.nextDayAt)}`
end

openButton.Activated:Connect(function()
	panel.Visible = not panel.Visible
	if panel.Visible then
		current = call("get") or current
		render()
	end
end)
closeButton.Activated:Connect(function() panel.Visible = false end)

-- 창이 열려 있는 동안 진행도를 다시 읽는다 (캐는 중에 열어 두고 볼 수 있게)
while true do
	task.wait(CONFIG.refreshInterval)
	if panel.Visible and not busy then
		current = call("get") or current
		render()
	end
end
