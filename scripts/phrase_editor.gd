class_name PhraseEditor
extends Control
## 照顧者編輯句子（用滑鼠和鍵盤）：新增、修改、刪除、調整順序、恢復預設。

var main: Node
var cat := ""
var list: ItemList
var edit: LineEdit
var hint: Label


func setup(m: Node, c: String) -> void:
	main = m
	cat = c


func _btn(t: String, cb: Callable, col := Color("#3B6FD8")) -> Button:
	var b := Button.new()
	b.text = t
	b.add_theme_font_size_override("font_size", 24)
	b.custom_minimum_size = Vector2(0, 56)
	for st in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = col.lightened(0.1) if st == "hover" else (col.darkened(0.15) if st == "pressed" else col)
		sb.set_corner_radius_all(12)
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.pressed.connect(cb)
	return b


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#F7F3EC")
	sb.set_corner_radius_all(20)
	sb.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 60
	panel.offset_right = -60
	panel.offset_top = 40
	panel.offset_bottom = -40
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var title := Label.new()
	title.text = "編輯「%s」（照顧者用滑鼠和鍵盤操作）" % Data.cat(cat).name
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("#2B2B2B"))
	v.add_child(title)
	var h := HBoxContainer.new()
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h.add_theme_constant_override("separation", 16)
	v.add_child(h)
	list = ItemList.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.size_flags_stretch_ratio = 1.6
	list.add_theme_font_size_override("font_size", 26)
	list.add_theme_color_override("font_color", Color("#222"))
	list.add_theme_color_override("font_hovered_color", Color("#000"))
	list.add_theme_color_override("font_selected_color", Color.WHITE)
	var lsb := StyleBoxFlat.new()
	lsb.bg_color = Color.WHITE
	lsb.border_color = Color("#CCC")
	lsb.set_border_width_all(2)
	lsb.set_corner_radius_all(10)
	lsb.set_content_margin_all(8)
	list.add_theme_stylebox_override("panel", lsb)
	var ssb := StyleBoxFlat.new()
	ssb.bg_color = Color("#1C7ED6")
	ssb.set_corner_radius_all(6)
	list.add_theme_stylebox_override("selected", ssb)
	list.add_theme_stylebox_override("selected_focus", ssb)
	list.item_selected.connect(func(i): edit.text = list.get_item_text(i))
	h.add_child(list)
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 10)
	h.add_child(side)
	var l := Label.new()
	l.text = "句子內容："
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", Color("#444"))
	side.add_child(l)
	edit = LineEdit.new()
	edit.add_theme_font_size_override("font_size", 28)
	edit.add_theme_color_override("font_color", Color("#111"))
	edit.add_theme_color_override("font_placeholder_color", Color("#999"))
	var esb := StyleBoxFlat.new()
	esb.bg_color = Color.WHITE
	esb.border_color = Color("#1C7ED6")
	esb.set_border_width_all(2)
	esb.set_corner_radius_all(10)
	esb.set_content_margin_all(10)
	edit.add_theme_stylebox_override("normal", esb)
	edit.add_theme_stylebox_override("focus", esb)
	edit.custom_minimum_size = Vector2(0, 60)
	edit.placeholder_text = "輸入要說的話"
	edit.text_submitted.connect(func(_t): _add())
	side.add_child(edit)
	side.add_child(_btn("新增這句", _add, Color("#2F9E44")))
	side.add_child(_btn("把選取的改成上面的內容", _modify))
	side.add_child(_btn("刪除選取的句子", _delete, Color("#C92A2A")))
	var mv := HBoxContainer.new()
	mv.add_theme_constant_override("separation", 10)
	var up := _btn("往前移", func(): _move(-1), Color("#6741D9"))
	up.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var dn := _btn("往後移", func(): _move(1), Color("#6741D9"))
	dn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mv.add_child(up)
	mv.add_child(dn)
	side.add_child(mv)
	if Data.PHRASES.has(cat):
		side.add_child(_btn("恢復成預設句子", _reset, Color("#868E96")))
	hint = Label.new()
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.text = "預設句子有預錄的自然語音；自己新增的句子會用電腦內建語音朗讀。"
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Color("#666"))
	hint.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(hint)
	side.add_child(_btn("完成", queue_free, Color("#1C7ED6")))
	_fill()
	edit.grab_focus()


func _fill(sel := -1) -> void:
	list.clear()
	for t in App.phrases.get(cat, []):
		list.add_item(t)
	if sel >= 0 and sel < list.item_count:
		list.select(sel)
		list.ensure_current_is_visible()


func _sel() -> int:
	var s := list.get_selected_items()
	return s[0] if s.size() > 0 else -1


func _add() -> void:
	var t := edit.text.strip_edges()
	if t == "":
		return
	App.phrases[cat].append(t)
	App.save_phrases(cat)
	edit.text = ""
	_fill(App.phrases[cat].size() - 1)


func _modify() -> void:
	var i := _sel()
	var t := edit.text.strip_edges()
	if i < 0 or t == "":
		return
	App.phrases[cat][i] = t
	App.save_phrases(cat)
	_fill(i)


func _delete() -> void:
	var i := _sel()
	if i < 0:
		return
	App.phrases[cat].remove_at(i)
	App.save_phrases(cat)
	_fill(mini(i, App.phrases[cat].size() - 1))


func _move(d: int) -> void:
	var i := _sel()
	var arr: Array = App.phrases[cat]
	var j := i + d
	if i < 0 or j < 0 or j >= arr.size():
		return
	var t = arr[i]
	arr[i] = arr[j]
	arr[j] = t
	App.save_phrases(cat)
	_fill(j)


func _reset() -> void:
	App.reset_phrases(cat)
	_fill()
