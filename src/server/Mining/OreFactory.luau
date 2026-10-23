--!strict
-- 광석 만들기 공통 (A): 광물 뽑기 + 광물 틀(ServerStorage.OreModels) 복사해서 지형 표면에 박기.
-- 벽 광석 다시 채우기(OreSpawner)와 파다가 발견(MiningServer)이 같이 쓴다.
-- 맵 도구(tools/generate_mine.luau, replace_mine_ores.luau)에도 같은 규칙이 복사돼 있으니 바꾸면 같이 맞춘다.

local SS = game:GetService("ServerStorage")
local CS = game:GetService("CollectionService")
local Mines = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Mines"))

local OreFactory = {}

-- 파야만 나오는 등급인지 (Mines 설정 digFinds.grades). 이 등급은 벽에 미리 박지 않는다
function OreFactory.isDigFind(m: Mines.Mine, o: Mines.Ore): boolean
	return m.digFinds ~= nil and table.find(m.digFinds.grades, o.grade) ~= nil
end

-- 깊이 조건(minDepth)을 만족하는 광물 중 무게(weight)로 하나 뽑기.
-- digFind = true면 파야 나오는 등급만, false면 벽에 박히는 등급만
function OreFactory.pick(m: Mines.Mine, y: number, digFind: boolean, rng: Random): Mines.Ore?
	local d = m.top - y
	local total, pool = 0, {}
	for _, o in m.ores do
		if d >= o.minDepth and OreFactory.isDigFind(m, o) == digFind then
			total += o.weight
			table.insert(pool, o)
		end
	end
	if #pool == 0 then return nil end
	local n = rng:NextNumber(0, total)
	for _, o in pool do
		n -= o.weight
		if n <= 0 then return o end
	end
	return pool[#pool]
end

local function findTemplate(path: string?): Model?
	if not path then return nil end
	local node: Instance? = SS:FindFirstChild("OreModels")
	for part in string.gmatch(path, "[^/]+") do
		node = node and node:FindFirstChild(part)
	end
	return if node and node:IsA("Model") then node else nil
end

-- 지형 레이캐스트 결과(표면)에 바닥을 붙여 세울 자리. 조금 파묻어서 벽에서 자라난 것처럼
function OreFactory.surfaceCFrame(hit: RaycastResult): CFrame
	local up = hit.Normal
	local cross = up:Cross(Vector3.yAxis)
	local look = if cross.Magnitude > 0.1 then cross.Unit else Vector3.xAxis
	return CFrame.fromMatrix(hit.Position - up * 0.35, look, up)
end

-- 광석 하나 만들어 folder에 넣기. surfaceCf = 표면에 바닥을 붙인 자리 (UpVector = 굴 쪽)
function OreFactory.spawn(m: Mines.Mine, folder: Instance, o: Mines.Ore, surfaceCf: CFrame, mult: number, rng: Random, origin: string): Model?
	local tpl = findTemplate(o.model)
	if not tpl then return nil end
	local model = tpl:Clone()
	model:ScaleTo(rng:NextNumber(1.1, 1.5))
	local cf = surfaceCf * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	model:PivotTo(cf)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then d.Anchored = true end
	end
	local layer, li = Mines.layerAt(m, cf.Position.Y)
	model.Name = o.name
	model:SetAttribute("Vein", true)
	model:SetAttribute("MineId", m.id)
	model:SetAttribute("Ore", o.name)
	model:SetAttribute("DisplayName", o.displayName)
	model:SetAttribute("Grade", o.grade)
	model:SetAttribute("OreValue", o.value * mult)
	model:SetAttribute("Hardness", layer.hardness + o.hardness - 1)
	model:SetAttribute("Layer", li)
	model:SetAttribute("Origin", origin)
	CS:AddTag(model, "Ore")
	model.Parent = folder
	return model
end

return OreFactory
