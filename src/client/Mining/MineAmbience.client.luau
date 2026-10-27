--!strict
-- 광산 배경음 + 붕괴 경보 진동음 (A, D-041) — 자기 화면에만
-- - 광산 안(Mines.findAreaAt)에 있으면 그 광산 배경음이 서서히 커지고, 나오면 작아진다.
-- - 그 광산이 붕괴 경보 중이면(C의 ReplicatedStorage.CollapseState 속성 = 붕괴 시각) 낮은 진동음.
--   붕괴가 가까울수록 커진다. 경보 길이는 Mines 설정 collapse.warning.
-- 소리 id·크기는 Config/MiningSounds.luau

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local Config = RS:WaitForChild("Shared"):WaitForChild("Config")
local Mines = require(Config:WaitForChild("Mines"))
local S = require(Config:WaitForChild("MiningSounds"))
local collapseState = RS:WaitForChild("CollapseState", 30)

local CHECK = 0.25 -- 위치 확인 간격(초)

local function loopSound(name: string, s: S.Snd): Sound
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = s.id
	sound.Looped = true
	sound.Volume = 0
	sound.Parent = SoundService
	return sound
end

-- 광산마다 배경음 하나씩 (처음엔 소리 0)
local ambience: { [string]: Sound } = {}
for id, s in S.ambience do
	ambience[id] = loopSound("MineAmbience_" .. id, s)
end
local rumble = loopSound("CollapseRumble", S.warningRumble)

local current: string? = nil -- 지금 배경음이 켜진 광산

local function fadeTo(sound: Sound, volume: number)
	if volume > 0 and not sound.IsPlaying then sound:Play() end
	local tw = TweenService:Create(sound, TweenInfo.new(S.AMBIENCE_FADE), { Volume = volume })
	tw:Play()
	if volume <= 0 then
		tw.Completed:Once(function()
			if sound.Volume <= 0.001 then sound:Stop() end
		end)
	end
end

while true do
	task.wait(CHECK)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local mine = root and Mines.findAreaAt(root.Position)
	local id = mine and mine.id

	-- 배경음: 들어간 광산 것만 켬
	if id ~= current then
		if current and ambience[current] then fadeTo(ambience[current], 0) end
		if id and ambience[id] then fadeTo(ambience[id], S.ambience[id].volume) end
		current = id
	end

	-- 경보 진동음: 지금 광산이 경보 중일 때만, 붕괴가 가까울수록 크게
	local collapseAt = mine and collapseState and collapseState:GetAttribute(mine.id)
	if mine and typeof(collapseAt) == "number" then
		local remaining = collapseAt - workspace:GetServerTimeNow()
		local warnLen = math.max(mine.collapse.warning, 1)
		local k = math.clamp(1 - remaining / warnLen, 0, 1)
		if not rumble.IsPlaying then rumble:Play() end
		rumble.Volume = S.WARNING_VOLUME.Min + (S.WARNING_VOLUME.Max - S.WARNING_VOLUME.Min) * k
		rumble.PlaybackSpeed = 0.9 + 0.15 * k -- 끝으로 갈수록 조금 급하게
	elseif rumble.IsPlaying then
		rumble:Stop()
	end
end
