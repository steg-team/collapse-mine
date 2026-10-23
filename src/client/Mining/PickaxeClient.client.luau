-- 곡괭이 클릭 처리 (StarterPlayerScripts에서 실행)
-- 곡괭이 모델(Tool "Pickaxe")은 Studio의 StarterPack에 있고, 스크립트만 여기서 관리한다.

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local ev = RS:WaitForChild("Remotes"):WaitForChild("MineHit")
-- 휘두르는 간격 = 곡괭이 단계·강화·채굴 속도 배수 (서버와 같은 계산, D-026)
local Pickaxe = require(RS:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Pickaxe"))

local TOOL_NAME = "Pickaxe"
local last = 0

local function hook(tool)
	if not tool:IsA("Tool") or tool.Name ~= TOOL_NAME or tool:GetAttribute("_hooked") then return end
	tool:SetAttribute("_hooked", true)
	tool.Activated:Connect(function()
		if os.clock() - last < Pickaxe.stats(player).cooldown then return end
		last = os.clock()
		ev:FireServer(mouse.Target, mouse.Hit.Position)
	end)
end

local function watch(container)
	for _, c in ipairs(container:GetChildren()) do hook(c) end
	container.ChildAdded:Connect(hook)
end

watch(player:WaitForChild("Backpack"))
player.CharacterAdded:Connect(watch)
if player.Character then watch(player.Character) end
player.ChildAdded:Connect(function(c)
	if c:IsA("Backpack") then watch(c) end
end)
