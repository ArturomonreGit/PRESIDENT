class_name Sfx
extends RefCounted
## Efectos de sonido sintetizados en código (sin archivos de audio). Uso: Sfx.play("click").
## Sonidos: click, page, notify, confirm, deny, alert, day, gavel, fanfare, reveal, flip.
## El volumen y el silencio se guardan en user://settings.cfg.

const RATE := 22050
const POOL := 6
const CFG := "user://settings.cfg"

static var _cache: Dictionary = {}
static var _players: Array = []
static var _root: Node = null
static var _next := 0
static var _loaded := false
static var muted := false
static var volume := 0.7  # 0..1
static var enabled := true  # las pruebas lo desactivan

static func _load_settings() -> void:
	if _loaded:
		return
	_loaded = true
	var cf := ConfigFile.new()
	if cf.load(CFG) == OK:
		muted = bool(cf.get_value("audio", "muted", false))
		volume = clampf(float(cf.get_value("audio", "volume", 0.7)), 0.0, 1.0)

static func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.load(CFG)
	cf.set_value("audio", "muted", muted)
	cf.set_value("audio", "volume", volume)
	cf.save(CFG)

static func set_muted(v: bool) -> void:
	_load_settings()
	muted = v
	save_settings()
	if not v:
		play("confirm")

static func is_muted() -> bool:
	_load_settings()
	return muted

static func play(sound: String, gain: float = 1.0) -> void:
	_load_settings()
	if not enabled or muted:
		return
	var loop := Engine.get_main_loop()
	if not (loop is SceneTree):
		return
	var tree := loop as SceneTree
	if _root == null or not is_instance_valid(_root):
		_root = Node.new()
		_root.name = "SfxPool"
		tree.root.add_child(_root)
		_players.clear()
		for i in range(POOL):
			var p := AudioStreamPlayer.new()
			_root.add_child(p)
			_players.append(p)
	var stream := _stream(sound)
	if stream == null:
		return
	var pl: AudioStreamPlayer = _players[_next % POOL]
	_next += 1
	pl.stream = stream
	pl.volume_db = linear_to_db(clampf(volume * gain, 0.001, 1.0))
	pl.play()

static func _stream(sound: String) -> AudioStreamWAV:
	if _cache.has(sound):
		return _cache[sound]
	var samples := PackedFloat32Array()
	match sound:
		"click": samples = _tone(1700.0, 0.030, 0.35, 40.0)
		"page": samples = _noise(0.07, 0.22, 38.0, 0.35)
		"day": samples = _mix([_tone(520.0, 0.05, 0.25, 30.0), _tone(780.0, 0.06, 0.18, 26.0)])
		"flip": samples = _seq([[900.0, 0.04, 0.3], [1350.0, 0.07, 0.3]])
		"notify": samples = _mix([_tone(880.0, 0.42, 0.30, 7.0), _delay(_tone(1320.0, 0.40, 0.22, 7.0), 0.07)])
		"confirm": samples = _seq([[660.0, 0.08, 0.34], [880.0, 0.16, 0.34]])
		"deny": samples = _seq([[260.0, 0.10, 0.34, "saw"], [180.0, 0.20, 0.34, "saw"]])
		"alert":
			samples = _seq([[990.0, 0.09, 0.34, "saw"], [0.0, 0.05, 0.0], [990.0, 0.09, 0.34, "saw"], [0.0, 0.05, 0.0], [1320.0, 0.20, 0.34, "saw"]])
		"gavel": samples = _mix([_tone(95.0, 0.28, 0.9, 14.0), _noise(0.09, 0.45, 40.0, 0.5)])
		"reveal": samples = _sweep(280.0, 880.0, 0.45, 0.28)
		"fanfare":
			samples = _seq([[523.0, 0.14, 0.32, "square"], [659.0, 0.14, 0.32, "square"], [784.0, 0.14, 0.32, "square"], [1047.0, 0.45, 0.34, "square"]])
		_: return null
	var st := _to_wav(samples)
	_cache[sound] = st
	return st

static func _to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in range(samples.size()):
		var v := int(clampf(samples[i], -1.0, 1.0) * 32000.0)
		data.encode_s16(i * 2, v)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w

static func _wave(kind: String, phase: float) -> float:
	match kind:
		"saw": return 2.0 * (phase - floorf(phase + 0.5))
		"square": return 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
	return sin(phase * TAU)

static func _tone(freq: float, dur: float, amp: float, decay: float, kind: String = "sine") -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in range(n):
		var t := float(i) / RATE
		var env := exp(-decay * t) * minf(1.0, t * 800.0)
		out[i] = _wave(kind, freq * t) * amp * env
	return out

static func _sweep(f0: float, f1: float, dur: float, amp: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	for i in range(n):
		var k := float(i) / n
		ph += lerpf(f0, f1, k * k) / RATE
		out[i] = sin(ph * TAU) * amp * sin(k * PI)
	return out

static func _noise(dur: float, amp: float, decay: float, smooth: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var prev := 0.0
	for i in range(n):
		var t := float(i) / RATE
		prev = lerpf(rng.randf_range(-1.0, 1.0), prev, smooth)
		out[i] = prev * amp * exp(-decay * t)
	return out

static func _seq(notes: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for nt in notes:
		var a: Array = nt
		var kind := str(a[3]) if a.size() > 3 else "sine"
		if float(a[0]) <= 0.0:
			var sil := PackedFloat32Array()
			sil.resize(int(float(a[1]) * RATE))
			out.append_array(sil)
		else:
			out.append_array(_tone(float(a[0]), float(a[1]), float(a[2]), 9.0, kind))
	return out

static func _delay(s: PackedFloat32Array, secs: float) -> PackedFloat32Array:
	var pad := PackedFloat32Array()
	pad.resize(int(secs * RATE))
	pad.append_array(s)
	return pad

static func _mix(list: Array) -> PackedFloat32Array:
	var n := 0
	for s in list:
		n = maxi(n, (s as PackedFloat32Array).size())
	var out := PackedFloat32Array()
	out.resize(n)
	for s in list:
		var arr := s as PackedFloat32Array
		for i in range(arr.size()):
			out[i] += arr[i]
	return out
