class_name RoomFactory
extends RefCounted

enum WALL_ANGLE { TOP_LEFT, TOP_RIGHT, BOTTOM_LEFT, BOTTOM_RIGHT }
enum WALL_SIDE { UP = 0, RIGHT = 2, BOTTOM = 0, LEFT = 1 }

var tile_config: TileConfig
var floor_layer: TileMapLayer
var wall_layer: TileMapLayer
var door_layer: TileMapLayer
var object_layer: TileMapLayer
var max_room_radius: int
var corridor_length: int

func _init(config: TileConfig, floor: TileMapLayer, wall: TileMapLayer, 
		  door: TileMapLayer, object: TileMapLayer, max_radius: int, corridor_len: int):
	self.tile_config = config
	self.floor_layer = floor
	self.wall_layer = wall
	self.door_layer = door
	self.object_layer = object
	self.max_room_radius = max_radius
	self.corridor_length = corridor_len

func create_room(center: Vector2i, radius: int, connections: Dictionary) -> void:
	_generate_floor(center, radius)
	_generate_walls(center, radius, connections)

func _generate_floor(center: Vector2i, radius: int):
	for x in range(center.x - radius, center.x + radius + 1):
		for y in range(center.y - radius, center.y + radius + 1):
			floor_layer.set_cell(
				Vector2i(x, y),
				0,
				tile_config.get_random_floor(),
				0
			)

func _generate_walls(center: Vector2i, radius: int, connections: Dictionary):
	# Основные стены
	for x in range(center.x - radius - 1, center.x + radius + 2):
		_place_wall_tile(Vector2i(x, center.y - radius - 1), WALL_SIDE.UP, connections.get("up", false))
		_place_wall_tile(Vector2i(x, center.y + radius + 1), WALL_SIDE.BOTTOM, connections.get("down", false))
	
	for y in range(center.y - radius, center.y + radius + 1):
		_place_wall_tile(Vector2i(center.x - radius - 1, y), WALL_SIDE.LEFT, connections.get("left", false))
		_place_wall_tile(Vector2i(center.x + radius + 1, y), WALL_SIDE.RIGHT, connections.get("right", false))
	
	# Углы
	_place_corner(center + Vector2i(-radius - 1, -radius - 1), WALL_ANGLE.TOP_LEFT)
	_place_corner(center + Vector2i(radius + 1, -radius - 1), WALL_ANGLE.TOP_RIGHT)
	_place_corner(center + Vector2i(radius + 1, radius + 1), WALL_ANGLE.BOTTOM_RIGHT)
	_place_corner(center + Vector2i(-radius - 1, radius + 1), WALL_ANGLE.BOTTOM_LEFT)
	
	# Внутренние углы для дверей
	_place_inner_corners(center, radius, connections)

func _place_inner_corners(center: Vector2i, radius: int, connections: Dictionary):
	if connections.get("up", false):
		var door_pos = Vector2i(center.x, center.y - radius - 1)
		wall_layer.set_cell(door_pos + Vector2i(-1, 0), 0, tile_config.Wall.InnerCorner.TOP, 1) # Левый внутренний угол
		wall_layer.set_cell(door_pos + Vector2i(1, 0), 0, tile_config.Wall.InnerCorner.TOP, 0) # Правый внутренний угол
	
	if connections.get("down", false):
		var door_pos = Vector2i(center.x, center.y + radius + 1)
		wall_layer.set_cell(door_pos + Vector2i(-1, 0), 0, tile_config.Wall.InnerCorner.BOTTOM, 1) # Левый внутренний угол
		wall_layer.set_cell(door_pos + Vector2i(1, 0), 0, tile_config.Wall.InnerCorner.BOTTOM, 0) # Правый внутренний угол
	
	if connections.get("left", false):
		var door_pos = Vector2i(center.x - radius - 1, center.y)
		wall_layer.set_cell(door_pos + Vector2i(0, -1), 0, tile_config.Wall.InnerCorner.TOP, 0)
		wall_layer.set_cell(door_pos + Vector2i(0, 1), 0, tile_config.Wall.InnerCorner.BOTTOM, 0)
	
	if connections.get("right", false):
		var door_pos = Vector2i(center.x + radius + 1, center.y)
		wall_layer.set_cell(door_pos + Vector2i(0, -1), 0, tile_config.Wall.InnerCorner.TOP, 1)
		wall_layer.set_cell(door_pos + Vector2i(0, 1), 0, tile_config.Wall.InnerCorner.BOTTOM, 1)

func _place_wall_tile(pos: Vector2i, side: int, has_door: bool):
	if has_door && _is_door_position(pos, side):
		_place_door(pos, side)
	else:
		match side:
			WALL_SIDE.UP, WALL_SIDE.BOTTOM:
				wall_layer.set_cell(pos, 0, tile_config.Wall.VERTICAL, 0)
			WALL_SIDE.LEFT:
				wall_layer.set_cell(pos, 0, tile_config.Wall.HORIZONTAL, 0)
			WALL_SIDE.RIGHT:
				wall_layer.set_cell(pos, 0, tile_config.Wall.HORIZONTAL, 1)

func _is_door_position(pos: Vector2i, side: int) -> bool:
	var spacing = max_room_radius * 2 + corridor_length
	match side:
		WALL_SIDE.UP, WALL_SIDE.BOTTOM:
			return pos.x % spacing == 0
		WALL_SIDE.LEFT, WALL_SIDE.RIGHT:
			return pos.y % spacing == 0
	return false

func _place_door(pos: Vector2i, side: int):
	var tile_data = tile_config.Door.get_tile(side)
	door_layer.set_cell(pos, 0, tile_data.tile, tile_data.alt)

func _place_corner(pos: Vector2i, angle: int):
	match angle:
		WALL_ANGLE.TOP_LEFT:
			wall_layer.set_cell(pos, 0, tile_config.Wall.TOP_CORNER, 0) # Левый верх
		WALL_ANGLE.TOP_RIGHT:
			wall_layer.set_cell(pos, 0, tile_config.Wall.TOP_CORNER, 1) # Правый верх
		WALL_ANGLE.BOTTOM_LEFT:
			wall_layer.set_cell(pos, 0, tile_config.Wall.BOTTOM_CORNER, 0) # Левый низ
		WALL_ANGLE.BOTTOM_RIGHT:
			wall_layer.set_cell(pos, 0, tile_config.Wall.BOTTOM_CORNER, 1) # Правый низ
