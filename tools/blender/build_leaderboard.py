"""
허브 랭킹판(Leaderboard) 외형 — 명예의 전당. 블렌더에서 실행하면 ~/Downloads/CollapseMine/Leaderboard.fbx

멀리서 눈에 띄는 포인트
- 3단 돌 계단 위 신전 같은 틀: 돌기둥 2개, 들보, 삼각 박공
- 박공 꼭대기의 큰 금 트로피
- 기둥 바깥 빨강·파랑 깃발, 앞 모서리의 빛나는 수정, 화로 2개

Roblox 기능 부품 자리 (비워 둠, Roblox 로컬 → 블렌더 (-x, z, y))
- 랭킹 패널 3개: 블렌더 x = -8.2, 0, 8.2 / 폭 7.4 / z 2.8~13.8 / 앞면 y = 1.7
- 간판 "랭킹": 블렌더 z 13.9~17.5, y 0.95~1.7, 폭 11
- 화로 불: 블렌더 (±14.6, -2, 9.7)
"""
import bpy, math, random, sys, os
try:
    from rbx_common import *  # noqa
except ImportError:
    pass

PANEL_X = (-8.2, 0.0, 8.2)
PANEL_W, PANEL_Z0, PANEL_Z1 = 7.4, 2.8, 13.8


