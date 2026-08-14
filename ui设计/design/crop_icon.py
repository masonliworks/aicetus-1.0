"""图标清洗 v3：alpha 反演法。
思路：图标 = 白鲸(alpha) 叠加在 蓝青渐变 上。
1) 行列投影定位图标（避开水印）；
2) 用饱和彩色像素拟合平面渐变 c = a*x + b*y + d；
3) 对每个像素反演 alpha = (obs - grad) / (white - grad)，得鲸鱼蒙版；
4) 干净渐变 + 纯白鲸重新合成 → 无接缝、无水渍、无水印；
5) 导出 iOS/Mac 全套尺寸。"""
import numpy as np
from PIL import Image
from pathlib import Path

SRC = "/Users/lifengzhi/WorkBuddy/2026-08-14-01-35-52/generated-images/iOS_app_icon__full_bleed_edge__2026-08-13T19-36-59.png"
OUT = Path("/Users/lifengzhi/WorkBuddy/2026-08-14-01-35-52/design/icon-set")
OUT.mkdir(parents=True, exist_ok=True)

img = np.asarray(Image.open(SRC).convert("RGB")).astype(np.float64)
mx, mn = img.max(axis=2), img.min(axis=2)
is_bg = ((mx - mn) < 12) & (mx < 140)
not_bg = ~is_bg

# 1. 图标主体包围盒（行/列投影阈值，过滤右下角水印的零星像素）
cols = np.where(not_bg.sum(axis=0) > 100)[0]
rows = np.where(not_bg.sum(axis=1) > 100)[0]
x0, x1, y0, y1 = cols[0], cols[-1], rows[0], rows[-1]
side = max(x1 - x0, y1 - y0) + 1
cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
x0, y0 = cx - side // 2, cy - side // 2
icon = img[y0:y0 + side, x0:x0 + side].copy()

# 2. 平面渐变拟合（只用饱和彩色像素）
smx, smn = icon.max(axis=2), icon.min(axis=2)
colored = (smx - smn) > 30
ys, xs = np.mgrid[0:side, 0:side]
A = np.stack([xs[colored], ys[colored], np.ones(int(colored.sum()))], axis=1)
grad = np.empty_like(icon)
for ch in range(3):
    coef, *_ = np.linalg.lstsq(A, icon[:, :, ch][colored], rcond=None)
    grad[:, :, ch] = coef[0] * xs + coef[1] * ys + coef[2]

# 3. 反演鲸鱼 alpha：obs = alpha*255 + (1-alpha)*grad  →  alpha = (obs-grad)/(255-grad)
denom = np.clip(255.0 - grad, 1.0, None)
alpha = (icon - grad) / denom
alpha = np.clip(np.median(alpha, axis=2), 0.0, 1.0)   # 三通道取中位数，抗噪
# 灰角区域（原图灰色底）强制 alpha=0
alpha[is_bg[y0:y0 + side, x0:x0 + side] & ((smx - smn) < 12)] = 0.0
# 对比拉伸：>0.35 的半透明区推向纯白（修掉鲸身水渍），边缘保留柔化过渡
alpha = np.clip((alpha - 0.35) / 0.55, 0.0, 1.0)
alpha = alpha * alpha * (3 - 2 * alpha)               # smoothstep，边缘更自然

# 4. 重新合成：干净渐变 + 纯白鲸
final = grad * (1 - alpha[..., None]) + 255.0 * alpha[..., None]
out = Image.fromarray(np.clip(final, 0, 255).astype(np.uint8)).resize((1024, 1024), Image.LANCZOS)

sizes = {
    "AppStore-1024.png": 1024,
    "iPhone-180@3x.png": 180, "iPhone-120@2x.png": 120, "iPhone-87@3x-settings.png": 87,
    "iPad-167@2x.png": 167, "iPad-152@2x.png": 152, "iPad-76@1x.png": 76,
    "Notification-60@3x.png": 60, "Notification-40@2x.png": 40,
    "Spotlight-120.png": 120, "Spotlight-80.png": 80,
    "Mac-512.png": 512, "Mac-256.png": 256, "Mac-128.png": 128,
}
for name, px in sizes.items():
    out.resize((px, px), Image.LANCZOS).save(OUT / name)
print("bbox side:", side, "| exported", len(sizes), "icons ->", OUT)
