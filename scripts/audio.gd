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
const SETTINGS_PATH := "user://settings.cfg"
var master_volume: float = 0.8 # 0.0 (muet) à 1.0 (plein volume), linéaire pour le curseur UI
var music_volume: float = 0.5

# --- Musique d'ambiance procédurale --------------------------------------
# Aucune piste musicale n'existait (uniquement des bruitages ponctuels) et
# aucune source CC0 fiable de boucles d'ambiance n'a été trouvée. Génère donc
# deux nappes synthétiques (accord calme / accord tendu) en direct via
# AudioStreamGenerator, et fait un fondu enchaîné entre les deux selon que la
# zone du joueur est sûre ou non (voir set_zone_mood, appelé par world.gd).
const MUSIC_MIX_RATE := 44100.0
const MUSIC_BUFFER_LEN := 2.0
const CALM_FREQS := [130.81, 164.81, 196.00] # accord majeur doux (Do-Mi-Sol)
const TENSION_FREQS := [110.00, 130.81, 155.56] # accord mineur plus sombre (La-Do-Mib)
var _music_calm_player: AudioStreamPlayer
var _music_tension_player: AudioStreamPlayer
var _calm_playback: AudioStreamGeneratorPlayback
var _tension_playback: AudioStreamGeneratorPlayback
var _calm_phases: Array = [0.0, 0.0, 0.0]
var _tension_phases: Array = [0.0, 0.0, 0.0]
var _calm_gain := 1.0
var _tension_gain := 0.0
var _target_mood_is_safe := true
var _lfo_phase := 0.0

func _ready() -> void:
	for i in range(POOL_SIZE):
		var p = AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_pool.append(p)
	_ensure_music_bus()
	_music_calm_player = _make_music_player()
	_music_tension_player = _make_music_player()
	_calm_playback = _music_calm_player.get_stream_playback()
	_tension_playback = _music_tension_player.get_stream_playback()
	_load_settings()
	_apply_master_volume()

func _ensure_music_bus() -> void:
	if AudioServer.get_bus_index("Music") != -1: return
	var idx = AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, "Music")
	AudioServer.set_bus_send(idx, "Master") # le volume/mute général affecte aussi la musique

func _make_music_player() -> AudioStreamPlayer:
	var gen = AudioStreamGenerator.new()
	gen.mix_rate = MUSIC_MIX_RATE
	gen.buffer_length = MUSIC_BUFFER_LEN
	var p = AudioStreamPlayer.new()
	p.stream = gen
	p.bus = "Music"
	p.volume_db = -80.0
	add_child(p)
	p.play()
	return p

func set_zone_mood(is_safe: bool) -> void:
	_target_mood_is_safe = is_safe

func _process(delta: float) -> void:
	_lfo_phase = fmod(_lfo_phase + delta * 0.6, TAU)
	_calm_gain = move_toward(_calm_gain, 1.0 if _target_mood_is_safe else 0.0, delta * 0.15)
	_tension_gain = move_toward(_tension_gain, 0.0 if _target_mood_is_safe else 1.0, delta * 0.15)
	_music_calm_player.volume_db = _gain_to_db(_calm_gain * music_volume)
	_music_tension_player.volume_db = _gain_to_db(_tension_gain * music_volume)
	_fill_pad(_calm_playback, _calm_phases, CALM_FREQS)
	_fill_pad(_tension_playback, _tension_phases, TENSION_FREQS)

func _gain_to_db(g: float) -> float:
	return linear_to_db(g) if g > 0.001 else -80.0

func _fill_pad(playback: AudioStreamGeneratorPlayback, phases: Array, freqs: Array) -> void:
	if playback == null: return
	var frames = playback.get_frames_available()
	for i in range(frames):
		var s = 0.0
		for j in range(freqs.size()):
			phases[j] = fmod(phases[j] + TAU * freqs[j] / MUSIC_MIX_RATE, TAU)
			s += sin(phases[j])
		s /= freqs.size()
		var trem = 0.85 + 0.15 * sin(_lfo_phase) # léger trémolo pour éviter un son de synthé figé
		s *= trem * 0.18 # amplitude basse : c'est une ambiance de fond, pas un lead
		playback.push_frame(Vector2(s, s))

func _load_settings() -> void:
	var cfg = ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		master_volume = clampf(cfg.get_value("audio", "master_volume", 0.8), 0.0, 1.0)
		music_volume = clampf(cfg.get_value("audio", "music_volume", 0.5), 0.0, 1.0)

func set_master_volume(v: float) -> void:
	master_volume = clampf(v, 0.0, 1.0)
	_apply_master_volume()
	var cfg = ConfigFile.new()
	cfg.load(SETTINGS_PATH) # ignore l'erreur si le fichier n'existe pas encore
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.save(SETTINGS_PATH)

func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	var cfg = ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.save(SETTINGS_PATH)

func _apply_master_volume() -> void:
	var bus_idx = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(bus_idx, master_volume <= 0.0)
	if master_volume > 0.0:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(master_volume))

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
