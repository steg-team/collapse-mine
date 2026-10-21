--!strict
-- 광산 안 카메라 보정
-- 기본 카메라가 줌아웃할 때 굴 천장(지형)을 뚫고 바위 속으로 들어가면, 바위 안에서 굴 바닥만 보여
-- 맵이 허공에 떠 있는 것처럼 보인다. 광산 안에서는
--   1) 최대 줌 거리를 줄이고
--   2) 머리 → 카메라 사이가 막히면 카메라를 벽 앞으로 당긴다.

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Mines = require(RS:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Mines"))

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local MINE_MAX_ZOOM = 20   -- 굴 높이(약 10)와 방 크기를 보고 정한 임시값
local WALL_PADDING = 0.8   -- 벽에서 띄울 거리

local defaultMaxZoom = player.CameraMaxZoomDistance
local inMine = false

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true
rayParams.RespectCanCollide = true -- 램프처럼 통과되는 파트는 건너뛰고 뒤의 벽까지 본다

local function setInMine(value: boolean)
	if value == inMine then return end
	inMine = value
	player.CameraMaxZoomDistance = value and MINE_MAX_ZOOM or defaultMaxZoom
end

RunService:BindToRenderStep("MineCamera", Enum.RenderPriority.Camera.Value + 1, function()
	local char = player.Character
	-- 머리 대신 몸통 중심에서 레이를 쏜다. 좁은 틈에서는 머리가 천장 지형 속에 들어가는데,
	-- 레이 시작점이 지형 속이면 벽을 못 잡아 카메라가 바위 속으로 들어간다.
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then return end

	setInMine(Mines.findAt(root.Position) ~= nil)
	if not inMine then return end

	local from = root.Position
	local to = camera.CFrame.Position
	local offset = to - from
	if offset.Magnitude < 0.5 then return end -- 1인칭

	rayParams.FilterDescendantsInstances = { char }
	local hit = workspace:Raycast(from, offset, rayParams)
	if hit then
		local dir = offset.Unit
		local dist = math.max(0.5, hit.Distance - WALL_PADDING)
		camera.CFrame = camera.CFrame - offset + dir * dist
	end
end)
