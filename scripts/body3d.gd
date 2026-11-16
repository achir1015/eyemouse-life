class_name Body3D
extends Node3D
## 3D 人體：看著哪個部位就亮起來，停留選取。可以轉到背面。
## 病人自己的左邊 = 模型的 +X（正面朝向鏡頭時在畫面右邊）。

signal part_hover(id: String)

var parts := {}                 # 碰撞體 → 部位設定 {front, back, top}
var meshes := {}                # 部位 id → Array[MeshInstance3D]（同一部位可以有多個模型）
var hover_id := ""
var selected_id := ""
var facing_back := false
var _yaw := 0.0
var _t := 0.0
var skin := Color("#F2C9A8")
var _mat_cache := {}
var root: Node3D                # 轉身用
var wide: Node3D                # 人體外形（橫向加寬）
const WIDTH := 1.2              # 正面、背面都加寬 20%


func _ready() -> void:
	root = Node3D.new()
	add_child(root)
	wide = Node3D.new()
	wide.scale = Vector3(WIDTH, 1, 1)
	root.add_child(wide)
	_build()


func _base(id: String) -> Color:
	if id.begins_with("eye"):
		return Color("#FFFFFF")          # 眼白（眼珠另外畫）
	if id == "mouth":
		return Color("#C2524A")          # 嘴唇
	if id.begins_with("ear"):
		return Color("#E9B18D")
	if id == "nose":
		return Color("#ECBA96")
	return skin


func _skin_mat(id: String) -> StandardMaterial3D:
	if not _mat_cache.has(id):
		var m := StandardMaterial3D.new()
		m.albedo_color = _base(id)
		m.roughness = 0.7
		m.emission_enabled = true
		m.emission = Color.BLACK
		_mat_cache[id] = m
	return _mat_cache[id]


func _add(shape: String, front: String, back: String, pos: Vector3, dims: Vector3, rot := Vector3.ZERO, extra := {}) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation = rot
	wide.add_child(body)
	var mi := MeshInstance3D.new()
	var col := CollisionShape3D.new()
	match shape:
		"sphere":
			var sm := SphereMesh.new()
			sm.radius = 0.5
			sm.height = 1.0
			sm.radial_segments = 32
			sm.rings = 16
			mi.mesh = sm
			mi.scale = dims
			var cs := SphereShape3D.new()
			cs.radius = 0.5
			col.shape = cs
			col.scale = dims
		"capsule":
			var cm := CapsuleMesh.new()
			cm.radius = dims.x
			cm.height = maxf(dims.y, dims.x * 2.01)
			cm.radial_segments = 24
			mi.mesh = cm
			mi.scale = Vector3(1, 1, dims.z if dims.z > 0 else 1)
			var cc := CapsuleShape3D.new()
			cc.radius = dims.x
			cc.height = maxf(dims.y, dims.x * 2.01)
			col.shape = cc
			col.scale = mi.scale
	body.add_child(mi)
	body.add_child(col)
	var cfg := {"front": front, "back": back}
	cfg.merge(extra)
	parts[body] = cfg
	for id in [front, back, str(extra.get("top", ""))]:
		if id == "":
			continue
		mi.material_override = _skin_mat(front)
		if not meshes.has(id):
			meshes[id] = []
		meshes[id].append(mi)


