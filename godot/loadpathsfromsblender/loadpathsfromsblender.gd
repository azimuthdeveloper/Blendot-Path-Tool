@tool
extends EditorPlugin

const MainPanel = preload("res://addons/loadpathsfromsblender/UI/LoadPathsUI.tscn")
var main_panel_instance
var eds = get_editor_interface().get_selection()
var selectedItemLabel: Label
var importButton: Button
var importable = false
var debugLabel : Label
var errorMessage : Label
var errorPanel : Panel
var importPanel : Panel
#
#var selectedBlenderObject: Node
#var selectedBlenderPath: String

var curveStatsLabel: Label

var inheritedBlendScene: Node3D
#var blendFile: String
var jsonFile: String
var importedPaths: Array

#@export var load_world_paths: bool setget _set_load_world_paths
#
#func _ready() -> void:
	#if Engine.is_editor_hint():
		#create_update_button()

func _enter_tree() -> void:
	main_panel_instance = MainPanel.instantiate()
	selectedItemLabel = main_panel_instance.get_node("VBoxContainer/HBoxContainer/selectedItem")

	debugLabel = main_panel_instance.get_node("VBoxContainer/debugLabel")
	errorPanel = main_panel_instance.get_node("VBoxContainer/errorPanel")
	importPanel = main_panel_instance.get_node("VBoxContainer/importPanel")
	importButton = main_panel_instance.get_node("VBoxContainer/importPanel/MarginContainer/VBoxContainer/importButton")
	# var okay = main_panel_instance.get_node("")
	
	errorMessage = main_panel_instance.get_node("VBoxContainer/errorPanel/VBoxContainer/errorMessage")
	
	curveStatsLabel = main_panel_instance.get_node("VBoxContainer/importPanel/MarginContainer/VBoxContainer/curveStats")
	
	importButton.disabled = true
	add_control_to_dock(EditorPlugin.DOCK_SLOT_RIGHT_UR, main_panel_instance)
	#eds.connect("selection_changed", Callable(self, "_update_selected_object"))
	eds.selection_changed.connect(_update_selected_object)
	importButton.pressed.connect(_import_button_pressed)
	#eds.connect("selection_changed", self, "_on_selection_changed")
	#add_inspector_plugin()
	#EditorInterface.get_editor_main_screen().add_child(main_panel_instance)
	
func _import_button_pressed() -> void:
	processInheritedBlendFile()
	#print("yay import")
	

func _exit_tree() -> void:
	remove_control_from_docks(main_panel_instance)
	
	if main_panel_instance:
		main_panel_instance.queue_free()

func _has_main_screen():
	return true


func _make_visible(visible):
	if main_panel_instance:
		main_panel_instance.visible = visible


func _get_plugin_name():
	return "Blender Path Companion"

func _get_plugin_icon():
	# Must return some kind of Texture for the icon.
	return EditorInterface.get_editor_theme().get_icon("Node", "EditorIcons")

func _set_load_world_paths(value: bool) -> void:
	load_paths()
	
