@tool
extends EditorPlugin	

func _enter_tree():
	var settings := EditorInterface.get_editor_settings()
	
	# Add property hints to the EditorSettings, for file picking
	var property_info = {
		"name": "global_plugins/paths",
		"type": TYPE_ARRAY,
		"hint": PROPERTY_HINT_TYPE_STRING,
		"hint_string": "%d/%d:plugin.cfg" % [TYPE_STRING, PROPERTY_HINT_GLOBAL_FILE]
	}
	settings.add_property_info(property_info)
	if !settings.has_setting("global_plugins/paths"):
		settings.set_setting("global_plugins/paths", [])
	
	var paths: Array = settings.get_setting("global_plugins/paths")
	var project_path := ProjectSettings.globalize_path("res://")
	
	# Load plugins at paths
	for path: String in paths:
		# Don't copy folders that are nested under each other
		if path.begins_with(project_path) or project_path.begins_with(path):
			prints("skipped -", path)
			continue
		
		var base_dir := path.get_base_dir()
		var base_file := path.get_file()
		
		# Check if plugin.cfg file exists
		if base_file != "plugin.cfg" or !FileAccess.file_exists(path):
			push_warning("A plugin.cfg file wasn't found at path ", path, ". Recheck EditorSettings > GlobalPlugins > paths for invalid paths.")
			continue
		
		var folder := base_dir.split("/", false)[-1]
		var base_path := base_dir.trim_suffix("/" + folder)
		
		# Check if the plugin already exists in the project
		var already_exists := FileAccess.file_exists("res://addons/" + folder + "/" + base_file)
		
		# Recursively copy the folder contents into this project
		var dirs := [folder]
		var i := 0
		while i < dirs.size():
			var dir: String = dirs[i]
			var cur_path := base_path + '/' + dir
			var local_path := project_path + "addons/" + dir
			DirAccess.make_dir_absolute(local_path)
			for file in DirAccess.get_files_at(cur_path):
				DirAccess.copy_absolute(cur_path + '/' + file, local_path + '/' + file)
			dirs.append_array( Array(DirAccess.get_directories_at(cur_path)).map(
				func(d): return dir + '/' + d) 
			)
			i += 1
		
		# The FileSystem dock doesn't properly scan new files if scanned immediately
		get_tree().process_frame.connect(
			func():
				EditorInterface.get_resource_filesystem().scan()
				# Don't override the enabled status if the plugin had already been added before
				if !already_exists:
					EditorInterface.set_plugin_enabled(folder, true)
		, CONNECT_ONE_SHOT)

func _exit_tree():
	pass
