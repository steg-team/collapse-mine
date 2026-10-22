"""
허브 제작소(Workshop) 외형을 블렌더에서 만들고 FBX로 내보내는 스크립트.

실행: 블렌더 Scripting 탭에서 열어 실행하거나, MCP for Blender로 실행.
결과: ~/Downloads/CollapseMine/Workshop.fbx (Roblox용), HubBuildings.blend (원본 사본)

규칙
- 1 블렌더 단위 = 1 스터드. 바닥 중앙이 원점, 앞면은 -Y (Roblox로 가져오면 앞면이 -Z).
- 재질별로 오브젝트를 합쳐 이름을 WS_<재질>로 남긴다. Roblox에서 재질별 MeshPart 하나가 되고,
  tools/import_hub_mesh.luau가 이름을 보고 Roblox 재질·색을 입힌다.
- 한 MeshPart당 삼각형 2만 개를 넘지 않게 한다 (현재 최대 약 1만 3천).
- 기능 부품(계산대 Counter, 간판, 불·연기·조명)은 만들지 않는다. Roblox 파트로 유지한다.
"""
import bpy, bmesh, math, random, os
from mathutils import Vector, Euler

COL = "Workshop"
PREFIX = "WS"

MATS = {
    "Stone": (0.47, 0.45, 0.43), "StoneDark": (0.33, 0.31, 0.30), "Wood": (0.48, 0.33, 0.20),
    "WoodDark": (0.30, 0.20, 0.13), "Roof": (0.27, 0.23, 0.20), "Iron": (0.23, 0.23, 0.26),
    "Brick": (0.45, 0.25, 0.20), "Ember": (1.0, 0.45, 0.15), "Water": (0.24, 0.43, 0.59),
    "Copper": (0.77, 0.45, 0.24), "Gold": (0.94, 0.75, 0.24), "Gem": (0.35, 0.78, 0.86), "Steel": (0.66, 0.68, 0.72),
}


# ---------------------------------------------------------------- 도우미
def setup():
    old = bpy.data.collections.get(COL)
    if old:
        for o in list(old.objects):
            bpy.data.objects.remove(o, do_unlink=True)
        bpy.data.collections.remove(old)
    col = bpy.data.collections.new(COL)
    bpy.context.scene.collection.children.link(col)
    for name, c in MATS.items():
        m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
        m.diffuse_color = (*[v ** 2.2 for v in c], 1)


def _mesh_obj(name, bm, matname):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new(name, me)
    me.materials.append(bpy.data.materials[matname])
    bpy.data.collections[COL].objects.link(ob)
    return ob


def box(matname, size, loc, rot=(0, 0, 0), bevel=0.0, taper=None):
    """size=(x,y,z) 전체 크기, loc=중심, rot=도, taper=(tx,ty) 윗면 축소 비율"""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        if taper and v.co.z > 0:
            v.co.x *= taper[0]; v.co.y *= taper[1]
        v.co.x *= size[0]; v.co.y *= size[1]; v.co.z *= size[2]
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=1, affect='EDGES', profile=0.5)
    ob = _mesh_obj(matname, bm, matname)
    ob.location = loc
    ob.rotation_euler = Euler([math.radians(a) for a in rot])
    return ob


def cyl(matname, r, depth, loc, rot=(0, 0, 0), verts=10, r2=None, bevel=0.0):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=verts, radius1=r,
                          radius2=(r if r2 is None else r2), depth=depth)
    if bevel > 0:
        rim = [e for e in bm.edges if abs(e.verts[0].co.z - e.verts[1].co.z) < 1e-4]
        bmesh.ops.bevel(bm, geom=rim, offset=bevel, segments=1, affect='EDGES', profile=0.5)
    ob = _mesh_obj(matname, bm, matname)
    ob.location = loc
    ob.rotation_euler = Euler([math.radians(a) for a in rot])
    return ob


def torus(matname, R, r, loc, seg=16, mseg=4):
    bm = bmesh.new()
    rings = []
    for i in range(seg):
        a = 2 * math.pi * i / seg
        ring = []
        for j in range(mseg):
            b = 2 * math.pi * j / mseg
            ring.append(bm.verts.new(((R + r * math.cos(b)) * math.cos(a), (R + r * math.cos(b)) * math.sin(a), r * math.sin(b))))
        rings.append(ring)
    for i in range(seg):
        for j in range(mseg):
            bm.faces.new((rings[i][j], rings[(i + 1) % seg][j], rings[(i + 1) % seg][(j + 1) % mseg], rings[i][(j + 1) % mseg]))
    ob = _mesh_obj(matname, bm, matname)
    ob.location = loc
    return ob


