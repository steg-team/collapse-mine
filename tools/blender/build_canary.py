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
내보낼 때 (레벨, 재질)별로 합쳐 Canary_L<레벨>_<재질> 이름으로 나간다.
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
    "Beak": (1.0, 0.52, 0.10), "Eye": (0.04, 0.04, 0.05), "EyeShine": (1.0, 1.0, 1.0), "Cheek": (1.0, 0.55, 0.50),
    "Helmet": (0.80, 0.16, 0.12), "Lamp": (1.0, 0.95, 0.70), "Scarf": (0.20, 0.40, 0.85),
    "GoldFeather": (1.0, 0.58, 0.04),  # 몸통 노랑과 구분되게 진한 주황빛 금 (Roblox Metal)
})

LEVEL = {"n": 1}  # 지금 만드는 부품이 붙는 레벨 (build 안에서 바꿈)


def tag(ob):
    ob["lv"] = LEVEL["n"]
    for p in ob.data.polygons:
        p.use_smooth = True  # 면이 각져 보이지 않게 (작은 펫은 매끈해야 귀엽다)
    return ob


def ball(m, r, loc, scale=(1, 1, 1), rot=(0, 0, 0), seg=14, top_only=False):
    """타원체: 반지름 r 공을 scale배로 늘림. top_only면 윗반구만 (헬멧)"""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=max(8, seg * 2 // 3), radius=r)
    if top_only:
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < -1e-4], context='VERTS')
    for v in bm.verts:
        v.co.x *= scale[0]; v.co.y *= scale[1]; v.co.z *= scale[2]
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
    # Lv1 기본 새. 귀여운 펫 비율: 머리가 몸통만큼 크고, 눈이 크고 반짝임, 배는 밝은 색, 볼 홍조
    LEVEL["n"] = 1
    body = ball("Feather", 0.25, (0, 0.04, 0.26), scale=(1, 1.15, 0.95), seg=24)
    head = ball("Feather", 0.235, (0, -0.15, 0.56), seg=24)
    tuft = part(cyl, "Feather", 0.045, 0.16, (0, -0.1, 0.8), rot=(-30, 0, 0), verts=12, r2=0.0)
    blob([body, head, tuft])
    ball("Belly", 0.17, (0, -0.19, 0.25), scale=(1, 0.45, 1.1), seg=18)
    part(cyl, "Beak", 0.055, 0.13, (0, -0.42, 0.5), rot=(95, 0, 0), verts=16, r2=0.0)
    for sx in (-1, 1):
        ball("Eye", 0.055, (sx * 0.11, -0.35, 0.6), scale=(1, 0.6, 1.15), seg=12)
        ball("EyeShine", 0.018, (sx * 0.11 + 0.02, -0.385, 0.635), seg=8)
        ball("Cheek", 0.04, (sx * 0.17, -0.31, 0.5), scale=(1, 0.4, 0.7), seg=8)
        ball("FeatherDark", 0.17, (sx * 0.23, 0.08, 0.3), scale=(0.3, 1.25, 0.85), rot=(-15, sx * 8, 0))
        part(cyl, "Beak", 0.03, 0.08, (sx * 0.08, -0.02, 0.04), verts=10)
    ball("FeatherDark", 0.13, (0, 0.33, 0.3), scale=(0.9, 1.2, 0.3), rot=(30, 0, 0))

    # Lv2 광부 헬멧 + 램프: 머리 위 반구, 챙, 앞 램프(Roblox Neon + PointLight 자리)
    LEVEL["n"] = 2
    # 챙이 눈 위(눈 꼭대기 0.66)에 오도록 높게 얹는다. 눈을 가리면 화나 보인다
    ball("Helmet", 0.24, (0, -0.14, 0.7), scale=(1, 1, 0.7), seg=24, top_only=True)
    part(cyl, "Helmet", 0.265, 0.022, (0, -0.14, 0.7), verts=28)
    part(cyl, "Iron", 0.055, 0.05, (0, -0.36, 0.79), rot=(100, 0, 0), verts=16)
    part(cyl, "Lamp", 0.042, 0.02, (0, -0.39, 0.795), rot=(100, 0, 0), verts=16)

    # Lv3 목도리: 목에 두른 고리 + 옆으로 늘어진 끝
    LEVEL["n"] = 3
    part(torus, "Scarf", 0.2, 0.045, (0, -0.1, 0.43), rot=(10, 0, 0), seg=24, mseg=8)
    part(box, "Scarf", (0.09, 0.035, 0.2), (0.17, -0.02, 0.32), rot=(10, 0, -20), bevel=0.012)

    # Lv4 가슴 보석: 위아래로 뾰족한 팔면체 (Roblox Neon)
    LEVEL["n"] = 4
    for s in (1, -1):
        part(cyl, "Gem", 0.055, 0.065, (0, -0.31, 0.36 + s * 0.032), rot=(0 if s > 0 else 180, 0, 0), verts=4, r2=0.0)

    # Lv5 황금 깃털: 날개 덮개(조금 크게 겹침), 꼬리 부채 5장, 볏 3개
    LEVEL["n"] = 5
    for sx in (-1, 1):
        ball("GoldFeather", 0.17, (sx * 0.24, 0.09, 0.31), scale=(0.32, 1.3, 0.88), rot=(-15, sx * 8, 0))
    for yaw in (-40, -20, 0, 20, 40):
        r = math.radians(yaw)
        ball("GoldFeather", 0.15, (math.sin(r) * 0.12, 0.42 + math.cos(r) * 0.06, 0.36), scale=(0.35, 1.3, 0.15), rot=(25, 0, yaw))
    for dx in (-0.06, 0, 0.06):
        part(cyl, "GoldFeather", 0.035, 0.13, (dx, -0.1, 0.9 + (0.02 if dx == 0 else 0)), rot=(-20, dx * 200, 0), verts=10, r2=0.0)
    return join_and_export_levels("Canary", "Canary.fbx")


def join_and_export_levels(prefix, filename):
    """rbx_common.join_and_export와 같지만 (레벨, 재질)별로 합친다. 레벨마다 켜고 끌 수 있게"""
    col = STATE["col"]
    groups = {}
    for ob in list(col.objects):
        groups.setdefault((ob.get("lv", 1), ob.data.materials[0].name), []).append(ob)
    for (lv, mname), obs in groups.items():
        bpy.ops.object.select_all(action='DESELECT')
        for o in obs:
            o.select_set(True)
        bpy.context.view_layer.objects.active = obs[0]
        if len(obs) > 1:
            bpy.ops.object.join()
        j = bpy.context.view_layer.objects.active
        j.name = j.data.name = f"{prefix}_L{lv}_{mname}"
        j["lv"] = lv
    bpy.ops.object.select_all(action='DESELECT')
    for ob in col.objects:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = col.objects[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.context.scene.cursor.location = (0, 0, 0)
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    tris = sum(len(p.vertices) - 2 for ob in col.objects for p in ob.data.polygons)
    out_dir = os.path.join(os.path.expanduser("~"), "Downloads", "CollapseMine")
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, filename)
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={'MESH'},
                             apply_unit_scale=True, apply_scale_options='FBX_SCALE_ALL', axis_forward='-Z', axis_up='Y',
                             mesh_smooth_type='FACE', bake_space_transform=True)
    print("내보냄:", path, "| 오브젝트", len(col.objects), "| 삼각형", tris)
    return path


if __name__ == "__main__":
    build()
