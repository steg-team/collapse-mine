"""
광산 카나리아(어깨 위 펫 새, D-023, D-045) — 블렌더에서 실행하면 ~/Downloads/CollapseMine/Canary.fbx 로 내보낸다.
화면 없이: /Applications/Blender.app/Contents/MacOS/Blender -b --python tools/blender/build_canary.py
(삼각형 6천 개 남짓, GPU 없는 노트북에서도 몇 초)

1 블렌더 단위 = 1 스터드, 발 밑 가운데가 원점, 앞(부리)은 -Y. 키 약 0.8스터드 (R15 어깨에 앉는 크기).

레벨마다 장비가 하나씩 붙는다 (펫 기능과 한 짝, D-045)
  Lv1 기본 새 (희귀 광맥 감지·붕괴 경보)
  Lv2 광부 헬멧 + 램프 (헤드랜턴 보조)
  Lv3 목도리 (출구 길 안내 — 붕괴 때 앞장서는 안내원)
  Lv4 가슴 보석 (광물을 상위 등급으로 바꾸기)
  Lv5 황금 꼬리깃·볏 (갇힐 때 가방 지켜 주기, 신화 "카나리아의 황금 깃털")
레벨마다 한 덩어리로 합쳐 손그림처럼 칠한 텍스처(512px)를 입혀 Canary_L<레벨>_Paint 로 나간다 (FBX에 텍스처 포함,
~/Downloads/CollapseMine/Canary_L<n>_Tex.png 도 같이 저장). 빛나는 램프·보석만 Canary_L<n>_Lamp/_Gem (Roblox Neon).
Roblox 쪽 tools/import_canary.luau가 이름으로 색·재질을 입히고, 서버가 카나리아 레벨보다 높은 L 장비는 숨긴다.
"""
import bpy, bmesh, math, sys, os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
try:
    from rbx_common import *  # noqa
    from rbx_common import _obj, _place  # 아래 도우미가 쓰는 내부 함수 (import * 에 안 딸려 옴)
except ImportError:
    pass  # MCP로 실행할 때는 rbx_common 내용을 앞에 붙여서 보낸다

# 새 전용 색 (rbx_common PALETTE에 더해서 setup이 재질을 만든다)
PALETTE.update({
    "Feather": (1.0, 0.82, 0.22), "FeatherDark": (0.95, 0.66, 0.12), "Belly": (1.0, 0.93, 0.62),
    "Beak": (1.0, 0.52, 0.10),
    "Helmet": (0.80, 0.16, 0.12), "Lamp": (1.0, 0.95, 0.70), "Scarf": (0.20, 0.40, 0.85),
    "GoldFeather": (1.0, 0.58, 0.04),  # 몸통 노랑과 구분되게 진한 주황빛 금 (Roblox Metal)
})

LEVEL = {"n": 1}  # 지금 만드는 부품이 붙는 레벨 (build 안에서 바꿈)


def tag(ob):
    ob["lv"] = LEVEL["n"]
    for p in ob.data.polygons:
        p.use_smooth = True  # 면이 각져 보이지 않게 (작은 펫은 매끈해야 귀엽다)
    return ob


def ball(m, r, loc, scale=(1, 1, 1), rot=(0, 0, 0), seg=14, top_only=False, taper=0.0):
    """타원체: 반지름 r 공을 scale배로 늘림. top_only면 윗반구만 (헬멧). taper면 +Y 끝으로 갈수록 가늘게 (날개·꼬리 깃)"""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=max(8, seg * 2 // 3), radius=r)
    if top_only:
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < -1e-4], context='VERTS')
    for v in bm.verts:
        k = 1 - taper * max(v.co.y / r, 0)
        v.co.x *= scale[0] * k; v.co.y *= scale[1]; v.co.z *= scale[2] * (0.5 + 0.5 * k)
    return tag(_place(_obj(bm, m), loc, rot))


def part(fn, *a, **k):
    return tag(fn(*a, **k))


