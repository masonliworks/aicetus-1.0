"""Logo v5 Mac 版底框修补。
图生图两轮后底边框仍有缺口（模型画不出连续条），改为程序化修补：
1) 定位底边框行带：y>650 且彩色像素数异常的 rows（底框两段的行）；
2) 每行找彩色 x 的最大空缺段（左右框段之间的白色缺口）；
3) 只填缺口内的白像素（mn>235），颜色用缺口两端做线性插值
   → 鲸鱼鳍/水滴等彩色像素保留，视觉上框条从鲸鱼"身后"穿过；
4) 近白底归一纯白，导出 Mac 4 尺寸 → design/icon-set-v5/
"""
import numpy as np
from PIL import Image
from pathlib import Path

BASE = Path("/Users/lifengzhi/codex/对话项目/Projects/Active/dp远程/ui设计")
SRC = BASE / "generated-images/logo-v5b-mac-overlap-v2-raw.png"
OUT = BASE / "design/icon-set-v5"

img = np.asarray(Image.open(SRC).convert("RGB")).astype(np.float64)
h, w, _ = img.shape
mx, mn = img.max(axis=2), img.min(axis=2)
colored = ((mx - mn) > 25) & (mn < 235)

# 1. 找底边框行带：限定 x 在主框范围内，y 在屏幕下半部
X_L, X_R = 140, 880
row_counts = colored[:, X_L:X_R].sum(axis=1)
# 侧框行只有 ~60 彩色像素；底框行（两段）有 400+；键盘底座行更靠下且更宽
candidate_rows = [y for y in range(650, h) if 300 < row_counts[y] < 750]
# 连续成带
band = []
for y in candidate_rows:
    if not band or y == band[-1] + 1:
        band.append(y)
    else:
        break
print("bezel band rows:", band[0], "-", band[-1], f"({len(band)} rows)")

# 2+3. 逐行补缺口
patched = 0
for y in band:
    xs = np.where(colored[y, X_L:X_R])[0] + X_L
    if len(xs) < 2:
        continue
    gaps = np.diff(xs)
    gi = int(np.argmax(gaps))
    if gaps[gi] < 20:        # 缺口太小不处理
        continue
    g0, g1 = xs[gi] + 1, xs[gi + 1] - 1
    # 端点取缺口两侧各 8 个彩色像素的中位数，避开抗锯齿边缘的浅色像素
    c0 = np.median(img[y, xs[max(0, gi - 7):gi + 1]], axis=0)
    c1 = np.median(img[y, xs[gi + 1:gi + 9]], axis=0)
    for x in range(g0, g1 + 1):
        if mn[y, x] > 235:   # 只填白像素，鲸鱼彩色部分保留（框在鲸后）
            t = (x - g0 + 1) / (g1 - g0 + 2)
            img[y, x] = c0 * (1 - t) + c1 * t
            patched += 1
print("patched px:", patched)

# 4. 白底归一 + 导出
bg = img.min(axis=2) > 235
img[bg] = 255.0
out = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).resize((1024, 1024), Image.LANCZOS)

for name, px in {"Mac-1024.png": 1024, "Mac-512.png": 512,
                 "Mac-256.png": 256, "Mac-128.png": 128}.items():
    out.resize((px, px), Image.LANCZOS).save(OUT / name)
print("exported 4 Mac icons ->", OUT)
