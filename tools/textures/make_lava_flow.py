"""용암 줄기(Beam)용 텍스처: 가로 = 흐르는 방향(이어 붙여도 이음새 없음), 세로 = 줄기 폭.
가운데는 밝게 녹은 용암, 가장자리로 갈수록 식은 검붉은 껍질, 테두리는 구불구불 투명하게 사라짐."""
import numpy as np
from PIL import Image

W, H = 512, 128
rng = np.random.default_rng(7)


def tile_noise(w, h, cells_x, cells_y, seed):
    """가로·세로 모두 이어지는 값 노이즈 (코사인 보간)"""
    r = np.random.default_rng(seed).random((cells_y, cells_x))
    xs = np.arange(w) / w * cells_x
    ys = np.arange(h) / h * cells_y
    x0 = np.floor(xs).astype(int); fx = xs - x0
    y0 = np.floor(ys).astype(int); fy = ys - y0
    x1 = (x0 + 1) % cells_x; y1 = (y0 + 1) % cells_y
    sx = (1 - np.cos(fx * np.pi)) / 2; sy = (1 - np.cos(fy * np.pi)) / 2
    a = r[np.ix_(y0, x0)]; b = r[np.ix_(y0, x1)]
    c = r[np.ix_(y1, x0)]; d = r[np.ix_(y1, x1)]
    top = a + (b - a) * sx[None, :]
    bot = c + (d - c) * sx[None, :]
    return top + (bot - top) * sy[:, None]


def fbm(w, h, base_x, base_y, octaves, seed):
    out = np.zeros((h, w)); amp = 1; tot = 0
    for o in range(octaves):
        out += amp * tile_noise(w, h, base_x * 2 ** o, base_y * 2 ** o, seed + o)
        tot += amp; amp *= 0.5
    return out / tot


n1 = fbm(W, H, 8, 4, 5, 1)  # 큰 덩어리
n2 = fbm(W, H, 16, 8, 4, 9)  # 잔 균열
v = np.linspace(-1, 1, H)[:, None]  # 폭 방향 -1..1

# 테두리를 구불구불하게: 길이 방향으로 흔들리는 폭
edge = 0.78 + 0.18 * (fbm(W, 1, 6, 1, 3, 21)[0][None, :] - 0.5) * 2
dist = np.abs(v) / edge  # 0 = 가운데, 1 = 테두리

# 녹은 정도: 가운데 뜨겁고 바깥은 식음 + 노이즈로 식은 껍질 조각
heat = (1 - dist ** 1.6) * 0.75 + (n1 - 0.5) * 0.9
cracks = np.abs(n2 - 0.5) * 2  # 0 근처 = 균열 (껍질 사이로 빛남)
crust = np.clip((heat < 0.35) * 1.0, 0, 1)
glow_in_cracks = np.clip(1 - cracks / 0.12, 0, 1) * crust
heat = np.clip(heat + glow_in_cracks * 0.6, 0, 1)

# 색: 껍질(검붉음) → 빨강 → 주황 → 노랑
stops = np.array([
    [0.00, 40, 12, 10],
    [0.30, 120, 20, 8],
    [0.50, 230, 70, 15],
    [0.75, 255, 150, 30],
    [1.00, 255, 235, 140],
])
rgb = np.zeros((H, W, 3))
for ch in range(3):
    rgb[..., ch] = np.interp(heat, stops[:, 0], stops[:, ch + 1])

alpha = np.clip((1 - dist) / 0.18, 0, 1)  # 테두리에서 부드럽게 사라짐
alpha = alpha * (0.85 + 0.15 * n1)
img = np.dstack([rgb, alpha * 255]).astype(np.uint8)
Image.fromarray(img, "RGBA").save("lava_flow.png")
print("saved", img.shape)
