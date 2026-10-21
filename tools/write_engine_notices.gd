extends SceneTree
## Package the runtime's own notices alongside the game's asset credits.
func _initialize() -> void:
	var output := FileAccess.open("res://_test/build/GODOT_LICENSES.txt", FileAccess.WRITE)
	if output == null:
		printerr("Cannot write engine notices")
		quit(1)
		return
	output.store_string(Engine.get_license_text() + "\n\nTHIRD-PARTY COPYRIGHT NOTICES\n")
	output.store_string(JSON.stringify(Engine.get_copyright_info(), "  "))
	var licenses := Engine.get_license_info()
	for name in licenses:
		output.store_string("\n\n" + name + "\n" + licenses[name])
	output.close()
	print("Engine license notices written")
	quit()
