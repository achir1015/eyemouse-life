class_name GazeKey
extends Control
## 立體鍵帽按鈕：眼睛看著會浮起來並慢慢填滿，滿了就「按下去」。也可以用滑鼠／觸控點。
## 防誤觸：選到一次之後，要先把視線移開才能再選同一顆（repeatable 的按鍵例外，例如刪字）。

signal fired

static var modal: Control = null          # 有對話框時，只有對話框裡的按鍵有效
static var last_fire_ms := 0
static var cursor_progress := 0.0
static var cursor_frame := 0
static var icon_cache := {}

var text := "":
	set(v):
		text = v
		queue_redraw()
var sub := "":                            # 小字說明（例如頁碼、目前設定值）
	set(v):
		sub = v
		queue_redraw()
var icon := "":
	set(v):
		icon = v
		queue_redraw()
var hue := 0.6
var color_override := Color(0, 0, 0, 0)
var dwell_mult := 1.0
var repeatable := false
var works_when_paused := false
var use_real := false                     # 教學中也用真實視線（例如「跳過教學」）
var key_id := ""                          # 教學用來找按鍵
var font_size := 30
var selected := false:
	set(v):
		selected = v
		queue_redraw()
var enabled := true:
	set(v):
		enabled = v
		queue_redraw()
var demo_ok := true                       # 教學示範時可以被示範游標選

var progress := 0.0
var gazed := false
var _armed := true
var _press := 0.0
var _lift := 0.0


static func make(t: String, h := 0.6, ic := "", fs := 30) -> GazeKey:
	var k := GazeKey.new()
	k.text = t
	k.hue = h
	k.icon = ic
	k.font_size = fs
	return k


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	add_to_group("gaze_key")
	resized.connect(queue_redraw)


static func tex(name: String) -> Texture2D:
	if name == "":
		return null
	if not icon_cache.has(name):
		var p := "res://assets/icons/%s.svg" % name
		icon_cache[name] = load(p) if ResourceLoader.exists(p) else null
	return icon_cache[name]


func active() -> bool:
	if not enabled or not is_visible_in_tree():
		return false
	if modal and is_instance_valid(modal) and modal.is_visible_in_tree() and modal != self and not modal.is_ancestor_of(self):
		return false
	if App.paused and not works_when_paused:
		return false
	if Gaze.bot_point != null and not use_real and not demo_ok:
		return false
	return true


func _gaze_point() -> Array:
	if use_real:
		return [Gaze.real_valid, Gaze.real_point]
	return [Gaze.valid, Gaze.point]


func _process(delta: float) -> void:
	var was := gazed
	var gp := _gaze_point()
	gazed = active() and bool(gp[0]) and get_global_rect().has_point(gp[1])
	if not gazed:
		_armed = true
	var dwell := maxf(0.25, App.dwell_s() * dwell_mult)
	if gazed and _armed and Time.get_ticks_msec() - last_fire_ms > 450:
		progress += delta / dwell
		cursor_progress = progress
		cursor_frame = Engine.get_process_frames()
		if progress >= 1.0:
			_fire()
	else:
		progress = maxf(0.0, progress - delta * 2.5)
	_press = maxf(0.0, _press - delta * 4.0)
	_lift = move_toward(_lift, 1.0 if gazed else 0.0, delta * 8.0)
	if gazed != was or progress > 0.0 or _press > 0.0 or (_lift > 0.0 and _lift < 1.0):
		queue_redraw()


func _fire() -> void:
	progress = 0.0
	last_fire_ms = Time.get_ticks_msec()
	_press = 1.0
	if not repeatable:
		_armed = false
	Snd.play("click")
	queue_redraw()
	fired.emit()


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		if active() or (use_real and enabled):
			_fire()
			accept_event()
	elif e is InputEventScreenTouch and e.pressed:
		if active():
			_fire()
			accept_event()


## 教學：示範游標要看的位置
func center_global() -> Vector2:
	return get_global_rect().get_center()


