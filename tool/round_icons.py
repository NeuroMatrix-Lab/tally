from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(r"D:\Project\tally")
RADIUS_RATIO = 0.22  # 现代桌面/移动图标常见的圆角比例


def rounded_icon(src: Path, radius_ratio: float = RADIUS_RATIO) -> Image.Image:
    im = Image.open(src).convert("RGBA")
    w, h = im.size
    radius = max(1, int(min(w, h) * radius_ratio))

    mask = Image.new("L", (w, h), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, w - 1, h - 1), radius=radius, fill=255)

    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    out.paste(im, (0, 0), mask)
    return out


def save_png(src: Path) -> None:
    out = rounded_icon(src)
    out.save(src, format="PNG", optimize=True)
    print(f"png  {src}  {out.size}")


def save_ico(src: Path) -> None:
    base = Image.open(src)
    # 收集现有尺寸，不足则从最大图生成常见 ICO 尺寸
    sizes = sorted({im.size[0] for im in getattr(base, "ico", None) and [] or []})
    try:
        frames = []
        # PIL ico 读取：逐尺寸取出
        i = 0
        while True:
            try:
                base.size = base.size  # noqa: B018  keep mypy quiet
                break
            except Exception:
                break
        # 直接枚举 ICO 内嵌尺寸
        sizes = []
        with Image.open(src) as im:
            n = getattr(im, "n_frames", 1)
            for idx in range(n):
                im.seek(idx)
                sizes.append(im.size)
        if not sizes:
            sizes = [(im.size)]
        frames = []
        for size in sizes:
            with Image.open(src) as im:
                # 尝试打开对应帧
                found = False
                n = getattr(im, "n_frames", 1)
                for idx in range(n):
                    im.seek(idx)
                    if im.size == size:
                        layer = rounded_icon_from_image(im.convert("RGBA"))
                        frames.append(layer)
                        found = True
                        break
                if not found:
                    layer = rounded_icon(src)
                    frames.append(layer)
        # 若只有一帧，补齐标准 ICO 尺寸
        if len(frames) == 1:
            master = frames[0]
            frames = [
                master.resize((s, s), Image.Resampling.LANCZOS)
                for s in (16, 24, 32, 48, 64, 128, 256)
                if s <= max(master.size)
            ] or frames
        frames[0].save(
            src,
            format="ICO",
            sizes=[(im.width, im.height) for im in frames],
            append_images=frames[1:] if len(frames) > 1 else None,
        )
        print(f"ico  {src}  frames={[im.size for im in frames]}")
    except Exception as e:
        # 退回：用最大尺寸圆角后重写 ICO
        im = Image.open(src).convert("RGBA")
        side = max(im.size)
        if im.size[0] != im.size[1]:
            canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
            canvas.paste(im, ((side - im.size[0]) // 2, (side - im.size[1]) // 2), im)
            im = canvas
        out = rounded_icon_from_image(im)
        out.save(src, format="ICO", sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
        print(f"ico  {src}  fallback from {im.size}, err={e}")


def rounded_icon_from_image(im: Image.Image, radius_ratio: float = RADIUS_RATIO) -> Image.Image:
    im = im.convert("RGBA")
    w, h = im.size
    radius = max(1, int(min(w, h) * radius_ratio))
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, w - 1, h - 1), radius=radius, fill=255)
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    out.paste(im, (0, 0), mask)
    return out


def collect_targets() -> list[Path]:
    patterns = [
        "android/app/src/main/res/mipmap-*/ic_launcher.png",
        "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-*.png",
        "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_*.png",
        "web/favicon.png",
        "web/icons/Icon-*.png",
        "windows/runner/resources/app_icon.ico",
    ]
    files: list[Path] = []
    for pat in patterns:
        files.extend(ROOT.glob(pat))
    # 去重、保持稳定顺序
    return sorted({p.resolve() for p in files if p.is_file()})


def main() -> int:
    targets = collect_targets()
    if not targets:
        print("no icons found", file=sys.stderr)
        return 1
    for path in targets:
        if path.suffix.lower() == ".ico":
            save_ico(path)
        else:
            save_png(path)
    print(f"done: {len(targets)} files")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