def beam_between(matname, p1, p2, thick, bevel=0.06):
    p1, p2 = Vector(p1), Vector(p2)
    d = p2 - p1
    ob = box(matname, (thick, thick, d.length), (p1 + p2) / 2, bevel=bevel)
    ob.rotation_euler = d.to_track_quat('Z', 'Y').to_euler()
    return ob


# ---------------------------------------------------------------- 제작소
W, D = 28, 18


def build_structure():
    rnd = random.Random(7)
    # 판석 바닥
    for ix in range(14):
        for iy in range(9):
            h = 0.9 + rnd.uniform(-0.06, 0.08)
            box("Stone" if rnd.random() < 0.75 else "StoneDark", (1.92, 1.92, h), (-W / 2 + 1 + ix * 2, -D / 2 + 1 + iy * 2, h / 2), bevel=0.12)

    def stone_wall(a0, a1, fixed, z0, z1, thick, along):
        z, row = z0, 0
        while z < z1 - 0.01:
            hgt = min(1.25, z1 - z)
            pos = a0 - (0.6 if row % 2 else 0)
            while pos < a1 - 0.01:
                ln = rnd.uniform(1.6, 2.6)
                a, b = max(pos, a0), min(pos + ln, a1)
                if b - a > 0.3:
                    m = "Stone" if rnd.random() < 0.6 else "StoneDark"
                    depth = thick + rnd.uniform(-0.1, 0.12)
                    if along == "x":
                        box(m, (b - a - 0.08, depth, hgt - 0.08), ((a + b) / 2, fixed, z + hgt / 2), bevel=0.14)
                    else:
                        box(m, (depth, b - a - 0.08, hgt - 0.08), (fixed, (a + b) / 2, z + hgt / 2), bevel=0.14)
                pos += ln
            z += hgt; row += 1

    stone_wall(-W / 2, W / 2, D / 2 - 0.7, 0.9, 5.9, 1.4, "x")            # 뒷벽 아래 돌
    for sx in (-1, 1):
        stone_wall(-0.5, D / 2, sx * (W / 2 - 0.6), 0.9, 13.0, 1.2, "y")   # 옆벽 (앞쪽 절반은 열림)

    # 뒷벽 위 세로 판자
    x = -W / 2
    while x < W / 2 - 0.01:
        wdt = min(rnd.uniform(1.0, 1.4), W / 2 - x)
        box("WoodDark" if rnd.random() < 0.5 else "Wood", (wdt - 0.06, 0.6, 8.2), (x + wdt / 2, D / 2 - 0.7, 10.0), bevel=0.05)
        x += wdt
    box("WoodDark", (W + 0.4, 0.9, 0.6), (0, D / 2 - 0.7, 6.1), bevel=0.08)

    # 통나무 기둥, 보, 버팀대
    for sx in (-1, 1):
        cyl("WoodDark", 0.75, 14.2, (sx * (W / 2 - 0.6), -D / 2 + 0.6, 8.0), verts=8, bevel=0.08)
        cyl("WoodDark", 0.75, 14.2, (sx * (W / 2 - 0.6), D / 2 - 0.7, 8.0), verts=8, bevel=0.08)
        beam_between("Wood", (sx * (W / 2 - 0.6), -D / 2 + 0.6, 11.5), (sx * (W / 2 - 4.0), -D / 2 + 0.6, 14.6), 0.6)
        beam_between("Wood", (sx * (W / 2 - 0.6), -0.5, 13.0), (sx * (W / 2 - 0.6), -D / 2 + 0.6, 13.0), 0.8)
    box("WoodDark", (W + 1.2, 1.3, 1.3), (0, -D / 2 + 0.6, 15.0), bevel=0.12)
    box("WoodDark", (W + 1.2, 1.3, 1.3), (0, D / 2 - 0.7, 15.0), bevel=0.12)


def build_roof():
    rnd = random.Random(11)
    pitch = math.radians(30)
    eave_z, half = 15.7, D / 2 + 1.6
    rise = math.tan(pitch) * half
    slope = half / math.cos(pitch)
    roof_w = W + 3.0
    for s in (-1, 1):
        box("WoodDark", (roof_w, slope + 0.3, 0.35), (0, s * half / 2, eave_z + rise / 2), rot=(-s * math.degrees(pitch), 0, 0), bevel=0.05)
    rows = 9
    for s in (-1, 1):
        for r in range(rows):
            t = (r + 0.5) / rows
            y, z = s * half * (1 - t), eave_z + rise * t + 0.35
            x = -roof_w / 2 + (0.0 if r % 2 == 0 else 0.8)
            while x < roof_w / 2 - 0.2:
                w = min(1.6, roof_w / 2 - x)
                if w > 0.4:
                    box("Roof" if rnd.random() < 0.8 else "StoneDark", (w - 0.1, slope / rows + 0.5, 0.32), (x + w / 2, y, z),
                        rot=(-s * math.degrees(pitch) + rnd.uniform(-2, 2), rnd.uniform(-1.5, 1.5), 0), bevel=0.06)
                x += 1.6
    cyl("WoodDark", 0.55, roof_w + 0.6, (0, 0, eave_z + rise + 0.5), rot=(0, 90, 0), verts=8)
    # 박공 벽
    for sx in (-1, 1):
        y = -D / 2 + 0.6
        while y < D / 2 - 0.7:
            yc = y + 0.55
            h = eave_z + rise * (1 - abs(yc) / half) - 0.2 - 13.0
            if h > 0.3:
                box("Wood", (0.5, 1.04, h), (sx * (W / 2 - 0.6), yc, 13.0 + h / 2), bevel=0.04)
            y += 1.1


