"""
광물 모델을 "앞·옆 턴어라운드 그림" 한 장으로 만드는 스크립트 (블렌더). 그림 한 장(앞모습)만 쓰던 방식보다 옆모습이 정확하다.

입력: ~/Downloads/CollapseMine/ref/turn_<번호>_<이름>.png
      제미나이에 "같은 물건의 턴어라운드 시트: 왼쪽 반 = 정면, 오른쪽 반 = 오른쪽 옆면, 같은 크기·같은 바닥선, 회색 배경"으로 요청한 그림
처리:
  1) 그림을 가운데 빈 세로줄에서 앞/옆으로 나누고, 각 실루엣에서 가장 큰 덩어리만 남김 (워터마크 등 제거)
  2) 앞 실루엣(x,z) × 옆 실루엣(y,z)이 둘 다 찬 칸만 블록으로 쌓아 닫힌 부피 → 리메시·스무스·데시메이트
  3) 텍스처 아틀라스 1024²: 왼쪽 반 = 앞 그림, 오른쪽 반 = 옆 그림. 앞뒤를 보는 면은 왼쪽, 옆을 보는 면은 오른쪽을 씀
  4) 빛 마스크(있는 광물만)도 같은 아틀라스 배치로 저장
출력: tex/TT_<키>_Color.png, tex/TT_<키>_Emissive.png, 메시 TT_<키> → EarlyOresTurn.fbx
Roblox 쪽: tools/import_early_ores.luau (메시 이름 TT_<키>)
"""
import bpy, bmesh, os, math
import numpy as np

BASE = os.path.join(os.path.expanduser("~"), "Downloads", "CollapseMine")
REF = os.path.join(BASE, "ref")
OUT = os.path.join(BASE, "tex")

TURN_ORES = [
    ("Coal", "turn_01_coal.png"), ("Copper", "turn_02_copper.png"), ("Quartz", "turn_03_quartz.png"),
    ("Amber", "turn_04_amber.png"), ("CavePearl", "turn_05_cavepearl.png"), ("Lantern", "turn_06_lantern.png"),
    ("Iron", "turn_07_iron.png"), ("Tin", "turn_08_tin.png"), ("Silver", "turn_09_silver.png"),
    ("Magnetite", "turn_10_magnetite.png"), ("Platinum", "turn_11_platinum.png"), ("PocketWatch", "turn_12_pocketwatch.png"),
    ("Limestone", "turn_13_limestone.png"), ("Calcite", "turn_14_calcite.png"), ("Azurite", "turn_15_azurite.png"),
    ("Malachite", "turn_16_malachite.png"), ("WaterPearl", "turn_17_waterpearl.png"), ("WetMap", "turn_18_wetmap.png"),
]


def fg_mask(px, thr=0.12):
    c = np.concatenate([px[:20, :20, :3].reshape(-1, 3), px[:20, -20:, :3].reshape(-1, 3),
                        px[-20:, :20, :3].reshape(-1, 3), px[-20:, -20:, :3].reshape(-1, 3)])
    return np.abs(px[:, :, :3] - c.mean(0)).sum(2) > thr


def largest_island(g):
    N1, N2 = g.shape
    lab = np.zeros(g.shape, int); cur = 0; sizes = {}
    for sj in range(N1):
        for si in range(N2):
            if g[sj, si] and lab[sj, si] == 0:
                cur += 1; stack = [(sj, si)]; lab[sj, si] = cur; n = 0
                while stack:
                    a, b = stack.pop(); n += 1
                    for da, db in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        aa, bb = a + da, b + db
                        if 0 <= aa < N1 and 0 <= bb < N2 and g[aa, bb] and lab[aa, bb] == 0:
                            lab[aa, bb] = cur; stack.append((aa, bb))
                sizes[cur] = n
    return lab == max(sizes, key=sizes.get) if sizes else g


