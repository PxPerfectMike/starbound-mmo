"""
Generate the MMO Hub dungeon PNG for Starbound.
Each pixel = one tile. Colors map to brushes in mmo_hub.dungeon.

Layout: A massive planet-like surface with deep ground, cliff walls
at the edges, and the hub station built in the center.
480 tiles wide, 120 tiles tall.
"""

from PIL import Image
import random

random.seed(42)

W, H = 480, 120

# === Color Palette (must match mmo_hub.dungeon exactly) ===
CLEAR         = (0, 0, 0, 255)
PLAYERSTART   = (255, 255, 0, 255)

# MMO objects
HUBRETURN     = (255, 0, 0, 255)
MARKET        = (0, 255, 0, 255)
MAILBOX       = (0, 0, 255, 255)
HUBBEACON     = (255, 0, 255, 255)

# Structure
STRUCT        = (120, 120, 120, 255)
FOUNDATION    = (80, 80, 80, 255)
FLOOR         = (110, 110, 130, 255)
WALL_BACK     = (90, 90, 110, 255)
THICK_WALL    = (70, 70, 90, 255)

# Interior
INTERIOR      = (60, 60, 60, 255)
INT_DARK      = (40, 40, 40, 255)

# Platform
PLATFORM      = (150, 150, 170, 255)

# Indoor objects
LIGHT_CEIL    = (255, 255, 200, 255)
LIGHT_NEON    = (150, 150, 255, 255)
TORCH_INDOOR  = (255, 200, 100, 255)
BENCH_INDOOR  = (170, 130, 90, 255)
BARREL_INDOOR = (130, 100, 70, 255)
CRATE_INDOOR  = (100, 60, 30, 255)
FLOWER_INDOOR = (0, 200, 100, 255)
CHAIR         = (139, 90, 43, 255)
TABLE         = (160, 110, 60, 255)

# Terrain
DIRT          = (90, 60, 35, 255)
GRASSY        = (60, 90, 40, 255)
PACKED_DIRT   = (75, 55, 30, 255)
COBBLE        = (100, 100, 100, 255)
ROCK1         = (65, 65, 65, 255)
ROCK2         = (55, 55, 55, 255)
OBSIDIAN      = (45, 45, 50, 255)
COBBLE_UNDER  = (85, 75, 65, 255)

# Outdoor objects
LAMPPOST      = (200, 180, 0, 255)
CARGO         = (140, 120, 100, 255)
TORCH_OUT     = (255, 180, 80, 255)
BENCH_OUT     = (170, 130, 80, 255)
CRATE_OUT     = (100, 60, 20, 255)
BARREL_OUT    = (130, 100, 60, 255)
FLOWER_OUT    = (0, 200, 90, 255)

img = Image.new("RGBA", (W, H), CLEAR)

def px(x, y, color):
    if 0 <= x < W and 0 <= y < H:
        img.putpixel((x, y), color)

def hline(x1, x2, y, color):
    for x in range(max(0, x1), min(W, x2 + 1)):
        px(x, y, color)

def fill_rect(x1, y1, x2, y2, color):
    for y in range(max(0, y1), min(H, y2 + 1)):
        hline(x1, x2, y, color)

# ============================================================
# TERRAIN PARAMETERS
# ============================================================
GROUND_Y = 50          # Surface level (grassy top)
CLIFF_WIDTH = 12       # Width of cliff walls at edges
CLIFF_HEIGHT = 30      # How tall the cliffs are above ground

# ============================================================
# CLIFF WALLS AT EDGES (prevents falling off)
# ============================================================
# Left cliff: solid rock wall from deep underground up above ground
cliff_top_L = GROUND_Y - CLIFF_HEIGHT
for y in range(cliff_top_L, H):
    hline(0, CLIFF_WIDTH - 1, y, ROCK1)
# Taper the top of the cliff
for i in range(5):
    hline(0, CLIFF_WIDTH - 1 - i, cliff_top_L + i, ROCK1 if i < 3 else ROCK2)
# Grassy cap on cliff
hline(0, CLIFF_WIDTH - 4, cliff_top_L, GRASSY)

# Right cliff
for y in range(cliff_top_L, H):
    hline(W - CLIFF_WIDTH, W - 1, y, ROCK1)
for i in range(5):
    hline(W - CLIFF_WIDTH + i, W - 1, cliff_top_L + i, ROCK1 if i < 3 else ROCK2)
hline(W - CLIFF_WIDTH + 4, W - 1, cliff_top_L, GRASSY)

# Inner cliff face has some variation
for y in range(cliff_top_L + 5, GROUND_Y):
    if y % 3 == 0:
        px(CLIFF_WIDTH, y, ROCK2)
        px(W - CLIFF_WIDTH - 1, y, ROCK2)

# ============================================================
# GROUND SURFACE - full width between cliffs
# ============================================================
terrain_left = CLIFF_WIDTH
terrain_right = W - CLIFF_WIDTH - 1

# Grassy surface
hline(terrain_left, terrain_right, GROUND_Y, GRASSY)

