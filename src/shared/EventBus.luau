--[[
	이벤트 버스: Events.luau에 정의된 이름으로 기능끼리 신호를 주고받는 창구. (D-011)
	서버는 서버끼리, 클라이언트는 클라이언트끼리만 통한다 (내부적으로 BindableEvent).
	서버 ↔ 클라이언트는 이걸 쓰지 않고 ReplicatedStorage.Remotes의 RemoteEvent를 쓴다.

	사용법
		local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
		local Events = require(Shared.Events)
		local EventBus = require(Shared.EventBus)

		-- 보내기 (인자 순서는 Events.luau 주석 그대로)
		EventBus.Fire(Events.OreMined, player, "Ruby", 3.2, "High")

		-- 받기 (반환값의 :Disconnect()로 해제)
		EventBus.On(Events.OreMined, function(player, oreId, weight, pressure)
		end)

	주의
	- 넘긴 테이블은 복사본으로 도착한다 (BindableEvent 특성). 받는 쪽이 고쳐도 보낸 쪽엔 영향 없음.
	- 함수, 메타테이블은 넘어가지 않는다. 플레이어·파트 같은 Instance는 그대로 넘어간다.
	- 받는 함수는 Fire 직후가 아니라 같은 프레임 안에서 조금 뒤에 실행될 수 있다 (Deferred 이벤트).
]]

local Events = require(script.Parent.Events)

local EventBus = {}

-- Events.luau에 있는 이름만 허용한다. 오타(Events.OreMind → nil)를 조용히 넘기지 않고 바로 에러로 잡기 위해.
local valid: { [string]: boolean } = {}
for _, name in Events do
	valid[name] = true
end

-- 이벤트 이름 → BindableEvent. 처음 쓰일 때 만든다.
local bindables: { [string]: BindableEvent } = {}

local function get(name: string): BindableEvent
	if not valid[name] then
		-- 레벨 3: get → Fire/On → 호출한 코드 위치를 에러에 찍는다
		error(`EventBus: Events.luau에 없는 이벤트 "{tostring(name)}"`, 3)
	end
	local b = bindables[name]
	if not b then
		b = Instance.new("BindableEvent")
		bindables[name] = b
	end
	return b
end

-- 이벤트 보내기. 듣는 쪽이 없어도 에러 없이 지나간다.
function EventBus.Fire(name: string, ...: any)
	get(name):Fire(...)
end

-- 이벤트 받기. 게임 시작 때 한 번 등록해 두면 Fire될 때마다 callback이 실행된다.
function EventBus.On(name: string, callback: (...any) -> ()): RBXScriptConnection
	return get(name).Event:Connect(callback)
end

-- 딱 한 번만 받고 자동 해제.
function EventBus.Once(name: string, callback: (...any) -> ()): RBXScriptConnection
	return get(name).Event:Once(callback)
end

return table.freeze(EventBus)
