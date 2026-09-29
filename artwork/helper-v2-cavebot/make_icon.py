"""Draw the 48 px Cavebot tab icon in the Helper's glossy cartoon style."""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


SIZE = 192
OUTPUT = Path(__file__).resolve().parents[2] / "data/images/baiakeros/helper_v2_cavebot.png"


def main() -> None:
    image = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    shadow = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw_shadow = ImageDraw.Draw(shadow)
    map_shape = [(23, 27), (137, 23), (169, 54), (164, 162), (29, 169)]
    draw_shadow.polygon([(x + 5, y + 8) for x, y in map_shape], fill=(0, 0, 0, 170))
    image.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(5)))

    mask = Image.new("L", image.size, 0)
    ImageDraw.Draw(mask).polygon(map_shape, fill=255)
    parchment = Image.new("RGBA", image.size)
    pixels = parchment.load()
    for y in range(SIZE):
        for x in range(SIZE):
            shade = max(0, min(1, (x + y) / 360))
            pixels[x, y] = (
                round(247 - 66 * shade),
                round(215 - 79 * shade),
                round(139 - 80 * shade),
                255,
            )
    image.paste(parchment, (0, 0), mask)
    draw = ImageDraw.Draw(image)
    draw.line(map_shape + [map_shape[0]], fill="#27180f", width=11, joint="curve")
    draw.line([(29, 37), (133, 33)], fill="#fff3c3", width=5)
    draw.line([(36, 161), (153, 155)], fill="#694320", width=4)

    # Folded corner and a few faint survey lines keep the symbol readable at 24 px.
    draw.polygon([(136, 23), (137, 55), (169, 54)], fill="#fff1b8")
    draw.line([(136, 23), (137, 55), (169, 54)], fill="#392417", width=8, joint="curve")
    draw.line([(142, 42), (158, 51)], fill="#c9964c", width=3)
    for points in (
        [(43, 70), (91, 65)],
        [(47, 87), (77, 84)],
        [(94, 142), (148, 139)],
    ):
        draw.line(points, fill=(128, 83, 39, 120), width=3)

    route = [(48, 133), (70, 126), (75, 105), (106, 108),
             (118, 87), (119, 65), (143, 65)]
    draw.line(route, fill="#102c2b", width=19, joint="curve")
    draw.line(route, fill="#12a797", width=13, joint="curve")
    draw.line(route, fill="#8bf9db", width=5, joint="curve")
    for x, y in (route[0], route[3]):
        draw.ellipse((x - 11, y - 11, x + 11, y + 11),
                     fill="#2a1916", outline="#fff1b0", width=3)
        draw.ellipse((x - 5, y - 5, x + 5, y + 5), fill="#ef6635")

    # Gold arrow points into the next waypoint.
    draw.polygon([(133, 45), (161, 63), (130, 80), (134, 66), (123, 58)],
                 fill="#362017")
    draw.polygon([(134, 50), (154, 63), (134, 75), (138, 64), (128, 58)],
                 fill="#f4be3e")
    draw.line([(136, 54), (149, 62)], fill="#fff4a4", width=3)

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    image.resize((48, 48), Image.Resampling.LANCZOS).save(OUTPUT)


if __name__ == "__main__":
    main()
