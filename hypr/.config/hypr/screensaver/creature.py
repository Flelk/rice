#!/usr/bin/env python3
# Creature: glitches the joke text, flashes in 3 times (half-block pixels)
import math, random, sys, time, shutil

W, H = 48, 60                      # pixels; 2 pixels per terminal row
PX, PY = 24.0, 37.0                # neck pivot the head tilts around
FPS = 15
SIZE = 0.65                        # on screen size, 1 = full drawing
OW, OH = int(W * SIZE), int(H * SIZE) // 2 * 2

def ell(x, y, cx, cy, rx, ry):
    return ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2

def pixel(x, y, tilt, light, scale):
    # Zoom: scale > 1 = it got closer
    x = (x - W / 2) / scale + W / 2
    y = (y - H * 0.62) / scale + H * 0.62
    # Head Space: rotate around the neck pivot
    c, s = math.cos(-tilt), math.sin(-tilt)
    hx = PX + (x - PX) * c - (y - PY) * s
    hy = PY + (x - PX) * s + (y - PY) * c

    beam = math.exp(-(((x - 24) / 15) ** 2 + ((y - 24) / 26) ** 2))   # spotlight falloff
    lit = light * beam
    haze = light * 0.05 * max(0, 1 - abs(x - 24) / (6 + y * 0.35))     # dust in the cone

    head = ell(hx, hy, 24, 20, 8.5, 13.5)
    jaw = ell(hx, hy, 24, 31, 5.5, 6.5)
    neck = abs(x - 24) < 3.2 - (y - 34) * 0.03 and 31 < y < 47
    body = ell(x, y, 24, 56, 19, 9.5)
    if body < 1:   # Ribs: bony shoulders
        body += 0.25 * (math.sin(y * 2.2) > 0.6) * (abs(x - 24) > 5)

    for sx in (-1, 1):   # Eyes: hollow sockets, blood runs down
        ex = 24 + sx * 4.3
        e = ell(hx, hy, ex, 17.5 + abs(hx - ex) * 0.15 * sx * -1, 2.3, 3.4)
        if e < 1:
            glint = ell(hx, hy, ex + 0.4 * sx, 17.8, 0.55, 0.45) < 1
            return (int(160 * lit + 40 * light), 0, 0) if glint else (2, 0, 0)
        if abs(hx - ex + sx * 0.6) < 0.7 and 20.5 < hy < 20.5 + 6 + (sx > 0) * 3:
            r = 90 + 80 * lit
            return (int(r), 0, 0)
    m = ell(hx, hy, 24, 29.5, 2.4, 6.8)   # Mouth: long, gaping
    if m < 1:
        depth = 1 - m
        return (int(70 * lit * (1 - depth) + 8), 0, 0)
    if abs(hx - 24) < 0.6 and 36 < hy < 41 and head >= 1:   # drool of blood
        return (int(60 + 90 * lit), 0, 0)

    if head < 1 or jaw < 1 or neck or body < 1:
        d = min(head, jaw, body if body < 1 else 9)
        edge = 1 - min(1, d) if (head < 1 or jaw < 1 or body < 1) else 0.6
        cheek = 0.75 if (ell(hx, hy, 24, 24, 7, 3) < 1 and abs(hx - 24) > 4) else 1   # sunken cheeks
        b = lit * (0.35 + 0.65 * edge) * cheek
        return (int(215 * b), int(205 * b), int(190 * b))
    return (int(30 * haze), int(28 * haze), int(26 * haze))

def frame(tilt, light, scale=1.0):
    return [[pixel((x + 0.5) / SIZE, (y + 0.5) / SIZE, tilt, light, scale) for x in range(OW)] for y in range(OH)]