def blob(obs, voxel=0.012, target=900):
    """여러 덩어리를 이음새 없는 한 덩어리로: 합치고 → 복셀로 다시 짜고 → 다듬고 → 삼각형 수 줄이기 (A의 광물 턴어라운드와 같은 방법)"""
    bpy.ops.object.select_all(action='DESELECT')
    for o in obs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = obs[0]
    bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    for name, kind, setup_ in (("rm", 'REMESH', lambda m: (setattr(m, "mode", 'VOXEL'), setattr(m, "voxel_size", voxel))),
                               ("sm", 'SMOOTH', lambda m: (setattr(m, "factor", 0.6), setattr(m, "iterations", 6)))):
        md = ob.modifiers.new(name, kind); setup_(md)
        bpy.ops.object.modifier_apply(modifier=md.name)
    n = len(ob.data.polygons)
    if n > target:
        md = ob.modifiers.new("dc", 'DECIMATE'); md.ratio = target / n
        bpy.ops.object.modifier_apply(modifier=md.name)
    return tag(ob)


def build():
    setup("Canary")
    # Lv1 기본 새. 카나리아는 원래 병아리를 닮았으니 빵빵하지 않게(몸통·머리 폭을 줄임): 앞이 들린 서양배 몸통(앉은 자세), 길게 접힌 날개와 긴 꼬리,
    # 머리 깃 없음, 작은 살구색 부리, 레몬 노랑. 귀여움은 큰 머리와 그린 눈(텍스처)으로
    LEVEL["n"] = 1
    body = ball("Feather", 0.22, (0, 0.07, 0.24), scale=(0.78, 1.42, 0.8), rot=(-22, 0, 0), seg=24)
    head = ball("Feather", 0.2, (0, -0.16, 0.53), scale=(0.95, 1, 1), seg=24)
    blob([body, head])
    part(cyl, "Beak", 0.042, 0.1, (0, -0.38, 0.5), rot=(95, 0, 0), verts=16, r2=0.0)
    for sx in (-1, 1):
        ball("FeatherDark", 0.16, (sx * 0.175, 0.17, 0.28), scale=(0.18, 1.75, 0.68), rot=(-24, sx * 5, 0), taper=0.75)
        ball("FeatherDark", 0.12, (sx * 0.03, 0.48, 0.13), scale=(0.45, 2.0, 0.14), rot=(-28, sx * 6, 0), taper=0.4)
        part(cyl, "Beak", 0.022, 0.08, (sx * 0.06, -0.01, 0.04), verts=10)

    # Lv2 광부 헬멧 + 램프: 머리 위 반구, 챙, 앞 램프(Roblox Neon + PointLight 자리).
    # 챙이 눈 위(눈 꼭대기 0.59)에 오도록 높게 얹는다. 눈을 가리면 화나 보인다
    LEVEL["n"] = 2
    ball("Helmet", 0.21, (0, -0.16, 0.64), scale=(1, 1, 0.7), seg=24, top_only=True)
    part(cyl, "Helmet", 0.235, 0.022, (0, -0.16, 0.64), verts=28)
    part(cyl, "Iron", 0.046, 0.05, (0, -0.36, 0.72), rot=(100, 0, 0), verts=16)
    part(cyl, "Lamp", 0.035, 0.02, (0, -0.39, 0.725), rot=(100, 0, 0), verts=16)

    # Lv3 목도리: 목에 두른 고리 + 옆으로 늘어진 끝
    LEVEL["n"] = 3
    part(torus, "Scarf", 0.155, 0.04, (0, -0.12, 0.38), rot=(14, 0, 0), seg=24, mseg=8)
    part(box, "Scarf", (0.08, 0.035, 0.18), (0.14, -0.05, 0.28), rot=(10, 0, -20), bevel=0.012)

    # Lv4 가슴 보석: 위아래로 뾰족한 팔면체 (Roblox Neon)
    LEVEL["n"] = 4
    for s in (1, -1):
        part(cyl, "Gem", 0.045, 0.055, (0, -0.27, 0.31 + s * 0.028), rot=(0 if s > 0 else 180, 0, 0), verts=4, r2=0.0)

    # Lv5 황금 깃털: 날개 덮개(조금 크게 겹침), 긴 꼬리 부채 5장, 헬멧 위 볏 3개
    LEVEL["n"] = 5
    for sx in (-1, 1):
        ball("GoldFeather", 0.16, (sx * 0.182, 0.18, 0.29), scale=(0.2, 1.8, 0.72), rot=(-24, sx * 5, 0), taper=0.75)
    for yaw in (-30, -15, 0, 15, 30):
        r = math.radians(yaw)
        ball("GoldFeather", 0.12, (math.sin(r) * 0.12, 0.5 + math.cos(r) * 0.03, 0.15), scale=(0.35, 1.9, 0.15), rot=(-28, 0, yaw))
    for dx in (-0.055, 0, 0.055):
        part(cyl, "GoldFeather", 0.03, 0.12, (dx, -0.12, 0.82 + (0.02 if dx == 0 else 0)), rot=(-20, dx * 200, 0), verts=10, r2=0.0)
    return join_and_export_levels("Canary", "Canary.fbx")


