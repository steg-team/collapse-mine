--!strict
-- 캐릭터 걸음 속도 (A, #37)
-- 걸음 속도에 붙는 효과를 여기 한 곳에서 곱한다. 지금은 가방 무게(B의 BagSpeedMultiplier, D-027) 하나.
-- 다른 속도 효과(부스트 등)가 생기면 speedOf에 곱하기를 더한다.
-- 서버가 Humanoid.WalkSpeed를 바꾸면 클라이언트에도 반영된다. 리스폰 뒤에도 다시 적용.

local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")

-- 기본 걸음 속도 = Studio의 StarterPlayer 설정 (기본 16)
local BASE_WALK = StarterPlayer.CharacterWalkSpeed

local function speedOf(player: Player): number
	local bag = tonumber(player:GetAttribute("BagSpeedMultiplier")) or 1
	-- 이상한 값이 와도 멈추거나 빨라지지 않게 (B 계약: 1 → 0.6)
	if bag ~= bag then bag = 1 end -- NaN
	bag = math.clamp(bag, 0.3, 1)
	return BASE_WALK * bag
end

local function apply(player: Player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then hum.WalkSpeed = speedOf(player) end
end

local function onPlayer(player: Player)
	player:GetAttributeChangedSignal("BagSpeedMultiplier"):Connect(function() apply(player) end)
	player.CharacterAdded:Connect(function(char)
		char:WaitForChild("Humanoid", 10)
		apply(player)
	end)
	apply(player)
end

Players.PlayerAdded:Connect(onPlayer)
-- 스크립트보다 먼저 들어온 플레이어 (Studio 테스트에서 흔함)
for _, p in Players:GetPlayers() do onPlayer(p) end
