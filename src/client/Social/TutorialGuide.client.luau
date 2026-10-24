--!strict
-- 튜토리얼 안내 UI (C 담당, D-031)
-- 서버(Tutorial.luau)가 알려준 단계의 문구를 화면 위쪽에 띄우고, 목표 지점 위에 화살표 + 테두리 강조를 붙인다.
-- 단계 판정은 서버. 여기서는 그리기와 "알겠어요"·"건너뛰기" 버튼만.
-- 숫자·문구는 Config/Social.luau 의 Tutorial.

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local CS = game:GetService("CollectionService")

local Shared = RS:WaitForChild("Shared")
local Social = require(Shared:WaitForChild("Config"):WaitForChild("Social"))
local Mines = require(Shared:WaitForChild("Config"):WaitForChild("Mines"))
local CONFIG = Social.Tutorial
local remote = RS:WaitForChild("Remotes"):WaitForChild("Tutorial") :: RemoteEvent
local player = Players.LocalPlayer

local FIRST_MINE = Mines.list[1].id -- 튜토리얼은 첫 광산(기본 광산)으로 안내

-- ───── 안내판 ─────
local gui = Instance.new("ScreenGui")
gui.Name = "Tutorial"
gui.ResetOnSpawn = false
gui.DisplayOrder = CONFIG.displayOrder
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0)
panel.Position = UDim2.new(0.5, 0, 0, CONFIG.topMargin)
panel.Size = UDim2.fromOffset(CONFIG.width, 0)
panel.AutomaticSize = Enum.AutomaticSize.Y
panel.BackgroundColor3 = CONFIG.panelColor
panel.BackgroundTransparency = 0.1
panel.Parent = gui
local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, CONFIG.cornerRadius); corner.Parent = panel
local stroke = Instance.new("UIStroke"); stroke.Color = CONFIG.accentColor; stroke.Thickness = 2; stroke.Parent = panel
local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0, CONFIG.padding); pad.PaddingBottom = UDim.new(0, CONFIG.padding)
pad.PaddingLeft = UDim.new(0, CONFIG.padding); pad.PaddingRight = UDim.new(0, CONFIG.padding)
pad.Parent = panel
local layout = Instance.new("UIListLayout"); layout.Padding = UDim.new(0, 8); layout.SortOrder = Enum.SortOrder.LayoutOrder; layout.Parent = panel
-- 폰처럼 좁은 화면에서는 판을 줄인다
local scale = Instance.new("UIScale"); scale.Parent = panel
local function fitToScreen()
	scale.Scale = math.min(1, (workspace.CurrentCamera.ViewportSize.X - 24) / CONFIG.width)
end
fitToScreen()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitToScreen)

local function label(order: number, size: number, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.LayoutOrder = order
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(1, 0, 0, 0)
	l.AutomaticSize = Enum.AutomaticSize.Y
	l.TextWrapped = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Font = Enum.Font.GothamBold
	l.TextSize = size
	l.TextColor3 = color
	l.Parent = panel
	return l
end
local header = label(1, CONFIG.textSize - 4, CONFIG.accentColor)
local body = label(2, CONFIG.textSize, Color3.new(1, 1, 1))

local buttons = Instance.new("Frame")
buttons.LayoutOrder = 3
buttons.BackgroundTransparency = 1
buttons.Size = UDim2.new(1, 0, 0, 34)
buttons.Parent = panel

local function button(text: string, x: number, anchorX: number, color: Color3): TextButton
	local b = Instance.new("TextButton")
	b.AnchorPoint = Vector2.new(anchorX, 0)
	b.Position = UDim2.fromScale(x, 0)
	b.Size = UDim2.fromOffset(120, 34)
	b.BackgroundColor3 = color
	b.Font = Enum.Font.GothamBold
	b.TextSize = CONFIG.textSize - 2
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Text = text
	b.Parent = buttons
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 8); c.Parent = b
	return b
end
local skipButton = button("건너뛰기", 0, 0, Color3.fromRGB(80, 80, 80))
local okButton = button("알겠어요", 1, 1, Color3.fromRGB(200, 140, 30))