func _update_selected_object():
	importable = false
	var selected = eds.get_selected_nodes()
	
	# we need to sanity check the selected items...
	print(selected.size())
	if selected.size() == 0:
		errorMessage.text = "No selected objects."
		_set_panel_visibility()
		return
		#selectedItemLabel.text = "No nodes selected"
	elif selected.size() > 1:
		errorMessage.text = "There's more than one selected object."
		_set_panel_visibility()
		return
		#selectedItemLabel.text = "More than one node selected"
	else:
		selectedItemLabel.text = selected[0].name
		importable = true
		
		var node = selected[0] as Node
		var filePath = node.scene_file_path
		print(filePath)
		var packedScene = ResourceLoader.load(filePath) as PackedScene
		if packedScene == null:
			errorMessage.text = "Selected resource doesn't have a PackedScene"
			_set_panel_visibility()
			return
		#if packedScene != null:
		print(packedScene)
		var scene = packedScene.instantiate()
		var child = scene.get_child(0)
		var childMesh = (child as MeshInstance3D).mesh.resource_path
		
		if childMesh == null:
			errorMessage.text = "Selected node is a packed scene, but doesn't have a .blend file underpinning it. The child is called %s" % [child.name]
			_set_panel_visibility()
			return;

		var originalFilePath = childMesh.replace("res://", "").split("::")[0]
		
		var directory = originalFilePath.get_base_dir()
		var filename = originalFilePath.get_file().get_basename()
		var json_path = "%s/%s/%scurves.json" % [directory, filename, filename]
		
		print(json_path)
		
		if !FileAccess.file_exists(json_path):
			errorMessage.text = "No paths .json was found at %s" % [json_path]
			_set_panel_visibility()
			return
		
		print(originalFilePath)
		errorMessage.text = ""
		
		#selectedBlenderObject = node;
		#selectedBlenderPath = originalFilePath;
		
		var fileContents = FileAccess.open(json_path, FileAccess.READ).get_as_text()
		var jsonCurvesFile = JSON.parse_string(fileContents) as Array
		
		#var inheritedBlendScene: Node3D
#var blendFile: String
#var importedPaths: Array

		inheritedBlendScene = node
		jsonFile = json_path
		importedPaths = jsonCurvesFile
		
		var curveCount = jsonCurvesFile.size()
		
		print("curve count %s" % [curveCount])
		curveStatsLabel.text = """Node name: %s
		
		Blend name: %s
		
		JSON Name: %s
		
		Curve count: %s
		""" % [node.name, originalFilePath, json_path, curveCount]
		
		_set_panel_visibility()

func processInheritedBlendFile():
	var pathContainer = inheritedBlendScene.get_node_or_null("Paths")
	if (!pathContainer):
		var pathsContainerNode = Node.new()
		pathsContainerNode.name = "Paths"
		inheritedBlendScene.add_child(pathsContainerNode)
		pathsContainerNode.owner = get_tree().edited_scene_root
		pathContainer = pathsContainerNode
	#var count
	for pathdata in importedPaths:
		print("\r\n\r\n🛣️: Processing %s path..." % [pathdata.name])
		var pathname = "%s-path" % [pathdata.name]
		
		var existingPath = pathContainer.get_node_or_null(pathname)
		if not existingPath:
			existingPath = Path3D.new()
			existingPath.name = pathname
			#existingPath = pathname
			pathContainer.add_child(existingPath)
			existingPath.owner = get_tree().edited_scene_root
		
		var curve = Curve3D.new()
		for point in pathdata.points:
			print(point)
			var in_handle = Vector3(point["leftHandle"][0], point["leftHandle"][1], point["leftHandle"][2])
			var position = Vector3(point["position"][0], point["position"][1], point["position"][2])
			var out_handle = Vector3(point["rightHandle"][0], point["rightHandle"][1], point["rightHandle"][2])
			var tilt = point["tilt"]
			
			curve.add_point(position, in_handle, out_handle)
			curve.set_point_tilt(curve.get_point_count() - 1, tilt)
			
		existingPath.curve = curve
		existingPath.position = Vector3(pathdata["location"]["x"], pathdata["location"]["z"], -pathdata["location"]["y"])
		existingPath.rotation = Vector3(pathdata["rotation"]["x"], pathdata["rotation"]["y"], pathdata["rotation"]["z"])
		existingPath.scale = Vector3(pathdata["scale"]["x"], pathdata["scale"]["y"], pathdata["scale"]["z"])
	
func _set_panel_visibility():
	print("error message length %s, contents '%s'" % [errorMessage.text.length(), errorMessage.text])
	if !errorMessage.text.is_empty():
		errorPanel.visible = true
		importButton.visible = false
		importButton.disabled = true
		importPanel.visible = false
		
		inheritedBlendScene = null
		jsonFile = ""
		
		
		#selectedBlenderObject = null
		#selectedBlenderPath = ""
		
	else:
		errorPanel.visible = false
		importButton.visible = true	
		importButton.disabled = false
		importPanel.visible = true
		
	
