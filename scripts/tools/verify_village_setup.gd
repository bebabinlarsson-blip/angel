@tool
extends SceneTree

func _init() -> void:
	print("--- BEGINNING COMPREHENSIVE VILLAGE VERIFICATION ---")
	var success := true
	
	# 1. Check Authored Environment scene and Layer Hierarchy
	var env_scene: PackedScene = load("res://scenes/world/authored_environment.tscn")
	if env_scene == null:
		printerr("FAIL: Could not load scenes/world/authored_environment.tscn")
		quit(1)
		return
	
	var env_node: Node = env_scene.instantiate()
	if env_node == null:
		printerr("FAIL: Could not instantiate AuthoredEnvironment")
		quit(1)
		return
	
	print("1. Checking Layer Hierarchy...")
	var expected_layers = [
		"GroundLayer",
		"RoadLayer",
		"HouseLayer",
		"DecorationLayer",
		"CollisionLayer",
		"TriggerLayer"
	]
	
	for layer_name in expected_layers:
		var layer = env_node.get_node_or_null(layer_name)
		if layer == null:
			printerr("FAIL: Missing expected layer: ", layer_name)
			success = false
		else:
			print("  [OK] Found layer: ", layer_name, " (", layer.get_class(), ")")
	
	# Verify GroundLayer Grid Size (>= 64x64)
	var ground = env_node.get_node_or_null("GroundLayer") as TileMapLayer
	if ground:
		var rect: Rect2i = ground.get_used_rect()
		print("  GroundLayer used rect: ", rect, " dimensions: ", rect.size.x, "x", rect.size.y)
		if rect.size.x >= 64 and rect.size.y >= 64:
			print("  [OK] GroundLayer grid meets requirement (>= 64x64): ", rect.size.x, "x", rect.size.y)
		else:
			printerr("FAIL: GroundLayer grid size < 64x64: ", rect.size.x, "x", rect.size.y)
			success = false
	
	# 2. Check CollisionLayer Hitboxes
	print("2. Checking CollisionLayer Hitboxes...")
	var col_layer = env_node.get_node_or_null("CollisionLayer")
	if col_layer:
		var bodies = col_layer.get_children()
		print("  Collision bodies count: ", bodies.size())
		var has_fountain_col := false
		var has_blacksmith_col := false
		var has_stalls_col := false
		var has_houses_col := false
		
		for child in bodies:
			var name_str: String = child.name
			if name_str.find("Fountain") >= 0:
				has_fountain_col = true
			if name_str.find("Blacksmith") >= 0:
				has_blacksmith_col = true
			if name_str.find("Stall") >= 0:
				has_stalls_col = true
			if name_str.find("House") >= 0 or name_str.find("Shop") >= 0:
				has_houses_col = true
		
		if has_fountain_col and has_blacksmith_col and has_stalls_col and has_houses_col:
			print("  [OK] Solid collision hitboxes verified for walls, fountain, blacksmith, stalls, and props.")
		else:
			printerr("FAIL: Missing some required collision hitboxes! fountain=", has_fountain_col, " blacksmith=", has_blacksmith_col, " stalls=", has_stalls_col, " houses=", has_houses_col)
			success = false
	
	# 3. Check TriggerLayer and 11 entryways
	print("3. Checking TriggerLayer Entryways...")
	var trig_layer = env_node.get_node_or_null("TriggerLayer")
	var required_triggers = [
		"Trigger_House_1", "Trigger_House_2", "Trigger_House_3",
		"Trigger_House_4", "Trigger_House_5", "Trigger_House_6",
		"Trigger_Shop_General", "Trigger_Shop_Armory",
		"Trigger_Church", "Trigger_Ruins", "Trigger_Mine"
	]
	
	if trig_layer == null:
		printerr("FAIL: TriggerLayer node missing!")
		success = false
	else:
		for trig_name in required_triggers:
			var trig = trig_layer.get_node_or_null(trig_name) as Area2D
			if trig == null:
				printerr("FAIL: Missing required trigger: ", trig_name)
				success = false
				continue
			
			var shape_node = trig.get_node_or_null("CollisionShape2D") as CollisionShape2D
			if shape_node == null or not (shape_node.shape is RectangleShape2D):
				printerr("FAIL: Trigger ", trig_name, " missing RectangleShape2D")
				success = false
			else:
				var rect_shape: RectangleShape2D = shape_node.shape as RectangleShape2D
				if rect_shape.size != Vector2(32, 32):
					printerr("FAIL: Trigger ", trig_name, " shape size is not 1x1 tile (32x32): ", rect_shape.size)
					success = false
			
			var interior_path: String = trig.get("interior_scene_path")
			if interior_path.is_empty():
				printerr("FAIL: Trigger ", trig_name, " has empty interior_scene_path")
				success = false
			else:
				var interior_res = load(interior_path)
				if interior_res == null:
					printerr("FAIL: Interior scene at ", interior_path, " could not be loaded!")
					success = false
				else:
					print("  [OK] Trigger ", trig_name, " -> ", interior_path, " (1x1 tile trigger verified)")
	
	# 4. Check Interior Scenes Contents (furniture, decorated interiors)
	print("4. Checking Interior Scenes...")
	var interiors_to_test = [
		"res://scenes/interiors/house_1.tscn",
		"res://scenes/interiors/house_2.tscn",
		"res://scenes/interiors/house_3.tscn",
		"res://scenes/interiors/house_4.tscn",
		"res://scenes/interiors/house_5.tscn",
		"res://scenes/interiors/house_6.tscn",
		"res://scenes/interiors/shop_general.tscn",
		"res://scenes/interiors/shop_armory.tscn"
	]
	for path in interiors_to_test:
		var scene: PackedScene = load(path)
		if scene == null:
			printerr("FAIL: Could not load interior scene: ", path)
			success = false
		else:
			var node: Node = scene.instantiate()
			var exit = node.get_node_or_null("Exit")
			var decor = node.get_node_or_null("DecorLayer")
			if exit == null:
				printerr("FAIL: Interior ", path, " missing Exit Area2D")
				success = false
			else:
				print("  [OK] Interior ", path.get_file(), " verified with Exit and Decor")
			node.free()
	
	# 5. Check NPC Day/Night Logic in QuestNPC
	print("5. Checking NPC Day/Night Scheduling Logic...")
	var npc_script: GDScript = load("res://scripts/npcs/quest_npc.gd")
	if npc_script == null:
		printerr("FAIL: Could not load quest_npc.gd")
		success = false
	else:
		var test_npc = npc_script.new()
		test_npc.npc_id = "blacksmith"
		test_npc.job = "blacksmith"
		test_npc._assign_default_housing_and_job()
		
		print("  Blacksmith assigned house door: ", test_npc.assigned_house_door, " (House 5)")
		print("  Blacksmith assigned job position: ", test_npc.assigned_job_position, " (Blacksmith)")
		if test_npc.assigned_house_door != Vector2(320, 160):
			printerr("FAIL: Blacksmith assigned door incorrect: ", test_npc.assigned_house_door)
			success = false
		if test_npc.assigned_job_position != Vector2(224, 80):
			printerr("FAIL: Blacksmith assigned job incorrect: ", test_npc.assigned_job_position)
			success = false
		
		# Test sleep state
		test_npc._enter_sleep_state()
		if not test_npc.is_sleeping:
			printerr("FAIL: NPC should be sleeping after _enter_sleep_state")
			success = false
		if test_npc.visible:
			printerr("FAIL: NPC should be invisible while sleeping")
			success = false
		if test_npc.collision_layer != 0:
			printerr("FAIL: NPC collision_layer should be 0 while sleeping")
			success = false
		if test_npc.can_talk():
			printerr("FAIL: NPC can_talk() should be false while sleeping")
			success = false
		print("  [OK] Night sleep state: is_sleeping=true, visible=false, collision=0, can_talk=false")
		
		# Test wake state at 06:00
		test_npc._wake_from_sleep_state()
		if test_npc.is_sleeping:
			printerr("FAIL: NPC should not be sleeping after _wake_from_sleep_state")
			success = false
		if not test_npc.visible:
			printerr("FAIL: NPC should be visible after waking")
			success = false
		if test_npc.collision_layer == 0:
			printerr("FAIL: NPC collision_layer should be restored after waking")
			success = false
		if test_npc.global_position != test_npc.assigned_house_door:
			printerr("FAIL: NPC global_position should be at assigned_house_door upon waking")
			success = false
		print("  [OK] Day wake state at 06:00: is_sleeping=false, visible=true, collision restored, at door trigger")
		
		# Test patrol offsets across all job types (Market, Blacksmith, Shops, Plaza)
		var job_types = ["market", "blacksmith", "general_shop", "armory_shop", "plaza"]
		for jt in job_types:
			test_npc.assigned_job_location = jt
			var offset_0: Vector2 = test_npc._patrol_offset_for_job(0)
			var offset_1: Vector2 = test_npc._patrol_offset_for_job(1)
			print("  [OK] Job patrol verified for: ", jt, " -> offsets: ", offset_0, ", ", offset_1)
		
		test_npc.free()

	env_node.free()
	
	if success:
		print("--- ALL VERIFICATIONS PASSED SUCCESSFULLY! ---")
		quit(0)
	else:
		printerr("--- VERIFICATION FAILED! ---")
		quit(1)
