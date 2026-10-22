"""
"별이 떨어진 곳" 광석 6종을 그림에서 바로 만드는 스크립트 (블렌더). D-010 / tools/import_starfall_tex.luau 참고.

입력: ~/Downloads/CollapseMine/ref/starfall_<n>_<광석>.png (1024², 밝은 단색 배경에 광석 하나)
출력:
- ~/Downloads/CollapseMine/tex/SF_<광석>_Color.png    색 그림 (실루엣 바깥을 안쪽 색으로 메워 가장자리에 회색이 안 번지게)
- ~/Downloads/CollapseMine/tex/SF_<광석>_Emissive.png 빛 마스크 (흰색만 빛남. 광석별 규칙은 emissive_mask)
- ~/Downloads/CollapseMine/StarfallOresTex.fbx        메시 6개 (SFT_<광석>, 탄젠트 포함)

메시: 그림 실루엣을 격자로 떠서 앞뒤로 둥글게 부풀림. 앞뒤를 보는 면은 UV = 그림 좌표라 그림 그대로 보이고,
옆·위·아래를 보는 면은 side_uv가 광석 안쪽 무늬 조각을 둘러 입혀 늘어난 줄무늬를 없앤다 (텍스처는 그대로, UV만 다름).
한계: 옆면 무늬는 그림 조각의 거울 반복이라 앞면과 경계에서 살짝 이어지지 않는다.
"""
import bpy, bmesh, os
import numpy as np

REF = os.path.join(os.path.expanduser("~"), "Downloads", "CollapseMine", "ref")
OUT = os.path.join(os.path.expanduser("~"), "Downloads", "CollapseMine", "tex")
ORES = [("Meteor", "starfall_1_meteor.png", 0.42), ("Stardust", "starfall_2_stardust.png", 0.42),
        ("Nebula", "starfall_3_nebula.png", 0.40), ("Comet", "starfall_4_comet.png", 0.45),
        ("Crystal", "starfall_5_crystal.png", 0.30), ("Star", "starfall_6_star.png", 0.30)]


def load(name):
    img = bpy.data.images.load(os.path.join(REF, name), check_existing=True)
    w, h = img.size
    return img, np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)


def fg_mask(px, thr=0.12):
    c = np.concatenate([px[:20, :20, :3].reshape(-1, 3), px[:20, -20:, :3].reshape(-1, 3),
                        px[-20:, :20, :3].reshape(-1, 3), px[-20:, -20:, :3].reshape(-1, 3)])
    return np.abs(px[:, :, :3] - c.mean(0)).sum(2) > thr


def dist_inside(m, iters=60):
    d = np.zeros(m.shape, np.float32)
    cur = m.copy()
    for _ in range(iters):
        if not cur.any():
            break
        d += cur
        e = cur.copy()
        e[1:, :] &= cur[:-1, :]; e[:-1, :] &= cur[1:, :]; e[:, 1:] &= cur[:, :-1]; e[:, :-1] &= cur[:, 1:]
        cur = e
    return d


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


