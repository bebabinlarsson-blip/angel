import os

INTERIORS = [
    {
        "filename": "house_1.tscn",
        "id": "house_1",
        "display_name": "Lina's House",
        "theme_kind": "house",
        "tiles_file": "house_tiles.tscn",
        "decor": "Bed, Table, Chairs, Fireplace, Shelves (Cozy Cottage)"
    },
    {
        "filename": "house_2.tscn",
        "id": "house_2",
        "display_name": "Baker's House",
        "theme_kind": "house",
        "tiles_file": "house_tiles.tscn",
        "decor": "Bed, Prep Table, Bread Pantry, Hearth, Shelves"
    },
    {
        "filename": "house_3.tscn",
        "id": "house_3",
        "display_name": "Guard's House",
        "theme_kind": "house",
        "tiles_file": "house_tiles.tscn",
        "decor": "Cot Bed, Strategy Table, Weapon Rack, Fireplace, Footlocker"
    },
    {
        "filename": "house_4.tscn",
        "id": "house_4",
        "display_name": "Elder's House",
        "theme_kind": "house",
        "tiles_file": "house_tiles.tscn",
        "decor": "Ornate Bed, Council Table, Archive Shelves, Grand Fireplace"
    },
    {
        "filename": "house_5.tscn",
        "id": "house_5",
        "display_name": "Craftsman's House",
        "theme_kind": "house",
        "tiles_file": "house_tiles.tscn",
        "decor": "Bed, Woodworking Bench, Tool Cabinets, Stove, Chairs"
    },
    {
        "filename": "house_6.tscn",
        "id": "house_6",
        "display_name": "Herbalist's House",
        "theme_kind": "house",
        "tiles_file": "house_tiles.tscn",
        "decor": "Bed, Brewing Table, Herb Jars, Hearth, Specimen Shelves"
    },
    {
        "filename": "shop_general.tscn",
        "id": "shop_general",
        "display_name": "General Goods",
        "theme_kind": "house",
        "tiles_file": "house_tiles.tscn",
        "decor": "Trade Counter, Goods Shelves, Display Cabinets, Storage Crates"
    },
    {
        "filename": "shop_armory.tscn",
        "id": "shop_armory",
        "display_name": "Armory",
        "theme_kind": "house",
        "tiles_file": "house_tiles.tscn",
        "decor": "Reinforced Counter, Weapon Displays, Armor Racks, Forge Hearth"
    },
]

TEMPLATE = """[gd_scene format=3]

[ext_resource type="Script" path="res://scripts/world/interior_scene.gd" id="1_interior"]
[ext_resource type="Script" path="res://scripts/world/interior_visual.gd" id="2_visual"]
[ext_resource type="Script" path="res://scripts/world/interior_exit.gd" id="3_exit"]
[ext_resource type="PackedScene" path="res://scenes/player/player.tscn" id="4_player"]
[ext_resource type="Script" path="res://scripts/systems/quest_system.gd" id="5_quests"]
[ext_resource type="Script" path="res://scripts/systems/cooking_system.gd" id="6_cooking"]
[ext_resource type="PackedScene" path="res://scenes/ui/hud.tscn" id="7_hud"]
[ext_resource type="PackedScene" path="res://scenes/ui/pause_menu.tscn" id="8_pause"]
[ext_resource type="PackedScene" path="res://scenes/ui/inventory.tscn" id="9_inventory"]
[ext_resource type="PackedScene" path="res://scenes/ui/quest_menu.tscn" id="10_quest_menu"]
[ext_resource type="PackedScene" path="res://scenes/ui/game_over.tscn" id="11_game_over"]
[ext_resource type="PackedScene" path="res://scenes/interiors/{tiles_file}" id="12_tiles"]

[sub_resource type="CircleShape2D" id="CircleShape_exit"]
radius = 36.0

[node name="{node_name}" type="Node2D"]
script = ExtResource("1_interior")
interior_id = "{interior_id}"
display_name = "{display_name}"
theme_kind = "{theme_kind}"
room_size = Vector2(960, 640)

[node name="InteriorVisual" type="Node2D" parent="."]
script = ExtResource("2_visual")
theme_kind = "{theme_kind}"
room_size = Vector2(960, 640)
visible = false

[node name="InteriorTilemap" parent="." instance=ExtResource("12_tiles")]

[node name="Player" parent="." instance=ExtResource("4_player")]
position = Vector2(0, 180)

[node name="Exit" type="Area2D" parent="."]
position = Vector2(0, 270)
script = ExtResource("3_exit")

[node name="CollisionShape2D" type="CollisionShape2D" parent="Exit"]
shape = SubResource("CircleShape_exit")

[node name="QuestSystem" type="Node" parent="."]
script = ExtResource("5_quests")

[node name="CookingSystem" type="Node" parent="."]
script = ExtResource("6_cooking")

[node name="HUD" parent="." instance=ExtResource("7_hud")]

[node name="UILayer" type="CanvasLayer" parent="."]

[node name="PauseMenu" parent="UILayer" instance=ExtResource("8_pause")]

[node name="InventoryUI" parent="UILayer" instance=ExtResource("9_inventory")]

[node name="QuestMenu" parent="UILayer" instance=ExtResource("10_quest_menu")]

[node name="GameOver" parent="UILayer" instance=ExtResource("11_game_over")]
"""

def main():
    target_dir = os.path.join(os.getcwd(), "scenes", "interiors")
    for item in INTERIORS:
        node_name = "".join([part.capitalize() for part in item["id"].split("_")])
        content = TEMPLATE.format(
            tiles_file=item["tiles_file"],
            node_name=node_name,
            interior_id=item["id"],
            display_name=item["display_name"],
            theme_kind=item["theme_kind"]
        )
        file_path = os.path.join(target_dir, item["filename"])
        with open(file_path, "w", encoding="utf-8") as f:
            f.write(content)
        print(f"Created {item['filename']}")

if __name__ == "__main__":
    main()
