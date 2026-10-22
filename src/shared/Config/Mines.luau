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
			{ name = "Lantern", displayName = "광부의 녹슨 등불", grade = "전설", value = 480, weight = 0.5, minDepth = 80, hardness = 4,
				color = Color3.fromRGB(150, 90, 50), material = Enum.Material.CorrodedMetal, model = "Stage01/Lantern" },
		},
		digFinds = { grades = { "희귀", "에픽", "전설" }, chance = NumberRange.new(0.008, 0.025) }, -- 임시값 (곡괭이 0.35초마다 → 깊은 곳에서 대략 15~40초에 하나)
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
} :: { Mine }

local byId: { [string]: Mine } = {}
for _, m in Mines.list do
	byId[m.id] = m
end

function Mines.get(id: string): Mine?
	return byId[id]
end

-- 위치가 어느 광산 영역 안인지 (지표 아래만)
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
