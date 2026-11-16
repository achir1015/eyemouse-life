extends Node3D
## 主畫面：上方說話列（求助、說話內容、朗讀、刪字、清除、眼動鼠、暫停）、左邊十種分類、右邊內容頁。
## 背景是慢慢飄動的 3D 光球；所有按鍵都是立體鍵帽，看著停留就會選取。

var ui: Control
var bar: Panel
var rail: Panel
var content: Control
var msg_panel: Panel
var msg_label: Label
var status_label: Label
var mascot_view: SubViewportContainer
var mascot: Mascot
var k_alarm: GazeKey
var k_speak: GazeKey
var k_del: GazeKey
var k_clear: GazeKey
var k_pause: GazeKey
var rail_keys := {}
var pages := {}
var cur_page := ""
var cursor: GazeCursor
var toast: Label
var _toast_t := 0.0

var overlay_alarm: Control
var overlay_pause: Control
var overlay_rest: Control
var dialog: Control
var editor: Control
var tutorial: Tutorial

var world_env: WorldEnvironment
var orbs: Array = []
var _t := 0.0
var _args := {}
var _update_manual := false


func _ready() -> void:
	_parse_args()
	_build_world()
	_build_ui()
	apply_theme()
	Sys.apply_window_mode()
	App.message_changed.connect(_on_message)
	App.paused_changed.connect(_on_paused)
	Snd.speaking_changed.connect(func(on): mascot.talking = on)
	Sys.power_changed.connect(_on_power)
	Gaze.link_changed.connect(func(_l): _update_status())
	Updater.checked.connect(_on_update_checked)
	Updater.failed.connect(func(m): if _update_manual: show_toast(m))
	Updater.progress.connect(func(_r, t): show_toast(t, 30.0))
	get_tree().root.size_changed.connect(_layout)
	Bpmf.load_async()
	show_page("quick")
	_layout()
	_on_message()
	if _args.has("selftest"):
		await _selftest()
		return
	await get_tree().process_frame
	if OS.has_feature("web") and not App.test_mode:
		await _web_start()
	if _args.has("screen"):
		await _test_screen(str(_args.screen))
	elif not bool(App.settings.tutorial_done) and not App.test_mode:
		start_tutorial()
	else:
		Snd.say_ui("welcome")
	if not App.test_mode:
		get_tree().create_timer(6.0).timeout.connect(func(): check_update(false))


func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			_args[kv[0]] = kv[1] if kv.size() > 1 else true


# ---------------------------------------------------------------- 3D 背景
func _build_world() -> void:
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0, 6)
	cam.fov = 55
	add_child(cam)
	world_env = WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sky.sky_material = sm
	e.sky = sky
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color.WHITE
	e.ambient_light_energy = 0.5
	world_env.environment = e
	add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	add_child(sun)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 26:
		var mi := MeshInstance3D.new()
		var s := SphereMesh.new()
		var r := rng.randf_range(0.15, 0.7)
		s.radius = r
		s.height = r * 2
		mi.mesh = s
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mi.material_override = m
		mi.position = Vector3(rng.randf_range(-9, 9), rng.randf_range(-5, 5), rng.randf_range(-8, 1))
		mi.set_meta("speed", Vector3(rng.randf_range(-0.08, 0.08), rng.randf_range(0.03, 0.12), 0))
		mi.set_meta("hue", rng.randf())
		mi.set_meta("phase", rng.randf() * TAU)
		add_child(mi)
		orbs.append(mi)


func _process(delta: float) -> void:
	_t += delta
	for o in orbs:
		var mi := o as MeshInstance3D
		mi.position += (mi.get_meta("speed") as Vector3) * delta
		mi.position.x += sin(_t * 0.3 + float(mi.get_meta("phase"))) * delta * 0.05
		if mi.position.y > 6:
			mi.position.y = -6
	if mascot and Gaze.valid:
		var vs := get_viewport().get_visible_rect().size
		var mc := mascot_view.get_global_rect().get_center()
		mascot.look = ((Gaze.point - mc) / (vs * 0.5)).clamp(Vector2(-1, -1), Vector2(1, 1))
	if _toast_t > 0.0:
		_toast_t -= delta
		toast.modulate.a = clampf(_toast_t * 2.0, 0.0, 1.0)
		toast.visible = _toast_t > 0.0
	if overlay_alarm.visible:
		var a := 0.55 + sin(_t * 6.0) * 0.25
		(overlay_alarm.get_child(0) as ColorRect).color = Color(0.75, 0.05, 0.05, a)
	if int(_t * 2) % 20 == 0:
		_update_status()


