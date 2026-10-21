"""Original 4x4 rain atlases: RGBA8 DDS with full mip chains; stdlib only."""
from pathlib import Path
import argparse
import math
import random
import struct

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "mod/art/beamng_weather_hashk014"


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
    header = [124, 0x2100F, height, width, width*4, 0, len(levels)] + [0]*11
    header += [32, 0x41, 0, 32, 0xFF, 0xFF00, 0xFF0000, 0xFF000000]
    header += [0x401008, 0, 0, 0, 0]
    return b"DDS " + struct.pack("<31I", *header) + b"".join(levels)


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


def outputs():
    return {
        "rain_fine.color.dds": atlas(1401, 102, 0.8, 0.7),
        "rain_body.color.dds": atlas(1402, 142, 1, 1.1),
        "rain_distant.color.dds": atlas(1403, 83, 0.9, 0.95),
        "rain_empty.color.dds": dds(4, 4, bytes(4*4*4)),
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
