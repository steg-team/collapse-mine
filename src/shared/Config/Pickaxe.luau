--!strict
--[[
	곡괭이 성능 (A, D-026) — 단계·강화가 채굴에 주는 효과
	제작·강화 비용과 이름은 B의 Config/Economy.luau PICKAXES. 단계 번호는 그 표와 같다
	(1 낡은 · 2 동굴 진주 · 3 백금 · 4 물빛 진주, D-044). 이름은 여기 따로 적지 않고 Pickaxe.name으로 읽는다 (이슈 #55).

	서버(MiningServer)와 클라이언트(PickaxeClient)가 같은 계산을 쓰도록 여기 모은다.
	클라이언트는 휘두르는 간격만 맞추고, 실제 판정(쿨다운·데미지)은 서버가 다시 계산한다 (보안 규칙).

	power    광석 데미지. 광석 Hardness = 파워 1로 깨는 데 필요한 타수
	cooldown 휘두르는 간격(초)
	digBonus 지형 파는 반경에 더하는 값(스터드)
	숫자는 모두 임시값.
]]

local Pickaxe = {}

Pickaxe.TIERS = table.freeze({
	{ power = 1, cooldown = 0.35, digBonus = 0 },
	{ power = 1.5, cooldown = 0.32, digBonus = 0.3 },
	{ power = 2.2, cooldown = 0.29, digBonus = 0.6 },
	{ power = 3.2, cooldown = 0.26, digBonus = 0.9 },
	-- 5단계 화염 루비 곡괭이 (T-006, B가 Economy.PICKAXES에 붙이면 쓰임). 임시값
	{ power = 4.6, cooldown = 0.23, digBonus = 1.2 },
})

-- 강화 1단계마다: 파워 +10%, 간격 -3% (최대 +5강, B의 ENHANCE_MAX)
Pickaxe.ENHANCE_POWER = 0.10
Pickaxe.ENHANCE_SPEED = 0.03

-- 서버 쿨다운 판정 여유: 네트워크 지연으로 클릭 간격이 조금 좁게 도착해도 막지 않게
Pickaxe.SERVER_TOLERANCE = 0.85

-- 단계 이름 (안내 문구용). 원본은 B의 Economy.PICKAXES, 아직 없는 단계는 "곡괭이 n단계"
local Economy = require(script.Parent:WaitForChild("Economy"))
function Pickaxe.name(tier: number): string
	local p = Economy.PICKAXES[tier]
	return if p then p.name else `곡괭이 {tier}단계`
end

export type Stats = { power: number, cooldown: number, digBonus: number }

-- 플레이어 속성으로 지금 성능 계산.
-- PickaxeTier·PickaxeEnhance는 B가, MineSpeedMultiplier(게임패스·부스트 배수)는 C가 서버에서 갱신한다
function Pickaxe.stats(player: Player): Stats
	local tier = math.clamp(math.floor(tonumber(player:GetAttribute("PickaxeTier")) or 1), 1, #Pickaxe.TIERS)
	local enhance = math.clamp(math.floor(tonumber(player:GetAttribute("PickaxeEnhance")) or 0), 0, 10)
	local speedMult = tonumber(player:GetAttribute("MineSpeedMultiplier")) or 1
	if speedMult <= 0 then speedMult = 1 end
	local t = Pickaxe.TIERS[tier]
	return {
		power = t.power * (1 + Pickaxe.ENHANCE_POWER * enhance),
		cooldown = t.cooldown * (1 - Pickaxe.ENHANCE_SPEED * enhance) / speedMult,
		digBonus = t.digBonus,
	}
end

return table.freeze(Pickaxe)
