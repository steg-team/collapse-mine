"""
블렌더 → Roblox 허브 건물용 공통 도우미.

규칙 (tools/blender/build_*.py 공통)
- 1 블렌더 단위 = 1 스터드, 바닥 중앙이 원점, 건물 앞면은 -Y.
- Roblox로 가져오면 Roblox 로컬 좌표 = (-X, Z, Y). 좌우가 바뀌니 좌우 대칭이 아닌 배치는 주의.
- 오브젝트는 재질별로 합쳐 <접두사>_<재질> 이름으로 내보낸다. Roblox 쪽 tools/import_hub_mesh.luau가 이름을 보고 재질을 입힌다.
"""
import bpy, bmesh, math, os
from mathutils import Vector, Euler

STATE = {"col": None}

PALETTE = {
    "Stone": (0.47, 0.45, 0.43), "StoneDark": (0.33, 0.31, 0.30), "StoneLight": (0.62, 0.60, 0.56),
    "Wood": (0.48, 0.33, 0.20), "WoodDark": (0.30, 0.20, 0.13), "Roof": (0.27, 0.23, 0.20),
    "RoofRed": (0.55, 0.22, 0.17), "ClothRed": (0.72, 0.20, 0.18), "ClothCream": (0.92, 0.88, 0.78),
    "ClothBlue": (0.20, 0.30, 0.58), "ClothGreen": (0.20, 0.45, 0.25), "ClothPurple": (0.40, 0.22, 0.55),
    "Iron": (0.23, 0.23, 0.26), "Gold": (0.94, 0.75, 0.24), "Copper": (0.77, 0.45, 0.24),
    "Coal": (0.12, 0.12, 0.13), "Gem": (0.35, 0.85, 0.95), "Amethyst": (0.70, 0.40, 0.95),
    "Ember": (1.0, 0.45, 0.15), "Glass": (1.0, 0.82, 0.50), "Brick": (0.45, 0.25, 0.20), "Water": (0.24, 0.43, 0.59),
}


def setup(colname):
    old = bpy.data.collections.get(colname)
    if old:
        for o in list(old.objects):
            bpy.data.objects.remove(o, do_unlink=True)
        bpy.data.collections.remove(old)
    col = bpy.data.collections.new(colname)
    bpy.context.scene.collection.children.link(col)
    STATE["col"] = col
    for name, c in PALETTE.items():
        m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
        m.diffuse_color = (*[v ** 2.2 for v in c], 1)
    return col


def _obj(bm, matname):
    me = bpy.data.meshes.new(matname)
    bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new(matname, me)
    me.materials.append(bpy.data.materials[matname])
    STATE["col"].objects.link(ob)
    return ob


def _place(ob, loc, rot):
    ob.location = loc
    ob.rotation_euler = Euler([math.radians(a) for a in rot])
    return ob


def box(m, size, loc, rot=(0, 0, 0), bevel=0.0, taper=None):
    """size=(x,y,z), loc=중심, rot=도, taper=(tx,ty) 윗면 축소"""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        if taper and v.co.z > 0:
            v.co.x *= taper[0]; v.co.y *= taper[1]
        v.co.x *= size[0]; v.co.y *= size[1]; v.co.z *= size[2]
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=1, affect='EDGES', profile=0.5)
    return _place(_obj(bm, m), loc, rot)


def cyl(m, r, depth, loc, rot=(0, 0, 0), verts=10, r2=None, bevel=0.0):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=verts, radius1=r,
                          radius2=(r if r2 is None else r2), depth=depth)
    if bevel > 0:
        rim = [e for e in bm.edges if abs(e.verts[0].co.z - e.verts[1].co.z) < 1e-4]
        bmesh.ops.bevel(bm, geom=rim, offset=bevel, segments=1, affect='EDGES', profile=0.5)
    return _place(_obj(bm, m), loc, rot)


def torus(m, R, r, loc, rot=(0, 0, 0), seg=16, mseg=5):
    bm = bmesh.new()
    rings = []
    for i in range(seg):
        a = 2 * math.pi * i / seg
        rings.append([bm.verts.new(((R + r * math.cos(b)) * math.cos(a), (R + r * math.cos(b)) * math.sin(a), r * math.sin(b)))
                      for b in [2 * math.pi * j / mseg for j in range(mseg)]])
    for i in range(seg):
        for j in range(mseg):
            bm.faces.new((rings[i][j], rings[(i + 1) % seg][j], rings[(i + 1) % seg][(j + 1) % mseg], rings[i][(j + 1) % mseg]))
    return _place(_obj(bm, m), loc, rot)


