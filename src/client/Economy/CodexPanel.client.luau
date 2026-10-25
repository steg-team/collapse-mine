--!strict
-- 광물 도감 창 (B 담당, D-035)
-- 인벤토리 창의 "📖 도감" 버튼이나 N 키로 연다. 광산마다 광물 카드를 늘어놓고,
-- 캔 적 있는 광물은 이름을, 아직이면 "???"를 보여 준다. 카드 아래 상·고·초 칸은 그 압력으로 캔 적이 있으면 켜진다.
-- 기록은 서버가 가방에 담을 때 적는다 (Bag.luau, Remotes.Bag "codex").

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")

local Config = RS:WaitForChild("Shared"):WaitForChild("Config")
local Mines = require(Config:WaitForChild("Mines"))
local Economy = require(Config:WaitForChild("Economy"))

local player = Players.LocalPlayer
local remote = RS:WaitForChild("Remotes"):WaitForChild("Bag") :: RemoteFunction

local PRESSURES = { { key = "Low", text = "상" }, { key = "High", text = "고" }, { key = "Extreme", text = "초" } }
local DARK = Color3.fromRGB(60, 56, 52)

-- UI (코드로 만들어서 Studio 수작업 없이 Rojo 만으로 동작하게)
local gui = Instance.new("ScreenGui")
gui.Name = "CodexPanel"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.DisplayOrder = 46 -- 인벤토리 창(45) 위에서 연다
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Name = "Window"
frame.AnchorPoint = Vector2.new(0.5, 0.5)
frame.Position = UDim2.fromScale(0.5, 0.45)
frame.Size = UDim2.new(0.92, 0, 0.7, 0)
frame.BackgroundColor3 = Color3.fromRGB(28, 26, 24)
frame.Parent = gui
local sizeLimit = Instance.new("UISizeConstraint")
sizeLimit.MaxSize = Vector2.new(560, 460)
sizeLimit.Parent = frame
Instance.new("UICorner").Parent = frame

local function make(class: string, parent: Instance, props: { [string]: any }): any
	local o = Instance.new(class)
	if o:IsA("TextLabel") or o:IsA("TextButton") then
		o.Font = Enum.Font.GothamBold
		o.TextColor3 = Color3.new(1, 1, 1)
		o.TextSize = 14
	end
	for k, v in props do
		(o :: any)[k] = v
	end
	o.Parent = parent
	return o
end

local title = make("TextLabel", frame, { Position = UDim2.new(0, 16, 0, 10), Size = UDim2.new(1, -70, 0, 30), BackgroundTransparency = 1, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Left })
local close = make("TextButton", frame, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 10), Size = UDim2.fromOffset(30, 30), BackgroundColor3 = Color3.fromRGB(70, 66, 60), Text = "X" })
Instance.new("UICorner").Parent = close

local list = make("ScrollingFrame", frame, {
	Position = UDim2.new(0, 12, 0, 48),
	Size = UDim2.new(1, -24, 1, -60),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 6,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
})
make("UIListLayout", list, { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })

-- 카드 하나: 등급 색 테두리, 이름(또는 ???), 등급, 압력 세 칸
local function card(parent: Instance, ore: Mines.Ore, codex: { [string]: boolean }, order: number)
	local found = codex[ore.name] == true
	local color = Economy.GRADE_COLOR[ore.grade] or Color3.new(1, 1, 1)
	local c = make("Frame", parent, { Name = ore.name, LayoutOrder = order, BackgroundColor3 = Color3.fromRGB(44, 41, 38) })
	Instance.new("UICorner").Parent = c
	make("UIStroke", c, { Color = color, Thickness = 2, Transparency = if found then 0 else 0.6 })
	make("TextLabel", c, {
		Position = UDim2.new(0, 6, 0, 4),
		Size = UDim2.new(1, -12, 0, 18),
		BackgroundTransparency = 1,
		Text = if found then ore.displayName else "???",
		TextColor3 = if found then color else Color3.fromRGB(130, 130, 130),
		TextScaled = true,
	})
	make("TextLabel", c, { Position = UDim2.new(0, 6, 0, 22), Size = UDim2.new(1, -12, 0, 14), BackgroundTransparency = 1, Text = ore.grade, TextSize = 12, TextColor3 = Color3.fromRGB(170, 170, 170) })
	for i, p in PRESSURES do
		local on = codex[`{ore.name}|{p.key}`] == true
		local chip = make("TextLabel", c, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new((i - 0.5) / 3, 0, 1, -5),
			Size = UDim2.new(1 / 3, -6, 0, 18),
			BackgroundColor3 = if on then color else DARK,
			Text = p.text,
			TextSize = 12,
			TextColor3 = if on then Color3.fromRGB(25, 25, 25) else Color3.fromRGB(120, 120, 120),
		})
		Instance.new("UICorner").Parent = chip
	end
end

local function render(codex: { [string]: boolean })
	for _, c in list:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	local mines = table.clone(Mines.list)
	table.sort(mines, function(a, b)
		return a.order < b.order
	end)
	-- 칸 수 = 광물 × 압력 3개. 다 켜면 그 광산 완성
	local total, have = 0, 0
	for i, m in mines do
		local section = make("Frame", list, { Name = m.id, LayoutOrder = i, Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 })
		make("UIListLayout", section, { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder })
		local header = make("TextLabel", section, { LayoutOrder = 0, Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left })
		local grid = make("Frame", section, { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1 })
		make("UIGridLayout", grid, { CellSize = UDim2.fromOffset(120, 64), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder })
		local mineHave = 0
		for j, o in m.ores do
			card(grid, o, codex, j)
			for _, p in PRESSURES do
				if codex[`{o.name}|{p.key}`] then
					mineHave += 1
				end
			end
		end
		local mineTotal = #m.ores * #PRESSURES
		header.Text = `⛏ {m.name}  {mineHave}/{mineTotal}` .. (if mineHave == mineTotal then "  ✨ 완성!" else "")
		total += mineTotal
		have += mineHave
	end
	title.Text = `📖 광물 도감  {have}/{total}`
end

local function toggle()
	gui.Enabled = not gui.Enabled
	if not gui.Enabled then
		return
	end
	local ok, result = pcall(remote.InvokeServer, remote, "codex")
	render(if ok and typeof(result) == "table" then result else {})
end

close.Activated:Connect(toggle)
UIS.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.N then
		toggle()
	end
end)
local codexButton = player.PlayerGui:WaitForChild("InventoryPanel"):WaitForChild("Window"):WaitForChild("Codex") :: TextButton
codexButton.Activated:Connect(toggle)
