"""
광산 카나리아(어깨 위 새, D-023) — 블렌더에서 실행하면 ~/Downloads/CollapseMine/Canary.fbx 로 내보낸다.
화면 없이: /Applications/Blender.app/Contents/MacOS/Blender -b --python tools/blender/build_canary.py
(삼각형 1천 개 남짓이라 GPU 없는 노트북에서도 몇 초)

1 블렌더 단위 = 1 스터드, 발 밑 가운데가 원점, 앞(부리)은 -Y. 키 약 0.8스터드 (R15 어깨에 앉는 크기).
오브젝트는 재질별로 합쳐 Canary_<재질> 이름으로 나간다. Roblox 쪽 tools/import_canary.luau가 이름을 보고 색을 입힌다.
"""
import bpy, bmesh, math, sys, os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
try:
    from rbx_common import *  # noqa
    from rbx_common import _obj, _place  # ball()이 쓰는 내부 도우미 (import * 에 안 딸려 옴)
except ImportError:
    pass  # MCP로 실행할 때는 rbx_common 내용을 앞에 붙여서 보낸다

# 새 전용 색 (rbx_common PALETTE에 더해서 setup이 재질을 만든다)
PALETTE.update({
    "Feather": (1.0, 0.84, 0.25), "FeatherDark": (0.92, 0.70, 0.16),
    "Beak": (1.0, 0.55, 0.12), "Eye": (0.05, 0.05, 0.06),
})


def ball(m, r, loc, scale=(1, 1, 1), rot=(0, 0, 0), seg=12):
    """타원체: 반지름 r 공을 scale배로 늘림"""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=max(6, seg * 2 // 3), radius=r)
    for v in bm.verts:
        v.co.x *= scale[0]; v.co.y *= scale[1]; v.co.z *= scale[2]
    return _place(_obj(bm, m), loc, rot)


def build():
    setup("Canary")
    # 몸통: 앞뒤로 조금 긴 알 모양, 바닥이 z=0
    ball("Feather", 0.28, (0, 0.03, 0.28), scale=(1, 1.25, 1), seg=16)
    # 머리 + 머리 깃
    ball("Feather", 0.2, (0, -0.2, 0.56), seg=14)
    cyl("FeatherDark", 0.05, 0.14, (0, -0.14, 0.78), rot=(-35, 0, 0), verts=6, r2=0.0)
    # 부리: 원뿔 끝이 앞(-Y)
    cyl("Beak", 0.065, 0.16, (0, -0.43, 0.53), rot=(90, 0, 0), verts=8, r2=0.0)
    # 눈
    for sx in (-1, 1):
        ball("Eye", 0.035, (sx * 0.13, -0.33, 0.61), seg=8)
    # 날개: 몸통 옆에 납작한 타원
    for sx in (-1, 1):
        ball("FeatherDark", 0.2, (sx * 0.26, 0.07, 0.3), scale=(0.25, 1.25, 0.8), rot=(-10, 0, 0), seg=10)
    # 꼬리: 뒤로 뻗어 살짝 들림
    box("FeatherDark", (0.22, 0.32, 0.05), (0, 0.42, 0.3), rot=(25, 0, 0))
    # 발
    for sx in (-1, 1):
        cyl("Beak", 0.03, 0.08, (sx * 0.08, -0.02, 0.04), verts=6)
    return join_and_export("Canary", "Canary.fbx")


if __name__ == "__main__":
    build()