# Terrain height variations (gentle hills)
hills = [
    (30, 55, 2),     # left hill
    (70, 90, 1),     # small bump
    (390, 410, 1),   # small bump right
    (425, 455, 2),   # right hill
]
for hstart, hend, height in hills:
    for h in range(height):
        y = GROUND_Y - 1 - h
        margin = h * 2  # hills taper at top
        hline(hstart + margin, hend - margin, y, GRASSY)
        hline(hstart + margin, hend - margin, y + 1, DIRT if h > 0 else GRASSY)
        # Fill dirt below the raised grass
        hline(hstart + margin, hend - margin, GROUND_Y, DIRT)

# ============================================================
# UNDERGROUND LAYERS - deep and varied
# ============================================================
# Layer 1: Dirt (0-8 tiles below surface)
for dy in range(1, 9):
    hline(0, W - 1, GROUND_Y + dy, DIRT)

# Layer 2: Packed dirt (8-14 below)
for dy in range(9, 15):
    hline(0, W - 1, GROUND_Y + dy, PACKED_DIRT)

# Layer 3: Cobblestone transition (14-18 below)
for dy in range(15, 19):
    hline(0, W - 1, GROUND_Y + dy, COBBLE_UNDER)

# Layer 4: Rock (18-30 below)
for dy in range(19, 31):
    hline(0, W - 1, GROUND_Y + dy, ROCK1)

# Layer 5: Deeper rock (30-40 below)
for dy in range(31, 41):
    hline(0, W - 1, GROUND_Y + dy, ROCK2)

# Layer 6: Obsidian bedrock (40+ below, to bottom)
for dy in range(41, H - GROUND_Y):
    hline(0, W - 1, GROUND_Y + dy, OBSIDIAN)

# Scatter some rock variation in dirt layers
random.seed(42)
for _ in range(200):
    rx = random.randint(0, W - 1)
    ry = random.randint(GROUND_Y + 5, GROUND_Y + 14)
    px(rx, ry, COBBLE_UNDER)

for _ in range(150):
    rx = random.randint(0, W - 1)
    ry = random.randint(GROUND_Y + 12, GROUND_Y + 25)
    px(rx, ry, ROCK1)

# ============================================================
# BUILDING - Centered hub station
# ============================================================
BLDG_LEFT = 190
BLDG_RIGHT = 290
BLDG_ROOF = GROUND_Y - 17
BLDG_FLOOR = GROUND_Y

# --- Foundation: cut into ground ---
fill_rect(BLDG_LEFT - 1, GROUND_Y, BLDG_RIGHT + 1, GROUND_Y + 4, FOUNDATION)

# --- Floor (2 tiles thick) ---
hline(BLDG_LEFT, BLDG_RIGHT, BLDG_FLOOR, FLOOR)
hline(BLDG_LEFT, BLDG_RIGHT, BLDG_FLOOR - 1, FLOOR)

# --- Roof ---
hline(BLDG_LEFT + 3, BLDG_RIGHT - 3, BLDG_ROOF, STRUCT)
hline(BLDG_LEFT + 2, BLDG_RIGHT - 2, BLDG_ROOF + 1, STRUCT)
hline(BLDG_LEFT + 1, BLDG_RIGHT - 1, BLDG_ROOF + 2, WALL_BACK)
hline(BLDG_LEFT, BLDG_RIGHT, BLDG_ROOF + 3, WALL_BACK)

# --- Walls ---
wall_top = BLDG_ROOF + 4
wall_bot = BLDG_FLOOR - 2

for y in range(wall_top, wall_bot + 1):
    px(BLDG_LEFT, y, WALL_BACK)
    px(BLDG_LEFT + 1, y, THICK_WALL)
    px(BLDG_RIGHT - 1, y, THICK_WALL)
    px(BLDG_RIGHT, y, WALL_BACK)
    hline(BLDG_LEFT + 2, BLDG_RIGHT - 2, y, INTERIOR)

# --- Doorways (both sides, 5 tiles tall) ---
for y in range(wall_bot - 4, wall_bot + 1):
    px(BLDG_LEFT, y, INTERIOR)
    px(BLDG_LEFT + 1, y, INTERIOR)
    px(BLDG_RIGHT - 1, y, INTERIOR)
    px(BLDG_RIGHT, y, INTERIOR)

# ============================================================
# INTERIOR DETAILS
# ============================================================

# Ceiling lights
for x in range(BLDG_LEFT + 5, BLDG_RIGHT - 3, 8):
    px(x, wall_top, LIGHT_CEIL)

# Mezzanine platforms
mezz_y = wall_top + 4
hline(BLDG_LEFT + 4, BLDG_LEFT + 20, mezz_y, PLATFORM)
hline(BLDG_RIGHT - 20, BLDG_RIGHT - 4, mezz_y, PLATFORM)

# Neon accents
for x in range(BLDG_LEFT + 7, BLDG_RIGHT - 5, 12):
    px(x, wall_top + 2, LIGHT_NEON)

