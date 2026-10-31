"""
허브 창고(Storage) 외형 — 광부들이 재료를 맡겨 두는 광물 창고. 블렌더에서 실행하면 ~/Downloads/CollapseMine/Storage.fbx 로 내보낸다.

멀리서 눈에 띄는 포인트
- 큰 미닫이 쌍문 (X자 보강목, 쇠 레일)
- 함석 박공지붕 + 지붕 위 환기탑과 광석 깃발
- 입구 옆에 쌓인 상자·통·광석 자루, 맡긴 광물이 담긴 광차
- 앞 처마 아래 매단 등불 두 개

Roblox 기능 부품 자리(비워 둠): 맡기는 창구 Counter = 블렌더 (5.5, -7.6, 2.3), 크기 5 x 2 x 2.6. 바닥 윗면 z=1.
1 블렌더 단위 = 1 스터드, 바닥 가운데가 원점, 앞면 -Y (rbx_common 규칙).
"""
import bpy, math, random, sys, os
sys.path.append(os.path.dirname(bpy.data.filepath) if bpy.data.filepath else ".")
try:
    from rbx_common import *  # noqa
except ImportError:
    pass  # MCP로 실행할 때는 rbx_common 내용을 앞에 붙여서 보낸다

PALETTE.update({"Steel": (0.67, 0.69, 0.73)})  # 함석 지붕 밝은 줄 (import_hub_mesh LOOK의 Steel과 같은 이름)

W, D = 20.0, 14.0
FLOOR = 1.0
EAVE = 10.0


