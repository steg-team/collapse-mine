--!strict
--[[
	광산 카나리아 광맥 감지 (B 담당, D-036)
	0.5초마다 광산 안 플레이어마다 가장 가까운 숨은 희귀 광맥까지 거리를 재서,
	카나리아 탐지 범위 안이면 플레이어 속성 CanaryVeinDistance(스터드), 밖이면 nil 로 둔다. HUD(CanaryHud)가 읽는다.
	광맥 위치는 A의 Mining/RareVeins (서버 전용). 위치는 클라이언트에 보내지 않고 거리만 보낸다 (탐지 범위를 서버가 정함).
	RareVeins 모듈이 아직 없으면 아무것도 하지 않는다 (A 작업 #43 전에도 B가 동작하게).

	어깨 위 새 (D-023 보강): 캐릭터가 생길 때마다 ServerStorage.CanaryBird(블렌더 메시, tools/import_canary.luau)를 복제해
	오른쪽 어깨에 붙인다. 서버가 붙여서 다른 사람에게도 보인다. 움직임·울음소리는 각자 클라이언트(CanaryHud)가 자기 새에만.
	템플릿이 없으면 새 없이 HUD만 동작한다.
	레벨 장비 (D-045): 메시 이름 Canary_L<n>_<재질>. 카나리아 레벨(화면 Lv)보다 높은 n은 숨긴다. 헬멧 램프(_Lamp)에 PointLight (헤드랜턴 보조).
]]

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = RS:WaitForChild("Shared"):WaitForChild("Config")
local Economy = require(Config:WaitForChild("Economy"))
local Mines = require(Config:WaitForChild("Mines"))

local UPDATE = 0.5

-- 레벨에 맞게 장비를 보이고 숨기고, 헤드랜턴 빛 거리를 맞춘다
local function applyLevel(bird: Model, level: number)
	for _, p in bird:GetDescendants() do
		if p:IsA("BasePart") then
			local n = tonumber(p.Name:match("^Canary_L(%d+)_"))
			p.Transparency = if n and n > level + 1 then 1 else 0
		elseif p:IsA("PointLight") then
			p.Enabled = level >= Economy.CANARY_PERKS.lamp
			p.Range = Economy.CANARY_LAMP_RANGE + Economy.CANARY_LAMP_RANGE_PER_LEVEL * (level - Economy.CANARY_PERKS.lamp)
		end
	end
end

-- 새를 몸통 오른쪽 어깨 위에 앉힌다. 클라이언트가 이 Weld(이름 Seat)의 C0를 흔들어 움직인다
local function attachBird(char: Model)
	local template = ServerStorage:FindFirstChild("CanaryBird") :: Model?
	local torso = (char:WaitForChild("UpperTorso", 5) or char:FindFirstChild("Torso")) :: BasePart?
	if not template or not template.PrimaryPart or not torso or char:FindFirstChild("Canary") then
		return
	end
	local bird = template:Clone()
	bird.Name = "Canary"
	local seat = CFrame.new(torso.Size.X / 2 - 0.3, torso.Size.Y / 2, 0.1)
	bird:PivotTo(torso.CFrame * seat) -- 템플릿 피벗 = 발 밑 가운데
	local body = bird.PrimaryPart :: BasePart
	for _, p in bird:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.Massless = true
			p.CanCollide = false
			p.CanQuery = false -- 채굴 레이·클릭에 안 걸리게
			p.CanTouch = false -- 출구 발판·포탈 Touched에 안 걸리게
			p.CastShadow = false
			if p.Name:match("_Lamp$") then
				local light = Instance.new("PointLight")
				light.Color = Color3.fromRGB(255, 236, 190)
				light.Brightness = 1.6
				light.Shadows = true
				light.Parent = p
			end
			if p ~= body then
				local w = Instance.new("WeldConstraint")
				w.Part0 = body
				w.Part1 = p
				w.Parent = p
			end
		end
	end
	local weld = Instance.new("Weld")
	weld.Name = "Seat"
	weld.Part0 = torso
	weld.Part1 = body
	weld.C0 = torso.CFrame:ToObjectSpace(body.CFrame)
	weld.Parent = body
	local player = Players:GetPlayerFromCharacter(char)
	if player then
		applyLevel(bird, player:GetAttribute("CanaryLevel") or 0)
	end
	bird.Parent = char
end

local function onPlayer(player: Player)
	player.CharacterAdded:Connect(attachBird)
	player:GetAttributeChangedSignal("CanaryLevel"):Connect(function()
		local bird = player.Character and player.Character:FindFirstChild("Canary")
		if bird then
			applyLevel(bird :: Model, player:GetAttribute("CanaryLevel") or 0)
		end
	end)
	if player.Character then
		task.spawn(attachBird, player.Character)
	end
end

local Canary = {}

function Canary.start()
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	task.spawn(function()
		local mining = script.Parent.Parent:WaitForChild("Mining", 30)
		local mod = mining and mining:WaitForChild("RareVeins", 30)
		if not mod then
			return -- 광맥이 아직 없다: 카나리아는 드러난 광석·붕괴 경보만 (CanaryHud)
		end
		local ok, RareVeins = pcall(require, mod)
		if not ok then
			warn("[Canary] RareVeins 불러오기 실패: " .. tostring(RareVeins))
			return
		end
		while true do
			task.wait(UPDATE)
			for _, player in Players:GetPlayers() do
				local char = player.Character
				local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
				local mine = root and Mines.findAreaAt(root.Position)
				local dist: number? = nil
				if root and mine then
					local spec = Economy.CANARY[player:GetAttribute("CanaryLevel") or 0] or Economy.CANARY[0]
					local okCall, d = pcall(RareVeins.nearest, mine.id, root.Position)
					if okCall and typeof(d) == "number" and d <= spec.range then
						dist = math.floor(d)
					end
				end
				if player:GetAttribute("CanaryVeinDistance") ~= dist then
					player:SetAttribute("CanaryVeinDistance", dist)
				end
			end
		end
	end)
end

return Canary
