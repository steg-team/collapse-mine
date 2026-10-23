--!strict
--[[
	광산 설정 — 광산 하나 = 아래 목록의 항목 하나 (docs/decisions.md D-006)

	공통 코드(MiningServer, MineTravel)와 맵 생성기(tools/generate_mine.luau)가 이 파일만 읽는다.
	새 광산을 추가할 때: 항목을 하나 추가 → Studio에서 생성기 실행 → 허브에 포탈 배치.

	좌표 규칙
	  origin  광산 중심의 지표 위치 (y=0). 광산끼리, 그리고 허브와 반경이 겹치지 않게 멀리 둔다.
	  top     지표 바로 아래 (첫 지층 시작 y)
	  bottom  광산 바닥 y
	  minDepth 광물이 나오기 시작하는 깊이 (top에서 아래로 잰 값)

	"임시값" 표시는 밸런스 테스트 전 숫자다.
]]

export type Layer = {
	name: string,
	top: number,
	bottom: number,
	material: Enum.Material,
	hardness: number,
}

export type Ore = {
	name: string,
	displayName: string,
	grade: string,
	value: number,
	weight: number,
	minDepth: number,
	hardness: number,
	color: Color3,
	material: Enum.Material,
	model: string?,
}

export type Mine = {
	id: string,
	name: string,
	order: number,
	requiredPickaxe: number,
	origin: Vector3,
	radius: number,
	top: number,
	bottom: number,
	layers: { Layer },
	ores: { Ore },
	-- 이 등급 광물은 벽에 미리 박지 않고, 지형을 팔 때마다 확률로 나온다 (판 자리 벽에 드러남).
	-- chance = 한 번 팔 때 나올 확률. Min은 지표, Max는 광산 바닥에서의 확률이고 깊이에 따라 사이 값.
	-- 나오는 광물은 그 깊이의 minDepth를 만족하는 것 중 weight로 뽑음
	digFinds: { grades: { string }, chance: NumberRange }?,
	oreRegrowDelay: number?, -- 붕괴 뒤 빈 벽 광석 자리를 다시 채우기까지 초
	-- interval: 붕괴 주기(초) 범위, 매 주기 이 안에서 랜덤 / warning: 경보 길이(초) / offset: 첫 붕괴를 미루는 시간(초), 광산끼리 엇갈리게 (D-013)
	collapse: { interval: NumberRange, warning: number, offset: number },
	cave: {
		seed: number,
		branches: number,
		hubRooms: number,
		roomSpacing: NumberRange,
		subBranchChance: number,
		tunnelRadius: number,
		roomScale: number?, -- 방 반경·높이 배율 (기본 1)
	},
}

local Mines = {}

