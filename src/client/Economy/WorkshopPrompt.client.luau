--!strict
-- 제작소 프롬프트에 "내" 다음 곡괭이 비용을 적는다 (B 담당, D-021)
-- 프롬프트는 서버 Workshop.luau 가 만들고 모두가 같은 것을 보므로, 문구만 클라이언트에서 플레이어별로 바꾼다.
-- 실제 비용 확인·차감은 서버가 한다 (여기 숫자는 안내용).

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")

local Config = RS:WaitForChild("Shared"):WaitForChild("Config")
local Economy = require(Config:WaitForChild("Economy"))
local Mines = require(Config:WaitForChild("Mines"))

local player = Players.LocalPlayer

local displayName: { [string]: string } = {}
for _, m in Mines.list do
	for _, o in m.ores do
		displayName[o.name] = o.displayName
	end
end

local prompts: { ProximityPrompt } = {}

local function texts(): (string, string)
	local tier = player:GetAttribute("PickaxeTier") or 1
	local enhance = player:GetAttribute("PickaxeEnhance") or 0
	local now = Economy.PICKAXES[tier]
	local nextSpec = Economy.PICKAXES[tier + 1]

	local craft = "가장 좋은 곡괭이예요"
	if nextSpec then
		local parts = { `{nextSpec.coins} 코인` }
		for oreId, n in nextSpec.ores do
			table.insert(parts, `{displayName[oreId] or oreId} {n}`)
		end
		craft = `{nextSpec.name} · {table.concat(parts, " + ")}`
	end

	local enh = `{now and now.name or ""} +{enhance} (최대)`
	if now and enhance < Economy.ENHANCE_MAX then
		enh = `{now.name} +{enhance} → +{enhance + 1} · {now.enhanceCost * (enhance + 1)} 코인`
	end
	return craft, enh
end

local function refresh()
	local craft, enh = texts()
	for _, p in prompts do
		p.ObjectText = if p.Name == "CraftPrompt" then craft else enh
	end
end

local function track(inst: Instance)
	if inst:IsA("ProximityPrompt") and (inst.Name == "CraftPrompt" or inst.Name == "EnhancePrompt") then
		table.insert(prompts, inst)
		refresh()
	end
end

workspace.DescendantAdded:Connect(track)
for _, inst in workspace:GetDescendants() do
	track(inst)
end
player:GetAttributeChangedSignal("PickaxeTier"):Connect(refresh)
player:GetAttributeChangedSignal("PickaxeEnhance"):Connect(refresh)