func load_paths() -> void:
	var edited_scene_root = get_tree().edited_scene_root
	var imported_node = edited_scene_root.get_node("Imported")

	if not imported_node:
		push_error("Cannot find 'Imported' node in the scene.")
		return

	for world in imported_node.get_children():
		if not world.has_method("get_scene_file_path"):
			push_error("Child node does not have 'get_scene_file_path' method.")
			continue

		var scene_file_path = world.get_scene_file_path()
		var scene_path = ""

		if scene_file_path.endswith(".blend"):
			scene_path = scene_file_path
		elif scene_file_path.endswith(".tscn"):
			var base_scene = load(scene_file_path)
			if base_scene == null:
				push_error("Cannot load base scene.")
				continue

			var scene_instance = base_scene.instance()
			var first_child = scene_instance.get_child(0)

			if first_child and first_child is MeshInstance3D:
				var mesh_path = first_child.mesh.resource_path
				mesh_path = mesh_path.substr(0, mesh_path.find("::"))
				scene_path = mesh_path

			scene_instance.queue_free()

			if not scene_path.endswith(".blend"):
				push_error("Base scene isn't a blend file.")
				continue
		else:
			push_error("Cannot process scene file path: %s" % scene_file_path)
			continue

		process_scene_path(world, scene_path)

func process_scene_path(world: Node, scene_path: String) -> void:
	var blender_path = scene_path.replace("res://", "")
	var directory = blender_path.get_base_dir()
	var filename = blender_path.get_file().get_basename()
	#var json_path = "%s/%s/%scurves.json".format(directory, filename, filename)
	var json_path = "%s/%s/%scurves.json" % [directory, filename, filename]

	if not world.has_node("Paths"):
		var paths_node = Node.new()
		paths_node.name = "Paths"
		world.add_child(paths_node)
		paths_node.owner = get_tree().edited_scene_root

	var paths_parent = world.get_node("Paths")
	if not FileAccess.file_exists(json_path):
		push_error("JSON path does not exist: %s" % json_path)
		return

	var json_file = FileAccess.open(json_path, FileAccess.READ)
	var json_content = json_file.get_as_text()
	json_file.close()

	var json = JSON.new()

	var path_infos = json.parse(json_content)
	for path_info in path_infos:
		create_or_update_path(paths_parent, path_info)

func create_or_update_path(parent: Node, path_info: Dictionary) -> void:
	var path_name = "%s-path" % path_info["name"]
	var existing_path = parent.get_node_or_null(path_name)

	if not existing_path:
		existing_path = Path3D.new()
		existing_path.name = path_name
		parent.add_child(existing_path)
		existing_path.owner = get_tree().edited_scene_root

	var curve = Curve3D.new()
	for point in path_info["points"]:
		var in_handle = Vector3(point["left_handle"][0], point["left_handle"][1], point["left_handle"][2])
		var position = Vector3(point["position"][0], point["position"][1], point["position"][2])
		var out_handle = Vector3(point["right_handle"][0], point["right_handle"][1], point["right_handle"][2])
		var tilt = point["tilt"]

		curve.add_point(position, in_handle, out_handle)
		curve.set_point_tilt(curve.get_point_count() - 1, tilt)

	existing_path.curve = curve
	existing_path.position = Vector3(path_info["location"]["x"], path_info["location"]["z"], -path_info["location"]["y"])
	existing_path.rotation = Vector3(path_info["rotation"]["x"], path_info["rotation"]["y"], path_info["rotation"]["z"])
	existing_path.scale = Vector3(path_info["scale"]["x"], path_info["scale"]["y"], path_info["scale"]["z"])

	print("Path '%s' processed successfully." % path_name)