def keep_main(mm, f=4):
    """가장 큰 덩어리만 (1/f 해상도에서 찾고 원래 크기로)"""
    H, W = mm.shape
    small = mm[:H // f * f, :W // f * f].reshape(H // f, f, W // f, f).any(axis=(1, 3))
    keep = largest_island(small)
    up = np.repeat(np.repeat(keep, f, 0), f, 1)
    out = np.zeros_like(mm); out[:up.shape[0], :up.shape[1]] = up
    return mm & out


def split_col(m):
    cols = m.any(0); W = len(cols); mid = W // 2
    for off in range(W // 3):
        for c in (mid - off, mid + off):
            if 0 <= c < W and not cols[c]:
                return c
    return mid


def dilate_color(rgb, m, steps=24):
    rgb = rgb.copy(); filled = m.copy()
    for _ in range(steps):
        nb = np.zeros_like(rgb); cnt = np.zeros(m.shape, np.float32)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            sf = np.roll(filled, (dy, dx), (0, 1)); nb += np.roll(rgb, (dy, dx), (0, 1)) * sf[..., None]; cnt += sf
        g = (~filled) & (cnt > 0); rgb[g] = nb[g] / cnt[g][:, None]; filled |= g
    return rgb


def save(name, arr):
    h, w = arr.shape[:2]
    im = bpy.data.images.get(name) or bpy.data.images.new(name, w, h, alpha=True)
    if tuple(im.size) != (w, h):
        im.scale(w, h)
    im.pixels[:] = arr.astype(np.float32).ravel()
    im.filepath_raw = os.path.join(OUT, name + ".png"); im.file_format = 'PNG'; im.save()
    return im


def emissive_mask(key, rgb):
    r, gg, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    lum = 0.299 * r + 0.587 * gg + 0.114 * b
    if key == "Amber":
        return np.clip((lum - 0.6) * 2, 0, 1) * (r > b + 0.25) * 0.6
    if key == "Lantern":
        return np.clip((lum - 0.7) * 3, 0, 1) * (r > b + 0.2)
    if key in ("CavePearl", "WaterPearl"):
        return np.clip((lum - 0.75) * 3, 0, 1) * 0.7
    return None


def build_turn(key, fn, size=3.0, N=96, voxel=0.04, target=6000, loc=(0, 0, 0), roundness=2.0, side_core=0.0):
    """roundness: 높이마다 단면을 (|x|/a)^p + (|y|/b)^p <= 1 로 깎는 지수. 2 = 타원(둥근 물건), 클수록 네모, 0 = 깎지 않음
    side_core: 옆 그림에서 세로로 이만큼(최대 대비 비율) 이상 찬 열만 두께로 씀. 회중시계처럼 옆 그림에
               바닥에 펼친 뚜껑·늘어진 사슬이 같이 그려져 몸통이 두꺼워지는 걸 막는다. 0 = 끔"""
    img = bpy.data.images.load(os.path.join(REF, fn), check_existing=True); img.reload()
    W, H = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(H, W, 4)
    m = fg_mask(px)
    cut = split_col(m)
    views = []
    for vi, (a, b) in enumerate(((0, cut), (cut, W))):
        mm = np.zeros_like(m); mm[:, a:b] = m[:, a:b]
        mm = keep_main(mm)
        ys, _ = np.nonzero(mm)
        y0, y1 = ys.min(), ys.max()  # 높이 기준은 자르기 전 전체 (앞 그림과 높이를 맞추려고)
        if vi == 1 and side_core > 0:
            cov = mm.sum(0)
            mm[:, cov < side_core * cov.max()] = False
        _, xs = np.nonzero(mm)
        views.append((xs.min(), xs.max(), y0, y1, mm))
    (fx0, fx1, fy0, fy1, fm), (sx0, sx1, sy0, sy1, sm) = views
    hF, hS = fy1 - fy0, sy1 - sy0
    wx = (fx1 - fx0) * size / hF; wy = (sx1 - sx0) * size / hS
    cell = size / N
    nx, ny = int(wx / cell) + 2, int(wy / cell) + 2
    xs = (np.arange(nx) + 0.5) * cell - wx / 2
    ys_ = (np.arange(ny) + 0.5) * cell - wy / 2
    zs = (np.arange(N) + 0.5) * cell

    def sample(mask, x0, x1, y0, h, w, t, z):
        u = x0 + (t + w / 2) / w * (x1 - x0); v = y0 + z / size * h
        return mask[np.clip(v.astype(int), 0, H - 1), np.clip(u.astype(int), 0, W - 1)]
    X, Z = np.meshgrid(xs, zs, indexing='ij'); Fm = sample(fm, fx0, fx1, fy0, hF, wx, X, Z)
    Y, Z2 = np.meshgrid(ys_, zs, indexing='ij'); Sm = sample(sm, sx0, sx1, sy0, hS, wy, Y, Z2)
    occ = Fm[:, None, :] & Sm[None, :, :]
    if roundness > 0:
        # 앞·옆 실루엣만 겹치면 단면이 늘 사각형이라 네모나 보인다 → 높이마다 그 범위에 맞는 타원으로 깎음
        for k in range(N):
            fx = np.nonzero(Fm[:, k])[0]; sy = np.nonzero(Sm[:, k])[0]
            if len(fx) == 0 or len(sy) == 0:
                continue
            cxk = (xs[fx[0]] + xs[fx[-1]]) / 2; ax = (xs[fx[-1]] - xs[fx[0]]) / 2 + cell
            cyk = (ys_[sy[0]] + ys_[sy[-1]]) / 2; ay = (ys_[sy[-1]] - ys_[sy[0]]) / 2 + cell
            ell = (np.abs(xs[:, None] - cxk) / ax) ** roundness + (np.abs(ys_[None, :] - cyk) / ay) ** roundness <= 1.0
            occ[:, :, k] &= ell

    bm = bmesh.new(); vmap = {}

    def V(a, b, c):
        k = (a, b, c)
        if k not in vmap:
            vmap[k] = bm.verts.new((a * cell - wx / 2, b * cell - wy / 2, c * cell))
        return vmap[k]
    pad = np.pad(occ, 1)
    for i, j, k in zip(*np.nonzero(occ)):
        if not pad[i, j + 1, k + 1]: bm.faces.new([V(i, j, k), V(i, j, k + 1), V(i, j + 1, k + 1), V(i, j + 1, k)])
        if not pad[i + 2, j + 1, k + 1]: bm.faces.new([V(i + 1, j, k), V(i + 1, j + 1, k), V(i + 1, j + 1, k + 1), V(i + 1, j, k + 1)])
        if not pad[i + 1, j, k + 1]: bm.faces.new([V(i, j, k), V(i + 1, j, k), V(i + 1, j, k + 1), V(i, j, k + 1)])
        if not pad[i + 1, j + 2, k + 1]: bm.faces.new([V(i, j + 1, k), V(i, j + 1, k + 1), V(i + 1, j + 1, k + 1), V(i + 1, j + 1, k)])
        if not pad[i + 1, j + 1, k]: bm.faces.new([V(i, j, k), V(i, j + 1, k), V(i + 1, j + 1, k), V(i + 1, j, k)])
        if not pad[i + 1, j + 1, k + 2]: bm.faces.new([V(i, j, k + 1), V(i + 1, j, k + 1), V(i + 1, j + 1, k + 1), V(i, j + 1, k + 1)])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    name = "TT_" + key
    old = bpy.data.objects.get(name)
    if old:
        bpy.data.objects.remove(old, do_unlink=True)
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new(name, me)
    col = bpy.data.collections.get("EarlyOresTurn") or bpy.data.collections.new("EarlyOresTurn")
    if col.name not in bpy.context.scene.collection.children:
        bpy.context.scene.collection.children.link(col)
    col.objects.link(ob)
    for o in bpy.context.selected_objects:
        o.select_set(False)
    bpy.context.view_layer.objects.active = ob; ob.select_set(True)
    md = ob.modifiers.new("rm", 'REMESH'); md.mode = 'VOXEL'; md.voxel_size = voxel
    bpy.ops.object.modifier_apply(modifier=md.name)
    sm_ = ob.modifiers.new("sm", 'SMOOTH'); sm_.factor = 0.5; sm_.iterations = 4
    bpy.ops.object.modifier_apply(modifier=sm_.name)
    n = len(ob.data.polygons)
    if n > target:
        dc = ob.modifiers.new("dc", 'DECIMATE'); dc.ratio = target / n
        bpy.ops.object.modifier_apply(modifier=dc.name)

    # 아틀라스
    A, P = 1024, 6
    rgb = dilate_color(px[..., :3], m)
    em_src = emissive_mask(key, px[..., :3])
    atlas = np.zeros((A, A, 4), np.float32); atlas[..., 3] = 1
    em_atlas = None if em_src is None else np.zeros((A, A, 4), np.float32)

    def put(x0, x1, y0, y1, u0):
        uu = np.linspace(x0, x1, A // 2); vv = np.linspace(y0, y1, A)
        ri = np.clip(vv.astype(int), 0, H - 1); ci = np.clip(uu.astype(int), 0, W - 1)
        atlas[:, u0:u0 + A // 2, :3] = rgb[ri][:, ci]
        if em_atlas is not None:
            e = (em_src * m)[ri][:, ci]
            em_atlas[:, u0:u0 + A // 2, 0] = e; em_atlas[:, u0:u0 + A // 2, 1] = e; em_atlas[:, u0:u0 + A // 2, 2] = e
            em_atlas[:, u0:u0 + A // 2, 3] = 1
    put(fx0 - P, fx1 + P, fy0, fy1, 0)
    put(sx0 - P, sx1 + P, sy0, sy1, A // 2)
    cimg = save(f"TT_{key}_Color", atlas)
    if em_atlas is not None:
        save(f"TT_{key}_Emissive", em_atlas)

    me = ob.data
    if not me.uv_layers:
        me.uv_layers.new(name="UVMap")
    bm = bmesh.new(); bm.from_mesh(me); uvl = bm.loops.layers.uv.verify()
    fw, sw = (fx1 - fx0) + 2 * P, (sx1 - sx0) + 2 * P
    for f in bm.faces:
        f.smooth = True
        side = abs(f.normal.x) > abs(f.normal.y)
        for lp in f.loops:
            co = lp.vert.co
            v = min(max(co.z / size, 0), 1)
            if side:
                u = 0.5 + (P + (co.y + wy / 2) / wy * (sx1 - sx0)) / sw * 0.5
            else:
                u = (P + (co.x + wx / 2) / wx * (fx1 - fx0)) / fw * 0.5
            lp[uvl].uv = (u, v)
    bm.to_mesh(me); bm.free()
    mat = bpy.data.materials.new(name + "_Mat"); mat.use_nodes = True; nt = mat.node_tree
    bsdf = next((x for x in nt.nodes if x.type == 'BSDF_PRINCIPLED'), None) or nt.nodes.new("ShaderNodeBsdfPrincipled")
    out = next((x for x in nt.nodes if x.type == 'OUTPUT_MATERIAL'), None) or nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(bsdf.outputs[0], out.inputs[0])
    t = nt.nodes.new("ShaderNodeTexImage"); t.image = cimg
    nt.links.new(t.outputs["Color"], bsdf.inputs["Base Color"])
    me.materials.append(mat)
    ob.location = loc
    return ob


# 단면 둥글기 (기본 2 = 타원). 각진 결정·납작한 종이는 덜 둥글게
ROUNDNESS = {"Calcite": 6.0, "Coal": 3.0, "Limestone": 3.0, "Magnetite": 3.0, "WetMap": 0.0}
SIDE_CORE = {"PocketWatch": 0.55}


def build_all(ores=TURN_ORES, fbx="EarlyOresTurn.fbx"):
    os.makedirs(OUT, exist_ok=True)
    obs = []
    for i, (key, fn) in enumerate(ores):
        obs.append(build_turn(key, fn, loc=(-12.5 + (i % 6) * 5, 60 + (i // 6) * 6, 0), roundness=ROUNDNESS.get(key, 2.0), side_core=SIDE_CORE.get(key, 0.0)))
    bpy.ops.object.select_all(action='DESELECT')
    for o in obs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = obs[0]
    path = os.path.join(BASE, fbx)
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={'MESH'}, apply_unit_scale=True,
                             apply_scale_options='FBX_SCALE_ALL', axis_forward='-Z', axis_up='Y', mesh_smooth_type='FACE',
                             use_tspace=True, path_mode='COPY', embed_textures=True, bake_space_transform=True)
    print("내보냄:", path)
    return path


if __name__ == "__main__":
    build_all()
