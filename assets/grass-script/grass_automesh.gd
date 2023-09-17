@tool
extends Path3D

const MIN_SEGMENT_RATIO : float = .01
const MIN_SEPARATION_SIZE : float = 0.03

enum Interpolation {
	Fibonacy,
	Constant,
	Exponential,
}

@export_category("Species")
@export var randomization : Array[float] = [1] : set = set_randomization
@export var material : ShaderMaterial = null : set = set_material

@export_category("Distribuition")
@export_range(0.02, 2.) var instance_separation : float = 0.34 : set = set_instance_separation
@export var max_scale : float = 1  : set = set_max_scale
@export var min_scale : float = .6 : set = set_min_scale
@export var grassland : float = 1.6 : set = set_grassland
@export_exp_easing var grassland_curve : float = 2. : set = set_grassland_curve
@export var distribuition_texture : CompressedTexture2D = null : set = set_distribuition_texture
@export var distribuition_texture_scale : float = 5. : set = set_distribuition_texture_scale

@export_category("Geometry")
@export_range(0.05, 1.) var lod_bias : float = 0.05 : set = set_lod_bias
@export var max_view_dist : float = 100. : set = set_max_view_dist
@export var lock : bool = false
@export var grass_size : Vector2 = Vector2(1,1) : set = set_grass_size, get = get_grass_size
@export var grass_deep : float = .2: set = set_grass_deep
@export_range(1, 64) var grass_divisions : int = 1 : set = set_grass_division
@export var grass_gravity : float = .2 : set = set_grass_gravity
@export var interpolation_method : Interpolation = Interpolation.Fibonacy : set = set_interpolation_method
@export_exp_easing var interpolation_power : float = 1. : set = set_interpolation_power
@export var acurated_physics : bool = false : set = set_acurated_physics
@export var gravity : Vector3 = Vector3(0,-.98,0) : set = set_gravity
@export var wall_distinction : float = 45. : set = set_wall_distinction
@export var random_inclination : float = 25 : set = set_random_inclination

@export_category("Tool")
@export var create_duplicate : bool = false : set = set_create_duplicate
@export var culling : int = 1

var dss : PhysicsDirectSpaceState3D
var last_trans : Transform3D
var transform_zero : Transform3D = Transform3D.IDENTITY.scaled(Vector3.ZERO)
var dirty : bool = false
var process_step : int = 0

func set_instance_separation(v : float):
	instance_separation = v if v > MIN_SEPARATION_SIZE else MIN_SEPARATION_SIZE
	call_deferred("t_update")

func set_min_scale(v : float):
	min_scale = v
	call_deferred("t_update")

func set_max_scale(v : float):
	max_scale = v
	call_deferred("t_update")

func set_lod_bias(v : float):
	lod_bias = v
	call_deferred("t_update")

func set_grassland(v : float):
	grassland = v
	call_deferred("t_update")

func set_grassland_curve(v : float):
	grassland_curve = v
	call_deferred("t_update")

func set_max_view_dist(v : float):
	max_view_dist = v
	call_deferred("t_update")

func set_randomization(v : Array[float]):
	randomization = v
	call_deferred("t_update")

func set_grass_size(s : Vector2):
	grass_size = s
	call_deferred("t_update")

func get_grass_size() -> Vector2:
	return grass_size

func set_grass_deep(v : float):
	grass_deep = v
	call_deferred("t_update")

func set_grass_division(v : int):
	grass_divisions = v
	call_deferred("t_update")

func set_grass_gravity(v : float):
	grass_gravity = v
	call_deferred("t_update")

func set_distribuition_texture(v : CompressedTexture2D):
	distribuition_texture = v
	if distribuition_texture != null:
		distribuition_texture.get_image().decompress()
	call_deferred("t_update")

func set_distribuition_texture_scale(v : float):
	distribuition_texture_scale = v
	call_deferred("t_update")

func set_material(v : ShaderMaterial):
	material = v
	call_deferred("t_update")

