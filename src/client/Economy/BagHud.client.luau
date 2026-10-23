--!strict
-- 가방 HUD (B 담당, D-020)
-- 화면 아래 가운데에 "가방 3/20 · 120 코인어치"를 띄운다. 꽉 차면 빨갛게 "판매소에서 파세요".
-- 데이터: 서버 Bag.luau 가 플레이어 속성 BagCount, BagCapacity, BagValue 를 갱신한다.

local Players = game:GetService("Players")

local player = Players.LocalPlayer

-- UI (코드로 만들어서 Studio 수작업 없이 Rojo 만으로 동작하게)
local gui = Instance.new("ScreenGui")
gui.Name = "BagHud"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local label = Instance.new("TextLabel")
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

local function refresh()
	local count = player:GetAttribute("BagCount")
	local cap = player:GetAttribute("BagCapacity")
	local value = player:GetAttribute("BagValue")
	if typeof(count) ~= "number" or typeof(cap) ~= "number" or typeof(value) ~= "number" then
		return -- 데이터 로드 전
	end
	gui.Enabled = true
	local full = count >= cap
	label.Text = if full
		then `가방 가득 {count}/{cap} · 판매소에서 파세요`
		else `가방 {count}/{cap} · {value} 코인어치`
	label.TextColor3 = if full then Color3.fromRGB(255, 110, 100) else Color3.new(1, 1, 1)
end

for _, name in { "BagCount", "BagCapacity", "BagValue" } do
	player:GetAttributeChangedSignal(name):Connect(refresh)
end
refresh()