# ---------------------------------------------------------------- 介面
func _panel() -> Panel:
	var p := Panel.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(p)
	return p


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	bar = _panel()
	rail = _panel()
	msg_panel = _panel()
	msg_label = Label.new()
	msg_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	msg_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	msg_label.clip_text = true
	msg_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(msg_label)
	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.add_theme_font_size_override("font_size", 15)
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(status_label)
	k_alarm = GazeKey.make("求助", 0.0, "bell", 34)
	k_alarm.key_id = "alarm"
	k_alarm.color_override = Pal.alarm()
	k_alarm.fired.connect(start_alarm)
	k_speak = GazeKey.make("朗讀", 0.36, "speaker", 24)
	k_speak.key_id = "speak"
	k_speak.fired.connect(App.speak_message)
	k_del = GazeKey.make("刪字", 0.04, "backspace", 24)
	k_del.key_id = "del"
	k_del.repeatable = true
	k_del.fired.connect(App.backspace)
	k_clear = GazeKey.make("清除", 0.0, "trash", 24)
	k_clear.key_id = "clear"
	k_clear.fired.connect(App.clear_message)
	k_pause = GazeKey.make("暫停", 0.6, "pause", 24)
	k_pause.key_id = "pause"
	k_pause.dwell_mult = 1.3
	k_pause.fired.connect(func(): App.set_paused(true))
	for k in [k_alarm, k_speak, k_del, k_clear, k_pause]:
		ui.add_child(k)
	var mv := Mascot.make_view(Vector2i(240, 220))
	mascot_view = mv[0]
	mascot = mv[1]
	ui.add_child(mascot_view)
	for c in Data.CATS:
		var k := GazeKey.make(c.name, c.hue, c.icon, 22)
		k.key_id = "rail:" + c.id
		var id: String = c.id
		k.fired.connect(func(): show_page(id))
		ui.add_child(k)
		rail_keys[c.id] = k
	content = Control.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(content)
	# 疊在上面的畫面
	overlay_alarm = _build_alarm()
	overlay_pause = _build_pause()
	overlay_rest = _build_rest()
	toast = Label.new()
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast.add_theme_font_size_override("font_size", 26)
	toast.add_theme_color_override("font_color", Color.WHITE)
	var tsb := StyleBoxFlat.new()
	tsb.bg_color = Color(0.1, 0.1, 0.15, 0.9)
	tsb.set_corner_radius_all(18)
	tsb.content_margin_left = 24
	tsb.content_margin_right = 24
	toast.add_theme_stylebox_override("normal", tsb)
	toast.visible = false
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(toast)
	tutorial = Tutorial.new()
	tutorial.main = self
	tutorial.visible = false
	ui.add_child(tutorial)
	cursor = GazeCursor.new()
	ui.add_child(cursor)