def build():
    setup("Leaderboard")
    rnd = random.Random(3)

    # 3단 계단식 단
    for i, (w, d, z0, z1, m) in enumerate([(34, 13, 0.0, 0.6, "StoneDark"), (30, 10.5, 0.6, 1.1, "Stone"), (28, 8, 1.1, 1.6, "StoneLight")]):
        box(m, (w, d, z1 - z0), (0, 1.2 + i * 0.6, (z0 + z1) / 2), bevel=0.12)
    box("Gold", (28.2, 0.18, 0.18), (0, 1.2 + 1.2 - 4.0 - 0.02, 1.52))   # 맨 윗단 앞 금테

    # 뒷벽 (돌 블록 엇갈림)
    z, row = 1.6, 0
    while z < 15.9:
        h = 1.1
        x = -13.0 - (0.7 if row % 2 else 0)
        while x < 13.0 - 0.01:
            ln = rnd.uniform(1.8, 2.8)
            a, b = max(x, -13.0), min(x + ln, 13.0)
            if b - a > 0.3:
                box("Stone" if rnd.random() < 0.7 else "StoneLight", (b - a - 0.08, 1.2 + rnd.uniform(-0.05, 0.08), h - 0.08), ((a + b) / 2, 3.2, z + h / 2), bevel=0.12)
            x += ln
        z += h; row += 1

    # 패널 액자 (패널 앞면보다 0.2 앞으로 튀어나온 나무 틀 + 금 모서리)
    for px in PANEL_X:
        ox, oz0, oz1 = PANEL_W / 2 + 0.55, PANEL_Z0 - 0.55, PANEL_Z1 + 0.55
        for zc, hh in [(oz0 + 0.3, 0.6), (oz1 - 0.3, 0.6)]:
            box("WoodDark", (2 * ox, 1.1, hh), (px, 2.05, zc), bevel=0.08)
        for sx in (-1, 1):
            box("WoodDark", (0.55, 1.1, oz1 - oz0), (px + sx * (ox - 0.275), 2.05, (oz0 + oz1) / 2), bevel=0.08)
        for sx in (-1, 1):
            for zc in (oz0 + 0.3, oz1 - 0.3):
                box("Gold", (0.75, 0.3, 0.75), (px + sx * (ox - 0.275), 1.45, zc), rot=(0, 45, 0), bevel=0.05)
        # 액자 위 금 장식 (작은 별)
        prism("Gold", [(math.cos(math.radians(90 + k * 36)) * (0.75 if k % 2 == 0 else 0.32),
                         math.sin(math.radians(90 + k * 36)) * (0.75 if k % 2 == 0 else 0.32)) for k in range(10)],
              0.25, (px, 1.45, oz1 + 0.75))

    # 돌기둥 2개 (받침, 기둥, 금 띠, 머리)
    for sx in (-1, 1):
        cx = sx * 14.6
        box("StoneLight", (2.8, 2.8, 1.0), (cx, 3.0, 2.1), bevel=0.15)
        cyl("StoneLight", 1.0, 13.0, (cx, 3.0, 2.6 + 6.5), verts=14, r2=0.9, bevel=0.05)
        for zz in (3.2, 15.0):
            torus("Gold", 1.0, 0.12, (cx, 3.0, zz), seg=18)
        box("StoneLight", (2.9, 2.9, 0.9), (cx, 3.0, 15.95), taper=(1.15, 1.15), bevel=0.12)

    # 들보 + 삼각 박공
    box("StoneLight", (36.0, 2.6, 1.4), (0, 3.1, 17.1), bevel=0.15)
    box("Gold", (36.2, 0.15, 0.2), (0, 1.78, 16.55))
    box("Stone", (34.0, 2.4, 0.5), (0, 3.1, 18.05), bevel=0.08)
    prism("StoneLight", [(-16.5, 0), (16.5, 0), (0, 5.2)], 2.2, (0, 3.1, 18.3))
    prism("Stone", [(-14.0, 0.5), (14.0, 0.5), (0, 4.6)], 0.4, (0, 1.95, 18.3))
    cyl("Gold", 1.3, 0.3, (0, 1.7, 20.3), rot=(90, 0, 0), verts=16)       # 박공 가운데 금 원판
    cyl("Amethyst", 0.7, 0.45, (0, 1.6, 20.3), rot=(90, 0, 0), verts=6)

    # 꼭대기 트로피
    tz = 23.4
    box("StoneDark", (3.4, 3.4, 1.0), (0, 3.1, tz - 0.5), bevel=0.12)
    box("Gold", (3.6, 3.6, 0.2), (0, 3.1, tz - 0.05))
    lathe("Gold", [(0.0, 0), (1.5, 0), (1.5, 0.35), (0.6, 0.6), (0.35, 1.7), (0.6, 2.1), (1.7, 2.7), (2.2, 3.8), (2.3, 4.7), (2.1, 4.8), (0.0, 4.8)],
          (0, 3.1, tz), seg=20)
    for sx in (-1, 1):
        torus("Gold", 0.95, 0.2, (sx * 2.45, 3.1, tz + 3.6), rot=(90, 0, 0), seg=16)
    crystal_cluster("Gem", (0, 3.1, tz + 4.7), rnd, n=6, scale=1.1)

    # 깃발 (기둥 바깥, 끝은 V자)
    for sx, color in [(-1, "ClothRed"), (1, "ClothBlue")]:
        bx = sx * 16.9
        cyl("Gold", 0.12, 2.8, (bx, 1.6, 16.2), rot=(0, 90, 0), verts=8)
        prism(color, [(-1.2, 0), (1.2, 0), (1.2, -8.2), (0, -7.0), (-1.2, -8.2)], 0.12, (bx, 1.7, 16.1))
        prism("Gold", [(-1.25, 0), (1.25, 0), (1.25, -0.3), (-1.25, -0.3)], 0.16, (bx, 1.62, 15.4))
        prism("Gold", [(0, 0.55), (0.45, 0), (0, -0.55), (-0.45, 0)], 0.16, (bx, 1.62, 11.5))

    # 화로 2개 (Roblox 불 자리: (±14.6, -2, 9.7))
    for sx in (-1, 1):
        fx = sx * 14.6
        box("Stone", (1.8, 1.8, 0.8), (fx, -2.0, 1.0), bevel=0.12)
        box("StoneLight", (1.2, 1.2, 7.2), (fx, -2.0, 1.4 + 3.6), taper=(0.85, 0.85), bevel=0.1)
        lathe("Iron", [(0.0, 0), (0.5, 0), (1.3, 0.8), (1.5, 1.1), (1.3, 1.15), (0.0, 1.15)], (fx, -2.0, 8.6), seg=14)
        box("Ember", (1.8, 1.8, 0.25), (fx, -2.0, 9.55), rot=(0, 0, 45))
        for k in range(4):
            a = k * math.pi / 2 + math.pi / 4
            box("Iron", (0.15, 0.15, 0.9), (fx + math.cos(a) * 1.35, -2.0 + math.sin(a) * 1.35, 9.95))

    # 앞 모서리 빛나는 수정
    crystal_cluster("Gem", (-11.5, -4.3, 0.6), rnd, n=8, scale=1.7)
    crystal_cluster("Amethyst", (11.5, -4.3, 0.6), rnd, n=8, scale=1.7)


if __name__ == "__main__":
    build()
    join_and_export("LB", "Leaderboard.fbx")
