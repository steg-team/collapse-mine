"""
"별이 떨어진 곳" 광석 6종 (docs/decisions.md D-010). 블렌더에서 실행하면 ~/Downloads/CollapseMine/StarfallOres.fbx

- 운석 파편: 불규칙한 돌판 사이로 용암 핵이 비침
- 별가루 원석: 짙은 남색 덩어리에 빛 알갱이가 박힘
- 성운석: 매끈한 둥근 돌 (은하 소용돌이 무늬는 Roblox AI 텍스처로)
- 혜성 핵: 각진 얼음 덩어리와 가시 + 감싸는 빛 구슬 (Roblox ForceField)
- 별빛 결정: 분홍빛 받침 위 결정 다발
- 떨어진 별: 통통하고 울퉁불퉁한 금빛 별

참고 이미지(제미나이 그림)에 맞춰 모양을 잡았다. 무늬가 필요한 메시는 UV를 펼쳐 내보낸다.

오브젝트 이름은 SF_<광석>_<재질>. 재질별로 따로 두어야 Roblox에서 빛나는 부분만 Neon으로 바꿀 수 있다.
빛·반짝임은 Roblox에서 입힌다 (tools/import_starfall_ores.luau).
새 장면 "Starfall"에서 만들어 다른 작업 장면을 건드리지 않는다.
"""
import bpy, bmesh, math, random, os
from mathutils import Vector, Euler, noise

PAL = {
    "MeteorRock": (0.16, 0.11, 0.09), "MeteorLava": (1.0, 0.35, 0.05),
    "StardustRock": (0.06, 0.08, 0.22), "StardustSpeck": (1.0, 0.95, 0.75),
    "NebulaBase": (0.28, 0.10, 0.45), "NebulaPink": (0.95, 0.35, 0.80), "NebulaBlue": (0.30, 0.45, 0.95),
    "CometIce": (0.70, 0.88, 1.0), "CometAura": (0.45, 0.80, 1.0), "NebulaSwirl": (0.45, 0.20, 0.65), "CrystalGlow": (1.0, 0.70, 0.85),
    "CrystalShard": (1.0, 0.95, 0.60), "CrystalBase": (0.22, 0.20, 0.26),
    "StarGold": (1.0, 0.78, 0.15), "StarCore": (1.0, 0.95, 0.55), "StarRock": (0.20, 0.17, 0.15),
}
COL = "StarfallOres"


def mats():
    for n, c in PAL.items():
        m = bpy.data.materials.get("SF_" + n) or bpy.data.materials.new("SF_" + n)
        m.diffuse_color = (*[v ** 2.2 for v in c], 1)


def coll():
    c = bpy.data.collections.get(COL)
    if c is None:
        c = bpy.data.collections.new(COL)
        bpy.context.scene.collection.children.link(c)
    return c


def emit(bm, ore, matkey, loc=(0, 0, 0)):
    name = f"SF_{ore}_{matkey}"
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me); bm.free()
    for p in me.polygons:
        p.use_smooth = False
    ob = bpy.data.objects.new(name, me)
    me.materials.append(bpy.data.materials["SF_" + matkey])
    coll().objects.link(ob)
    ob.location = loc
    return ob


def ico(r, sub):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=r)
    return bm


def lumpy(bm, amp, freq, seed):
    for v in bm.verts:
        v.co *= 1 + amp * noise.noise(v.co * freq + Vector((seed, seed * 2, seed * 3)))


def transformed(bm, loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1)):
    m = Euler([math.radians(a) for a in rot]).to_matrix().to_4x4()
    for v in bm.verts:
        v.co = m @ Vector((v.co.x * scale[0], v.co.y * scale[1], v.co.z * scale[2])) + Vector(loc)
    return bm


def add_into(dst, src):
    me = bpy.data.meshes.new("tmp"); src.to_mesh(me); src.free()
    dst.from_mesh(me); bpy.data.meshes.remove(me)


def blob(ore, mat, R, sub, amp, freq, seed, loc, squash=(1, 1, 1)):
    bm = ico(R, sub); lumpy(bm, amp, freq, seed); transformed(bm, scale=squash)
    return emit(bm, ore, mat, loc)


