tool
extends Control

const Layout = preload("res://addons/dockable_container/layout.gd")

const SPLIT_THEME_CLASS = [
	"HSplitContainer",  # SPLIT_THEME_CLASS[LayoutSplit.Direction.HORIZONTAL]
	"VSplitContainer",  # SPLIT_THEME_CLASS[LayoutSplit.Direction.VERTICAL]
]

const SPLIT_MOUSE_CURSOR_SHAPE = [
	Control.CURSOR_HSPLIT,  # SPLIT_MOUSE_CURSOR_SHAPE[LayoutSplit.Direction.HORIZONTAL]
	Control.CURSOR_VSPLIT,  # SPLIT_MOUSE_CURSOR_SHAPE[LayoutSplit.Direction.VERTICAL]
]

var split_tree: Layout.LayoutSplit setget set_split_tree, get_split_tree

var _parent_rect
var _split_tree: Layout.LayoutSplit
var _mouse_hovering = false
var _dragging = false


func _draw() -> void:
	var theme_class = SPLIT_THEME_CLASS[_split_tree.direction]
	var icon = get_icon("grabber", theme_class)
	var autohide = bool(get_constant("autohide", theme_class))
	if not icon or (autohide and not _mouse_hovering):
		return
	
	draw_texture(icon, (rect_size - icon.get_size()) * 0.5 )


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT:
		_dragging = event.is_pressed()
	elif Engine.editor_hint and event is InputEventMouseButton and event.button_index == BUTTON_RIGHT and not event.is_pressed():
		_split_tree.percent = 0.5
	elif event is InputEventMouseMotion and _dragging:
		var mouse_in_parent = get_parent_control().get_local_mouse_position()
		if _split_tree.is_horizontal():
			_split_tree.percent = (mouse_in_parent.x - _parent_rect.position.x) / _parent_rect.size.x
		else:
			_split_tree.percent = (mouse_in_parent.y - _parent_rect.position.y) / _parent_rect.size.y


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		_mouse_hovering = true
		set_split_cursor(true)
		if bool(get_constant("autohide", SPLIT_THEME_CLASS[_split_tree.direction])):
			update()
	elif what == NOTIFICATION_MOUSE_EXIT:
		_mouse_hovering = false
		set_split_cursor(false)
		if bool(get_constant("autohide", SPLIT_THEME_CLASS[_split_tree.direction])):
			update()
	elif what == NOTIFICATION_FOCUS_EXIT:
		_dragging = false


func set_split_tree(value: Layout.LayoutSplit):
	_split_tree = value


func get_split_tree() -> Layout.LayoutSplit:
	return _split_tree


func set_split_cursor(value: bool) -> void:
	if value:
		mouse_default_cursor_shape = SPLIT_MOUSE_CURSOR_SHAPE[_split_tree.direction]
	else:
		mouse_default_cursor_shape = CURSOR_ARROW


func get_split_rects(rect: Rect2) -> Dictionary:
	_parent_rect = rect
	var hseparation = get_constant("separation", "HSplitContainer")
	var vseparation = get_constant("separation", "VSplitContainer")
	var separation = hseparation if _split_tree.is_horizontal() else vseparation
	var origin = rect.position
	var size = rect.size
	var percent = _split_tree.percent
	var first_minimum_size = _split_tree.first.get_minimum_size(hseparation, vseparation)
	var second_minimum_size = _split_tree.second.get_minimum_size(hseparation, vseparation)
	if _split_tree.is_horizontal():
		var first_width = max((size.x - separation) * percent, first_minimum_size.x)
		var split_offset = clamp(size.x * percent - separation * 0.5, first_minimum_size.x, size.x - second_minimum_size.x - separation)
		var second_width = size.x - split_offset - separation
		
		return {
			"first": Rect2(origin.x, origin.y, split_offset, size.y),
			"self": Rect2(origin.x + split_offset, origin.y, separation, size.y),
			"second": Rect2(origin.x + split_offset + separation, origin.y, second_width, size.y),
		}
	else:
		var first_height = max((size.y - separation) * percent, first_minimum_size.y)
		var split_offset = clamp(size.y * percent - separation * 0.5, first_minimum_size.y, size.y - second_minimum_size.y - separation)
		var second_height = size.y - split_offset - separation
		
		return {
			"first": Rect2(origin.x, origin.y, size.x, split_offset),
			"self": Rect2(origin.x, origin.y + split_offset, size.x, separation),
			"second": Rect2(origin.x, origin.y + split_offset + separation, size.x, second_height),
		}