func _layout() -> void:
	var vs := ui.size
	if vs.x < 10:
		vs = get_viewport().get_visible_rect().size
	var m := 8.0
	var gap := 8.0
	var bar_h := clampf(vs.y * 0.16, 100, 150)
	bar.position = Vector2(0, 0)
	bar.size = Vector2(vs.x, bar_h + m)
	var kh := bar_h - m
	var x := m
	k_alarm.position = Vector2(x, m)
	k_alarm.size = Vector2(clampf(vs.x * 0.12, 130, 200), kh)
	x += k_alarm.size.x + gap
	var right_keys := [k_speak, k_del, k_clear]
	var small_w := clampf(vs.x * 0.075, 88, 130)
	var mascot_w := kh * 1.05
	var msg_w := vs.x - x - (small_w + gap) * 4 - mascot_w - gap - m
	msg_panel.position = Vector2(x, m)
	msg_panel.size = Vector2(msg_w, kh)
	msg_label.position = Vector2(x + 16, m + 18)
	msg_label.size = Vector2(msg_w - 32, kh - 24)
	status_label.position = Vector2(x + 10, m + 2)
	status_label.size = Vector2(msg_w - 24, 20)
	x += msg_w + gap
	for k in right_keys:
		k.position = Vector2(x, m)
		k.size = Vector2(small_w, kh)
		x += small_w + gap
	mascot_view.position = Vector2(x, m - 4)
	mascot_view.size = Vector2(mascot_w, kh + 8)
	x += mascot_w + gap
	k_pause.position = Vector2(x, m)
	k_pause.size = Vector2(vs.x - x - m, kh)
	# 左邊分類
	var top := bar_h + m + gap
	var rail_w := clampf(vs.x * 0.15, 170, 260)
	rail.position = Vector2(0, top - 4)
	rail.size = Vector2(rail_w + m * 2, vs.y - top + 4)
	var n := Data.CATS.size()
	var rh := (vs.y - top - m - gap * (n - 1)) / n
	var i := 0
	for c in Data.CATS:
		var k: GazeKey = rail_keys[c.id]
		k.position = Vector2(m, top + i * (rh + gap))
		k.size = Vector2(rail_w, rh)
		i += 1
	content.position = Vector2(rail_w + m * 2 + gap, top)
	content.size = Vector2(vs.x - content.position.x - m, vs.y - top - m)
	for p in pages.values():
		(p as Control).size = content.size
	_fit_message()
	toast.position = Vector2(vs.x * 0.2, vs.y - 110)
	toast.size = Vector2(vs.x * 0.6, 64)
	for ov in [overlay_alarm, overlay_pause, overlay_rest]:
		_layout_overlay(ov, vs)
	if dialog and is_instance_valid(dialog):
		_layout_dialog(vs)
	tutorial.size = vs


func apply_theme() -> void:
	for p in [bar, rail]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Pal.panel()
		sb.border_color = Pal.panel_border()
		sb.border_width_bottom = 2 if p == bar else 0
		sb.border_width_right = 2 if p == rail else 0
		(p as Panel).add_theme_stylebox_override("panel", sb)
	var msb := StyleBoxFlat.new()
	msb.bg_color = Color(0, 0, 0, 0.35) if Pal.theme() != "warm" else Color(1, 1, 1, 0.95)
	msb.border_color = Pal.panel_border()
	msb.set_border_width_all(3)
	msb.set_corner_radius_all(18)
	msg_panel.add_theme_stylebox_override("panel", msb)
	msg_label.add_theme_color_override("font_color", Pal.text())
	status_label.add_theme_color_override("font_color", Pal.text_dim())
	var sm := world_env.environment.sky.sky_material as ProceduralSkyMaterial
	sm.sky_top_color = Pal.bg_top()
	sm.sky_horizon_color = Pal.bg_top().lerp(Pal.bg_bottom(), 0.5)
	sm.ground_horizon_color = sm.sky_horizon_color
	sm.ground_bottom_color = Pal.bg_bottom()
	sm.sun_angle_max = 0.0
	for o in orbs:
		var mi := o as MeshInstance3D
		var m := mi.material_override as StandardMaterial3D
		var h := float(mi.get_meta("hue"))
		match Pal.theme():
			"warm": m.albedo_color = Pal.hsv(0.08 + h * 0.12, 0.35, 1.0, 0.35)
			"contrast": m.albedo_color = Color(0, 0, 0, 0)
			_: m.albedo_color = Pal.hsv(0.55 + h * 0.2, 0.6, 1.0, 0.18)
	get_tree().call_group("gaze_key", "queue_redraw")
	for p in pages.values():
		if p.has_method("rebuild"):
			p.rebuild()
		if p.has_method("_refresh_labels"):
			p._refresh_labels()
		if p.has_method("_refresh"):
			p._refresh()


