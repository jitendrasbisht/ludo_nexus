"""Play Store feature graphic: 1024x500 banner. Navy background matching
the app's own theme, the Dice Duo icon art, and the "Ludo Nexus" wordmark."""
import sys
sys.path.insert(0, r'C:/Users/Jeet/AppData/Local/Temp/claude/C--Users-Jeet-Desktop-projects-TaxVault/929d35c5-bf52-4b8e-b7a7-51665e7fc54b/scratchpad')
from gen_launcher_icon import glossy_die, paste_rotated, rounded_rect_mask
from PIL import Image, ImageDraw, ImageFilter, ImageFont
import numpy as np

W, H = 1024, 500

NAVY_TOP = (42, 62, 102)
NAVY_BOTTOM = (22, 36, 68)


def vgrad(size, top, bottom):
    w, h = size
    ys = np.linspace(0, 1, h).astype(np.float32)
    top = np.array(top, dtype=np.float32)
    bottom = np.array(bottom, dtype=np.float32)
    rows = top[None, :] * (1 - ys[:, None]) + bottom[None, :] * ys[:, None]
    rgb = np.repeat(rows[:, None, :], w, axis=1).astype(np.uint8)
    return Image.fromarray(rgb, mode='RGB')


def font(size, bold=True):
    paths = [
        "C:/Windows/Fonts/segoeuib.ttf" if bold else "C:/Windows/Fonts/segoeui.ttf",
        "C:/Windows/Fonts/arialbd.ttf" if bold else "C:/Windows/Fonts/arial.ttf",
    ]
    for p in paths:
        try:
            return ImageFont.truetype(p, size)
        except Exception:
            pass
    return ImageFont.load_default()


def build():
    base = vgrad((W, H), NAVY_TOP, NAVY_BOTTOM).convert('RGBA')
    draw = ImageDraw.Draw(base)

    # Faint decorative board-grid watermark on the right side (echoes the
    # in-app background style) so the banner doesn't feel like flat navy.
    rnd = np.random.RandomState(3)
    for _ in range(40):
        x = rnd.randint(560, W - 30)
        y = rnd.randint(20, H - 20)
        r = rnd.randint(2, 4)
        draw.ellipse([x - r, y - r, x + r, y + r], fill=(110, 140, 195, 90))

    # Dice cluster on the right.
    red_die = glossy_die(190, (238, 59, 47), (150, 20, 12), (255, 158, 140))
    green_die = glossy_die(150, (15, 176, 90), (6, 90, 40), (150, 230, 180))
    blue_die = glossy_die(170, (10, 168, 232), (6, 90, 140), (150, 224, 255))
    yellow_die = glossy_die(130, (230, 200, 20), (140, 110, 5), (255, 240, 150), pip_color='#332a05')

    paste_rotated(base, blue_die, 760, 250, -12)
    paste_rotated(base, red_die, 880, 175, 16)
    paste_rotated(base, green_die, 860, 340, -22)
    paste_rotated(base, yellow_die, 720, 380, 10)

    # Wordmark on the left.
    title_font = font(96)
    tagline_font = font(30, bold=False)
    draw.text((60, 165), "Ludo Nexus", font=title_font, fill=(255, 255, 255, 255))
    draw.text((64, 275), "Roll \u00b7 Race \u00b7 Rule the Board", font=tagline_font, fill=(200, 212, 235, 255))

    return base.convert('RGB')


if __name__ == '__main__':
    img = build()
    img.save('store_assets/feature_graphic.png')
    print('saved', img.size)
