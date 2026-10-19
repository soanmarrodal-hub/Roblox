"""Planche des 30 héros (vue de face, par île) : docs/images/heroes/_all_front.png.

Chaque aperçu docs/images/heroes/<Héros>.png contient 4 vues carrées côte à côte ; on garde la première (face).
Usage : python3 tools/hero_pipeline/contact_sheet.py
"""
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
DIR = os.path.join(ROOT, 'docs', 'images', 'heroes')
ORDER = [
    ['Leafin', 'Bramble', 'Cylla', 'Lumora', 'Thornix', 'Verdantis'],
    ['Pyrion', 'Solmir', 'Zahir', 'Solara', 'Rajin', 'Helius'],
    ['Glitchi', 'Volta', 'Kairo', 'Synthia', 'Mekhar', 'Axiom'],
    ['Floconi', 'Grizzlace', 'Kiriha', 'Aurelis', 'Hivernor', 'Kryovane'],
    ['Tizzo', 'Magmok', 'Embra', 'Cendrael', 'Vulkhar', 'Magnarok'],
]
CELL = 256


def main():
    W = CELL * 6
    H = (CELL + 28) * len(ORDER)
    sheet = Image.new('RGB', (W, H), (23, 26, 41))
    draw = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype('DejaVuSans-Bold.ttf', 18)
    except OSError:
        font = ImageFont.load_default()
    for r, row in enumerate(ORDER):
        for c, name in enumerate(row):
            path = os.path.join(DIR, name + '.png')
            if not os.path.exists(path):
                continue
            im = Image.open(path).convert('RGB')
            side = im.height
            front = im.crop((0, 0, side, side)).resize((CELL, CELL), Image.LANCZOS)
            x, y = c * CELL, r * (CELL + 28)
            sheet.paste(front, (x, y))
            tw = draw.textlength(name, font=font)
            draw.text((x + (CELL - tw) / 2, y + CELL + 4), name, fill=(235, 238, 250), font=font)
    out = os.path.join(DIR, '_all_front.png')
    sheet.save(out, optimize=True)
    print('planche :', out, sheet.size)


if __name__ == '__main__':
    main()
