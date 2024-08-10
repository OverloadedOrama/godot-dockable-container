class_name FloatingWindow
extends Window

signal data_changed

var window_content: Control
var _is_initialized := false
var prevent_data_erasure := false


func _init(content: Control, data := {}) -> void:
	window_content = content
	title = window_content.name
	name = window_content.name
	min_size = window_content.get_minimum_size()
	unresizable = false
	wrap_controls = true
	ready.connect(_deserialize.bind(data))


func _ready() -> void:
	set_deferred(&"size", Vector2(300, 300))
	#set_deferred(&"position", DisplayServer.window_get_size() / 2 - size / 2)
	position = DisplayServer.window_get_size() / 2 - size / 2


func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		if not window_content.get_rect().has_point(event.position) and _is_initialized:
			data_changed.emit(name, serialize())


func serialize() -> Dictionary:
	return {"size": size, "position": position}


func _deserialize(data: Dictionary) -> void:
	window_content.get_parent().remove_child(window_content)
	window_content.visible = true
	window_content.global_position = Vector2.ZERO
	add_child(window_content)
	size_changed.connect(window_size_changed)
	if not data.is_empty():
		if "position" in data:
			set_position(data["position"])
		if "size" in data:
			set_deferred(&"size", data["size"])
	_is_initialized = true


func window_size_changed() -> void:
	window_content.size = size
	window_content.position = Vector2.ZERO
	if _is_initialized:
		data_changed.emit(name, serialize())


func destroy() -> void:
	size_changed.disconnect(window_size_changed)
	queue_free()


func _exit_tree() -> void:
	if _is_initialized and !prevent_data_erasure:
		data_changed.emit(name, {})
