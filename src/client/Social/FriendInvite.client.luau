--!strict
-- 친구 초대 버튼 (C 담당, D-033)
-- 화면 왼쪽 👥 버튼 → 로블록스 기본 친구 초대 창 (SocialService).
-- 초대할 수 없는 상황(Studio 테스트, 초대 기능이 막힌 계정 등)이면 알림만 띄운다.
-- 버튼 모양은 출석 버튼과 같게 (Config/Social.luau 의 DailyLogin), 위치·문구는 FriendInvite.

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")
local StarterGui = game:GetService("StarterGui")

local Social = require(RS:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Social"))
local CONFIG = Social.FriendInvite
local LOOK = Social.DailyLogin
local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "FriendInvite"
gui.ResetOnSpawn = false
gui.DisplayOrder = LOOK.displayOrder
gui.Parent = player:WaitForChild("PlayerGui")

local button = Instance.new("TextButton")
button.AnchorPoint = Vector2.new(0, 0.5)
button.Position = UDim2.new(0, LOOK.buttonMargin, 0.5, CONFIG.buttonOffset)
button.Size = UDim2.fromOffset(LOOK.buttonSize, LOOK.buttonSize)
button.BackgroundColor3 = LOOK.panelColor
button.Text = "👥"
button.TextSize = LOOK.titleSize
button.Parent = gui
local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, LOOK.cornerRadius); c.Parent = button

local function notify(text: string)
	-- 로블록스 기본 알림 (오른쪽 아래). 실패해도 게임에 영향 없게 pcall
	pcall(StarterGui.SetCore, StarterGui, "SendNotification", { Title = "친구 초대", Text = text, Duration = 4 })
end

local opening = false
button.Activated:Connect(function()
	if opening then return end
	opening = true
	-- 초대할 수 있는지 먼저 묻는다 (안 되는데 창을 띄우면 에러)
	local ok, can = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
	if ok and can then
		local options = Instance.new("ExperienceInviteOptions")
		options.PromptMessage = CONFIG.promptMessage
		local shown = pcall(SocialService.PromptGameInvite, SocialService, player, options)
		if not shown then notify("초대 창을 열지 못했어요. 잠시 후 다시 해 주세요") end
	else
		notify("지금은 친구를 초대할 수 없어요 (Studio 테스트에서는 원래 안 돼요)")
	end
	opening = false
end)
