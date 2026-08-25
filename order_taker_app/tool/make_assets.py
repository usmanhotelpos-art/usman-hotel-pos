# -*- coding: utf-8 -*-
"""Generate Usman Hotel logo, BBQ scene and order-taker artwork + Android icons."""
import math
import os
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "assets", "img")
RES = os.path.join(ROOT, "android", "app", "src", "main", "res")
os.makedirs(ASSETS, exist_ok=True)

GOLD = (245, 197, 66)
GOLD_DK = (198, 146, 20)
EMERALD = (16, 185, 129)
EMERALD_DK = (5, 120, 85)
DARK = (2, 6, 23)
SLATE = (15, 23, 42)

FONTS = [
    r"C:\Windows\Fonts\ariblk.ttf",   # Arial Black
    r"C:\Windows\Fonts\arialbd.ttf",  # Arial Bold
    r"C:\Windows\Fonts\impact.ttf",
]
def font(size, idx=0):
    for p in FONTS[idx:]:
        if os.path.exists(p):
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()

def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))

def radial_gradient(size, inner, outer, cx=0.5, cy=0.42, radius=1.05):
    w, h = size
    img = Image.new("RGB", size)
    px = img.load()
    maxd = math.hypot(max(cx, 1 - cx), max(cy, 1 - cy)) * radius
    for y in range(h):
        for x in range(w):
            d = math.hypot((x / w) - cx, (y / h) - cy) / maxd
            px[x, y] = lerp(inner, outer, min(1.0, d))
    return img

# ----------------------------------------------------------------- logo ----
def draw_flame(d, cx, cy, s):
    """Stylised BBQ flame: layered teardrops."""
    def tear(rx, ry, top_dy, col):
        pts = []
        for i in range(73):
            ang = math.pi * i / 36
            x = rx * math.sin(ang)
            y = -ry * math.cos(ang)
            if ang > math.pi / 2:
                k = (ang - math.pi / 2) / (math.pi / 2)
                y += ry * 0.55 * k
            pts.append((cx + x, cy + top_dy + y))
        for i in range(37):
            ang = math.pi * i / 36
            x = rx * 0.72 * math.sin(ang)
            y = ry * 0.5 + ry * 0.45 * math.cos(ang)
            pts.append((cx + x, cy + top_dy + ry * 0.28 + y))
        d.polygon(pts, fill=col)
    tear(s * 0.52, s * 0.78, -s * 0.10, EMERALD_DK)
    tear(s * 0.40, s * 0.60, s * 0.02, GOLD_DK)
    tear(s * 0.26, s * 0.40, s * 0.12, GOLD)
    tear(s * 0.13, s * 0.21, s * 0.22, (255, 244, 214))

def draw_skewers(d, cx, cy, s):
    """Two crossed BBQ skewers behind the flame."""
    for dx in (-1, 1):
        x0, y0 = cx + dx * s * 0.95, cy - s * 0.62
        x1, y1 = cx - dx * s * 0.95, cy + s * 0.58
        d.line([(x0, y0), (x1, y1)], fill=(120, 113, 108), width=int(s * 0.075))
        # kebab cubes along the stick
        for t in (0.30, 0.46, 0.62):
            kx = x0 + (x1 - x0) * t
            ky = y0 + (y1 - y0) * t
            r = s * 0.115
            d.rounded_rectangle([kx - r, ky - r * 0.8, kx + r, ky + r * 0.8],
                                radius=int(r * 0.45),
                                fill=lerp(GOLD, (180, 83, 9), t))

