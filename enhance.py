"""Enhance the client's property photos for the website.

All photos live in the user profile Pictures\Screenshots folder (property
photos taken 2026-10-05). Nothing is used from the UI 'paste' cache.
"""

import os
from pathlib import Path

from PIL import Image, ImageEnhance, ImageFilter

USER = os.path.expandvars(r"%USERPROFILE%")
SRC = Path(USER) / "Pictures" / "Screenshots"
OUT = Path(r"C:\Users\Krushna Kale\Desktop\Projects\Project 5\public\images")
OUT.mkdir(parents=True, exist_ok=True)

# (name, source file, max width, unsharp radius)
PHOTOS = [
    ("pp-entrance-fountain", "Screenshot 2026-10-05 204135.png", 1400, 1.6),
    ("pp-lawn-dining", "Screenshot 2026-10-05 204239.png", 1400, 1.6),
    ("pp-signboard-outdoor", "Screenshot 2026-10-05 204316.png", 1100, 1.6),
    ("pp-open-garden-dusk", "Screenshot 2026-10-05 203802.png", 1100, 1.4),
    ("pp-sunset-teal-roof", "Screenshot 2026-10-05 203821.png", 1100, 1.4),
    ("pp-interior-walkway", "Screenshot 2026-10-05 203838.png", 1100, 1.4),
]


def enhance(im: Image.Image, radius: float) -> Image.Image:
    im = im.resize((im.width * 2, im.height * 2), Image.LANCZOS)
    im = ImageEnhance.Contrast(im).enhance(1.12)
    im = ImageEnhance.Sharpness(im).enhance(1.5)
    im = im.filter(ImageFilter.UnsharpMask(radius=radius, percent=90, threshold=2))
    im = ImageEnhance.Color(im).enhance(1.06)
    im = ImageEnhance.Contrast(im).enhance(1.05)
    return im


def main() -> None:
    for name, src, max_w, radius in PHOTOS:
        p = SRC / src
        if not p.exists():
            print(f"MISSING {p}")
            continue
        im = Image.open(p)
        if im.mode not in ("RGB", "L"):
            im = im.convert("RGB")
        im = enhance(im, radius)
        if im.width > max_w:
            im = im.resize((max_w, round(im.height * max_w / im.width)), Image.LANCZOS)
        out = OUT / f"{name}.jpg"
        im.save(out, "JPEG", quality=92, subsampling=0, optimize=True)
        print(f"ok   {out.name}  {im.size[0]}x{im.size[1]}  {out.stat().st_size//1024} KB")

    # Logo: crisp 2x, alpha kept.
    logo = Image.open(r"C:\Users\Krushna Kale\Downloads\Palm Paradise Logo with Palm Tree.png")
    if logo.mode in ("RGBA", "LA", "P"):
        logo = logo.convert("RGBA")
        bg = Image.new("RGBA", logo.size, (255, 255, 255, 0))
        bg.paste(logo, mask=logo.split()[-1])
        logo = bg
    logo = logo.resize((round(logo.width * 2), round(logo.height * 2)), Image.LANCZOS)
    logo.save(OUT / "logo.png", "PNG", optimize=True)
    print(f"ok   logo.png  {logo.size[0]}x{logo.size[1]}  RGBA logo")


if __name__ == "__main__":
    main()
