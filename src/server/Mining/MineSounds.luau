--!strict
-- 채굴 소리·발견 연출 (A, D-041). 서버가 그 자리에 소리를 내서 근처 사람 모두 듣는다.
-- 소리 id·크기는 Config/MiningSounds.luau. 화면 흔들림만 Remotes.MiningFx로 캔 사람에게 보낸다.

local RS = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local S = require(RS:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("MiningSounds"))

local MineSounds = {}
local rng = Random.new()

-- Remotes 폴더는 Studio에서 관리하지만, 없으면 만든다 (다른 담당 Remote와 같은 방식)
local remotes = RS:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = RS
end
local fxRemote = remotes:FindFirstChild("MiningFx") :: RemoteEvent?
if not fxRemote then
	local e = Instance.new("RemoteEvent")
	e.Name = "MiningFx"
	e.Parent = remotes
	fxRemote = e
end

-- 위치에 소리 하나 (지형에 붙인 Attachment에서 나서 거리에 따라 작아짐)
function MineSounds.playAt(s: S.Snd, pos: Vector3, maxDistance: number?)
	local a = Instance.new("Attachment")
	a.WorldPosition = pos
	a.Parent = workspace.Terrain
	local sound = Instance.new("Sound")
	sound.SoundId = s.id
	sound.Volume = s.volume
	if s.speed then sound.PlaybackSpeed = rng:NextNumber(s.speed.Min, s.speed.Max) end
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 8
	sound.RollOffMaxDistance = maxDistance or S.HEAR_DISTANCE
	sound.Parent = a
	sound:Play()
	Debris:AddItem(a, 8)
end

-- 땅 칠 때: 흙이면 둔탁, 아니면 바위
function MineSounds.terrainHit(pos: Vector3, material: Enum.Material)
	MineSounds.playAt(if S.DIRT_MATERIALS[material] then S.hitDirt else S.hitRock, pos)
end

function MineSounds.oreHit(pos: Vector3)
	MineSounds.playAt(S.hitOre, pos)
end

function MineSounds.oreBreak(pos: Vector3)
	MineSounds.playAt(S.oreBreak, pos)
	MineSounds.playAt(S.oreDing, pos)
end

-- 희귀 이상이 벽에 드러남
function MineSounds.rareRevealed(pos: Vector3)
	MineSounds.playAt(S.rareChime, pos)
end

-- 전설 이상을 캠: 팡파르 + 빛기둥(모두에게 보임) + 캔 사람 화면 흔들림
function MineSounds.legendary(player: Player, pos: Vector3, color: Color3?)
	local L = S.LEGENDARY_FX
	MineSounds.playAt(S.legendary, pos, L.hearDistance)

	local c = color or Color3.fromRGB(255, 190, 70)
	local pillar = Instance.new("Part")
	pillar.Name = "LegendaryPillar"
	pillar.Shape = Enum.PartType.Cylinder
	pillar.Size = Vector3.new(L.pillarHeight, L.pillarWidth, L.pillarWidth) -- 원통은 X축이 길이
	pillar.CFrame = CFrame.new(pos + Vector3.new(0, L.pillarHeight / 2 - 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	pillar.Anchored, pillar.CanCollide, pillar.CanTouch, pillar.CanQuery = true, false, false, false
	pillar.CastShadow = false
	pillar.Material = Enum.Material.Neon
	pillar.Color = c
	pillar.Transparency = 0.3
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = c, 30, 3
	light.Parent = pillar
	pillar.Parent = workspace
	-- 위로 퍼지며 사라짐
	TweenService:Create(pillar, TweenInfo.new(L.pillarTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Transparency = 1,
		Size = Vector3.new(L.pillarHeight, L.pillarWidth * 2.5, L.pillarWidth * 2.5),
	}):Play()
	Debris:AddItem(pillar, L.pillarTime + 0.2)

	if fxRemote then
		(fxRemote :: RemoteEvent):FireClient(player, "legendary")
	end
end

return MineSounds
