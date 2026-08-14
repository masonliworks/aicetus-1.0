"""Logo v6 居中性修正。
measure_center.py 实测：iOS 版包围盒中心 (498,571)，偏左 14、偏下 59；
Mac 版 (512,520)，偏下 8。
处理：按包围盒中心把主体平移到画布几何中心（露出的边缘本来就是白底），
再从修正后的 1024 主图重新导出全套尺寸 → design/icon-set-v6/
"""
import numpy as np
from PIL import Image
from pathlib import Path

BASE = Path("/Users/lifengzhi/codex/对话项目/Projects/Active/dp远程/ui设计")
OUT = BASE / "design/icon-set-v6"

# 实测偏移（包围盒中心 → 画布中心的平移量）
SHIFTS = {"AppStore-1024.png": (14, -59), "Mac-1024.png": (0, -8)}


def recenter(master: Image.Image, dx: int, dy: int) -> Image.Image:
    canvas = Image.new("RGB", (1024, 1024), (255, 255, 255))
    canvas.paste(master, (dx, dy))
    return canvas


phone = recenter(Image.open(OUT / "AppStore-1024.png").convert("RGB"), *SHIFTS["AppStore-1024.png"])
mac = recenter(Image.open(OUT / "Mac-1024.png").convert("RGB"), *SHIFTS["Mac-1024.png"])

# 校验
for name, im in [("iOS", phone), ("Mac", mac)]:
    a = np.asarray(im).astype(np.float64)
    ys, xs = np.where(a.min(axis=2) < 235)
    print(f"{name} 修正后包围盒中心: ({(xs.min()+xs.max())/2:.0f}, {(ys.min()+ys.max())/2:.0f})")

ios_sizes = {
    "AppStore-1024.png": 1024,
    "iPhone-180@3x.png": 180, "iPhone-120@2x.png": 120, "iPhone-87@3x-settings.png": 87,
    "iPad-167@2x.png": 167, "iPad-152@2x.png": 152, "iPad-76@1x.png": 76,
    "Notification-60@3x.png": 60, "Notification-40@2x.png": 40,
    "Spotlight-120.png": 120, "Spotlight-80.png": 80,
}
mac_sizes = {"Mac-1024.png": 1024, "Mac-512.png": 512, "Mac-256.png": 256, "Mac-128.png": 128}

for name, px in ios_sizes.items():
    phone.resize((px, px), Image.LANCZOS).save(OUT / name)
for name, px in mac_sizes.items():
    mac.resize((px, px), Image.LANCZOS).save(OUT / name)
print("re-exported ->", OUT)
