"""
기본 광산 입구 장식 — 화로 2, 갱도 문틀 2, 레일, 광차, 벽 횃불 12, 매단 간판 테두리·사슬.
블렌더에서 실행하면 ~/Downloads/CollapseMine/EntranceProps.fbx

원점 = 입구 바닥 중심 MOUTH (Roblox 월드 (0, 0, 38)). Roblox 입구 로컬 (lx, ly, lz) → 블렌더 (-lx, lz, ly).
위치값은 Studio에서 지금 배치(tools/build_cave_entrance.luau가 레이로 맞춘 자리)를 뽑아 넣었다.
기능 부품(간판 글자판 Sign, 이동 판정 Field, 어둠 Darkness, 불·빛)은 Roblox 파트로 남긴다.

벽 횃불 끝(불 자리)은 횃불 원점 기준 (밖으로 TORCH_TIP[0], 위로 TORCH_TIP[1]).
tools/import_entrance_props.luau가 같은 값으로 Roblox 불 파트를 옮긴다.
"""
import bpy, math, random
try:
    from rbx_common import *  # noqa
except ImportError:
    pass

TORCH_TIP = (2.05, 2.75)


def R(lx, ly, lz):
    """Roblox 입구 로컬 → 블렌더"""
    return (-lx, lz, ly)


BRAZIERS = [(-32.0, 6.36, 10.0), (32.0, 4.70, 10.0)]             # Roblox 로컬 (x, 바닥 y, z)
GATES = [(-20.0, 13.59, 2.0, 19.03), (-28.0, 12.55, 2.0, 12.81)]  # (z, 기둥 x, 바닥 y, 기둥 높이)
TORCHES = [(-22.31, 6.0, 1), (22.17, 6.0, -1), (-18.91, -3.0, 1), (20.05, -3.0, -1), (-17.22, -12.0, 1), (17.25, -12.0, -1),
           (-15.48, -21.0, 1), (15.82, -21.0, -1), (-14.27, -30.0, 1), (14.04, -30.0, -1), (-12.71, -39.0, 1), (12.66, -39.0, -1)]
TORCH_Y = 9.0
RAIL_X, RAIL_Z1, RAIL_Z2, FLOOR = -4.0, 24.0, -52.0, 2.0
CART = (-4.0, 17.0)
SIGN = (0.0, 40.0, 6.0, 28.0, 7.0)          # (x, y, z, 폭, 높이), 글자 면은 +Z(허브 쪽)
CHAIN_TOPS = {10.0: 52.74, -10.0: 51.09}    # Roblox x → 천장 높이


def brazier(lx, gy, lz, rnd):
    bx, by, bz = R(lx, gy, lz)
    cyl("StoneDark", 3.4, 1.0, (bx, by, bz + 0.5), verts=8, bevel=0.12)
    cyl("Stone", 2.8, 1.2, (bx, by, bz + 1.6), verts=8, r2=2.4, bevel=0.1)
    cyl("StoneLight", 1.7, 9.0, (bx, by, bz + 2.2 + 4.5), verts=8, r2=1.25, bevel=0.08)
    for zz in (4.0, 9.5):
        torus("Iron", 1.62 - (zz - 4.0) * 0.045, 0.16, (bx, by, bz + zz), seg=16)
    cyl("Stone", 1.9, 0.8, (bx, by, bz + 11.6), verts=8, bevel=0.08)
    lathe("Iron", [(0.0, 0), (1.2, 0), (2.6, 1.0), (3.6, 2.2), (3.9, 3.0), (3.6, 3.1), (0.0, 3.1)], (bx, by, bz + 12.0), seg=20)
    torus("Gold", 3.8, 0.18, (bx, by, bz + 15.0), seg=24)
    cyl("Ember", 3.3, 0.4, (bx, by, bz + 14.9), verts=16)
    for k in range(6):   # 숯덩이
        a = k * math.pi / 3 + rnd.uniform(0, 0.4)
        box("Coal", (1.1, 1.0, 0.7), (bx + math.cos(a) * 1.8, by + math.sin(a) * 1.8, bz + 15.2), rot=(rnd.uniform(0, 30), rnd.uniform(0, 30), rnd.uniform(0, 90)), bevel=0.15)
    for k in range(4):   # 그릇을 받치는 발톱
        a = k * math.pi / 2 + math.pi / 4
        beam("Iron", (bx + math.cos(a) * 1.3, by + math.sin(a) * 1.3, bz + 11.4), (bx + math.cos(a) * 3.7, by + math.sin(a) * 3.7, bz + 15.6), 0.35)


