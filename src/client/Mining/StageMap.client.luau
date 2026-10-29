--!strict
-- 광산 지도 (A, D-042) — 화면 왼쪽 🗺️ 버튼 → 스테이지 카드 → 누르면 그 스테이지 허브로 이동
-- - 카드: 이름, 필요한 곡괭이, 대표 광물, 지금 있는 곳 / 잠김 표시. 아직 없는 광산(Mines.UPCOMING)도 잠긴 카드로
-- - 광산 안에서는 버튼이 흐려지고 못 쓴다 (서버도 다시 막음)
-- - 이동 판정은 서버(Remotes.StageTravel). 여기서는 보여 주기만
-- 버튼 모양은 다른 왼쪽 버튼과 같게 C의 Social.DailyLogin 모양 설정을 읽는다

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local Config = RS:WaitForChild("Shared"):WaitForChild("Config")
local Mines = require(Config:WaitForChild("Mines"))
local Social = require(Config:WaitForChild("Social"))
local Pickaxe = require(Config:WaitForChild("Pickaxe"))
local LOOK = Social.DailyLogin
local remote = RS:WaitForChild("Remotes"):WaitForChild("StageTravel") :: RemoteFunction
local player = Players.LocalPlayer

local GOLD = Color3.fromRGB(255, 200, 60)
local TEXT = Color3.fromRGB(240, 232, 220)
local DIM = Color3.fromRGB(150, 140, 128)
local CARD = Color3.fromRGB(48, 42, 36)
local CARD_LOCKED = Color3.fromRGB(34, 31, 28)

local gui = Instance.new("ScreenGui")
gui.Name = "StageMap"
gui.ResetOnSpawn = false
gui.DisplayOrder = LOOK.displayOrder
gui.Parent = player:WaitForChild("PlayerGui")

