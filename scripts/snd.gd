extends Node
## 聲音：音效、預錄語音（edge-tts 女聲／男聲）、電腦內建語音（自訂句子）、警報。

signal speaking_changed(on: bool)

const SFX := ["click", "select", "tick", "page", "pop", "open", "back", "alarm_siren", "alarm_bell", "alarm_beep", "chime"]

var voice := AudioStreamPlayer.new()
var alarm_player := AudioStreamPlayer.new()
var pool: Array = []
var streams := {}
var alarming := ""                  # "" / "help" / "power"
var _speaking := false
var _tts_voice := ""
var _alarm_t := 0.0
var _queue: Array = []
var last_spoken := ""               # 測試用：最後念出的文字
var last_engine := ""               # 測試用：voice / tts / none


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(voice)
	add_child(alarm_player)
	voice.finished.connect(_next)
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		pool.append(p)
	for s in SFX:
		var path := "res://assets/sfx/%s.wav" % s
		if ResourceLoader.exists(path):
			streams[s] = load(path)
	_pick_tts_voice()


func _pick_tts_voice() -> void:
	if OS.has_feature("web"):
		return
	var best := ""
	for v in DisplayServer.tts_get_voices():
		var lang := str(v.get("language", ""))
		if lang.begins_with("zh") and (lang.contains("TW") or lang.contains("Hant")):
			best = str(v.id)
			break
		if lang.begins_with("zh") and best == "":
			best = str(v.id)
	_tts_voice = best


func vol() -> float:
	return clampf(float(App.settings.volume), 0.0, 1.0)


func play(name: String, v := 1.0) -> void:
	if not streams.has(name) or vol() <= 0.001:
		return
	if name in ["click", "select", "tick"] and not bool(App.settings.click_sound):
		return
	for p in pool:
		var ap := p as AudioStreamPlayer
		if not ap.playing:
			ap.stream = streams[name]
			ap.volume_db = linear_to_db(maxf(vol() * v, 0.001))
			ap.play()
			return


# ---------------------------------------------------------------- 語音
static func phrase_key(text: String) -> String:
	return "p_" + text.strip_edges().md5_text().substr(0, 12)


func voice_path(text: String) -> String:
	var g := "m" if str(App.settings.voice) == "m" else "f"
	return "res://assets/voice/%s/%s.ogg" % [g, phrase_key(text)]


func has_recorded(text: String) -> bool:
	return ResourceLoader.exists(voice_path(text))


## 念一句話：有預錄語音就播預錄，沒有就用電腦內建語音
func speak(text: String) -> void:
	text = text.strip_edges()
	if text == "":
		return
	stop_speaking()
	last_spoken = text
	var path := voice_path(text)
	if ResourceLoader.exists(path):
		last_engine = "voice"
		_play_stream(load(path))
	else:
		_tts(text)


func _tts(text: String) -> void:
	if OS.has_feature("web") or _tts_voice == "":
		last_engine = "none"
		return
	last_engine = "tts"
	var rate := clampf(float(App.settings.tts_rate), 0.5, 2.0)
	DisplayServer.tts_speak(text.replace("\n", "，"), _tts_voice, int(vol() * 100), 1.0, rate, 0, true)
	_set_speaking(true)


func _play_stream(st: AudioStream) -> void:
	voice.stream = st
	voice.volume_db = linear_to_db(maxf(vol(), 0.001))
	voice.play()
	_set_speaking(true)


## 程式介面的語音（教學、提示）：assets/voice/ui/<id>.ogg
func say_ui(id: String, interrupt := true) -> void:
	var path := "res://assets/voice/ui/%s.ogg" % id
	if not ResourceLoader.exists(path):
		print("MISSING_VOICE ", id)
		return
	if interrupt:
		stop_speaking()
		_play_stream(load(path))
	elif voice.playing:
		_queue.append(path)
	else:
		_play_stream(load(path))


func has_ui_voice(id: String) -> bool:
	return ResourceLoader.exists("res://assets/voice/ui/%s.ogg" % id)


func _next() -> void:
	if _queue.size() > 0:
		_play_stream(load(_queue.pop_front()))
	else:
		_set_speaking(false)


func stop_speaking() -> void:
	_queue.clear()
	voice.stop()
	if not OS.has_feature("web") and DisplayServer.tts_is_speaking():
		DisplayServer.tts_stop()
	_set_speaking(false)


func is_speaking() -> bool:
	return voice.playing or (_speaking and not OS.has_feature("web") and DisplayServer.tts_is_speaking())


func _set_speaking(v: bool) -> void:
	if v != _speaking:
		_speaking = v
		speaking_changed.emit(v)


# ---------------------------------------------------------------- 警報
func start_alarm(kind := "help") -> void:
	if alarming == kind:
		return
	alarming = kind
	if bool(App.settings.alarm_boost) and not App.demo:
		Sys.volume_up(12)
	var name := "alarm_" + str(App.settings.alarm_sound)
	if not streams.has(name):
		name = "alarm_siren"
	alarm_player.stream = streams.get(name)
	alarm_player.volume_db = 0.0
	alarm_player.play()
	_alarm_t = 2.5
	say_ui("power" if kind == "power" else "alarm")


func stop_alarm() -> void:
	alarming = ""
	alarm_player.stop()
	stop_speaking()


func _process(delta: float) -> void:
	if _speaking and not voice.playing and not OS.has_feature("web") and not DisplayServer.tts_is_speaking():
		_set_speaking(false)
	if alarming != "":
		if not alarm_player.playing:
			alarm_player.play()
		_alarm_t += delta
		if _alarm_t > 7.0:
			_alarm_t = 0.0
			say_ui("power" if alarming == "power" else "alarm")
