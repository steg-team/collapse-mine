--!strict
-- 서버 공지 배너 (C 담당)
-- 서버가 Remotes.Announce 로 보낸 문구를 화면 위쪽에 하나씩 띄운다.
-- 여러 개가 한꺼번에 오면 줄을 세워 차례로 보여준다 (겹쳐 그리면 못 읽으니까).
-- 채굴 시야를 가리지 않도록 위쪽 가운데에 얇게 둔다 (기획서 "화면 예시").

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local announceRemote = RS:WaitForChild("Remotes"):WaitForChild("Announce") :: RemoteEvent
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local SHOW_TIME = 3.5   -- 배너가 떠 있는 시간(초), 임시값
local FADE_TIME = 0.25
local MAX_QUEUE = 5     -- 밀린 공지가 이보다 많으면 오래된 것부터 버린다. 붕괴 직전처럼 몰릴 때 배너가 한참 밀리지 않게

-- kind 별 색 (서버 Announcer.Kind 와 같은 목록)
local STYLE: { [string]: { bg: Color3, stroke: Color3, icon: string } } = {
	Legendary = { bg = Color3.fromRGB(70, 45, 10), stroke = Color3.fromRGB(255, 200, 60), icon = "✨" },
	Boost     = { bg = Color3.fromRGB(20, 45, 80), stroke = Color3.fromRGB(90, 180, 255), icon = "🚀" },
	Collapse  = { bg = Color3.fromRGB(80, 15, 15), stroke = Color3.fromRGB(255, 80, 60), icon = "⚠️" },
	Info      = { bg = Color3.fromRGB(25, 25, 30), stroke = Color3.fromRGB(200, 200, 210), icon = "📢" },
}

-- UI 만들기 (코드로 만들어서 Studio 수작업 없이 Rojo 만으로 동작하게)
local gui = Instance.new("ScreenGui")
gui.Name = "AnnounceBanner"
gui.ResetOnSpawn = false   -- 죽어도 배너가 사라지지 않게
gui.DisplayOrder = 50      -- 다른 HUD 보다 위
gui.IgnoreGuiInset = false -- 상단 로블록스 메뉴 바 아래에 그린다
gui.Parent = playerGui

local banner = Instance.new("Frame")
banner.Name = "Banner"
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Position = UDim2.new(0.5, 0, 0, 8)
banner.Size = UDim2.new(0, 0, 0, 40)
banner.AutomaticSize = Enum.AutomaticSize.X -- 문구 길이에 맞춰 가로가 늘어남
banner.BackgroundTransparency = 1
banner.Visible = false
banner.Parent = gui

local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 10); corner.Parent = banner
local stroke = Instance.new("UIStroke"); stroke.Thickness = 2; stroke.Transparency = 1; stroke.Parent = banner
local pad = Instance.new("UIPadding")
pad.PaddingLeft = UDim.new(0, 16); pad.PaddingRight = UDim.new(0, 16)
pad.Parent = banner

local label = Instance.new("TextLabel")
label.Name = "Text"
label.BackgroundTransparency = 1
label.Size = UDim2.new(0, 0, 1, 0)
label.AutomaticSize = Enum.AutomaticSize.X
label.Font = Enum.Font.GothamBold
label.TextSize = 18
label.TextColor3 = Color3.new(1, 1, 1)
label.TextTransparency = 1
label.Parent = banner

-- 폰은 화면이 좁아서 글자를 줄인다
local function fitToScreen()
	local w = workspace.CurrentCamera.ViewportSize.X
	label.TextSize = if w < 700 then 14 else 18
end
fitToScreen()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitToScreen)

local queue: { { text: string, kind: string } } = {}
local showing = false

local function fade(visible: boolean)
	local t = if visible then 0 else 1
	local info = TweenInfo.new(FADE_TIME)
	TweenService:Create(banner, info, { BackgroundTransparency = if visible then 0.15 else 1 }):Play()
	TweenService:Create(stroke, info, { Transparency = t }):Play()
	local tw = TweenService:Create(label, info, { TextTransparency = t })
	tw:Play()
	tw.Completed:Wait()
end

local function showNext()
	if showing then return end
	showing = true
	while #queue > 0 do
		local item = table.remove(queue, 1) :: { text: string, kind: string }
		local style = STYLE[item.kind] or STYLE.Info
		banner.BackgroundColor3 = style.bg
		stroke.Color = style.stroke
		label.Text = `{style.icon}  {item.text}`
		banner.Visible = true
		fade(true)
		task.wait(SHOW_TIME)
		fade(false)
	end
	banner.Visible = false
	showing = false
end

announceRemote.OnClientEvent:Connect(function(text: any, kind: any)
	-- 서버에서만 오지만, 형식이 틀린 값은 그냥 버린다
	if typeof(text) ~= "string" then return end
	if typeof(kind) ~= "string" then kind = "Info" end
	table.insert(queue, { text = text, kind = kind })
	while #queue > MAX_QUEUE do table.remove(queue, 1) end
	task.spawn(showNext)
end)
