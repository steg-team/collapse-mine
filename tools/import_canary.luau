--[[
	블렌더 카나리아 메시를 서버 템플릿으로 정리하는 스크립트 (Studio 명령창, Edit 모드에서 실행)

	순서
	1) 블렌더에서 tools/blender/build_canary.py 실행 → ~/Downloads/CollapseMine/Canary.fbx
	2) Studio 파일 → 가져오기(Ctrl+M)로 FBX를 가져옴. Workspace에 Canary 모델이 생김
	3) 이 스크립트 실행 → ServerStorage.CanaryBird. 서버(Economy/Canary.luau)가 캐릭터마다 복제해 어깨에 붙인다

	하는 일: 이름(Canary_L<레벨>_Paint 또는 _Lamp·_Gem)을 보고 색·재질을 입히고, 몸통(L1 Paint)을 PrimaryPart로, 피벗을 발 밑 가운데로.
	레벨 장비(L2 헬멧·램프, L3 목도리, L4 보석, L5 황금 깃)는 서버가 카나리아 레벨에 맞춰 보이고 숨긴다 (D-045).
	이전 템플릿은 ServerStorage.OldCanaryBird 로 백업한다.
]]

local CHS = game:GetService("ChangeHistoryService")
local SS = game:GetService("ServerStorage")

-- Paint = 블렌더에서 칠한 텍스처를 입은 메시 (FBX에 텍스처가 같이 들어 있어 가져오기가 TextureID를 채운다). 색은 흰색으로 둬야 텍스처 색 그대로
local LOOK = {
	Paint = { Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic },
	Lamp = { Color3.fromRGB(255, 240, 190), Enum.Material.Neon },
	Gem = { Color3.fromRGB(90, 220, 240), Enum.Material.Neon },
}

local src = workspace:FindFirstChild("Canary")
assert(src and src:IsA("Model"), "Workspace에 가져온 Canary 모델이 없어요 (Ctrl+M으로 Canary.fbx 가져오기)")

local rec = CHS:TryBeginRecording("ImportCanary")
local body
for _, p in src:GetDescendants() do
	if p:IsA("MeshPart") then
		local look = LOOK[p.Name:match("^Canary_L%d+_(.+)$") or ""]
		if look then
			p.Color, p.Material = look[1], look[2]
		end
		p.Anchored = true
		if p.Name == "Canary_L1_Paint" then
			body = p
		end
	end
end
assert(body, "Canary_L1_Paint 메시가 없어요")
src.PrimaryPart = body
local cf, size = src:GetBoundingBox()
src.WorldPivot = CFrame.new(cf.Position - Vector3.new(0, size.Y / 2, 0)) -- 발 밑 가운데, 앞 = -Z

local old = SS:FindFirstChild("CanaryBird")
if old then
	local prev = SS:FindFirstChild("OldCanaryBird")
	if prev then
		prev:Destroy()
	end
	old.Name = "OldCanaryBird"
end
src.Name = "CanaryBird"
src.Parent = SS
if rec then
	CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit)
end
print("[ImportCanary] ServerStorage.CanaryBird 준비됨. 크기", size)