# ---------- 그림 텍스처: 표면 위치·방향으로 색을 계산해 이미지에 칠한다 ----------
# 레벨마다 한 덩어리(Neon으로 빛나야 하는 램프·보석만 따로)로 합치고, UV를 펴고, UV 공간에서 삼각형을 그려
# 칸마다 3D 위치·법선·원래 재질을 알아낸 뒤 손그림처럼 칠한다 (깃털 비늘, 배·볼, 눈 반짝임, 헬멧 광택, 목도리 뜨개 줄).
# 조명은 아주 약하게만 굽는다 (Roblox가 다시 비추므로 두 번 어두워지지 않게).
import numpy as np

TEX = 512
GLOW = {"Lamp", "Gem"}  # Neon 재질로 따로 내보내는 것 (텍스처 없음)
LIGHT = np.array([-0.35, -0.55, 0.76]); LIGHT /= np.linalg.norm(LIGHT)


def _rgb(*c):
    return np.array(c, np.float32)


def _smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def _mix(a, b, t):
    return a + (b - a) * t[..., None]


def _hash(p):
    """3D 위치 → 0~1 얼룩 (흠집·깃털 결 흔들림용)"""
    return np.modf(np.sin(p @ np.array([12.9898, 78.233, 37.719])) * 43758.5453)[0] % 1.0


