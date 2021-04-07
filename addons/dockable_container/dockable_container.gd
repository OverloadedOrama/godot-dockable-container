tool
extends Container

signal layout_changed()

const SplitHandle = preload("res://addons/dockable_container/split_handle.gd")
const DockablePanel = preload("res://addons/dockable_container/dockable_panel.gd")
const DragNDropPanel = preload("res://addons/dockable_container/drag_n_drop_panel.gd")
const Layout = preload("res://addons/dockable_container/layout.gd")
const LayoutRoot = preload("res://addons/dockable_container/layout_root.gd")

export(int, "Left", "Center", "Right") var tab_align = TabContainer.ALIGN_CENTER
export(int) var rearrange_group = 0
export(Resource) var layout setget set_layout_root_node, get_layout_root_node

var _layout_root_node
var _layout_root = LayoutRoot.new()
var _panel_container = Container.new()
var _split_container = Container.new()
var _drag_n_drop_panel = DragNDropPanel.new()
var _drag_panel: DockablePanel
var _current_panel_index = 0
var _current_split_index = 0
var _last_sort_child_count = 0


func _ready() -> void:
	set_process_input(false)
	add_child(_panel_container)
	move_child(_panel_container, 0)
	_panel_container.add_child(_split_container)
	_split_container.mouse_filter = MOUSE_FILTER_PASS
	
	_drag_n_drop_panel.mouse_filter = MOUSE_FILTER_PASS
	_drag_n_drop_panel.set_drag_forwarding(self)
	_drag_n_drop_panel.visible = false
	add_child(_drag_n_drop_panel)
	
	if Engine.editor_hint:
		yield(get_tree(), "idle_frame")
	set_layout_root_node(_layout_root_node)
	_layout_root.connect("changed", self, "queue_sort")


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		_resort()
	elif what == NOTIFICATION_DRAG_BEGIN:
		_drag_n_drop_panel.visible = true
		set_process_input(true)
	elif what == NOTIFICATION_DRAG_END:
		_drag_n_drop_panel.visible = false
		set_process_input(false)


func _input(event: InputEvent) -> void:
	assert(get_viewport().gui_is_dragging(), "FIXME: should only be called when dragging")
	if event is InputEventMouseMotion:
		var panel
		for i in range(1, _panel_container.get_child_count()):
			var p = _panel_container.get_child(i)
			if p.get_rect().has_point(event.position):
				panel = p
				break
		_drag_panel = panel
		if not panel:
			return
		fit_child_in_rect(_drag_n_drop_panel, panel.get_child_rect())


func set_layout_root_node(value: Layout.LayoutNode) -> void:
	if value == null:
		_layout_root_node = Layout.LayoutPanel.new()
	else:
		_layout_root_node = value
	_layout_root.root = _layout_root_node
	_update_tree_indices()


func get_layout_root_node() -> Layout.LayoutNode:
	if Engine.editor_hint:
		return _layout_root_node
	else:
		return _layout_root.root


func can_drop_data_fw(position: Vector2, data, from_control) -> bool:
	return from_control == _drag_n_drop_panel and data is Dictionary and data.get("type") == "tabc_element"


func drop_data_fw(position: Vector2, data, from_control) -> void:
	assert(from_control == _drag_n_drop_panel, "FIXME")
	
	var from_node: DockablePanel = get_node(data.from_path)
	if _drag_panel == null or (from_node == _drag_panel and _drag_panel.get_child_count() == 1):
		return
	
	var moved_tab = from_node.get_tab_control(data.tabc_element)
	var moved_reference = moved_tab.reference_to
	var moved_parent_index = moved_reference.get_position_in_parent()
	
	var margin = _drag_n_drop_panel.get_hover_margin()
	_layout_root.split_leaf_with_node(_drag_panel.leaf, moved_parent_index, margin)
	
	emit_signal("layout_changed")
	queue_sort()