func _update_status() -> void:
	var t := Time.get_datetime_dict_from_system()
	var st := Gaze.status_text()
	if Sys.has_battery and not Sys.on_ac:
		st += "　⚠ 使用電池中"
	status_label.text = "%s　%02d:%02d" % [st, t.hour, t.minute]


func _on_message() -> void:
	if App.message == "":
		msg_label.text = "看著下面的句子，就會說出來"
		msg_label.add_theme_color_override("font_color", Pal.text_dim())
	else:
		msg_label.text = App.message
		msg_label.add_theme_color_override("font_color", Pal.text())
	_fit_message()


func _fit_message() -> void:
	var font := msg_label.get_theme_default_font()
	var fs := 40
	var w := maxf(40.0, msg_label.size.x - 8)
	while fs > 16:
		# 中文不一定能用字詞斷行，所以用「單行寬度 ÷ 可用寬度」估算行數
		var one := font.get_string_size(msg_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var lines := ceili(one / w)
		if lines * fs * 1.35 <= msg_label.size.y:
			break
		fs -= 2
	msg_label.add_theme_font_size_override("font_size", fs)


# ---------------------------------------------------------------- 頁面
func show_page(id: String) -> void:
	if cur_page == id:
		return
	cur_page = id
	for k in rail_keys:
		rail_keys[k].selected = k == id
	for p in pages.values():
		p.visible = false
	if not pages.has(id):
		var p: Control
		match id:
			"body":
				p = BodyPage.new()
				p.setup(self)
			"type":
				p = TypePage.new()
				p.setup(self)
			"tools":
				p = ToolsPage.new()
				p.setup(self)
			_:
				p = PhrasePage.new()
				p.setup(self, id)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.size = content.size
		content.add_child(p)
		pages[id] = p
	pages[id].visible = true
	Snd.play("page")


func page(id: String) -> Control:
	return pages.get(id)


func find_key(id: String) -> GazeKey:
	for k in get_tree().get_nodes_in_group("gaze_key"):
		if (k as GazeKey).key_id == id and (k as GazeKey).is_visible_in_tree():
			return k
	return null


func show_toast(t: String, dur := 3.0) -> void:
	toast.text = t
	toast.visible = true
	_toast_t = dur


# ---------------------------------------------------------------- 疊加畫面
func _overlay(col: Color) -> Control:
	var ov := Control.new()
	ov.mouse_filter = Control.MOUSE_FILTER_STOP
	ov.visible = false
	var cr := ColorRect.new()
	cr.color = col
	cr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov.add_child(cr)
	var lbl := Label.new()
	lbl.name = "Title"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 56)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	lbl.add_theme_constant_override("outline_size", 10)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov.add_child(lbl)
	ui.add_child(ov)
	return ov


