--!strict
-- 결제 (C 담당): 게임패스 보유 확인, 서버 부스트(개발자 상품, D-017), 패스·부스트 배수
--
-- ⚠️ MarketplaceService.ProcessReceipt 는 게임 전체에 하나만 둘 수 있다. 여기서만 설정하고 다른 곳에서 덮어쓰지 않는다.
--
-- A·B 는 MarketplaceService 를 직접 쓰지 말고 이 모듈만 쓴다. 결제 관련 문제가 생기면 여기 한 곳만 보면 되게.
--
--   local Payments = require(game.ServerScriptService.Server.Social.Payments)
--   Payments.HasPass(player, Social.PassName.AutoMine)               --> true / false
--   Payments.GetMultiplier(player, Social.MultiplierKind.MineSpeed)  --> 1, 2, ...
--
-- 패스 목록·가격·배수, 패스 이름은 src/shared/Config/Social.luau

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")

local SSS = game:GetService("ServerScriptService")

local Social = require(RS:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Social"))
local PlayerData = require(SSS:WaitForChild("Server"):WaitForChild("Economy"):WaitForChild("PlayerData"))
local Passes = Social.Passes
local BOOST = Social.ServerBoost

-- 서버 부스트가 끝나는 시각 (workspace:GetServerTimeNow 기준, 0 이면 없음)
-- 클라이언트 표시용으로 ReplicatedStorage.ServerBoost 의 속성 EndsAt 에도 올린다
local boostEndsAt = 0
local boostState = RS:FindFirstChild("ServerBoost") or Instance.new("Folder")
boostState.Name = "ServerBoost"
boostState.Parent = RS

export type MultiplierKind = Social.MultiplierKind

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
	if (Passes :: any)[passName] == nil then
		-- 오타를 조용히 넘기지 않기 위해 경고 (패스 이름은 Config/Social.luau 의 PassName)
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
	-- 서버 부스트 (서버 전체 공통)
	local boostM = BOOST.multiplier[kind]
	if boostM and Payments.IsBoostActive() then
		result *= boostM
	end
	return result
end

function Payments.IsBoostActive(): boolean
	return workspace:GetServerTimeNow() < boostEndsAt
end

-- 서버 부스트 켜기 / 연장. buyer 는 공지용 (테스트면 nil)
local Announcer -- 늦게 불러온다 (Announcer 가 Remotes 를 기다리는 동안 결제 처리가 막히지 않게)
local function grantBoost(buyer: Player?)
	local now = workspace:GetServerTimeNow()
	local extending = boostEndsAt > now
	-- 이미 켜져 있으면 남은 시간 뒤에 이어 붙인다 (배수는 그대로)
	boostEndsAt = math.max(boostEndsAt, now) + BOOST.duration
	boostState:SetAttribute("EndsAt", boostEndsAt)

	Announcer = Announcer or require(script.Parent:WaitForChild("Announcer"))
	local who = if buyer then `{buyer.DisplayName}님이` else "누군가"
	local minutes = BOOST.duration // 60
	if extending then
		Announcer.announce(`{who} 서버 부스트를 {minutes}분 연장했습니다!`, Social.AnnounceKind.Boost)
	else
		Announcer.announce(`{who} 서버 전체에 {BOOST.displayName}를 선물했습니다! ({minutes}분)`, Social.AnnounceKind.Boost)
	end
end

-- 개발자 상품 결제 처리. 로블록스가 "지급 완료(PurchaseGranted)"를 받을 때까지 같은 영수증을 계속 다시 보낸다.
-- 그래서 영수증 ID 를 저장해 두고, 이미 처리한 영수증이면 지급 없이 완료만 알린다 (중복 지급 방지).
MarketplaceService.ProcessReceipt = function(info)
	local player = Players:GetPlayerByUserId(info.PlayerId)
	local data = player and PlayerData.get(player)
	if not player or not data then
		-- 나갔거나 저장 데이터가 아직 없음 → 다음 접속 때 로블록스가 다시 보냄
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local receipts = data.social.receipts
	if typeof(receipts) ~= "table" then
		receipts = {}
		data.social.receipts = receipts
	end
	if table.find(receipts, info.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	if info.ProductId == BOOST.productId and BOOST.productId ~= 0 then
		grantBoost(player)
	else
		warn(`[Payments] 모르는 개발자 상품 {info.ProductId}`)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- 지급 기록 (오래된 것부터 버려서 개수 제한)
	table.insert(receipts, info.PurchaseId)
	while #receipts > BOOST.receiptHistory do table.remove(receipts, 1) end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- Studio 테스트: Command Bar 에서 workspace:SetAttribute("BoostTest", true) → 결제 없이 부스트 켜기/연장
-- (상품 id 가 아직 0 이라 실제 구매 창을 띄울 수 없으므로)
if RunService:IsStudio() then
	workspace:GetAttributeChangedSignal("BoostTest"):Connect(function()
		if workspace:GetAttribute("BoostTest") then
			workspace:SetAttribute("BoostTest", nil)
			grantBoost(nil)
		end
	end)
end

-- 게임 안에서 패스 구매 창 띄우기 (서버에서 호출. 클라이언트 버튼은 나중에 상점/UI 작업 때)
function Payments.PromptPass(player: Player, passName: string)
	local pass = (Passes :: any)[passName] :: Social.Pass?
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