def build_props():
    rnd = random.Random(23)
    # 굴뚝 (엇갈린 벽돌)
    cx, cy, s = -9.0, 6.4, 4.0
    z, row = 0.9, 0
    while z < 27.0:
        h, off = 0.7, (0.5 if row % 2 else 0.0)
        for side in range(4):
            for k in range(2):
                ln = s / 2
                along = -s / 2 + off + k * ln + ln / 2
                if along > s / 2: along -= s
                m = "Brick" if rnd.random() < 0.85 else "StoneDark"
                j = rnd.uniform(-0.04, 0.06)
                if side == 0: box(m, (ln - 0.08, 0.7 + j, h - 0.08), (cx + along, cy - s / 2 + 0.35, z + h / 2), bevel=0.07)
                if side == 1: box(m, (ln - 0.08, 0.7 + j, h - 0.08), (cx + along, cy + s / 2 - 0.35, z + h / 2), bevel=0.07)
                if side == 2: box(m, (0.7 + j, ln - 0.08, h - 0.08), (cx - s / 2 + 0.35, cy + along, z + h / 2), bevel=0.07)
                if side == 3: box(m, (0.7 + j, ln - 0.08, h - 0.08), (cx + s / 2 - 0.35, cy + along, z + h / 2), bevel=0.07)
        z += h; row += 1
    box("StoneDark", (s + 0.9, s + 0.9, 0.7), (cx, cy, z + 0.35), bevel=0.12)
    box("StoneDark", (s + 0.5, s + 0.5, 0.5), (cx, cy, z - 3.0), bevel=0.1)

    # 화덕 + 후드 + 풀무
    fx, fy = -8.5, 4.6
    box("Stone", (7.2, 5.0, 3.4), (fx, fy, 2.6), bevel=0.2)
    box("StoneDark", (6.4, 0.5, 0.5), (fx, fy - 2.55, 4.4), bevel=0.08)
    box("Ember", (5.0, 3.4, 0.4), (fx, fy - 0.1, 4.45))
    for k in range(5):
        box("StoneDark", (1.0, 1.0, 0.6), (fx - 2 + k, fy - 0.3 + rnd.uniform(-1, 1), 4.8), rot=(0, 0, rnd.uniform(0, 90)), bevel=0.15)
    box("Brick", (6.6, 4.6, 3.8), (fx, fy + 0.2, 7.2), taper=(0.55, 0.65), bevel=0.15)
    box("WoodDark", (2.6, 1.4, 0.25), (fx + 4.6, fy - 1.0, 3.2), bevel=0.05)
    box("WoodDark", (2.6, 1.4, 0.25), (fx + 4.6, fy - 1.0, 4.2), rot=(0, -8, 0), bevel=0.05)
    box("Roof", (2.2, 1.2, 0.9), (fx + 4.6, fy - 1.0, 3.7), taper=(0.8, 1.0), bevel=0.2)

    # 모루 + 망치
    ax, ay = 1.0, -1.0
    cyl("WoodDark", 1.15, 2.4, (ax, ay, 2.1), verts=10, bevel=0.1)
    box("Iron", (2.2, 1.6, 0.5), (ax, ay, 3.35), taper=(0.7, 0.75), bevel=0.08)
    box("Iron", (1.3, 0.95, 1.1), (ax, ay, 4.1), taper=(1.35, 1.35), bevel=0.06)
    box("Iron", (3.3, 1.5, 0.75), (ax + 0.2, ay, 5.0), bevel=0.1)
    cyl("Iron", 0.55, 1.9, (ax - 2.25, ay, 5.08), rot=(0, 90, 0), r2=0.04, verts=10)
    cyl("Wood", 0.13, 2.0, (ax + 0.9, ay - 0.7, 5.5), rot=(0, 85, 25), verts=6)
    box("Iron", (0.55, 0.55, 0.9), (ax + 1.8, ay - 0.25, 5.5), rot=(0, 0, 25), bevel=0.06)

    # 물통
    tx, ty = -3.4, 1.4
    cyl("Wood", 1.4, 2.4, (tx, ty, 2.1), r2=1.55, verts=14, bevel=0.06)
    for zz in (1.5, 2.9):
        torus("Iron", 1.46 + (zz - 1.5) * 0.06, 0.08, (tx, ty, zz), seg=18)
    cyl("Water", 1.4, 0.1, (tx, ty, 3.0), verts=14)

    # 곡괭이 걸이 (등급별 머리)
    wall_y = D / 2 - 1.15
    box("WoodDark", (13.0, 0.4, 0.8), (5.0, wall_y + 0.1, 11.6), bevel=0.06)
    for i, hm in enumerate(["StoneDark", "Copper", "Steel", "Gold", "Gem"]):
        x = 0.4 + i * 2.5
        cyl("Wood", 0.16, 4.6, (x, wall_y - 0.3, 9.4), verts=6)
        cyl("WoodDark", 0.2, 0.7, (x, wall_y - 0.3, 7.6), verts=6)
        box(hm, (0.6, 0.6, 0.6), (x, wall_y - 0.3, 11.75), bevel=0.08)
        for s2 in (-1, 1):
            cyl(hm, 0.26, 1.4, (x + s2 * 0.95, wall_y - 0.3, 11.55), rot=(0, s2 * 75, 0), r2=0.03, verts=6)

    # 숫돌
    gx, gy = 9.5, 3.5
    for s2 in (-1, 1):
        beam_between("Wood", (gx + s2 * 0.6, gy - 1.3, 0.9), (gx + s2 * 0.6, gy, 3.1), 0.3)
        beam_between("Wood", (gx + s2 * 0.6, gy + 1.3, 0.9), (gx + s2 * 0.6, gy, 3.1), 0.3)
    cyl("Stone", 1.3, 0.5, (gx, gy, 3.3), rot=(0, 90, 0), verts=16, bevel=0.06)
    cyl("Iron", 0.1, 1.8, (gx, gy, 3.3), rot=(0, 90, 0), verts=6)

    # 술통, 상자, 광석 더미
    for bx, by in [(11.2, 6.8), (8.9, 7.0)]:
        cyl("Wood", 1.0, 2.6, (bx, by, 2.2), verts=12, r2=0.9, bevel=0.05)
        for zz in (1.5, 2.9):
            torus("Iron", 1.0 - (zz - 1.5) * 0.06, 0.07, (bx, by, zz))
    for bx, by, sz, rz in [(11.0, 3.6, 1.8, 10), (11.3, 3.7, 1.3, -15)]:
        z0 = 0.9 if sz > 1.5 else 2.7
        box("Wood", (sz, sz, sz), (bx, by, z0 + sz / 2), rot=(0, 0, rz), bevel=0.08)
        box("WoodDark", (sz + 0.06, sz + 0.06, 0.2), (bx, by, z0 + sz * 0.8), rot=(0, 0, rz))
    rnd2 = random.Random(31)
    for k in range(6):
        box("Iron" if k % 2 else "Copper", (0.8, 0.7, 0.6), (5.0 + rnd2.uniform(-1.5, 1.5), 6.0 + rnd2.uniform(-0.8, 0.8), 1.2),
            rot=(rnd2.uniform(0, 40), rnd2.uniform(0, 40), rnd2.uniform(0, 90)), bevel=0.15)