func set_create_duplicate(v):
	var nd : Path3D = self.duplicate()
	nd.curve = curve.duplicate()
	nd.name = nd.name + str(Time.get_unix_time_from_system())
	get_parent().add_child(nd)
	nd.owner = get_tree().edited_scene_root
	for i in range(get_child_count()):
		var m_dst : MultiMeshInstance3D = nd.get_child(i)
		var m_src : MultiMeshInstance3D = get_child(i)
		m_dst.multimesh = m_src.multimesh.duplicate()
		m_dst.owner = get_tree().edited_scene_root

func set_interpolation_method(v : Interpolation):
	interpolation_method = v
	call_deferred("t_update")

func set_interpolation_power(v : float):
	interpolation_power = v
	call_deferred("t_update")

func set_acurated_physics(v : bool):
	acurated_physics = v
	call_deferred("t_update")

func set_gravity(v : Vector3):
	gravity = v
	call_deferred("t_update")

func set_wall_distinction(v : float):
	wall_distinction = abs(v)
	call_deferred("t_update")

func set_random_inclination(v : float):
	random_inclination = v
	call_deferred("t_update")

func _ready():
	if not Engine.is_editor_hint():
		set_physics_process(false)
		set_process(false)
		return
	# event support
	connect("curve_changed", t_update)
	last_trans = global_transform
	dirty = false
	if distribuition_texture:
		distribuition_texture.get_image().decompress()


func _physics_process(_delta):
	if global_transform != last_trans:
		last_trans = global_transform
		dirty = true
	if dirty : generate_grass(get_tree().root.get_world_3d().direct_space_state)

var timer : SceneTreeTimer

func t_update():
	if lock: return
	dirty = true

func _get_culling() -> int :
	var v = 1
	for i in range(culling - 1):
		v = v << 1
	return v

func _setmentate_line(amount : int) -> Array[float]:
	match interpolation_method:
		Interpolation.Fibonacy: return _segmentate_line_fibo(amount, interpolation_power)
	return _segmentate_line_const(amount)

func _segmentate_line_const(amount : int) -> Array[float]:
	var r : Array[float] = []
	var s : float = 1. / float(amount)
	for i in range(amount): r.append(s)
	return r

func _segmentate_line_fibo(amount : int, curve_power : float) -> Array[float]:
	amount += 1
	var fibo : Array[int] = [1,1]
	var sum : int = 1
	for i in range(2, amount):
		var length : int = fibo[i - 1] + fibo[i - 2]
		fibo.append(length)
		sum += length
	var lengths : Array[float] = []
	var f_sum : float = 0
	fibo.pop_front()
	for f in fibo:
		var l : float = pow(f / float(sum), curve_power)
		lengths.append(l)
		f_sum += l
	for i in range(lengths.size()):
		lengths[i] = lengths[i] / f_sum
	#lengths.pop_front()
	return lengths

func _segmentate_line_exp(amount : int, curve_power : float) -> Array[float]:
	var ratios : Array[float] = []
	var sum : float = 0.
	for i in range(amount):
		var r : float = 1 / pow(i + 1, curve_power)
		ratios.append(r)
		sum += r
	for i in range(amount):
		ratios[i] = ratios[i] / sum
	return ratios

func _randomize_angle(v : Vector3, amount : float) -> Vector3:
	var ang : float = randf_range(-amount, amount)
	var v2 : Vector3 = Vector3(
			v.x * randf_range(-PI, PI),
			v.y * randf_range(-PI, PI),
			v.z * randf_range(-PI, PI)
		).normalized()
	var axis : Vector3 = v2.cross(v)
	return Vector3.UP # v.slerp(axis, ang)

func _vec_2_transform(d : Vector3, up : Vector3 = Vector3.UP) -> Basis:
	if d.cross(up).length_squared() == 0:
		return Basis.IDENTITY
	return Basis.IDENTITY.looking_at(d, up)
	
func _tr(dir : Vector3, up : Vector3, rot : float) -> Transform3D:
	var tr : Transform3D =  _vec_2_transform(dir, up) #.rotated(upside_norm, rotation_ang) #Transform3D.IDENTITY.looking_at(segment_dir) * base_tr
	var e : Vector3 = tr.basis.get_euler()
	e.y = rot
	tr.basis = Basis.IDENTITY.from_euler(e)
	return tr

