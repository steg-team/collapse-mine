--!strict
-- 가방 HUD (B 담당, D-020, 무게 D-027)
-- 화면 아래 가운데에 "가방 12.4/30kg · 120 코인어치"와 무게 게이지를 띄운다.
-- 한도를 넘으면 노랑 "무거워서 느려요", 더 안 담기는 무게면 빨강.
-- 그 위에 판매·제작 결과 한 줄 알림을 잠깐 띄운다.
-- 데이터: 서버 Bag.luau 가 플레이어 속성 BagKg, BagCapacity(kg), BagValue, SellMultiplier 를 갱신한다.
-- 코인어치는 지금 팔면 받을 값(판매가 배수를 곱한 값)으로 보여 주고, 배수가 1보다 크면 "💰×2"를 붙인다.
-- 부스트·패스를 산 효과가 늘 보이는 자리에 있어야 산 보람이 있다 (시뮬레이터 장르 흔한 방식: 재화 옆 배수 배지)

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local Economy = require(RS:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Economy"))

local player = Players.LocalPlayer

-- UI (코드로 만들어서 Studio 수작업 없이 Rojo 만으로 동작하게)
local gui = Instance.new("ScreenGui")
gui.Name = "BagHud"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

-- 누르면 인벤토리 창이 열린다 (InventoryPanel.client.luau 가 이 버튼 "Bag"을 찾아 연결)
local label = Instance.new("TextButton")
label.Name = "Bag"
label.AutoButtonColor = false
label.AnchorPoint = Vector2.new(0.5, 1)
label.Position = UDim2.new(0.5, 0, 1, -80) -- 기본 도구 칸(곡괭이) 바로 위
label.Size = UDim2.new(0, 0, 0, 0)
label.AutomaticSize = Enum.AutomaticSize.XY
label.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
label.BackgroundTransparency = 0.35
label.Font = Enum.Font.GothamBold
label.TextSize = 18
label.TextColor3 = Color3.new(1, 1, 1)
label.Parent = gui

local pad = Instance.new("UIPadding")
pad.PaddingLeft = UDim.new(0, 14)
pad.PaddingRight = UDim.new(0, 14)
pad.PaddingTop = UDim.new(0, 6)
pad.PaddingBottom = UDim.new(0, 6)
pad.Parent = label

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = label

-- 무게 게이지: 가방 줄 아래 얇은 막대. 끝 = 더 안 담기는 무게, 흰 눈금 = 한도(여기부터 느려짐)
local GREEN, YELLOW, RED = Color3.fromRGB(110, 210, 110), Color3.fromRGB(255, 200, 60), Color3.fromRGB(255, 90, 80)
-- 가방 줄(자동 크기) 안에 넣으면 줄이 같이 늘어나서, 밖에 두고 줄 너비에 맞춘다
local gauge = Instance.new("Frame")
gauge.Name = "Gauge"
gauge.AnchorPoint = Vector2.new(0.5, 0)
gauge.Position = UDim2.new(0.5, 0, 1, -78) -- 가방 줄(-80에서 위로 자람) 바로 아래
gauge.BackgroundColor3 = Color3.fromRGB(60, 60, 64)
gauge.BorderSizePixel = 0
gauge.Parent = gui
local function fitGauge()
	gauge.Size = UDim2.fromOffset(label.AbsoluteSize.X - 16, 4)
end
label:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitGauge)
fitGauge()
local fill = Instance.new("Frame")
fill.BorderSizePixel = 0
fill.Parent = gauge
local tick = Instance.new("Frame")
tick.BorderSizePixel = 0
tick.BackgroundColor3 = Color3.new(1, 1, 1)
tick.Position = UDim2.fromScale(1 / Economy.BAG_HARD_LIMIT, 0)
tick.Size = UDim2.new(0, 2, 1, 0)
tick.Parent = gauge

local function refresh()
	local kg = player:GetAttribute("BagKg")
	local cap = player:GetAttribute("BagCapacity")
	local value = player:GetAttribute("BagValue")
	local mult = player:GetAttribute("SellMultiplier")
	mult = if typeof(mult) == "number" and mult > 0 then mult else 1
	if typeof(kg) ~= "number" or typeof(cap) ~= "number" or typeof(value) ~= "number" then
		return -- 데이터 로드 전
	end
	gui.Enabled = true
	local ratio = kg / cap
	local color = if ratio >= Economy.BAG_HARD_LIMIT - 0.05 then RED elseif ratio > 1 then YELLOW else GREEN
	local kgText = string.format("%.1f/%dkg", kg, cap)
	local worth = `{math.floor(value * mult + 0.5)} 코인어치` .. (if mult > 1 then ` 💰×{string.format("%g", mult)}` else "")
	label.Text = if ratio >= Economy.BAG_HARD_LIMIT - 0.05
		then `🎒 {kgText} · 너무 무거워요! 팔거나 버리세요`
		elseif ratio > 1 then `🎒 {kgText} · 무거워서 느려요 · {worth}`
		else `🎒 가방 {kgText} · {worth}`
	label.TextColor3 = if ratio > 1 then color else Color3.new(1, 1, 1)
	fill.BackgroundColor3 = color
	fill.Size = UDim2.fromScale(math.clamp(ratio / Economy.BAG_HARD_LIMIT, 0, 1), 1)
end

for _, name in { "BagKg", "BagCapacity", "BagValue", "SellMultiplier" } do
	player:GetAttributeChangedSignal(name):Connect(refresh)
end
refresh()

-- 한 줄 알림 (판매 결과, 제작 실패 이유). 서버 Bag.notify 가 EconomyNotice / EconomyNoticeAt 속성을 올린다
local NOTICE_SECONDS = 3

local notice = label:Clone()
notice.Name = "Notice"
notice.Active = false
notice.Position = UDim2.new(0.5, 0, 1, -118) -- 가방 줄 바로 위
notice.TextColor3 = Color3.fromRGB(255, 220, 120)
notice.Visible = false
notice.Parent = gui

local shownAt = 0
player:GetAttributeChangedSignal("EconomyNoticeAt"):Connect(function()
	local text = player:GetAttribute("EconomyNotice")
	if typeof(text) ~= "string" then
		return
	end
	notice.Text = text
	notice.Visible = true
	local mine = os.clock()
	shownAt = mine
	task.delay(NOTICE_SECONDS, function()
		if shownAt == mine then
			notice.Visible = false
		end
	end)
end)