def cell_shell(ore, mat, R, sub, shrink, thick, amp, seed, loc, squash=(1, 1, 1)):
    """구를 불규칙한 판으로 쪼갠 껍질. 판 사이 틈으로 안쪽 핵이 보인다"""
    src = ico(1.0, sub)
    out = bmesh.new()
    rnd = random.Random(seed)
    for v in src.verts:
        v.co = (v.co + Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-1, 1))) * 0.2).normalized()
    sq = lambda p: Vector((p.x * squash[0], p.y * squash[1], p.z * squash[2]))
    for v in src.verts:
        cents = [f.calc_center_median() for f in v.link_faces]
        n = v.co.normalized()
        t1 = n.orthogonal().normalized(); t2 = n.cross(t1)
        cents.sort(key=lambda c: math.atan2((c - v.co).dot(t2), (c - v.co).dot(t1)))
        rr = R * (1 + amp * noise.noise(v.co * 1.7 + Vector((seed, 0, 0)))) * rnd.uniform(0.96, 1.06)
        center = n * rr
        outer = [center + (c.normalized() * rr - center) * shrink * rnd.uniform(0.9, 1.05) for c in cents]
        inner = [p * (1 - thick / rr) for p in outer]
        ov = [out.verts.new(sq(p)) for p in outer]
        iv = [out.verts.new(sq(p)) for p in inner]
        cv = out.verts.new(sq(center) * 1.015)
        k = len(ov)
        for i in range(k):
            out.faces.new((cv, ov[i], ov[(i + 1) % k]))
            out.faces.new((ov[i], iv[i], iv[(i + 1) % k], ov[(i + 1) % k]))
        out.faces.new(list(reversed(iv)))
    src.free()
    bmesh.ops.recalc_face_normals(out, faces=out.faces)
    return emit(out, ore, mat, loc)


def shard(bm, base, direction, length, radius, sides=6, tip=0.35):
    d = Vector(direction).normalized()
    t1 = d.orthogonal().normalized(); t2 = d.cross(t1)
    base = Vector(base)
    angs = [2 * math.pi * i / sides for i in range(sides)]
    ring0 = [bm.verts.new(base + (t1 * math.cos(a) + t2 * math.sin(a)) * radius) for a in angs]
    top = base + d * length * (1 - tip)
    ring1 = [bm.verts.new(top + (t1 * math.cos(a) + t2 * math.sin(a)) * radius * 0.92) for a in angs]
    apex = bm.verts.new(base + d * length)
    for i in range(sides):
        j = (i + 1) % sides
        bm.faces.new((ring0[i], ring0[j], ring1[j], ring1[i]))
        bm.faces.new((ring1[i], ring1[j], apex))
    bm.faces.new(list(reversed(ring0)))


def surface_points(R, amp, freq, seed, n, rnd, squash=(1, 1, 1), zmin=-0.6):
    pts = []
    while len(pts) < n:
        d = Vector((rnd.gauss(0, 1), rnd.gauss(0, 1), rnd.gauss(0, 1))).normalized()
        if d.z < zmin:
            continue
        p = d * R * (1 + amp * noise.noise(d * R * freq + Vector((seed, seed * 2, seed * 3))))
        pts.append((Vector((p.x * squash[0], p.y * squash[1], p.z * squash[2])), d))
    return pts


def specks(ore, mat, pts, rnd, rmin, rmax, loc):
    bm = bmesh.new()
    for p, d in pts:
        s = ico(rnd.uniform(rmin, rmax), 0)
        transformed(s, loc=tuple(p + d * 0.02), rot=(rnd.uniform(0, 90), rnd.uniform(0, 90), rnd.uniform(0, 90)))
        add_into(bm, s)
    return emit(bm, ore, mat, loc)


def _unused_torus_bm(R, r, rot, segs=28, ms=4):
    t = bmesh.new()
    rings = []
    for i in range(segs):
        a = 2 * math.pi * i / segs
        rings.append([t.verts.new(((R + r * math.cos(b)) * math.cos(a), (R + r * math.cos(b)) * math.sin(a), r * math.sin(b)))
                      for b in [2 * math.pi * j / ms for j in range(ms)]])
    for i in range(segs):
        for j in range(ms):
            t.faces.new((rings[i][j], rings[(i + 1) % segs][j], rings[(i + 1) % segs][(j + 1) % ms], rings[i][(j + 1) % ms]))
    return transformed(t, rot=rot)