func _build() -> void:
	# 頭（正面＝臉，背面＝後腦勺，頂部＝頭頂）
	_add("sphere", "face", "back_head", Vector3(0, 1.62, 0), Vector3(0.24, 0.28, 0.25), Vector3.ZERO, {"top": "head_top", "top_y": 1.70})
	for sx in [-1, 1]:
		var side := "_l" if sx > 0 else "_r"
		_add("sphere", "ear" + side, "ear" + side, Vector3(sx * 0.125, 1.62, -0.005), Vector3(0.04, 0.075, 0.05))
		_add("sphere", "eye" + side, "back_head", Vector3(sx * 0.048, 1.645, 0.11), Vector3(0.056, 0.04, 0.04))
		# 五官細節（只有外觀，不影響選取）：眼珠、瞳孔、反光、眉毛、鼻孔
		_deco(Vector3(sx * 0.048, 1.644, 0.127), Vector3(0.027, 0.029, 0.01), Color("#3A2618"))
		_deco(Vector3(sx * 0.048, 1.644, 0.1315), Vector3(0.012, 0.013, 0.005), Color("#0B0705"))
		_deco(Vector3(sx * 0.048 - 0.006, 1.651, 0.1335), Vector3(0.007, 0.007, 0.004), Color.WHITE, true)
		_deco(Vector3(sx * 0.05, 1.677, 0.108), Vector3(0.064, 0.011, 0.014), Color("#4A3226"), false, sx * -0.12)
		_deco(Vector3(sx * 0.011, 1.582, 0.144), Vector3(0.011, 0.007, 0.006), Color("#7A4A3A"))
	_add("sphere", "nose", "back_head", Vector3(0, 1.603, 0.127), Vector3(0.042, 0.062, 0.052))
	_add("sphere", "mouth", "back_head", Vector3(0, 1.556, 0.112), Vector3(0.078, 0.034, 0.042))
	_deco(Vector3(0, 1.556, 0.1325), Vector3(0.062, 0.006, 0.004), Color("#6E2A28"))
	_add("capsule", "neck", "nape", Vector3(0, 1.47, 0), Vector3(0.055, 0.14, 0))
	# 軀幹
	_add("capsule", "chest", "upper_back", Vector3(0, 1.28, 0), Vector3(0.155, 0.38, 0.72), Vector3(0, 0, PI / 2), {"sx": 1.0})
	_add("capsule", "belly", "waist", Vector3(0, 1.04, 0), Vector3(0.14, 0.32, 0.75), Vector3(0, 0, PI / 2))
	_add("sphere", "groin", "butt", Vector3(0, 0.88, -0.005), Vector3(0.31, 0.2, 0.22))
	for sx in [-1, 1]:
		var side := "_l" if sx > 0 else "_r"
		_add("sphere", "shoulder" + side, "shoulder" + side, Vector3(sx * 0.2, 1.405, 0), Vector3(0.13, 0.12, 0.13))
		_add("capsule", "uarm" + side, "uarm" + side, Vector3(sx * 0.235, 1.23, 0), Vector3(0.048, 0.32, 0), Vector3(0, 0, sx * 0.12))
		_add("capsule", "farm" + side, "farm" + side, Vector3(sx * 0.262, 0.97, 0.015), Vector3(0.042, 0.3, 0), Vector3(0, 0, sx * 0.06))
		_add("sphere", "hand" + side, "hand" + side, Vector3(sx * 0.272, 0.775, 0.02), Vector3(0.075, 0.14, 0.05))
		_add("capsule", "thigh" + side, "thigh" + side, Vector3(sx * 0.095, 0.64, 0), Vector3(0.075, 0.42, 0))
		_add("sphere", "knee" + side, "knee" + side, Vector3(sx * 0.095, 0.425, 0.01), Vector3(0.115, 0.1, 0.11))
		_add("capsule", "calf" + side, "calf" + side, Vector3(sx * 0.095, 0.24, 0), Vector3(0.055, 0.36, 0))
		_add("capsule", "foot" + side, "foot" + side, Vector3(sx * 0.095, 0.035, 0.04), Vector3(0.04, 0.2, 0), Vector3(PI / 2, 0, 0))


## 只有外觀的小零件（五官細節），沒有碰撞體
func _deco(pos: Vector3, dims: Vector3, col: Color, glossy := false, roll := 0.0) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 24
	sm.rings = 12
	mi.mesh = sm
	mi.position = pos
	mi.rotation.z = roll
	mi.scale = dims
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.2 if glossy else 0.6
	if glossy:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = m
	wide.add_child(mi)


## 視線打到的部位 id（camera 的光線）
func pick(cam: Camera3D, vp_pos: Vector2) -> String:
	var from := cam.project_ray_origin(vp_pos)
	var to := from + cam.project_ray_normal(vp_pos) * 20.0
	var q := PhysicsRayQueryParameters3D.create(from, to)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty() or not parts.has(hit.collider):
		return ""
	var cfg: Dictionary = parts[hit.collider]
	var local: Vector3 = wide.global_transform.affine_inverse() * (hit.position as Vector3)
	if cfg.has("top") and local.y > float(cfg.top_y):
		return str(cfg.top)
	return str(cfg.front) if local.z >= 0.0 else str(cfg.back)


## 模型座標（加寬前）→ 世界座標，給示範游標與測試用
func world_pos(p: Vector3) -> Vector3:
	return wide.global_transform * p


func set_back(v: bool) -> void:
	facing_back = v


func _process(delta: float) -> void:
	_t += delta
	var target := PI if facing_back else 0.0
	_yaw = lerp_angle(_yaw, target, minf(1.0, delta * 5.0))
	root.rotation.y = _yaw
	# 上色：注視中（黃）、已選（橘、閃）
	for id in _mat_cache:
		var m: StandardMaterial3D = _mat_cache[id]
		m.emission = Color.BLACK
		m.albedo_color = _base(id)
	_tint(hover_id, Color("#FFD43B"), 0.55)
	_tint(selected_id, Color("#FF7A00"), 0.45 + sin(_t * 5.0) * 0.2)


func _tint(id: String, c: Color, k: float) -> void:
	if id == "" or not meshes.has(id):
		return
	for mi in meshes[id]:
		var m: StandardMaterial3D = (mi as MeshInstance3D).material_override
		m.albedo_color = _base(id).lerp(c, 0.65)
		m.emission = c * k