def make_logo(out_path, px=1024):
    S = 4  # supersample
    W = px * S
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    m = int(W * 0.03)                       # outer margin
    ring_box = [m, m, W - m, W - m]

    # gold outer ring
    d.ellipse(ring_box, fill=GOLD_DK)
    rb = [int(W*0.042)] * 2 + [W - int(W*0.042)] * 2
    d.ellipse(rb, outline=GOLD, width=int(W * 0.018))

    # dark face
    face = radial_gradient((W, W), SLATE, DARK).convert("RGBA")
    mask = Image.new("L", (W, W), 0)
    dm = ImageDraw.Draw(mask)
    fb = [int(W*0.062)] * 2 + [W - int(W*0.062)] * 2
    dm.ellipse(fb, fill=255)
    img.paste(face, (0, 0), mask)

    # emerald arc accent on lower part of the ring
    acc = [int(W*0.050)] * 2 + [W - int(W*0.050)] * 2
    d.arc(acc, start=25, end=155, fill=EMERALD, width=int(W * 0.02))

    cx, cy = W / 2, W * 0.40
    s = W * 0.30
    draw_skewers(d, cx, cy + s * 0.15, s * 1.35)
    draw_flame(d, cx, cy, s)

    # text
    f1 = font(int(W * 0.135))
    f2 = font(int(W * 0.085))
    f3 = font(int(W * 0.038), idx=1)
    def ctext(y, fnt, txt, fill, tracking=0):
        if tracking:
            widths = [d.textlength(ch, font=fnt) + tracking for ch in txt]
            total = sum(widths) - tracking
            x = (W - total) / 2
            for ch, wd in zip(txt, widths):
                d.text((x, y), ch, font=fnt, fill=fill)
                x += wd
        else:
            tw = d.textlength(txt, font=fnt)
            d.text(((W - tw) / 2, y), txt, font=fnt, fill=fill)
    ctext(W * 0.615, f1, "USMAN", GOLD, tracking=W * 0.006)
    ctext(W * 0.765, f2, "HOTEL", (241, 245, 249))
    ctext(W * 0.885, f3, "•  B B Q   &   R E S T A U R A N T  •", (148, 163, 184))

    img = img.resize((px, px), Image.LANCZOS)
    img.save(out_path)
    return img

# ------------------------------------------------------- launcher icons ----
def rounded_icon(src, out, corner_ratio=0.18):
    """Full-bleed rounded-square icon from a square source."""
    S = src.width
    bg = Image.new("RGBA", (S, S), DARK + (255,))
    # subtle vertical gradient
    grad = Image.new("L", (1, S))
    for y in range(S):
        grad.putpixel((0, y), int(40 + 60 * y / S))
    grad = grad.resize((S, S))
    dark_layer = Image.new("RGBA", (S, S), (7, 12, 32, 255))
    bg = Image.composite(dark_layer, bg, grad)
    pad = int(S * 0.09)
    icon = src.resize((S - 2 * pad, S - 2 * pad), Image.LANCZOS)
    bg.alpha_composite(icon, (pad, pad))
    mask = Image.new("L", (S, S), 0)
    dm = ImageDraw.Draw(mask)
    dm.rounded_rectangle([0, 0, S - 1, S - 1], radius=int(S * corner_ratio), fill=255)
    out_img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    out_img.paste(bg, (0, 0), mask)
    out_img.save(out)