def shade(mat, P, N):
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    lit = 0.86 + 0.14 * _smooth(-0.2, 0.6, N @ LIGHT)
    if mat in ("Feather", "Belly"):
        c = _mix(_rgb(0.98, 0.8, 0.16), _rgb(1.0, 0.93, 0.34), _smooth(0.05, 0.7, z))  # 레몬 노랑
        # 깃털 비늘: 뒤·옆에서 위로 겹친 반원 줄 (앞 배 쪽은 매끈)
        ang = np.arctan2(x, y + 0.1)
        row = np.modf(z * 18 + 0.25 * np.cos(ang * 9))[0]
        scale = _smooth(0.78, 0.98, row) * _smooth(-0.1, 0.3, y + 0.15)
        c = c * (1 - 0.12 * scale[:, None])
        # 배: 앞쪽 아래 크림색 타원 (가장자리 부드럽게)
        e = (x / 0.13) ** 2 + ((z - 0.25) / 0.16) ** 2
        belly = (1 - _smooth(0.7, 1.05, e)) * _smooth(0.0, -0.25, y + 0.05)
        c = _mix(c, _rgb(1.0, 0.97, 0.62), 0.7 * belly)
        # 볼 홍조
        for sx in (-1, 1):
            d = np.linalg.norm(P - np.array([sx * 0.135, -0.28, 0.48]), axis=1)
            c = _mix(c, _rgb(1.0, 0.56, 0.52), 0.75 * (1 - _smooth(0.02, 0.05, d)))
        # 눈: 얼굴에 그린 납작한 세로 타원 + 큰 반짝임·작은 반짝임 (튀어나온 구슬 눈은 무섭게 보여서 그림으로)
        front = _smooth(-0.22, -0.3, y)
        for sx in (-1, 1):
            ex, ez = x - sx * 0.09, z - 0.545
            eye = (1 - _smooth(0.85, 1.0, (ex / 0.034) ** 2 + (ez / 0.046) ** 2)) * front
            c = _mix(c, _rgb(0.16, 0.1, 0.08), eye)
            hi = (1 - _smooth(0.6, 1.0, ((ex - sx * 0.008) / 0.013) ** 2 + ((ez - 0.014) / 0.013) ** 2)) * front
            lo = (1 - _smooth(0.6, 1.0, ((ex + sx * 0.01) / 0.006) ** 2 + ((ez + 0.018) / 0.006) ** 2)) * front
            c = _mix(c, _rgb(1, 1, 1), np.maximum(hi, lo) * eye)
    elif mat in ("FeatherDark",):
        c = _mix(_rgb(0.95, 0.74, 0.12), _rgb(1.0, 0.9, 0.3), _smooth(0.1, 0.4, z))
        # 긴 깃털 결: 날개 길이 방향으로 비스듬한 가는 줄 (고리 무늬는 애벌레처럼 보여서 피함)
        line = np.modf(z * 28 - y * 9 + 100)[0]
        c = c * (1 - 0.13 * _smooth(0.86, 0.98, line)[:, None])
        c = _mix(c, _rgb(0.82, 0.6, 0.1), _smooth(0.35, 0.7, y))  # 날개·꼬리 끝은 조금 진하게
    elif mat == "Beak":
        c = _mix(_rgb(0.93, 0.6, 0.42), _rgb(1.0, 0.8, 0.62), _smooth(0.45, 0.56, z))  # 카나리아 부리·발은 살구빛
    elif mat == "Helmet":
        c = _mix(_rgb(0.6, 0.08, 0.06), _rgb(0.9, 0.2, 0.14), _smooth(0.66, 0.84, z))
        spec = _smooth(0.86, 0.97, N @ LIGHT)  # 칠한 광택
        c = _mix(c, _rgb(1.0, 0.75, 0.7), 0.7 * spec)
        scuff = (_hash(np.floor(P * 90)) > 0.985).astype(np.float32)  # 드문드문 작은 흠집
        c = c * (1 - 0.12 * scuff[:, None])
        c = _mix(c, _rgb(0.95, 0.85, 0.3), _smooth(0.004, 0.0, np.abs(z - 0.71)) )  # 챙 위 노란 띠
    elif mat == "Iron":
        c = _mix(_rgb(0.2, 0.2, 0.23), _rgb(0.55, 0.55, 0.6), _smooth(0.4, 0.95, N @ LIGHT))
    elif mat == "Scarf":
        ang = np.arctan2(x, y + 0.1)
        knit = np.abs(np.modf(ang * 6 + 100)[0] - 0.5) * 2
        c = _mix(_rgb(0.16, 0.32, 0.78), _rgb(0.3, 0.5, 0.95), knit)
        c = _mix(c, _rgb(0.95, 0.95, 0.98), _smooth(0.92, 0.97, np.modf(z * 25 + 100)[0]) * 0.6)
    elif mat == "GoldFeather":
        c = _mix(_rgb(0.78, 0.3, 0.0), _rgb(1.0, 0.78, 0.12), _smooth(0.1, 0.9, (N @ LIGHT + 1) / 2))
        line = np.modf(z * 28 - y * 9 + 100)[0]
        c = c * (1 - 0.15 * _smooth(0.86, 0.98, line)[:, None])
        c = _mix(c, _rgb(1, 0.97, 0.75), 0.8 * _smooth(0.9, 0.99, N @ LIGHT))
    else:
        c = np.tile(_rgb(0.8, 0.8, 0.8), (len(P), 1))
    return np.clip(c * lit[:, None], 0, 1)