def gate(lz, px, gy, ph, rnd, lamp=False):
    _, y, _ = R(0, 0, lz)
    z0 = gy
    for sx in (-1, 1):
        x = sx * px
        box("StoneDark", (3.4, 3.4, 0.8), (x, y, z0 + 0.4), bevel=0.15)                              # 받침돌
        cyl("Wood", 1.45, ph, (x, y, z0 + ph / 2), verts=8, r2=1.35, bevel=0.12)                   # 통나무 기둥
        for zz in (z0 + 1.6, z0 + ph - 2.2):
            torus("Iron", 1.48, 0.14, (x, y, zz), seg=12, mseg=4)
        beam("WoodDark", (x, y, z0 + ph - 5.5), (x - sx * 5.0, y, z0 + ph + 0.3), 0.9)              # 버팀대
        box("Iron", (0.3, 1.8, 1.8), (x - sx * 1.5, y, z0 + ph - 0.6), bevel=0.05)                 # 꺾쇠
    beam_len = 2 * px + 3.6
    cyl("Wood", 1.5, beam_len, (0, y, z0 + ph + 1.3), rot=(0, 90, 0), verts=8, bevel=0.12)         # 윗 들보
    for k in range(-3, 4):                                                                            # 들보 위 덧판(천장 받침)
        box("WoodDark", (1.6, 3.6, 0.35), (k * (beam_len / 7.5), y, z0 + ph + 2.95), rot=(0, 0, rnd.uniform(-4, 4)), bevel=0.05)
    for sx in (-1, 1):
        for zz in (z0 + ph + 1.3,):
            cyl("Iron", 0.22, 3.4, (sx * (px - 0.2), y, zz), rot=(90, 0, 0), verts=6)                # 볼트
    if lamp:
        box("Iron", (0.1, 0.1, 2.0), (0, y - 0.8, z0 + ph - 0.2))
        lantern((0, y - 0.8, z0 + ph - 1.9))


def rails():
    x0 = -RAIL_X
    y1, y2 = RAIL_Z1, RAIL_Z2
    L = y1 - y2
    yc = (y1 + y2) / 2
    for dx in (-2.0, 2.0):
        x = x0 + dx
        box("Iron", (0.7, L, 0.12), (x, yc, FLOOR + 0.46))     # 아랫날개
        box("Iron", (0.18, L, 0.36), (x, yc, FLOOR + 0.7))     # 몸통
        box("Steel", (0.42, L, 0.22), (x, yc, FLOOR + 0.98))   # 머리 (밟혀서 반짝이는 윗면)
    rnd = random.Random(9)
    y = y1 - 0.8
    while y > y2 + 0.5:
        box("Wood" if rnd.random() < 0.6 else "WoodDark", (6.0, 1.1, 0.42), (x0 + rnd.uniform(-0.15, 0.15), y, FLOOR + 0.2), rot=(0, 0, rnd.uniform(-3, 3)), bevel=0.06)
        for dx in (-2.0, 2.0):
            for s in (-1, 1):
                cyl("Iron", 0.09, 0.3, (x0 + dx + s * 0.35, y, FLOOR + 0.5), verts=6)
        y -= 2.5
    # 허브 쪽 끝 멈춤 받침
    box("WoodDark", (6.0, 1.4, 1.8), (x0, y1 + 0.4, FLOOR + 0.9), bevel=0.1)
    box("Iron", (6.2, 0.3, 0.4), (x0, y1 - 0.35, FLOOR + 1.4))
    for dx in (-2.0, 2.0):
        cyl("Iron", 0.35, 0.6, (x0 + dx, y1 - 0.5, FLOOR + 1.3), rot=(90, 0, 0), verts=10)


def cart(rnd):
    cx, cy = -CART[0], CART[1]
    base = FLOOR + 1.6
    box("Wood", (4.6, 6.6, 2.6), (cx, cy, base + 1.3), taper=(1.12, 1.08), bevel=0.12)
    for zz in (base + 0.35, base + 2.4):
        box("Iron", (4.6 * (1.0 + 0.12 * (zz - base) / 2.6) + 0.12, 6.6 * (1.0 + 0.08 * (zz - base) / 2.6) + 0.12, 0.22), (cx, cy, zz))
    for sx in (-1, 1):
        for sy in (-1, 1):
            box("Iron", (0.3, 0.3, 2.7), (cx + sx * 2.45, cy + sy * 3.4, base + 1.3), rot=(sy * 3, -sx * 3, 0))
    box("Iron", (3.6, 6.0, 0.3), (cx, cy, base - 0.2))       # 바닥 틀
    for sy in (-2.0, 2.0):                                     # 바퀴 + 축
        cyl("Iron", 0.15, 4.8, (cx, cy + sy, FLOOR + 0.9), rot=(0, 90, 0), verts=8)
        for sx in (-2.0, 2.0):
            cyl("Iron", 0.9, 0.35, (cx + sx, cy + sy, FLOOR + 0.9), rot=(0, 90, 0), verts=14)
            torus("Steel", 0.85, 0.1, (cx + sx * 1.05, cy + sy, FLOOR + 0.9), rot=(0, 90, 0), seg=14, mseg=4)
    for sy in (-1, 1):                                         # 손잡이 고리
        torus("Iron", 0.45, 0.09, (cx, cy + sy * 3.75, base + 2.1), rot=(90, 0, 0), seg=10, mseg=4)
    for j in range(14):                                        # 광석 더미
        r = rnd.uniform(0, 1.6); a = rnd.uniform(0, 2 * math.pi)
        box(["Coal", "Copper", "Iron", "Coal"][j % 4], (1.0, 0.9, 0.8), (cx + math.cos(a) * r, cy + math.sin(a) * r * 1.6, base + 2.7 + (1.6 - r) * 0.35),
            rot=(rnd.uniform(0, 40), rnd.uniform(0, 40), rnd.uniform(0, 90)), bevel=0.15)
    crystal_cluster("Gem", (cx + 0.4, cy - 0.6, base + 3.0), rnd, n=4, scale=0.55)


