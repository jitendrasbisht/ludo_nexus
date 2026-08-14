"""Crops the raw 1080x2400 (20:9) device screenshots down to a clean 9:16
(1080x1920) so they fall within Play Store's 2:1 max aspect-ratio cap --
trims the OS status bar and nav bar first, then center-crops the rest."""
from PIL import Image
import glob
import os

STATUS_BAR = 90
NAV_BAR = 127  # matches the real device's navigationBarBackground height
TARGET_W, TARGET_H = 1080, 1920

files = sorted(glob.glob('screenshot_*.png'))
for f in files:
    im = Image.open(f)
    w, h = im.size
    trimmed = im.crop((0, STATUS_BAR, w, h - NAV_BAR))
    tw, th = trimmed.size
    # Anchor from the top (keep the app bar) and trim any extra height off
    # the bottom instead of center-cropping, which was clipping the status
    # pill's text right at the bottom edge.
    final = trimmed.crop((0, 0, tw, min(th, TARGET_H)))
    if final.size != (TARGET_W, TARGET_H):
        final = final.resize((TARGET_W, TARGET_H), Image.LANCZOS)
    out = f.replace('screenshot_', 'store_screenshot_')
    final.save(out)
    print(f, '->', out, final.size, 'ratio', round(final.size[1] / final.size[0], 3))
