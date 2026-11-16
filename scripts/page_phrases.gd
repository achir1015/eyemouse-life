class_name PhrasePage
extends Control
## 句子頁：一格一句，看著就說出來。右邊是上一頁／下一頁／編輯。
## 「我的常用」多一顆「最近說過」切換鍵。

var main: Node
var cat := "care"
var page := 0
var show_history := false
var tiles: Array = []
var k_prev: GazeKey
var k_next: GazeKey
var k_edit: GazeKey
var k_hist: GazeKey
var lbl_page: Label
var lbl_empty: Label


func setup(m: Node, c: String) -> void:
	main = m
	cat = c
	name = "page_" + c


func _ready() -> void:
	var h := float(Data.cat(cat).hue)
	k_prev = GazeKey.make("上一頁", h, "up", 24)
	k_prev.key_id = "prev"
	k_prev.fired.connect(func(): _turn(-1))
	k_next = GazeKey.make("下一頁", h, "down", 24)
	k_next.key_id = "next"
	k_next.fired.connect(func(): _turn(1))
	k_edit = GazeKey.make("編輯", 0.08, "edit", 22)
	k_edit.key_id = "edit"
	k_edit.color_override = Color(0.35, 0.38, 0.45)
	k_edit.fired.connect(func(): main.open_editor(cat))
	for k in [k_prev, k_next, k_edit]:
		add_child(k)
	if cat == "mine":
		k_hist = GazeKey.make("最近說過", 0.14, "history", 22)
		k_hist.key_id = "history"
		k_hist.fired.connect(_toggle_history)
		add_child(k_hist)
	lbl_page = Label.new()
	lbl_page.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_page.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_page.add_theme_font_size_override("font_size", 22)
	add_child(lbl_page)
	lbl_empty = Label.new()
	lbl_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_empty.add_theme_font_size_override("font_size", 28)
	add_child(lbl_empty)
	App.phrases_changed.connect(func(c): if c == cat or c == "": rebuild())
	resized.connect(rebuild)
	rebuild()


func items() -> Array:
	if show_history:
		return App.history
	return App.phrases.get(cat, [])


func grid() -> Vector2i:
	if cat == "quick":
		return Vector2i(5, 2)
	var rows := 5 if size.y >= 520 else 4
	if size.y >= 680:
		rows = 6
	return Vector2i(4, rows)


func per_page() -> int:
	var g := grid()
	return g.x * g.y


func pages() -> int:
	return maxi(1, ceili(float(items().size()) / per_page()))


func _turn(d: int) -> void:
	page = clampi(page + d, 0, pages() - 1)
	Snd.play("page")
	rebuild()


func _toggle_history() -> void:
	show_history = not show_history
	page = 0
	rebuild()


func rebuild() -> void:
	if size.x < 10:
		return
	for t in tiles:
		t.queue_free()
	tiles.clear()
	var g := grid()
	var nav_w := 150.0
	var gap := 10.0
	var area := Vector2(size.x - nav_w - gap, size.y)
	var cw := (area.x - gap * (g.x - 1)) / g.x
	var ch := (area.y - gap * (g.y - 1)) / g.y
	var list := items()
	page = clampi(page, 0, pages() - 1)
	var start := page * per_page()
	var h := float(Data.cat(cat).hue)
	var fs := 46 if cat == "quick" else 30
	for i in per_page():
		var idx := start + i
		if idx >= list.size():
			break
		var txt: String = list[idx]
		var k := GazeKey.make(txt, h, "", fs)
		if cat == "quick":
			k.hue = [0.36, 0.0, 0.36, 0.0, 0.36, 0.0, 0.62, 0.12, 0.62, 0.9][idx % 10]
		k.key_id = "%s:%d" % [cat, idx]
		k.position = Vector2((i % g.x) * (cw + gap), (i / g.x) * (ch + gap))
		k.size = Vector2(cw, ch)
		k.fired.connect(func(): App.say_phrase(txt))
		add_child(k)
		tiles.append(k)
	# 右側導覽
	var x := size.x - nav_w
	var nh := (size.y - gap * 3) / 4.0
	k_prev.position = Vector2(x, 0)
	k_prev.size = Vector2(nav_w, nh)
	lbl_page.position = Vector2(x, nh + gap)
	lbl_page.size = Vector2(nav_w, nh * 0.6)
	k_next.position = Vector2(x, nh * 1.6 + gap * 2)
	k_next.size = Vector2(nav_w, nh)
	var bottom_y := nh * 2.6 + gap * 3
	var rest := size.y - bottom_y
	if k_hist:
		k_hist.position = Vector2(x, bottom_y)
		k_hist.size = Vector2(nav_w, rest / 2 - gap / 2)
		k_hist.text = "我的常用" if show_history else "最近說過"
		k_hist.icon = "star" if show_history else "history"
		k_edit.position = Vector2(x, bottom_y + rest / 2 + gap / 2)
		k_edit.size = Vector2(nav_w, rest / 2 - gap / 2)
	else:
		k_edit.position = Vector2(x, bottom_y)
		k_edit.size = Vector2(nav_w, rest)
	k_edit.visible = not show_history
	k_prev.enabled = page > 0
	k_next.enabled = page < pages() - 1
	lbl_page.text = "第 %d / %d 頁" % [page + 1, pages()]
	lbl_page.add_theme_color_override("font_color", Pal.text())
	lbl_empty.visible = list.is_empty()
	lbl_empty.position = Vector2.ZERO
	lbl_empty.size = area
	lbl_empty.add_theme_color_override("font_color", Pal.text_dim())
	lbl_empty.text = "還沒有說過的話。" if show_history else "這裡還沒有句子。照顧者可以用滑鼠點「編輯」新增。"
