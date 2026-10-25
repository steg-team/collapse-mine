--!strict
--[[
	허브 건물 Counter 상호작용과 한 줄 알림 (B 담당)
	판매소(Bag)·제작소(Workshop)가 같이 쓴다. 건물은 스테이지 허브마다 하나씩 있다 (D-019, #17).

	Counter.prompt(building, name, actionText, onTriggered, key?, hold?)  Counter에 프롬프트 붙이기 (겹치지 않게 위아래로 쌓음)
	Counter.isNear(player, building)                                     서버에서 다시 재는 거리 판정
	Counter.notify(player, text)                                         화면 아래 HUD 한 줄 알림 (BagHud 가 EconomyNotice 를 읽음)
]]

local RS = game:GetService("ReplicatedStorage")

local Economy = require(RS:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Economy"))

local Counter = {}

-- 화면 아래 HUD에 한 줄 알림 (판매 결과, 제작 실패 이유 등). 같은 문구가 연달아 와도 다시 뜨게 시각도 같이 올린다
function Counter.notify(player: Player, text: string)
	player:SetAttribute("EconomyNotice", text)
	player:SetAttribute("EconomyNoticeAt", os.clock())
end

-- 허브마다 있는 건물(Shop, Workshop)의 Counter (스테이지별 허브, #17). 이름이 CollapseMine 으로 시작하는 폴더의 Hub/<building>/Counter
local function counters(building: string): { BasePart }
	local list = {}
	for _, hub in workspace:GetChildren() do
		local root = hub.Name:sub(1, 12) == "CollapseMine" and hub:FindFirstChild("Hub")
		local house = root and root:FindFirstChild(building)
		local counter = house and house:FindFirstChild("Counter")
		if counter and counter:IsA("BasePart") then
			table.insert(list, counter)
		end
	end
	return list
end

-- 플레이어가 그 건물 Counter 근처인지. 프롬프트·창 버튼은 클라이언트가 띄우므로 서버에서 한 번 더 잰다
function Counter.isNear(player: Player, building: string): boolean
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return false
	end
	for _, counter in counters(building) do
		if (hrp.Position - counter.Position).Magnitude <= Economy.SELL_REACH then
			return true
		end
	end
	return false
end

local PROMPT_GAP = 78 -- 기본 프롬프트 높이(72px) + 여백

-- Counter에 프롬프트를 붙인다. 클라이언트는 name으로 찾아 문구를 바꾼다
function Counter.prompt(building: string, name: string, actionText: string, onTriggered: (Player) -> (), key: Enum.KeyCode?, hold: number?)
	for _, counter in counters(building) do
		if not counter:FindFirstChild(name) then
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = name
			prompt.ActionText = actionText
			prompt.HoldDuration = hold or 0.3
			prompt.MaxActivationDistance = 10
			prompt.RequiresLineOfSight = false
			prompt.KeyboardKeyCode = key or Enum.KeyCode.E -- 한 Counter에 프롬프트가 둘이면 키를 다르게
			prompt.Parent = counter
			-- 같은 Counter의 프롬프트는 같은 자리에 그려져 글자가 겹친다. 위아래로 쌓고 가운데를 Counter에 맞춘다
			local stack = {}
			for _, c in counter:GetChildren() do
				if c:IsA("ProximityPrompt") then
					table.insert(stack, c)
				end
			end
			for i, p in stack do
				p.UIOffset = Vector2.new(0, (i - 1 - (#stack - 1) / 2) * PROMPT_GAP)
			end
			prompt.Triggered:Connect(function(player: Player)
				if Counter.isNear(player, building) then
					onTriggered(player)
				end
			end)
		end
	end
end

return Counter
