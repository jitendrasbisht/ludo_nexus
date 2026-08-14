"""Play Store hi-res icon: same Dice Duo art as the launcher icon, but
full-bleed square (no pre-rounded corners) at 512x512, since Play Store
applies its own icon mask on top of whatever's uploaded."""
import sys
sys.path.insert(0, r'C:/Users/Jeet/AppData/Local/Temp/claude/C--Users-Jeet-Desktop-projects-TaxVault/929d35c5-bf52-4b8e-b7a7-51665e7fc54b/scratchpad')
from gen_launcher_icon import linear_gradient_bg, glossy_die, paste_rotated
from PIL import Image, ImageDraw, ImageFilter

SIZE = 512


def build():
    bg = linear_gradient_bg(SIZE, (255, 209, 102), (255, 138, 61))
    canvas = Image.fromarray(bg, mode='RGB').convert('RGBA')

    shadow = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.ellipse([SIZE * 0.20, SIZE * 0.66, SIZE * 0.56, SIZE * 0.76], fill=(0, 0, 0, 60))
    sd.ellipse([SIZE * 0.46, SIZE * 0.48, SIZE * 0.86, SIZE * 0.60], fill=(0, 0, 0, 60))
    shadow = shadow.filter(ImageFilter.GaussianBlur(SIZE * 0.02))
    canvas = Image.alpha_composite(canvas, shadow)

    red_die = glossy_die(int(SIZE * 0.50), (238, 59, 47), (150, 20, 12), (255, 158, 140))
    blue_die = glossy_die(int(SIZE * 0.44), (10, 168, 232), (6, 90, 140), (150, 224, 255))

    paste_rotated(canvas, red_die, SIZE * 0.39, SIZE * 0.59, -14)
    paste_rotated(canvas, blue_die, SIZE * 0.64, SIZE * 0.43, 12)

    return canvas  # Play Store spec: 32-bit PNG *with* alpha -- keep RGBA, just fully opaque


if __name__ == '__main__':
    img = build()
    img.save('store_assets/icon_512.png')
    print('saved', img.size)
