--!strict
-- 붕괴 연출 신호 (A, D-040)
-- 붕괴(CollapseOccurred) 순간 광산 안에 있는 사람 = C가 갇힘으로 치는 사람에게 Remotes.CollapseFx를 보낸다.
-- 돌·먼지·흔들림·소리는 클라이언트(CollapseFx.client)가 만든다. 서버는 누구에게 얼마 동안 보일지만 정한다.

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local Shared = RS:WaitForChild("Shared")
local Mines = require(Shared:WaitForChild("Config"):WaitForChild("Mines"))
local Social = require(Shared:WaitForChild("Config"):WaitForChild("Social"))
local Events = require(Shared:WaitForChild("Events"))
local EventBus = require(Shared:WaitForChild("EventBus"))

-- Remotes 폴더는 Studio에서 관리하지만, 없으면 만든다 (다른 담당 Remote와 같은 방식)
local remotes = RS:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = RS
end
local fx = remotes:FindFirstChild("CollapseFx") :: RemoteEvent?
if not fx then
	local e = Instance.new("RemoteEvent")
	e.Name = "CollapseFx"
	e.Parent = remotes
	fx = e
end
local remote = fx :: RemoteEvent

-- 갇힌 사람이 허브로 옮겨지기까지(C 설정). 그동안 연출을 보여 준다
local function duration(): number
	local c = (Social :: any).Collapse
	return (c and tonumber(c.trappedTeleportDelay)) or 3
end

-- (mineId: string) — Events.luau 계약. C가 같은 순간 갇힘을 판정하니 같은 기준(findAreaAt)으로 고른다
EventBus.On(Events.CollapseOccurred, function(mineId: string)
	local mine = Mines.get(mineId)
	if not mine then return end
	local d = duration()
	for _, player in Players:GetPlayers() do
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and Mines.findAreaAt(root.Position) == mine then
			remote:FireClient(player, mineId, d)
		end
	end
end)
