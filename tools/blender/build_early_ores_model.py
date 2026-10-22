"""
1~3스테이지 광물 18종 — 직접 모델링 버전 (그림 텍스처 버전은 build_starfall_from_images.py 의 EARLY_ORES).
블렌더에서 실행하면 ~/Downloads/CollapseMine/EarlyOresModel.fbx

오브젝트 이름은 EM_<광석>_<재질>. 재질별로 나눠 두어야 Roblox에서 금속·유리·네온 등 재질을 따로 입힐 수 있다
(tools/import_early_ores_model.luau 의 LOOK 표). 모양은 제미나이 그림(ref/ore_*.png)을 참고했다.
1 블렌더 단위 = 1 스터드, 광석마다 바닥 가운데가 원점 근처, 앞면은 -Y.
"""
import bpy, bmesh, math, random, os
from mathutils import Vector, Euler, noise

COL = "EarlyOresModel"
ORDER = ["Coal", "Copper", "Quartz", "Amber", "CavePearl", "Lantern",
         "Iron", "Tin", "Silver", "Magnetite", "Platinum", "PocketWatch",
         "Limestone", "Calcite", "Azurite", "Malachite", "WaterPearl", "WetMap"]


def coll():
    c = bpy.data.collections.get(COL)
    if c is None:
        c = bpy.data.collections.new(COL)
        bpy.context.scene.collection.children.link(c)
    return c


def mat(name):
    m = bpy.data.materials.get("EM_" + name) or bpy.data.materials.new("EM_" + name)
    return m


def emit(bm, ore, mname, loc, smooth=False):
    """같은 광석·재질 오브젝트가 이미 있으면 거기에 합친다"""
    name = f"EM_{ore}_{mname}"
    for v in bm.verts:
        v.co += Vector(loc)
    ob = bpy.data.objects.get(name)
    if ob is None:
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me)
        ob = bpy.data.objects.new(name, me)
        me.materials.append(mat(mname))
        coll().objects.link(ob)
    else:
        tmp = bmesh.new(); tmp.from_mesh(ob.data)
        me2 = bpy.data.meshes.new("tmp"); bm.to_mesh(me2)
        tmp.from_mesh(me2); bpy.data.meshes.remove(me2)
        tmp.to_mesh(ob.data); tmp.free()
    bm.free()
    for p in ob.data.polygons:
        p.use_smooth = smooth or p.use_smooth
    return ob


# ---------- 모양 도우미 ----------
def ico(r, sub):
    bm = bmesh.new(); bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=r); return bm


def uvs(r, seg=16, ring=10):
    bm = bmesh.new(); bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=ring, radius=r); return bm


def lumpy(bm, amp, freq, seed):
    off = Vector((seed, seed * 2.1, seed * 3.3))
    for v in bm.verts:
        v.co *= 1 + amp * noise.noise(v.co * freq + off)
    return bm


def xf(bm, loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1)):
    m = Euler([math.radians(a) for a in rot]).to_matrix()
    for v in bm.verts:
        v.co = m @ Vector((v.co.x * scale[0], v.co.y * scale[1], v.co.z * scale[2])) + Vector(loc)
    return bm


def merge(dst, src):
    me = bpy.data.meshes.new("tmp"); src.to_mesh(me); src.free()
    dst.from_mesh(me); bpy.data.meshes.remove(me)
    return dst


def shard(bm, base, direction, length, radius, sides=6, tip=0.35):
    d = Vector(direction).normalized(); t1 = d.orthogonal().normalized(); t2 = d.cross(t1); base = Vector(base)
    angs = [2 * math.pi * i / sides for i in range(sides)]
    r0 = [bm.verts.new(base + (t1 * math.cos(a) + t2 * math.sin(a)) * radius) for a in angs]
    top = base + d * length * (1 - tip)
    r1 = [bm.verts.new(top + (t1 * math.cos(a) + t2 * math.sin(a)) * radius * 0.92) for a in angs]
    apex = bm.verts.new(base + d * length)
    for i in range(sides):
        j = (i + 1) % sides
        bm.faces.new((r0[i], r0[j], r1[j], r1[i])); bm.faces.new((r1[i], r1[j], apex))
    bm.faces.new(list(reversed(r0)))
    return bm


