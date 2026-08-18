from PIL import Image, ImageDraw
import math
import random

WIDTH = 1080
HEIGHT = 2160

SKY_TOP = (28, 36, 80)
SKY_MID = (58, 47, 110)
SKY_BOTTOM = (90, 58, 122)
INK = (27, 27, 27, 255)
MOON = (255, 233, 168, 255)
CLOUD = (122, 106, 168, 255)
STAR = (255, 233, 168, 255)

random.seed(11)

img = Image.new("RGBA", (WIDTH, HEIGHT), SKY_TOP + (255,))
px = img.load()
for y in range(HEIGHT):
    t = y / (HEIGHT - 1)
    if t <= 0.55:
        t2 = t / 0.55
        r = int(SKY_TOP[0] * (1 - t2) + SKY_MID[0] * t2)
        g = int(SKY_TOP[1] * (1 - t2) + SKY_MID[1] * t2)
        b = int(SKY_TOP[2] * (1 - t2) + SKY_MID[2] * t2)
    else:
        t2 = (t - 0.55) / 0.45
        r = int(SKY_MID[0] * (1 - t2) + SKY_BOTTOM[0] * t2)
        g = int(SKY_MID[1] * (1 - t2) + SKY_BOTTOM[1] * t2)
        b = int(SKY_MID[2] * (1 - t2) + SKY_BOTTOM[2] * t2)
    for x in range(WIDTH):
        px[x, y] = (r, g, b, 255)

d = ImageDraw.Draw(img)


def outline_ellipse(box, fill):
    d.ellipse(box, fill=fill, outline=INK, width=6)


def draw_moon(cx, cy, r):
    outline_ellipse((cx - r, cy - r, cx + r, cy + r), MOON)
    # crescent cutout -- a smaller offset circle painted in the sky's own
    # top color, so it reads as a bite taken out of the moon
    cut_r = r * 0.82
    d.ellipse((cx - cut_r + r * 0.55, cy - cut_r, cx + cut_r + r * 0.55, cy + cut_r), fill=SKY_TOP + (255,))


def draw_cloud(cx, cy, scale):
    parts = [(-46, 0, 50), (-4, -26, 36), (36, -6, 30), (0, 10, 40)]
    for dx, dy, r in parts:
        rr = r * scale
        outline_ellipse((cx + dx * scale - rr, cy + dy * scale - rr, cx + dx * scale + rr, cy + dy * scale + rr), CLOUD)


def draw_star(cx, cy, size, filled=True):
    pts = []
    for i in range(8):
        ang = -math.pi / 2 + i * math.pi / 4
        r = size if i % 2 == 0 else size * 0.4
        pts.append((cx + math.cos(ang) * r, cy + math.sin(ang) * r))
    if filled:
        d.polygon(pts, fill=STAR, outline=INK, width=3)
    else:
        d.polygon(pts, outline=STAR)


draw_moon(WIDTH - 160, 220, 88)
draw_cloud(190, 380, 1.0)
draw_cloud(WIDTH - 260, 560, 0.75)
draw_cloud(150, 1520, 0.85)
draw_cloud(WIDTH - 200, 1780, 0.9)

# generous scatter of stars, a mix of bold outlined ones and tiny faint dots
big_star_positions = [
    (120, 150), (WIDTH - 380, 130), (500, 90), (760, 300), (300, 520),
    (900, 480), (150, 760), (820, 700), (480, 900), (700, 1050),
    (200, 1150), (900, 1250), (350, 1350), (620, 1500), (140, 1680),
    (850, 1900), (450, 2000), (700, 2080), (250, 1980), (950, 1700),
]
for x, y in big_star_positions:
    draw_star(x, y, random.randint(14, 24), filled=True)

for _ in range(60):
    x = random.randint(20, WIDTH - 20)
    y = random.randint(20, HEIGHT - 20)
    r = random.randint(2, 4)
    d.ellipse((x - r, y - r, x + r, y + r), fill=STAR + (180,) if len(STAR) == 3 else (255, 233, 168, 150))


# ---- Original mascots (not based on any existing character), scattered
# faintly as watermarks the same way the other themes use dice/board icons.

def draw_dino(cx, cy, scale, opacity):
    a = int(255 * opacity)
    fill = (143, 224, 106, a)
    spike_fill = (87, 194, 58, a)
    ink = (27, 27, 27, a)
    def sc(v):
        return v * scale
    d.ellipse((cx - sc(50), cy - sc(6), cx + sc(30), cy + sc(54)), fill=fill, outline=ink, width=4)
    d.ellipse((cx + sc(6), cy - sc(52), cx + sc(70), cy + sc(8)), fill=fill, outline=ink, width=4)
    d.ellipse((cx + sc(46), cy - sc(32), cx + sc(56), cy - sc(22)), fill=ink)
    d.polygon([(cx - sc(10), cy - sc(44)), (cx, cy - sc(62)), (cx + sc(12), cy - sc(42))], fill=spike_fill, outline=ink, width=3)
    d.polygon([(cx + sc(10), cy - sc(50)), (cx + sc(22), cy - sc(68)), (cx + sc(32), cy - sc(48))], fill=spike_fill, outline=ink, width=3)
    d.ellipse((cx - sc(22), cy + sc(40), cx - sc(2), cy + sc(58)), fill=fill, outline=ink, width=3)


def draw_star_buddy(cx, cy, scale, opacity):
    a = int(255 * opacity)
    fill = (255, 217, 74, a)
    ink = (27, 27, 27, a)
    pts = []
    for i in range(10):
        ang = -math.pi / 2 + i * math.pi / 5
        r = scale * (46 if i % 2 == 0 else 20)
        pts.append((cx + math.cos(ang) * r, cy + math.sin(ang) * r))
    d.polygon(pts, fill=fill, outline=ink, width=4)
    d.ellipse((cx - 8 * scale, cy - 2 * scale, cx - 3 * scale, cy + 3 * scale), fill=ink)
    d.ellipse((cx + 3 * scale, cy - 2 * scale, cx + 8 * scale, cy + 3 * scale), fill=ink)


def draw_bear(cx, cy, scale, opacity):
    a = int(255 * opacity)
    fill = (200, 138, 74, a)
    ink = (27, 27, 27, a)
    def sc(v):
        return v * scale
    d.ellipse((cx - sc(32), cy - sc(32), cx + sc(32), cy + sc(32)), fill=fill, outline=ink, width=4)
    d.ellipse((cx - sc(38), cy - sc(46), cx - sc(14), cy - sc(22)), fill=fill, outline=ink, width=4)
    d.ellipse((cx + sc(14), cy - sc(46), cx + sc(38), cy - sc(22)), fill=fill, outline=ink, width=4)
    d.ellipse((cx - sc(10), cy - sc(6), cx + sc(10), cy + sc(3)), fill=ink)


mascots = [
    (draw_dino, 160, 900, 0.85),
    (draw_star_buddy, WIDTH - 150, 1050, 0.9),
    (draw_bear, 140, 1600, 1.0),
    (draw_dino, WIDTH - 140, 1400, 0.75),
]
for fn, x, y, s in mascots:
    fn(x, y, s, 0.45)

img.convert("RGB").save("../assets/background/ludo_background_kids_night.png", quality=95)
print("Saved: ../assets/background/ludo_background_kids_night.png")
