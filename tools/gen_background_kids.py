from PIL import Image, ImageDraw
import math
import random

WIDTH = 1080
HEIGHT = 2160

SKY_TOP = (110, 198, 255)
SKY_MID = (154, 220, 255)
SKY_BOTTOM = (189, 234, 255)
INK = (27, 27, 27, 255)
WHITE = (255, 255, 255, 255)
SUN = (255, 217, 74, 255)
HILL_A = (126, 217, 87, 255)
HILL_B = (87, 194, 58, 255)

random.seed(7)

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


def draw_sun(cx, cy, r):
    for i in range(16):
        a = i * (2 * math.pi / 16)
        x1, y1 = cx + math.cos(a) * (r + 6), cy + math.sin(a) * (r + 6)
        x2, y2 = cx + math.cos(a) * (r + 34), cy + math.sin(a) * (r + 34)
        d.line((x1, y1, x2, y2), fill=SUN, width=10)
    outline_ellipse((cx - r, cy - r, cx + r, cy + r), SUN)


def draw_cloud(cx, cy, scale):
    parts = [(-46, 0, 50), (-4, -26, 36), (36, -6, 30), (0, 10, 40)]
    for dx, dy, r in parts:
        rr = r * scale
        outline_ellipse((cx + dx * scale - rr, cy + dy * scale - rr, cx + dx * scale + rr, cy + dy * scale + rr), WHITE)


def draw_hills():
    d.ellipse((-260, HEIGHT - 340, WIDTH * 0.62, HEIGHT + 260), fill=HILL_A, outline=INK, width=6)
    d.ellipse((WIDTH * 0.28, HEIGHT - 260, WIDTH + 260, HEIGHT + 300), fill=HILL_B, outline=INK, width=6)


draw_sun(WIDTH - 150, 210, 84)
draw_cloud(190, 330, 1.15)
draw_cloud(WIDTH - 260, 520, 0.85)
draw_cloud(140, 900, 0.7)
draw_cloud(WIDTH - 170, 1150, 1.0)
draw_hills()


# ---- Original mascots (not based on any existing character), scattered
# faintly as watermarks the same way the other themes use dice/board icons.

def draw_dino(cx, cy, scale, opacity):
    a = int(255 * opacity)
    fill = (143, 224, 106, a)
    spike_fill = (87, 194, 58, a)
    ink = (27, 27, 27, a)
    def sc(v):
        return v * scale
    # body
    d.ellipse((cx - sc(50), cy - sc(6), cx + sc(30), cy + sc(54)), fill=fill, outline=ink, width=4)
    # head
    d.ellipse((cx + sc(6), cy - sc(52), cx + sc(70), cy + sc(8)), fill=fill, outline=ink, width=4)
    # eye
    d.ellipse((cx + sc(46), cy - sc(32), cx + sc(56), cy - sc(22)), fill=ink)
    # back spikes
    d.polygon([(cx - sc(10), cy - sc(44)), (cx, cy - sc(62)), (cx + sc(12), cy - sc(42))], fill=spike_fill, outline=ink, width=3)
    d.polygon([(cx + sc(10), cy - sc(50)), (cx + sc(22), cy - sc(68)), (cx + sc(32), cy - sc(48))], fill=spike_fill, outline=ink, width=3)
    # little leg
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
    (draw_dino, 160, 620, 0.9),
    (draw_star_buddy, WIDTH - 150, 780, 1.0),
    (draw_bear, 130, 1350, 1.1),
    (draw_star_buddy, WIDTH - 200, 1620, 0.75),
    (draw_dino, WIDTH - 130, 1950, 0.8),
]
for fn, x, y, s in mascots:
    fn(x, y, s, 0.5)

img.convert("RGB").save("../assets/background/ludo_background_kids.png", quality=95)
print("Saved: ../assets/background/ludo_background_kids.png")
