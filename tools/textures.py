"""Original 4x4 rain atlases: legacy DXT5/BC3 DDS with full mip chains."""
from pathlib import Path
import argparse
import math
import random
import struct
from io import BytesIO
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "mod/art/beamng_weather_hashk014"


def bc3(width, height, pixels):
    # These generated atlases have constant RGB; only opacity varies.
    rgb = pixels[:3]
    assert all(pixels[i:i+3] == rgb for i in range(0, len(pixels), 4))
    color = ((rgb[0] >> 3) << 11) | ((rgb[1] >> 2) << 5) | (rgb[2] >> 3)
    result = bytearray()
    for by in range(0, height, 4):
        for bx in range(0, width, 4):
            alpha = [pixels[(min(height-1,by+y)*width+min(width-1,bx+x))*4+3] for y in range(4) for x in range(4)]
            high, low = max(alpha), min(alpha)
            indices = 0
            if high != low:
                palette = [high, low] + [((7-i)*high+i*low)//7 for i in range(1,7)]
                for i, value in enumerate(alpha):
                    index = min(range(8), key=lambda k: abs(palette[k]-value))
                    indices |= index << (3*i)
            result.extend(bytes((high,low)) + indices.to_bytes(6,'little') + struct.pack('<HHI',color,color,0))
    return bytes(result)


def dds(width, height, pixels):
    levels = [bytes(pixels)]
    w, h = width, height
    while w > 1 or h > 1:
        nw, nh = max(1, w // 2), max(1, h // 2)
        previous = levels[-1]
        result = bytearray(nw * nh * 4)
        for y in range(nh):
            for x in range(nw):
                sources = [(min(h-1, y*2+dy)*w + min(w-1, x*2+dx))*4 for dy in range(2) for dx in range(2)]
                for c in range(4):
                    result[(y*nw+x)*4+c] = (sum(previous[i+c] for i in sources) + 2) // 4
        levels.append(bytes(result))
        w, h = nw, nh
    compressed = [bc3(max(1,width>>i),max(1,height>>i),level) for i,level in enumerate(levels)]
    header = [124, 0xA1007, height, width, len(compressed[0]), 0, len(levels)] + [0]*11
    header += [32, 4, int.from_bytes(b'DXT5','little'), 0, 0, 0, 0, 0]
    header += [0x401008, 0, 0, 0, 0]
    return b"DDS " + struct.pack("<31I", *header) + b"".join(compressed)


def atlas(seed, opacity, width_scale, length_scale):
    size, cell = 512, 128
    rng = random.Random(seed)
    pixels = bytearray(bytes((220, 231, 238, 0)) * (size*size))
    for cy in range(4):
        for cx in range(4):
            center = cell/2 + rng.uniform(-9, 9)
            length = rng.uniform(35, 86) * length_scale
            sigma = rng.uniform(0.85, 1.9) * width_scale
            strength = rng.uniform(0.55, 1) * opacity
            for y in range(cell):
                t = (y-cell/2) / (length/2)
                if abs(t) >= 1:
                    continue
                taper = (1-t*t) ** 1.8
                local_sigma = sigma * (0.6 + 0.4 * taper)
                for x in range(max(0, int(center-10)), min(cell, int(center+11))):
                    across = math.exp(-0.5*((x-center)/local_sigma)**2)
                    alpha = round(strength * taper * across)
                    index = (((cy*cell+y)*size)+(cx*cell+x))*4
                    pixels[index+3] = min(255, max(0, alpha))
    return dds(size, size, pixels)


def glass_texture(normal=False):
    # Sixteen lifetime frames: bead with a shaded rim, a highlight and a normal dome.
    size, cell = 256, 64
    image = Image.new("RGBA", (size, size), (128, 128, 255, 0) if normal else (0, 0, 0, 0))
    pixels = image.load()
    for frame in range(16):
        fade = min(1, (16-frame)/4)
        for y in range(cell):
            for x in range(cell):
                dx, dy = (x+0.5-cell/2)/(cell*0.42), (y+0.5-cell/2)/(cell*0.42)
                r2 = dx*dx+dy*dy
                if r2 >= 1:
                    continue
                z = math.sqrt(1-r2)
                edge = min(1, (1-r2)*16)
                if normal:
                    rgba = (round(128+dx*100), round(128-dy*100), round(128+z*127), 255)
                else:
                    highlight = math.exp(-((dx+0.35)**2+(dy+0.42)**2)/0.025)
                    rim = math.exp(-((math.sqrt(r2)-0.87)/0.09)**2)
                    value = round(110+100*highlight+40*rim)
                    rgba = (value, min(255,value+10), min(255,value+18), round((18+100*rim+120*highlight)*edge*fade))
                pixels[(frame%4)*cell+x, (frame//4)*cell+y] = rgba
    result = BytesIO()
    image.save(result, format="PNG", optimize=False)
    return result.getvalue()


def outputs():
    return {
        "rain_fine.color.dds": atlas(1401, 102, 0.8, 0.7),
        "rain_body.color.dds": atlas(1402, 142, 1, 1.1),
        "rain_distant.color.dds": atlas(1403, 83, 0.9, 0.95),
        "rain_empty.color.dds": dds(4, 4, bytes(4*4*4)),
        "glass_drop.color.png": glass_texture(),
        "glass_drop.normal.png": glass_texture(normal=True),
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    for name, data in outputs().items():
        path = OUT / name
        if args.check:
            assert path.read_bytes() == data, f"Texture differs: {name}"
        else:
            path.write_bytes(data)
        print(f"{name}: {len(data)} bytes")


if __name__ == "__main__":
    main()