def lathe(m, profile, loc, rot=(0, 0, 0), seg=16):
    """profile=[(반지름, 높이), ...] 아래→위. 회전체 (트로피 컵, 꽃병 등)"""
    bm = bmesh.new()
    rings = []
    for r, z in profile:
        rings.append([bm.verts.new((max(r, 0.001) * math.cos(2 * math.pi * i / seg), max(r, 0.001) * math.sin(2 * math.pi * i / seg), z)) for i in range(seg)])
    for k in range(len(rings) - 1):
        for i in range(seg):
            bm.faces.new((rings[k][i], rings[k][(i + 1) % seg], rings[k + 1][(i + 1) % seg], rings[k + 1][i]))
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])
    return _place(_obj(bm, m), loc, rot)


def prism(m, pts, thick, loc, rot=(0, 0, 0)):
    """XZ 평면의 다각형 pts=[(x,z),...]을 Y로 thick만큼 두께 (깃발, 박공 삼각형 등)"""
    bm = bmesh.new()
    front = [bm.verts.new((x, -thick / 2, z)) for x, z in pts]
    back = [bm.verts.new((x, thick / 2, z)) for x, z in pts]
    bm.faces.new(front)
    bm.faces.new(list(reversed(back)))
    n = len(pts)
    for i in range(n):
        bm.faces.new((front[i], back[i], back[(i + 1) % n], front[(i + 1) % n]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _place(_obj(bm, m), loc, rot)


def beam(m, p1, p2, thick, bevel=0.06):
    p1, p2 = Vector(p1), Vector(p2)
    d = p2 - p1
    ob = box(m, (thick, thick, d.length), (p1 + p2) / 2, bevel=bevel)
    ob.rotation_euler = d.to_track_quat('Z', 'Y').to_euler()
    return ob


def crystal_cluster(m, loc, rnd, n=5, scale=1.0):
    """빛나는 수정 다발: 끝이 뾰족한 육각 기둥을 사방으로 기울여 꽂음"""
    for i in range(n):
        h = scale * rnd.uniform(1.2, 2.6)
        r = scale * rnd.uniform(0.22, 0.4)
        tilt = 0 if i == 0 else rnd.uniform(15, 40)
        yaw = rnd.uniform(0, 360)
        ob = cyl(m, r, h, (0, 0, 0), verts=6, r2=r * 0.15)
        d = Vector((0, 0, h / 2))
        e = Euler((math.radians(tilt), 0, math.radians(yaw)))
        d.rotate(e)
        ob.location = Vector(loc) + d
        ob.rotation_euler = e


def lantern(loc, frame="Iron", glass="Glass"):
    """매다는 등불: 쇠 틀 + 유리 + 고리. Roblox에서 같은 자리에 PointLight를 둔다"""
    x, y, z = loc
    box(glass, (0.7, 0.7, 0.9), (x, y, z), bevel=0.05)
    box(frame, (1.0, 1.0, 0.18), (x, y, z - 0.52), bevel=0.04)
    box(frame, (1.0, 1.0, 0.18), (x, y, z + 0.52), taper=(0.5, 0.5))
    for sx in (-1, 1):
        for sy in (-1, 1):
            box(frame, (0.1, 0.1, 0.9), (x + sx * 0.42, y + sy * 0.42, z))
    torus(frame, 0.18, 0.05, (x, y, z + 0.85), rot=(90, 0, 0), seg=10, mseg=4)


def join_and_export(prefix, filename):
    col = STATE["col"]
    groups = {}
    for ob in list(col.objects):
        groups.setdefault(ob.data.materials[0].name, []).append(ob)
    for mname, obs in groups.items():
        bpy.ops.object.select_all(action='DESELECT')
        for o in obs:
            o.select_set(True)
        bpy.context.view_layer.objects.active = obs[0]
        if len(obs) > 1:
            bpy.ops.object.join()
        j = bpy.context.view_layer.objects.active
        j.name = j.data.name = f"{prefix}_{mname}"
    bpy.ops.object.select_all(action='DESELECT')
    for ob in col.objects:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = col.objects[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.context.scene.cursor.location = (0, 0, 0)
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    report = []
    for ob in col.objects:
        tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
        assert tris < 20000, f"{ob.name} 삼각형 {tris}개 — Roblox 한도 초과"
        report.append(f"{ob.name}:{tris}")
    out_dir = os.path.join(os.path.expanduser("~"), "Downloads", "CollapseMine")
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, filename)
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={'MESH'},
                             apply_unit_scale=True, apply_scale_options='FBX_SCALE_ALL', axis_forward='-Z', axis_up='Y',
                             mesh_smooth_type='FACE', bake_space_transform=True)
    print("내보냄:", path, "|", ", ".join(report))
    return path
