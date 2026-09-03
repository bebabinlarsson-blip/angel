import os

tres_content = """[gd_resource type="TileSet" load_steps=3 format=3 uid="uid://dfkwy28shg5a8"]

[ext_resource type="Texture2D" uid="uid://blak8q76y5v2a" path="res://assets/tilesets/atlas_tileset.png" id="1_atlas"]

[sub_resource type="TileSetAtlasSource" id="TileSetAtlasSource_k7f2b"]
texture = ExtResource("1_atlas")
texture_region_size = Vector2i(32, 32)
"""

# Let's say tiles in row 2 (y=2) are rocks/cliffs and need collision.
for x in range(32):
    for y in range(21):
        tres_content += f"{x}:{y}/0 = 0\n"
        # Adding physics to water (y=5, x=5) and rocks (y=2, x=0 to 10)
        if (y == 2 and x <= 10) or (y == 5 and x == 5):
            tres_content += f"{x}:{y}/0/physics_layer_0/polygon_0/points = PackedVector2Array(-16, -16, 16, -16, 16, 16, -16, 16)\n"

tres_content += """
[resource]
tile_size = Vector2i(32, 32)
physics_layer_0/collision_layer = 1
physics_layer_0/collision_mask = 1
sources/1 = SubResource("TileSetAtlasSource_k7f2b")
"""

with open(r"c:\Users\Benji-Laptop\Documents\angel\assets\tilesets\grass_tileset.tres", "w") as f:
    f.write(tres_content)

print("Updated grass_tileset.tres with collision")