Mines.list = {
	{
		id = "basic",
		name = "기본 광산",
		order = 1,
		requiredPickaxe = 1, -- 나무 곡괭이
		origin = Vector3.new(0, 0, -900),
		radius = 350,
		top = -4,
		bottom = -125,
		layers = {
			{ name = "흙층", top = -4, bottom = -50, material = Enum.Material.Ground, hardness = 1 },
			{ name = "바위층", top = -50, bottom = -125, material = Enum.Material.Slate, hardness = 2 },
		},
		-- 1스테이지 "흙 동굴" 광물 6종 (D-012). 가치·확률·경도 모두 임시값
		-- model = ServerStorage.OreModels 아래 광물 틀 경로. 틀이 없으면 color·material로 만든 돌 파트를 쓴다.
		ores = {
			{ name = "Coal", displayName = "석탄", grade = "일반", value = 2, weight = 50, minDepth = 0, hardness = 1,
				color = Color3.fromRGB(40, 40, 46), material = Enum.Material.Slate, model = "Stage01/Coal" },
			{ name = "Copper", displayName = "구리", grade = "일반", value = 5, weight = 30, minDepth = 0, hardness = 1,
				color = Color3.fromRGB(200, 115, 60), material = Enum.Material.Metal, model = "Stage01/Copper" },
			{ name = "Quartz", displayName = "석영", grade = "고급", value = 15, weight = 12, minDepth = 15, hardness = 2,
				color = Color3.fromRGB(235, 235, 245), material = Enum.Material.Glass, model = "Stage01/Quartz" },
			{ name = "Amber", displayName = "호박석", grade = "희귀", value = 45, weight = 5, minDepth = 35, hardness = 2,
				color = Color3.fromRGB(230, 150, 40), material = Enum.Material.Glass, model = "Stage01/Amber" },
			{ name = "CavePearl", displayName = "동굴 진주", grade = "에픽", value = 140, weight = 2.5, minDepth = 60, hardness = 3,
				color = Color3.fromRGB(245, 240, 225), material = Enum.Material.SmoothPlastic, model = "Stage01/CavePearl" },
			{ name = "Lantern", displayName = "광부의 녹슨 등불", grade = "전설", value = 480, weight = 0.2, minDepth = 80, hardness = 4,
				color = Color3.fromRGB(150, 90, 50), material = Enum.Material.CorrodedMetal, model = "Stage01/Lantern" },
		},
		digFinds = { grades = { "희귀", "에픽", "전설" }, chance = NumberRange.new(0.004, 0.012) }, -- 임시값 (곡괭이 0.35초마다 → 깊이 40 호박석 약 1분, 깊이 100 등불 약 20분)
		oreRegrowDelay = 5, -- 임시값 (초)
		collapse = { interval = NumberRange.new(480, 720), warning = 60, offset = 0 }, -- 8~12분 랜덤, 임시값 (초)
		cave = {
			seed = 7,
			branches = 12,
			hubRooms = 4,
			roomSpacing = NumberRange.new(40, 60),
			subBranchChance = 0.45,
			tunnelRadius = 7, -- 굴 폭 약 14 (좁아 보이지 않게)
			roomScale = 1.4,
		},
	},
	{
		id = "iron",
		name = "철광 갱도",
		order = 2,
		requiredPickaxe = 2, -- 돌 곡괭이
		origin = Vector3.new(-900, 0, -900),
		radius = 350,
		top = -4,
		bottom = -125,
		layers = {
			{ name = "갱도 바위층", top = -4, bottom = -55, material = Enum.Material.Slate, hardness = 2 },
			{ name = "철광층", top = -55, bottom = -125, material = Enum.Material.Basalt, hardness = 3 },
		},
		-- 2스테이지 "철광 갱도" 광물 6종 (공유 기획서, D-017). 가치·확률·경도 모두 임시값
		ores = {
			{ name = "Iron", displayName = "철", grade = "일반", value = 6, weight = 50, minDepth = 0, hardness = 1,
				color = Color3.fromRGB(120, 105, 100), material = Enum.Material.CorrodedMetal, model = "Stage02/Iron" },
			{ name = "Tin", displayName = "주석", grade = "일반", value = 9, weight = 30, minDepth = 0, hardness = 1,
				color = Color3.fromRGB(190, 195, 200), material = Enum.Material.Metal, model = "Stage02/Tin" },
			{ name = "Silver", displayName = "은", grade = "고급", value = 30, weight = 12, minDepth = 15, hardness = 2,
				color = Color3.fromRGB(225, 228, 235), material = Enum.Material.Metal, model = "Stage02/Silver" },
			{ name = "Magnetite", displayName = "자철석", grade = "희귀", value = 90, weight = 5, minDepth = 35, hardness = 2,
				color = Color3.fromRGB(30, 30, 34), material = Enum.Material.Basalt, model = "Stage02/Magnetite" },
			{ name = "Platinum", displayName = "백금", grade = "에픽", value = 280, weight = 2.5, minDepth = 60, hardness = 3,
				color = Color3.fromRGB(230, 230, 220), material = Enum.Material.Foil, model = "Stage02/Platinum" },
			{ name = "PocketWatch", displayName = "감독관의 회중시계", grade = "전설", value = 950, weight = 0.2, minDepth = 80, hardness = 4,
				color = Color3.fromRGB(200, 160, 60), material = Enum.Material.Metal, model = "Stage02/PocketWatch" },
		},
		digFinds = { grades = { "희귀", "에픽", "전설" }, chance = NumberRange.new(0.004, 0.012) }, -- 임시값
		oreRegrowDelay = 5, -- 임시값 (초)
		collapse = { interval = NumberRange.new(480, 720), warning = 60, offset = 180 }, -- 기본 광산과 3분 엇갈림, 임시값 (초)
		cave = {
			seed = 11,
			branches = 12,
			hubRooms = 4,
			roomSpacing = NumberRange.new(40, 60),
			subBranchChance = 0.45,
			tunnelRadius = 7,
			roomScale = 1.4,
		},
	},
	{
		id = "groundwater",
		name = "지하수 동굴",
		order = 3,
		requiredPickaxe = 3, -- 철 곡괭이
		origin = Vector3.new(900, 0, -900),
		radius = 350,
		top = -4,
		bottom = -125,
		layers = {
			{ name = "석회암층", top = -4, bottom = -55, material = Enum.Material.Limestone, hardness = 3 },
			{ name = "젖은 암반층", top = -55, bottom = -125, material = Enum.Material.Rock, hardness = 4 },
		},
		-- 3스테이지 "지하수 동굴" 광물 6종 (공유 기획서, D-017). 가치·확률·경도 모두 임시값
		ores = {
			{ name = "Limestone", displayName = "석회석", grade = "일반", value = 15, weight = 50, minDepth = 0, hardness = 1,
				color = Color3.fromRGB(215, 210, 195), material = Enum.Material.Limestone, model = "Stage03/Limestone" },
			{ name = "Calcite", displayName = "방해석", grade = "일반", value = 22, weight = 30, minDepth = 0, hardness = 1,
				color = Color3.fromRGB(240, 235, 220), material = Enum.Material.Glass, model = "Stage03/Calcite" },
			{ name = "Azurite", displayName = "남동석", grade = "고급", value = 75, weight = 12, minDepth = 15, hardness = 2,
				color = Color3.fromRGB(40, 80, 200), material = Enum.Material.Glass, model = "Stage03/Azurite" },
			{ name = "Malachite", displayName = "공작석", grade = "희귀", value = 220, weight = 5, minDepth = 35, hardness = 2,
				color = Color3.fromRGB(30, 160, 90), material = Enum.Material.Marble, model = "Stage03/Malachite" },
			{ name = "WaterPearl", displayName = "물빛 진주", grade = "에픽", value = 700, weight = 2.5, minDepth = 60, hardness = 3,
				color = Color3.fromRGB(170, 220, 255), material = Enum.Material.Glass, model = "Stage03/WaterPearl" },
			{ name = "WetMap", displayName = "젖은 광산 지도", grade = "전설", value = 2400, weight = 0.2, minDepth = 80, hardness = 4,
				color = Color3.fromRGB(200, 180, 140), material = Enum.Material.Fabric, model = "Stage03/WetMap" },
		},
		digFinds = { grades = { "희귀", "에픽", "전설" }, chance = NumberRange.new(0.004, 0.012) }, -- 임시값
		oreRegrowDelay = 5, -- 임시값 (초)
		collapse = { interval = NumberRange.new(480, 720), warning = 60, offset = 360 }, -- 기본 광산과 6분 엇갈림, 임시값 (초)
		cave = {
			seed = 23,
			branches = 12,
			hubRooms = 4,
			roomSpacing = NumberRange.new(40, 60),
			subBranchChance = 0.45,
			tunnelRadius = 7,
			roomScale = 1.4,
		},
	},
} :: { Mine }

