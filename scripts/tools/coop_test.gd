extends SceneTree
# Test de coop de bout en bout : deux instances (host/client) chargent World.tscn
# réellement, se connectent via ENet, et on vérifie que chacune voit le joueur distant
# se synchroniser (position) via les RPC.
# Usage: godot --headless --path <proj> -s scripts/tools/coop_test.gd -- host|client [ip]

var role := "host"
var join_ip := "127.0.0.1"
var stage := 0
var inst = null
var frame_count := 0

func _initialize() -> void:
	var args = OS.get_cmdline_user_args()
	role = args[0] if args.size() > 0 else "host"
	join_ip = args[1] if args.size() > 1 else "127.0.0.1"
	root.size = Vector2i(800, 600)

func _process(delta: float) -> bool:
	frame_count += 1
	match stage:
		0:
			var net = root.get_node("/root/Net")
			var gs = root.get_node("/root/GameState")
			gs.mode = "host" if role == "host" else "join"
			gs.char_data = gs.new_character(role, "humain", "guerrier")
			if role == "host":
				var ip = net.host_game()
				print("[%s] HOST_IP=%s" % [role, ip])
				stage = 2 # l'hôte peut lancer le monde tout de suite
			else:
				net.connected_ok.connect(func(): print("[%s] CONNECTED" % role); stage = 1)
				net.connect_failed.connect(func(): print("[%s] CONNECT_FAILED" % role))
				net.join_game(join_ip)
				stage = 10
			return false
		10:
			if frame_count > 300: print("[%s] TIMEOUT waiting connection" % role); return true
			return false
		1:
			# le client attend un peu que le host ait eu le temps de lancer son monde
			if frame_count < 60: return false
			stage = 2
			return false
		2:
			var packed: PackedScene = load("res://scenes/World.tscn")
			inst = packed.instantiate()
			root.add_child(inst)
			print("[%s] WORLD_LOADED is_sim=%s" % [role, inst.is_sim])
			stage = 3
			frame_count = 0
			return false
		3:
			if frame_count < 180: return false # ~3s pour laisser les RPC de position circuler
			var remote_count = inst.remote_players.size()
			var remote_names = []
			for pid in inst.remote_players.keys():
				remote_names.append(inst.remote_players[pid].char_data.name)
			print("[%s] RESULT remote_players=%d names=%s my_pos=%s" % [role, remote_count, remote_names, inst.player.global_position])
			return true
	return false
