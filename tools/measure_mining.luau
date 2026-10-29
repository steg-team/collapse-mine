--[[
	채굴 속도 측정 (A) — 레시피 개수·콘텐츠 소비 시간을 정하려고 "실제로 1분에 몇 개 캐나"를 잰다.

	쓰는 법
	1. Studio에서 Play.
	2. 상단 [테스트] 탭의 "현재: 클라이언트" 버튼을 눌러 서버 보기로 바꾼다.
	3. 이 파일 전체를 명령창(보기 → 명령 모음)에 붙여넣고 실행 → "측정 시작".
	4. 다시 클라이언트 보기로 돌아가 평소처럼 5~10분 플레이 (광산 들어가서 캐고, 나와서 팔고).
	   1분마다 출력 창에 중간 결과가 찍힌다.
	5. 끝낼 때 서버 보기에서 이 파일을 한 번 더 실행 → 최종 보고 출력 후 측정 끝.

	재는 것 (플레이어마다)
	- 전체 시간, 광산 안에 있던 시간(광산별)
	- 등급별·광물별로 캔 개수 (OreMined). 희귀 이상은 지형을 팔 때만 나오고, 일반·고급은 벽 광석이다
	- 광산 안 1분당 등급별 개수  ← 레시피 계산에 쓰는 숫자
	- 판매 코인 (OreSold), 전체 1분당 판매 코인

	왜 Script를 따로 만드나: 명령창에서 require한 모듈은 게임 스크립트와 다른 사본이라
	EventBus 신호를 못 받는다. 게임 안에서 도는 Script를 넣어야 진짜 신호를 받는다.
	측정용 Script(ServerScriptService._MiningMeter)는 Play를 멈추면 같이 사라진다 (Edit에는 남지 않음).
]]

local RunService = game:GetService("RunService")
local SSS = game:GetService("ServerScriptService")

if not RunService:IsRunning() or not RunService:IsServer() then
	warn("[측정] Play 중 서버 보기에서 실행하세요 (지금은 Edit이거나 클라이언트 보기)")
	return
end

local old = SSS:FindFirstChild("_MiningMeter")
if old then
	local report = old:FindFirstChild("Report") :: BindableFunction?
	if report then
		report:Invoke(true)
	end
	old:Destroy()
	print("[측정] 끝")
	return
end

local SOURCE = [==[
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Shared = RS:WaitForChild("Shared")
local Events = require(Shared:WaitForChild("Events"))
local EventBus = require(Shared:WaitForChild("EventBus"))
local Mines = require(Shared:WaitForChild("Config"):WaitForChild("Mines"))

local GRADES = { "일반", "고급", "희귀", "에픽", "전설", "신화" }

-- 광물 이름 → { 등급, 표시 이름, 광산 id }
local oreInfo = {}
for _, m in Mines.list do
	for _, o in m.ores do
		oreInfo[o.name] = { grade = o.grade, name = o.displayName, mine = m.id }
	end
end

local started = os.clock()
local stats = {}
local function get(plr)
	local s = stats[plr]
	if not s then
		s = { inMine = {}, grade = {}, ore = {}, coins = 0, depthSum = 0, depthN = 0, lastMin = {} }
		stats[plr] = s
	end
	return s
end

local conns = {}
table.insert(conns, EventBus.On(Events.OreMined, function(plr, oreId)
	local info = oreInfo[oreId]
	local s = get(plr)
	local g = info and info.grade or "?"
	s.grade[g] = (s.grade[g] or 0) + 1
	local key = info and `{info.mine}/{info.name}` or tostring(oreId)
	s.ore[key] = (s.ore[key] or 0) + 1
end))
table.insert(conns, EventBus.On(Events.OreSold, function(plr, _oreId, _count, total)
	local s = get(plr)
	s.coins += tonumber(total) or 0
end))

-- 1초마다 어디 있는지 (광산 안 시간, 평균 깊이 비율)
task.spawn(function()
	while script.Parent do
		task.wait(1)
		for _, plr in Players:GetPlayers() do
			local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
			if root then
				local m = Mines.findAreaAt(root.Position)
				if m then
					local s = get(plr)
					s.inMine[m.id] = (s.inMine[m.id] or 0) + 1
					local t = math.clamp((m.top - root.Position.Y) / (m.top - m.bottom), 0, 1)
					s.depthSum += t
					s.depthN += 1
				end
			end
		end
	end
end)

local function fmt(n) return string.format("%.1f", n) end

local function report(final)
	local elapsed = (os.clock() - started) / 60
	print(string.rep("=", 60))
	print(`[측정] {final and "최종" or "중간"} 보고 — 경과 {fmt(elapsed)}분`)
	for plr, s in stats do
		local mineSec = 0
		local where = {}
		for id, sec in s.inMine do
			mineSec += sec
			table.insert(where, `{id} {fmt(sec / 60)}분`)
		end
		local mineMin = math.max(mineSec / 60, 1 / 60)
		local total = 0
		for _, n in s.grade do total += n end
		print(`- {plr.Name}: 광산 안 {fmt(mineSec / 60)}분 ({table.concat(where, ", ")}), 평균 깊이 {math.floor((s.depthN > 0 and s.depthSum / s.depthN or 0) * 100)}%`)
		print(`  캔 광물 {total}개 → 광산 안 1분당 {fmt(total / mineMin)}개`)
		local parts = {}
		for _, g in GRADES do
			local n = s.grade[g] or 0
			if n > 0 then table.insert(parts, `{g} {n} ({fmt(n / mineMin)}/분)`) end
		end
		if s.grade["?"] then table.insert(parts, `알 수 없음 {s.grade["?"]}`) end
		print(`  등급별: {#parts > 0 and table.concat(parts, " · ") or "없음"}`)
		print(`  판매 {math.floor(s.coins)}코인 → 전체 1분당 {fmt(s.coins / math.max(elapsed, 1 / 60))}코인`)
		if final then
			local list = {}
			for k, n in s.ore do table.insert(list, { k, n }) end
			table.sort(list, function(a, b) return a[2] > b[2] end)
			for _, it in list do print(`    {it[1]}: {it[2]}`) end
		end
	end
	if next(stats) == nil then print("  (아직 캔 사람 없음)") end
	print(string.rep("=", 60))
end

local fn = Instance.new("BindableFunction")
fn.Name = "Report"
fn.OnInvoke = function(final)
	report(final)
	for _, c in conns do pcall(function() c:Disconnect() end) end
	return true
end
fn.Parent = script

task.spawn(function()
	while script.Parent do
		task.wait(60)
		if script.Parent then report(false) end
	end
end)

print("[측정] 시작 — 평소처럼 플레이하세요. 1분마다 중간 보고, 끝낼 땐 measure_mining.luau를 한 번 더 실행")
]==]

local meter = Instance.new("Script")
meter.Name = "_MiningMeter"
meter.Source = SOURCE
meter.Parent = SSS
