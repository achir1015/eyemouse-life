class_name ToolsPage
extends Control
## 電腦工具與設定：音量、回到桌面、休息、眼控速度、聲音、主題、警報、教學、更新、關閉。
## 設定類按鍵看一次就切換到下一個選項，小字顯示目前的值。

var main: Node
var keys := {}

const ITEMS := [
	["vol_up", "音量加大", "vol_up"], ["vol_down", "音量減小", "vol_down"], ["mute", "靜音切換", "mute"],
	["desktop", "回到桌面", "desktop"], ["rest", "休息黑畫面", "moon"],
	["speed", "眼控速度", "eye"], ["voice", "預錄聲音", "voice"], ["speak_on_select", "選了就念", "speaker"],
	["accumulate", "句子累加", "chat"], ["theme", "畫面配色", "sun"],
	["alarm_sound", "警報聲音", "bell"], ["power_alarm", "斷電警報", "power"], ["show_cursor", "視線游標", "calib"],
	["fullscreen", "全螢幕", "desktop"], ["app_volume", "程式音量", "speaker"],
	["tutorial", "語音教學", "book"], ["eyemouse", "眼動鼠校正", "calib"], ["update", "檢查更新", "refresh"],
	["about", "關於", "info"], ["quit", "關閉程式", "close"],
]


func setup(m: Node) -> void:
	main = m
	name = "page_tools"


const WEB_HIDE := ["vol_up", "vol_down", "mute", "desktop", "power_alarm", "fullscreen", "eyemouse", "quit"]


func items() -> Array:
	if OS.has_feature("web") or OS.has_feature("mobile"):
		return ITEMS.filter(func(it): return not WEB_HIDE.has(it[0]))
	return ITEMS


func _ready() -> void:
	for it in items():
		var k := GazeKey.make(it[1], 0.72, it[2], 26)
		k.key_id = "tool:" + it[0]
		var id: String = it[0]
		k.fired.connect(func(): _do(id))
		add_child(k)
		keys[id] = k
	var hues := {"vol_up": 0.56, "vol_down": 0.56, "mute": 0.56, "desktop": 0.46, "rest": 0.46,
		"tutorial": 0.30, "eyemouse": 0.30, "update": 0.30, "about": 0.30, "quit": 0.0}
	for id in hues:
		if keys.has(id):
			keys[id].hue = hues[id]
	for id in ["vol_up", "vol_down"]:
		if keys.has(id):
			keys[id].repeatable = true
	App.settings_changed.connect(_refresh)
	resized.connect(_layout)
	_layout()
	_refresh()


func _layout() -> void:
	if size.x < 10:
		return
	var cols := 5
	var rows := ceili(float(items().size()) / cols)
	var gap := 10.0
	var w := (size.x - gap * (cols - 1)) / cols
	var h := (size.y - gap * (rows - 1)) / rows
	var i := 0
	for it in items():
		var k: GazeKey = keys[it[0]]
		k.position = Vector2((i % cols) * (w + gap), (i / cols) * (h + gap))
		k.size = Vector2(w, h)
		i += 1


static func onoff(v) -> String:
	return "開" if bool(v) else "關"


func _opt_name(list: Array, v) -> String:
	for o in list:
		if o[0] == v:
			return o[1]
	return str(v)


func _refresh() -> void:
	var s := App.settings
	if OS.has_feature("web") or OS.has_feature("mobile"):
		keys["update"].sub = "目前 " + App.APP_VERSION
		keys["speed"].sub = "%s（%.1f 秒）" % [App.SPEEDS[int(s.speed)][0], App.dwell_s()]
		keys["voice"].sub = "男聲" if str(s.voice) == "m" else "女聲"
		keys["speak_on_select"].sub = onoff(s.speak_on_select)
		keys["accumulate"].sub = onoff(s.accumulate)
		keys["theme"].sub = _opt_name(App.THEMES, s.theme)
		keys["alarm_sound"].sub = _opt_name(App.ALARMS, s.alarm_sound)
		keys["show_cursor"].sub = onoff(s.show_cursor)
		keys["app_volume"].sub = "%d%%" % int(round(float(s.volume) * 100))
		return
	keys["speed"].sub = "%s（%.1f 秒）" % [App.SPEEDS[int(s.speed)][0], App.dwell_s()]
	keys["voice"].sub = "男聲" if str(s.voice) == "m" else "女聲"
	keys["speak_on_select"].sub = onoff(s.speak_on_select)
	keys["accumulate"].sub = onoff(s.accumulate)
	keys["theme"].sub = _opt_name(App.THEMES, s.theme)
	keys["alarm_sound"].sub = _opt_name(App.ALARMS, s.alarm_sound)
	keys["power_alarm"].sub = onoff(s.power_alarm) + ("" if Sys.has_battery else "（無電池）")
	keys["show_cursor"].sub = onoff(s.show_cursor)
	keys["fullscreen"].sub = onoff(s.fullscreen)
	keys["app_volume"].sub = "%d%%" % int(round(float(s.volume) * 100))
	keys["update"].sub = "目前 " + App.APP_VERSION
	keys["eyemouse"].sub = "已連線" if Gaze.linked else "未連線"
	keys["eyemouse"].enabled = Gaze.eyemouse_exe() != ""


func _cycle(k: String, list: Array) -> void:
	var cur = App.settings[k]
	var i := 0
	for j in list.size():
		if list[j][0] == cur:
			i = j
	App.set_setting(k, list[(i + 1) % list.size()][0])


func _do(id: String) -> void:
	var s := App.settings
	match id:
		"vol_up": Sys.volume_up(2)
		"vol_down": Sys.volume_down(2)
		"mute": Sys.volume_mute()
		"desktop": main.go_desktop()
		"rest": main.show_rest()
		"speed":
			App.set_setting("speed", (int(s.speed) + 1) % App.SPEEDS.size())
		"voice":
			App.set_setting("voice", "f" if str(s.voice) == "m" else "m")
			Snd.speak("你好，我是現在的聲音")
		"speak_on_select", "accumulate", "power_alarm", "show_cursor":
			App.set_setting(id, not bool(s[id]))
		"fullscreen":
			App.set_setting("fullscreen", not bool(s.fullscreen))
			Sys.apply_window_mode()
		"theme":
			_cycle("theme", App.THEMES)
			main.apply_theme()
		"alarm_sound":
			_cycle("alarm_sound", App.ALARMS)
			Snd.play("alarm_" + str(App.settings.alarm_sound), 0.6)
		"app_volume":
			var v := float(s.volume) + 0.25
			App.set_setting("volume", 0.25 if v > 1.01 else v)
			Snd.play("chime")
		"tutorial": main.start_tutorial()
		"eyemouse": main.eyemouse_calibrate()
		"update": main.check_update(true)
		"about": main.show_about()
		"quit": main.confirm_quit()
	_refresh()
