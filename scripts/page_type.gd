class_name TypePage
extends Control
## 打字說話：眼控注音鍵盤（可不打聲調、自動分字、候選詞、聯想），也可切換英數。
## 打好的字放進上方說話列，看「朗讀」念出來；也可以存成「我的常用」。

const BPMF_ROWS := [
	["ㄅ", "ㄉ", "ˇ", "ˋ", "ㄓ", "ˊ", "˙", "ㄚ", "ㄞ", "ㄢ", "ㄦ"],
	["ㄆ", "ㄊ", "ㄍ", "ㄐ", "ㄔ", "ㄗ", "ㄧ", "ㄛ", "ㄟ", "ㄣ", "ˉ"],
	["ㄇ", "ㄋ", "ㄎ", "ㄑ", "ㄕ", "ㄘ", "ㄨ", "ㄜ", "ㄠ", "ㄤ", "，"],
	["ㄈ", "ㄌ", "ㄏ", "ㄒ", "ㄖ", "ㄙ", "ㄩ", "ㄝ", "ㄡ", "ㄥ", "。"],
]
const ABC_ROWS := [
	["1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "?"],
	["q", "w", "e", "r", "t", "y", "u", "i", "o", "p", "!"],
	["a", "s", "d", "f", "g", "h", "j", "k", "l", "-", ","],
	["z", "x", "c", "v", "b", "n", "m", "@", ".", "/", ":"],
]
const CAND_N := 8

var main: Node
var mode := "bpmf"
var syls: Array = []           # 正在拼的注音音節
var cands: Array = []          # 候選 [{w, n}] 或聯想字串
var assoc := false             # 目前顯示的是聯想詞
var cand_page := 0
var keys: Array = []
var cand_keys: Array = []
var k_cprev: GazeKey
var k_cnext: GazeKey
var ctrl_keys := {}
var lbl_comp: Label


func setup(m: Node) -> void:
	main = m
	name = "page_type"


func _ready() -> void:
	Bpmf.load_async()
	lbl_comp = Label.new()
	lbl_comp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_comp.add_theme_font_size_override("font_size", 34)
	lbl_comp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lbl_comp)
	for i in CAND_N:
		var k := GazeKey.make("", 0.14, "", 40)
		k.key_id = "cand:%d" % i
		var idx := i
		k.fired.connect(func(): _pick(idx))
		add_child(k)
		cand_keys.append(k)
	k_cprev = GazeKey.make("", 0.14, "left", 20)
	k_cprev.fired.connect(func(): _cand_turn(-1))
	k_cnext = GazeKey.make("", 0.14, "right", 20)
	k_cnext.fired.connect(func(): _cand_turn(1))
	add_child(k_cprev)
	add_child(k_cnext)
	for r in 4:
		for c in 11:
			var k := GazeKey.make("", 0.62, "", 36)
			var rr := r
			var cc := c
			k.fired.connect(func(): _key(rr, cc))
			add_child(k)
			keys.append(k)
	var defs := [
		["mode", "英數", "", 0.72], ["space", "空白", "space", 0.62], ["del", "刪除", "backspace", 0.02],
		["speak", "朗讀", "speaker", 0.36], ["save", "存到常用", "save", 0.14], ["clear", "全部清除", "trash", 0.0],
	]
	for d in defs:
		var k := GazeKey.make(d[1], d[3], d[2], 26)
		k.key_id = "type:" + d[0]
		var id: String = d[0]
		k.fired.connect(func(): _ctrl(id))
		add_child(k)
		ctrl_keys[d[0]] = k
	ctrl_keys["del"].repeatable = true
	resized.connect(_layout)
	_layout()
	_refresh()


func _layout() -> void:
	if size.x < 10:
		return
	var gap := 8.0
	var top_h := clampf(size.y * 0.15, 70, 110)
	var ctrl_h := clampf(size.y * 0.14, 64, 100)
	var kb_h := size.y - top_h - ctrl_h - gap * 2
	# 候選列：左邊顯示拼音，右邊候選字
	var comp_w := clampf(size.x * 0.16, 130, 220)
	lbl_comp.position = Vector2(0, 0)
	lbl_comp.size = Vector2(comp_w, top_h)
	var arrow_w := 56.0
	var cx := comp_w + gap
	var cw := (size.x - cx - (arrow_w + gap) * 2 - gap * (CAND_N - 1)) / CAND_N
	k_cprev.position = Vector2(cx, 0)
	k_cprev.size = Vector2(arrow_w, top_h)
	cx += arrow_w + gap
	for i in CAND_N:
		var k: GazeKey = cand_keys[i]
		k.position = Vector2(cx + i * (cw + gap), 0)
		k.size = Vector2(cw, top_h)
	k_cnext.position = Vector2(size.x - arrow_w, 0)
	k_cnext.size = Vector2(arrow_w, top_h)
	# 鍵盤 11 × 4
	var kw := (size.x - gap * 10) / 11
	var kh := (kb_h - gap * 3) / 4
	for r in 4:
		for c in 11:
			var k: GazeKey = keys[r * 11 + c]
			k.position = Vector2(c * (kw + gap), top_h + gap + r * (kh + gap))
			k.size = Vector2(kw, kh)
	# 控制列
	var n := ctrl_keys.size()
	var bw := (size.x - gap * (n - 1)) / n
	var i := 0
	for id in ["mode", "space", "del", "speak", "save", "clear"]:
		var k: GazeKey = ctrl_keys[id]
		k.position = Vector2(i * (bw + gap), size.y - ctrl_h)
		k.size = Vector2(bw, ctrl_h)
		i += 1