def build():
    sc = bpy.data.scenes.get("Starfall") or bpy.data.scenes.new("Starfall")
    bpy.context.window.scene = sc
    mats()
    c = coll()
    for o in list(c.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    rnd = random.Random(21)

    # 1) 운석 파편
    SQ = (1.12, 1.0, 0.92)
    blob("Meteor", "MeteorLava", 1.22, 2, 0.02, 1.5, 3, (-10, 0, 1.3), squash=SQ)
    cell_shell("Meteor", "MeteorRock", 1.38, 1, 0.87, 0.3, 0.12, 8, (-10, 0, 1.3), squash=SQ)

    # 2) 별가루 원석 (둥글고 매끈하게, 무늬는 AI 텍스처) + 표면 빛 알갱이
    SQ = (1.08, 1.0, 0.95)
    bm = ico(1.2, 3); lumpy(bm, 0.1, 0.9, 7); transformed(bm, scale=SQ)
    emit(bm, "Stardust", "StardustRock", (-6, 0, 1.2))
    specks("Stardust", "StardustSpeck", surface_points(1.2, 0.1, 0.9, 7, 45, rnd, SQ, zmin=-0.5), rnd, 0.04, 0.1, (-6, 0, 1.2))

    # 3) 성운석
    bm = ico(1.25, 3); lumpy(bm, 0.14, 0.9, 13); transformed(bm, scale=(1.0, 0.92, 1.1), rot=(0, 18, 0))
    emit(bm, "Nebula", "NebulaSwirl", (-2, 0, 1.35))

    # 4) 혜성 핵
    bm = ico(1.05, 1); lumpy(bm, 0.28, 1.2, 31)
    for i in range(7):
        d = Vector((rnd.gauss(0, 1), rnd.gauss(0, 1), abs(rnd.gauss(0, 1)) * 0.6)).normalized()
        shard(bm, d * 0.7, d, rnd.uniform(0.8, 1.3), rnd.uniform(0.18, 0.28), sides=5, tip=0.45)
    emit(bm, "Comet", "CometIce", (2, 0, 1.3))
    emit(ico(1.55, 3), "Comet", "CometAura", (2, 0, 1.3))

    # 5) 별빛 결정
    bm = ico(1.0, 2); lumpy(bm, 0.2, 1.5, 41); transformed(bm, scale=(1.1, 0.95, 0.4))
    emit(bm, "Crystal", "CrystalGlow", (6, 0, 0.3))
    bm = bmesh.new()
    shard(bm, (0, 0, 0.2), (0.05, 0.02, 1), 2.9, 0.38, sides=6, tip=0.3)
    for i in range(8):
        a = i * 2 * math.pi / 8 + rnd.uniform(-0.3, 0.3)
        tilt = rnd.uniform(0.35, 0.85)
        shard(bm, (math.cos(a) * 0.45, math.sin(a) * 0.4, 0.25), (math.cos(a) * tilt, math.sin(a) * tilt, 1),
              rnd.uniform(1.0, 2.1), rnd.uniform(0.16, 0.28), sides=6, tip=0.32)
    emit(bm, "Crystal", "CrystalShard", (6, 0, 0.35))

    # 6) 떨어진 별: 두툼한 별을 한 번 쪼개고 울퉁불퉁하게
    bm = bmesh.new()
    n, ro, ri, th, bulge = 5, 1.35, 0.72, 0.9, 0.55
    front, back = [], []
    for i in range(n * 2):
        a = i * math.pi / n + math.pi / 2
        r = ro if i % 2 == 0 else ri
        front.append(bm.verts.new((r * math.cos(a), -th / 2, r * math.sin(a))))
        back.append(bm.verts.new((r * math.cos(a), th / 2, r * math.sin(a))))
    fc = bm.verts.new((0, -th / 2 - bulge, 0)); bc = bm.verts.new((0, th / 2 + bulge, 0))
    for i in range(n * 2):
        j = (i + 1) % (n * 2)
        bm.faces.new((fc, front[j], front[i])); bm.faces.new((bc, back[i], back[j]))
        bm.faces.new((front[i], front[j], back[j], back[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=1, use_grid_fill=True)
    for v in bm.verts:
        v.co *= 1 + 0.07 * noise.noise(v.co * 2.3 + Vector((5, 1, 2)))
    transformed(bm, rot=(-12, 0, 10))
    emit(bm, "Star", "StarGold", (10, 0, 1.45))

def export():
    c = coll()
    bpy.ops.object.select_all(action='DESELECT')
    obs = [o for o in c.objects if o.type == 'MESH']
    for o in obs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = obs[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.context.scene.cursor.location = (0, 0, 0)
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    for o in obs:  # Roblox AI 텍스처가 무늬를 입힐 수 있게 UV 펼침
        bpy.ops.object.select_all(action='DESELECT'); o.select_set(True); bpy.context.view_layer.objects.active = o
        bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
        bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.02)
        bpy.ops.object.mode_set(mode='OBJECT')
    bpy.ops.object.select_all(action='DESELECT')
    for o in obs:
        o.select_set(True)
    path = os.path.join(os.path.expanduser("~"), "Downloads", "CollapseMine", "StarfallOres.fbx")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={'MESH'}, apply_unit_scale=True,
                             apply_scale_options='FBX_SCALE_ALL', axis_forward='-Z', axis_up='Y', mesh_smooth_type='FACE',
                             bake_space_transform=True)
    print("내보냄:", path)


if __name__ == "__main__":
    build()
    export()
