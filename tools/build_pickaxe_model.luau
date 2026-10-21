--[[
	곡괭이 모델(Tool "Pickaxe")을 StarterPack에 만드는 스크립트
	(Studio 명령창에서 실행, Rojo 동기화 대상 아님)

	모델만 만든다. 클릭 처리는 src/client/Mining/PickaxeClient.client.luau,
	채굴 판정은 src/server/Mining/MiningServer.server.luau 가 담당.
	통신용 ReplicatedStorage.Remotes.MineHit 도 없으면 같이 만든다.
]]

local CHS = game:GetService("ChangeHistoryService")
local rec = CHS:TryBeginRecording("BuildPickaxe")
local RS = game:GetService("ReplicatedStorage")

local remotes = RS:FindFirstChild("Remotes") or Instance.new("Folder")
remotes.Name = "Remotes"; remotes.Parent = RS
local ev = remotes:FindFirstChild("MineHit") or Instance.new("RemoteEvent")
ev.Name = "MineHit"; ev.Parent = remotes

local old = game.StarterPack:FindFirstChild("Pickaxe")
if old then old:Destroy() end

local tool = Instance.new("Tool")
tool.Name = "Pickaxe"
tool.ToolTip = "클릭해서 땅과 광석을 캐기"
tool.CanBeDropped = false

local handle = Instance.new("Part")
handle.Name = "Handle"
handle.Size = Vector3.new(0.35, 4, 0.35)
handle.Material = Enum.Material.Wood
handle.Color = Color3.fromRGB(120, 80, 45)
handle.CanCollide = false
handle.Parent = tool

local head = Instance.new("Part")
head.Name = "Head"
head.Size = Vector3.new(3.4, 0.45, 0.45)
head.Material = Enum.Material.Metal
head.Color = Color3.fromRGB(150, 155, 165)
head.CanCollide = false
head.Massless = true
head.CFrame = handle.CFrame * CFrame.new(0, 1.85, 0)
head.Parent = tool
local wh = Instance.new("WeldConstraint"); wh.Part0 = handle; wh.Part1 = head; wh.Parent = head

for _, side in ipairs({-1, 1}) do
	local tip = Instance.new("WedgePart")
	tip.Name = "Tip"
	tip.Size = Vector3.new(0.45, 0.45, 0.9)
	tip.Material = Enum.Material.Metal
	tip.Color = head.Color
	tip.CanCollide = false
	tip.Massless = true
	tip.CFrame = head.CFrame * CFrame.new(side * 2.15, 0, 0) * CFrame.Angles(0, side * math.pi / 2, 0)
	tip.Parent = tool
	local w = Instance.new("WeldConstraint"); w.Part0 = handle; w.Part1 = tip; w.Parent = tip
end

tool.Grip = CFrame.new(0, -1.3, 0)
tool.Parent = game.StarterPack

if rec then CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
print("[Pickaxe] StarterPack.Pickaxe 생성 완료")
