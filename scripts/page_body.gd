class_name BodyPage
extends Control
## 身體感覺：中間是 3D 人體，看著不舒服的部位（停留選取）→ 左邊選感覺 → 說「我的左肩膀有點痛」。
## 右邊是要照顧者做的動作（抓一抓、揉一揉…）與轉身。

var main: Node
var view: SubViewportContainer
var vp: SubViewport
var cam: Camera3D
var body: Body3D
var feel_keys: Array = []
var act_keys: Array = []
var k_turn: GazeKey
var k_front: GazeKey
var k_back: GazeKey
var k_whole: GazeKey
var lbl_part: Label
var lbl_l: Label
var lbl_r: Label
var hover := ""
var hover_t := 0.0
var part := ""


func setup(m: Node) -> void:
	main = m
	name = "page_body"


func _ready() -> void:
	var h := float(Data.cat("body").hue)
	view = SubViewportContainer.new()
	view.stretch = true
	view.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(view)
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	view.add_child(vp)
	body = Body3D.new()
	vp.add_child(body)
	cam = Camera3D.new()
	cam.fov = 30
	cam.position = Vector3(0, 0.88, 3.75)
	vp.add_child(cam)
	cam.look_at(Vector3(0, 0.86, 0))
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-30, 30, 0)
	sun.light_energy = 1.0
	vp.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 210, 0)
	fill.light_energy = 0.55
	vp.add_child(fill)
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(1, 0.97, 0.94)
	e.ambient_light_energy = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	we.environment = e
	vp.add_child(we)
	for f in Data.FEELINGS:
		var k := GazeKey.make(f[1], h, "", 40)
		k.key_id = "feel:" + f[0]
		var fid: String = f[0]
		k.fired.connect(func(): _feel(fid))
		add_child(k)
		feel_keys.append(k)
	for a in Data.BODY_ACTIONS:
		var k := GazeKey.make(a, 0.08, "", 26)
		k.key_id = "act:" + a
		var txt: String = a
		k.fired.connect(func(): App.say_phrase(txt))
		add_child(k)
		act_keys.append(k)
	k_turn = GazeKey.make("轉到背面", 0.62, "rotate", 24)
	k_turn.key_id = "turn"
	k_turn.fired.connect(_turn)
	add_child(k_turn)
	# 人體正上方：正面／背面切換（目前那一面會亮起來）
	k_front = GazeKey.make("正面", 0.56, "front", 28)
	k_front.key_id = "side:front"
	k_front.fired.connect(func(): _set_side(false))
	add_child(k_front)
	k_back = GazeKey.make("背面", 0.56, "back", 28)
	k_back.key_id = "side:back"
	k_back.fired.connect(func(): _set_side(true))
	add_child(k_back)
	k_whole = GazeKey.make("全身", h, "body", 24)
	k_whole.key_id = "whole"
	k_whole.fired.connect(func(): _select("whole"))
	add_child(k_whole)
	lbl_part = _label(30)
	lbl_l = _label(30)
	lbl_r = _label(30)
	resized.connect(_layout)
	_layout()


func _label(fs: int) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", fs)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _layout() -> void:
	if size.x < 10:
		return
	var gap := 10.0
	var lw := clampf(size.x * 0.25, 200, 300)
	var rw := clampf(size.x * 0.3, 240, 360)
	var cw := size.x - lw - rw - gap * 2
	# 左：8 種感覺（2 欄 × 4 列）
	var fw := (lw - gap) / 2
	var fh := (size.y - gap * 3) / 4
	for i in feel_keys.size():
		var k: GazeKey = feel_keys[i]
		k.position = Vector2((i % 2) * (fw + gap), (i / 2) * (fh + gap))
		k.size = Vector2(fw, fh)
	# 中：正面／背面切換鍵＋3D 人體
	var th := clampf(size.y * 0.13, 64, 96)
	var tw := (cw - gap) / 2
	k_front.position = Vector2(lw + gap, 0)
	k_front.size = Vector2(tw, th)
	k_back.position = Vector2(lw + gap * 2 + tw, 0)
	k_back.size = Vector2(tw, th)
	lbl_part.position = Vector2(lw + gap, th + 4)
	lbl_part.size = Vector2(cw, 44)
	view.position = Vector2(lw + gap, th + 48)
	view.size = Vector2(cw, size.y - th - 48)
	lbl_l.position = Vector2(lw + gap + cw - 50, size.y * 0.42)
	lbl_l.size = Vector2(46, 46)
	lbl_r.position = Vector2(lw + gap + 4, size.y * 0.42)
	lbl_r.size = Vector2(46, 46)
	# 右：動作（2 欄 × 4 列）＋轉身、全身
	var x := lw + cw + gap * 2
	var aw := (rw - gap) / 2
	var ah := (size.y - gap * 4) / 5
	for i in act_keys.size():
		var k: GazeKey = act_keys[i]
		k.position = Vector2(x + (i % 2) * (aw + gap), (i / 2) * (ah + gap))
		k.size = Vector2(aw, ah)
	k_turn.position = Vector2(x, (ah + gap) * 4)
	k_turn.size = Vector2(aw, ah)
	k_whole.position = Vector2(x + aw + gap, (ah + gap) * 4)
	k_whole.size = Vector2(aw, ah)
	_refresh_labels()