def adaptive_foreground(src, out, px=432):
    """Adaptive-icon foreground: logo in the middle ~66% safe zone."""
    fg = Image.new("RGBA", (px, px), (0, 0, 0, 0))
    side = int(px * 0.62)
    icon = src.resize((side, side), Image.LANCZOS)
    fg.alpha_composite(icon, ((px - side) // 2, (px - side) // 2))
    fg.save(out)

MIPMAP_SIZES = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}

def write_icons(logo):
    for dpi, size in MIPMAP_SIZES.items():
        folder = os.path.join(RES, "mipmap-" + dpi)
        os.makedirs(folder, exist_ok=True)
        big = logo.resize((512, 512), Image.LANCZOS)
        rounded_icon(big, os.path.join(folder, "ic_launcher.png"), 0.22)
        rounded_icon(big, os.path.join(folder, "ic_launcher_round.png"), 0.5)
    fg_folder = os.path.join(RES, "mipmap-xxxhdpi")
    adaptive_foreground(logo.resize((1024, 1024), Image.LANCZOS),
                        os.path.join(fg_folder, "ic_launcher_foreground.png"))

# ------------------------------------------------------------ bbq scene ----
def make_bbq_scene(path, w=1080, h=1620):
    S = 1
    img = radial_gradient((w, h), (44, 26, 12), (5, 4, 8), cy=0.68).convert("RGBA")
    ov = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)

    rng = __import__("random")
    rng.seed(7)

    # hanging warm bokeh lights
    for _ in range(26):
        x, y = rng.randint(0, w), rng.randint(0, int(h * 0.42))
        r = rng.randint(4, 14)
        glow = Image.new("RGBA", (r * 6, r * 6), (0, 0, 0, 0))
        gd = ImageDraw.Draw(glow)
        gd.ellipse([r * 2, r * 2, r * 4, r * 4], fill=(255, 196, 90, 190))
        gd.ellipse([r * 2 - r, r * 2 - r, r * 4 + r, r * 4 + r], fill=(255, 160, 50, 60))
        glow = glow.filter(ImageFilter.GaussianBlur(r * 0.8))
        ov.alpha_composite(glow, (x - r * 3, y - r * 3))

    # grill pit
    pit_cx, pit_cy = w // 2, int(h * 0.70)
    pit_w, pit_h = int(w * 0.86), int(h * 0.16)
    # coals glow
    glow = Image.new("RGBA", (pit_w * 2, pit_h * 6), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gw, gh = glow.size
    for i, (col, a) in enumerate([((255, 120, 20), 150), ((255, 170, 40), 130), ((255, 220, 120), 90)]):
        rr = int(min(gw, gh) * (0.42 - i * 0.11))
        gd.ellipse([gw//2 - rr*2, gh//2 - rr//1, gw//2 + rr*2, gh//2 + rr], fill=col + (a,))
    glow = glow.filter(ImageFilter.GaussianBlur(48))
    img.alpha_composite(glow, (pit_cx - gw // 2, pit_cy - gh // 2))

    # grill body
    d.rounded_rectangle([pit_cx - pit_w//2, pit_cy - pit_h//2,
                         pit_cx + pit_w//2, pit_cy + pit_h//2],
                        radius=40, fill=(24, 18, 14, 235),
                        outline=(80, 50, 24, 255), width=6)
    # charcoal
    for _ in range(90):
        x = rng.randint(pit_cx - pit_w//2 + 30, pit_cx + pit_w//2 - 30)
        y = rng.randint(pit_cy - pit_h//2 + 24, pit_cy + pit_h//2 - 24)
        r = rng.randint(8, 20)
        hot = rng.random()
        col = lerp((25, 20, 18), (255, 140 + int(60 * hot), 30), hot ** 1.6)
        d.ellipse([x - r, y - r * 0.7, x + r, y + r * 0.7], fill=col + (255,))

    # skewers laying over the grill with kebab cubes + flames licking up
    def skewer(x0, y0, x1, y1):
        d.line([(x0, y0), (x1, y1)], fill=(154, 140, 125, 255), width=14)
        n = 5
        for k in range(n):
            t = 0.18 + 0.64 * k / (n - 1)
            kx = x0 + (x1 - x0) * t
            ky = y0 + (y1 - y0) * t
            rw, rh = 46, 34
            d.rounded_rectangle([kx - rw, ky - rh, kx + rw, ky + rh], radius=16,
                                fill=lerp((196, 100, 30), (232, 168, 60), rng.random()) + (255,),
                                outline=(90, 40, 10, 255), width=4)
    skewer(int(w*0.16), int(h*0.655), int(w*0.84), int(h*0.63))
    skewer(int(w*0.20), int(h*0.715), int(w*0.88), int(h*0.70))

    # little flames above coals
    for fx in range(pit_cx - pit_w//2 + 40, pit_cx + pit_w//2 - 40, 56):
        fh = rng.randint(50, 130)
        fl = rng.randint(18, 30)
        fy = pit_cy - pit_h//2
        flame = Image.new("RGBA", (fl * 4, fh * 2), (0, 0, 0, 0))
        fd = ImageDraw.Draw(flame)
        fw, fhh = flame.size
        pts = [(fw/2, 4)]
        for i in range(1, 13):
            yy = 4 + (fhh - 20) * i / 12
            ww = fl * (1 - i / 13) * (1 + 0.3 * math.sin(i * 2.1))
            pts.append((fw/2 + ww, yy))
        for i in range(12, -1, -1):
            yy = 4 + (fhh - 20) * i / 12
            ww = fl * (1 - i / 13) * (1 - 0.3 * math.sin(i * 1.7))
            pts.append((fw/2 - ww, yy))
        fd.polygon(pts, fill=(255, 150, 40, 210))
        fd.polygon([(p[0] * 0.55 + fw * 0.22, p[1] * 0.75 + fhh * 0.12) for p in pts],
                   fill=(255, 220, 110, 200))
        flame = flame.filter(ImageFilter.GaussianBlur(2))
        img.alpha_composite(flame, (fx - fw//2, fy - fhh + 30))

    # smoke wisps
    smoke = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    sd = ImageDraw.Draw(smoke)
    for _ in range(14):
        sx, sy = rng.randint(0, w), rng.randint(int(h*0.30), int(h*0.60))
        sr = rng.randint(40, 110)
        sd.ellipse([sx - sr, sy - sr//2, sx + sr, sy + sr//2], fill=(200, 200, 210, 16))
    smoke = smoke.filter(ImageFilter.GaussianBlur(38))
    img.alpha_composite(smoke)

    img.alpha_composite(ov)
    img.convert("RGB").save(path, quality=88)
    return img

# ------------------------------------------------------- order taker art ----
def make_order_taker(path, w=720, h=900):
    S = 2
    W, H = w * S, h * S
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    skin = (240, 190, 150)
    vest = EMERALD_DK
    shirt = (238, 242, 246)

    cx = W / 2
    # body / torso
    torso_top = H * 0.42
    d.rounded_rectangle([cx - W*0.27, torso_top, cx + W*0.27, H*1.05],
                        radius=int(W*0.16), fill=shirt + (255,))
    # vest panels
    d.polygon([(cx - W*0.30, torso_top + H*0.02), (cx - W*0.06, torso_top + H*0.02),
               (cx - W*0.10, H*0.98), (cx - W*0.33, H*0.98)], fill=vest + (255,))
    d.polygon([(cx + W*0.30, torso_top + H*0.02), (cx + W*0.06, torso_top + H*0.02),
               (cx + W*0.10, H*0.98), (cx + W*0.33, H*0.98)], fill=vest + (255,))
    # shirt collar V
    d.polygon([(cx - W*0.085, torso_top), (cx + W*0.085, torso_top), (cx, torso_top + H*0.09)],
              fill=(203, 213, 225, 255))
    # bow tie
    bw, bh = W * 0.075, H * 0.030
    by = torso_top + H * 0.012
    d.polygon([(cx - bw, by), (cx - 6*S, by - bh), (cx - 6*S, by + bh)], fill=GOLD + (255,))
    d.polygon([(cx + bw, by), (cx + 6*S, by - bh), (cx + 6*S, by + bh)], fill=GOLD + (255,))
    d.ellipse([cx - 10*S, by - 10*S, cx + 10*S, by + 10*S], fill=GOLD_DK + (255,))

    # head
    hr = W * 0.145
    hy = H * 0.24
    d.ellipse([cx - hr, hy - hr, cx + hr, hy + hr], fill=skin + (255,))
    # hair cap
    d.pieslice([cx - hr, hy - hr - 8*S, cx + hr, hy + hr * 0.55], start=180, end=360,
               fill=(30, 27, 26, 255))
    # ears
    d.ellipse([cx - hr - 12*S, hy - 14*S, cx - hr + 14*S, hy + 14*S], fill=skin + (255,))
    d.ellipse([cx + hr - 14*S, hy - 14*S, cx + hr + 12*S, hy + 14*S], fill=skin + (255,))
    # eyes
    er = 7.5 * S
    d.ellipse([cx - hr*0.42 - er, hy - 6*S - er, cx - hr*0.42 + er, hy - 6*S + er], fill=(15, 23, 42, 255))
    d.ellipse([cx + hr*0.42 - er, hy - 6*S - er, cx + hr*0.42 + er, hy - 6*S + er], fill=(15, 23, 42, 255))
    # brows
    d.line([(cx - hr*0.60, hy - hr*0.30), (cx - hr*0.20, hy - hr*0.38)], fill=(30, 27, 26, 255), width=8*S)
    d.line([(cx + hr*0.20, hy - hr*0.38), (cx + hr*0.60, hy - hr*0.30)], fill=(30, 27, 26, 255), width=8*S)
    # smile
    d.arc([cx - hr*0.38, hy + hr*0.10, cx + hr*0.38, hy + hr*0.55], start=15, end=165,
          fill=(120, 53, 40, 255), width=9*S)

    # left arm holding clipboard
    d.rounded_rectangle([cx - W*0.40, torso_top + H*0.05, cx - W*0.22, torso_top + H*0.34],
                        radius=int(W*0.09), fill=vest + (255,))
    d.ellipse([cx - W*0.43, torso_top + H*0.29, cx - W*0.31, torso_top + H*0.41], fill=skin + (255,))

    # clipboard
    cb_w, cb_h = W * 0.34, H * 0.30
    cb_x, cb_y = cx - W*0.52, torso_top + H*0.16
    d.rounded_rectangle([cb_x, cb_y, cb_x + cb_w, cb_y + cb_h], radius=18*S,
                        fill=(120, 78, 40, 255), outline=(87, 55, 26, 255), width=6*S)
    d.rounded_rectangle([cb_x + 12*S, cb_y + 12*S, cb_x + cb_w - 12*S, cb_y + cb_h - 12*S],
                        radius=10*S, fill=(250, 250, 245, 255))
    d.rounded_rectangle([cb_x + cb_w*0.32, cb_y - 12*S, cb_x + cb_w*0.68, cb_y + 16*S],
                        radius=8*S, fill=(87, 55, 26, 255))
    for i in range(5):
        ly = cb_y + cb_h * (0.16 + 0.14 * i)
        d.line([(cb_x + cb_w*0.14, ly), (cb_x + cb_w*(0.86 if i % 2 == 0 else 0.62), ly)],
               fill=(148, 163, 184, 255), width=6*S)
    # pen tick
    d.line([(cb_x + cb_w*0.18, cb_y + cb_h*0.82), (cb_x + cb_w*0.28, cb_y + cb_h*0.92),
            (cb_x + cb_w*0.50, cb_y + cb_h*0.62)], fill=EMERALD + (255,), width=8*S, joint="curve")

    # right arm raised holding pen to pad
    d.rounded_rectangle([cx + W*0.22, torso_top + H*0.05, cx + W*0.40, torso_top + H*0.28],
                        radius=int(W*0.09), fill=vest + (255,))
    d.ellipse([cx + W*0.34, torso_top + H*0.23, cx + W*0.46, torso_top + H*0.35], fill=skin + (255,))
    # pen
    d.line([(cx + W*0.42, torso_top + H*0.30), (cx + W*0.30, torso_top + H*0.40)],
           fill=(30, 41, 59, 255), width=10*S)

    # name badge
    d.rounded_rectangle([cx + W*0.10, torso_top + H*0.16, cx + W*0.24, torso_top + H*0.24],
                        radius=8*S, fill=GOLD + (255,))

    img = img.resize((w, h), Image.LANCZOS)
    img.save(path)
    return img

if __name__ == "__main__":
    logo = make_logo(os.path.join(ASSETS, "logo.png"))
    write_icons(logo)
    make_bbq_scene(os.path.join(ASSETS, "bbq_bg.jpg"))
    make_order_taker(os.path.join(ASSETS, "order_taker.png"))
    print("assets generated OK")
