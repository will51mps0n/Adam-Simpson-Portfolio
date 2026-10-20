"""Generates src/shared/Rooms.luau: the arena maps and the lobby map.

Run from the block-horde folder:  python3 tools/make_rooms.py
Each map is checked: closed outer wall, entry gaps (S) only on the edge,
enough spawn (P) and ammo (A) cells, and every floor cell reachable.
"""
import random
from collections import deque

def blank(w, h):
    g = [["." for _ in range(w)] for _ in range(h)]
    for c in range(w):
        g[0][c] = g[h - 1][c] = "#"
    for r in range(h):
        g[r][0] = g[r][w - 1] = "#"
    return g

def rect(g, c0, r0, w, h, ch="#"):
    for r in range(r0, r0 + h):
        for c in range(c0, c0 + w):
            g[r][c] = ch

def gaps(g, side, positions, width=2):
    h, w = len(g), len(g[0])
    for p in positions:
        for k in range(width):
            if side == "N": g[0][p + k] = "S"
            if side == "S": g[h - 1][p + k] = "S"
            if side == "W": g[p + k][0] = "S"
            if side == "E": g[p + k][w - 1] = "S"

def put(g, cells, ch):
    for c, r in cells:
        assert g[r][c] == ".", (c, r, g[r][c], ch)
        g[r][c] = ch

def spawns_around(cc, rc):
    return [(cc - 2, rc - 1), (cc, rc - 1), (cc + 2, rc - 1), (cc - 2, rc + 1), (cc, rc + 1), (cc + 2, rc + 1)]

def check(name, g, playable=True):
    h, w = len(g), len(g[0])
    for row in g:
        assert len(row) == w, name
    for r in range(h):
        for c in range(w):
            edge = r in (0, h - 1) or c in (0, w - 1)
            if edge:
                assert g[r][c] in "#S", (name, "edge", c, r)
            else:
                assert g[r][c] != "S", (name, "inner S", c, r)
    count = lambda ch: sum(row.count(ch) for row in g)
    if playable:
        assert count("S") >= 4, name
        assert count("P") >= 6, name
        assert count("A") >= 4, name
        assert 30 <= w <= 48, (name, w)
    # Reachability from the first spawn cell over everything except walls.
    start = next((c, r) for r in range(h) for c in range(w) if g[r][c] == "P")
    seen = {start}
    q = deque([start])
    while q:
        c, r = q.popleft()
        for dc, dr in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (c + dc, r + dr)
            if 0 <= n[0] < w and 0 <= n[1] < h and n not in seen and g[n[1]][n[0]] != "#":
                seen.add(n)
                q.append(n)
    for r in range(h):
        for c in range(w):
            if g[r][c] != "#":
                assert (c, r) in seen, (name, "unreachable", c, r)
    # Each entry gap must open onto floor.
    for r in range(h):
        for c in range(w):
            if g[r][c] == "S":
                inward = (c, min(max(r, 1), h - 2)) if c in (0, w - 1) else None
                ic = 1 if c == 0 else w - 2 if c == w - 1 else c
                ir = 1 if r == 0 else h - 2 if r == h - 1 else r
                assert g[ir][ic] != "#", (name, "blocked gap", c, r)

# Boxy: open square, enemies pour in from the top and bottom.
def boxy():
    w, h = 36, 30
    g = blank(w, h)
    for c0, r0 in ((6, 6), (28, 6), (6, 22), (28, 22)):
        rect(g, c0, r0, 2, 2)
    gaps(g, "N", (7, 17, 27))
    gaps(g, "S", (7, 17, 27))
    put(g, spawns_around(18, 15), "P")
    put(g, [(3, 3), (32, 3), (3, 26), (32, 26), (18, 8), (18, 22)], "A")
    return g

# Columns: a grid of 2x2 pillars.
def columns():
    w, h = 40, 32
    g = blank(w, h)
    for r0 in range(4, h - 3, 6):
        for c0 in range(4, w - 3, 6):
            rect(g, c0, r0, 2, 2)
    gaps(g, "N", (7, 31))
    gaps(g, "S", (7, 31))
    gaps(g, "W", (8, 21))
    gaps(g, "E", (8, 21))
    put(g, [(17, 13), (19, 13), (21, 13), (17, 15), (19, 15), (21, 15)], "P")
    put(g, [(2, 2), (37, 2), (2, 29), (37, 29), (13, 19), (26, 13)], "A")
    return g

