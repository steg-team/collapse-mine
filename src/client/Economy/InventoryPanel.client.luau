--!strict
-- 인벤토리 창 (B 담당, D-022, 무게 D-027)
-- 화면 아래 가방 버튼(BagHud)을 누르거나 B 키로 연다. 같은 광물·압력끼리 묶어 개수·무게·값·1kg당 값을 보여 주고,
-- 어디서나 한 개씩 버릴 수 있고, 판매소 근처에서는 묶음별로 또는 전부 팔 수 있다 (판정·금액은 서버, Remotes.Bag).
-- 다음 곡괭이 재료·카나리아 먹이로 쓰이는 광물은 줄 아래에 "⚒ 돌 곡괭이 재료 2/3"처럼 표시한다.

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")

local Config = RS:WaitForChild("Shared"):WaitForChild("Config")
local Mines = require(Config:WaitForChild("Mines"))
local Economy = require(Config:WaitForChild("Economy"))

local player = Players.LocalPlayer
local remote = RS:WaitForChild("Remotes"):WaitForChild("Bag") :: RemoteFunction

-- 판매소 Counter에서 이 거리 안이면 판매 버튼을 켠다 (서버는 Economy.SELL_REACH로 다시 잰다)
local NEAR_SHOP = 12
local PRESSURE_TEXT = { Low = "상압", High = "고압", Extreme = "초고압" }
local GRADE_COLOR = Economy.GRADE_COLOR

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

local title = text(frame, { Position = UDim2.new(0, 16, 0, 10), Size = UDim2.new(1, -150, 0, 30), TextSize = 20, TextXAlignment = Enum.TextXAlignment.Left })
local close = button(frame, "X", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 10), Size = UDim2.fromOffset(30, 30), BackgroundColor3 = Color3.fromRGB(70, 66, 60), TextColor3 = Color3.new(1, 1, 1) })
-- 도감 창 열기 (CodexPanel.client.luau 가 이 버튼 "Codex"를 찾아 연결)
button(frame, "📖 도감", { Name = "Codex", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -48, 0, 10), Size = UDim2.fromOffset(80, 30), BackgroundColor3 = Color3.fromRGB(70, 66, 60), TextColor3 = Color3.new(1, 1, 1) })

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

-- 같은 광물·같은 압력은 1kg당 값이 같아서 한 줄로 묶는다
type Group = { ore: string, pressure: string, count: number, kg: number, value: number }

local function groups(): { Group }
	local byKey: { [string]: Group } = {}
	local out: { Group } = {}
	for _, item in items do
		local key = item.ore .. "|" .. item.pressure
		local g = byKey[key]
		if not g then
			g = { ore = item.ore, pressure = item.pressure, count = 0, kg = 0, value = 0 }
			byKey[key] = g
			table.insert(out, g)
		end
		g.count += 1
		g.kg += item.weight
		g.value += item.value
	end
	-- 1kg당 값이 높은 것부터: 버릴 때 아래쪽부터 고르면 된다
	table.sort(out, function(a, b)
		return a.value / a.kg > b.value / b.kg
	end)
	return out
end

local function act(action: string, g: Group)
	if busy then
		return
	end
	busy = true
	remote:InvokeServer(action, g.ore, g.pressure)
	busy = false
end

local function render()
	for _, c in list:GetChildren() do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	local cap = player:GetAttribute("BagCapacity") or 0
	local kg = player:GetAttribute("BagKg") or 0
	title.Text = string.format("가방 %.1f/%dkg", kg, cap)
	footer.Text = if #items == 0
		then "아직 캔 광물이 없어요"
		elseif nearShop then "값은 판매가 배수를 곱하기 전이에요"
		else "무거우면 느려져요. 싼 것부터 버려 보세요"
	sellAll.Visible = nearShop and #items > 0

	-- "팔까, 쓸까": 다음 곡괭이 재료와 카나리아 먹이에 쓰이는 광물은 줄 아래에 표시해서 모르고 팔지 않게 한다.
	-- 개수는 압력과 상관없이 같은 광물 전부 (제작소가 압력을 가리지 않고 싼 것부터 씀)
	local countOf: { [string]: number } = {}
	local rareCount = 0
	for _, item in items do
		countOf[item.ore] = (countOf[item.ore] or 0) + 1
		local info = oreInfo[item.ore]
		if info and info.grade == Economy.CANARY_FEED_GRADE then
			rareCount += 1
		end
	end
	local nextPickaxe = Economy.PICKAXES[(player:GetAttribute("PickaxeTier") or 1) + 1]
	local nextCanary = Economy.CANARY[(player:GetAttribute("CanaryLevel") or 0) + 1]
	local function useTag(oreId: string): string?
		local need = nextPickaxe and nextPickaxe.ores[oreId]
		if need then
			return `⚒ {nextPickaxe.name} 재료 {countOf[oreId]}/{need}`
		end
		local info = oreInfo[oreId]
		if nextCanary and info and info.grade == Economy.CANARY_FEED_GRADE then
			return `🐤 카나리아 먹이 ({Economy.CANARY_FEED_GRADE} 광물 {rareCount}/{nextCanary.rare})`
		end
		return nil
	end

	for i, g in groups() do
		local info = oreInfo[g.ore]
		local tag = useTag(g.ore)
		local row = Instance.new("Frame")
		row.Name = `Row{i}`
		row.LayoutOrder = i
		row.Size = UDim2.new(1, -8, 0, if tag then 48 else 36)
		row.BackgroundColor3 = Color3.fromRGB(44, 41, 38)
		Instance.new("UICorner").Parent = row
		row.Parent = list

		text(row, {
			Position = UDim2.new(0, 10, 0, 0),
			Size = UDim2.new(1, -160, 0, 36),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextSize = 14,
			TextTruncate = Enum.TextTruncate.AtEnd,
			RichText = true,
			Text = string.format(
				'<font color="#%s">%s</font> %s ×%d · %.1fkg · %d 코인 <font color="#aaaaaa">(%.1f/kg)</font>',
				(info and GRADE_COLOR[info.grade] or Color3.new(1, 1, 1)):ToHex(),
				info and info.displayName or g.ore,
				PRESSURE_TEXT[g.pressure] or g.pressure,
				g.count,
				g.kg,
				g.value,
				g.value / g.kg
			),
		})
		if tag then
			text(row, { Name = "Use", Position = UDim2.new(0, 10, 0, 28), Size = UDim2.new(1, -160, 0, 16), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 12, TextTruncate = Enum.TextTruncate.AtEnd, TextColor3 = Color3.fromRGB(255, 200, 90), Text = tag })
		end
		local drop = button(row, "버리기", { Name = "Drop", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -82, 0.5, 0), Size = UDim2.fromOffset(70, 28), BackgroundColor3 = Color3.fromRGB(90, 84, 76), TextColor3 = Color3.new(1, 1, 1) })
		drop.Activated:Connect(function()
			act("drop", g)
		end)
		if nearShop then
			local sell = button(row, "팔기", { Name = "Sell", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.fromOffset(70, 28) })
			sell.Activated:Connect(function()
				act("sell", g)
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
player:GetAttributeChangedSignal("BagKg"):Connect(reload)
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
