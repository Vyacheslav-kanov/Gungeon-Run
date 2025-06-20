extends Node2D
class_name LevelGenerator

# Конфигурация генерации
@export_category("Настройки уровня")
@export var grid_size := Vector2i(3, 3)
@export var min_room_radius := 2
@export var max_room_radius := 3
@export var corridor_length := 6

# Ссылки на слои TileMapLayer
@onready var floor_layer: TileMapLayer = $FloorLayer
@onready var wall_layer: TileMapLayer = $WallLayer
@onready var door_layer: TileMapLayer = $DoorLayer
@onready var object_layer: TileMapLayer = $ObjectLayer

# Зависимости
var tile_config: TileConfig
var room_factory: RoomFactory

# Состояние генератора
var rooms: Array = []
var room_grid: Array = []
var start_room: Vector2i
var end_room: Vector2i
var maze: Array = []

func _ready():
	tile_config = TileConfig.new()
	room_factory = RoomFactory.new(
		tile_config,
		floor_layer,
		wall_layer,
		door_layer,
		object_layer,
		max_room_radius,
		corridor_length
	)
	generate_level()

func generate_level():
	_clear_layers()
	maze = _generate_simple_maze(grid_size.x, grid_size.y)  # Простой гарантированно работающий алгоритм
	_create_rooms(maze)
	_generate_corridors(maze)
	_place_special_rooms()
	print("Уровень успешно сгенерирован")  # Для отладки

func _clear_layers():
	floor_layer.clear()
	wall_layer.clear()
	door_layer.clear()
	if object_layer:
		object_layer.clear()
	rooms.clear()
	room_grid.clear()
	maze.clear()

func _generate_simple_maze(width: int, height: int) -> Array:
	var maze = []
	# Инициализация пустого лабиринта
	for y in range(height):
		maze.append([])
		for _x in range(width):
			maze[y].append(0)
	
	# Гарантированно соединяем все комнаты
	for y in range(height):
		for x in range(width):
			# Соединяем с правым соседом, если он есть
			if x < width - 1:
				maze[y][x] |= 1  # Right
				maze[y][x+1] |= 4 # Left
			# Соединяем с нижним соседом, если он есть
			if y < height - 1:
				maze[y][x] |= 2  # Down
				maze[y+1][x] |= 8 # Up
	
	# Убираем некоторые соединения для разнообразия (но оставляем связным)
	for y in range(height):
		for x in range(width):
			if x < width - 1 and y < height - 1:
				if randi() % 3 == 0:  # 33% chance to remove horizontal
					maze[y][x] &= ~1
					maze[y][x+1] &= ~4
				elif randi() % 3 == 0:  # 33% chance to remove vertical
					maze[y][x] &= ~2
					maze[y+1][x] &= ~8
	
	return maze

func _find_unvisited_neighbors(pos: Vector2i, width: int, height: int, visited: Array[Vector2i]) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	for dir in [
		Vector2i(1, 0), Vector2i(0, 1), 
		Vector2i(-1, 0), Vector2i(0, -1)
	]:
		var nx: int = pos.x + dir.x
		var ny: int = pos.y + dir.y
		if 0 <= nx and nx < width and 0 <= ny and ny < height:
			if not Vector2i(nx, ny) in visited:
				neighbors.append(dir)
	return neighbors

func _create_rooms(maze: Array):
	var spacing = (max_room_radius * 2) + corridor_length
	room_grid.resize(grid_size.y)
	
	# Сначала создаем все комнаты
	for y in range(grid_size.y):
		room_grid[y] = []
		for x in range(grid_size.x):
			var center = Vector2i(x * spacing, y * spacing)
			var radius = randi_range(min_room_radius, max_room_radius)
			room_grid[y].append({
				"center": center,
				"radius": radius,
				"connections": {
					"up": false,
					"right": false,
					"down": false,
					"left": false
				}
			})
	
	# Затем добавляем соединения на основе лабиринта
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			if x < grid_size.x - 1 and (maze[y][x] & 1 != 0):
				room_grid[y][x].connections.right = true
				room_grid[y][x+1].connections.left = true
			
			if y < grid_size.y - 1 and (maze[y][x] & 2 != 0):
				room_grid[y][x].connections.down = true
				room_grid[y+1][x].connections.up = true
	
	# Генерируем комнаты с дверями
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var room = room_grid[y][x]
			room_factory.create_room(
				room.center, 
				room.radius, 
				room.connections
			)
			rooms.append(room.center)

func _generate_corridors(maze: Array):
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			if x < grid_size.x - 1 and (maze[y][x] & 1 != 0):
				var room1 = room_grid[y][x]
				var room2 = room_grid[y][x+1]
				_create_horizontal_corridor(room1, room2)
			
			if y < grid_size.y - 1 and (maze[y][x] & 2 != 0):
				var room1 = room_grid[y][x]
				var room2 = room_grid[y+1][x]
				_create_vertical_corridor(room1, room2)

