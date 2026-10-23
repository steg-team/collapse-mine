--!strict
-- C 가 쓰는 Remote 를 가져온다. 없으면 서버가 만든다 (C 담당)
--
-- 원래 Remotes 는 Studio 에서 tools/create_social_remotes.luau 로 만들어 두는데,
-- 로컬 복사본에서 그걸 깜빡하면 WaitForChild 가 영원히 기다려서 Collapse → (Collapse 를 require 하는) PlayerData 로드까지
-- 같이 멈췄다 (#18). 그래서 없으면 경고만 하고 서버에서 바로 만든다. 서버가 만든 Remote 는 클라이언트에도 그대로 보인다.

local RS = game:GetService("ReplicatedStorage")

local function folder(): Instance
	local f = RS:FindFirstChild("Remotes")
	if not f then
		f = Instance.new("Folder")
		f.Name = "Remotes"
		f.Parent = RS
	end
	return f :: Instance
end

local SocialRemotes = {}

function SocialRemotes.get(name: string, className: "RemoteEvent" | "RemoteFunction"): Instance
	local f = folder()
	local remote = f:FindFirstChild(name)
	if not remote then
		warn(`[SocialRemotes] Remotes.{name} 이 없어서 서버에서 만듦 (Studio 에서 tools/create_social_remotes.luau 를 실행해 두면 이 경고가 안 뜸)`)
		remote = Instance.new(className)
		remote.Name = name
		remote.Parent = f
	end
	return remote :: Instance
end

return table.freeze(SocialRemotes)
