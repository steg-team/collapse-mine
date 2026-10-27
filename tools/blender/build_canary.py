"""
광산 카나리아(어깨 위 펫 새, D-023, D-045) — 블렌더에서 실행하면 ~/Downloads/CollapseMine/Canary.fbx 로 내보낸다.
화면 없이: /Applications/Blender.app/Contents/MacOS/Blender -b --python tools/blender/build_canary.py
(삼각형 2천 개 남짓이라 GPU 없는 노트북에서도 몇 초)

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
    "Feather": (1.0, 0.84, 0.25), "FeatherDark": (0.92, 0.70, 0.16),
    "Beak": (1.0, 0.55, 0.12), "Eye": (0.05, 0.05, 0.06),
    "Helmet": (0.80, 0.16, 0.12), "Lamp": (1.0, 0.95, 0.70), "Scarf": (0.20, 0.40, 0.85),
    "GoldFeather": (1.0, 0.58, 0.04),  # 몸통 노랑과 구분되게 진한 주황빛 금 (Roblox Metal)
})

LEVEL = {"n": 1}  # 지금 만드는 부품이 붙는 레벨 (build 안에서 바꿈)


def tag(ob):
    ob["lv"] = LEVEL["n"]
    return ob


def ball(m, r, loc, scale=(1, 1, 1), rot=(0, 0, 0), seg=12, top_only=False):
    """타원체: 반지름 r 공을 scale배로 늘림. top_only면 윗반구만 (헬멧)"""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=max(6, seg * 2 // 3), radius=r)
    if top_only:
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < -1e-4], context='VERTS')
    for v in bm.verts:
        v.co.x *= scale[0]; v.co.y *= scale[1]; v.co.z *= scale[2]
    return tag(_place(_obj(bm, m), loc, rot))


def part(fn, *a, **k):
    return tag(fn(*a, **k))


def build():
    setup("Canary")
    # Lv1 기본 새: 몸통(앞뒤로 조금 긴 알), 머리, 머리 깃, 부리(끝이 -Y), 눈, 날개, 꼬리, 발
    LEVEL["n"] = 1
    ball("Feather", 0.28, (0, 0.03, 0.28), scale=(1, 1.25, 1), seg=16)
    ball("Feather", 0.2, (0, -0.2, 0.56), seg=14)
    part(cyl, "FeatherDark", 0.05, 0.14, (0, -0.14, 0.78), rot=(-35, 0, 0), verts=6, r2=0.0)
    part(cyl, "Beak", 0.065, 0.16, (0, -0.43, 0.53), rot=(90, 0, 0), verts=8, r2=0.0)
    for sx in (-1, 1):
        ball("Eye", 0.035, (sx * 0.13, -0.33, 0.61), seg=8)
        ball("FeatherDark", 0.2, (sx * 0.26, 0.07, 0.3), scale=(0.25, 1.25, 0.8), rot=(-10, 0, 0), seg=10)
        part(cyl, "Beak", 0.03, 0.08, (sx * 0.08, -0.02, 0.04), verts=6)
    part(box, "FeatherDark", (0.22, 0.32, 0.05), (0, 0.42, 0.3), rot=(25, 0, 0))

    # Lv2 광부 헬멧 + 램프: 머리 위 반구, 챙, 앞 램프(Roblox Neon + PointLight 자리)
    LEVEL["n"] = 2
    ball("Helmet", 0.215, (0, -0.19, 0.6), scale=(1, 1, 0.8), seg=14, top_only=True)
    part(cyl, "Helmet", 0.235, 0.025, (0, -0.19, 0.6), verts=16)
    part(cyl, "Iron", 0.06, 0.05, (0, -0.39, 0.68), rot=(90, 0, 0), verts=10)
    part(cyl, "Lamp", 0.045, 0.02, (0, -0.42, 0.68), rot=(90, 0, 0), verts=10)

    # Lv3 목도리: 목에 두른 고리 + 옆으로 늘어진 끝
    LEVEL["n"] = 3
    part(torus, "Scarf", 0.17, 0.045, (0, -0.15, 0.42), rot=(12, 0, 0), seg=14, mseg=5)
    part(box, "Scarf", (0.09, 0.04, 0.2), (0.14, -0.04, 0.3), rot=(10, 0, -20))

    # Lv4 가슴 보석: 위아래로 뾰족한 팔면체 (Roblox Neon)
    LEVEL["n"] = 4
    for s in (1, -1):
        part(cyl, "Gem", 0.06, 0.07, (0, -0.33, 0.32 + s * 0.035), rot=(0 if s > 0 else 180, 0, 0), verts=4, r2=0.0)

    # Lv5 황금 깃털: 날개를 덮는 금빛 깃(조금 크게 겹침), 위로 펼친 꼬리 부채 5장, 볏 3개
    LEVEL["n"] = 5
    for sx in (-1, 1):
        ball("GoldFeather", 0.2, (sx * 0.27, 0.08, 0.31), scale=(0.27, 1.3, 0.84), rot=(-10, 0, 0), seg=10)
    for yaw in (-40, -20, 0, 20, 40):
        r = math.radians(yaw)
        part(box, "GoldFeather", (0.08, 0.34, 0.03), (math.sin(r) * 0.16, 0.45 + math.cos(r) * 0.08, 0.4), rot=(28, 0, yaw))
    for dx in (-0.06, 0, 0.06):
        part(cyl, "GoldFeather", 0.035, 0.13, (dx, -0.17, 0.8 + (0.02 if dx == 0 else 0)), rot=(-20, dx * 200, 0), verts=6, r2=0.0)
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
