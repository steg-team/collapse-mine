--!strict
-- 서버 부스트 UI (C 담당, D-018)
-- - 화면 왼쪽(출석 📅 아래) 🚀 버튼: 서버 부스트 구매 창
-- - 오른쪽 위: 부스트 중이면 "🚀 서버 채굴 2배 12:34"
-- 지급·판정은 서버(Payments.luau). 남은 시간은 ReplicatedStorage.ServerBoost 의 속성 EndsAt(서버 시계).
-- 숫자·색은 Config/Social.luau 의 ServerBoost (버튼 모양은 DailyLogin 과 맞춤).

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local Social = require(RS:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Social"))
local CONFIG = Social.ServerBoost
local BUTTON = Social.DailyLogin -- 왼쪽 버튼 크기·색을 출석 버튼과 같게
local player = Players.LocalPlayer
local boostState = RS:WaitForChild("ServerBoost")

local gui = Instance.new("ScreenGui")
gui.Name = "ServerBoost"
gui.ResetOnSpawn = false
gui.DisplayOrder = BUTTON.displayOrder
gui.Parent = player:WaitForChild("PlayerGui")

-- 구매 버튼 (출석 📅 버튼 바로 아래)
local buyButton = Instance.new("TextButton")
buyButton.Name = "Buy"
buyButton.AnchorPoint = Vector2.new(0, 0.5)
buyButton.Position = UDim2.new(0, BUTTON.buttonMargin, 0.5, CONFIG.buttonOffset)
buyButton.Size = UDim2.fromOffset(BUTTON.buttonSize, BUTTON.buttonSize)
buyButton.BackgroundColor3 = BUTTON.panelColor
buyButton.Text = "🚀"
buyButton.TextSize = BUTTON.titleSize
buyButton.Parent = gui
local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, BUTTON.cornerRadius); c.Parent = buyButton

buyButton.Activated:Connect(function()
	if CONFIG.productId == 0 then
		-- 대시보드에서 상품을 만들기 전. Studio 에서는 Server 명령창의 BoostTest 로 확인
		warn("[ServerBoost] productId 가 아직 0 이라 구매 창을 띄울 수 없음 (Config/Social.luau)")
		return
	end
	MarketplaceService:PromptProductPurchase(player, CONFIG.productId)
end)

-- 남은 시간 표시 (오른쪽 위)
local timer = Instance.new("TextLabel")
timer.Name = "Timer"
timer.AnchorPoint = Vector2.new(1, 0)
timer.Position = UDim2.new(1, -CONFIG.timerRightMargin, 0, CONFIG.timerTopMargin)
timer.AutomaticSize = Enum.AutomaticSize.XY
timer.BackgroundTransparency = 1
timer.Font = Enum.Font.GothamBold
timer.TextSize = CONFIG.timerTextSize
timer.TextColor3 = CONFIG.timerColor
timer.Visible = false
timer.Parent = gui
local stroke = Instance.new("UIStroke"); stroke.Thickness = 2; stroke.Parent = timer

while true do
	local endsAt = boostState:GetAttribute("EndsAt")
	local remaining = if typeof(endsAt) == "number" then endsAt - workspace:GetServerTimeNow() else 0
	if remaining > 0 then
		local s = math.ceil(remaining)
		timer.Text = `🚀 {CONFIG.displayName} {s // 60}:{string.format("%02d", s % 60)}`
		timer.Visible = true
	else
		timer.Visible = false
	end
	task.wait(0.5)
end