def wall_torch(lx, lz, out):
    """out=+1 이면 Roblox +X로 튀어나옴(왼쪽 벽). 블렌더에서는 -X 방향"""
    ox, oy, oz = R(lx, TORCH_Y, lz)
    d = -out   # 블렌더 X 방향

    def P(u, v, w=0.0):
        return (ox + d * u, oy + w, oz + v)
    box("Iron", (0.3, 1.4, 2.6), P(0.15, 0.0), bevel=0.06)                                  # 벽판
    for v in (-0.95, 0.95):
        for w in (-0.45, 0.45):
            cyl("Steel", 0.14, 0.2, P(0.32, v, w), rot=(0, 90, 0), verts=8)                 # 리벳
    beam("Iron", P(0.3, 0.3), P(1.6, 0.3), 0.22)                                              # 가로 팔
    beam("Iron", P(0.3, -1.0), P(1.45, 0.25), 0.18)                                           # 버팀
    torus("Iron", 0.48, 0.1, P(1.95, 0.3), seg=14, mseg=4)                                    # 잡는 고리
    lathe("Iron", [(0.0, 0), (0.25, 0), (0.45, 0.35), (0.5, 0.5), (0.0, 0.5)], P(1.95, -1.05), seg=10)  # 아래 받침 컵
    tilt = 8 * (1 if d > 0 else -1)
    cyl("Wood", 0.24, 3.2, P(1.98, 0.75), rot=(0, tilt, 0), verts=8, r2=0.3)                 # 손잡이
    for k in range(3):                                                                         # 천 감개
        cyl("ClothCream" if k % 2 == 0 else "Wood", 0.4 - k * 0.02, 0.28, P(2.0 + 0.04 * k, 2.15 + k * 0.25), rot=(0, tilt + (k - 1) * 4, 0), verts=10)
    cyl("Ember", 0.33, 0.25, P(TORCH_TIP[0], TORCH_TIP[1] - 0.05), verts=10)


def sign_frame():
    x, y, z, w, h = SIGN
    bx, by, bz = R(x, y, z)
    for zc in (bz + h / 2 + 0.45, bz - h / 2 - 0.45):
        box("WoodDark", (w + 2.2, 1.5, 0.9), (bx, by, zc), bevel=0.12)
    for sx in (-1, 1):
        box("WoodDark", (0.9, 1.5, h + 1.8), (bx + sx * (w / 2 + 0.65), by, bz), bevel=0.12)
        for sz in (-1, 1):
            box("Iron", (1.5, 1.7, 1.5), (bx + sx * (w / 2 + 0.6), by, bz + sz * (h / 2 + 0.45)), bevel=0.1)
            cyl("Gold", 0.3, 1.8, (bx + sx * (w / 2 + 0.6), by, bz + sz * (h / 2 + 0.45)), rot=(90, 0, 0), verts=8)
    # 사슬 (고리를 엇갈려 이어 천장까지)
    for lx, top in CHAIN_TOPS.items():
        cx = -lx
        zz = bz + h / 2 + 0.9
        k = 0
        torus("Iron", 0.5, 0.12, (cx, by, zz + 0.2), rot=(90, 0, 0), seg=12, mseg=4)         # 간판 고리
        while zz < top:
            torus("Iron", 0.32, 0.09, (cx, by, zz + 0.5), rot=(90, 0, 90 if k % 2 else 0), seg=10, mseg=4)
            zz += 0.55; k += 1
        box("Iron", (1.2, 1.2, 0.4), (cx, by, top), bevel=0.06)                                # 천장 고정쇠


def build():
    setup("EntranceProps")
    rnd = random.Random(17)
    for b in BRAZIERS:
        brazier(*b, rnd)
    for i, g in enumerate(GATES):
        gate(*g, rnd, lamp=(i == 0))
    rails()
    cart(rnd)
    for lx, lz, out in TORCHES:
        wall_torch(lx, lz, out)
    sign_frame()


if __name__ == "__main__":
    build()
    join_and_export("EN", "EntranceProps.fbx")
