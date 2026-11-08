extends RefCounted
class_name OptionalAssetLoader

## Optional external model loader. The project remains fully playable when no
## external assets are installed; procedural fallbacks are supplied by callers.

const ENVIRONMENT_ROOT: String = "res://assets/environment"
const CHARACTER_ROOT: String = "res://assets/characters"


static func find_environment_model(asset_key: String) -> String:
	var files: Array[String] = []
	_collect_model_files(ENVIRONMENT_ROOT, files)
	files.sort()

	var key: String = asset_key.to_lower()
	for path in files:
		var filename: String = path.get_file().to_lower()
		if _filename_matches_key(filename, key):
			if ResourceLoader.exists(path):
				return path

	return ""


static func find_character_model() -> String:
	var candidates: Array[String] = [
		CHARACTER_ROOT + "/player.glb",
		CHARACTER_ROOT + "/player.gltf",
		CHARACTER_ROOT + "/player.fbx"
	]
	for path in candidates:
		if ResourceLoader.exists(path):
			return path
	return ""


static func instantiate_scene_file(path: String) -> Node3D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null

	var resource: Resource = ResourceLoader.load(path)
	if not (resource is PackedScene):
		return null

	var instance: Node = (resource as PackedScene).instantiate()
	if instance is Node3D:
		return instance as Node3D

	instance.free()
	return null


static func instantiate_environment_model(asset_key: String) -> Node3D:
	var path: String = find_environment_model(asset_key)
	return instantiate_scene_file(path)


static func fit_model_to_size(model: Node3D, target_size: Vector3, preserve_aspect: bool = true) -> void:
	if model == null:
		return

	var bounds_list: Array[AABB] = []
	_collect_mesh_bounds(model, Transform3D.IDENTITY, bounds_list)
	if bounds_list.is_empty():
		return

	var combined: AABB = bounds_list[0]
	for index in range(1, bounds_list.size()):
		combined = combined.merge(bounds_list[index])

	var source_size: Vector3 = combined.size
	if source_size.x <= 0.001 or source_size.z <= 0.001:
		return
	# Flat floor modules may have effectively zero thickness. Give that axis a
	# tiny safe denominator so X/Z still fit and the imported surface stays flat.
	var safe_source_size := Vector3(
		maxf(source_size.x, 0.001),
		maxf(source_size.y, 0.001),
		maxf(source_size.z, 0.001)
	)

	# Uniform fit avoids distorting a Quaternius mesh unless callers explicitly
	# request a modular wall/floor panel to fit a slot.
	var sx: float = target_size.x / safe_source_size.x
	var sy: float = target_size.y / safe_source_size.y
	var sz: float = target_size.z / safe_source_size.z
	var fit_scale: Vector3 = Vector3.ONE * minf(sx, minf(sy, sz))
	if not preserve_aspect:
		fit_scale = Vector3(sx, sy, sz)
	model.scale = fit_scale
	model.position = -(combined.get_center() * fit_scale)


static func _collect_mesh_bounds(
	node: Node,
	parent_transform: Transform3D,
	results: Array[AABB]
) -> void:
	var current_transform: Transform3D = parent_transform
	if node is Node3D:
		current_transform = parent_transform * (node as Node3D).transform

	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.mesh != null:
			results.append(current_transform * mesh_instance.mesh.get_aabb())

	for child in node.get_children():
		_collect_mesh_bounds(child, current_transform, results)


static func _collect_model_files(folder: String, results: Array[String]) -> void:
	var directory: DirAccess = DirAccess.open(folder)
	if directory == null:
		return

	for filename in directory.get_files():
		var lower: String = filename.to_lower()
		if lower.ends_with(".glb") or lower.ends_with(".gltf") or lower.ends_with(".fbx"):
			results.append(folder.path_join(filename))

	for child_folder in directory.get_directories():
		_collect_model_files(folder.path_join(child_folder), results)


static func _filename_matches_key(filename: String, key: String) -> bool:
	match key:
		"wall":
			return filename.contains("wall") or filename.contains("bulkhead")
		"floor":
			return filename.contains("floor") or filename.contains("deck") or filename.contains("ground")
		"door":
			return filename.contains("door") or filename.contains("hatch")
		"console":
			return filename.contains("console") or filename.contains("terminal") or filename.contains("computer")
		"crate":
			return filename.contains("crate") or filename.contains("container") or filename.contains("box")
		"pod":
			return filename.contains("pod") or filename.contains("capsule") or filename.contains("escape")
		_:
			return filename.contains(key)
