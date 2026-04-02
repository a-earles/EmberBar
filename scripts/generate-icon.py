#!/usr/bin/env python3
"""Generate EmberBar app icon — Classic Flame (Option A) on dark rounded square."""

import struct
import zlib
import math
import os
import sys


def clamp(v, lo=0, hi=255):
    return max(lo, min(hi, int(v)))


def lerp(a, b, t):
    return a + (b - a) * max(0, min(1, t))


def smoothstep(edge0, edge1, x):
    t = max(0, min(1, (x - edge0) / (edge1 - edge0)))
    return t * t * (3 - 2 * t)


def create_ember_icon(size):
    """Create Option A Classic Flame icon."""
    pixels = []
    cx = size / 2
    cy = size / 2

    for y in range(size):
        row = []
        for x in range(size):
            # Normalized coords centered
            nx = (x - cx) / cx  # -1 to 1
            ny = (y - cy) / cy  # -1 to 1

            # --- Background: rounded square (squircle) ---
            pad = 0.07
            corner = 5.0
            sq = abs(nx / (1 - pad)) ** corner + abs(ny / (1 - pad)) ** corner
            in_bg = sq <= 1.0
            bg_alpha = smoothstep(1.05, 0.95, sq)

            if bg_alpha <= 0:
                row.extend([0, 0, 0, 0])
                continue

            bg_r, bg_g, bg_b = 26, 26, 26

            # --- Flame shape using ellipse-based approach ---
            # Flame coords: center at (0.5, 0.38) of icon, height ~0.7
            flame_cx = 0
            flame_cy_offset = -0.12  # shift flame up slightly
            fny = ny - flame_cy_offset

            # Flame vertical range: top at fny = -0.65, bottom at fny = 0.55
            flame_top = -0.65
            flame_bot = 0.55
            flame_h = flame_bot - flame_top

            if flame_top <= fny <= flame_bot:
                # t goes from 0 (top) to 1 (bottom)
                t = (fny - flame_top) / flame_h

                # Width envelope: narrow tip → wide middle → rounded bottom
                if t < 0.12:
                    # Narrow tip
                    w = t / 0.12 * 0.12
                elif t < 0.45:
                    # Widening smoothly
                    tt = (t - 0.12) / 0.33
                    w = 0.12 + smoothstep(0, 1, tt) * 0.43
                elif t < 0.75:
                    # Wide middle
                    tt = (t - 0.45) / 0.30
                    w = 0.55 + tt * 0.05
                else:
                    # Rounding inward at bottom
                    tt = (t - 0.75) / 0.25
                    w = 0.60 * (1 - smoothstep(0, 1, tt) * 0.8)
                    w = max(0, w)

                in_flame = abs(nx) < w
            else:
                in_flame = False
                w = 0
                t = 0

            if in_flame and w > 0.01:
                edge_dist = abs(nx) / w  # 0=center, 1=edge

                # --- Outer flame gradient ---
                if t < 0.2:
                    fr = lerp(255, 255, t / 0.2)
                    fg = lerp(213, 170, t / 0.2)
                    fb = lerp(79, 50, t / 0.2)
                elif t < 0.5:
                    tt = (t - 0.2) / 0.3
                    fr = lerp(255, 245, tt)
                    fg = lerp(170, 100, tt)
                    fb = lerp(50, 30, tt)
                elif t < 0.8:
                    tt = (t - 0.5) / 0.3
                    fr = lerp(245, 210, tt)
                    fg = lerp(100, 60, tt)
                    fb = lerp(30, 20, tt)
                else:
                    tt = (t - 0.8) / 0.2
                    fr = lerp(210, 180, tt)
                    fg = lerp(60, 40, tt)
                    fb = lerp(20, 12, tt)

                # Darken toward edges
                edge_dark = 1.0 - edge_dist ** 1.5 * 0.35
                fr *= edge_dark
                fg *= edge_dark
                fb *= edge_dark

                # --- Inner core: bright center flame ---
                core_w = w * 0.4
                core_top = 0.08
                core_bot = 0.65
                if abs(nx) < core_w and core_top < t < core_bot:
                    core_edge = abs(nx) / max(core_w, 0.01)
                    core_t = (t - core_top) / (core_bot - core_top)
                    core_blend = (1 - core_edge ** 1.5) * (1 - core_t * 0.6) * 0.8

                    # Core colors: white-yellow top → golden bottom
                    cr = lerp(255, 255, core_t)
                    cg = lerp(245, 180, core_t)
                    cb = lerp(190, 60, core_t)

                    fr = lerp(fr, cr, core_blend)
                    fg = lerp(fg, cg, core_blend)
                    fb = lerp(fb, cb, core_blend)

                # Anti-alias flame edge
                aa = smoothstep(1.0, 0.85, edge_dist)
                # Also AA the tip
                if t < 0.08:
                    aa *= smoothstep(0, 0.08, t)
                # AA the bottom
                if t > 0.9:
                    aa *= smoothstep(1.0, 0.9, t)

                # Composite flame over background
                r = clamp(lerp(bg_r, fr, aa))
                g = clamp(lerp(bg_g, fg, aa))
                b = clamp(lerp(bg_b, fb, aa))
                a = clamp(bg_alpha * 255)
            else:
                # Background only
                r, g, b = bg_r, bg_g, bg_b
                a = clamp(bg_alpha * 255)

            row.extend([r, g, b, a])

        pixels.append(bytes([0] + row))

    raw = b''.join(pixels)

    def chunk(chunk_type, data):
        c = chunk_type + data
        return struct.pack('>I', len(data)) + c + struct.pack('>I', zlib.crc32(c) & 0xffffffff)

    header = struct.pack('>IIBBBBB', size, size, 8, 6, 0, 0, 0)
    compressed = zlib.compress(raw, 9)

    png = b'\x89PNG\r\n\x1a\n'
    png += chunk(b'IHDR', header)
    png += chunk(b'IDAT', compressed)
    png += chunk(b'IEND', b'')
    return png


def main():
    if len(sys.argv) < 2:
        print("Usage: generate-icon.py <output_iconset_dir>")
        sys.exit(1)

    iconset_dir = sys.argv[1]
    os.makedirs(iconset_dir, exist_ok=True)

    sizes = {
        'icon_16x16.png': 16,
        'icon_16x16@2x.png': 32,
        'icon_32x32.png': 32,
        'icon_32x32@2x.png': 64,
        'icon_128x128.png': 128,
        'icon_128x128@2x.png': 256,
        'icon_256x256.png': 256,
        'icon_256x256@2x.png': 512,
        'icon_512x512.png': 512,
        'icon_512x512@2x.png': 1024,
    }

    for filename, size in sizes.items():
        png_data = create_ember_icon(size)
        with open(os.path.join(iconset_dir, filename), 'wb') as f:
            f.write(png_data)
        print(f"  {filename} ({size}x{size})")

    print(f"Generated {len(sizes)} icon sizes")


if __name__ == '__main__':
    main()
