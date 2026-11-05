"""Normalize the saved generated masters into registered, editable pixel assets. Requires Pillow."""
from collections import deque
from pathlib import Path
import json
import re
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/art-direction/cozy-v2"
OUTPUT = ROOT / "assets/sprites/sock_puppet/cozy_v3/frames"
HAIR = ROOT / "assets/sprites/sock_puppet/hair"


def alpha_mask(image):
    image = image.convert("RGBA")
    image.putalpha(image.getchannel("A").point(lambda value: 255 if value >= 128 else 0))
    return image


def cells(image, columns, rows):
    width, height = image.width // columns, image.height // rows
    return [image.crop(((i % columns)*width, (i//columns)*height,
                       (i % columns+1)*width, (i//columns+1)*height))
            for i in range(columns*rows)]


def eyes(image):
    mask = set()
    for y in range(12, 65):
        for x in range(40, 90):
            r, g, b, a = image.getpixel((x, y))
            if a and r > 160 and g > 140 and b > 80 and r-g < 85 and g-b > 10:
                mask.add((x, y))
    components = []
    while mask:
        point = mask.pop()
        queue, component = deque([point]), [point]
        while queue:
            x, y = queue.popleft()
            for neighbor in [(x-1,y), (x+1,y), (x,y-1), (x,y+1)]:
                if neighbor in mask:
                    mask.remove(neighbor)
                    queue.append(neighbor)
                    component.append(neighbor)
        if len(component) >= 7:
            components.append(component)
    components = sorted(components, key=len, reverse=True)[:2]
    assert len(components) == 2, "Two separate button eyes required"
    return sorted((round(sum(x for x,y in c)/len(c)), round(sum(y for x,y in c)/len(c))) for c in components)


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    HAIR.mkdir(parents=True, exist_ok=True)
    reference = cells(alpha_mask(Image.open(SOURCE / "puppet-alpha-master.png")),4,2)
    bounds = [cell.getbbox() for cell in reference]
    scale = min(72/max(b[2]-b[0] for b in bounds),100/max(b[3]-b[1] for b in bounds))
    source = alpha_mask(Image.open(SOURCE / "puppet-bald-master.png"))
    assert source.size == Image.open(SOURCE / "puppet-alpha-master.png").size
    body_cells = cells(source,4,2)
    scale = min(scale,71/max(cell.getbbox()[2]-cell.getbbox()[0] for cell in body_cells))
    frames = []
    for cell in body_cells:
        cell = cell.resize((round(cell.width*scale),round(cell.height*scale)),Image.Resampling.NEAREST)
        box = cell.getbbox()
        frame = Image.new("RGBA",(96,128))
        frame.alpha_composite(cell,(48-(box[0]+box[2])//2,113-box[3]))
        assert frame.getbbox()[3] == 113
        assert frame.getbbox()[2]-frame.getbbox()[0] <= 72
        frames.append(frame)
    hairstyles = []
    for index, cell in enumerate(cells(alpha_mask(Image.open(SOURCE / "hair-parts-master.png")),3,1)):
        cell = cell.crop(cell.getbbox())
        factor = min(36/cell.width,30/cell.height)
        cell = cell.resize((round(cell.width*factor),round(cell.height*factor)),Image.Resampling.NEAREST)
        frame = Image.new("RGBA",(64,48))
        root_x = round(cell.width*(0.78 if index == 0 else 0.5))
        frame.alpha_composite(cell,(32-root_x,46-cell.height))
        assert frame.getbbox()[3] == 46 and frame.getbbox()[0] > 0
        hairstyles.append(frame)
    atlas = Image.new("RGBA",(384,304))
    for i,frame in enumerate(frames):
        atlas.alpha_composite(frame,((i%4)*96,(i//4)*128))
    for i,frame in enumerate(hairstyles):
        atlas.alpha_composite(frame,(i*64,256))
    palette = atlas.convert("RGB").quantize(colors=64,method=Image.Quantize.MEDIANCUT)
    near, far = [], []
    for i,frame in enumerate(frames+hairstyles):
        pixels = frame.convert("RGB").quantize(palette=palette,dither=Image.Dither.NONE).convert("RGBA")
        pixels.putalpha(frame.getchannel("A"))
        assert set(pixels.getchannel("A").getdata()) <= {0,255}
        pixels.save(OUTPUT/f"{i:02d}.png" if i < 8 else HAIR/f"{i-8}.png")
        if i < 8:
            first, second = eyes(pixels)
            near.append(first)
            far.append(second)
            atlas.alpha_composite(pixels,((i%4)*96,(i//4)*128))
        else:
            atlas.alpha_composite(pixels,((i-8)*64,256))
    atlas.save(SOURCE / "separated-runtime-contact.png")
    (SOURCE / "registration-v3.json").write_text(json.dumps({"canvas":[96,128],"baseline":113,"hair_canvas":[64,48],"hair_root":[32,46],"near_eyes":near,"far_eyes":far,"palette_colors":64},indent=2))
    layout = ROOT / "scripts/art_layout.gd"
    text = layout.read_text()
    for name,points in [("NEAR_EYE_PIXELS",near),("FAR_EYE_PIXELS",far)]:
        text = re.sub(r"const "+name+r" := .*","const "+name+" := ["+", ".join(f"Vector2i({x},{y})" for x,y in points)+"]",text)
    layout.write_text(text)
    print("8 bald frames + 3 separate hairstyles, shared 64-color palette, binary alpha, baseline 113: PASS")


if __name__ == "__main__":
    main()
