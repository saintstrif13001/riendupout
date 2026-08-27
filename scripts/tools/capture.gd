extends SceneTree
# Outil de capture d'écran hors-ligne pour vérification visuelle par l'agent.
# Usage: godot --rendering-driver opengl3 --path <proj> -s scripts/tools/capture.gd -- <scene_res_path> <out_png_path> [wait_frames]

var frame_count := 0
var wait_frames := 20
var out_path := "user://screenshot.png"
var scene_path := "res://scenes/Main.tscn"
var stage := 0 # 0=attente autoloads, 1=scene instanciée+attente rendu, 2=fait

func _initialize() -> void:
	var args = OS.get_cmdline_user_args()
	scene_path = args[0] if args.size() > 0 else "res://scenes/Main.tscn"
	out_path = args[1] if args.size() > 1 else "user://screenshot.png"
	wait_frames = int(args[2]) if args.size() > 2 else 20
	root.size = Vector2i(1152, 648)

func _process(delta: float) -> bool:
	if stage == 0:
		stage = 1
		if scene_path == "res://scenes/World.tscn":
			var gs = root.get_node("/root/GameState")
			gs.mode = "solo"
			gs.char_data = gs.new_character("Testeur", "humain", "guerrier")
		var packed: PackedScene = load(scene_path)
		var inst = packed.instantiate()
		root.add_child(inst)
		var args = OS.get_cmdline_user_args()
		if args.size() > 3 and inst.has_method("get") and "player" in inst:
			var zone_id = args[3]
			var data = root.get_node("/root/Data")
			if data.ZONES.has(zone_id):
				var z = data.ZONES[zone_id]
				inst.player.global_position = Vector2(z.x0 + 300, data.WORLD_HEIGHT/2.0)
				var cam = inst.player.get_node_or_null("Camera2D")
				if cam: cam.reset_smoothing()
		return false

	frame_count += 1
	if frame_count < wait_frames:
		return false

	var img = root.get_texture().get_image()
	var err = img.save_png(out_path)
	print("SAVE_RESULT:%d PATH:%s" % [err, out_path])
	return true
