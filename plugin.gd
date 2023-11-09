# Author: Sheshire | MIT Licensed.
@tool
extends EditorPlugin


# Properties

var control_box: HBoxContainer



# Public Functions

func move_up() -> void:
	var nodes := _get_selected_nodes()

	get_undo_redo().create_action("move node up")

	for parent in nodes:
		_move_up(nodes[parent], parent)

	get_undo_redo().commit_action()


func move_down() -> void:
	var nodes := _get_selected_nodes()

	get_undo_redo().create_action("move node down")

	for parent in nodes:
		_move_down(nodes[parent], parent)

	get_undo_redo().commit_action()


func move_out() -> void:
	var nodes := _get_selected_nodes()

	get_undo_redo().create_action("move nodes out")

	for i in nodes:
		if i.owner == i or i.owner == null:
			continue
		_move_out(nodes[i], i)

	get_undo_redo().commit_action()


func move_in() -> void:
	var nodes = _get_selected_nodes()

	get_undo_redo().create_action("move nodes in")

	for i in nodes:
		_move_in(nodes[i], i)

	get_undo_redo().commit_action()


# Logic

func _enter_tree() -> void:
	control_box = HBoxContainer.new()
	var up = Button.new()
	var down = Button.new()
	var right = Button.new()
	var left = Button.new()

	up.text = "↑"
	down.text = "↓"
	right.text = "→"
	left.text = "←"

	up.pressed.connect(move_up)
	down.pressed.connect(move_down)
	left.pressed.connect(move_out)
	right.pressed.connect(move_in)

	control_box.add_child(up)
	control_box.add_child(down)
	control_box.add_child(left)
	control_box.add_child(right)

	var base := get_editor_interface().get_base_control()
	var scene_tree = base.find_children("Scene","VBoxContainer", true, false)
	scene_tree[0].add_child(control_box)


func _exit_tree() -> void:
	control_box.queue_free()



# ==================================
# Private Section
# ==================================

func _get_selected_nodes() -> Dictionary:
	var result := {}
	var selection := get_editor_interface().get_selection()
	var selected_nodes := selection.get_transformable_selected_nodes()

	for node in selected_nodes:
		var parent = node.get_parent()
		if not parent in result:
			var nodes : Array[Node] = []
			result[parent] = nodes
		result[parent].append(node)

	for node in selection.get_selected_nodes():
		selection.call_deferred("add_node", node)

	return result


func _move_up(nodes: Array[Node], parent: Node) -> void:
	var node_positions = {}
	for i in nodes:
		node_positions[i.get_index()] = i
	var order = node_positions.keys()
	order.sort()
	var offset := 0

	for i in order:
		var node = node_positions[i]
		var pos = max(i -1, offset)
		offset += 1

		get_undo_redo().add_do_method(parent, "move_child", node, pos)
		get_undo_redo().add_undo_method(parent, "move_child", node, i)


func _move_down(nodes: Array[Node], parent: Node) -> void:
	var node_positions = {}
	for i in nodes:
		node_positions[i.get_index()] = i
	var order = node_positions.keys()
	order.sort()
	order.reverse()
	var offset := 0

	for i in order:
		var node = node_positions[i]
		var pos = min(i +1, parent.get_child_count() - 1 - offset)
		offset += 1

		get_undo_redo().add_do_method(parent, "move_child", node, pos)
		get_undo_redo().add_undo_method(parent, "move_child", node, i)


func _move_out(nodes: Array[Node], parent: Node) -> void:
	var offset := 1
	var grandparent := parent.get_parent()
	var index = parent.get_index()
	var node_positions = {}

	for i in nodes:
		node_positions[i.get_index()] = i
	var order = node_positions.keys()
	order.sort()

	for i in order:
		var node: Node = node_positions[i]
		var from_index := node.get_index()
		var owner := node.owner
		var node_data := _get_node_data(node)

		get_undo_redo().add_do_method(node, "reparent", grandparent)
		get_undo_redo().add_do_method(grandparent, "move_child", node, index + offset)
		get_undo_redo().add_do_method(self, "_set_node_data", node, node_data)
		get_undo_redo().add_undo_method(node, "reparent", parent)
		get_undo_redo().add_undo_method(parent, "move_child", node, from_index)
		get_undo_redo().add_undo_method(self, "_set_node_data", node, node_data)

		offset += 1


func _move_in(nodes: Array[Node], parent: Node) -> void:
	var offset := 1
	var node_positions = {}

	for i in nodes:
		node_positions[i.get_index()] = i
	var order = node_positions.keys()
	order.sort()

	for i in order:
		var node: Node = node_positions[i]
		if node.owner == null:
			continue
		var from_index: int = node.get_index()
		var target : Node
		var owner := node.owner
		var node_data := _get_node_data(node)

		if from_index == 0:
			if node is Control:
				target = Control.new()
			elif node is Node2D:
				target = Node2D.new()
			elif node is Node3D:
				target = Node3D.new()
			else:
				target = Node.new()
			get_undo_redo().add_undo_method(parent, "remove_child", target)
			get_undo_redo().add_do_reference(target)
			get_undo_redo().add_do_method(parent, "add_child", target, true)
			get_undo_redo().add_do_property(target, "owner", owner)
			get_undo_redo().add_do_method(parent, "move_child", target, 0)
		else:
			target = parent.get_child(from_index - 1)


		get_undo_redo().add_do_method(node, "reparent", target)
		get_undo_redo().add_do_method(self, "_set_node_data", node, node_data)
		get_undo_redo().add_undo_method(node, "reparent", parent)
		get_undo_redo().add_undo_method(self, "_set_node_data", node, node_data)
		get_undo_redo().add_undo_method(parent, "move_child", node, from_index)


func _get_node_data(node: Node, data: Dictionary = {}) -> Dictionary:
	var node_data := {}
	node_data.owner = node.owner
	node_data.name = node.name

	data[node] = node_data

	for i in node.get_children():
		_get_node_data(i, data)

	return data


func _set_node_data(node: Node, data: Dictionary) -> void:
	var node_data = data[node]
	node.owner = node_data.owner
	node.name = node_data.name

	for i in node.get_children():
		_set_node_data(i, data)