local byId: { [string]: Mine } = {}
for _, m in Mines.list do
	byId[m.id] = m
end

function Mines.get(id: string): Mine?
	return byId[id]
end

-- 플레이어가 어느 광산에 "들어가 있는지" (붕괴 탈출·갇힘 판정, 카운트다운 HUD용, D-013)
-- findAt 과 달리 지표 위도 포함한다. 출구 비탈 굴은 지표(top) 위까지 올라가서,
-- findAt 으로 재면 출구 게이트에 닿기 전에 이미 "광산 밖"이 돼 탈출 판정이 너무 일찍 나온다.
-- 광산 밖으로 나가는 길은 출구 게이트(→ 허브 순간이동)뿐이라, 광산 반경 안이면 전부 "광산 안"으로 본다.
local AREA_CEILING = 150 -- 광산 지표(origin.Y)보다 이만큼 위까지 (출구 언덕보다 충분히 높게)
function Mines.findAreaAt(pos: Vector3): Mine?
	for _, m in Mines.list do
		local flat = Vector3.new(pos.X - m.origin.X, 0, pos.Z - m.origin.Z)
		if flat.Magnitude <= m.radius and pos.Y <= m.origin.Y + AREA_CEILING and pos.Y >= m.bottom - 10 then
			return m
		end
	end
	return nil
end

-- 위치가 어느 광산 영역 안인지 (지표 아래만) — 채굴 가능 여부 판정용
function Mines.findAt(pos: Vector3): Mine?
	for _, m in Mines.list do
		local flat = Vector3.new(pos.X - m.origin.X, 0, pos.Z - m.origin.Z)
		if flat.Magnitude <= m.radius and pos.Y <= m.top and pos.Y >= m.bottom - 10 then
			return m
		end
	end
	return nil
end

function Mines.layerAt(m: Mine, y: number): (Layer, number)
	for i, layer in m.layers do
		if y > layer.bottom then
			return layer, i
		end
	end
	return m.layers[#m.layers], #m.layers
end

return table.freeze(Mines)