def octa(r, loc=(0, 0, 0), rot=(0, 0, 0), stretch=1.0):
    bm = bmesh.new()
    p = [(r, 0, 0), (-r, 0, 0), (0, r, 0), (0, -r, 0), (0, 0, r * stretch), (0, 0, -r * stretch)]
    v = [bm.verts.new(c) for c in p]
    for a, b in ((0, 2), (2, 1), (1, 3), (3, 0)):
        bm.faces.new((v[a], v[b], v[4])); bm.faces.new((v[b], v[a], v[5]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return xf(bm, loc, rot)


def cone(r1, r2, depth, seg=12, loc=(0, 0, 0), rot=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=seg, radius1=r1, radius2=r2, depth=depth)
    return xf(bm, loc, rot)


def box(size, loc=(0, 0, 0), rot=(0, 0, 0), bevel=0.0):
    bm = bmesh.new(); bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x *= size[0]; v.co.y *= size[1]; v.co.z *= size[2]
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=1, affect='EDGES', profile=0.5)
    return xf(bm, loc, rot)


def torus(R, r, loc=(0, 0, 0), rot=(0, 0, 0), seg=20, ms=6, arc=1.0):
    bm = bmesh.new(); rings = []
    n = seg if arc >= 1 else seg + 1
    for i in range(n):
        a = 2 * math.pi * arc * i / seg
        rings.append([bm.verts.new(((R + r * math.cos(b)) * math.cos(a), (R + r * math.cos(b)) * math.sin(a), r * math.sin(b)))
                      for b in [2 * math.pi * j / ms for j in range(ms)]])
    for i in range(seg if arc >= 1 else seg):
        i2 = (i + 1) % len(rings)
        for j in range(ms):
            bm.faces.new((rings[i][j], rings[i2][j], rings[i2][(j + 1) % ms], rings[i][(j + 1) % ms]))
    return xf(bm, loc, rot)


def lathe(profile, seg=20, loc=(0, 0, 0), rot=(0, 0, 0), cap=True):
    bm = bmesh.new(); rings = []
    for r, z in profile:
        rings.append([bm.verts.new((max(r, 1e-3) * math.cos(2 * math.pi * i / seg), max(r, 1e-3) * math.sin(2 * math.pi * i / seg), z)) for i in range(seg)])
    for k in range(len(rings) - 1):
        for i in range(seg):
            bm.faces.new((rings[k][i], rings[k][(i + 1) % seg], rings[k + 1][(i + 1) % seg], rings[k + 1][i]))
    if cap:
        bm.faces.new(list(reversed(rings[0]))); bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return xf(bm, loc, rot)


def surf_pts(R, n, rnd, squash=(1, 1, 1), zmin=-0.3, amp=0.0, freq=1.0, seed=0, front=0.0):
    """덩어리 겉면 점들 (front>0이면 앞쪽(-Y)에 몰리게)"""
    out = []
    while len(out) < n:
        d = Vector((rnd.gauss(0, 1), rnd.gauss(0, 1) - front, rnd.gauss(0, 1))).normalized()
        if d.z < zmin:
            continue
        rr = R * (1 + amp * noise.noise(d * R * freq + Vector((seed, seed * 2.1, seed * 3.3))))
        p = d * rr
        out.append((Vector((p.x * squash[0], p.y * squash[1], p.z * squash[2])), d))
    return out


def rock(R, sub, amp, freq, seed, squash, rot=(0, 0, 0)):
    # create_icosphere의 subdivisions=1은 면 20개(정이십면체)라 한 단계 올려서 쓴다
    return xf(lumpy(ico(R, sub + 1), amp, freq, seed), scale=squash, rot=rot)


# ---------- 광석 18종 ----------
def build_ores(origin_of):
    rnd = random.Random(7)

    # 1) 석탄: 각진 검은 덩어리 몇 개가 뭉친 모양 (면이 각지게 플랫 셰이딩)
    o = origin_of("Coal")
    bm = rock(1.05, 1, 0.22, 1.3, 3, (1.1, 1.0, 0.95))
    for p, s in (((0.7, -0.3, 0.5), 0.55), ((-0.75, -0.2, 0.25), 0.5), ((0.1, 0.5, 0.75), 0.5)):
        merge(bm, xf(lumpy(ico(s, 0), 0.2, 2, rnd.random() * 9), loc=p, rot=(rnd.uniform(0, 90), rnd.uniform(0, 90), 0)))
    emit(xf(bm, loc=(0, 0, 1.0)), "Coal", "CoalRock", o)

    # 2) 구리: 회갈색 바위 + 튀어나온 구리 덩이 + 녹청 점
    o = origin_of("Copper")
    emit(xf(rock(1.1, 2, 0.16, 1.1, 11, (1.05, 0.95, 1.0)), loc=(0, 0, 1.1)), "Copper", "CopperRock", o)
    bm = bmesh.new()
    for p, d in surf_pts(1.1, 8, rnd, (1.05, 0.95, 1.0), zmin=-0.2, front=0.8):
        merge(bm, xf(lumpy(ico(rnd.uniform(0.24, 0.38), 1), 0.25, 3, rnd.random() * 9), loc=tuple(p + d * 0.05 + Vector((0, 0, 1.1))), scale=(1.2, 0.8, 1)))
    emit(bm, "Copper", "CopperMetal", o)
    bm = bmesh.new()
    for p, d in surf_pts(1.12, 14, rnd, (1.05, 0.95, 1.0), zmin=0, front=0.5):
        merge(bm, xf(ico(rnd.uniform(0.04, 0.07), 0), loc=tuple(p + Vector((0, 0, 1.1)))))
    emit(bm, "Copper", "CopperPatina", o)

    # 3) 석영: 회색 돌 받침 + 하얀 결정 다발
    o = origin_of("Quartz")
    emit(xf(rock(0.85, 1, 0.2, 1.5, 21, (1.3, 1.0, 0.45)), loc=(0, 0, 0.35)), "Quartz", "QuartzBase", o)
    bm = bmesh.new()
    shard(bm, (0.1, 0, 0.4), (0.12, 0, 1), 2.4, 0.33)
    shard(bm, (-0.45, 0.05, 0.35), (-0.45, 0, 1), 2.0, 0.3)
    for i in range(6):
        a = i * 2 * math.pi / 6 + rnd.uniform(-0.3, 0.3); t = rnd.uniform(0.5, 1.0)
        shard(bm, (math.cos(a) * 0.5, math.sin(a) * 0.4, 0.4), (math.cos(a) * t, math.sin(a) * t, 1), rnd.uniform(0.7, 1.3), rnd.uniform(0.14, 0.22))
    emit(bm, "Quartz", "QuartzCrystal", o)

    # 4) 호박석: 둥그스름한 꿀빛 덩어리(반투명) 안에 나뭇잎 + 아래 돌
    o = origin_of("Amber")
    emit(xf(rock(1.05, 1, 0.18, 1.2, 31, (1.05, 0.85, 1.0)), loc=(0, 0, 1.15)), "Amber", "AmberBody", o)
    leaf = bmesh.new()
    pts = [(0, 0.55), (0.18, 0.3), (0.22, 0.0), (0.12, -0.3), (0, -0.5), (-0.12, -0.3), (-0.22, 0.0), (-0.18, 0.3)]
    f = [leaf.verts.new((x, -0.02, z)) for x, z in pts]; b = [leaf.verts.new((x, 0.02, z)) for x, z in pts]
    leaf.faces.new(f); leaf.faces.new(list(reversed(b)))
    for i in range(len(pts)):
        leaf.faces.new((f[i], b[i], b[(i + 1) % len(pts)], f[(i + 1) % len(pts)]))
    bmesh.ops.recalc_face_normals(leaf, faces=leaf.faces)
    emit(xf(leaf, loc=(0.05, -0.25, 1.2), rot=(10, 0, -35)), "Amber", "AmberLeaf", o)
    bm = bmesh.new()
    for x in (-0.5, 0.15, 0.6):
        merge(bm, xf(lumpy(ico(0.32, 0), 0.2, 2, x * 7), loc=(x, 0.1, 0.18), scale=(1.2, 1, 0.6)))
    emit(bm, "Amber", "AmberBase", o)

    # 5) 동굴 진주: 석회 그릇 안에 둥근 진주 여러 알
    o = origin_of("CavePearl")
    prof = [(0.0, 0.0), (1.0, 0.02), (1.35, 0.35), (1.4, 0.75), (1.2, 0.85), (1.05, 0.55), (0.6, 0.35), (0.0, 0.3)]
    emit(lumpy(lathe(prof, seg=18), 0.08, 2.0, 41), "CavePearl", "PearlCup", o)
    bm = bmesh.new()
    for i, (x, y, z, r) in enumerate([(0, 0, 0.6, 0.36), (0.55, 0.1, 0.6, 0.3), (-0.5, 0.15, 0.6, 0.31), (0.2, -0.5, 0.58, 0.28),
                                      (-0.25, -0.45, 0.6, 0.27), (0.3, 0.5, 0.62, 0.28), (-0.35, 0.5, 0.6, 0.26), (0.05, 0.0, 0.98, 0.3),
                                      (0.45, -0.25, 0.92, 0.24), (-0.4, -0.1, 0.92, 0.25)]):
        merge(bm, xf(uvs(r, 14, 8), loc=(x, y, z)))
    emit(bm, "CavePearl", "Pearl", o, smooth=True)

    # 6) 광부의 녹슨 등불
    o = origin_of("Lantern")
    bm = cone(0.62, 0.66, 0.28, seg=16, loc=(0, 0, 0.14))                     # 아래 받침(기름통)
    merge(bm, cone(0.66, 0.5, 0.14, seg=16, loc=(0, 0, 0.35)))
    merge(bm, cone(0.5, 0.18, 0.45, seg=16, loc=(0, 0, 1.95)))                 # 위 뚜껑
    merge(bm, cone(0.56, 0.56, 0.08, seg=16, loc=(0, 0, 1.7)))
    for i in range(4):                                                            # 유리 둘레 철사
        a = i * math.pi / 2 + math.pi / 4
        merge(bm, box((0.07, 0.07, 1.3), loc=(math.cos(a) * 0.5, math.sin(a) * 0.5, 1.05)))
    merge(bm, torus(0.5, 0.04, loc=(0, 0, 0.75), seg=16, ms=4))
    merge(bm, torus(0.5, 0.04, loc=(0, 0, 1.35), seg=16, ms=4))
    merge(bm, torus(0.42, 0.045, loc=(0, 0, 2.15), rot=(90, 0, 0), seg=16, ms=5, arc=0.5))  # 손잡이
    merge(bm, torus(0.14, 0.04, loc=(0, 0, 2.62), rot=(90, 0, 0), seg=10, ms=4))
    merge(bm, cone(0.12, 0.12, 0.25, seg=8, loc=(0.45, -0.35, 0.45), rot=(90, 0, 40)))       # 심지 손잡이
    emit(lumpy(bm, 0.02, 4, 3), "Lantern", "LanternIron", o)
    emit(cone(0.45, 0.45, 1.25, seg=16, loc=(0, 0, 1.05)), "Lantern", "LanternGlass", o)
    fl = uvs(0.17, 10, 8)
    for v in fl.verts:
        if v.co.z > 0:
            v.co.z *= 2.4; v.co.x *= 1 - v.co.z * 0.9; v.co.y *= 1 - v.co.z * 0.9
    emit(xf(fl, loc=(0, 0, 0.95)), "Lantern", "LanternFlame", o, smooth=True)

    # 7) 철: 붉은 회색 바위 + 금속 띠 결정
    o = origin_of("Iron")
    emit(xf(rock(1.1, 1, 0.2, 1.2, 51, (1.0, 0.92, 1.05)), loc=(0, 0, 1.1)), "Iron", "IronRock", o)
    bm = bmesh.new()
    for p, d in surf_pts(1.05, 7, rnd, (1.0, 0.92, 1.05), zmin=-0.3, front=0.7):
        tang = d.cross(Vector((0, 0, 1))).normalized() if abs(d.z) < 0.9 else Vector((1, 0, 0))
        merge(bm, shard(bmesh.new(), p + Vector((0, 0, 1.1)) - tang * 0.3 - d * 0.1, tang + d * 0.15, 0.7, 0.14, sides=4, tip=0.25))
    emit(bm, "Iron", "IronMetal", o)

    # 8) 주석: 어두운 바위 + 은회색 결정 송이
    o = origin_of("Tin")
    emit(xf(rock(1.1, 1, 0.22, 1.1, 61, (1.05, 0.95, 1.0)), loc=(0, 0, 1.1)), "Tin", "TinRock", o)
    bm = bmesh.new()
    for p, d in surf_pts(1.05, 5, rnd, (1.05, 0.95, 1.0), zmin=-0.1, front=0.8):
        for k in range(3):
            j = Vector((rnd.uniform(-0.18, 0.18), rnd.uniform(-0.18, 0.18), rnd.uniform(-0.18, 0.18)))
            shard(bm, p + Vector((0, 0, 1.1)) + j - d * 0.1, d + j, rnd.uniform(0.45, 0.7), rnd.uniform(0.1, 0.15), sides=4, tip=0.4)
    emit(bm, "Tin", "TinCrystal", o)

    # 9) 은: 회색 바위 + 은 덩이와 철사 같은 은맥
    o = origin_of("Silver")
    emit(xf(rock(1.1, 1, 0.2, 1.2, 71, (1.0, 0.95, 1.05)), loc=(0, 0, 1.1)), "Silver", "SilverRock", o)
    bm = bmesh.new()
    pts = surf_pts(1.02, 7, rnd, (1.0, 0.95, 1.05), zmin=-0.3, front=1.0)
    for p, d in pts:  # 바위에 반쯤 박힌 은 덩이
        merge(bm, xf(lumpy(uvs(rnd.uniform(0.22, 0.34), 12, 8), 0.25, 3, rnd.random() * 9), loc=tuple(p + Vector((0, 0, 1.1)))))
    for (p1, _), (p2, _) in zip(pts, pts[1:]):  # 은맥: 겉면을 따라 이어진 작은 구슬 줄
        for k in range(1, 8):
            q = p1.lerp(p2, k / 8).normalized() * 1.0
            merge(bm, xf(uvs(0.1, 8, 5), loc=tuple(q + Vector((0, 0, 1.1)))))
    emit(bm, "Silver", "SilverMetal", o, smooth=True)

    # 10) 자철석: 검은 팔면체 결정 다발
    o = origin_of("Magnetite")
    emit(xf(rock(0.8, 1, 0.2, 1.4, 81, (1.2, 1.0, 0.55)), loc=(0, 0, 0.42)), "Magnetite", "MagnetiteBase", o)
    bm = bmesh.new()
    for x, y, z, r in [(0, 0, 1.2, 0.62), (0.7, -0.1, 0.95, 0.45), (-0.65, 0.05, 0.95, 0.48), (0.25, -0.55, 0.85, 0.38),
                       (-0.3, 0.5, 0.9, 0.4), (0.55, 0.5, 0.8, 0.32), (-0.6, -0.5, 0.75, 0.3)]:
        merge(bm, octa(r, (x, y, z), (rnd.uniform(-25, 25), rnd.uniform(-25, 25), rnd.uniform(0, 90)), 1.15))
    emit(bm, "Magnetite", "MagnetiteCrystal", o)

    # 11) 백금: 매끈하고 묵직한 은백색 덩이
    o = origin_of("Platinum")
    bm = lumpy(ico(1.05, 3), 0.16, 1.4, 91)
    for p, s in (((0.55, -0.2, 0.45), 0.5), ((-0.5, -0.25, 0.5), 0.48), ((0.1, -0.35, -0.3), 0.45)):
        merge(bm, xf(lumpy(ico(s, 2), 0.15, 2, s * 9), loc=p))
    emit(xf(bm, loc=(0, 0, 1.05), scale=(1.05, 0.95, 1.0)), "Platinum", "PlatinumMetal", o, smooth=True)

    # 12) 감독관의 회중시계: 뚜껑이 열린 황동 시계 + 짧은 사슬 (앞을 보고 살짝 기울임)
    o = origin_of("PocketWatch")
    TILT = (75, 0, 12)
    brass = cone(1.0, 1.0, 0.32, seg=28)
    merge(brass, torus(1.0, 0.09, loc=(0, 0, 0.17), seg=28, ms=6))
    merge(brass, torus(1.0, 0.09, loc=(0, 0, -0.17), seg=28, ms=6))
    merge(brass, cone(0.14, 0.14, 0.25, seg=10, loc=(0, 1.12, 0), rot=(90, 0, 0)))                  # 용두
    merge(brass, torus(0.2, 0.05, loc=(0, 1.38, 0), rot=(0, 90, 0), seg=12, ms=5))                  # 고리
    # 뚜껑: 아래쪽 가장자리(경첩)를 축으로 뒤로 젖혀 열린 모양
    lid = cone(1.0, 1.0, 0.08, seg=28, loc=(0, 1.0, 0))
    merge(lid, torus(1.0, 0.07, loc=(0, 1.0, 0), seg=28, ms=5))
    xf(lid, rot=(-115, 0, 0))
    merge(brass, xf(lid, loc=(0, -1.0, -0.17)))
    emit(xf(brass, rot=TILT, loc=(0, 0, 1.35)), "PocketWatch", "WatchBrass", o, smooth=True)
    emit(xf(cone(0.86, 0.86, 0.04, seg=28, loc=(0, 0, 0.17)), rot=TILT, loc=(0, 0, 1.35)), "PocketWatch", "WatchFace", o)
    hands = box((0.06, 0.55, 0.03), loc=(0, 0.27, 0.21))
    merge(hands, box((0.06, 0.4, 0.03), loc=(0.17, -0.1, 0.21), rot=(0, 0, 60)))
    for i in range(12):
        a = i * math.pi / 6
        merge(hands, box((0.05, 0.12, 0.02), loc=(math.sin(a) * 0.72, math.cos(a) * 0.72, 0.2), rot=(0, 0, -math.degrees(a))))
    emit(xf(hands, rot=TILT, loc=(0, 0, 1.35)), "PocketWatch", "WatchInk", o)
    ch = bmesh.new()
    for i in range(6):
        merge(ch, torus(0.12, 0.035, loc=(0.25 + i * 0.17, 0.0, 2.6 - i * 0.2), rot=(0 if i % 2 else 90, 30, 0), seg=10, ms=4))
    emit(ch, "PocketWatch", "WatchBrass", o)

    # 13) 석회석: 연베이지 각진 덩어리 + 작은 구멍
    o = origin_of("Limestone")
    emit(xf(rock(1.1, 1, 0.18, 1.0, 101, (1.1, 1.0, 0.95)), loc=(0, 0, 1.05)), "Limestone", "LimeRock", o)
    bm = bmesh.new()
    for p, d in surf_pts(1.12, 16, rnd, (1.1, 1.0, 0.95), zmin=-0.2, front=0.6):
        merge(bm, xf(uvs(rnd.uniform(0.05, 0.09), 8, 5), loc=tuple(p + Vector((0, 0, 1.05)) - d * 0.03), scale=(1, 1, 0.6)))
    emit(bm, "Limestone", "LimeHole", o)

    # 14) 방해석: 비스듬한 마름모 결정(반투명 주황)
    o = origin_of("Calcite")
    bm = box((1.3, 1.3, 1.3), bevel=0.05)
    for v in bm.verts:  # 세 축을 서로 섞어 마름모 결정(능면체)
        x, y, z = v.co
        v.co = Vector((x + 0.28 * (y + z), y + 0.28 * (x + z), z + 0.28 * (x + y)))
    emit(xf(bm, rot=(-20, -30, 25), loc=(0, 0, 1.25)), "Calcite", "CalciteCrystal", o)

    # 15) 남동석: 어두운 바위 + 진한 파랑 결정 송이
    o = origin_of("Azurite")
    emit(xf(rock(1.05, 1, 0.2, 1.2, 121, (1.05, 1.0, 0.9)), loc=(0, 0, 1.0)), "Azurite", "AzuriteRock", o)
    bm = bmesh.new()
    for p, d in surf_pts(1.0, 9, rnd, (1.05, 1.0, 0.9), zmin=0.0, front=0.7):
        for k in range(4):
            j = Vector((rnd.uniform(-0.2, 0.2), rnd.uniform(-0.2, 0.2), rnd.uniform(-0.1, 0.25)))
            shard(bm, p + Vector((0, 0, 1.0)) - d * 0.05, d + j, rnd.uniform(0.35, 0.6), rnd.uniform(0.07, 0.11), sides=5, tip=0.4)
    emit(bm, "Azurite", "AzuriteCrystal", o)

    # 16) 공작석: 포도송이처럼 둥근 혹이 뭉친 초록 덩어리 (Roblox Marble 재질로 줄무늬)
    o = origin_of("Malachite")
    bm = lumpy(ico(0.95, 2), 0.1, 1.5, 131)
    for p, d in surf_pts(0.95, 14, rnd, zmin=-0.4):
        merge(bm, xf(lumpy(ico(rnd.uniform(0.3, 0.5), 2), 0.08, 2, rnd.random() * 9), loc=tuple(p * 0.85)))
    emit(xf(bm, loc=(0, 0, 1.0)), "Malachite", "MalachiteStone", o, smooth=True)

    # 17) 물빛 진주: 벌어진 조개 + 빛나는 하늘색 진주
    o = origin_of("WaterPearl")
    shell = lathe([(0.0, 0.0), (0.7, 0.05), (1.15, 0.22), (1.3, 0.42), (1.28, 0.48), (1.1, 0.3), (0.6, 0.16), (0.0, 0.12)], seg=22)
    for v in shell.verts:  # 부채꼴 골
        a = math.atan2(v.co.y, v.co.x); r = Vector((v.co.x, v.co.y)).length
        v.co.z += 0.05 * math.cos(a * 9) * min(1, r)
    top = shell.copy()
    xf(shell, scale=(1.0, 1.0, 1.0), loc=(0, 0, 0.05))
    xf(top, rot=(180, 0, 0)); xf(top, rot=(-60, 0, 0), loc=(0, 0.95, 0.6))
    merge(shell, top)
    emit(shell, "WaterPearl", "Shell", o, smooth=True)
    emit(xf(uvs(0.5, 18, 12), loc=(0, -0.05, 0.62)), "WaterPearl", "WaterPearlGem", o, smooth=True)
    bm = bmesh.new()
    for x, y in ((0.7, -0.5), (-0.6, -0.6), (0.9, 0.2)):
        merge(bm, xf(uvs(0.07, 8, 6), loc=(x, y, 0.42), scale=(1, 1, 1.3)))
    emit(bm, "WaterPearl", "WaterDrop", o, smooth=True)

    # 18) 젖은 광산 지도: 살짝 휘어진 양피지 + 양끝 말림 + 굴 그림과 빨간 X
    o = origin_of("WetMap")
    sheet = bmesh.new()
    bmesh.ops.create_grid(sheet, x_segments=12, y_segments=8, size=1.0)
    for v in sheet.verts:
        v.co.x *= 1.25; v.co.y *= 0.9
        v.co.z = 0.08 * math.sin(v.co.x * 3) + 0.05 * math.cos(v.co.y * 4)
    bmesh.ops.solidify(sheet, geom=sheet.faces[:], thickness=0.04)
    merge(sheet, cone(0.18, 0.18, 1.9, seg=12, loc=(-1.3, 0, 0.12), rot=(90, 0, 0)))
    merge(sheet, cone(0.13, 0.13, 1.9, seg=12, loc=(1.3, 0, 0.1), rot=(90, 0, 0)))
    MAPROT, MAPLOC = (-62, 0, 8), (0, 0, 1.15)
    emit(xf(sheet, rot=MAPROT, loc=MAPLOC), "WetMap", "Paper", o)
    ink = bmesh.new()
    path = [(-0.9, -0.4), (-0.5, -0.1), (-0.2, -0.4), (0.2, 0.1), (0.55, -0.15), (0.85, 0.35)]
    for (x1, y1), (x2, y2) in zip(path, path[1:]):
        dx, dy = x2 - x1, y2 - y1
        merge(ink, box((math.hypot(dx, dy), 0.06, 0.03), loc=((x1 + x2) / 2, (y1 + y2) / 2, 0.11), rot=(0, 0, math.degrees(math.atan2(dy, dx)))))
    merge(ink, box((0.06, 0.5, 0.03), loc=(-0.2, 0.15, 0.11)))
    merge(ink, box((0.45, 0.06, 0.03), loc=(0.2, 0.45, 0.11)))
    emit(xf(ink, rot=MAPROT, loc=MAPLOC), "WetMap", "Ink", o)
    x = box((0.4, 0.08, 0.03), loc=(0.6, 0.45, 0.12), rot=(0, 0, 45))
    merge(x, box((0.4, 0.08, 0.03), loc=(0.6, 0.45, 0.12), rot=(0, 0, -45)))
    emit(xf(x, rot=MAPROT, loc=MAPLOC), "WetMap", "InkRed", o)


def build():
    sc = bpy.data.scenes.get("EarlyOresModel") or bpy.data.scenes.new("EarlyOresModel")
    bpy.context.window.scene = sc
    c = coll()
    if c.name not in sc.collection.children:
        sc.collection.children.link(c)
    for ob in list(c.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    origin_of = lambda k: ((ORDER.index(k) % 6) * 4 - 10, (ORDER.index(k) // 6) * 4, 0)
    build_ores(origin_of)
    report = []
    for ob in c.objects:
        tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
        assert tris < 20000, ob.name
        report.append(f"{ob.name}:{tris}")
    return report


def export():
    c = coll()
    bpy.ops.object.select_all(action='DESELECT')
    obs = [o for o in c.objects if o.type == 'MESH']
    for o in obs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = obs[0]
    path = os.path.join(os.path.expanduser("~"), "Downloads", "CollapseMine", "EarlyOresModel.fbx")
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={'MESH'}, apply_unit_scale=True,
                             apply_scale_options='FBX_SCALE_ALL', axis_forward='-Z', axis_up='Y', mesh_smooth_type='FACE',
                             bake_space_transform=True)
    print("내보냄:", path)
    return path


if __name__ == "__main__":
    print(build())
    export()
