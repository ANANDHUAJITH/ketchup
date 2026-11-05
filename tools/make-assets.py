#!/usr/bin/env python3
"""Regenerate Ketchup's composited branding scenes from the icon mark.

    pip install cairosvg fonttools
    tools/make-assets.py [--icon logo-icon.svg] [--font Poppins-Bold.ttf]

Input (default = archiso/airootfs/usr/share/ketchup/logo-icon.svg):
    a single flat SVG, viewBox starting at "0 0", red/blue bottle-and-cape mark.
    Pass --mascots DIR (a dir with standing.svg) to fall back to the old mascot art.

Outputs: logo-icon.svg (+ .default), icon-theme copies, Calamares icon.png/welcome.png,
         KDE wallpapers, GRUB/syslinux splash, Limine wallpaper.
logo.svg / logo-light.svg / logo-blue*.svg and Calamares logo.png are hand-designed
and NOT touched by this script.
"""
import argparse, pathlib, re, shutil, sys

import cairosvg
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTFont

ROOT = pathlib.Path(__file__).resolve().parent.parent
AIR = ROOT / "archiso" / "airootfs"
BG, GLOW, RED, CREAM = "#14090a", "#3a0f10", "#e63a2e", "#f3e6dc"
DEFAULT_FONTS = [
    "/usr/share/fonts/truetype/google-fonts/Poppins-Bold.ttf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
]


def inner(svg_path):
    """Return (viewBox w, h, inner markup) of an SVG so it can be nested."""
    s = pathlib.Path(svg_path).read_text()
    m = re.search(r'viewBox="0 0 ([\d.]+) ([\d.]+)"', s)
    w, h = float(m.group(1)), float(m.group(2))
    body = re.sub(r"^.*?<svg[^>]*>", "", s, count=1, flags=re.S)
    body = body.rsplit("</svg>", 1)[0]
    body = re.sub(r"<title>.*?</title>", "", body, flags=re.S)
    return w, h, body


def nested(svg_path, x, y, height):
    w, h, body = inner(svg_path)
    scale = height / h
    xmlns = ' xmlns:xlink="http://www.w3.org/1999/xlink"'
    return (f'<svg x="{x:.1f}" y="{y:.1f}" width="{w*scale:.1f}" height="{height:.1f}" '
            f'viewBox="0 0 {w:g} {h:g}"{xmlns}>{body}</svg>'), w * scale


def text_path(font_file, text, size, x, y, fill, tracking=0):
    """Text -> SVG <path>, so the wordmark never depends on installed fonts."""
    font = TTFont(font_file)
    gs, cmap, hmtx = font.getGlyphSet(), font.getBestCmap(), font["hmtx"]
    scale = size / font["head"].unitsPerEm
    d, cx = [], x
    for ch in text:
        g = cmap[ord(ch)]
        pen = SVGPathPen(gs)
        gs[g].draw(TransformPen(pen, (scale, 0, 0, -scale, cx, y)))
        d.append(pen.getCommands())
        cx += hmtx[g][0] * scale + tracking
    return f'<path fill="{fill}" d="{" ".join(d)}"/>', cx - x


def write(path, data):
    path = pathlib.Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    if isinstance(data, str):
        path.write_text(data)
    else:
        path.write_bytes(data)
    print("  wrote", path.relative_to(ROOT))


def png(svg, out, w, h=None, bg=None):
    write(out, cairosvg.svg2png(bytestring=svg.encode(), output_width=w, output_height=h, background_color=bg))