func _refresh_labels() -> void:
	for l in [lbl_part, lbl_l, lbl_r]:
		l.add_theme_color_override("font_color", Pal.text())
	# 正面時病人的左邊在畫面右邊
	k_front.selected = not body.facing_back
	k_back.selected = body.facing_back
	# 目前顯示的那一面用綠色，另一面用藍色
	k_front.color_override = Pal.ok() if not body.facing_back else Color(0, 0, 0, 0)
	k_back.color_override = Pal.ok() if body.facing_back else Color(0, 0, 0, 0)
	k_front.sub = "目前" if not body.facing_back else ""
	k_back.sub = "目前" if body.facing_back else ""
	lbl_l.text = "右" if body.facing_back else "左"
	lbl_r.text = "左" if body.facing_back else "右"
	if part != "":
		lbl_part.text = "已選：" + str(Data.PARTS.get(part, ""))
		lbl_part.add_theme_color_override("font_color", Color("#FF9F1C"))
	elif hover != "":
		lbl_part.text = str(Data.PARTS.get(hover, ""))
	else:
		lbl_part.text = "看著不舒服的地方"
		lbl_part.add_theme_color_override("font_color", Pal.text_dim())


func _turn() -> void:
	_set_side(not body.facing_back)


func _set_side(back: bool) -> void:
	if back == body.facing_back:
		return
	Snd.play("page")
	body.set_back(back)
	k_turn.text = "轉到正面" if body.facing_back else "轉到背面"
	_refresh_labels()


func _select(id: String) -> void:
	part = id
	body.selected_id = id
	Snd.play("select")
	_refresh_labels()
	var name_txt: String = Data.PARTS.get(id, "")
	if name_txt != "":
		Snd.speak(name_txt)


func select_for_demo(id: String) -> void:
	_select(id)


func _feel(fid: String) -> void:
	if part == "":
		Snd.say_ui("select_part")
		return
	App.say_phrase(Data.body_sentence(part, fid))


## 3D 部位的視線停留
func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	var id := ""
	if Gaze.valid and not App.paused and (GazeKey.modal == null or not GazeKey.modal.is_visible_in_tree()):
		var r := view.get_global_rect()
		if r.has_point(Gaze.point):
			var local := (Gaze.point - r.position) / r.size * Vector2(vp.size)
			id = body.pick(cam, local)
	if id != hover:
		hover = id
		hover_t = 0.0
		body.hover_id = id
		_refresh_labels()
	if id != "" and id != part:
		hover_t += delta / maxf(0.25, App.dwell_s())
		GazeKey.cursor_progress = hover_t
		GazeKey.cursor_frame = Engine.get_process_frames()
		if hover_t >= 1.0:
			hover_t = 0.0
			_select(id)
	elif id == "":
		hover_t = 0.0


func _gui_input(e: InputEvent) -> void:
	# 照顧者用滑鼠直接點部位
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var r := view.get_global_rect()
		var gp: Vector2 = get_global_transform() * (e as InputEventMouseButton).position
		if r.has_point(gp):
			var local: Vector2 = (gp - r.position) / r.size * Vector2(vp.size)
			var id := body.pick(cam, local)
			if id != "":
				_select(id)
			else:
				_turn()          # 點人體旁邊的空白處：翻到另一面