def build():
    setup("Storage")
    rnd = random.Random(11)

    # 돌 기단 + 앞 경사로
    box("StoneDark", (W + 1.2, D + 1.2, 1.0), (0, 0, 0.5), bevel=0.12)
    box("StoneLight", (W + 0.8, 0.9, 0.18), (0, -D / 2 + 0.6, 1.0), bevel=0.04)               # 앞 문턱돌
    box("Stone", (9.0, 3.0, 0.6), (-3.0, -D / 2 - 1.4, 0.3), rot=(-8, 0, 0), bevel=0.08)       # 수레 경사로

    # 모서리 돌기둥 (아래 1/3 돌, 위는 나무)
    for px in (-W / 2 + 0.6, W / 2 - 0.6):
        for py in (-D / 2 + 0.6, D / 2 - 0.6):
            box("StoneLight", (1.6, 1.6, 3.2), (px, py, FLOOR + 1.6), bevel=0.15)
            box("WoodDark", (1.1, 1.1, EAVE - FLOOR - 3.0), (px, py, FLOOR + 3.2 + (EAVE - FLOOR - 3.2) / 2), bevel=0.1)

    # 벽: 세로 판자 (색 섞기), 앞벽은 문 자리 비움
    def plank_wall(x0, x1, y, z0, z1, along_x=True):
        x = x0
        while x < x1 - 0.05:
            w = min(0.8, x1 - x)
            m = "Wood" if rnd.random() < 0.6 else "WoodDark"
            if along_x:
                box(m, (w - 0.05, 0.4, z1 - z0), (x + w / 2, y, (z0 + z1) / 2), bevel=0.03)
            else:
                box(m, (0.4, w - 0.05, z1 - z0), (y, x + w / 2, (z0 + z1) / 2), bevel=0.03)
            x += w

    plank_wall(-W / 2 + 1.4, W / 2 - 1.4, D / 2 - 0.5, FLOOR, EAVE)            # 뒷벽
    for sx in (-1, 1):
        plank_wall(-D / 2 + 1.4, D / 2 - 1.4, sx * (W / 2 - 0.5), FLOOR, EAVE, along_x=False)   # 옆벽
        box("WoodDark", (0.6, 5.0, 0.35), (sx * (W / 2 - 0.3), 0, 6.2), bevel=0.04)             # 옆 창틀
        box("Glass", (0.3, 4.2, 1.6), (sx * (W / 2 - 0.35), 0, 7.2))                             # 높은 창
    DOOR_W, DOOR_H = 9.0, 7.0
    DX = -3.0  # 문은 왼쪽으로 치우치고 오른쪽에 맡기는 창구
    plank_wall(-W / 2 + 1.4, DX - DOOR_W / 2, -D / 2 + 0.5, FLOOR, EAVE)
    plank_wall(DX + DOOR_W / 2, W / 2 - 1.4, -D / 2 + 0.5, FLOOR, EAVE)
    plank_wall(DX - DOOR_W / 2, DX + DOOR_W / 2, -D / 2 + 0.5, FLOOR + DOOR_H, EAVE)   # 문 위

    # 미닫이 쌍문 (조금 열린 상태) + X 보강목 + 쇠 레일
    for i, ox in enumerate((-DOOR_W / 4 - 0.6, DOOR_W / 4 + 0.6)):
        cx = DX + ox
        box("WoodDark", (DOOR_W / 2 - 0.1, 0.35, DOOR_H - 0.1), (cx, -D / 2 - 0.05, FLOOR + DOOR_H / 2), bevel=0.05)
        for z in (FLOOR + 0.4, FLOOR + DOOR_H / 2, FLOOR + DOOR_H - 0.4):
            box("Wood", (DOOR_W / 2 - 0.2, 0.2, 0.45), (cx, -D / 2 - 0.28, z))
        beam("Wood", (cx - DOOR_W / 4 + 0.3, -D / 2 - 0.3, FLOOR + 0.6), (cx + DOOR_W / 4 - 0.3, -D / 2 - 0.3, FLOOR + DOOR_H - 0.6), 0.35, bevel=0.03)
        beam("Wood", (cx + DOOR_W / 4 - 0.3, -D / 2 - 0.3, FLOOR + 0.6), (cx - DOOR_W / 4 + 0.3, -D / 2 - 0.3, FLOOR + DOOR_H - 0.6), 0.35, bevel=0.03)
        box("Iron", (0.25, 0.25, 0.9), (cx + (0.9 if i == 0 else -0.9), -D / 2 - 0.4, FLOOR + 3.4))   # 손잡이
    box("Iron", (DOOR_W + 4.0, 0.3, 0.3), (DX, -D / 2 - 0.3, FLOOR + DOOR_H + 0.2))                     # 레일
    for k in range(5):
        cyl("Iron", 0.18, 0.2, (DX - DOOR_W / 2 - 1.5 + k * (DOOR_W + 3) / 4, -D / 2 - 0.45, FLOOR + DOOR_H + 0.2), rot=(90, 0, 0), verts=8)
    box("Coal", (DOOR_W - 0.2, 0.2, DOOR_H - 0.2), (DX, -D / 2 + 0.6, FLOOR + DOOR_H / 2))   # 문틈 안쪽 어둠

    # 맡기는 창구: 벽에 뚫린 창 + 선반 (Counter 파트는 Roblox에서)
    CX = 5.5
    box("Coal", (4.6, 0.3, 2.4), (CX, -D / 2 + 0.55, 5.0))
    box("WoodDark", (5.4, 0.5, 0.4), (CX, -D / 2 + 0.3, 6.4), bevel=0.05)
    box("WoodDark", (5.4, 1.2, 0.35), (CX, -D / 2 - 0.2, 3.7), bevel=0.05)
    for sx in (-1, 1):
        box("WoodDark", (0.4, 0.5, 2.8), (CX + sx * 2.5, -D / 2 + 0.3, 5.0), bevel=0.04)
    # 창구 위 작은 차양
    box("Iron", (6.0, 1.8, 0.15), (CX, -D / 2 - 0.8, 7.2), rot=(-18, 0, 0))

    # 지붕: 함석 골판 (줄마다 밝기 섞기)
    pitch = math.radians(28)
    half = D / 2 + 1.4
    rise = math.tan(pitch) * half
    slope = half / math.cos(pitch)
    rw = W + 2.4
    for s in (-1, 1):
        box("WoodDark", (rw, slope + 0.3, 0.3), (0, s * half / 2, EAVE + 0.3 + rise / 2), rot=(-s * math.degrees(pitch), 0, 0))
        n = 18
        for i in range(n):
            x = -rw / 2 + (i + 0.5) * rw / n
            box("Iron" if i % 3 else "Steel", (rw / n - 0.06, slope + 0.2, 0.18), (x, s * half / 2, EAVE + 0.55 + rise / 2),
                rot=(-s * math.degrees(pitch), 0, 0))
    ridge_z = EAVE + 0.4 + rise + 0.3
    box("Steel", (rw + 0.4, 0.9, 0.5), (0, 0, ridge_z), bevel=0.05)
    for sx in (-1, 1):
        prism("Wood", [(-half + 1.0, 0), (half - 1.0, 0), (0, rise - 0.4)], 0.4, (sx * (W / 2 - 0.5), 0, EAVE + 0.4), rot=(0, 0, 90))
    # 박공 앞쪽 둥근 환기창
    torus("WoodDark", 1.0, 0.18, (0, -D / 2 - 0.4, EAVE + 2.4), rot=(90, 0, 0), seg=16, mseg=4)

    # 지붕 위 환기탑 + 광석 깃발
    box("Wood", (2.4, 2.4, 2.0), (4.0, 0, ridge_z + 1.2), bevel=0.08)
    box("Iron", (3.0, 3.0, 0.3), (4.0, 0, ridge_z + 2.4), taper=(0.5, 0.5))
    box("Iron", (0.2, 0.2, 4.5), (-6.0, 0, ridge_z + 2.2))
    prism("ClothBlue", [(0, 0), (3.0, -0.6), (0, -1.6)], 0.1, (-6.0, 0, ridge_z + 4.3))
    crystal_cluster("Gem", (-6.0, 0, ridge_z + 4.45), rnd, n=3, scale=0.25)

    # 처마 아래 등불
    for lx in (DX - DOOR_W / 2 - 1.2, CX + 3.2):
        box("Iron", (0.15, 1.6, 0.15), (lx, -D / 2 - 0.8, EAVE - 0.6))
        lantern((lx, -D / 2 - 1.5, EAVE - 2.0))

    # 앞마당 소품: 상자 더미, 통, 광석 자루, 광차
    def crate(x, y, z, s=1.6, r=0):
        box("Wood", (s, s, s), (x, y, z + s / 2), rot=(0, 0, r), bevel=0.06)
        for e in (-1, 1):
            box("WoodDark", (s + 0.04, 0.2, s * 0.22), (x, y + e * (s / 2 - 0.05), z + s / 2), rot=(0, 0, r))
    crate(-W / 2 - 1.8, -D / 2 + 1.0, 0, 2.0, 8)
    crate(-W / 2 - 1.6, -D / 2 + 3.4, 0, 1.8, -5)
    crate(-W / 2 - 1.7, -D / 2 + 2.0, 2.0, 1.6, 20)
    for i, (bx, by) in enumerate([(W / 2 + 1.5, -D / 2 + 1.2), (W / 2 + 1.4, -D / 2 + 3.1)]):
        lathe("Wood", [(0.75, 0), (0.95, 0.9), (0.95, 1.4), (0.75, 2.2)], (bx, by, 0), seg=12)
        torus("Iron", 0.92, 0.07, (bx, by, 0.55), seg=12, mseg=4)
        torus("Iron", 0.92, 0.07, (bx, by, 1.75), seg=12, mseg=4)
    for i in range(3):   # 광석 자루
        sx_ = W / 2 + 1.0 - i * 1.1
        lathe("ClothCream", [(0.5, 0), (0.75, 0.4), (0.7, 1.0), (0.3, 1.4), (0.15, 1.6)], (sx_, -D / 2 - 1.4, 0), seg=10)
    # 광차 + 짧은 선로
    for rx in (-0.8, 0.8):
        box("Iron", (0.2, 7.0, 0.2), (DX + rx, -D / 2 - 4.5, 0.1))
    for k in range(6):
        box("WoodDark", (2.4, 0.4, 0.15), (DX, -D / 2 - 1.8 - k * 1.1, 0.05))
    box("Iron", (2.2, 3.0, 1.6), (DX, -D / 2 - 4.0, 1.3), taper=(1.15, 1.15), bevel=0.06)
    for wy in (-1.0, 1.0):
        for wx in (-1.1, 1.1):
            cyl("Coal", 0.45, 0.25, (DX + wx, -D / 2 - 4.0 + wy, 0.5), rot=(0, 90, 0), verts=10)
    for j in range(6):
        box("Copper" if j % 2 else "Coal", (0.8, 0.8, 0.7), (DX + rnd.uniform(-0.6, 0.6), -D / 2 - 4.0 + rnd.uniform(-0.9, 0.9), 2.2),
            rot=(rnd.uniform(0, 40), rnd.uniform(0, 40), rnd.uniform(0, 90)), bevel=0.15)
    crystal_cluster("Amethyst", (DX + 0.3, -D / 2 - 4.2, 2.3), rnd, n=3, scale=0.35)

    return join_and_export("Storage", "Storage.fbx")


if __name__ == "__main__":
    build()
