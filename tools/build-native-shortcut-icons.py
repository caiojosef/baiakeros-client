"""Draw new native-sized glyphs from explicit pixel maps; existing assets are untouched."""
from pathlib import Path
from PIL import Image

OUTPUT = Path(__file__).resolve().parents[1] / 'data/images/topbuttons'
COLORS = {'.': (0, 0, 0, 0), 'w': (198, 198, 198, 255),
          'g': (127, 127, 127, 255), 'h': (231, 231, 231, 255)}
GLYPHS = {
    'codex-native-v2': [
        '................',
        '..gwww....wwwg..',
        '..w...w..w...w..',
        '..w....ww....w..',
        '..w.hh..w.hh.w..',
        '..w.....w....w..',
        '..w.hh..w.hh.w..',
        '..w.....w....w..',
        '..w.hh..w.hh.w..',
        '..w.....w....w..',
        '..w.....w....w..',
        '..gwwww.w.wwwwg.',
        '..g....www....g.',
        '..gwwwwwww.wwgg.',
        '................',
        '................',
    ],
    'market-native-v2': [
        '................',
        '..hww...........',
        '....w...........',
        '....w.hwwwwwww..',
        '....www.....wg..',
        '.....w......w...',
        '.....w......w...',
        '.....w.....wg...',
        '.....gwwwwww....',
        '......w.........',
        '......hwwwwwg...',
        '................',
        '.....gwg..gwg...',
        '.....whw..whw...',
        '.....gwg..gwg...',
        '................',
    ],
}
for name, rows in GLYPHS.items():
    assert len(rows) == 16 and all(len(row) == 16 for row in rows)
    image = Image.new('RGBA', (16, 16))
    image.putdata([COLORS[pixel] for row in rows for pixel in row])
    image.save(OUTPUT / (name + '.png'))
    print(name + ': 16x16 native glyph created')
