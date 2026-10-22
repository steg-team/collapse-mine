"""
허브 판매소(Shop) 외형 — 광물 거래소. 블렌더에서 실행하면 ~/Downloads/CollapseMine/Shop.fbx 로 내보낸다.

멀리서 눈에 띄는 포인트
- 지붕 용마루 위 큰 금화 장식
- 빨강·크림 줄무늬 차양 (끝이 물결처럼 늘어짐)
- 뒷선반·진열 상자의 빛나는 수정 (Roblox에서 Neon)
- 입구 옆 광석 가득한 광차, 매단 등불

Roblox 기능 부품 자리(비워 둠): 계산대 Counter = 블렌더 (0, -4.5, 2.8), 크기 16 x 2.6 x 3.6. 바닥 윗면 z=1.
"""
import bpy, math, random, sys, os
sys.path.append(os.path.dirname(bpy.data.filepath) if bpy.data.filepath else ".")
try:
    from rbx_common import *  # noqa
except ImportError:
    pass  # MCP로 실행할 때는 rbx_common 내용을 앞에 붙여서 보낸다

W, D = 24.0, 16.0
FLOOR = 1.0
EAVE = 12.4


def build():
    setup("Shop")
    rnd = random.Random(5)

    # 돌 기단 + 나무 바닥
    box("StoneDark", (W + 1.0, D + 1.0, 0.6), (0, 0, 0.3), bevel=0.1)
    x = -W / 2
    while x < W / 2 - 0.01:
        w = min(0.9, W / 2 - x)
        box("Wood" if rnd.random() < 0.6 else "WoodDark", (w - 0.05, D, 0.4), (x + w / 2, 0, 0.8), bevel=0.04)
        x += w
    # 앞 계단 2단
    for i, (wd, dy) in enumerate([(16, -D / 2 - 0.7), (18, -D / 2 - 1.5)]):
        box("Stone", (wd, 0.9, 0.6 - i * 0.3 + 0.0), (0, dy, 0.3 - i * 0.15), bevel=0.08)

    # 기둥 (각진 기둥 + 받침돌 + 위쪽 까치발)
    posts = [(-W / 2 + 0.5, -D / 2 + 0.5), (W / 2 - 0.5, -D / 2 + 0.5), (-W / 2 + 0.5, D / 2 - 0.5), (W / 2 - 0.5, D / 2 - 0.5)]
    for px, py in posts:
        box("Stone", (1.4, 1.4, 0.8), (px, py, FLOOR + 0.4), bevel=0.12)
        box("WoodDark", (1.0, 1.0, EAVE - FLOOR - 0.4), (px, py, FLOOR + 0.8 + (EAVE - FLOOR - 0.8) / 2), bevel=0.1)
    for sx in (-1, 1):
        beam("Wood", (sx * (W / 2 - 0.5), -D / 2 + 0.5, EAVE - 3.0), (sx * (W / 2 - 3.4), -D / 2 + 0.5, EAVE - 0.4), 0.5)
    box("WoodDark", (W + 1.0, 1.1, 1.1), (0, -D / 2 + 0.5, EAVE - 0.2), bevel=0.1)   # 앞 보
    box("WoodDark", (W + 1.0, 1.1, 1.1), (0, D / 2 - 0.5, EAVE - 0.2), bevel=0.1)
    for sx in (-1, 1):
        box("WoodDark", (1.1, D, 1.1), (sx * (W / 2 - 0.5), 0, EAVE - 0.2), bevel=0.1)

    # 뒷벽: 가로 판자 (높이마다 색 섞기)
    z = FLOOR
    while z < EAVE - 0.7:
        h = 0.9
        box("Wood" if rnd.random() < 0.55 else "WoodDark", (W - 1.2, 0.5, h - 0.06), (0, D / 2 - 0.5, z + h / 2), bevel=0.04)
        z += h
    # 옆벽: 아래 판자 + 창 + 위 판자
    for sx in (-1, 1):
        for z0, z1 in [(FLOOR, 5.2), (8.8, EAVE - 0.7)]:
            z = z0
            while z < z1 - 0.05:
                h = min(0.9, z1 - z)
                box("Wood" if rnd.random() < 0.55 else "WoodDark", (0.5, D - 1.2, h - 0.06), (sx * (W / 2 - 0.5), 0, z + h / 2), bevel=0.04)
                z += h
        box("WoodDark", (0.9, D - 1.0, 0.4), (sx * (W / 2 - 0.5), 0, 5.4), bevel=0.06)  # 창턱
        for k in range(3):
            box("WoodDark", (0.4, 0.4, 3.6), (sx * (W / 2 - 0.5), -4 + k * 4, 7.0))      # 창살

    # 지붕: 빨간 기와 (줄마다 엇갈림)
    pitch = math.radians(32)
    half = D / 2 + 1.6
    rise = math.tan(pitch) * half
    slope = half / math.cos(pitch)
    rw = W + 2.6
    for s in (-1, 1):
        box("WoodDark", (rw, slope + 0.3, 0.3), (0, s * half / 2, EAVE + 0.4 + rise / 2), rot=(-s * math.degrees(pitch), 0, 0))
    rows = 8
    for s in (-1, 1):
        for r in range(rows):
            t = (r + 0.5) / rows
            x = -rw / 2 + (0.0 if r % 2 == 0 else 0.7)
            while x < rw / 2 - 0.2:
                w = min(1.4, rw / 2 - x)
                if w > 0.4:
                    box("RoofRed" if rnd.random() < 0.85 else "Brick", (w - 0.08, slope / rows + 0.45, 0.3),
                        (x + w / 2, s * half * (1 - t), EAVE + 0.4 + rise * t + 0.3),
                        rot=(-s * math.degrees(pitch) + rnd.uniform(-2, 2), 0, rnd.uniform(-1.5, 1.5)), bevel=0.05)
                x += 1.4
    ridge_z = EAVE + 0.4 + rise + 0.5
    cyl("WoodDark", 0.5, rw + 0.6, (0, 0, ridge_z), rot=(0, 90, 0), verts=8)
    # 박공 삼각형 판
    for sx in (-1, 1):
        prism("Wood", [(-half + 1.2, 0), (half - 1.2, 0), (0, rise - 0.6)], 0.4, (sx * (W / 2 - 0.5), 0, EAVE + 0.5), rot=(0, 0, 90))

    # 용마루 위 큰 금화 (간판 역할) — 앞을 보게 세움
    cz = ridge_z + 3.4
    box("WoodDark", (0.6, 0.6, 2.4), (0, 0, ridge_z + 1.0))
    cyl("Gold", 2.6, 0.5, (0, 0, cz), rot=(90, 0, 0), verts=24, bevel=0.08)
    torus("Gold", 2.4, 0.22, (0, -0.3, cz), rot=(90, 0, 0), seg=24, mseg=5)
    torus("Gold", 2.4, 0.22, (0, 0.3, cz), rot=(90, 0, 0), seg=24, mseg=5)
    cyl("Copper", 1.4, 0.65, (0, 0, cz), rot=(90, 0, 0), verts=6)   # 가운데 육각 광석 문양
    for k in range(8):                                              # 테두리 톱니
        a = k * math.pi / 4
        box("Gold", (0.5, 0.5, 0.5), (math.cos(a) * 2.75, 0, cz + math.sin(a) * 2.75), rot=(0, -math.degrees(a), 0))

    # 줄무늬 차양 (앞 보 아래로 비스듬히, 끝은 물결 자락)
    n = 12
    aw = (W - 1.0) / n
    for i in range(n):
        x = -W / 2 + 0.5 + aw * (i + 0.5)
        m = "ClothRed" if i % 2 == 0 else "ClothCream"
        box(m, (aw - 0.02, 4.2, 0.12), (x, -D / 2 - 1.5, EAVE - 1.6), rot=(-24, 0, 0))
        prism(m, [(-aw / 2, 0), (aw / 2, 0), (aw / 2, -0.7), (0, -1.2), (-aw / 2, -0.7)], 0.12, (x, -D / 2 - 3.42, EAVE - 2.45))
    for sx in (-1, 1):
        beam("Iron", (sx * (W / 2 - 0.5), -D / 2 + 0.5, EAVE - 0.8), (sx * (W / 2 - 0.5), -D / 2 - 3.4, EAVE - 2.4), 0.15)

    # 뒷선반 3단 + 광석·수정 진열
    for k, sz in enumerate([3.6, 6.0, 8.4]):
        box("WoodDark", (W - 3.0, 1.4, 0.25), (0, D / 2 - 1.4, sz), bevel=0.04)
        for b in range(-4, 5, 2):
            box("Iron", (0.15, 1.0, 0.6), (b * 2.4, D / 2 - 1.2, sz - 0.4))
        for j in range(7):
            xx = -9 + j * 3 + rnd.uniform(-0.4, 0.4)
            pick = (j + k) % 4
            if pick == 0:
                crystal_cluster("Gem", (xx, D / 2 - 1.4, sz + 0.12), rnd, n=4, scale=0.45)
            elif pick == 1:
                crystal_cluster("Amethyst", (xx, D / 2 - 1.4, sz + 0.12), rnd, n=4, scale=0.45)
            else:
                box("Coal" if pick == 2 else "Copper", (0.9, 0.8, 0.7), (xx, D / 2 - 1.4, sz + 0.5),
                    rot=(rnd.uniform(0, 30), rnd.uniform(0, 30), rnd.uniform(0, 90)), bevel=0.15)

    # 계산대 위 금 저울 + 금화 탑 (계산대 자체는 Roblox 파트)
    cx, cy, top = -3.0, -4.5, FLOOR + 3.6 + 0.4
    cyl("Gold", 0.7, 0.25, (cx, cy, top + 0.12), verts=12)
    cyl("Gold", 0.12, 3.0, (cx, cy, top + 1.6), verts=8)
    box("Gold", (4.2, 0.2, 0.2), (cx, cy, top + 3.1), bevel=0.03)
    for dx in (-1.9, 1.9):
        for a in range(3):
            ang = a * 2 * math.pi / 3
            beam("Iron", (cx + dx, cy, top + 3.0), (cx + dx + math.cos(ang) * 0.6, cy + math.sin(ang) * 0.6, top + 1.25), 0.04, bevel=0)
        lathe("Gold", [(0.0, 0), (0.75, 0.05), (0.85, 0.3)], (cx + dx, cy, top + 1.1), seg=14)
    for i, (dx, n_) in enumerate([(2.6, 6), (3.6, 4), (3.1, 3)]):
        for j in range(n_):
            cyl("Gold", 0.5, 0.18, (cx + dx + 0.6 + rnd.uniform(-0.04, 0.04), cy + (i - 1) * 0.9, top + 0.1 + j * 0.2), verts=12)
    # 금화 자루
    lathe("ClothCream", [(0.0, 0), (0.9, 0.1), (1.1, 0.7), (0.8, 1.4), (0.35, 1.7), (0.5, 2.0), (0.0, 2.05)], (cx + 8.0, cy, top), seg=12)

    # 진열 상자 (계산대 앞 양옆) — 수정·석탄·구리
    for sx, kind in [(-1, "Gem"), (1, "Amethyst")]:
        bx, by = sx * 8.8, -D / 2 - 0.6
        box("Wood", (2.6, 2.0, 1.4), (bx, by, FLOOR + 0.2), bevel=0.08)
        box("WoodDark", (2.7, 2.1, 0.2), (bx, by, FLOOR + 0.75))
        crystal_cluster(kind, (bx, by, FLOOR + 0.9), rnd, n=6, scale=0.6)

    # 입구 왼쪽(블렌더 -X → Roblox +X) 광차
    kx, ky = -W / 2 - 3.2, -D / 2 + 2.5
    box("Wood", (3.0, 4.4, 2.0), (kx, ky, FLOOR - 0.4 + 1.6), taper=(1.12, 1.08), bevel=0.08)
    for zz in (FLOOR + 0.9, FLOOR + 2.3):
        box("Iron", (3.25, 4.65, 0.18), (kx, ky, zz))
    for sy in (-1.4, 1.4):
        for sx in (-1, 1):
            cyl("Iron", 0.7, 0.3, (kx + sx * 1.6, ky + sy, FLOOR - 0.2 + 0.7), rot=(0, 90, 0), verts=12)
    for j in range(9):
        box(["Coal", "Copper", "Iron"][j % 3], (1.0, 0.9, 0.8), (kx + rnd.uniform(-0.9, 0.9), ky + rnd.uniform(-1.5, 1.5), FLOOR + 2.7 + rnd.uniform(0, 0.4)),
            rot=(rnd.uniform(0, 40), rnd.uniform(0, 40), rnd.uniform(0, 90)), bevel=0.15)
    crystal_cluster("Gem", (kx, ky, FLOOR + 2.9), rnd, n=3, scale=0.5)

    # 술통·자루 (오른쪽 앞 = Roblox 왼쪽)
    for bx, by in [(W / 2 + 2.2, -D / 2 + 1.5), (W / 2 + 2.0, -D / 2 + 3.9)]:
        cyl("Wood", 1.0, 2.4, (bx, by, FLOOR - 0.4 + 1.2), r2=0.9, verts=12, bevel=0.05)
        for zz in (FLOOR - 0.4 + 0.6, FLOOR - 0.4 + 1.9):
            torus("Iron", 1.0, 0.07, (bx, by, zz))
    lathe("ClothCream", [(0.0, 0), (0.8, 0.1), (0.95, 0.6), (0.6, 1.3), (0.25, 1.5), (0.0, 1.55)], (W / 2 + 2.6, -D / 2 - 0.6, FLOOR - 0.4), seg=10)

    # 매단 등불 (앞 보 양끝)
    for sx in (-1, 1):
        lantern((sx * (W / 2 - 2.2), -D / 2 + 0.5, EAVE - 2.4))
        box("Iron", (0.08, 0.08, 1.2), (sx * (W / 2 - 2.2), -D / 2 + 0.5, EAVE - 1.3))


if __name__ == "__main__":
    build()
    join_and_export("SH", "Shop.fbx")
