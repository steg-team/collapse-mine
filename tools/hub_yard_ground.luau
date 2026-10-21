--[[
	허브 마당 바닥에서 풀(잡초)을 없애는 스크립트 (Studio 명령창에서 실행)

	허브 바닥은 Terrain 풀(Grass)이라 풀잎 장식이 무릎까지 자라 건물 앞이 지저분해 보였다.
	분지 바닥 높이(-12~8)만 풀 → 흙(Ground)으로, 건물 앞 광장은 흙 → 돌바닥(Cobblestone)으로 바꾼다.
	절벽 위 풀은 높이가 달라 그대로 남는다. tools/build_hub_cliffs.luau 다음에 실행.
]]

local CHS = game:GetService("ChangeHistoryService")
local T = workspace.Terrain

local rec = CHS:TryBeginRecording("HubYardNoGrass")
local yard = Region3.new(Vector3.new(-92, -12, 36), Vector3.new(92, 8, 146)):ExpandToGrid(4)
T:ReplaceMaterial(yard, 4, Enum.Material.Grass, Enum.Material.Ground)
local plaza = Region3.new(Vector3.new(-56, -12, 60), Vector3.new(56, 8, 112)):ExpandToGrid(4)
T:ReplaceMaterial(plaza, 4, Enum.Material.Ground, Enum.Material.Cobblestone)
if rec then CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
print("[HubYard] 마당 풀 제거 완료")
