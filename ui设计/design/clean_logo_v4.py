"""Logo v4 清洗：破屏鲸双端版（手机版 + Mac 版）。
v4 原图已是满版渐变（无灰画布、无内嵌框），唯一问题是右下角"AI生成"水印。
策略：裁剪法——水印位于右下角（约 x>88%, y>91%），
取 side=928 的方裁（x 48~976, y 0~928）完整避开水印，
主体居中偏差 <5% 可忽略，LANCZOS 上采样回 1024。
输出：iOS 全套尺寸（手机版）+ Mac 尺寸（Mac 版）→ design/icon-set-v4/
"""
from PIL import Image
from pathlib import Path

BASE = Path("/Users/lifengzhi/codex/对话项目/Projects/Active/dp远程/ui设计")
OUT = BASE / "design/icon-set-v4"
OUT.mkdir(parents=True, exist_ok=True)

CROP = (48, 0, 48 + 928, 928)   # left, top, right, bottom


def load_clean(src: str) -> Image.Image:
    img = Image.open(src).convert("RGB").crop(CROP)
    return img.resize((1024, 1024), Image.LANCZOS)


phone = load_clean(str(BASE / "generated-images/logo-v4-phone-bright-raw.png"))
mac = load_clean(str(BASE / "generated-images/logo-v4b-mac-samewhale-v2-raw.png"))

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
