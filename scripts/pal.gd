class_name Pal
extends RefCounted
## 配色：三種主題（夜空藍、暖陽米、高對比）。每個分類一個色相，按鍵顏色由色相推算，
## 所以同一主題裡的按鍵明度一致、白字一樣清楚。


static func hsv(h: float, s: float, v: float, a := 1.0) -> Color:
	var c := Color.from_hsv(fposmod(h, 1.0), clampf(s, 0, 1), clampf(v, 0, 1))
	c.a = a
	return c


static func theme() -> String:
	return str(App.settings.theme)


static func contrast() -> bool:
	return theme() == "contrast"


## 主色：明度自動調到亮度≈0.42，白字對比足夠
static func key_color(h: float, s := 0.6) -> Color:
	if contrast():
		return Color(0.05, 0.05, 0.05)
	var v := 0.95
	var c := hsv(h, s, v)
	var target := 0.40 if theme() == "night" else 0.46
	while c.get_luminance() > target and v > 0.35:
		v -= 0.01
		c = hsv(h, s, v)
	return c


static func bg_top() -> Color:
	match theme():
		"warm": return Color("#FBF4E8")
		"contrast": return Color.BLACK
	return Color("#16243F")


static func bg_bottom() -> Color:
	match theme():
		"warm": return Color("#EAD9C0")
		"contrast": return Color.BLACK
	return Color("#0A1222")


static func panel() -> Color:
	match theme():
		"warm": return Color(1, 0.99, 0.96, 0.88)
		"contrast": return Color(0, 0, 0, 0.95)
	return Color(0.08, 0.13, 0.24, 0.82)


static func panel_border() -> Color:
	match theme():
		"warm": return Color("#D9C3A0")
		"contrast": return Color("#FFE600")
	return Color("#2E4A7A")


static func text() -> Color:
	match theme():
		"warm": return Color("#3A2A14")
		"contrast": return Color("#FFE600")
	return Color("#EAF2FF")


static func text_dim() -> Color:
	match theme():
		"warm": return Color("#7A6448")
		"contrast": return Color("#FFFFFF")
	return Color("#9DB2D6")


static func key_text() -> Color:
	return Color("#FFE600") if contrast() else Color.WHITE


## 視線停留中的外框、進度色
static func gaze() -> Color:
	return Color("#00E5FF") if contrast() else Color("#FFC53D")


static func alarm() -> Color:
	return Color("#E03131")


static func ok() -> Color:
	return Color("#2F9E44")
