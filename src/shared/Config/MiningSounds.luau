--!strict
--[[
	채굴 소리·발견 연출 (A, D-041) — 소리 id와 크기를 여기 한 곳에 모은다.
	모두 Creator Store 무료 공식 라이선스 효과음 (ProSoundEffects·APM). 바꾸려면 id만 바꾸면 된다.
	숫자(볼륨·거리·길이)는 모두 임시값.

	누가 쓰나
	- 서버 MineSounds: 치기·깨짐·희귀 등장·전설 (그 자리에서 나서 근처 사람 모두 들림)
	- 클라이언트 MineAmbience: 광산 배경음, 붕괴 경보 진동음 (자기 화면에만)
	- 클라이언트 MiningFx: 전설 발견 화면 흔들림
]]

export type Snd = { id: string, volume: number, speed: NumberRange? }

local function snd(id: number, volume: number, speed: NumberRange?): Snd
	return table.freeze({ id = "rbxassetid://" .. id, volume = volume, speed = speed })
end

local MiningSounds = {}

-- 곡괭이로 칠 때. 흙(DIRT_MATERIALS)은 둔탁하게, 나머지 바위는 맑게
MiningSounds.hitDirt = snd(9114083746, 0.7, NumberRange.new(0.9, 1.15)) -- Dirt Dig Dirt Throws From Shovel 12
MiningSounds.hitRock = snd(9118608146, 0.8, NumberRange.new(0.95, 1.2)) -- Rock Hits Rock On Rock 8
MiningSounds.hitOre = snd(9118608146, 0.9, NumberRange.new(1.2, 1.4)) -- 같은 돌 타격음을 높게 = 광석은 더 "깡"
MiningSounds.DIRT_MATERIALS = table.freeze({
	[Enum.Material.Ground] = true,
	[Enum.Material.Grass] = true,
	[Enum.Material.Mud] = true,
	[Enum.Material.Sand] = true,
	[Enum.Material.LeafyGrass] = true,
})

-- 광석이 깨질 때: 돌 부서짐 + 짧은 "띵"
MiningSounds.oreBreak = snd(9118588165, 0.9, NumberRange.new(0.95, 1.1)) -- Rock Drop On Concrete Drops Breaks 10
MiningSounds.oreDing = snd(3199238931, 0.6, NumberRange.new(1, 1.1)) -- Pick_up_gem

-- 희귀 이상 광물이 벽에 드러날 때 (파다가 발견)
MiningSounds.rareChime = snd(4612374393, 1) -- bling_diamond_pickup_2

-- 전설 이상을 캤을 때: 팡파르 + 빛기둥 + 캔 사람 화면 흔들림 (기획서 "발견 연출")
MiningSounds.legendary = snd(1848016523, 1) -- Global Success StingA (APM)
MiningSounds.LEGENDARY_FX = table.freeze({
	pillarHeight = 80, -- 빛기둥 높이(스터드)
	pillarWidth = 4,
	pillarTime = 4, -- 빛기둥이 떠 있는 시간(초)
	hearDistance = 300, -- 팡파르가 들리는 거리
	shake = 0.6, -- 캔 사람 화면 흔들림 세기
	shakeTime = 0.8,
})

-- 위치 소리가 들리는 거리 (치기·깨짐·차임)
MiningSounds.HEAR_DISTANCE = 80

-- 붕괴 경보 중 광산 안: 낮은 진동음. 붕괴가 가까울수록 커진다 (minVolume → maxVolume)
MiningSounds.warningRumble = snd(9114223352, 0.25) -- Earthquake Deep Subterranean Booms 3
MiningSounds.WARNING_VOLUME = NumberRange.new(0.25, 1.4)

-- 광산 안 배경음 (광산 id별, 반복). 광산에 들어가면 서서히 커지고 나오면 작아진다
MiningSounds.ambience = table.freeze({
	basic = snd(9120505513, 0.45), -- Water Cave Trickle Very Thin 3 (동굴 물방울)
	iron = snd(9118747853, 0.35), -- Rumble Ambience Interior Wind (갱도 바람)
	groundwater = snd(9120505297, 0.55), -- Water Cave Trickle Thin Into Small Puddles 5 (물 흐르는 동굴)
	lava = snd(9114223352, 0.3), -- Earthquake Deep Subterranean Booms 3 (땅속 울림, 용암 광산 전용 소리를 찾으면 교체). 임시값
} :: { [string]: Snd })
MiningSounds.AMBIENCE_FADE = 1.5 -- 배경음이 켜지고 꺼지는 시간(초)

return table.freeze(MiningSounds)