func _layout_overlay(ov: Control, vs: Vector2) -> void:
	ov.position = Vector2.ZERO
	ov.size = vs
	var lbl := ov.get_node("Title") as Label
	lbl.position = Vector2(vs.x * 0.05, vs.y * 0.24)
	lbl.size = Vector2(vs.x * 0.9, 90)
	var f := lbl.get_theme_default_font()
	var fs := 60
	while fs > 24 and f.get_string_size(lbl.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > lbl.size.x:
		fs -= 4
	lbl.add_theme_font_size_override("font_size", fs)
	for c in ov.get_children():
		if c is GazeKey:
			var k := c as GazeKey
			var s := Vector2(clampf(vs.x * 0.34, 300, 560), clampf(vs.y * 0.3, 180, 300))
			if ov == overlay_rest:
				s = Vector2(220, 220)
			k.position = Vector2((vs.x - s.x) / 2, vs.y * 0.5)
			k.size = s


func _build_alarm() -> Control:
	var ov := _overlay(Color(0.75, 0.05, 0.05, 0.6))
	(ov.get_node("Title") as Label).text = "求助中！請過來幫忙"
	var k := GazeKey.make("停止警報", 0.36, "check", 44)
	k.key_id = "stop_alarm"
	k.works_when_paused = true
	k.color_override = Pal.ok()
	k.fired.connect(stop_alarm)
	ov.add_child(k)
	return ov


func _build_pause() -> Control:
	var ov := _overlay(Color(0.02, 0.04, 0.1, 0.82))
	(ov.get_node("Title") as Label).text = "眼控暫停中\n看著「繼續」三秒恢復"
	var k := GazeKey.make("繼續", 0.36, "play", 52)
	k.key_id = "resume"
	k.works_when_paused = true
	k.color_override = Pal.ok()
	k.fired.connect(func():
		App.set_paused(false)
		Snd.say_ui("resumed"))
	ov.add_child(k)
	return ov


func _build_rest() -> Control:
	var ov := _overlay(Color(0, 0, 0, 1))
	(ov.get_node("Title") as Label).text = ""
	var k := GazeKey.make("看這裡回來", 0.6, "eye", 22)
	k.key_id = "rest_back"
	k.works_when_paused = true
	k.color_override = Color(0.12, 0.14, 0.2)
	k.fired.connect(func():
		overlay_rest.visible = false
		App.set_paused(false))
	ov.add_child(k)
	return ov


## 網頁版：瀏覽器規定要先點一下才能播放聲音
func _web_start() -> void:
	var ov := _overlay(Color(0.05, 0.08, 0.16, 0.97))
	(ov.get_node("Title") as Label).text = Data.APP_NAME
	var k := GazeKey.make("點一下開始", 0.36, "play", 44)
	k.sub = "瀏覽器要先點一下才能播放聲音"
	k.key_id = "web_start"
	k.works_when_paused = true
	k.use_real = true
	k.color_override = Pal.ok()
	ov.add_child(k)
	ov.visible = true
	ui.move_child(ov, cursor.get_index())
	_layout_overlay(ov, ui.size)
	GazeKey.modal = ov
	await k.fired
	GazeKey.modal = null
	ov.queue_free()


func _on_paused(p: bool) -> void:
	for k in [overlay_pause.get_child(2), overlay_rest.get_child(2)]:
		(k as GazeKey).dwell_mult = 3.0 / App.dwell_s()
	if p and not overlay_rest.visible:
		overlay_pause.visible = true
		Snd.say_ui("paused")
	if not p:
		overlay_pause.visible = false
		overlay_rest.visible = false


func show_rest() -> void:
	overlay_rest.visible = true
	App.set_paused(true)
	overlay_pause.visible = false
	Snd.say_ui("rest")


func start_alarm(kind := "help") -> void:
	if App.demo:
		Snd.play("alarm_beep", 0.4)
		return
	(overlay_alarm.get_node("Title") as Label).text = "電源中斷！\n請檢查電源和呼吸器" if kind == "power" else "求助中！請過來幫忙"
	overlay_alarm.visible = true
	_layout_overlay(overlay_alarm, ui.size)
	GazeKey.modal = overlay_alarm
	Snd.start_alarm(kind)


func stop_alarm() -> void:
	overlay_alarm.visible = false
	if GazeKey.modal == overlay_alarm:
		GazeKey.modal = null
	Snd.stop_alarm()


func _on_power(on_ac: bool) -> void:
	_update_status()
	if not bool(App.settings.power_alarm):
		return
	if not on_ac:
		start_alarm("power")
	elif Snd.alarming == "power":
		stop_alarm()
		Snd.say_ui("power_ok")


# ---------------------------------------------------------------- 對話框
## buttons: [[文字, 色相, Callable], ...]
func show_dialog(title: String, body: String, buttons: Array) -> void:
	close_dialog()
	_toast_t = 0.0
	toast.visible = false
	dialog = Control.new()
	dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.name = "Dim"
	dialog.add_child(dim)
	var box := Panel.new()
	box.name = "Box"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Pal.panel().lerp(Color.BLACK, 0.2) if Pal.theme() != "warm" else Color("#FFFaf2")
	sb.bg_color.a = 0.98
	sb.border_color = Pal.panel_border()
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(24)
	box.add_theme_stylebox_override("panel", sb)
	dialog.add_child(box)
	var lt := Label.new()
	lt.name = "T"
	lt.text = title
	lt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lt.add_theme_font_size_override("font_size", 40)
	lt.add_theme_color_override("font_color", Pal.text())
	box.add_child(lt)
	var lb := Label.new()
	lb.name = "B"
	lb.text = body
	lb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.add_theme_font_size_override("font_size", 24)
	lb.add_theme_color_override("font_color", Pal.text_dim())
	box.add_child(lb)
	for b in buttons:
		var k := GazeKey.make(b[0], b[1], b[3] if b.size() > 3 else "", 32)
		k.key_id = "dlg:" + str(b[0])
		k.works_when_paused = true
		var cb: Callable = b[2]
		k.fired.connect(func():
			close_dialog()
			if cb.is_valid():
				cb.call())
		box.add_child(k)
	ui.add_child(dialog)
	ui.move_child(dialog, cursor.get_index())
	GazeKey.modal = dialog
	_layout_dialog(ui.size)


func _layout_dialog(vs: Vector2) -> void:
	dialog.position = Vector2.ZERO
	dialog.size = vs
	var dim := dialog.get_node("Dim") as ColorRect
	dim.size = vs
	var box := dialog.get_node("Box") as Panel
	var keys := box.get_children().filter(func(c): return c is GazeKey)
	var w := clampf(vs.x * 0.7, 520, 1100)
	var h := clampf(vs.y * 0.62, 360, 560)
	box.position = (vs - Vector2(w, h)) / 2
	box.size = Vector2(w, h)
	var lt := box.get_node("T") as Label
	lt.position = Vector2(20, 24)
	lt.size = Vector2(w - 40, 56)
	var lb := box.get_node("B") as Label
	lb.position = Vector2(40, 90)
	lb.size = Vector2(w - 80, h - 90 - 190)
	var n := maxi(1, keys.size())
	var gap := 16.0
	var kw := (w - 60 - gap * (n - 1)) / n
	for i in keys.size():
		var k := keys[i] as GazeKey
		k.position = Vector2(30 + i * (kw + gap), h - 180)
		k.size = Vector2(kw, 150)


func close_dialog() -> void:
	if dialog and is_instance_valid(dialog):
		if GazeKey.modal == dialog:
			GazeKey.modal = null
		dialog.queue_free()
	dialog = null


func confirm_quit() -> void:
	Snd.say_ui("confirm_quit")
	show_dialog("關閉程式", "關閉後就不能用眼睛操作這個工具了。\n確定要關閉嗎？", [
		["關閉程式", 0.0, quit_app, "close"], ["取消", 0.36, Callable(), "left"]])


func quit_app() -> void:
	Gaze.shutdown()
	get_tree().quit()


func _exit_tree() -> void:
	Bpmf.wait_loaded()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_app()


func go_desktop() -> void:
	Snd.say_ui("desktop")
	await get_tree().create_timer(0.3).timeout
	Sys.to_desktop()


func eyemouse_calibrate() -> void:
	var exe := Gaze.eyemouse_exe()
	if exe == "":
		show_toast("沒有找到眼動鼠")
		return
	if OS.get_name() == "macOS":
		OS.create_process("open", [exe, "--args", "--calibrate"])
	else:
		OS.create_process(exe, ["--calibrate"])
	show_toast("已開啟眼動鼠校正")


func show_about() -> void:
	show_dialog(Data.APP_NAME, "版本 %s（%s）\n給漸凍人與上肢不便的朋友：用眼睛說話、求助、打字、使用電腦。\n系統開發：吳玉柱 先生 與 Claude AI Opus 5.5\n注音詞庫：McBopomofo 小麥注音（MIT 授權）\n%s" % [
		App.APP_VERSION, Updater.platform_name(), Gaze.status_text()], [["關閉", 0.6, Callable(), "check"]])


# ---------------------------------------------------------------- 更新
func check_update(manual: bool) -> void:
	_update_manual = manual
	if manual:
		show_toast("正在檢查更新…")
	Updater.check()


func _on_update_checked(has: bool, latest: String, notes: String) -> void:
	if has:
		show_dialog("有新版本 " + latest, notes + "\n\n要現在更新嗎？更新完會自動重新開啟。", [
			["立即更新", 0.36, Updater.apply_update, "refresh"], ["以後再說", 0.6, Callable(), "left"]])
	elif _update_manual:
		show_toast("目前已經是最新版本 " + App.APP_VERSION)
		Snd.say_ui("update_none")


# ---------------------------------------------------------------- 照顧者編輯（滑鼠＋鍵盤）
func open_editor(cat: String) -> void:
	if editor and is_instance_valid(editor):
		editor.queue_free()
	editor = PhraseEditor.new()
	editor.setup(self, cat)
	ui.add_child(editor)
	ui.move_child(editor, cursor.get_index())
	editor.position = Vector2.ZERO
	editor.size = ui.size
	GazeKey.modal = editor
	editor.tree_exited.connect(func(): if GazeKey.modal == editor: GazeKey.modal = null)


# ---------------------------------------------------------------- 教學
func start_tutorial() -> void:
	tutorial.start()


func tutorial_finished() -> void:
	App.set_setting("tutorial_done", true)
	show_page("quick")
	if App.test_mode and _args.has("quit-after-tutorial"):
		print("TUTORIAL DONE msg=", App.message)
		get_tree().quit()


# ---------------------------------------------------------------- 測試
func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	img.save_png(path)
	print("SHOT ", path)


func _test_screen(s: String) -> void:
	var delay := float(_args.get("delay", 1.2))
	var parts := s.split(":")
	match parts[0]:
		"alarm":
			start_alarm()
		"power":
			start_alarm("power")
		"pause":
			App.set_paused(true)
		"rest":
			show_rest()
		"about":
			show_about()
		"update":
			check_update(true)
			var res = await Updater.checked
			print("UPDATE has=", res[0], " latest=", res[1], " current=", Updater.current_version())
		"quit":
			confirm_quit()
		"editor":
			show_page(parts[1])
			open_editor(parts[1])
		"tutorial":
			tutorial.start(int(parts[1]) if parts.size() > 1 else 0, _args.has("one"))
		"type":
			show_page("type")
			var tp: TypePage = page("type")
			for sym in str(_args.get("keys", "ㄒㄧㄝㄒㄧㄝ")).split(""):
				if sym != "":
					tp.syls = Bpmf.push_symbol(tp.syls, sym)
			tp._update_cands()
			if _args.has("pick"):
				tp._pick(int(_args.pick))
		"body":
			show_page("body")
			if parts.size() > 1:
				var bp: BodyPage = page("body")
				if parts.size() > 2 and parts[2] == "back":
					bp._turn()
				bp.select_for_demo(parts[1])
		_:
			show_page(parts[0])
	if _args.has("msg"):
		App.message = str(_args.msg)
		App.message_changed.emit()
	if _args.has("shot"):
		await get_tree().create_timer(delay).timeout
		if _args.has("debug"):
			for ov in [overlay_alarm, overlay_pause]:
				var l := ov.get_node("Title") as Label
				print("DBG ", ov.get_global_rect(), " ", l.get_global_rect(), " ", l.visible, " ", l.text)
		await _shot(str(_args.shot))
		if not _args.has("stay"):
			get_tree().quit()


func _selftest() -> void:
	var ok := true
	var r := []
	Bpmf.wait_loaded()
	var syl := []
	for s in "ㄒㄧㄝㄒㄧㄝ".split(""):
		syl = Bpmf.push_symbol(syl, s)
	r.append(["自動分字 ㄒㄧㄝㄒㄧㄝ", str(syl), syl.size() == 2])
	var c := Bpmf.candidates(syl)
	r.append(["候選 謝謝", str(c.slice(0, 3)), not c.is_empty() and c[0].w == "謝謝"])
	var c2 := Bpmf.candidates(["ㄨㄛ"])
	r.append(["不打聲調 ㄨㄛ → 我", str(c2.slice(0, 3)), not c2.is_empty() and c2[0].w == "我"])
	var c3 := Bpmf.candidates(Bpmf.push_symbol(["ㄏㄠ"], "ˇ"))
	r.append(["ㄏㄠˇ → 好", str(c3.slice(0, 2)), not c3.is_empty() and c3[0].w == "好"])
	var c4 := Bpmf.candidates(["ㄒ"])
	r.append(["只打聲母 ㄒ 也有候選", str(c4.size()), c4.size() > 10])
	var a := Bpmf.associate("謝")
	r.append(["聯想 謝", str(a.slice(0, 5)), a.has("謝")])
	r.append(["身體句子", Data.body_sentence("shoulder_l", "pain"), Data.body_sentence("shoulder_l", "pain") == "我的左肩膀有點痛"])
	App.settings.voice = "f"
	r.append(["預錄語音 是", Snd.voice_path("是"), Snd.has_recorded("是")])
	r.append(["預錄語音 身體", Snd.voice_path("我的左肩膀有點痛"), Snd.has_recorded("我的左肩膀有點痛")])
	App.settings.voice = "m"
	r.append(["男聲 我要喝水", "", Snd.has_recorded("我要喝水")])
	App.settings.voice = "f"
	var missing := 0
	for t in Data.TUTORIAL:
		if not Snd.has_ui_voice(t[0]):
			missing += 1
	for k in Data.VOICE:
		if not Snd.has_ui_voice(k):
			missing += 1
	r.append(["介面語音齊全", str(missing) + " 缺", missing == 0])
	var vs := DisplayServer.tts_get_voices()
	r.append(["電腦語音", str(Snd._tts_voice), Snd._tts_voice != ""])
	# 停留選取
	show_page("quick")
	await get_tree().process_frame
	await get_tree().process_frame
	var k := find_key("quick:0")
	App.message = ""
	Gaze.bot_point = k.center_global()
	await get_tree().create_timer(App.dwell_s() + 0.6).timeout
	Gaze.bot_point = null
	r.append(["停留選取「是」", App.message, App.message == "是"])
	# 防誤觸：不移開不會再選
	var before := App.history.size()
	Gaze.bot_point = k.center_global()
	await get_tree().create_timer(App.dwell_s() * 1.6).timeout
	Gaze.bot_point = null
	r.append(["沒移開視線不會重複選", "", App.history.size() == before])
	# 暫停時按鍵無效
	App.set_paused(true)
	App.message = ""
	var k2 := find_key("resume")
	Gaze.bot_point = Vector2(5, 5)
	await get_tree().create_timer(0.2).timeout
	r.append(["暫停畫面出現", "", overlay_pause.visible])
	Gaze.bot_point = k2.center_global()
	await get_tree().create_timer(3.4).timeout
	Gaze.bot_point = null
	r.append(["看繼續 3 秒恢復", "", not App.paused])
	# 身體頁 3D 選取
	show_page("body")
	await get_tree().create_timer(0.5).timeout
	var bp: BodyPage = page("body")
	var target := bp.cam.unproject_position(bp.body.world_pos(Vector3(0.2, 1.405, 0.1)))
	var vr := bp.view.get_global_rect()
	Gaze.bot_point = vr.position + target / Vector2(bp.vp.size) * vr.size
	await get_tree().create_timer(App.dwell_s() + 0.7).timeout
	Gaze.bot_point = null
	r.append(["3D 選左肩膀", bp.part, bp.part == "shoulder_l"])
	App.settings.speak_on_select = false
	bp._feel("pain")
	App.settings.speak_on_select = true
	r.append(["說出身體句子", App.message, App.message == "我的左肩膀有點痛"])
	for row in r:
		print("%s %s  %s" % ["PASS" if row[2] else "FAIL", row[0], row[1]])
		ok = ok and row[2]
	print("SELFTEST ", "OK" if ok else "FAILED")
	var out := str(_args.get("out", ""))
	if out != "":
		var f := FileAccess.open(out, FileAccess.WRITE)
		for row in r:
			f.store_line("%s %s  %s" % ["PASS" if row[2] else "FAIL", row[0], row[1]])
		f.store_line("SELFTEST " + ("OK" if ok else "FAILED"))
	get_tree().quit(0 if ok else 1)