def inflate(name, ore, color_img, size=3.0, N=64, depth=0.42, back=0.85, rim_smooth=3):
    _, px = load(name)
    H, W = px.shape[:2]
    m = fg_mask(px)
    ys, xs = np.nonzero(m)
    x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
    span = max(x1 - x0, y1 - y0)
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    g = np.zeros((N + 1, N + 1), bool)
    for j in range(N + 1):
        for i in range(N + 1):
            u = cx - span / 2 + span * i / N; v = cy - span / 2 + span * j / N
            g[j, i] = m[int(np.clip(v, 0, H - 1)), int(np.clip(u, 0, W - 1))]
    g = largest_island(g)
    d = dist_inside(g)
    for _ in range(10):  # 계단 없애기
        p = np.pad(d, 1)
        d = np.where(g, (p[:-2, 1:-1] + p[2:, 1:-1] + p[1:-1, :-2] + p[1:-1, 2:] + p[1:-1, 1:-1] * 2) / 6, 0)
    pg = np.pad(g, 1)
    edge = g & ~(pg[:-2, 1:-1] & pg[2:, 1:-1] & pg[1:-1, :-2] & pg[1:-1, 2:])
    d = np.where(edge, 0, d)  # 테두리 두께 0 → 앞뒤가 붙음
    dmax = max(d.max(), 1e-6)

    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    front, rear = {}, {}
    for j in range(N + 1):
        for i in range(N + 1):
            if not g[j, i]:
                continue
            x, z = (i / N - 0.5) * size, (j / N - 0.5) * size
            t = min(1.0, d[j, i] / dmax) ** 0.8
            bulge = np.sqrt(max(0.0, 1 - (1 - t) ** 2)) * depth * size
            front[(i, j)] = bm.verts.new((x, -bulge, z))
            rear[(i, j)] = bm.verts.new((x, bulge * back, z))
    uv = lambda i, j: ((cx - span / 2 + span * i / N) / W, (cy - span / 2 + span * j / N) / H)
    for j in range(N):
        for i in range(N):
            q = [(i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1)]
            if all(k in front for k in q):
                f = bm.faces.new([front[k] for k in q][::-1])
                for lp, k in zip(f.loops, q[::-1]):
                    lp[uvl].uv = uv(*k)
                b = bm.faces.new([rear[k] for k in q])
                for lp, k in zip(b.loops, q):
                    lp[uvl].uv = uv(*k)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    # 격자로 뜬 실루엣은 테두리가 계단이라 Roblox에서 빗살 무늬가 생긴다 → 테두리 선만 살짝 둥글게
    rim = [v for v in bm.verts if abs(v.co.y) < 1e-6]
    for _ in range(rim_smooth):
        bmesh.ops.smooth_vert(bm, verts=rim, factor=0.5, use_axis_x=True, use_axis_y=False, use_axis_z=True)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(ore); bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new(ore, me)
    col = bpy.data.collections.get("StarfallTex") or bpy.data.collections.new("StarfallTex")
    if col.name not in bpy.context.scene.collection.children:
        bpy.context.scene.collection.children.link(col)
    col.objects.link(ob)
    mat = bpy.data.materials.new(ore + "_Mat"); mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next((n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED'), None) or nt.nodes.new("ShaderNodeBsdfPrincipled")
    out = next((n for n in nt.nodes if n.type == 'OUTPUT_MATERIAL'), None) or nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(bsdf.outputs[0], out.inputs[0])
    tex = nt.nodes.new("ShaderNodeTexImage"); tex.image = color_img
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    me.materials.append(mat)
    return ob


def _pingpong(p, L):
    t = p % (2 * L)
    return t if t <= L else 2 * L - t


def side_uv(ob, fn, size=3.0, ratio=1.8):
    """옆·위·아래를 보는 면은 그림을 늘리는 대신 광석 안쪽 무늬 조각을 둘러 입힌다.
    둘레 방향(각도)·두께 방향으로 거울 반복(ping-pong)이라 이음새 없이 이어지고, 무늬 크기는 앞면과 같다."""
    import math
    _, px = load(fn)
    H, W = px.shape[:2]
    m = fg_mask(px)
    ys, xs = np.nonzero(m)
    span = max(xs.max() - xs.min(), ys.max() - ys.min())
    d = dist_inside(m, iters=300)
    py, pxx = np.unravel_index(np.argmax(d), d.shape)
    L = 2 * min(d.max() * 0.7, span * 0.22)  # 무늬 조각 한 변(px): 실루엣 안쪽에서 가장 넓은 곳
    dens = span / size
    R = size * 0.4
    bm = bmesh.new(); bm.from_mesh(ob.data)
    uvl = bm.loops.layers.uv.active
    for f in bm.faces:
        f.smooth = True
        n = f.normal
        if abs(n.y) >= max(abs(n.x), abs(n.z)) * ratio:
            continue  # 앞·뒤를 보는 면은 그림 그대로
        c = f.calc_center_median(); th0 = math.atan2(c.z, c.x)
        for lp in f.loops:
            co = lp.vert.co; th = math.atan2(co.z, co.x)
            if th - th0 > math.pi: th -= 2 * math.pi
            elif th0 - th > math.pi: th += 2 * math.pi
            u = pxx - L / 2 + _pingpong(th * R * dens + 10 * L, L)
            v = py - L / 2 + _pingpong(co.y * dens + 10 * L, L)
            lp[uvl].uv = (u / W, v / H)
    bm.to_mesh(ob.data); bm.free()


def build_solid(key, fn, depth, color_img, size=3.0, N=72, back=0.85, voxel=0.045, target=6000, ratio=1.6):
    """빈틈없는 광석 메시. inflate는 테두리가 계단이라 실금·접힘이 생겨 Roblox에서 옆구리가 뚫려 보였다.
    그래서 실루엣×부풀림 높이를 작은 블록으로 쌓아 닫힌 부피를 만들고, 리메시·스무스·데시메이트로 다듬은 뒤
    UV를 위치로 다시 계산한다 (앞뒤를 보는 면 = 그림 좌표, 나머지 = 안쪽 무늬 조각 둘러 입히기)."""
    import math
    _, px = load(fn)
    H, W = px.shape[:2]
    m = fg_mask(px)
    ys, xs = np.nonzero(m)
    x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
    span = max(x1 - x0, y1 - y0); cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    g = np.zeros((N, N), bool)
    for j in range(N):
        for i in range(N):
            u = cx - span / 2 + span * (i + 0.5) / N; v = cy - span / 2 + span * (j + 0.5) / N
            g[j, i] = m[int(np.clip(v, 0, H - 1)), int(np.clip(u, 0, W - 1))]
    g = largest_island(g)
    d = dist_inside(g)
    for _ in range(10):
        p = np.pad(d, 1)
        d = np.where(g, (p[:-2, 1:-1] + p[2:, 1:-1] + p[1:-1, :-2] + p[1:-1, 2:] + p[1:-1, 1:-1] * 2) / 6, 0)
    t = np.clip(d / max(d.max(), 1e-6), 0, 1) ** 0.8
    bulge = np.sqrt(np.clip(1 - (1 - t) ** 2, 0, 1)) * depth * size
    cell = size / N
    K = int(math.ceil(depth * size / cell)) + 1
    ks = (np.arange(-K, K) + 0.5) * cell
    occ = g[:, :, None] & (ks[None, None, :] >= -np.maximum(bulge, cell)[:, :, None]) \
        & (ks[None, None, :] <= np.maximum(bulge * back, cell)[:, :, None])
    bm = bmesh.new(); vmap = {}

    def V(a, b, c):
        k = (a, b, c)
        if k not in vmap:
            vmap[k] = bm.verts.new(((a - N / 2) * cell, (b - K) * cell, (c - N / 2) * cell))
        return vmap[k]
    pad = np.pad(occ, 1)
    for j, i, k in zip(*np.nonzero(occ)):  # x=i, y=k, z=j
        if not pad[j + 1, i, k + 1]: bm.faces.new([V(i, k, j), V(i, k, j + 1), V(i, k + 1, j + 1), V(i, k + 1, j)])
        if not pad[j + 1, i + 2, k + 1]: bm.faces.new([V(i + 1, k, j), V(i + 1, k + 1, j), V(i + 1, k + 1, j + 1), V(i + 1, k, j + 1)])
        if not pad[j, i + 1, k + 1]: bm.faces.new([V(i, k, j), V(i, k + 1, j), V(i + 1, k + 1, j), V(i + 1, k, j)])
        if not pad[j + 2, i + 1, k + 1]: bm.faces.new([V(i, k, j + 1), V(i + 1, k, j + 1), V(i + 1, k + 1, j + 1), V(i, k + 1, j + 1)])
        if not pad[j + 1, i + 1, k]: bm.faces.new([V(i, k, j), V(i + 1, k, j), V(i + 1, k, j + 1), V(i, k, j + 1)])
        if not pad[j + 1, i + 1, k + 2]: bm.faces.new([V(i, k + 1, j), V(i, k + 1, j + 1), V(i + 1, k + 1, j + 1), V(i + 1, k + 1, j)])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    name = "SFT_" + key
    old = bpy.data.objects.get(name)
    if old:
        bpy.data.objects.remove(old, do_unlink=True)
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new(name, me)
    col = bpy.data.collections.get("StarfallTex") or bpy.data.collections.new("StarfallTex")
    if col.name not in bpy.context.scene.collection.children:
        bpy.context.scene.collection.children.link(col)
    col.objects.link(ob)
    mat = bpy.data.materials.new(name + "_Mat"); mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next((n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED'), None) or nt.nodes.new("ShaderNodeBsdfPrincipled")
    out = next((n for n in nt.nodes if n.type == 'OUTPUT_MATERIAL'), None) or nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(bsdf.outputs[0], out.inputs[0])
    tex = nt.nodes.new("ShaderNodeTexImage"); tex.image = color_img
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    me.materials.append(mat)
    for o in bpy.context.selected_objects:
        o.select_set(False)
    bpy.context.view_layer.objects.active = ob; ob.select_set(True)
    md = ob.modifiers.new("rm", 'REMESH'); md.mode = 'VOXEL'; md.voxel_size = voxel
    bpy.ops.object.modifier_apply(modifier=md.name)
    sm = ob.modifiers.new("sm", 'SMOOTH'); sm.factor = 0.6; sm.iterations = 6
    bpy.ops.object.modifier_apply(modifier=sm.name)
    n = len(ob.data.polygons)
    if n > target:
        dc = ob.modifiers.new("dc", 'DECIMATE'); dc.ratio = target / n
        bpy.ops.object.modifier_apply(modifier=dc.name)
    dm = dist_inside(m, iters=300)
    py, pxx = np.unravel_index(np.argmax(dm), dm.shape)
    L = 2 * min(dm.max() * 0.7, span * 0.22); dens = span / size; R = size * 0.4
    me = ob.data
    if not me.uv_layers:
        me.uv_layers.new(name="UVMap")
    bm = bmesh.new(); bm.from_mesh(me); uvl = bm.loops.layers.uv.verify()
    for f in bm.faces:
        f.smooth = True; nn = f.normal
        if abs(nn.y) >= max(abs(nn.x), abs(nn.z)) * ratio:
            for lp in f.loops:
                co = lp.vert.co
                lp[uvl].uv = ((cx - span / 2 + span * (co.x / size + 0.5)) / W, (cy - span / 2 + span * (co.z / size + 0.5)) / H)
        else:
            c = f.calc_center_median(); th0 = math.atan2(c.z, c.x)
            for lp in f.loops:
                co = lp.vert.co; th = math.atan2(co.z, co.x)
                if th - th0 > math.pi: th -= 2 * math.pi
                elif th0 - th > math.pi: th += 2 * math.pi
                lp[uvl].uv = ((pxx - L / 2 + _pingpong(th * R * dens + 10 * L, L)) / W,
                              (py - L / 2 + _pingpong(co.y * dens + 10 * L, L)) / H)
    bm.to_mesh(me); bm.free()
    return ob


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
    mx, mn = rgb.max(2), rgb.min(2)
    sat = (mx - mn) / np.maximum(mx, 1e-3)
    if key == "Meteor":
        m = np.clip((r - 0.55) * 3, 0, 1) * np.clip((sat - 0.45) * 3, 0, 1) * (r > b + 0.3)   # 용암 틈
    elif key == "Stardust":
        m = np.clip((lum - 0.55) * 3, 0, 1) + np.clip((b - 0.55) * 2, 0, 1) * (b > r + 0.15)  # 별가루 + 푸른 틈
    elif key == "Nebula":
        m = np.clip((lum - 0.75) * 4, 0, 1)                                                    # 작은 별들
    elif key == "Comet":
        m = np.clip((lum - 0.7) * 2.5, 0, 1)
    elif key == "Crystal":
        m = np.clip((lum - 0.65) * 2.5, 0, 1)
    else:
        m = np.clip((lum - 0.6) * 2.5, 0, 1)
    return np.clip(m, 0, 1)


def build():
    os.makedirs(OUT, exist_ok=True)
    sc = bpy.data.scenes.get("Starfall") or bpy.data.scenes.new("Starfall")
    bpy.context.window.scene = sc
    obs = []
    for i, (key, fn, depth) in enumerate(ORES):
        _, px = load(fn)
        fg = fg_mask(px)
        rgb = px[..., :3].copy()
        filled = fg.copy()
        for _ in range(12):  # 바깥 회색을 안쪽 색으로 메움
            nb = np.zeros_like(rgb); cnt = np.zeros(fg.shape, np.float32)
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                sf = np.roll(filled, (dy, dx), (0, 1)); nb += np.roll(rgb, (dy, dx), (0, 1)) * sf[..., None]; cnt += sf
            grow = (~filled) & (cnt > 0)
            rgb[grow] = nb[grow] / cnt[grow][:, None]
            filled |= grow
        cimg = save(f"SF_{key}_Color", np.concatenate([rgb, np.ones(fg.shape + (1,), np.float32)], 2))
        em = emissive_mask(key, px[..., :3]) * fg
        save(f"SF_{key}_Emissive", np.stack([em, em, em, np.ones_like(em)], 2))
        old = bpy.data.objects.get("SFT_" + key)
        if old:
            bpy.data.objects.remove(old, do_unlink=True)
        ob = build_solid(key, fn, depth, cimg)  # 예전: inflate + side_uv (옆구리 구멍 문제)
        ob.location = (-12.5 + i * 5, 4, 0)
        ob.location.z -= min((ob.matrix_world @ v.co).z for v in ob.data.vertices)
        obs.append(ob)
    bpy.ops.object.select_all(action='DESELECT')
    for o in obs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = obs[0]
    path = os.path.join(os.path.expanduser("~"), "Downloads", "CollapseMine", "StarfallOresTex.fbx")
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={'MESH'}, apply_unit_scale=True,
                             apply_scale_options='FBX_SCALE_ALL', axis_forward='-Z', axis_up='Y', mesh_smooth_type='FACE',
                             use_tspace=True, path_mode='COPY', embed_textures=True, bake_space_transform=True)
    print("내보냄:", path)


if __name__ == "__main__":
    build()
