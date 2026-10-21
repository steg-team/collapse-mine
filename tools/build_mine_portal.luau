--[[
	허브에 광산 포탈(입구 아치)을 만드는 스크립트 (Studio 명령창에서 실행)

	MINE_ID 와 POSITION(허브 위 바닥 좌표)을 바꿔서 광산마다 한 번씩 실행한다.
	포탈 판정은 src/server/Mining/MineTravel.server.luau 가 태그 "MinePortal"로 처리한다.
]]

local MINE_ID = "basic"
local POSITION = Vector3.new(0, 0.5, 52)   -- 아치 바닥 중심
local FACING = 0                            -- 아치가 바라보는 방향(도)

local RS = game:GetService("ReplicatedStorage")
local CS = game:GetService("CollectionService")
local CHS = game:GetService("ChangeHistoryService")
local Mines = require(RS.Shared.Config.Mines)
local M = assert(Mines.get(MINE_ID), "Mines 설정에 없는 id")

local rec = CHS:TryBeginRecording("BuildPortal " .. MINE_ID)
local hub = workspace.CollapseMine.Hub
local portals = hub:FindFirstChild("MinePortals") or Instance.new("Folder")
portals.Name = "MinePortals"; portals.Parent = hub
local old = portals:FindFirstChild("Portal_" .. MINE_ID); if old then old:Destroy() end

local model = Instance.new("Model")
model.Name = "Portal_" .. MINE_ID
local base = CFrame.new(POSITION) * CFrame.Angles(0, math.rad(FACING), 0)

local function part(name, size, offset, color, mat)
	local p = Instance.new("Part")
	p.Name = name; p.Size = size; p.CFrame = base * CFrame.new(offset)
	p.Anchored = true; p.Color = color; p.Material = mat
	p.Parent = model
	return p
end
local wood = Color3.fromRGB(110, 75, 45)
part("PillarL", Vector3.new(2, 12, 2), Vector3.new(-6, 6, 0), wood, Enum.Material.WoodPlanks)
part("PillarR", Vector3.new(2, 12, 2), Vector3.new(6, 6, 0), wood, Enum.Material.WoodPlanks)
part("Beam", Vector3.new(15, 2, 2.4), Vector3.new(0, 13, 0), wood, Enum.Material.WoodPlanks)

local field = part("Field", Vector3.new(10, 11, 1), Vector3.new(0, 6, 0), Color3.fromRGB(255, 170, 70), Enum.Material.Neon)
field.Transparency = 0.45; field.CanCollide = false
field:SetAttribute("MineId", MINE_ID)
CS:AddTag(field, "MinePortal")

local bb = Instance.new("BillboardGui")
bb.Size = UDim2.fromOffset(220, 60); bb.StudsOffset = Vector3.new(0, 9, 0); bb.MaxDistance = 150
local tl = Instance.new("TextLabel")
tl.Size = UDim2.fromScale(1, 1); tl.BackgroundTransparency = 1; tl.TextScaled = true
tl.Font = Enum.Font.GothamBold; tl.TextColor3 = Color3.new(1, 1, 1); tl.TextStrokeTransparency = 0.3
tl.Text = M.name .. "\n곡괭이 " .. M.requiredPickaxe .. "단계"
tl.Parent = bb; bb.Parent = field

model.PrimaryPart = field
model.Parent = portals
if rec then CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
print("[Portal] " .. model:GetFullName() .. " 생성")