# Castle: an inner walled keep with a doorway on each side.
def castle():
    w, h = 44, 36
    g = blank(w, h)
    kc0, kr0, kw, kh = 13, 10, 18, 16
    rect(g, kc0, kr0, kw, 1)
    rect(g, kc0, kr0 + kh - 1, kw, 1)
    rect(g, kc0, kr0, 1, kh)
    rect(g, kc0 + kw - 1, kr0, 1, kh)
    # Corner towers.
    for c0, r0 in ((kc0 - 1, kr0 - 1), (kc0 + kw - 2, kr0 - 1), (kc0 - 1, kr0 + kh - 2), (kc0 + kw - 2, kr0 + kh - 2)):
        rect(g, c0, r0, 3, 3)
    # Doorways, 3 cells wide.
    mid_c, mid_r = kc0 + kw // 2, kr0 + kh // 2
    for k in (-1, 0, 1):
        g[kr0][mid_c + k] = "."
        g[kr0 + kh - 1][mid_c + k] = "."
        g[mid_r + k][kc0] = "."
        g[mid_r + k][kc0 + kw - 1] = "."
    gaps(g, "N", (6, 36))
    gaps(g, "S", (6, 36))
    gaps(g, "W", (5, 28))
    gaps(g, "E", (5, 28))
    put(g, spawns_around(mid_c, mid_r), "P")
    put(g, [(3, 3), (40, 3), (3, 32), (40, 32), (kc0 + 3, kr0 + 3), (kc0 + kw - 4, kr0 + kh - 4)], "A")
    return g

