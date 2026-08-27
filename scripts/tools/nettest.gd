extends SceneTree
# Test de connectivité réseau ENet (host/client) via boucle locale.
# Usage: godot --headless --path <proj> -s scripts/tools/nettest.gd -- host|client

var role := "host"
var frame_count := 0
var net = null

func _initialize() -> void:
	var args = OS.get_cmdline_user_args()
	role = args[0] if args.size() > 0 else "host"

func _process(delta: float) -> bool:
	frame_count += 1
	if frame_count == 2:
		net = root.get_node("/root/Net")
		if role == "host":
			var ip = net.host_game()
			print("HOST_STARTED ip=%s" % ip)
			net.player_joined.connect(func(id): print("HOST_SAW_PEER id=%d" % id))
		else:
			net.connected_ok.connect(func(): print("CLIENT_CONNECTED"))
			net.connect_failed.connect(func(): print("CLIENT_FAILED"))
			net.join_game("127.0.0.1")
			print("CLIENT_JOINING")

	if frame_count > 240: # ~4s à 60fps
		print("TIMEOUT_QUIT role=%s" % role)
		return true
	return false
