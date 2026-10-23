--!strict
-- 인벤토리 창 (B 담당, D-022)
-- 화면 아래 가방 버튼(BagHud)을 누르거나 B 키로 연다. 캔 광물마다 이름·무게·압력·값을 보여 주고,
-- 판매소 근처에서는 한 개씩 또는 전부 팔 수 있다 (판매 판정·금액은 서버, Remotes.Bag).

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")

local Config = RS:WaitForChild("Shared"):WaitForChild("Config")
local Mines = require(Config:WaitForChild("Mines"))

local player = Players.LocalPlayer
local remote = RS:WaitForChild("Remotes"):WaitForChild("Bag") :: RemoteFunction

-- 판매소 Counter에서 이 거리 안이면 판매 버튼을 켠다 (서버는 Economy.SELL_REACH로 다시 잰다)
local NEAR_SHOP = 12
local PRESSURE_TEXT = { Low = "상압", High = "고압", Extreme = "초고압" }
-- 기획서 "광물 등급" 색
local GRADE_COLOR = {
	["일반"] = Color3.fromRGB(170, 170, 170),
	["고급"] = Color3.fromRGB(90, 200, 90),
	["희귀"] = Color3.fromRGB(80, 150, 255),
	["에픽"] = Color3.fromRGB(180, 100, 255),
	["전설"] = Color3.fromRGB(255, 160, 40),
	["신화"] = Color3.fromRGB(255, 70, 70),
}

local oreInfo: { [string]: { displayName: string, grade: string } } = {}
for _, m in Mines.list do
	for _, o in m.ores do
		oreInfo[o.name] = { displayName = o.displayName, grade = o.grade }
	end
end

type Item = { ore: string, weight: number, pressure: string, value: number }

-- UI (코드로 만들어서 Studio 수작업 없이 Rojo 만으로 동작하게)
local gui = Instance.new("ScreenGui")
gui.Name = "InventoryPanel"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.DisplayOrder = 45 -- 직접 연 창이라 출석판(40) 위, 붕괴 HUD(49)·공지(50) 아래
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Name = "Window"
frame.AnchorPoint = Vector2.new(0.5, 0.5)
frame.Position = UDim2.fromScale(0.5, 0.45) -- 아래 가방 버튼을 가리지 않게 살짝 위
frame.Size = UDim2.new(0.9, 0, 0.65, 0)
frame.BackgroundColor3 = Color3.fromRGB(28, 26, 24)
frame.Parent = gui
local sizeLimit = Instance.new("UISizeConstraint")
sizeLimit.MaxSize = Vector2.new(460, 420)
sizeLimit.Parent = frame
Instance.new("UICorner").Parent = frame

local function text(parent: Instance, props: { [string]: any }): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBold
	t.TextColor3 = Color3.new(1, 1, 1)
	t.TextSize = 16
	for k, v in props do
		(t :: any)[k] = v
	end
	t.Parent = parent
	return t
end

local function button(parent: Instance, label: string, props: { [string]: any }): TextButton
	local b = Instance.new("TextButton")
	b.Font = Enum.Font.GothamBold
	b.TextSize = 15
	b.Text = label
	b.TextColor3 = Color3.fromRGB(30, 30, 30)
	b.BackgroundColor3 = Color3.fromRGB(255, 190, 50)
	for k, v in props do
		(b :: any)[k] = v
	end
	Instance.new("UICorner").Parent = b
	b.Parent = parent
	return b
end

local title = text(frame, { Position = UDim2.new(0, 16, 0, 10), Size = UDim2.new(1, -70, 0, 30), TextSize = 20, TextXAlignment = Enum.TextXAlignment.Left })
local close = button(frame, "X", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 10), Size = UDim2.fromOffset(30, 30), BackgroundColor3 = Color3.fromRGB(70, 66, 60), TextColor3 = Color3.new(1, 1, 1) })

