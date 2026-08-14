"""Logo v3-D1 清洗：破屏鲸（手机线框 + 白鲸破屏）。
基于 crop_icon.py 的 alpha 反演法，针对 D1 原图结构调整：
- D1 = 灰蓝画布 + 内嵌「竖版」圆角矩形图标（x 180~826, y 88~932），
  画布与图标同为蓝色系，无法用饱和度区分，故内框边界用跳变检测后硬编码；
- 取 844×844 方形裁剪（含左右画布条），渐变平面只用内框内的饱和像素拟合，
  画布条 alpha=0 由渐变外推填充 → 无接缝满版方图；
- 右下角"AI生成"水印在裁剪区之外，天然排除。
"""
import numpy as np
from PIL import Image
from pathlib import Path

SRC = "/Users/lifengzhi/codex/对话项目/Projects/Active/dp远程/ui设计/generated-images/logo-v3-d1-whale-out-of-phone-raw.png"
OUT = Path("/Users/lifengzhi/codex/对话项目/Projects/Active/dp远程/ui设计/design/icon-set-v3")
OUT.mkdir(parents=True, exist_ok=True)

# 内嵌图标边界（由跳变检测得到，见调试记录）
IN_X0, IN_X1 = 180, 826
IN_Y0, IN_Y1 = 88, 932
SIDE = IN_Y1 - IN_Y0          # 844
CX, CY = 512, (IN_Y0 + IN_Y1) // 2   # 图标中心
X0, Y0 = CX - SIDE // 2, IN_Y0       # 方形裁剪起点 (90, 88)

img = np.asarray(Image.open(SRC).convert("RGB")).astype(np.float64)
icon = img[Y0:Y0 + SIDE, X0:X0 + SIDE].copy()
ys, xs = np.mgrid[0:SIDE, 0:SIDE]

# 内框在裁剪坐标系中的位置
in_x0, in_x1 = IN_X0 - X0, IN_X1 - X0
in_y0, in_y1 = 0, SIDE
inside = (xs >= in_x0) & (xs < in_x1) & (ys >= in_y0) & (ys < in_y1)

# 1. 平面渐变拟合：只用内框里的饱和彩色像素（排除白色鲸鱼/手机线框）
smx, smn = icon.max(axis=2), icon.min(axis=2)
colored = inside & ((smx - smn) > 30)
A = np.stack([xs[colored], ys[colored], np.ones(int(colored.sum()))], axis=1)
grad = np.empty_like(icon)
for ch in range(3):
    coef, *_ = np.linalg.lstsq(A, icon[:, :, ch][colored], rcond=None)
    grad[:, :, ch] = coef[0] * xs + coef[1] * ys + coef[2]

# 2. 反演白色主体 alpha
denom = np.clip(255.0 - grad, 1.0, None)
alpha = (icon - grad) / denom
alpha = np.clip(np.median(alpha, axis=2), 0.0, 1.0)
# 内框外的画布条强制 alpha=0（渐变外推填充）
alpha[~inside] = 0.0
# 内框里既不饱和也不白的像素（圆角外残留画布）同样归零
corner_canvas = inside & ~((smx - smn) > 30) & ~(smn > 180)
alpha[corner_canvas] = 0.0
# 对比拉伸 + smoothstep
alpha = np.clip((alpha - 0.35) / 0.55, 0.0, 1.0)
alpha = alpha * alpha * (3 - 2 * alpha)

# 3. 重新合成
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
print("crop:", (X0, Y0, SIDE), "| exported", len(sizes), "icons ->", OUT)