func _create_horizontal_corridor(room1: Dictionary, room2: Dictionary):
	var y_pos = room1["center"].y
	var room1_right_edge = room1["center"].x + room1["radius"] + 1  # Правая стена комнаты 1
	var room2_left_edge = room2["center"].x - room2["radius"] - 1   # Левая стена комнаты 2
	
	# Коридор между стенами комнат
	for x in range(room1_right_edge, room2_left_edge + 1):
		floor_layer.set_cell(Vector2i(x, y_pos), 0, tile_config.get_random_floor(), 0)
		
		# Верхняя и нижняя стены коридора
		wall_layer.set_cell(Vector2i(x, y_pos - 1), 0, tile_config.Wall.VERTICAL, 0)
		wall_layer.set_cell(Vector2i(x, y_pos + 1), 0, tile_config.Wall.VERTICAL, 0)
	
	# Оформляем дверные проемы в стенах комнат
	_place_door(room1_right_edge, y_pos, TileConfig.Door.Side.RIGHT)  # Дверь в правой стене комнаты 1
	_place_door(room2_left_edge, y_pos, TileConfig.Door.Side.LEFT)    # Дверь в левой стене комнаты 2

func _create_vertical_corridor(room1: Dictionary, room2: Dictionary):
	var x_pos = room1["center"].x
	var room1_bottom_edge = room1["center"].y + room1["radius"] + 1  # Нижняя стена комнаты 1
	var room2_top_edge = room2["center"].y - room2["radius"] - 1     # Верхняя стена комнаты 2
	
	# Вертикальный коридор между комнатами
	for y in range(room1_bottom_edge, room2_top_edge + 1):
		floor_layer.set_cell(Vector2i(x_pos, y), 0, tile_config.get_random_floor(), 0)
		
		# Левая и правая стены коридора
		wall_layer.set_cell(Vector2i(x_pos - 1, y), 0, tile_config.Wall.HORIZONTAL, 0)
		wall_layer.set_cell(Vector2i(x_pos + 1, y), 0, tile_config.Wall.HORIZONTAL, 1)
	
	# Оформляем дверные проемы
	_place_door(x_pos, room1_bottom_edge, TileConfig.Door.Side.BOTTOM)  # Дверь в нижней стене комнаты 1
	_place_door(x_pos, room2_top_edge, TileConfig.Door.Side.UP)       # Дверь в верхней стене комнаты 2

func _place_door(x: int, y: int, side: int):
	# Удаляем стену где будет дверь
	wall_layer.erase_cell(Vector2i(x, y))
	
	# Ставим дверь
	var door_data = tile_config.Door.TILES[side]
	door_layer.set_cell(Vector2i(x, y), 0, door_data.tile, door_data.alt)
	
	# Добавляем внутренние углы
	match side:
		TileConfig.Door.Side.RIGHT:
			wall_layer.set_cell(Vector2i(x, y - 1), 0, tile_config.Wall.InnerCorner.TOP, 0)
			wall_layer.set_cell(Vector2i(x, y + 1), 0, tile_config.Wall.InnerCorner.BOTTOM, 0)
		
		TileConfig.Door.Side.LEFT:
			wall_layer.set_cell(Vector2i(x, y - 1), 0, tile_config.Wall.InnerCorner.TOP, 1)
			wall_layer.set_cell(Vector2i(x, y + 1), 0, tile_config.Wall.InnerCorner.BOTTOM, 1)
		
		TileConfig.Door.Side.UP:
			wall_layer.set_cell(Vector2i(x - 1, y), 0, tile_config.Wall.InnerCorner.TOP, 0)
			wall_layer.set_cell(Vector2i(x + 1, y), 0, tile_config.Wall.InnerCorner.TOP, 1)
		
		TileConfig.Door.Side.BOTTOM:
			wall_layer.set_cell(Vector2i(x - 1, y), 0, tile_config.Wall.InnerCorner.BOTTOM, 1)
			wall_layer.set_cell(Vector2i(x + 1, y), 0, tile_config.Wall.InnerCorner.BOTTOM, 0)

func _place_special_rooms():
	if rooms.is_empty():
		return
	
	start_room = rooms.front()
	end_room = rooms.back()
	
	if object_layer:
		var end_center: Vector2i = end_room
		object_layer.set_cell(end_center, 0, tile_config.Floor.HATCH, 0)

func get_spawn_position() -> Vector2:
	if start_room:
		return floor_layer.map_to_local(start_room)
	return Vector2.ZERO
