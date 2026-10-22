--!strict
-- 서버 전체 공지 (C 담당)
-- 화면 위쪽 배너로 모든 플레이어(또는 한 명)에게 문구를 띄운다.
--
-- 누가 부르나
--   - C 내부 기능(붕괴 경보 등)은 이 모듈을 require 해서 Announcer.announce 를 직접 호출한다.
--   - A·B는 이 모듈을 직접 부르지 않는다. 이벤트(LegendaryFound 등)만 쏘면
--     AnnounceEvents.server.luau 가 받아서 공지로 바꾼다. (기능끼리는 이벤트로만, AGENTS.md)

local RS = game:GetService("ReplicatedStorage")

local Social = require(RS:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Social"))

-- 배너 색·아이콘은 kind 로 정한다 (Config/Social.luau 의 AnnounceKind)
export type Kind = Social.AnnounceKind
local CONFIG = Social.Announce

-- Remotes 는 Studio 에서 관리 (tools/create_social_remotes.luau 로 생성)
local announceRemote = RS:WaitForChild("Remotes"):WaitForChild("Announce") :: RemoteEvent

local lastSent: { [string]: number } = {}

local Announcer = {}

local function clean(text: string): string
	if utf8.len(text) and (utf8.len(text) :: number) > CONFIG.maxLength then
		-- 한글이 깨지지 않게 글자 단위로 자른다
		local cut = utf8.offset(text, CONFIG.maxLength + 1)
		if cut then text = string.sub(text, 1, cut - 1) .. "…" end
	end
	return text
end

local function isDuplicate(text: string): boolean
	local now = os.clock()
	local last = lastSent[text]
	lastSent[text] = now
	return last ~= nil and now - last < CONFIG.duplicateWindow
end

-- 서버 전체에 공지
function Announcer.announce(text: string, kind: Kind?)
	if typeof(text) ~= "string" or text == "" then return end
	text = clean(text)
	if isDuplicate(text) then return end
	announceRemote:FireAllClients(text, kind or Social.AnnounceKind.Info)
end

-- 한 사람에게만 공지 (예: "광산 입장에 곡괭이 3단계가 필요합니다")
function Announcer.announceTo(player: Player, text: string, kind: Kind?)
	if typeof(text) ~= "string" or text == "" then return end
	announceRemote:FireClient(player, clean(text), kind or Social.AnnounceKind.Info)
end

return table.freeze(Announcer)
