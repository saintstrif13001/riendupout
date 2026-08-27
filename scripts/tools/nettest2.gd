extends SceneTree
# Test minimal: la connexion tient-elle dans la durée, ou se coupe-t-elle toujours peu après ?
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
			print("HOST_STARTED ip=%s t=%d" % [ip, frame_count])
			net.player_joined.connect(func(id): print("HOST_SAW_PEER id=%d t=%d" % [id, frame_count]))
			net.player_left.connect(func(id): print("HOST_LOST_PEER id=%d t=%d" % [id, frame_count]))
		else:
			net.connected_ok.connect(func(): print("CLIENT_CONNECTED t=%d" % frame_count))
			net.connect_failed.connect(func(): print("CLIENT_FAILED t=%d" % frame_count))
			net.join_game("127.0.0.1")
			print("CLIENT_JOINING t=%d" % frame_count)

	if frame_count % 60 == 0 and frame_count > 0:
		var mp = get_multiplayer()
		var mp_peer = mp.multiplayer_peer
		var status = mp_peer.get_connection_status() if mp_peer else -1
		print("[%s] alive t=%d peer_status=%s unique_id=%s" % [role, frame_count, status, (mp.get_unique_id() if mp_peer else "n/a")])

	if frame_count > 600: # 10s
		print("[%s] DONE t=%d" % [role, frame_count])
		return true
	return false