def script():
    # Timeline: (tilt, light, scale, glitch) per frame, creature ~1.5s over 3 flashes
    out = []
    def add(n, tilt=0, light=0, scale=1.0, glitch=0.0):
        for i in range(n):
            g = glitch(i / max(1, n - 1)) if callable(glitch) else glitch
            l = random.choice([1, 1, 1, 0.75, 0.35]) if light else 0
            out.append((math.radians(tilt + random.uniform(-2, 2)), l, scale, g))
    add(12, glitch=0.04)                                              # calm, barely twitching
    add(4, glitch=lambda p: 0.15 + 0.35 * p)                          # it's coming
    add(7, 15, 1, glitch=0.6)                                         # flash 1
    add(random.randint(8, 12), glitch=lambda p: 0.5 * (1 - p) + 0.08)
    add(8, -38, 1, glitch=0.8)                                        # flash 2: snapped
    add(random.randint(6, 10), glitch=lambda p: 0.6 * (1 - p) + 0.1)
    add(7, -55, 1, 1.25, glitch=1.0)                                  # flash 3: closer
    add(4, glitch=lambda p: 1 + p)                                    # text falls apart
    return out

def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))

def blood(row, rows):   # same stops as tte: ff2020 > b30000 > 4a0000, top to bottom
    t = row / max(1, rows - 1)
    return lerp((255, 32, 32), (179, 0, 0), t * 2) if t < 0.5 else lerp((179, 0, 0), (74, 0, 0), t * 2 - 1)

JUNK = "█▓▒░#%&@$!?/\\|<>~*"

def compose(text, ttop, tleft, img, ctop, cleft, glitch):
    tw = max(len(l) for l in text)
    r0, r1 = min(ttop, ctop), max(ttop + len(text), ctop + OH // 2)
    c0, c1 = min(tleft, cleft), max(tleft + tw, cleft + OW)
    out = []
    for r in range(r0, r1):
        tr = r - ttop
        line = text[tr] if 0 <= tr < len(text) else ""
        shift = random.randint(-6, 6) if random.random() < glitch * 0.35 else 0
        invert = random.random() < glitch * 0.08
        color = blood(tr, len(text))
        cells = [f"\033[{r + 1};{c0 + 1}H"]
        for c in range(c0, c1):
            cy, cx = r - ctop, c - cleft
            if img and 0 <= cy < OH // 2 and 0 <= cx < OW:
                a, b = img[cy * 2][cx], img[cy * 2 + 1][cx]
                if sum(a) + sum(b) > 24:   # creature, else see-through to the text
                    cells.append(f"\033[38;2;{a[0]};{a[1]};{a[2]};48;2;{b[0]};{b[1]};{b[2]}m▀")
                    continue
            i = c - tleft - shift
            ch = line[i] if 0 <= i < len(line) else " "
            fg, bg = color, (8, 0, 0)
            if ch != " " and random.random() < glitch * 0.15:
                ch = random.choice(JUNK)
                fg = random.choice([(255, 64, 64), (230, 210, 210), (120, 0, 0)])
            if invert:
                fg, bg = (0, 0, 0), (74, 0, 0)
            cells.append(f"\033[38;2;{fg[0]};{fg[1]};{fg[2]};48;2;{bg[0]};{bg[1]};{bg[2]}m{ch}")
        out.append("".join(cells))
    return "".join(out) + "\033[0m"

if __name__ == "__main__":
    text = open(sys.argv[1]).read().rstrip("\n").split("\n")   # joke art from bigtext.py
    cols, lines = shutil.get_terminal_size()
    ttop, tleft = max(0, (lines - len(text)) // 2), max(0, (cols - max(len(l) for l in text)) // 2)
    ctop, cleft = max(0, (lines - OH // 2) // 2), max(0, (cols - OW) // 2)
    sys.stdout.write("\033[?25l")
    for t, l, s, g in script():
        start = time.time()
        img = frame(t, l, s) if l else None
        sys.stdout.write(compose(text, ttop, tleft, img, ctop, cleft, g))
        sys.stdout.flush()
        time.sleep(max(0, 1 / FPS - (time.time() - start)))
    sys.stdout.write("\033[0m\033[2J")
