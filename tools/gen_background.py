from PIL import Image, ImageDraw, ImageFilter
import math
import random


# ============================================================
# SETTINGS
# ============================================================

WIDTH = 1080
HEIGHT = 2160

# Background -- navy
TOP_BLUE = (42, 62, 102)
BOTTOM_BLUE = (22, 36, 68)

# Watermark -- lighter than the navy base so it still reads against it
WATERMARK_BLUE = (110, 140, 195)
WHITE = (255, 255, 255)

random.seed(42)


# ============================================================
# 1. BLUE GRADIENT BACKGROUND
# ============================================================

background = Image.new(
    "RGBA",
    (WIDTH, HEIGHT),
    TOP_BLUE + (255,)
)

pixels = background.load()

for y in range(HEIGHT):

    t = y / (HEIGHT - 1)

    r = int(TOP_BLUE[0] * (1 - t) + BOTTOM_BLUE[0] * t)
    g = int(TOP_BLUE[1] * (1 - t) + BOTTOM_BLUE[1] * t)
    b = int(TOP_BLUE[2] * (1 - t) + BOTTOM_BLUE[2] * t)

    for x in range(WIDTH):
        pixels[x, y] = (r, g, b, 255)


# ============================================================
# 2. SOFT CENTER GLOW
# ============================================================

glow = Image.new(
    "RGBA",
    (WIDTH, HEIGHT),
    (0, 0, 0, 0)
)

gp = glow.load()

cx = WIDTH * 0.50
cy = HEIGHT * 0.40

max_distance = math.sqrt(
    (WIDTH / 2) ** 2 +
    (HEIGHT / 2) ** 2
)

for y in range(HEIGHT):
    for x in range(WIDTH):

        dx = x - cx
        dy = y - cy

        distance = math.sqrt(dx * dx + dy * dy)

        strength = max(
            0,
            1 - distance / max_distance
        )

        strength = strength ** 2

        alpha = int(45 * strength)

        gp[x, y] = (
            235,
            247,
            255,
            alpha
        )

background = Image.alpha_composite(
    background,
    glow
)


# ============================================================
# 3. HALFTONE DOTS
# ============================================================

dots = Image.new(
    "RGBA",
    (WIDTH, HEIGHT),
    (0, 0, 0, 0)
)

dd = ImageDraw.Draw(dots)

spacing = 32

# Top-left dots
for y in range(180, 550, spacing):
    for x in range(0, 270, spacing):

        distance = math.sqrt(
            x * x +
            (y - 180) ** 2
        )

        radius = max(
            2,
            int(8 - distance / 100)
        )

        alpha = max(
            0,
            int(85 - distance / 8)
        )

        dd.ellipse(
            (
                x - radius,
                y - radius,
                x + radius,
                y + radius
            ),
            fill=WATERMARK_BLUE + (alpha,)
        )


# Bottom-right dots
for y in range(1650, HEIGHT, spacing):
    for x in range(WIDTH - 300, WIDTH, spacing):

        distance = math.sqrt(
            (WIDTH - x) ** 2 +
            (HEIGHT - y) ** 2
        )

        radius = max(
            2,
            int(8 - distance / 100)
        )

        alpha = max(
            0,
            int(85 - distance / 8)
        )

        dd.ellipse(
            (
                x - radius,
                y - radius,
                x + radius,
                y + radius
            ),
            fill=WATERMARK_BLUE + (alpha,)
        )

background = Image.alpha_composite(
    background,
    dots
)


# ============================================================
# 4. LUDO BOARD WATERMARK
# ============================================================

def draw_ludo_board(
    base,
    center_x,
    center_y,
    size,
    angle=0,
    opacity=28
):

    board = Image.new(
        "RGBA",
        (size, size),
        (0, 0, 0, 0)
    )

    d = ImageDraw.Draw(board)

    margin = int(size * 0.07)

    left = margin
    top = margin
    right = size - margin
    bottom = size - margin

    # Outer board
    d.rounded_rectangle(
        (left, top, right, bottom),
        radius=int(size * 0.04),
        outline=WATERMARK_BLUE + (opacity,),
        width=4
    )

    # Home areas
    home = int(size * 0.27)

    homes = [
        (left, top),
        (right - home, top),
        (left, bottom - home),
        (right - home, bottom - home)
    ]

    for hx, hy in homes:

        d.rounded_rectangle(
            (
                hx + 5,
                hy + 5,
                hx + home - 5,
                hy + home - 5
            ),
            radius=10,
            outline=WATERMARK_BLUE + (opacity,),
            width=3
        )

        # Four tokens
        token_r = int(home * 0.07)

        positions = [
            (hx + home * 0.30, hy + home * 0.30),
            (hx + home * 0.70, hy + home * 0.30),
            (hx + home * 0.30, hy + home * 0.70),
            (hx + home * 0.70, hy + home * 0.70)
        ]

        for tx, ty in positions:

            d.ellipse(
                (
                    tx - token_r,
                    ty - token_r,
                    tx + token_r,
                    ty + token_r
                ),
                outline=WATERMARK_BLUE + (opacity,),
                width=2
            )

    # Vertical path
    track_left = int(size * 0.43)
    track_right = int(size * 0.57)

    d.rectangle(
        (
            track_left,
            top,
            track_right,
            bottom
        ),
        outline=WATERMARK_BLUE + (opacity,),
        width=3
    )

    # Horizontal path
    track_top = int(size * 0.43)
    track_bottom = int(size * 0.57)

    d.rectangle(
        (
            left,
            track_top,
            right,
            track_bottom
        ),
        outline=WATERMARK_BLUE + (opacity,),
        width=3
    )

    # Grid
    cell = int(size * 0.045)

    for x in range(
        int(size * 0.28),
        int(size * 0.73),
        cell
    ):

        d.line(
            (
                x,
                track_top,
                x,
                track_bottom
            ),
            fill=WATERMARK_BLUE + (opacity,),
            width=1
        )

    for y in range(
        int(size * 0.28),
        int(size * 0.73),
        cell
    ):

        d.line(
            (
                track_left,
                y,
                track_right,
                y
            ),
            fill=WATERMARK_BLUE + (opacity,),
            width=1
        )

    # Center
    center_size = int(size * 0.20)

    c1 = int(size / 2 - center_size / 2)
    c2 = int(size / 2 + center_size / 2)

    d.rectangle(
        (c1, c1, c2, c2),
        outline=WATERMARK_BLUE + (opacity,),
        width=3
    )

    d.line(
        (c1, c1, c2, c2),
        fill=WATERMARK_BLUE + (opacity,),
        width=2
    )

    d.line(
        (c2, c1, c1, c2),
        fill=WATERMARK_BLUE + (opacity,),
        width=2
    )

    # Rotate
    if angle:
        board = board.rotate(
            angle,
            resample=Image.Resampling.BICUBIC,
            expand=True
        )

    base.alpha_composite(
        board,
        (
            int(center_x - board.width / 2),
            int(center_y - board.height / 2)
        )
    )


