#!/usr/bin/env python3
"""Generate Tahoe5's AppIcon set.

    python3 make_icons.py

Writes every PNG the asset catalog expects into
Sources/Assets.xcassets/AppIcon.appiconset/.

SOURCE RESOLUTION IS THE BINDING CONSTRAINT. The only logo art that exists is
342x342 (Web/assets/), and no higher-resolution original was found anywhere.
Nothing here invents detail. What it does do is minimise how far the logo has to
be stretched:

  * The background is drawn at full size — a radial felt gradient matching
    body{} in styles.css — so most of the icon is genuinely sharp at 1024.
  * The badge sits at INSET of the canvas rather than filling it, so at 1024 the
    logo is scaled ~1.9x instead of ~2.5x. It also reads better small, and
    macOS icons are conventionally inset rather than full-bleed.
  * A light unsharp mask counteracts the softening LANCZOS introduces when
    enlarging. Applied only when enlarging — downscaled sizes are already crisp.

For a genuinely sharp 1024 icon the logo needs regenerating at 1024x1024 from
whatever produced it. Drop that in as SOURCE and re-run; the rest still applies.

iOS app icons must be fully opaque — App Store Connect rejects an alpha channel
— so everything is composited onto the felt and saved as RGB.
"""

import pathlib
from PIL import Image, ImageFilter

SOURCE = pathlib.Path("Web/assets/tahoe-5-logo-1.png")
OUT = pathlib.Path("Sources/Assets.xcassets/AppIcon.appiconset")

FELT = (0x0B, 0x1F, 0x16)        # --bg from styles.css
FELT_HILITE = (0x1B, 0x49, 0x3B)  # gradient centre, matching the page
INSET = 0.66                      # fraction of the canvas the badge occupies

SIZES = [
    ("icon-16.png", 16),
    ("icon-32.png", 32),
    ("icon-64.png", 64),
    ("icon-128.png", 128),
    ("icon-256.png", 256),
    ("icon-512.png", 512),
    ("icon-1024.png", 1024),
]


def felt_background(size: int) -> Image.Image:
    """Radial gradient, drawn at full resolution so it is never upscaled.

    Built at 256 and enlarged when needed: a smooth gradient has no
    high-frequency detail to lose, so that is free.
    """
    g = 256
    grad = Image.new("RGB", (g, g), FELT)
    px = grad.load()
    cx, cy = g * 0.2, g * 0.2
    reach = g * 0.48 * (2 ** 0.5)
    for y in range(g):
        for x in range(g):
            d = min((((x - cx) ** 2 + (y - cy) ** 2) ** 0.5) / reach, 1.0)
            px[x, y] = tuple(
                round(FELT_HILITE[i] + (FELT[i] - FELT_HILITE[i]) * d) for i in range(3)
            )
    return grad.resize((size, size), Image.LANCZOS)


def render(size: int, logo: Image.Image) -> Image.Image:
    canvas = felt_background(size)
    edge = max(1, round(size * INSET))
    scaled = logo.resize((edge, edge), Image.LANCZOS)
    if edge > logo.width:
        # Only when enlarging; downscales are already crisp.
        scaled = scaled.filter(ImageFilter.UnsharpMask(radius=2, percent=110, threshold=3))
    offset = (size - edge) // 2
    canvas.paste(scaled, (offset, offset), scaled)
    return canvas


def main() -> None:
    if not SOURCE.exists():
        raise SystemExit(f"missing {SOURCE} — run this from the project root")

    OUT.mkdir(parents=True, exist_ok=True)
    logo = Image.open(SOURCE).convert("RGBA")

    for name, size in SIZES:
        render(size, logo).save(OUT / name)
        print(f"  {name:16} {size}x{size}")

    print(f"\nWrote {len(SIZES)} icons to {OUT}")
    if logo.width < 1024:
        scale = round(1024 * INSET / logo.width, 2)
        print(f"NOTE: source is {logo.width}x{logo.height}; the badge is enlarged "
              f"{scale}x at 1024. Regenerate the logo at 1024x1024 for a truly "
              f"sharp icon — see the docstring.")


if __name__ == "__main__":
    main()