# Mezzanine furniture
mezz_obj_y = mezz_y - 1
px(BLDG_LEFT + 6, mezz_obj_y, CHAIR)
px(BLDG_LEFT + 8, mezz_obj_y, TABLE)
px(BLDG_LEFT + 10, mezz_obj_y, CHAIR)
px(BLDG_LEFT + 16, mezz_obj_y, BARREL_INDOOR)

px(BLDG_RIGHT - 18, mezz_obj_y, CRATE_INDOOR)
px(BLDG_RIGHT - 15, mezz_obj_y, BARREL_INDOOR)
px(BLDG_RIGHT - 9, mezz_obj_y, BENCH_INDOOR)
px(BLDG_RIGHT - 6, mezz_obj_y, FLOWER_INDOOR)

# Wall torches
px(BLDG_LEFT + 3, wall_bot - 4, TORCH_INDOOR)
px(BLDG_RIGHT - 3, wall_bot - 4, TORCH_INDOOR)

# Ground floor objects
obj_y = BLDG_FLOOR - 2

px(BLDG_LEFT + 6, obj_y, HUBRETURN)
px(BLDG_LEFT + 14, obj_y, BENCH_INDOOR)
px(BLDG_LEFT + 16, obj_y, TABLE)
px(BLDG_LEFT + 18, obj_y, CHAIR)
px(BLDG_LEFT + 24, obj_y, MARKET)
px(BLDG_LEFT + 28, obj_y, BARREL_INDOOR)
px(BLDG_LEFT + 30, obj_y, CRATE_INDOOR)

center_x = (BLDG_LEFT + BLDG_RIGHT) // 2
px(center_x, obj_y, MARKET)          # second market terminal (center)
px(center_x + 5, obj_y, FLOWER_INDOOR)

# Player spawn: just inside the left entrance of the building
# obj_y is the clear row above the floor, inside the building
px(BLDG_LEFT + 3, obj_y, PLAYERSTART)

px(BLDG_LEFT + 50, obj_y, MAILBOX)
px(BLDG_LEFT + 56, obj_y, BENCH_INDOOR)
px(BLDG_LEFT + 58, obj_y, TABLE)
px(BLDG_RIGHT - 16, obj_y, MARKET)   # third market terminal (right side)
px(BLDG_RIGHT - 8, obj_y, HUBBEACON)
px(BLDG_RIGHT - 4, obj_y, FLOWER_INDOOR)

# ============================================================
# OUTDOOR DECORATIONS
# ============================================================
outdoor_obj_y = GROUND_Y - 1

# Cobblestone paths to entrances (replace grass at ground level only)
hline(BLDG_LEFT - 20, BLDG_LEFT - 1, GROUND_Y, COBBLE)
hline(BLDG_RIGHT + 1, BLDG_RIGHT + 20, GROUND_Y, COBBLE)

# Lampposts along paths and scattered
for lx in [BLDG_LEFT - 10, BLDG_LEFT - 25, BLDG_RIGHT + 10, BLDG_RIGHT + 25,
           60, 100, 140, 340, 380, 420]:
    px(lx, outdoor_obj_y, LAMPPOST)

# Shipping containers near building
px(BLDG_LEFT - 5, outdoor_obj_y, CARGO)
px(BLDG_RIGHT + 5, outdoor_obj_y, CARGO)

# Outdoor benches
for bx in [BLDG_LEFT - 15, BLDG_RIGHT + 15, 80, 120, 360, 400]:
    px(bx, outdoor_obj_y, BENCH_OUT)

# Flowerpots scattered
for fx in [BLDG_LEFT - 30, BLDG_RIGHT + 30, 50, 90, 150, 330, 390, 430]:
    px(fx, outdoor_obj_y, FLOWER_OUT)

# Crates and barrels scattered
for cx in [40, 110, 160, 320, 370, 440]:
    px(cx, outdoor_obj_y, CRATE_OUT)
for bx in [45, 115, 155, 325, 365, 435]:
    px(bx, outdoor_obj_y, BARREL_OUT)

# Torches for lighting across the terrain
for tx in range(25, W - 25, 20):
    if not (BLDG_LEFT - 2 <= tx <= BLDG_RIGHT + 2):
        px(tx, outdoor_obj_y, TORCH_OUT)

# ============================================================
# SAVE
# ============================================================
out_path = r"C:\repos\starbound-mmo\mod\dungeons\mmo\hub\mmo_hub.png"
img.save(out_path)
print(f"Generated {out_path} ({W}x{H})")
print(f"Building: cols {BLDG_LEFT}-{BLDG_RIGHT} ({BLDG_RIGHT - BLDG_LEFT} tiles wide)")
print(f"Ground level: row {GROUND_Y}")
print(f"Ground depth: {H - GROUND_Y} tiles (dirt -> packed dirt -> cobble -> rock -> obsidian)")
print(f"Cliff walls: {CLIFF_WIDTH} tiles thick, {CLIFF_HEIGHT} tiles above ground")
print(f"Terrain: {W} tiles wide, playable area {terrain_right - terrain_left} tiles")
print(f"Player spawn at ({center_x}, {obj_y})")
