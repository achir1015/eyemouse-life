class_name Tutorial
extends Control
## 語音動態教學：眼動鼠一邊用語音說明，一邊用橘色「示範游標」實際操作真正的畫面
## （看著按鍵 → 填滿 → 選到），被說明的地方會打亮、其他地方變暗。
## 「跳過教學」隨時可以用真實視線或滑鼠選。

var main: Node
var running := false
var step := 0
var focus_rect := Rect2()
var subtitle: Label
var sub_panel: Panel
var mascot_view: SubViewportContainer
var mascot: Mascot
var k_skip: GazeKey
var k_next: GazeKey
var lbl_step: Label
var _abort := false
var _skip_wait := false
var _one := false
const PARK := Vector2(-500, -500)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub_panel = Panel.new()
	sub_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.16, 0.94)
	sb.border_color = Color("#FFB347")
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(22)
	sub_panel.add_theme_stylebox_override("panel", sb)
	add_child(sub_panel)
	subtitle = Label.new()
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 30)
	subtitle.add_theme_color_override("font_color", Color.WHITE)
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(subtitle)
	lbl_step = Label.new()
	lbl_step.add_theme_font_size_override("font_size", 18)
	lbl_step.add_theme_color_override("font_color", Color("#FFB347"))
	lbl_step.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lbl_step)
	var mv := Mascot.make_view(Vector2i(360, 360), 0.95)
	mascot_view = mv[0]
	mascot = mv[1]
	add_child(mascot_view)
	k_skip = GazeKey.make("跳過教學", 0.0, "close", 22)
	k_skip.key_id = "tut_skip"
	k_skip.use_real = true
	k_skip.works_when_paused = true
	k_skip.color_override = Color(0.4, 0.42, 0.5)
	k_skip.fired.connect(stop)
	add_child(k_skip)
	k_next = GazeKey.make("下一步", 0.36, "right", 22)
	k_next.key_id = "tut_next"
	k_next.use_real = true
	k_next.works_when_paused = true
	k_next.fired.connect(func(): _skip_wait = true)
	add_child(k_next)
	resized.connect(_layout)
	Snd.speaking_changed.connect(func(on): if running: mascot.talking = on)


func _layout() -> void:
	var vs := size
	var mw := clampf(vs.y * 0.34, 200, 340)
	var sh := clampf(vs.y * 0.2, 120, 190)
	var y := vs.y - sh - 16
	# 說明的地方在下半部時，字幕改放上面
	if focus_rect.size.x > 0 and focus_rect.get_center().y > vs.y * 0.55:
		y = 16
	mascot_view.position = Vector2(10, y + sh - mw + 10)
	mascot_view.size = Vector2(mw, mw)
	sub_panel.position = Vector2(mw * 0.8, y)
	sub_panel.size = Vector2(vs.x - mw * 0.8 - 230, sh)
	subtitle.position = sub_panel.position + Vector2(28, 26)
	subtitle.size = sub_panel.size - Vector2(56, 40)
	lbl_step.position = sub_panel.position + Vector2(28, 4)
	lbl_step.size = Vector2(300, 24)
	k_next.position = Vector2(vs.x - 210, y)
	k_next.size = Vector2(196, sh / 2 - 5)
	k_skip.position = Vector2(vs.x - 210, y + sh / 2 + 5)
	k_skip.size = Vector2(196, sh / 2 - 5)
	queue_redraw()


func _draw() -> void:
	if not running:
		return
	var dim := Color(0, 0, 0, 0.55)
	var vs := size
	if focus_rect.size.x <= 0:
		draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.35))
		return
	var r := focus_rect.grow(10)
	draw_rect(Rect2(0, 0, vs.x, r.position.y), dim)
	draw_rect(Rect2(0, r.end.y, vs.x, vs.y - r.end.y), dim)
	draw_rect(Rect2(0, r.position.y, r.position.x, r.size.y), dim)
	draw_rect(Rect2(r.end.x, r.position.y, vs.x - r.end.x, r.size.y), dim)
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.set_border_width_all(5)
	sb.border_color = Color("#FFB347")
	sb.set_corner_radius_all(16)
	draw_style_box(sb, r)


func start(from := 0, one := false) -> void:
	if running:
		return
	running = true
	_abort = false
	_one = one
	visible = true
	App.demo = true
	Gaze.bot_point = PARK
	mascot.wave()
	_layout()
	_run(from)


func stop() -> void:
	if not running:
		return
	_abort = true
	_finish()


func _finish() -> void:
	running = false
	visible = false
	App.demo = false
	Gaze.bot_point = null
	focus_rect = Rect2()
	Snd.stop_speaking()
	main.tutorial_finished()


