"""Logo v6 清洗：破屏鲸「皇家蓝纯色」双端版。
构图已定稿（白底 + #2563EB 纯色主体），无灰画布、无可见水印。
处理：近白底归一纯白（mn>235 → 255），主体边缘抗锯齿保留。
输出：iOS 全套（手机版）+ Mac 尺寸（Mac 版）→ design/icon-set-v6/
"""
import numpy as np
from PIL import Image
from pathlib import Path

BASE = Path("/Users/lifengzhi/codex/对话项目/Projects/Active/dp远程/ui设计")
OUT = BASE / "design/icon-set-v6"
OUT.mkdir(parents=True, exist_ok=True)


def normalize_bg(src: str) -> Image.Image:
    img = np.asarray(Image.open(src).convert("RGB")).astype(np.float64)
    bg = img.min(axis=2) > 235
    img[bg] = 255.0
    print(f"  bg normalized: {int(bg.sum())} px")
    return Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).resize((1024, 1024), Image.LANCZOS)


print("iOS 版（皇家蓝·手机）:")
phone = normalize_bg(str(BASE / "generated-images/logo-v6-phone-royalblue-raw.png"))
print("Mac 版（皇家蓝·MacBook）:")
mac = normalize_bg(str(BASE / "generated-images/logo-v6-mac-royalblue-raw.png"))

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
print("exported", len(ios_sizes), "+", len(mac_sizes), "icons ->", OUT)
