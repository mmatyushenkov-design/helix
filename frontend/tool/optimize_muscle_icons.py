from pathlib import Path
import shutil
from PIL import Image, ImageDraw

root = Path(__file__).resolve().parents[1]
assets = root / 'assets' / 'muscle_groups'
originals = root.parent / 'references' / 'generated-muscle-groups'
originals.mkdir(parents=True, exist_ok=True)
preview = root / 'build' / 'preview'
preview.mkdir(parents=True, exist_ok=True)
codes = ['chest', 'arms', 'back', 'legs', 'shoulders', 'core', 'full_body', 'cardio']
colors = ['#69B985', '#D36B6B', '#6598D1', '#A4BE5F', '#67B8C7', '#A17AC5', '#D69A5D', '#D77C9E']

sheet = Image.new('RGB', (4 * 280, 2 * 300), '#1E1E1E')
draw = ImageDraw.Draw(sheet)
for index, (code, color) in enumerate(zip(codes, colors)):
    path = assets / f'{code}.png'
    shutil.copy2(path, originals / path.name)
    with Image.open(path) as source:
        source = source.convert('RGBA')
        alpha = source.getchannel('A')
        transparent = sum(1 for value in alpha.getdata() if value == 0) / (source.width * source.height)
        print(f'{code}: {source.size}, alpha={alpha.getextrema()}, transparent={transparent:.1%}')
        source.thumbnail((256, 256), Image.Resampling.LANCZOS)
        source.save(path, optimize=True)
        x = (index % 4) * 280
        y = (index // 4) * 300
        draw.rounded_rectangle((x + 20, y + 20, x + 260, y + 260), radius=32, fill='#262626', outline=color, width=2)
        tile = source.resize((216, 216), Image.Resampling.LANCZOS)
        sheet.paste(tile, (x + 32, y + 32), tile)
        draw.text((x + 24, y + 274), code, fill='#EAEAEA')
sheet.save(preview / 'muscle-icons-sheet.png', optimize=True)
