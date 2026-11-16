class_name Bpmf
extends RefCounted
## 注音輸入引擎（詞庫：McBopomofo 小麥注音，MIT 授權，data/bpmf.txt）。
## 特色（為眼控設計，減少要看的次數）：
##   • 可以不選聲調：打 ㄒㄧㄝ 就列出「謝、些、寫、鞋…」
##   • 自動分字：打完一個音再打聲母，會自動開始下一個字，可以直接打詞（ㄒㄧㄝㄒㄧㄝ → 謝謝）
##   • 選字後提供聯想詞（選「謝」→ 謝、天謝地…）

const INITIALS := "ㄅㄆㄇㄈㄉㄊㄋㄌㄍㄎㄏㄐㄑㄒㄓㄔㄕㄖㄗㄘㄙ"
const MEDIALS := "ㄧㄨㄩ"
const FINALS := "ㄚㄛㄜㄝㄞㄟㄠㄡㄢㄣㄤㄥㄦ"
const TONES := "ˉˊˇˋ˙"

static var words := PackedStringArray()
static var reads: Array = []                 # 每筆：PackedStringArray 音節（含聲調）
static var bases: Array = []                 # 每筆：PackedStringArray 音節（去掉聲調）
static var by_first := {}                    # 第一個音節（去聲調）→ PackedInt32Array
static var by_char := {}                     # 詞的第一個字 → PackedInt32Array（2 字以上的詞）
static var loaded := false
static var _thread: Thread


static func load_async() -> void:
	if loaded or _thread:
		return
	_thread = Thread.new()
	_thread.start(_load)


static func wait_loaded() -> void:
	if _thread and _thread.is_started():
		_thread.wait_to_finish()
		_thread = null
	if not loaded:
		_load()


static func _load() -> void:
	if loaded:
		return
	var f := FileAccess.open("res://data/bpmf.txt", FileAccess.READ)
	if not f:
		push_error("找不到注音詞庫")
		return
	var w := PackedStringArray()
	var rs: Array = []
	var bs: Array = []
	var bf := {}
	var bc := {}
	var i := 0
	while not f.eof_reached():
		var ln := f.get_line()
		if ln == "" or ln.begins_with("#"):
			continue
		var p := ln.split("\t")
		if p.size() < 2:
			continue
		var syl := p[1].split(" ")
		var b := PackedStringArray()
		for s in syl:
			b.append(strip_tone(s))
		w.append(p[0])
		rs.append(syl)
		bs.append(b)
		var k := b[0]
		if not bf.has(k):
			bf[k] = PackedInt32Array()
		bf[k].append(i)
		if p[0].length() >= 2:
			var c := p[0].substr(0, 1)
			if not bc.has(c):
				bc[c] = PackedInt32Array()
			if bc[c].size() < 80:
				bc[c].append(i)
		i += 1
	words = w
	reads = rs
	bases = bs
	by_first = bf
	by_char = bc
	loaded = true


static func strip_tone(s: String) -> String:
	if s != "" and TONES.contains(s.substr(s.length() - 1)):
		return s.substr(0, s.length() - 1)
	return s


static func tone_of(s: String) -> String:
	# 回傳 ""（沒打聲調）或 "1"、"ˊ"、"ˇ"、"ˋ"、"˙"
	if s == "":
		return ""
	var t := s.substr(s.length() - 1)
	if t == "ˉ":
		return "1"
	if TONES.contains(t):
		return t
	return ""


static func kind(sym: String) -> int:
	if INITIALS.contains(sym):
		return 0
	if MEDIALS.contains(sym):
		return 1
	if FINALS.contains(sym):
		return 2
	if TONES.contains(sym):
		return 3
	return -1


## 把一個注音符號加到音節陣列（自動分字）。回傳新的陣列。
static func push_symbol(syls: Array, sym: String) -> Array:
	var out := syls.duplicate()
	var k := kind(sym)
	if k < 0:
		return out
	if out.is_empty():
		if k == 3:
			return out
		out.append(sym)
		return out
	var cur: String = out[-1]
	if tone_of(cur) != "":
		if k != 3:
			out.append(sym)
		return out
	if k == 3:
		out[-1] = cur + sym
		return out
	# 依結構判斷要不要開新字：聲母 → 介音 → 韻母
	var last_kind := 0
	for ch in cur:
		last_kind = maxi(last_kind, kind(ch))
	var has_kind := [false, false, false]
	for ch in cur:
		var kk := kind(ch)
		if kk >= 0 and kk < 3:
			has_kind[kk] = true
	if k <= last_kind or has_kind[k]:
		out.append(sym)
	else:
		out[-1] = cur + sym
	return out


static func _syl_match(typed: String, rd: String, base: String, partial: bool) -> bool:
	var tb := strip_tone(typed)
	var tt := tone_of(typed)
	if tt != "":
		if tb != base:
			return false
		var rt := tone_of(rd)
		if tt == "1":
			return rt == ""
		return rt == tt
	if partial:
		return base.begins_with(tb)
	return base == tb


## 候選字詞：syls 是已打的音節。回傳 [{w: 字詞, n: 用掉幾個音節}]
static func candidates(syls: Array, limit := 60) -> Array:
	if syls.is_empty():
		return []
	wait_loaded()
	var n := syls.size()
	var first: String = syls[0]
	var fb := strip_tone(first)
	var first_partial := n == 1 and tone_of(first) == ""
	var idx := PackedInt32Array()
	for k in by_first:
		var ok: bool = (k as String).begins_with(fb) if first_partial else k == fb
		if ok:
			idx.append_array(by_first[k])
	idx.sort()
	var out: Array = []
	var seen := {}
	# 1) 整串音節對應的詞
	if n >= 2:
		for i in idx:
			var r: PackedStringArray = reads[i]
			if r.size() != n:
				continue
			var good := true
			for j in n:
				var last := j == n - 1 and tone_of(syls[j]) == ""
				if not _syl_match(syls[j], r[j], bases[i][j], last):
					good = false
					break
			if good and not seen.has(words[i]):
				seen[words[i]] = true
				out.append({"w": words[i], "n": n})
				if out.size() >= limit / 2:
					break
	# 2) 第一個音節的單字
	for i in idx:
		var r: PackedStringArray = reads[i]
		if r.size() != 1:
			continue
		if not _syl_match(first, r[0], bases[i][0], first_partial):
			continue
		if seen.has(words[i]):
			continue
		seen[words[i]] = true
		out.append({"w": words[i], "n": 1})
		if out.size() >= limit:
			break
	return out


## 聯想：選了 c 之後，常接在後面的字（回傳接續的部分）
static func associate(c: String, limit := 18) -> Array:
	wait_loaded()
	if c.length() < 1:
		return []
	var out: Array = []
	# 先找以整個詞開頭的較長詞（選「謝謝」→「謝謝你」的「你」）
	if c.length() >= 2 and by_char.has(c.substr(0, 1)):
		for i in by_char[c.substr(0, 1)]:
			if words[i].length() > c.length() and words[i].begins_with(c):
				var rest0 := words[i].substr(c.length())
				if not out.has(rest0):
					out.append(rest0)
	var last := c.substr(c.length() - 1)
	if by_char.has(last):
		for i in by_char[last]:
			var rest := words[i].substr(1)
			if rest != "" and not out.has(rest):
				out.append(rest)
			if out.size() >= limit:
				break
	return out.slice(0, limit)
