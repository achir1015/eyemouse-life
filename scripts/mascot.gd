class_name Mascot
extends Node3D
## 3D 眼動鼠（原創造型，與眼動鼠 App 圖示同一隻）：會眨眼、說話時嘴巴動、頭會轉向使用者看的方向、會揮手。

var look := Vector2.ZERO          # -1～1：使用者視線相對位置（頭跟著轉）
var talking := false
var _t := 0.0
var _blink := 0.0
var _next_blink := 2.0
var _wave := 0.0
var _point := Vector2.ZERO
var _pointing := 0.0

var head: Node3D
var eyes: Array = []
var mouth: MeshInstance3D
var arm_l: Node3D
var arm_r: Node3D
var body: Node3D


static func mat(c: Color, rough := 0.55, emit := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	return m


static func sphere(r: float, c: Color, parent: Node3D, pos := Vector3.ZERO, scl := Vector3.ONE, rough := 0.55) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2
	sm.radial_segments = 32
	sm.rings = 16
	mi.mesh = sm
	mi.material_override = mat(c, rough)
	mi.position = pos
	mi.scale = scl
	parent.add_child(mi)
	return mi


static func capsule(r: float, h: float, c: Color, parent: Node3D, pos := Vector3.ZERO, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = r
	cm.height = maxf(h, r * 2.01)
	cm.radial_segments = 24
	cm.rings = 8
	mi.mesh = cm
	mi.material_override = mat(c)
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func _ready() -> void:
	var fur := Color("#D9D3F2")
	var line := Color("#7C70B8")
	var pink := Color("#FFB3CF")
	body = Node3D.new()
	add_child(body)
	# 身體＋胸前的小愛心（生活工具）
	sphere(0.42, fur, body, Vector3(0, 0.38, 0), Vector3(1.0, 0.95, 0.85))
	sphere(0.26, Color("#EEEAFB"), body, Vector3(0, 0.36, 0.17), Vector3(1, 1, 0.5))
	var heart := Node3D.new()
	heart.position = Vector3(0, 0.42, 0.33)
	body.add_child(heart)
	sphere(0.055, Color("#FF6B8B"), heart, Vector3(-0.04, 0.02, 0))
	sphere(0.055, Color("#FF6B8B"), heart, Vector3(0.04, 0.02, 0))
	var tip := sphere(0.06, Color("#FF6B8B"), heart, Vector3(0, -0.035, 0), Vector3(0.9, 0.9, 0.8))
	tip.rotation_degrees = Vector3(0, 0, 45)
	# 腳
	sphere(0.12, line, body, Vector3(-0.18, 0.02, 0.12), Vector3(1, 0.6, 1.3))
	sphere(0.12, line, body, Vector3(0.18, 0.02, 0.12), Vector3(1, 0.6, 1.3))
	# 手臂（以肩膀為轉軸）
	arm_l = Node3D.new()
	arm_l.position = Vector3(0.36, 0.55, 0.02)
	body.add_child(arm_l)
	capsule(0.07, 0.34, fur, arm_l, Vector3(0.0, -0.15, 0), Vector3(0, 0, 0.25))
	sphere(0.08, Color("#F1EDFF"), arm_l, Vector3(0.04, -0.32, 0))
	arm_r = Node3D.new()
	arm_r.position = Vector3(-0.36, 0.55, 0.02)
	body.add_child(arm_r)
	capsule(0.07, 0.34, fur, arm_r, Vector3(0.0, -0.15, 0), Vector3(0, 0, -0.25))
	sphere(0.08, Color("#F1EDFF"), arm_r, Vector3(-0.04, -0.32, 0))
	# 頭
	head = Node3D.new()
	head.position = Vector3(0, 1.05, 0)
	add_child(head)
	sphere(0.5, fur, head, Vector3.ZERO, Vector3(1.0, 0.92, 0.9))
	for sx in [-1, 1]:
		var ear := sphere(0.26, fur, head, Vector3(sx * 0.4, 0.38, -0.05), Vector3(1, 1, 0.35))
		ear.rotation_degrees.z = -sx * 20
		sphere(0.17, pink, head, Vector3(sx * 0.4, 0.38, 0.04), Vector3(1, 1, 0.2))
		# 眼睛
		var eye := Node3D.new()
		eye.position = Vector3(sx * 0.17, 0.02, 0.4)
		head.add_child(eye)
		sphere(0.13, Color("#2F2849"), eye, Vector3.ZERO, Vector3(1, 1.2, 0.5))
		sphere(0.115, Color.WHITE, eye, Vector3(0, 0, 0.012), Vector3(1, 1.18, 0.5))
		var iris := sphere(0.085, Color("#6D5DEB"), eye, Vector3(0, -0.01, 0.04), Vector3(1, 1.15, 0.45))
		sphere(0.05, Color("#2F2849"), iris, Vector3(0, 0, 0.05), Vector3(1, 1, 0.5))
		sphere(0.028, Color.WHITE, eye, Vector3(-0.035, 0.05, 0.08), Vector3(1, 1, 0.4), 0.1)
		eyes.append(eye)
		# 腮紅、鬍鬚
		sphere(0.08, Color("#FFC2D6"), head, Vector3(sx * 0.3, -0.16, 0.33), Vector3(1.2, 0.7, 0.3))
		for i in 3:
			var wh := capsule(0.008, 0.32, line, head, Vector3(sx * 0.36, -0.12 - i * 0.045, 0.32), Vector3(0, 0, PI / 2 + sx * (i - 1) * 0.15))
			wh.material_override = mat(line.darkened(0.1))
	sphere(0.05, Color("#FF7EA6"), head, Vector3(0, -0.09, 0.45), Vector3(1.2, 0.9, 0.8))
	mouth = sphere(0.05, Color("#5A3F6E"), head, Vector3(0, -0.2, 0.42), Vector3(1.2, 0.25, 0.5))


func wave() -> void:
	_wave = 2.4


## 指向畫面上的方向（-1～1），持續 dur 秒
func point_to(dir: Vector2, dur := 2.0) -> void:
	_point = dir
	_pointing = dur


func _process(delta: float) -> void:
	_t += delta
	# 呼吸
	body.scale = Vector3(1, 1.0 + sin(_t * 2.0) * 0.015, 1)
	head.position.y = 1.05 + sin(_t * 2.0) * 0.012
	# 頭跟著視線轉
	var target := Vector3(-look.y * 0.25, look.x * 0.45, -look.x * 0.06)
	if talking:
		target.x += sin(_t * 7.0) * 0.05
	head.rotation = head.rotation.lerp(target, minf(1.0, delta * 5.0))
	# 眨眼
	_next_blink -= delta
	if _next_blink <= 0.0:
		_blink = 0.16
		_next_blink = randf_range(2.5, 5.0)
	_blink = maxf(0.0, _blink - delta)
	var ey := 0.12 if _blink > 0.0 else 1.0
	for e in eyes:
		(e as Node3D).scale.y = lerpf((e as Node3D).scale.y, ey, minf(1.0, delta * 30.0))
	# 說話：嘴巴開合
	var open := 0.25
	if talking:
		open = 0.35 + absf(sin(_t * 11.0)) * 0.9
	mouth.scale.y = lerpf(mouth.scale.y, open, minf(1.0, delta * 18.0))
	# 揮手／指方向
	if _wave > 0.0:
		_wave -= delta
		arm_l.rotation = Vector3(0, 0, 2.3 + sin(_t * 9.0) * 0.45)
	elif _pointing > 0.0:
		_pointing -= delta
		var side := arm_l if _point.x >= 0 else arm_r
		var a := atan2(-_point.y, absf(_point.x) + 0.001)
		side.rotation = side.rotation.lerp(Vector3(0, 0, (PI / 2 + a) * (1 if _point.x >= 0 else -1)), minf(1.0, delta * 8.0))
	else:
		arm_l.rotation = arm_l.rotation.lerp(Vector3(0, 0, sin(_t * 1.6) * 0.06), minf(1.0, delta * 6.0))
		arm_r.rotation = arm_r.rotation.lerp(Vector3(0, 0, -sin(_t * 1.6) * 0.06), minf(1.0, delta * 6.0))


## 建一個放吉祥物的小視窗（獨立 3D 世界、透明背景）
static func make_view(px_size: Vector2i, zoom := 1.0) -> Array:
	var cont := SubViewportContainer.new()
	cont.stretch = true
	cont.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.size = px_size
	vp.msaa_3d = Viewport.MSAA_4X
	cont.add_child(vp)
	var m := Mascot.new()
	vp.add_child(m)
	var cam := Camera3D.new()
	cam.fov = 32.0 / zoom
	vp.add_child(cam)
	cam.transform = Transform3D(Basis.looking_at(Vector3(0, 0.82, 0) - Vector3(0, 0.95, 4.6)), Vector3(0, 0.95, 4.6))
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 25, 0)
	sun.light_energy = 1.1
	vp.add_child(sun)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.95, 0.93, 1.0)
	e.ambient_light_energy = 0.75
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment = e
	vp.add_child(env)
	return [cont, m]