func set_control_as_current_tab(control: Control) -> void:
	assert(control.get_parent_control() == self, "Trying to focus a control not managed by this container")
	var position_in_parent = control.get_position_in_parent()
	var leaf = _layout_root.get_leaf_for_node(position_in_parent)
	if not leaf:
		return
	var position_in_leaf = leaf.find_node(position_in_parent)
	if position_in_leaf < 0:
		return
	var panel
	for i in range(1, _panel_container.get_child_count()):
		var p = _panel_container.get_child(i)
		if p.leaf == leaf:
			panel = p
			break
	if not panel:
		return
	panel.current_tab = position_in_leaf


func _update_tree_indices() -> void:
	var indices = PoolIntArray()
	for i in range(1, get_child_count() - 1):
		var c = get_child(i)
		if c is Control and not c.is_set_as_toplevel():
			indices.append(i)
	_layout_root.update_indices(indices)
	queue_sort()


func _resort() -> void:
	assert(_panel_container, "FIXME: resorting without _panel_container")
	assert(_panel_container.get_position_in_parent() == 0, "FIXME: _panel_container is not first child")
	if _drag_n_drop_panel.get_position_in_parent() < get_child_count() - 1:
		_drag_n_drop_panel.raise()
	
	if get_child_count() != _last_sort_child_count:
		_last_sort_child_count = get_child_count()
		_update_tree_indices()
	
	var rect = Rect2(Vector2.ZERO, rect_size)
	fit_child_in_rect(_panel_container, rect)
	_panel_container.fit_child_in_rect(_split_container, rect)
	
	_current_panel_index = 1
	_current_split_index = 0
	_set_tree_or_leaf_rect(_layout_root.root, rect)
	_untrack_children_after(_panel_container, _current_panel_index)
	_untrack_children_after(_split_container, _current_split_index)


func _set_tree_or_leaf_rect(tree_or_leaf: Layout.LayoutNode, rect: Rect2) -> void:
	if tree_or_leaf is Layout.LayoutSplit:
		var split = _get_split(_current_split_index)
		split.split_tree = tree_or_leaf
		_current_split_index += 1
		var split_rects = split.get_split_rects(rect)
		_split_container.fit_child_in_rect(split, split_rects.self)
		_set_tree_or_leaf_rect(tree_or_leaf.first, split_rects.first)
		_set_tree_or_leaf_rect(tree_or_leaf.second, split_rects.second)
	elif tree_or_leaf is Layout.LayoutPanel:
		var panel = _get_panel(_current_panel_index)
		_current_panel_index += 1
		var nodes = []
		for n in tree_or_leaf.nodes:
			nodes.append(get_child(n))
		panel.track_nodes(nodes, tree_or_leaf)
		_panel_container.fit_child_in_rect(panel, rect)
	else:
		assert(false, "Invalid Resource, should be branch or leaf, found %s" % tree_or_leaf)


func _get_panel(idx: int) -> DockablePanel:
	assert(_panel_container, "FIXME: creating panel without _panel_container")
	if idx < _panel_container.get_child_count():
		return _panel_container.get_child(idx)
	var panel = DockablePanel.new()
	panel.tab_align = tab_align
	panel.set_tabs_rearrange_group(max(0, rearrange_group))
	_panel_container.add_child(panel)
	panel.connect("control_moved", self, "_on_reference_control_moved")
	return panel


func _get_split(idx: int) -> SplitHandle:
	assert(_split_container, "FIXME: creating split without _split_container")
	if idx < _split_container.get_child_count():
		return _split_container.get_child(idx)
	var split = SplitHandle.new()
	_split_container.add_child(split)
	return split


static func _untrack_children_after(node, idx: int) -> void:
	for i in range(idx, node.get_child_count()):
		var child = node.get_child(idx)
		node.remove_child(child)
		child.queue_free()


func _on_reference_control_moved(control: Control) -> void:
	var panel = control.get_parent_control()
	assert(panel is DockablePanel, "FIXME: reference control was moved to something other than DockableContainerPanel")
	
	if panel.get_child_count() <= 1:
		return
	
	var position_in_parent = control.reference_to.get_position_in_parent()
	var relative_position_in_leaf = control.get_position_in_parent()
	_layout_root.move_node_to_leaf(position_in_parent, panel.leaf, relative_position_in_leaf)
	
	emit_signal("layout_changed")
	queue_sort()