# ---------------------------------------------------------------- 합치기·내보내기
def join_and_export():
    col = bpy.data.collections[COL]
    groups = {}
    for ob in list(col.objects):
        groups.setdefault(ob.data.materials[0].name, []).append(ob)
    for mname, obs in groups.items():
        bpy.ops.object.select_all(action='DESELECT')
        for o in obs: o.select_set(True)
        bpy.context.view_layer.objects.active = obs[0]
        if len(obs) > 1: bpy.ops.object.join()
        j = bpy.context.view_layer.objects.active
        j.name = j.data.name = f"{PREFIX}_{mname}"
    bpy.ops.object.select_all(action='DESELECT')
    for ob in col.objects: ob.select_set(True)
    bpy.context.view_layer.objects.active = col.objects[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.context.scene.cursor.location = (0, 0, 0)
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    for ob in col.objects:
        tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
        assert tris < 20000, f"{ob.name} 삼각형 {tris}개 — Roblox 한도 초과"
    out_dir = os.path.join(os.path.expanduser("~"), "Downloads", "CollapseMine")
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, "Workshop.fbx")
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={'MESH'},
                             apply_unit_scale=True, apply_scale_options='FBX_SCALE_ALL', axis_forward='-Z', axis_up='Y',
                             mesh_smooth_type='FACE', bake_space_transform=True)
    print("내보냄:", path)


if __name__ == "__main__":
    setup()
    build_structure()
    build_roof()
    build_props()
    join_and_export()
