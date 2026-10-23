--!strict
--[[
	플레이어 저장 데이터 (B 담당, D-014)
	플레이어당 키 하나에 전부 담고, 세션 잠금·자동 저장은 ProfileStore에 맡긴다.

	다른 기능에서 읽기
		local PlayerData = require(game:GetService("ServerScriptService").Server.Economy.PlayerData)
		EventBus.On(Events.PlayerDataLoaded, function(player)
			local data = PlayerData.get(player)
		end)

	규칙
	- PlayerDataLoaded 전이나 나간 뒤에는 get이 nil을 돌려준다.
	- 쓰기는 B만 한다. C는 data.social 칸만 쓴다 (안의 구조는 C가 정함).
	- Instance, Vector3 같은 userdata는 넣지 못한다 (문자열·숫자·테이블만).
]]

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local Shared = RS:WaitForChild("Shared")
local Events = require(Shared:WaitForChild("Events"))
local EventBus = require(Shared:WaitForChild("EventBus"))
local Mines = require(Shared:WaitForChild("Config"):WaitForChild("Mines"))
local Economy = require(Shared.Config:WaitForChild("Economy"))
local ProfileStore = require(script.Parent.ProfileStore)
-- C의 조회 함수 (D-011: "지금 상태"는 이벤트로 따로 들고 있지 않고 물어본다)
local Collapse = require(script.Parent.Parent:WaitForChild("Social"):WaitForChild("Collapse"))

export type BagItem = {
	ore: string,
	weight: number,
	pressure: string,
	value: number,
}

export type Data = {
	v: number,
	coins: number,
	pickaxe: { tier: number, enhance: number },
	canary: number,
	rebirths: number,
	bag: { BagItem },
	codex: { [string]: boolean },
	stats: { totalEarned: number, bestOre: number, bestHaul: number },
	social: { [string]: any },
}

-- 새 칸을 추가하면 기존 플레이어에게도 Reconcile로 채워진다.
-- 칸의 뜻이 바뀔 때만 v를 올리고 load에서 옮긴다.
local TEMPLATE: Data = {
	v = 1,
	coins = 0,
	pickaxe = { tier = 1, enhance = 0 },
	canary = 0,
	rebirths = 0,
	bag = {},
	codex = {},
	stats = { totalEarned = 0, bestOre = 0, bestHaul = 0 },
	social = {},
}

local store = ProfileStore.New("PlayerData", TEMPLATE)
local profiles: { [Player]: any } = {}
local lastMineId: { [Player]: string? } = {}
local rng = Random.new()

local PlayerData = {}

function PlayerData.get(player: Player): Data?
	local profile = profiles[player]
	return profile and profile.Data
end

-- 가방에서 TRAPPED_BAG_LOSS 비율만큼 무작위로 뺀다 (내림이라 1개뿐이면 안 잃음)
function PlayerData.loseBag(data: Data)
	for _ = 1, math.floor(#data.bag * Economy.TRAPPED_BAG_LOSS) do
		table.remove(data.bag, rng:NextInteger(1, #data.bag))
	end
end

local function load(player: Player)
	local profile = store:StartSessionAsync(`Player_{player.UserId}`, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})
	if not profile then
		-- 다른 서버가 잠금을 안 풀었거나 DataStore 장애. 빈 데이터로 시작하면 저장 때 덮어쓰므로 내보낸다.
		if player.Parent == Players then
			player:Kick("데이터를 불러오지 못했습니다. 다시 접속해 주세요.")
		end
		return
	end

	profile:AddUserId(player.UserId) -- GDPR 삭제 요청 대응
	profile:Reconcile()
	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		player:Kick("다른 서버에서 접속해 데이터를 옮겼습니다. 다시 접속해 주세요.")
	end)
	if player.Parent ~= Players then
		profile:EndSession()
		return
	end
	profiles[player] = profile

	local data: Data = profile.Data
	player:SetAttribute("PickaxeTier", data.pickaxe.tier)

	-- 퇴장 때는 PlayerRemoving보다 캐릭터가 먼저 지워지므로, 지워지는 순간 광산 안이었는지 적어 둔다
	player.CharacterRemoving:Connect(function(char)
		local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
		local mine = root and Mines.findAreaAt(root.Position) -- C의 isInside와 같은 기준 (출구 비탈 포함)
		lastMineId[player] = mine and mine.id
	end)

	-- ponytail: 채굴 코드(A)가 leaderstats.Coins에 직접 더하는 동안 그 값을 저장한다.
	-- 판매소가 생겨 코인 흐름이 B로 오면 data.coins를 직접 바꾸고 이 연결은 지운다.
	local ls = player:WaitForChild("leaderstats", 10)
	local coins = ls and ls:FindFirstChild("Coins") :: IntValue?
	if coins then
		coins.Value = data.coins
		coins.Changed:Connect(function(value)
			data.coins = value
		end)
	end

	EventBus.Fire(Events.PlayerDataLoaded, player)
end

local function release(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	profiles[player] = nil
	local mineId = lastMineId[player]
	lastMineId[player] = nil

	-- 경보 중에 광산 안에서 나가면 갇힘과 같은 차감 (나갔다 들어와 차감을 피하는 것 방지)
	if mineId and Collapse.GetRemainingTime(mineId) ~= nil then
		PlayerData.loseBag(profile.Data)
	end
	profile:EndSession()
end

function PlayerData.start()
	EventBus.On(Events.PlayerTrapped, function(player: Player)
		local data = PlayerData.get(player)
		if data then
			PlayerData.loseBag(data)
		end
	end)
	-- 탈출 보너스 지급. 코인을 leaderstats로 저장하는 동안은 거기에 더한다 (load의 ponytail 참고)
	EventBus.On(Events.PlayerEscaped, function(player: Player, _mineId: string, bonus: number)
		local ls = player:FindFirstChild("leaderstats")
		local coins = ls and ls:FindFirstChild("Coins") :: IntValue?
		if coins and PlayerData.get(player) then
			coins.Value += bonus
		end
	end)

	Players.PlayerAdded:Connect(load)
	Players.PlayerRemoving:Connect(release)
	-- 스크립트보다 먼저 들어온 플레이어 (Studio 테스트에서 흔함)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
end

return PlayerData
