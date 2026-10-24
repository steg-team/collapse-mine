--[[
	C(이벤트·서비스)가 쓰는 RemoteEvent를 ReplicatedStorage.Remotes에 만드는 스크립트
	(Studio 명령창에서 실행, Rojo 동기화 대상 아님. 이미 있으면 그대로 둔다)
	안 만들어 두면 서버가 실행 중에 만들긴 한다 (SocialRemotes.luau). 다만 경고가 뜨니 플레이스에 저장해 두는 게 좋다.

	- Announce : 서버 → 클라이언트. 화면 위쪽 서버 공지 배너 (text, kind)
	  보내는 쪽 src/server/Social/Announcer.luau, 받는 쪽 src/client/Social/AnnounceBanner.client.luau
	- DailyLogin (RemoteFunction) : 클라이언트 → 서버. 출석판 상태 조회("get") / 보상 받기("claim")
	  서버 src/server/Social/DailyLogin.luau, 클라이언트 src/client/Social/DailyLoginPanel.client.luau
]]

local CHS = game:GetService("ChangeHistoryService")
local rec = CHS:TryBeginRecording("CreateSocialRemotes")
local RS = game:GetService("ReplicatedStorage")

local remotes = RS:FindFirstChild("Remotes") or Instance.new("Folder")
remotes.Name = "Remotes"; remotes.Parent = RS

-- 이름 → 종류
local LIST = {
	Announce = "RemoteEvent",
	DailyLogin = "RemoteFunction",
	Tutorial = "RemoteEvent", -- 서버 ↔ 클라이언트. 튜토리얼 단계 (src/server/Social/Tutorial.luau)
}

for name, className in LIST do
	if not remotes:FindFirstChild(name) then
		local ev = Instance.new(className)
		ev.Name = name; ev.Parent = remotes
		print("Remotes." .. name .. " (" .. className .. ") 생성")
	end
end

if rec then CHS:FinishRecording(rec, Enum.FinishRecordingOperation.Commit) end
print("완료. Ctrl+S로 플레이스를 저장하세요.")
