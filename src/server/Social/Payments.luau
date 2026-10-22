--!strict
-- 결제 (C 담당): 게임패스 보유 확인, 패스·부스트 배수
--
-- A·B 는 MarketplaceService 를 직접 쓰지 말고 이 모듈만 쓴다. 결제 관련 문제가 생기면 여기 한 곳만 보면 되게.
--
--   local Payments = require(game.ServerScriptService.Server.Social.Payments)
--   Payments.HasPass(player, "AutoMine")          --> true / false
--   Payments.GetMultiplier(player, "MineSpeed")   --> 1, 2, ...
--
-- 패스 목록·가격·배수는 src/shared/Config/Passes.luau

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")

local Passes = require(RS:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Passes"))

export type MultiplierKind = "MineSpeed" | "SellPrice"

-- 플레이어별 보유 패스 캐시. UserOwnsGamePassAsync 는 느리고 호출 제한이 있어서
-- 입장할 때 한 번만 묻고, 그 뒤로는 캐시에서 바로 답한다.
local owned: { [Player]: { [string]: boolean } } = {}

-- 패스 id → 이름 (구매 완료 이벤트는 id 로 오기 때문에)
local nameById: { [number]: string } = {}
for name, pass in Passes do
	if pass.id ~= 0 then nameById[pass.id] = name end
end

local Payments = {}

local function loadOwned(player: Player)
	local set: { [string]: boolean } = {}
	owned[player] = set -- 조회 중에도 HasPass 가 에러 없이 false 를 돌려주게 먼저 넣어둔다
	for name, pass in Passes do
		if pass.id ~= 0 then
			-- 로블록스 서버 오류로 실패할 수 있어서 pcall. 실패하면 이번 접속 동안은 미보유로 본다
			local ok, has = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.id)
			if ok then
				set[name] = has == true
			else
				warn(`[Payments] {player.Name} 의 {name} 보유 확인 실패: {has}`)
			end
		end
	end
end

-- 게임패스 보유 여부. 입장 직후 조회가 끝나기 전에는 false 가 나올 수 있다.
function Payments.HasPass(player: Player, passName: string): boolean
	if Passes[passName] == nil then
		-- 오타를 조용히 넘기지 않기 위해 경고 (패스 이름은 Config/Passes.luau 참고)
		warn(`[Payments] 없는 패스 이름: {passName}`)
		return false
	end
	-- Studio 테스트용: 플레이어 속성 TestPass_<이름> = true 면 보유로 친다 (실서버에선 무시)
	if RunService:IsStudio() and player:GetAttribute("TestPass_" .. passName) == true then
		return true
	end
	local set = owned[player]
	return set ~= nil and set[passName] == true
end

-- 패스(+ 나중에 부스트)를 합친 최종 배수. 효과가 없으면 1.
function Payments.GetMultiplier(player: Player, kind: MultiplierKind): number
	local result = 1
	for name, pass in Passes do
		local m = pass.multiplier and pass.multiplier[kind]
		if m and Payments.HasPass(player, name) then
			result *= m
		end
	end
	-- TODO 서버 부스트(개발자 상품): B의 데이터 저장이 생기면 ProcessReceipt + 만료 시각 저장과 함께 여기서 곱한다
	return result
end

-- 게임 안에서 패스 구매 창 띄우기 (서버에서 호출. 클라이언트 버튼은 나중에 상점/UI 작업 때)
function Payments.PromptPass(player: Player, passName: string)
	local pass = Passes[passName]
	if not pass or pass.id == 0 then
		warn(`[Payments] 구매 창을 띄울 수 없는 패스: {passName} (id 미설정)`)
		return
	end
	MarketplaceService:PromptGamePassPurchase(player, pass.id)
end

-- 게임 중에 산 패스는 캐시에 바로 반영 (다시 접속하지 않아도 효과가 생기게)
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, passId: number, purchased: boolean)
	if not purchased then return end
	local name = nameById[passId]
	local set = owned[player]
	if name and set then set[name] = true end
end)

Players.PlayerAdded:Connect(function(player) task.spawn(loadOwned, player) end)
Players.PlayerRemoving:Connect(function(player) owned[player] = nil end)
-- 이 모듈이 처음 require 되기 전에 이미 들어와 있던 플레이어 (Studio 테스트에서 흔함)
for _, player in Players:GetPlayers() do
	if not owned[player] then task.spawn(loadOwned, player) end
end

return table.freeze(Payments)