# ============================================================
# 5. WATERMARK BOARDS
# ============================================================

draw_ludo_board(
    background,
    145, 430,
    300,
    angle=-12,
    opacity=80
)

draw_ludo_board(
    background,
    900, 400,
    320,
    angle=16,
    opacity=78
)

draw_ludo_board(
    background,
    130, 1510,
    330,
    angle=-18,
    opacity=75
)

draw_ludo_board(
    background,
    930, 1580,
    350,
    angle=15,
    opacity=80
)


# ============================================================
# 6. DICE WATERMARK
# ============================================================

def draw_dice(
    base,
    center_x,
    center_y,
    size,
    angle=0,
    opacity=38
):

    dice = Image.new(
        "RGBA",
        (size, size),
        (0, 0, 0, 0)
    )

    d = ImageDraw.Draw(dice)

    margin = int(size * 0.12)

    d.rounded_rectangle(
        (
            margin,
            margin,
            size - margin,
            size - margin
        ),
        radius=int(size * 0.15),
        outline=WATERMARK_BLUE + (opacity,),
        width=4
    )

    dot_radius = int(size * 0.055)

    positions = [
        (0.30, 0.30),
        (0.70, 0.30),
        (0.50, 0.50),
        (0.30, 0.70),
        (0.70, 0.70)
    ]

    for px, py in positions:

        x = int(size * px)
        y = int(size * py)

        d.ellipse(
            (
                x - dot_radius,
                y - dot_radius,
                x + dot_radius,
                y + dot_radius
            ),
            fill=WATERMARK_BLUE + (opacity,)
        )

    if angle:
        dice = dice.rotate(
            angle,
            resample=Image.Resampling.BICUBIC,
            expand=True
        )

    base.alpha_composite(
        dice,
        (
            int(center_x - dice.width / 2),
            int(center_y - dice.height / 2)
        )
    )


# ============================================================
# 7. DICE PLACEMENT
# ============================================================

draw_dice(
    background,
    145, 400,
    150,
    angle=-12,
    opacity=90
)

draw_dice(
    background,
    910, 560,
    135,
    angle=15,
    opacity=90
)

draw_dice(
    background,
    120, 1840,
    140,
    angle=-10,
    opacity=85
)

draw_dice(
    background,
    950, 1830,
    145,
    angle=15,
    opacity=85
)


# ============================================================
# 8. SMALL STARS
# ============================================================

stars = Image.new(
    "RGBA",
    (WIDTH, HEIGHT),
    (0, 0, 0, 0)
)

sd = ImageDraw.Draw(stars)


def draw_star(
    draw,
    x,
    y,
    size,
    alpha
):

    points = []

    for i in range(10):

        angle = (
            -math.pi / 2 +
            i * math.pi / 5
        )

        radius = (
            size
            if i % 2 == 0
            else size * 0.4
        )

        points.append(
            (
                x + math.cos(angle) * radius,
                y + math.sin(angle) * radius
            )
        )

    draw.polygon(
        points,
        outline=WATERMARK_BLUE + (alpha,)
    )


for _ in range(35):

    x = random.randint(
        30,
        WIDTH - 30
    )

    y = random.randint(
        200,
        HEIGHT - 200
    )

    draw_star(
        sd,
        x,
        y,
        random.randint(8, 18),
        random.randint(60, 90)
    )


background = Image.alpha_composite(
    background,
    stars
)


# ============================================================
# 9. SOFT WAVES AT BOTTOM
# ============================================================

waves = Image.new(
    "RGBA",
    (WIDTH, HEIGHT),
    (0, 0, 0, 0)
)

wd = ImageDraw.Draw(waves)


def draw_wave(
    offset,
    amplitude,
    alpha
):

    points = []

    for x in range(
        -50,
        WIDTH + 50,
        10
    ):

        y = (
            offset +
            amplitude *
            math.sin(
                (x / WIDTH) *
                math.pi * 2
            )
        )

        points.append(
            (x, y)
        )

    points += [
        (WIDTH, HEIGHT),
        (0, HEIGHT)
    ]

    wd.polygon(
        points,
        fill=WHITE + (alpha,)
    )


draw_wave(
    HEIGHT * 0.84,
    70,
    25
)

draw_wave(
    HEIGHT * 0.89,
    55,
    18
)


background = Image.alpha_composite(
    background,
    waves
)


# ============================================================
# 10. SAVE
# ============================================================

background.convert("RGB").save(
    "ludo_background.png",
    quality=95
)

print("Saved: ludo_background.png")