local list = Instance.new("ScrollingFrame")
list.Name = "List"
list.Position = UDim2.new(0, 12, 0, 48)
list.Size = UDim2.new(1, -24, 1, -110)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 6
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.CanvasSize = UDim2.new()
list.Parent = frame
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 4)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list

local footer = text(frame, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 16, 1, -14), Size = UDim2.new(1, -170, 0, 36), TextSize = 14, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(200, 200, 200) })
local sellAll = button(frame, "전부 팔기", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -14, 1, -14), Size = UDim2.fromOffset(130, 36) })

local items: { Item } = {}
local nearShop = false
local busy = false

local function isNearShop(): boolean
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return false
	end
	for _, hub in workspace:GetChildren() do
		local root = hub.Name:sub(1, 12) == "CollapseMine" and hub:FindFirstChild("Hub")
		local shop = root and root:FindFirstChild("Shop")
		local counter = shop and shop:FindFirstChild("Counter")
		if counter and counter:IsA("BasePart") and (hrp.Position - counter.Position).Magnitude <= NEAR_SHOP then
			return true
		end
	end
	return false
end

local function render()
	for _, c in list:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	local cap = player:GetAttribute("BagCapacity") or 0
	title.Text = `가방 {#items}/{cap}`
	footer.Text = if #items == 0
		then "아직 캔 광물이 없어요"
		elseif nearShop then "값은 판매가 배수를 곱하기 전이에요"
		else "판매소에 가면 팔 수 있어요"
	sellAll.Visible = nearShop and #items > 0

	for i, item in items do
		local info = oreInfo[item.ore]
		local row = Instance.new("Frame")
		row.Name = `Row{i}`
		row.LayoutOrder = i
		row.Size = UDim2.new(1, -8, 0, 36)
		row.BackgroundColor3 = Color3.fromRGB(44, 41, 38)
		Instance.new("UICorner").Parent = row
		row.Parent = list

		text(row, {
			Position = UDim2.new(0, 10, 0, 0),
			Size = UDim2.new(1, -100, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextSize = 15,
			RichText = true,
			Text = string.format(
				'<font color="#%s">%s</font>  무게 %.1f · %s · %d 코인',
				(info and GRADE_COLOR[info.grade] or Color3.new(1, 1, 1)):ToHex(),
				info and info.displayName or item.ore,
				item.weight,
				PRESSURE_TEXT[item.pressure] or item.pressure,
				item.value
			),
		})
		if nearShop then
			local sell = button(row, "팔기", { Name = "Sell", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.fromOffset(70, 28) })
			sell.Activated:Connect(function()
				if busy then
					return
				end
				busy = true
				remote:InvokeServer("sell", i, item.ore)
				busy = false
			end)
		end
	end
end

local function reload()
	if not gui.Enabled then
		return
	end
	local ok, result = pcall(remote.InvokeServer, remote, "get")
	if ok and typeof(result) == "table" then
		items = result
	end
	render()
end

local function toggle()
	gui.Enabled = not gui.Enabled
	nearShop = isNearShop()
	reload()
end

sellAll.Activated:Connect(function()
	if not busy then
		busy = true
		remote:InvokeServer("sellAll")
		busy = false
	end
end)
close.Activated:Connect(toggle)
UIS.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.B then
		toggle()
	end
end)

local bagButton = player.PlayerGui:WaitForChild("BagHud"):WaitForChild("Bag") :: TextButton
bagButton.Activated:Connect(toggle)

-- 가방이 바뀌면(판매·채굴·갇힘) 다시 받아 온다. 서버 판매 결과 문구는 BagHud 알림 줄에 뜬다
player:GetAttributeChangedSignal("BagCount"):Connect(reload)
player:GetAttributeChangedSignal("BagValue"):Connect(reload)

-- 창을 연 채 판매소에 다가가거나 멀어지면 버튼을 켜고 끈다
while true do
	task.wait(0.5)
	if gui.Enabled then
		local near = isNearShop()
		if near ~= nearShop then
			nearShop = near
			render()
		end
	end
end
