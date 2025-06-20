extends Node2D
class_name SortingNode

var target: Node2D
var base_offset: int = 0

func setup(target_node: Node2D, offset: int):
	target = target_node
	base_offset = offset
	target.y_sort_enabled = true

func update_position(char_global_pos: Vector2):
	if target:
		target.z_index = int(char_global_pos.y + base_offset)