local function corner(p: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = p
end

local function label(parent: Instance, text: string, size: number, color: Color3, bold: boolean?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(1, 0, 0, size + 6)
	l.Font = if bold then Enum.Font.GothamBold else Enum.Font.Gotham
	l.TextSize = size
	l.TextColor3 = color
	l.TextWrapped = true
	l.Text = text
	l.Parent = parent
	return l
end

-- 왼쪽 버튼 (📅 🚀 📜 👥 아래)
local button = Instance.new("TextButton")
button.Name = "MapButton"
button.AnchorPoint = Vector2.new(0, 0.5)
button.Position = UDim2.new(0, LOOK.buttonMargin, 0.5, Mines.STAGE_MAP.buttonOffset)
button.Size = UDim2.fromOffset(LOOK.buttonSize, LOOK.buttonSize)
button.BackgroundColor3 = LOOK.panelColor
button.Text = "🗺️"
button.TextSize = LOOK.titleSize
button.Parent = gui
corner(button, LOOK.cornerRadius)

-- 지도 창
local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.new(0.9, 0, 0, 300)
panel.BackgroundColor3 = LOOK.panelColor
panel.Visible = false
panel.Parent = gui
corner(panel, LOOK.cornerRadius)
local limit = Instance.new("UISizeConstraint")
limit.MaxSize = Vector2.new(820, 300)
limit.Parent = panel

local title = label(panel, "🗺️ 광산 지도", 22, TEXT, true)
title.Position = UDim2.fromOffset(0, 12)

local close = Instance.new("TextButton")
close.AnchorPoint = Vector2.new(1, 0)
close.Position = UDim2.new(1, -10, 0, 10)
close.Size = UDim2.fromOffset(34, 34)
close.BackgroundTransparency = 1
close.Text = "X" -- ✕는 기본 글꼴에 없어서 네모로 보임
close.TextSize = 22
close.TextColor3 = TEXT
close.Font = Enum.Font.GothamBold
close.Parent = panel

-- 카드 줄 (가로로, 좁은 화면이면 옆으로 밀어서 봄)
local row = Instance.new("ScrollingFrame")
row.Position = UDim2.fromOffset(14, 52)
row.Size = UDim2.new(1, -28, 0, 196)
row.BackgroundTransparency = 1
row.BorderSizePixel = 0
row.ScrollingDirection = Enum.ScrollingDirection.X
row.AutomaticCanvasSize = Enum.AutomaticSize.X
row.CanvasSize = UDim2.new()
row.ScrollBarThickness = 4
row.Parent = panel
local list = Instance.new("UIListLayout")
list.FillDirection = Enum.FillDirection.Horizontal
list.Padding = UDim.new(0, 10)
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Parent = row

local notice = label(panel, "", 16, GOLD)
notice.AnchorPoint = Vector2.new(0, 1)
notice.Position = UDim2.new(0, 0, 1, -14)

-- 지금 있는 스테이지 (서 있는 허브의 x로 가장 가까운 스테이지 허브를 찾음)
local function currentStage(): string?
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then return nil end
	local best, bd = nil, math.huge
	for _, m in Mines.list do
		local folder = m.hub and workspace:FindFirstChild(m.hub)
		local sp = folder and folder:FindFirstChild("Hub") and folder.Hub:FindFirstChild("MineSpawn")
		if sp and sp:IsA("BasePart") then
			local d = (sp.Position - root.Position).Magnitude
			if d < bd then best, bd = m.id, d end
		end
	end
	return if bd < 250 then best else nil
end

local function insideMine(): boolean
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root ~= nil and Mines.findAreaAt(root.Position) ~= nil
end

local busy = false

local function makeCard(order: number, name: string, needTier: number, hint: string, mineId: string?)
	local tier = tonumber(player:GetAttribute("PickaxeTier")) or 1
	local locked = mineId == nil or tier < needTier
	local here = mineId ~= nil and currentStage() == mineId

	local card = Instance.new("TextButton")
	card.LayoutOrder = order
	card.Size = UDim2.fromOffset(150, 186)
	card.BackgroundColor3 = if locked then CARD_LOCKED else CARD
	card.AutoButtonColor = not locked and not here
	card.Text = ""
	card.Parent = row
	corner(card, 10)
	if here then
		local stroke = Instance.new("UIStroke")
		stroke.Color = GOLD
		stroke.Thickness = 2
		stroke.Parent = card
	end
	local pad = Instance.new("UIPadding")
	pad.PaddingTop, pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 10), UDim.new(0, 8), UDim.new(0, 8)
	pad.Parent = card
	local inner = Instance.new("UIListLayout")
	inner.Padding = UDim.new(0, 4)
	inner.SortOrder = Enum.SortOrder.LayoutOrder
	inner.Parent = card

	label(card, `{order}스테이지`, 13, DIM).LayoutOrder = 1
	label(card, (if locked then "🔒 " else "") .. name, 18, if locked then DIM else TEXT, true).LayoutOrder = 2
	label(card, Pickaxe.name(needTier), 14, if tier >= needTier then GOLD else DIM).LayoutOrder = 3
	local h = label(card, hint, 13, DIM)
	h.LayoutOrder = 4
	h.Size = UDim2.new(1, 0, 0, 64)
	h.TextYAlignment = Enum.TextYAlignment.Top
	local status = label(card, if here then "📍 지금 여기" elseif mineId == nil then "준비 중" elseif locked then "곡괭이가 모자라요" else "눌러서 이동", 14, if here then GOLD elseif locked then DIM else TEXT, true)
	status.LayoutOrder = 5

	card.Activated:Connect(function()
		if busy then return end
		if mineId == nil then
			notice.Text = `{name}은(는) 아직 준비 중이에요`
			return
		end
		if here then
			notice.Text = "지금 이 광산 허브에 있어요"
			return
		end
		busy = true
		notice.Text = "이동 중…"
		local ok, res = pcall(function() return remote:InvokeServer(mineId) end)
		busy = false
		if ok and typeof(res) == "table" then
			notice.Text = tostring(res.message or "")
			if res.ok then panel.Visible = false end
		else
			notice.Text = "잠시 후 다시 해 주세요"
		end
	end)
end

local function refresh()
	for _, c in row:GetChildren() do
		if c:IsA("GuiObject") then c:Destroy() end
	end
	local sorted = table.clone(Mines.list)
	table.sort(sorted, function(a, b) return a.order < b.order end)
	local n = 0
	for _, m in sorted do
		n += 1
		-- 대표 광물: 그 광산에서 가장 비싼 것부터 3개 (이름만)
		local ores = table.clone(m.ores)
		table.sort(ores, function(a, b) return a.value > b.value end)
		local names = {}
		for i = 1, math.min(3, #ores) do table.insert(names, ores[i].displayName) end
		makeCard(n, m.name, m.requiredPickaxe, table.concat(names, ", "), m.id)
	end
	for _, u in Mines.UPCOMING do
		n += 1
		makeCard(n, u.name, u.requiredPickaxe, u.hint, nil)
	end
end

local function open()
	if insideMine() then
		-- 광산 안: 창 대신 버튼 아래 짧은 안내
		button.Text = "🚫"
		task.delay(1.2, function() button.Text = "🗺️" end)
		pcall(function()
			game:GetService("StarterGui"):SetCore("SendNotification", { Title = "광산 지도", Text = "광산 안에서는 쓸 수 없어요. 출구로 나가세요", Duration = 3 })
		end)
		return
	end
	notice.Text = ""
	refresh()
	panel.Visible = true
end

button.Activated:Connect(function()
	if panel.Visible then panel.Visible = false else open() end
end)
close.Activated:Connect(function() panel.Visible = false end)

-- 광산 안이면 버튼을 흐리게 (못 쓴다는 걸 미리 보여 줌), 들어가면 열린 창도 닫음
task.spawn(function()
	while true do
		task.wait(0.5)
		local inside = insideMine()
		button.BackgroundTransparency = if inside then 0.5 else 0
		button.TextTransparency = if inside then 0.5 else 0
		if inside and panel.Visible then panel.Visible = false end
	end
end)