func generate_grass(dss : PhysicsDirectSpaceState3D):
	if not has_node("instances"): return
	if $instances.mesh:
		var t = $instances.mesh
		$instances.mesh = null
	$instances.visibility_range_end = max_view_dist
	$instances.lod_bias = lod_bias
	
	var _gravity : Basis = Basis.IDENTITY if -gravity.normalized().dot(Vector3.UP) == 1.\
		else Basis.IDENTITY.looking_at(-gravity.normalized())
	
	var mesh : ArrayMesh = ArrayMesh.new()
	var curve2d : Curve2D = Curve2D.new()
	var first : Vector2 = Vector2(10000, 10000)
	var last : Vector2 = Vector2(-10000, -10000)
	for p in curve.get_baked_points():
		var v = Vector2(p.x, p.z)
		curve2d.add_point(v)
		if v.x < first.x: first.x = v.x
		if v.y < first.y: first.y = v.y
		if v.x > last.x: last.x = v.x
		if v.y > last.y: last.y = v.y
	var p : Vector2 = Vector2(0,0)
	
	# prepare
	var points : PackedVector2Array = curve2d.get_baked_points()
	var amount : int = ceil((last.x - first.x) / instance_separation) *\
		ceil((last.y - first.y) / instance_separation)
	
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	var normal_array : PackedVector3Array = []
	var uv_array : PackedVector2Array = []
	var vertex_array : PackedVector3Array = []
	var color_array : PackedColorArray = []
	var index_array : PackedInt32Array = []
	
	var division_size : Vector2 = Vector2(grass_size.x / 2., grass_size.y)
	var distribuition_image_size : Vector2 = Vector2(1,1)
	if distribuition_texture != null:
		distribuition_image_size = Vector2(distribuition_texture.get_image().get_width(), distribuition_texture.get_image().get_height())
	
	var i : int = 0
	var z : float = first.y
	var index : int = 0
	var segments : Array[float] = _setmentate_line(grass_divisions)
	var seg_index : int = 0
	var pars : PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
	var col_mask : int = _get_culling()
	var _random_inclination : float = deg_to_rad(random_inclination)
	
	while z < last.y:
		var x : float = first.x
		while x < last.x:
			var inclination : float = randf_range(-_random_inclination, _random_inclination)
			inclination = PI*.5 + inclination
			
			var rotation_ang : float = randf_range(-PI, PI)
			var pos : Vector3 = Vector3(
				x + randf_range(-instance_separation, instance_separation) * .76,
				0,
				z + randf_range(-instance_separation, instance_separation) * .76
			)
			
			# physic
			pars.from = pos * global_transform.inverse()
			pars.to = pars.from + Vector3(0,-6, 0) * global_transform.basis.inverse()
			
			var res : Dictionary = dss.intersect_ray(pars)
			if res.is_empty():
				pos = Vector3.ZERO
			else:
				pos = res.position - global_transform.origin
				pos *= global_transform.basis
				#pos *= global_transform.basis.inverse()
				if res.collider.collision_layer & col_mask == 0:
					pos = Vector3.ZERO
				
			# point
			if not Geometry2D.is_point_in_polygon(Vector2(x,z), points):
				pos = Vector3.ZERO
			
			if pos != Vector3.ZERO:
				# wall ?
				var wall_definition : float = deg_to_rad(wall_distinction)
				var up_definition : float = acos(-gravity.normalized().dot(res.normal as Vector3))
				var is_on_wall : bool = up_definition > wall_definition
				
				var closest_point : Vector3 = curve.get_closest_point(pos)
				closest_point.y = 0
				
				# grass land factor
				var l : float = min(closest_point.distance_to(Vector3(pos.x, 0, pos.y)), grassland) / grassland
				l = pow(l, grassland_curve)
				l *= randf_range(min_scale, max_scale)
				var div : Vector2 = division_size * l
				
				var upside_norm : Vector3 = -gravity.normalized()
				var base_tr : Transform3D;
				if is_on_wall:
					base_tr = _vec_2_transform(res.normal as Vector3, upside_norm)
				else:
					base_tr = Transform3D.IDENTITY
				base_tr.basis = base_tr.basis.rotated(base_tr.basis.x, inclination)
				
				# color
				var uv : Vector2 = Vector2(fmod(abs(pos.x) * distribuition_texture_scale, 1), fmod(abs(pos.z) * distribuition_texture_scale, 1))
				uv *= distribuition_image_size
				var c : Color = Color(1,1,1,1)
				if distribuition_texture != null:
					c = distribuition_texture.get_image().get_pixel(int(uv.x), int(uv.y))
				c.a = 0 # flat alpha as zero to define a non-weight interpolation
				
				var segment_dir : Vector3 = upside_norm * base_tr
				
				var tr : Transform3D = _tr(segment_dir, upside_norm, rotation_ang)
				var point : Vector3 = pos + tr * Vector3(0,-grass_deep, 0)
				var first_ratio : float = segments[0]
				var segment_count : int = 1 # first xz edge
				
				# first 2 vertices
				normal_array.append(Vector3(0, 0, 1))
				uv_array.append(Vector2(0, 1))
				color_array.append(c)
				vertex_array.append(point + (tr * Vector3(-div.x, 0, 0)))
				
				normal_array.append(Vector3(0, 0, 1))
				uv_array.append(Vector2(1, 1))
				color_array.append(c)
				vertex_array.append(point + (tr * Vector3(div.x, 0, 0)))
				
				uv = Vector2(0,1)
				index += 2
				
				for ratio in segments:
					var _ratio : float = ratio
					while ratio > 0.:
						# make a ray from current point to final position
						# if it detect a collision recalculate it
						if acurated_physics:
							var dest : Vector3 = point + (tr * Vector3(0, div.y * _ratio, 0))
							pars.from = point + global_transform.origin
							pars.to = dest + global_transform.origin
							res = dss.intersect_ray(pars)
							if not res.is_empty():
								if res.collider.collision_layer & col_mask != 0:
									pos = res.position - global_transform.origin
									var new_ratio = (pos - point).length() / div.y * ratio
									if new_ratio > MIN_SEGMENT_RATIO:
										_ratio = new_ratio
									segment_dir = segment_dir.normalized()
									segment_dir = segment_dir.reflect(res.normal as Vector3)
									segment_dir -= gravity.normalized() * grass_gravity
									
									tr = _tr(segment_dir, upside_norm, rotation_ang)
									segment_count = 1
						# realize the desired line
						uv.y -= _ratio
						
						normal_array.append(tr * Vector3(0, 0, 1))
						uv_array.append(Vector2(0, uv.y))
						color_array.append(c)
						vertex_array.append(point + (tr * Vector3(-div.x, div.y * _ratio, 0)))
						
						normal_array.append(tr * Vector3(0, 0, 1))
						uv_array.append(Vector2(1, uv.y))
						color_array.append(c)
						vertex_array.append(point + (tr * Vector3(div.x, div.y * _ratio, 0)))
						
						index += 2
						
						index_array.append(index - 4)
						index_array.append(index - 3)
						index_array.append(index - 2)

						index_array.append(index - 2)
						index_array.append(index - 3)
						index_array.append(index - 1)
						
						segment_count += 1
						
						point += (tr * Vector3(0, div.y * _ratio, 0))
						
						segment_dir += gravity.normalized() * grass_gravity
						segment_dir = segment_dir.normalized()
						tr = _tr(segment_dir, upside_norm, rotation_ang)
						
						ratio -= _ratio
				
				# adjust weights
				var weight_influence : float = 1.
				var weight_step : float = 1 / float(segment_count - 1)
				var color_index = color_array.size() - 1
				while weight_influence > 0.:
					color_array[color_index].a = weight_influence
					color_array[color_index - 1].a = weight_influence
					color_index -= 2
					weight_influence -= weight_step
				
			i += 1
			x += instance_separation
		z += instance_separation
	
	arrays[Mesh.ARRAY_VERTEX] = vertex_array
	arrays[Mesh.ARRAY_NORMAL] = normal_array
	arrays[Mesh.ARRAY_TEX_UV] = uv_array
	arrays[Mesh.ARRAY_COLOR] = color_array
	arrays[Mesh.ARRAY_INDEX] = index_array
	
	if index_array.size() > 0:
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		$instances.mesh = mesh
		mesh.surface_set_material(0, material)
	
	dirty = false