func _run(from: int) -> void:
	for i in range(from, Data.TUTORIAL.size()):
		if _abort:
			return
		step = i
		var t: Array = Data.TUTORIAL[i]
		if App.test_mode:
			print("TUT ", i + 1, " ", t[0], " page=", main.cur_page, " msg=", App.message)
			if OS.get_cmdline_user_args().has("--tut-shots"):
				main.call_deferred("_shot", "user://tut/%02d.png" % (i + 1))
		lbl_step.text = "語音教學 %d / %d" % [i + 1, Data.TUTORIAL.size()]
		subtitle.text = t[1]
		await _prepare(str(t[2]))
		if _abort:
			return
		Snd.say_ui(t[0])
		await _wait_voice(str(t[1]).length() * 0.2)
		if _abort:
			return
		await _act(str(t[2]))
		if _abort:
			return
		await _sleep(0.6)
		if _one:
			return
	if not _abort:
		_finish()


func _sleep(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _wait_voice(fallback: float) -> void:
	_skip_wait = false
	await _sleep(0.3)
	var t := 0.0
	while not _abort and not _skip_wait:
		if not Snd.is_speaking() and t > (0.0 if Snd.has_ui_voice("tut_01") else fallback):
			break
		await get_tree().process_frame
		t += get_process_delta_time()
		if t > 40.0:
			break
	if _skip_wait:
		Snd.stop_speaking()


func _set_focus(r: Rect2) -> void:
	focus_rect = r
	_layout()


## 說明前：切到要介紹的地方、打亮
func _prepare(a: String) -> void:
	if a == "mascot":
		_set_focus(Rect2())
		mascot.wave()
	elif a.begins_with("focus="):
		var w := a.substr(6)
		var r := Rect2()
		match w:
			"rail": r = main.rail.get_global_rect()
			"bar": r = main.msg_panel.get_global_rect()
			"alarm": r = main.k_alarm.get_global_rect()
			"pause": r = main.k_pause.get_global_rect()
		_set_focus(r)
		mascot.point_to(Vector2(signf(r.get_center().x - size.x * 0.2), -0.6), 3.0)
	elif a.begins_with("press="):
		var id := a.substr(6)
		if id.begins_with("quick:"):
			main.show_page("quick")
		var k: GazeKey = main.find_key(id)
		if k:
			_set_focus(k.get_global_rect())
	elif a == "body_demo":
		main.show_page("body")
		_set_focus(main.content.get_global_rect())
	elif a == "type_demo":
		main.show_page("type")
		App.clear_message()
		_set_focus(main.content.get_global_rect())


## 說明後：示範游標實際操作
func _act(a: String) -> void:
	if a.begins_with("press="):
		await _press(a.substr(6))
		await _sleep(0.5)
		if a.begins_with("press=rail:"):
			_set_focus(main.content.get_global_rect())
		await _wait_voice(0.0)
	elif a == "body_demo":
		var bp: BodyPage = main.page("body")
		var target := bp.cam.unproject_position(bp.body.world_pos(Vector3(0.2, 1.405, 0.1)))
		var vr := bp.view.get_global_rect()
		await _move_to(vr.position + target / Vector2(bp.vp.size) * vr.size)
		await _sleep(App.dwell_s() + 0.5)
		await _wait_voice(0.0)
		await _press("feel:pain")
		await _wait_voice(0.0)
	elif a == "type_demo":
		for s in ["ㄒ", "ㄧ", "ㄝ", "ㄒ", "ㄧ", "ㄝ"]:
			await _press("key:" + s)
			if _abort:
				return
		await _press("cand:0")
		await _sleep(0.4)
		await _press("type:speak")
		await _wait_voice(0.0)


func _move_to(p: Vector2) -> void:
	var from: Vector2 = Gaze.bot_point if Gaze.bot_point != PARK else size / 2
	var t := 0.0
	while t < 1.0 and not _abort:
		t = minf(1.0, t + get_process_delta_time() / 0.7)
		Gaze.bot_point = from.lerp(p, ease(t, -2.0))
		await get_tree().process_frame


func _press(id: String) -> void:
	var k: GazeKey = main.find_key(id)
	if not k or _abort:
		return
	await _move_to(k.center_global())
	var fired := [false]
	var cb := func(): fired[0] = true
	k.fired.connect(cb)
	var t := 0.0
	while not fired[0] and t < App.dwell_s() * 3 + 1.0 and not _abort:
		await get_tree().process_frame
		t += get_process_delta_time()
	if is_instance_valid(k) and k.fired.is_connected(cb):
		k.fired.disconnect(cb)
	await _sleep(0.35)
