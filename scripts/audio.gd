extends Node
# Autoload "Audio" : gestionnaire centralisé des effets sonores. Le jeu était
# totalement silencieux jusqu'ici — aucun AudioStreamPlayer nulle part.

const SFX := {
	"attack_hit": "res://assets/audio/attack_hit.ogg",
	"skill_cast": "res://assets/audio/skill_cast.ogg",
	"gold_pickup": "res://assets/audio/gold_pickup.ogg",
	"chest_open": "res://assets/audio/chest_open.ogg",
	"item_pickup": "res://assets/audio/item_pickup.ogg",
	"potion_drink": "res://assets/audio/potion_drink.ogg",
	"level_up": "res://assets/audio/level_up.ogg",
	"quest_complete": "res://assets/audio/quest_complete.ogg",
	"ui_click": "res://assets/audio/ui_click.ogg",
	"death": "res://assets/audio/death.ogg",
	"dialogue_open": "res://assets/audio/dialogue_open.ogg",
}

var _cache: Dictionary = {}
# Pool de lecteurs tournants : évite de couper un son en cours si plusieurs
# effets se déclenchent la même frame (ex: plusieurs coups rapprochés).
var _pool: Array = []
var _pool_index := 0
const POOL_SIZE := 8

func _ready() -> void:
	for i in range(POOL_SIZE):
		var p = AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_pool.append(p)

func _load(key: String) -> AudioStream:
	if not SFX.has(key): return null
	if not _cache.has(key):
		_cache[key] = load(SFX[key])
	return _cache[key]

func play(key: String, volume_db: float = 0.0, pitch_variation: float = 0.0) -> void:
	var stream = _load(key)
	if stream == null: return
	var p: AudioStreamPlayer = _pool[_pool_index]
	_pool_index = (_pool_index + 1) % POOL_SIZE
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation) if pitch_variation > 0.0 else 1.0
	p.play()
