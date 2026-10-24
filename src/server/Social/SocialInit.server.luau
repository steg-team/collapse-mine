--!strict
-- C(이벤트·서비스) 서버 모듈을 게임 시작 때 미리 불러온다.
-- Payments 는 처음 require 될 때부터 패스 보유 조회를 시작하므로,
-- A·B 가 처음 물어보기 전에 캐시가 채워져 있도록 여기서 먼저 깨운다.

local Social = script.Parent
require(Social:WaitForChild("Payments"))
-- 붕괴는 require 되는 순간부터 광산별 타이머가 돈다
require(Social:WaitForChild("Collapse"))
-- 출석 보상 (Remotes.DailyLogin 응답 연결)
require(Social:WaitForChild("DailyLogin"))
-- 허브 랭킹판 (점수 이벤트 연결 + 주기적으로 판 갱신)
require(Social:WaitForChild("Leaderboard"))
-- 튜토리얼 진행 (게임 이벤트로 단계 넘기기)
require(Social:WaitForChild("Tutorial"))
-- 일일 퀘스트 (게임 이벤트로 진행도 올리기)
require(Social:WaitForChild("DailyQuest"))