skipButton.Activated:Connect(function() remote:FireServer("skip") end)
okButton.Activated:Connect(function() remote:FireServer("next") end)

-- ───── 목표 표시 (화살표 + 테두리 강조) ─────
local highlight = Instance.new("Highlight")
highlight.FillTransparency = 1
highlight.OutlineColor = CONFIG.accentColor
highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop -- 벽 너머에서도 보이게
highlight.Enabled = false
highlight.Parent = gui -- Adornee 로 대상 지정

local marker = Instance.new("BillboardGui")
marker.Size = UDim2.fromOffset(60, 60)
marker.AlwaysOnTop = true
marker.StudsOffset = Vector3.new(0, CONFIG.markerHeight, 0)
marker.Enabled = false
marker.Parent = gui
local arrow = Instance.new("TextLabel")
arrow.Size = UDim2.fromScale(1, 1)
arrow.BackgroundTransparency = 1
arrow.Text = "⬇"
arrow.TextScaled = true
arrow.TextColor3 = CONFIG.accentColor
arrow.Parent = marker

local function rootPos(): Vector3?
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root and root.Position
end

-- 목록 중 가장 가까운 것
local function nearest(list: { Instance }): Instance?
	local pos = rootPos()
	if not pos then return list[1] end
	local best, bestDist = nil, math.huge
	for _, inst in list do
		local p = if inst:IsA("BasePart") then inst.Position elseif inst:IsA("Model") then inst:GetPivot().Position else nil
		if p and (p - pos).Magnitude < bestDist then
			best, bestDist = inst, (p - pos).Magnitude
		end
	end
	return best
end

-- 기본 광산으로 가는 허브 포탈 (태그 MinePortal, 속성 MineId)
local function findPortal(): Instance?
	local list = {}
	for _, p in CS:GetTagged("MinePortal") do
		if p:GetAttribute("MineId") == FIRST_MINE then table.insert(list, p) end
	end
	return nearest(list)
end

-- 광산 안이면 그 광산 출구, 허브면 판매소 Counter
local function findSell(): Instance?
	local pos = rootPos()
	local mine = pos and Mines.findAreaAt(pos)
	if mine then
		local folder = workspace:FindFirstChild("Mines") and workspace.Mines:FindFirstChild(mine.id)
		return folder and (folder:FindFirstChild("ExitGate") or folder:FindFirstChild("ExitPoint"))
	end
	local list = {}
	for _, hub in workspace:GetChildren() do
		if hub.Name:sub(1, 12) == "CollapseMine" then
			local shop = hub:FindFirstChild("Hub") and hub.Hub:FindFirstChild("Shop")
			local counter = shop and shop:FindFirstChild("Counter")
			if counter then table.insert(list, counter) end
		end
	end
	return nearest(list)
end

local current: Social.TutorialStep? = nil

local function updateTarget()
	local target: Instance? = nil
	if current and current.target == "portal" then target = findPortal()
	elseif current and current.target == "sell" then target = findSell() end
	highlight.Adornee = target
	highlight.Enabled = target ~= nil
	marker.Adornee = target
	marker.Enabled = target ~= nil
end

remote.OnClientEvent:Connect(function(step: any, total: any)
	if typeof(step) ~= "number" or typeof(total) ~= "number" then return end
	local s = CONFIG.steps[step]
	current = s
	if not s then -- 끝
		gui.Enabled = false
		updateTarget()
		return
	end
	header.Text = `튜토리얼 {step}/{total}`
	body.Text = s.text
	okButton.Visible = s.manual == true
	gui.Enabled = true
	updateTarget()
end)

-- 걸어 다니는 동안 목표를 다시 고른다 (광산에 들어가면 판매소 대신 출구로 등). 화살표는 살짝 위아래로
while true do
	task.wait(0.5)
	if current then
		updateTarget()
		marker.StudsOffset = Vector3.new(0, CONFIG.markerHeight + math.sin(os.clock() * 4) * 0.6, 0)
	end
end