def scene(w, h, body, glow=(0.5, 0.5), extra=""):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" '
            f'width="{w}" height="{h}" viewBox="0 0 {w} {h}">'
            f'<defs><radialGradient id="g" cx="{glow[0]}" cy="{glow[1]}" r="0.75">'
            f'<stop offset="0" stop-color="{GLOW}"/><stop offset="0.55" stop-color="#1d0b0c"/>'
            f'<stop offset="1" stop-color="{BG}"/></radialGradient></defs>'
            f'<rect width="{w}" height="{h}" fill="url(#g)"/>{extra}{body}</svg>')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--icon", default=str(AIR / "usr/share/ketchup/logo-icon.svg"),
                     help="single flat SVG (viewBox starting at 0 0) used as the mark "
                          "everywhere a big logo is composited. Defaults to the current "
                          "brand emblem; pass --mascots/old mascot svg here to go back to it.")
    ap.add_argument("--mascots", default=None, help="legacy: a mascot/ dir with standing.svg")
    ap.add_argument("--font", default=None)
    a = ap.parse_args()
    if a.mascots:
        stand = pathlib.Path(a.mascots) / "standing.svg"
    else:
        stand = pathlib.Path(a.icon)
    if not stand.exists():
        sys.exit(f"missing {stand}")
    font = a.font or next((f for f in DEFAULT_FONTS if pathlib.Path(f).exists()), None)
    if not font:
        sys.exit("no bold font found; pass --font")

    # NOTE: logo.svg / logo-light.svg / logo-blue*.svg are hand-designed assets
    # (not generated here) - this script only (re)composites scenes that use the
    # icon mark, plus propagates the icon mark into every icon-theme slot.

    # ---- square icon, copied into every icon-theme name ----------------------
    icon = stand.read_text()
    write(AIR / "usr/share/ketchup/logo-icon.svg", icon)
    write(AIR / "usr/share/ketchup/logo-icon.default.svg", icon)
    names_places = ["start-here-kde-plasma", "start-here-kde", "start-here-kde-symbolic", "start-here",
                    "start-here-ketchup", "distributor-logo", "distributor-logo-ketchup",
                    "distributor-logo-archlinux"]
    for n in names_places:
        write(AIR / f"usr/share/icons/ketchup/scalable/places/{n}.svg", icon)
    for n in ("ketchup-logo", "ketchup"):
        write(AIR / f"usr/share/icons/ketchup/scalable/apps/{n}.svg", icon)
    for n in ("ketchup-logo", "distributor-logo-ketchup"):
        write(AIR / f"usr/share/icons/hicolor/scalable/apps/{n}.svg", icon)

    # ---- Calamares branding -------------------------------------------------
    cal = AIR / "usr/share/calamares/branding/ketchup"
    logo_svg_path = AIR / "usr/share/ketchup/logo.svg"   # hand-designed, dark-bg variant
    png(logo_svg_path.read_text(), cal / "logo.png", 640)               # height follows aspect
    png(icon, cal / "icon.png", 128, 128)
    wel, _ = nested(stand, 0, 0, 220)
    png(scene(480, 220, wel, glow=(0.3, 0.5)).replace(f'fill="url(#g)"', 'fill="none"'), cal / "welcome.png", 480, 220)

    # ---- KDE wallpapers -----------------------------------------------------
    def wallpaper(w, h):
        mh = h * 0.78
        m, mwid = nested(stand, w * 0.5 + h * 0.02, h * 0.11, mh)
        wm, wmw = text_path(font, "ketchup", h * 0.17, w * 0.09, h * 0.56, CREAM, tracking=-3)
        halo = f'<ellipse cx="{w*0.66}" cy="{h*0.52}" rx="{h*0.42}" ry="{h*0.42}" fill="{RED}" opacity="0.10"/>'
        return scene(w, h, m + wm, glow=(0.66, 0.5), extra=halo)

    wp = AIR / "usr/share/wallpapers/Ketchup/contents/images"
    png(wallpaper(1920, 1080), wp / "1920x1080.png", 1920, 1080)
    png(wallpaper(3840, 2160), wp / "3840x2160.png", 3840, 2160)

    # ---- boot splash images (GRUB/syslinux scaffolding) ---------------------
    def splash(w, h):
        m, mwid = nested(stand, (w - h * 0.5) / 2, h * 0.06, h * 0.5)
        wm, wmw = text_path(font, "ketchup", h * 0.12, 0, h * 0.78, CREAM, tracking=-2)
        wm, wmw = text_path(font, "ketchup", h * 0.12, (w - wmw) / 2, h * 0.78, CREAM, tracking=-2)
        return scene(w, h, m + wm)
    png(splash(1920, 1080), AIR.parent / "syslinux/splash.png", 1920, 1080)
    png(splash(640, 480), AIR.parent / "syslinux/splash1.png", 640, 480)
    png(splash(1920, 1080), AIR.parent / "grub/splash.png", 1920, 1080)

    # ---- Limine wallpaper (dimmed so menu text stays readable) --------------
    w, h = 1280, 720
    m, _ = nested(stand, w - h * 0.76 - 40, h * 0.12, h * 0.76)
    dim = f'<rect width="{w}" height="{h}" fill="#000" opacity="0.35"/>'
    limg = scene(w, h, m + dim, glow=(0.8, 0.5))
    png(limg, AIR.parent / "limine/wallpaper.png", w, h)
    shutil.copy(AIR.parent / "limine/wallpaper.png", AIR / "usr/share/ketchup/limine-wallpaper.png")   # installed-system copy
    print("done")


if __name__ == "__main__":
    main()
