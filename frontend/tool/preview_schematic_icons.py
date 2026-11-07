from pathlib import Path
import shutil
from PIL import Image, ImageDraw

root = Path(__file__).resolve().parents[1]
source_dir = root / 'assets' / 'muscle_groups_schematic'
originals = root.parent / 'references' / 'generated-muscle-groups-schematic'
originals.mkdir(parents=True, exist_ok=True)
preview = root / 'build' / 'preview'
preview.mkdir(parents=True, exist_ok=True)
codes = ['chest', 'arms', 'back', 'legs', 'shoulders', 'core', 'full_body', 'cardio']
colors = ['#69B985', '#D36B6B', '#6598D1', '#A4BE5F', '#67B8C7', '#A17AC5', '#D69A5D', '#D77C9E']

sheet = Image.new('RGB', (4 * 280, 2 * 300), '#1E1E1E')
draw = ImageDraw.Draw(sheet)
for index, (code, color) in enumerate(zip(codes, colors)):
    path = source_dir / f'{code}.png'
    shutil.copy2(path, originals / path.name)
    with Image.open(path) as source:
        source = source.convert('RGBA')
        alpha = source.getchannel('A')
        transparent_pixels = sum(value == 0 for value in alpha.get_flattened_data())
        transparent = transparent_pixels / (source.width * source.height)
        print(f'{code}: {source.size}, alpha={alpha.getextrema()}, transparent={transparent:.1%}')
        x = (index % 4) * 280
        y = (index // 4) * 300
        draw.rounded_rectangle((x + 20, y + 20, x + 260, y + 260), radius=32, fill='#262626', outline=color, width=2)
        tile = source.copy()
        tile.thumbnail((216, 216), Image.Resampling.LANCZOS)
        sheet.paste(tile, (x + 32 + (216 - tile.width) // 2, y + 32 + (216 - tile.height) // 2), tile)
        draw.text((x + 24, y + 274), code, fill='#EAEAEA')
sheet.save(preview / 'muscle-icons-schematic-sheet.png', optimize=True)