# Mazey: maze corridors three cells wide, with a few loops.
def mazey():
    kw, kh = 10, 8
    w, h = kw * 4 + 1, kh * 4 + 1
    g = [["#" for _ in range(w)] for _ in range(h)]
    rng = random.Random(7)
    def carve_cell(cx, cy):
        rect(g, cx * 4 + 1, cy * 4 + 1, 3, 3, ".")
    seen = set()
    stack = [(kw // 2, kh // 2)]
    seen.add(stack[0])
    carve_cell(*stack[0])
    while stack:
        cx, cy = stack[-1]
        options = [(cx + dx, cy + dy, dx, dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
                   if 0 <= cx + dx < kw and 0 <= cy + dy < kh and (cx + dx, cy + dy) not in seen]
        if not options:
            stack.pop()
            continue
        nx, ny, dx, dy = rng.choice(options)
        carve_cell(nx, ny)
        # Knock out the 3-wide wall between the two cells.
        if dx:
            wc = cx * 4 + (4 if dx > 0 else 0)
            rect(g, wc, cy * 4 + 1, 1, 3, ".")
        else:
            wr = cy * 4 + (4 if dy > 0 else 0)
            rect(g, cx * 4 + 1, wr, 3, 1, ".")
        seen.add((nx, ny))
        stack.append((nx, ny))
    # Extra openings so there is more than one way around.
    for _ in range(14):
        cx, cy = rng.randrange(kw - 1), rng.randrange(kh)
        rect(g, cx * 4 + 4, cy * 4 + 1, 1, 3, ".")
    for _ in range(10):
        cx, cy = rng.randrange(kw), rng.randrange(kh - 1)
        rect(g, cx * 4 + 1, cy * 4 + 4, 3, 1, ".")
    # Open plaza in the middle for spawning.
    pc, pr = (kw // 2) * 4 - 3, (kh // 2) * 4 - 3
    rect(g, pc, pr, 11, 7, ".")
    gaps(g, "N", (5, 33), width=3)
    gaps(g, "S", (5, 33), width=3)
    gaps(g, "W", (9, 21), width=3)
    gaps(g, "E", (9, 21), width=3)
    put(g, spawns_around(pc + 5, pr + 3), "P")
    put(g, [(2, 2), (w - 3, 2), (2, h - 3), (w - 3, h - 3), (pc + 1, pr + 1)], "A")
    return g

# Tight: a cramped room full of obstacles.
def tight():
    w, h = 30, 24
    g = blank(w, h)
    for c0, r0, cw, ch in ((5, 4, 4, 2), (21, 4, 4, 2), (5, 18, 4, 2), (21, 18, 4, 2), (13, 7, 4, 1), (13, 16, 4, 1), (4, 10, 1, 4), (25, 10, 1, 4)):
        rect(g, c0, r0, cw, ch)
    gaps(g, "W", (5, 17))
    gaps(g, "E", (5, 17))
    gaps(g, "N", (14,))
    put(g, spawns_around(15, 12), "P")
    put(g, [(2, 2), (27, 2), (2, 21), (27, 21), (15, 4)], "A")
    return g

# Strip: long and thin, enemies come from both ends.
def strip():
    w, h = 48, 20
    g = blank(w, h)
    for c0 in (10, 20, 27, 37):
        rect(g, c0, 4, 1, 4)
        rect(g, c0, 12, 1, 4)
    gaps(g, "W", (4, 9, 14))
    gaps(g, "E", (4, 9, 14))
    put(g, spawns_around(24, 10), "P")
    put(g, [(3, 2), (44, 2), (3, 17), (44, 17), (15, 10), (32, 10)], "A")
    return g

# Recty: big rectangles carve the room into lanes.
def recty():
    w, h = 42, 30
    g = blank(w, h)
    for c0, r0, cw, ch in ((5, 5, 10, 3), (27, 5, 10, 3), (5, 22, 10, 3), (27, 22, 10, 3), (5, 12, 3, 6), (34, 12, 3, 6)):
        rect(g, c0, r0, cw, ch)
    gaps(g, "N", (20,))
    gaps(g, "S", (20,))
    gaps(g, "W", (3, 24))
    gaps(g, "E", (3, 24))
    put(g, spawns_around(21, 15), "P")
    put(g, [(2, 2), (39, 2), (2, 27), (39, 27), (21, 9), (21, 21)], "A")
    return g

# Patchy: scattered patches of wall.
def patchy():
    w, h = 40, 32
    g = blank(w, h)
    rng = random.Random(11)
    placed = 0
    while placed < 16:
        cw, ch = rng.choice(((2, 3), (3, 2), (2, 2), (4, 1), (1, 4)))
        c0, r0 = rng.randrange(3, w - 3 - cw), rng.randrange(3, h - 3 - ch)
        if abs(c0 + cw / 2 - 20) < 6 and abs(r0 + ch / 2 - 16) < 5:
            continue
        if any(g[r][c] != "." for r in range(r0 - 1, r0 + ch + 1) for c in range(c0 - 1, c0 + cw + 1)):
            continue
        rect(g, c0, r0, cw, ch)
        placed += 1
    gaps(g, "N", (8, 30))
    gaps(g, "S", (8, 30))
    gaps(g, "W", (15,))
    gaps(g, "E", (15,))
    put(g, spawns_around(20, 16), "P")
    for c, r in ((2, 2), (37, 2), (2, 29), (37, 29), (20, 6), (20, 26)):
        if g[r][c] == ".":
            g[r][c] = "A"
    return g

ROOMS = [("Boxy", boxy), ("Columns", columns), ("Castle", castle), ("Mazey", mazey),
         ("Tight", tight), ("Strip", strip), ("Recty", recty), ("Patchy", patchy)]

def emit(name, g):
    lines = "\n".join('\t\t\t"%s",' % "".join(row) for row in g)
    return '\t%s = {\n\t\tname = "%s",\n\t\tmap = {\n%s\n\t\t},\n\t},\n' % (name, name.upper(), lines)

if __name__ == "__main__":
    import sys
    out = []
    for name, make in ROOMS:
        g = make()
        check(name, g)
        out.append(emit(name, g))
        if "-v" in sys.argv:
            print(name, len(g[0]), "x", len(g))
            print("\n".join("".join(r) for r in g))
    src = (
        "--!strict\n"
        "-- Generated by tools/make_rooms.py: edit that script, not this file.\n"
        "-- Room layouts as ASCII grids, one character per 4x4 stud cell.\n"
        "-- '#' wall, '.' floor, 'S' enemy entry gap, 'P' player spawn, 'A' ammo box spot.\n"
        "-- The top row is north, the top of the screen.\n\n"
        "local RoomGrid = require(script.Parent.RoomGrid)\n\n"
        "local Rooms = {}\n\n"
        "-- Arenas in the order the party menu lists them.\n"
        "Rooms.ORDER = { %s }\n\n" % ", ".join('"%s"' % n for n, _ in ROOMS)
        + "Rooms.ARENAS = {\n" + "".join(out) + "} :: { [string]: RoomGrid.RoomDef }\n\nreturn Rooms\n"
    )
    open("src/shared/Rooms.luau", "w").write(src)
    print("wrote %d arenas" % len(ROOMS))
