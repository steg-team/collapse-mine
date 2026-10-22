--!strict
-- 서버 공지 배너 (C 담당)
-- 서버가 Remotes.Announce 로 보낸 문구를 화면 위쪽에 하나씩 띄운다.
-- 여러 개가 한꺼번에 오면 줄을 세워 차례로 보여준다 (겹쳐 그리면 못 읽으니까).
-- 채굴 시야를 가리지 않도록 위쪽 가운데에 얇게 둔다 (기획서 "화면 예시").

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Social = require(RS:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Social"))
local CONFIG = Social.Banner

local announceRemote = RS:WaitForChild("Remotes"):WaitForChild("Announce") :: RemoteEvent
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

-- 숫자·색은 전부 Config/Social.luau 의 Banner

-- UI 만들기 (코드로 만들어서 Studio 수작업 없이 Rojo 만으로 동작하게)
local gui = Instance.new("ScreenGui")
gui.Name = "AnnounceBanner"
gui.ResetOnSpawn = false   -- 죽어도 배너가 사라지지 않게
gui.DisplayOrder = CONFIG.displayOrder
gui.IgnoreGuiInset = false -- 상단 로블록스 메뉴 바 아래에 그린다
gui.Parent = playerGui

local banner = Instance.new("Frame")
banner.Name = "Banner"
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Position = UDim2.new(0.5, 0, 0, CONFIG.topMargin)
banner.Size = UDim2.new(0, 0, 0, CONFIG.height)
banner.AutomaticSize = Enum.AutomaticSize.X -- 문구 길이에 맞춰 가로가 늘어남
banner.BackgroundTransparency = 1
banner.Visible = false
banner.Parent = gui

local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, CONFIG.cornerRadius); corner.Parent = banner
local stroke = Instance.new("UIStroke"); stroke.Thickness = CONFIG.strokeThickness; stroke.Transparency = 1; stroke.Parent = banner
local pad = Instance.new("UIPadding")
pad.PaddingLeft = UDim.new(0, CONFIG.padding); pad.PaddingRight = UDim.new(0, CONFIG.padding)
pad.Parent = banner

local label = Instance.new("TextLabel")
label.Name = "Text"
label.BackgroundTransparency = 1
label.Size = UDim2.new(0, 0, 1, 0)
label.AutomaticSize = Enum.AutomaticSize.X
label.Font = Enum.Font.GothamBold
label.TextSize = CONFIG.textSize
label.TextColor3 = Color3.new(1, 1, 1)
label.TextTransparency = 1
label.Parent = banner

-- 폰은 화면이 좁아서 글자를 줄인다
local function fitToScreen()
	local w = workspace.CurrentCamera.ViewportSize.X
	label.TextSize = if w < CONFIG.smallScreenWidth then CONFIG.textSizeSmall else CONFIG.textSize
end
fitToScreen()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitToScreen)

local queue: { { text: string, kind: string } } = {}
local showing = false

local function fade(visible: boolean)
	local t = if visible then 0 else 1
	local info = TweenInfo.new(CONFIG.fadeTime)
	TweenService:Create(banner, info, { BackgroundTransparency = if visible then CONFIG.backgroundTransparency else 1 }):Play()
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
		local style = CONFIG.styles[item.kind :: Social.AnnounceKind] or CONFIG.styles.Info
		banner.BackgroundColor3 = style.bg
		stroke.Color = style.stroke
		label.Text = `{style.icon}  {item.text}`
		banner.Visible = true
		fade(true)
		task.wait(CONFIG.showTime)
		fade(false)
	end
	banner.Visible = false
	showing = false
end

announceRemote.OnClientEvent:Connect(function(text: any, kind: any)
	-- 서버에서만 오지만, 형식이 틀린 값은 그냥 버린다
	if typeof(text) ~= "string" then return end
	if typeof(kind) ~= "string" then kind = Social.AnnounceKind.Info end
	table.insert(queue, { text = text, kind = kind })
	while #queue > CONFIG.maxQueue do table.remove(queue, 1) end
	task.spawn(showNext)
end)