def paint(ob, name):
    """ob을 UV 펴고 칠한 텍스처 하나를 입힌다"""
    bpy.ops.object.select_all(action='DESELECT')
    ob.select_set(True); bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.02)
    bpy.ops.object.mode_set(mode='OBJECT')
    me = ob.data; me.calc_loop_triangles()
    uvl = me.uv_layers.active.data
    mats = [m.name for m in me.materials]
    col = np.zeros((TEX, TEX, 3), np.float32); filled = np.zeros((TEX, TEX), bool)
    cn = me.corner_normals
    by_mat = {}
    for t in me.loop_triangles:
        by_mat.setdefault(t.material_index, []).append(t)
    for mi, tris in by_mat.items():
        Ps, Ns, idx = [], [], []
        for t in tris:
            uv = np.array([uvl[l].uv for l in t.loops]) * TEX
            P = np.array([me.vertices[v].co for v in t.vertices]); N = np.array([cn[l].vector for l in t.loops])
            x0, y0 = np.floor(uv.min(0)).astype(int); x1, y1 = np.ceil(uv.max(0)).astype(int)
            xs, ys = np.meshgrid(np.arange(max(x0, 0), min(x1 + 1, TEX)), np.arange(max(y0, 0), min(y1 + 1, TEX)))
            px = np.stack([xs.ravel() + 0.5, ys.ravel() + 0.5], 1)
            a, b, c = uv
            den = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
            if abs(den) < 1e-12:
                continue
            w0 = ((b[1] - c[1]) * (px[:, 0] - c[0]) + (c[0] - b[0]) * (px[:, 1] - c[1])) / den
            w1 = ((c[1] - a[1]) * (px[:, 0] - c[0]) + (a[0] - c[0]) * (px[:, 1] - c[1])) / den
            w = np.stack([w0, w1, 1 - w0 - w1], 1)
            inside = (w >= -0.02).all(1)
            if not inside.any():
                continue
            w = w[inside]; q = px[inside].astype(int)
            Ps.append(w @ P); n = w @ N; Ns.append(n / np.linalg.norm(n, axis=1, keepdims=True)); idx.append(q)
        if not Ps:
            continue
        q = np.concatenate(idx)
        col[q[:, 1], q[:, 0]] = shade(mats[mi], np.concatenate(Ps), np.concatenate(Ns))
        filled[q[:, 1], q[:, 0]] = True
    # 섬 가장자리 번짐 방지: 빈 칸을 옆 칸 색으로 몇 번 채운다
    for _ in range(6):
        acc = np.zeros_like(col); cnt = np.zeros(filled.shape, np.float32)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            acc += np.roll(np.roll(col * filled[..., None], dy, 0), dx, 1); cnt += np.roll(np.roll(filled, dy, 0), dx, 1)
        grow = (~filled) & (cnt > 0)
        col[grow] = acc[grow] / cnt[grow][:, None]; filled |= grow
    img = bpy.data.images.new(name, TEX, TEX, alpha=False)
    img.pixels.foreach_set(np.concatenate([col, np.ones((TEX, TEX, 1), np.float32)], 2).ravel())
    img.filepath_raw = os.path.join(os.path.expanduser("~"), "Downloads", "CollapseMine", f"{name}.png")
    img.file_format = 'PNG'; img.save()
    m = bpy.data.materials.new(name); m.use_nodes = True
    nt = m.node_tree; tex = nt.nodes.new("ShaderNodeTexImage"); tex.image = img
    nt.links.new(tex.outputs["Color"], nt.nodes["Principled BSDF"].inputs["Base Color"])
    nt.nodes.active = tex
    me.materials.clear(); me.materials.append(m)
    for p in me.polygons:
        p.material_index = 0
    return ob


def join_and_export_levels(prefix, filename):
    """레벨마다 한 덩어리로 합쳐 칠한다 (Canary_L<n>_Paint). 빛나는 램프·보석은 Canary_L<n>_<재질>로 따로 (Roblox Neon)"""
    col = STATE["col"]
    for ob in col.objects:  # 합치기 전에 위치·회전을 메시에 굽는다 (칠할 때 3D 위치가 맞게)
        ob.select_set(True)
    bpy.context.view_layer.objects.active = col.objects[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    groups = {}
    for ob in list(col.objects):
        mname = ob.data.materials[0].name
        key = (ob.get("lv", 1), mname if mname in GLOW else "Paint")
        groups.setdefault(key, []).append(ob)
    for (lv, kind), obs in groups.items():
        bpy.ops.object.select_all(action='DESELECT')
        for o in obs:
            o.select_set(True)
        bpy.context.view_layer.objects.active = obs[0]
        if len(obs) > 1:
            bpy.ops.object.join()
        j = bpy.context.view_layer.objects.active
        j.name = j.data.name = f"{prefix}_L{lv}_{kind}"
        j["lv"] = lv
        if kind == "Paint":
            paint(j, f"{prefix}_L{lv}_Tex")
    bpy.ops.object.select_all(action='DESELECT')
    for ob in col.objects:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = col.objects[0]
    bpy.context.scene.cursor.location = (0, 0, 0)
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    tris = sum(len(p.vertices) - 2 for ob in col.objects for p in ob.data.polygons)
    out_dir = os.path.join(os.path.expanduser("~"), "Downloads", "CollapseMine")
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, filename)
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={'MESH'},
                             apply_unit_scale=True, apply_scale_options='FBX_SCALE_ALL', axis_forward='-Z', axis_up='Y',
                             mesh_smooth_type='FACE', bake_space_transform=True, path_mode='COPY', embed_textures=True)
    print("내보냄:", path, "| 오브젝트", len(col.objects), "| 삼각형", tris)
    return path


if __name__ == "__main__":
    build()
