#!/usr/bin/env python3
# Big Text: stdin lines -> ANSI Shadow block letters (figlet .flf, no smushing)
import sys, os

def load(path):
    with open(path, encoding="utf-8") as f:
        lines = f.read().split("\n")
    head = lines[0].split()
    hard, height, comments = head[0][5], int(head[1]), int(head[5])
    glyphs, i = {}, 1 + comments
    for code in range(32, 127):
        rows = [r.rstrip("\n").rstrip("@").replace(hard, " ") for r in lines[i:i + height]]
        width = max(len(r) for r in rows)
        glyphs[chr(code)] = [r.ljust(width) for r in rows]
        i += height
    return glyphs, height

glyphs, height = load(os.path.join(os.path.dirname(os.path.abspath(__file__)), "ansi-shadow.flf"))
out = []
for line in sys.stdin.read().strip("\n").split("\n"):
    chars = [glyphs.get(c, glyphs["?"]) for c in line.upper()]
    rows = ["".join(g[r] for g in chars).rstrip() for r in range(height)]
    while rows and not rows[-1].strip():
        rows.pop()
    out += rows + [""]
print("\n".join(out).rstrip("\n"))
