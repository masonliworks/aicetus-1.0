"""测量图标主体居中度：蓝色像素包围盒中心 vs 画布中心。"""
import numpy as np
from PIL import Image
from pathlib import Path

BASE = Path("/Users/lifengzhi/codex/对话项目/Projects/Active/dp远程/ui设计/design/icon-set-v6")
for name in ["AppStore-1024.png", "Mac-1024.png"]:
    img = np.asarray(Image.open(BASE / name).convert("RGB")).astype(np.float64)
    fg = img.min(axis=2) < 235          # 非白 = 蓝色主体
    ys, xs = np.where(fg)
    cx, cy = xs.mean(), ys.mean()
    x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
    print(f"{name}:")
    print(f"  bbox: x {x0}~{x1} (宽{x1-x0}), y {y0}~{y1} (高{y1-y0})")
    print(f"  包围盒中心: ({(x0+x1)/2:.0f}, {(y0+y1)/2:.0f}) vs 画布中心 (512, 512)")
    print(f"  质心: ({cx:.0f}, {cy:.0f})")
    print(f"  左右留白: {x0} / {1023-x1} | 上下留白: {y0} / {1023-y1}")
