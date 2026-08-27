extends Node
# Autoload "Net" : connexion multijoueur (ENet, coop hébergée par un joueur hôte, jusqu'à 4).

const PORT := 27015
const MAX_PLAYERS := 4

signal player_joined(peer_id)
signal player_left(peer_id)
signal connected_ok()
signal connect_failed()

var is_online: bool = false

func host_game() -> String:
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(PORT, MAX_PLAYERS - 1)
	if err != OK:
		return ""
	multiplayer.multiplayer_peer = peer
	is_online = true
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	return get_local_ip()

func join_game(ip: String) -> void:
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_client(ip, PORT)
	if err != OK:
		emit_signal("connect_failed")
		return
	multiplayer.multiplayer_peer = peer
	is_online = true
	multiplayer.connected_to_server.connect(func(): emit_signal("connected_ok"))
	multiplayer.connection_failed.connect(func(): emit_signal("connect_failed"))
	multiplayer.server_disconnected.connect(func(): emit_signal("connect_failed"))

func _on_peer_connected(id: int) -> void:
	emit_signal("player_joined", id)

func _on_peer_disconnected(id: int) -> void:
	emit_signal("player_left", id)

func get_local_ip() -> String:
	for ip in IP.get_local_addresses():
		if ip.begins_with("192.168.") or ip.begins_with("10.") or ip.begins_with("172."):
			return ip
	return "127.0.0.1"

func disconnect_all() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	is_online = false
