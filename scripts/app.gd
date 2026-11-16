extends Node
## 全域狀態：設定、句子清單（可編輯）、說過的話、說話列內容。

signal settings_changed
signal phrases_changed(cat: String)
signal message_changed
signal paused_changed(paused: bool)

const APP_VERSION := "1.0.6"
const SPEEDS := [["較慢", 1.6], ["慢", 1.25], ["正常", 1.0], ["快", 0.8], ["較快", 0.6]]
const THEMES := [["night", "夜空藍"], ["warm", "暖陽米"], ["contrast", "高對比"]]
const ALARMS := [["siren", "警笛"], ["bell", "鈴聲"], ["beep", "嗶嗶聲"]]

var settings := {
	"speed": 2,
	"voice": "f",               # 預錄語音：f 女聲（曉臻）／m 男聲（雲哲）
	"tts_rate": 1.0,            # 自訂句子用電腦語音的速度
	"volume": 1.0,
	"speak_on_select": true,    # 選到句子就念出來
	"accumulate": false,        # 句子累加在說話列（關閉時說話列只顯示最後一句）
	"theme": "night",
	"show_cursor": true,
	"click_sound": true,
	"auto_eyemouse": true,
	"power_alarm": true,
	"alarm_sound": "siren",
	"alarm_boost": true,        # 警報時把系統音量調大
	"fullscreen": true,
	"tutorial_done": false,
}

var phrases := {}               # 分類 id → Array[String]
var history: Array = []         # 最近說過的話（新的在前）
var message := ""               # 說話列內容
var paused := false
var demo := false               # 教學示範中（不真的發警報、不存紀錄）
var test_mode := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	test_mode = OS.get_cmdline_user_args().has("--test")
	_load()


# ---------------------------------------------------------------- 存取
func _read_json(path: String):
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _write_json(path: String, v) -> void:
	if test_mode and not OS.get_cmdline_user_args().has("--save"):
		return
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(v, " "))


func _load() -> void:
	var s = _read_json("user://settings.json")
	if typeof(s) == TYPE_DICTIONARY:
		for k in s:
			if settings.has(k):
				settings[k] = s[k]
	if test_mode and OS.get_cmdline_user_args().has("--fresh"):
		settings.tutorial_done = false
	for k in Data.PHRASES:
		phrases[k] = Data.PHRASES[k].duplicate()
	var p = _read_json("user://phrases.json")
	if typeof(p) == TYPE_DICTIONARY:
		for k in p:
			if phrases.has(k) and typeof(p[k]) == TYPE_ARRAY:
				phrases[k] = p[k]
	var h = _read_json("user://history.json")
	if typeof(h) == TYPE_ARRAY:
		history = h


func save_settings() -> void:
	_write_json("user://settings.json", settings)
	settings_changed.emit()


func set_setting(k: String, v) -> void:
	settings[k] = v
	save_settings()


func save_phrases(cat := "") -> void:
	_write_json("user://phrases.json", phrases)
	phrases_changed.emit(cat)


func reset_phrases(cat: String) -> void:
	if Data.PHRASES.has(cat):
		phrases[cat] = Data.PHRASES[cat].duplicate()
		save_phrases(cat)


func add_phrase(cat: String, text: String) -> bool:
	text = text.strip_edges()
	if text == "" or not phrases.has(cat):
		return false
	if not phrases[cat].has(text):
		phrases[cat].append(text)
		save_phrases(cat)
	return true


# ---------------------------------------------------------------- 眼控
func dwell_s() -> float:
	return float(SPEEDS[clampi(int(settings.speed), 0, SPEEDS.size() - 1)][1])


func set_paused(v: bool) -> void:
	if paused == v:
		return
	paused = v
	paused_changed.emit(v)


# ---------------------------------------------------------------- 說話列
## 選到一句話：顯示在說話列並（依設定）念出來
func say_phrase(text: String) -> void:
	if bool(settings.accumulate) and message != "":
		var sep := "" if message.ends_with("。") or message.ends_with("，") else "，"
		message += sep + text
	else:
		message = text
	message_changed.emit()
	if bool(settings.speak_on_select):
		Snd.speak(text)
	remember(text)


## 打字：在說話列後面加字
func type_text(t: String) -> void:
	message += t
	message_changed.emit()


func backspace() -> void:
	if message.length() > 0:
		message = message.substr(0, message.length() - 1)
		message_changed.emit()


func clear_message() -> void:
	message = ""
	message_changed.emit()


func speak_message() -> void:
	if message.strip_edges() == "":
		return
	Snd.speak(message)
	remember(message)


func remember(text: String) -> void:
	if demo:
		return
	history.erase(text)
	history.push_front(text)
	if history.size() > 40:
		history.resize(40)
	_write_json("user://history.json", history)
