class_name GazeCursor
extends Control
## 視線游標：柔和的圓點，停留選取時外圈慢慢畫滿。教學示範時是一隻小手指＋「示範」。

var _pos := Vector2(-999, -999)
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	_t += delta
	if Gaze.valid:
		var k := 30.0 if Gaze.bot_point == null else 60.0
		_pos = Gaze.point if _pos.x < -900 else _pos.lerp(Gaze.point, minf(1.0, delta * k))
	queue_redraw()


func _prog() -> float:
	if Engine.get_process_frames() - GazeKey.cursor_frame <= 1:
		return clampf(GazeKey.cursor_progress, 0.0, 1.0)
	return 0.0


func _draw() -> void:
	if not Gaze.valid:
		return
	var demo := Gaze.bot_point != null
	if not demo and not bool(App.settings.show_cursor):
		return
	var c := _pos
	var p := _prog()
	var col := Pal.gaze()
	if demo:
		# 示範游標：橘色大圓＋字
		draw_circle(c, 26, Color(1, 0.55, 0.1, 0.35))
		draw_arc(c, 26, 0, TAU, 40, Color("#FF8A00"), 4, true)
		draw_circle(c, 6, Color("#FF8A00"))
		if p > 0.0:
			draw_arc(c, 34, -PI / 2, -PI / 2 + TAU * p, 48, Color("#FF5A00"), 8, true)
		var f := get_theme_default_font()
		draw_string_outline(f, c + Vector2(-40, 62), "示範", HORIZONTAL_ALIGNMENT_CENTER, 80, 22, 6, Color(0, 0, 0, 0.6))
		draw_string(f, c + Vector2(-40, 62), "示範", HORIZONTAL_ALIGNMENT_CENTER, 80, 22, Color("#FFB347"))
		return
	if Gaze.source == "mouse" and not Gaze.linked:
		# 用滑鼠時系統游標就在那裡，只畫進度圈
		if p > 0.0:
			draw_arc(c, 24, -PI / 2, -PI / 2 + TAU * p, 40, col, 6, true)
		return
	draw_circle(c, 16, Color(col, 0.18))
	draw_arc(c, 16, 0, TAU, 32, Color(col, 0.7), 3, true)
	draw_circle(c, 4, col)
	if p > 0.0:
		draw_arc(c, 24, -PI / 2, -PI / 2 + TAU * p, 48, col, 7, true)