func _rows() -> Array:
	return BPMF_ROWS if mode == "bpmf" else ABC_ROWS


func _refresh() -> void:
	var rows := _rows()
	for r in 4:
		for c in 11:
			var k: GazeKey = keys[r * 11 + c]
			var s: String = rows[r][c]
			k.text = s
			k.key_id = "key:" + s
			var kd := Bpmf.kind(s)
			k.hue = [0.58, 0.48, 0.66, 0.08][kd] if mode == "bpmf" and kd >= 0 else 0.62
			if s == "ˉ":
				k.text = "一聲"
				k.font_size = 24
			else:
				k.font_size = 38
	ctrl_keys["mode"].text = "英數" if mode == "bpmf" else "注音"
	lbl_comp.add_theme_color_override("font_color", Pal.text())
	lbl_comp.text = "".join(syls) if not syls.is_empty() else ("聯想" if assoc and not cands.is_empty() else "")
	if lbl_comp.text == "" :
		lbl_comp.text = "注音" if mode == "bpmf" else "ABC"
		lbl_comp.add_theme_color_override("font_color", Pal.text_dim())
	var start := cand_page * CAND_N
	for i in CAND_N:
		var k: GazeKey = cand_keys[i]
		var j := start + i
		if j < cands.size():
			var c = cands[j]
			k.text = str(c.w) if c is Dictionary else str(c)
			k.enabled = true
			k.visible = true
		else:
			k.text = ""
			k.enabled = false
	k_cprev.enabled = cand_page > 0
	k_cnext.enabled = (cand_page + 1) * CAND_N < cands.size()


func _update_cands() -> void:
	assoc = false
	cand_page = 0
	cands = Bpmf.candidates(syls) if not syls.is_empty() else []
	_refresh()


func _key(r: int, c: int) -> void:
	var s: String = _rows()[r][c]
	if mode == "abc":
		App.type_text(s)
		return
	if s == "，" or s == "。":
		_commit_raw()
		App.type_text(s)
		return
	syls = Bpmf.push_symbol(syls, s)
	_update_cands()


func _pick(i: int) -> void:
	var j := cand_page * CAND_N + i
	if j >= cands.size():
		return
	var c = cands[j]
	if c is Dictionary:
		App.type_text(str(c.w))
		syls = syls.slice(int(c.n))
		if syls.is_empty():
			cands = Bpmf.associate(str(c.w))
			assoc = true
			cand_page = 0
			_refresh()
		else:
			_update_cands()
	else:
		App.type_text(str(c))
		cands = Bpmf.associate(str(c))
		assoc = true
		cand_page = 0
		_refresh()


## 還沒選字就打標點或切換時：直接用第一個候選字
func _commit_raw() -> void:
	if syls.is_empty():
		return
	while not syls.is_empty():
		var cs := Bpmf.candidates(syls, 4)
		if cs.is_empty():
			syls.clear()
			break
		App.type_text(str(cs[0].w))
		syls = syls.slice(int(cs[0].n))
	cands = []
	_refresh()


func _cand_turn(d: int) -> void:
	cand_page = maxi(0, cand_page + d)
	Snd.play("page")
	_refresh()


func _ctrl(id: String) -> void:
	match id:
		"mode":
			_commit_raw()
			mode = "abc" if mode == "bpmf" else "bpmf"
			cands = []
			_refresh()
		"space":
			if mode == "bpmf" and not syls.is_empty():
				syls = Bpmf.push_symbol(syls, "ˉ")
				_update_cands()
			else:
				App.type_text(" ")
		"del":
			if not syls.is_empty():
				var last: String = syls[-1]
				if last.length() <= 1:
					syls.pop_back()
				else:
					syls[-1] = last.substr(0, last.length() - 1)
				_update_cands()
			else:
				App.backspace()
				cands = []
				_refresh()
		"speak":
			_commit_raw()
			App.speak_message()
		"save":
			_commit_raw()
			if App.message.strip_edges() != "" and App.add_phrase("mine", App.message):
				Snd.say_ui("saved")
		"clear":
			syls.clear()
			cands = []
			App.clear_message()
			_refresh()


## 教學示範用：依序按下注音
func demo_keys() -> Array:
	return keys