# ---------------------------------------------------------------- 繪圖
func _base_color() -> Color:
	if color_override.a > 0.0:
		return color_override
	return Pal.key_color(hue)


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 4 or h < 4:
		return
	var depth := clampf(h * 0.08, 5.0, 11.0)
	var r := clampf(minf(w, h) * 0.16, 8.0, 22.0)
	var press := _press * depth * 0.75
	var lift := _lift * 2.0
	var c := _base_color()
	var hc := Pal.contrast()
	if not enabled:
		c = Color(0.45, 0.47, 0.52) if not hc else Color(0.12, 0.12, 0.12)
	# 影子＋側面（鍵帽厚度）
	var side := StyleBoxFlat.new()
	side.bg_color = c.darkened(0.42) if not hc else Color(0.25, 0.25, 0.0)
	side.set_corner_radius_all(int(r))
	side.shadow_color = Color(0, 0, 0, 0.35 if not hc else 0.0)
	side.shadow_size = int(4 + _lift * 6)
	side.shadow_offset = Vector2(0, 3 + _lift * 3)
	draw_style_box(side, Rect2(0, depth, w, h - depth))
	# 頂面
	var top_r := Rect2(0, press - lift, w, h - depth)
	var top := StyleBoxFlat.new()
	top.bg_color = c
	top.set_corner_radius_all(int(r))
	if hc:
		top.set_border_width_all(3)
		top.border_color = Color("#FFE600")
	else:
		top.border_width_top = 3
		top.border_color = c.lightened(0.28)
	draw_style_box(top, top_r)
	# 停留進度（由左往右填滿）
	if progress > 0.0:
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color(1, 1, 1, 0.30) if not hc else Color(0, 0.9, 1, 0.45)
		fill.set_corner_radius_all(int(r))
		draw_style_box(fill, Rect2(top_r.position, Vector2(maxf(r * 2, top_r.size.x * clampf(progress, 0, 1)), top_r.size.y)))
	# 選取中／注視中的外框
	if selected or gazed:
		var ring := StyleBoxFlat.new()
		ring.draw_center = false
		ring.set_border_width_all(5 if gazed else 4)
		ring.border_color = Pal.gaze() if gazed else Color(1, 1, 1, 0.95)
		ring.set_corner_radius_all(int(r + 3))
		draw_style_box(ring, top_r.grow(3))
	if selected:
		draw_circle(top_r.position + Vector2(top_r.size.x - 14, 14), 6, Color.WHITE if not hc else Color("#FFE600"))
	_draw_content(top_r)


func _draw_content(rect: Rect2) -> void:
	var font := get_theme_default_font()
	var col := Pal.key_text() if enabled else Color(0.85, 0.85, 0.88)
	var t := tex(icon)
	var pad := 10.0
	var inner := rect.grow(-pad)
	var sub_h := 0.0
	if sub != "":
		sub_h = minf(26.0, inner.size.y * 0.28)
	if t and text == "":
		var s := minf(inner.size.x, inner.size.y - sub_h) * 0.8
		draw_texture_rect(t, Rect2(inner.get_center() - Vector2(s, s + sub_h) / 2, Vector2(s, s)), false, col)
		_draw_sub(font, inner, sub_h, col)
		return
	var text_rect := inner
	if t:
		var vertical := inner.size.y > inner.size.x * 0.75 or (inner.size.y > 110 and text.length() <= 4)
		if vertical:
			var s := minf(inner.size.y * 0.42, inner.size.x * 0.5)
			draw_texture_rect(t, Rect2(Vector2(inner.get_center().x - s / 2, inner.position.y + 2), Vector2(s, s)), false, col)
			text_rect = Rect2(inner.position + Vector2(0, s + 4), inner.size - Vector2(0, s + 4))
		else:
			var s := minf(inner.size.y * 0.72, 56.0)
			draw_texture_rect(t, Rect2(inner.position + Vector2(4, (inner.size.y - sub_h - s) / 2), Vector2(s, s)), false, col)
			text_rect = Rect2(inner.position + Vector2(s + 12, 0), inner.size - Vector2(s + 12, 0))
	text_rect.size.y -= sub_h
	if text != "":
		var fs := font_size
		var sz := Vector2.ZERO
		# 先試單行（字可以縮到 70%），放不下才換行
		var one := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		if one.x > text_rect.size.x and one.x * 0.7 <= text_rect.size.x:
			fs = int(fs * text_rect.size.x / one.x)
		while fs > 12:
			sz = font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, text_rect.size.x, fs, 3)
			if sz.x <= text_rect.size.x + 1 and sz.y <= text_rect.size.y + 1:
				break
			fs -= 2
		var asc := font.get_ascent(fs)
		var y := text_rect.position.y + (text_rect.size.y - sz.y) / 2 + asc
		var outline := 0 if Pal.contrast() else 5
		if outline > 0:
			draw_multiline_string_outline(font, Vector2(text_rect.position.x, y), text, HORIZONTAL_ALIGNMENT_CENTER, text_rect.size.x, fs, 3, outline, Color(0, 0, 0, 0.35))
		draw_multiline_string(font, Vector2(text_rect.position.x, y), text, HORIZONTAL_ALIGNMENT_CENTER, text_rect.size.x, fs, 3, col)
	_draw_sub(font, inner, sub_h, col)


func _draw_sub(font: Font, inner: Rect2, sub_h: float, col: Color) -> void:
	if sub == "" or sub_h <= 0.0:
		return
	var fs := int(sub_h * 0.78)
	draw_string(font, Vector2(inner.position.x, inner.end.y - sub_h * 0.2), sub, HORIZONTAL_ALIGNMENT_CENTER, inner.size.x, fs, Color(col, 0.85))
