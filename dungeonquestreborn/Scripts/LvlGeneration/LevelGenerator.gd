extends Node2D

enum WALL_ANGLE { TOP_LEFT, TOP_RIGHT, BOTTOM_LEFT, BOTTOM_RIGHT }
enum WALL_SIDE { UP = 0, RIGHT = 2, BOTTOM = 0, LEFT = 1 }
enum DOOR_SIDE { UP, RIGHT, BOTTOM, LEFT }

const TILE_FLOOR = [Vector2i(1,1), Vector2i(2,1), Vector2i(3,1), Vector2i(1,2)]
const TILE_WALL_TOP_CORNER = Vector2i(0,0)    # Верхний угол (альт 0-левый, 1-правый)
const TILE_WALL_BOTTOM_CORNER = Vector2i(0,4) # Нижний угол (альт 0-левый, 1-правый)
const TILE_WALL_VERTICAL = Vector2i(3,0)      # Вертикальные стены (верх/низ)
const TILE_WALL_HORIZONTAL = Vector2i(0,1)    # Горизонтальные стены (лево/право)
const TILE_DOOR_VERTICAL = Vector2i(2,5)      # Вертикальная дверь (альт 0)
const TILE_DOOR_HORIZONTAL = Vector2i(2,7)    # Горизонтальная дверь (альт 0-левая, 1-правая)
const TILE_HATCH = Vector2i(2,2)
const TILE_INNER_CORNER_TOP = Vector2i(1, 3)    # Верхний внутренний угол (альт 0-правый, 1-левый)
const TILE_INNER_CORNER_BOTTOM = Vector2i(2, 3) # Нижний внутренний угол (альт 0-правый, 1-левый)

const TILE_INNER_CORNER = {
	"top_left": [Vector2i(1,3), 1],     # Верхний угол слева от двери
	"top_right": [Vector2i(1,3), 0],    # Верхний угол справа от двери
	"bottom_left": [Vector2i(2,3), 1],  # Нижний угол слева от двери
	"bottom_right": [Vector2i(2,3), 0]  # Нижний угол справа от двери
}

var persistent_player_data: Dictionary = {
	"gold": 0,
	"max_health": 100
}

const SKELETON_SCENE = preload("res://Scene/SkeletonCrus_2.tscn")  # Укажите правильный путь
@export var max_skeletons_per_room: int = 5
@export var skeleton_spawn_chance: float = 0.6  # 80% chance to spawn skeletons

@onready var floor_layer = $FloorLayer
@onready var wall_layer = $"../Ysort/WallLayer"
@onready var door_layer = $"../Ysort/DoorLayer"
@onready var ysort_node = $"../Ysort"

const GRID_SIZE = 3  # Size x Size сетка комнат
const MIN_ROOM_RADIUS = 2  # Минимальный радиус
const MAX_ROOM_RADIUS = 3  # Максимальный радиус
const CENTER_TO_CENTER_DISTANCE = (MAX_ROOM_RADIUS * 2) + 6  # Расстояние между центрами

func _ready():
	
	floor_layer = get_node_or_null("Dangeon/FloorLayer")
	wall_layer = get_node_or_null("Y-sort/WallLayer")
	door_layer = get_node_or_null("Y-sort/DoorLayer")

func configure_tile_data():
	# Для вертикальных стен (чтобы перекрывали персонажа)
	var wall_source_id = wall_layer.get_cell_source_id(Vector2i(0,0))
	if wall_source_id != -1:
		var wall_data = wall_layer.tile_set.get_source(wall_source_id).tile_data
		wall_data.z_index = 1  # Базовый z-index стен
		
	# Для дверей
	var door_source_id = door_layer.get_cell_source_id(Vector2i(0,0))
	if door_source_id != -1:
		var door_data = door_layer.tile_set.get_source(door_source_id).tile_data
		door_data.z_index = 2  # Двери поверх стен

func generate_grid_level():
	floor_layer = $FloorLayer
	wall_layer = $"../Ysort/WallLayer"
	door_layer = $"../Ysort/DoorLayer"
	ysort_node = $"../Ysort"
	
	floor_layer.clear()
	wall_layer.clear()
	door_layer.clear()
	
	if persistent_player_data:
		var player = get_tree().get_first_node_in_group("player")
		if player:
			player.gold = persistent_player_data.get("gold", 0)
			player.max_health = persistent_player_data.get("max_health", 100)
			player.current_health = player.max_health
			player.update_health()
			player.player_ui.update_gold(player.gold)
	
	var player = get_tree().get_first_node_in_group("player")
	if player:
		persistent_player_data["gold"] = player.gold
		persistent_player_data["max_health"] = player.max_health
	
	# 1. Создаем сетку центров комнат
	var room_centers = []
	var start_pos = Vector2i(0, 0)  # Стартовая позиция
	
	for y in range(GRID_SIZE):
		var row = []
		for x in range(GRID_SIZE):
			var center = start_pos + Vector2i(x, y) * CENTER_TO_CENTER_DISTANCE
			row.append(center)
		room_centers.append(row)
	
	# 2. Генерируем радиусы для каждой комнаты
	var room_radii = []
	for y in range(GRID_SIZE):
		var row = []
		for x in range(GRID_SIZE):
			row.append(randi_range(MIN_ROOM_RADIUS, MAX_ROOM_RADIUS))
		room_radii.append(row)
	
	# 3. Генерируем лабиринт
	var maze = generate_maze(GRID_SIZE, GRID_SIZE)
	
	# 4. Создаем комнаты и коридоры
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			var center = room_centers[y][x]
			var radius = room_radii[y][x]
			
			# Определяем соединения для текущей комнаты
			var connections = {
				"right": maze[y][x] & 1 != 0 and x < GRID_SIZE-1,
				"down": maze[y][x] & 2 != 0 and y < GRID_SIZE-1,
				"left": x > 0 and maze[y][x-1] & 1 != 0,
				"up": y > 0 and maze[y-1][x] & 2 != 0
			}
			
			create_room(center, radius, connections)
			
			if not is_start_or_end_room(x, y):
				spawn_skeletons_in_room(center, radius)  # Правильный вызов
			
			# Создаем коридоры
			if connections["right"]:
				var door1_pos = center + Vector2i(radius + 1, 0)
				var door2_pos = room_centers[y][x+1] - Vector2i(room_radii[y][x+1] + 1, 0)
				@warning_ignore("unused_variable")
				var door1 = place_door(door1_pos, DOOR_SIDE.RIGHT)
				@warning_ignore("unused_variable")
				var door2 = place_door(door2_pos, DOOR_SIDE.LEFT)
				create_horizontal_corridor(door1_pos, door2_pos)
			
			if connections["down"]:
				var door1_pos = center + Vector2i(0, radius + 1)
				var door2_pos = room_centers[y+1][x] - Vector2i(0, room_radii[y+1][x] + 1)
				
				# просто создаем две двери
				@warning_ignore("unused_variable") 
				var door1 = place_door(door1_pos, DOOR_SIDE.BOTTOM)
				@warning_ignore("unused_variable")
				var door2 = place_door(door2_pos, DOOR_SIDE.UP)
				create_vertical_corridor(door1_pos, door2_pos)
	
	# 5. Помечаем стартовую и конечную комнаты
	var start_center = room_centers[0][0]
	var exit_center = room_centers[GRID_SIZE-1][GRID_SIZE-1]
	@warning_ignore("unused_variable")
	var exit_radius = room_radii[GRID_SIZE-1][GRID_SIZE-1]
	
	# Создаем люк в конечной комнате
	create_hatch(exit_center)
	
	# Дверь в стартовой комнате
	var start_door = place_door(start_center - Vector2i(0, room_radii[0][0] + 1), DOOR_SIDE.UP, true) # true = заперта
	start_door.add_to_group("start_point")  # Добавляем в группу для поиска

	# Позиционируем игрока в стартовой комнате
	if player:
	# Вариант 1: Позиция рядом со стартовой дверью
		player.position = floor_layer.map_to_local(start_center) + Vector2(0, 30)
	
	# Вариант 2: Использовать позицию стартовой двери
	# player.position = start_door.position + Vector2(0, -50)
	
	# Вариант 3: Центр стартовой комнаты
	# player.position = floor_layer.map_to_local(start_center)
	
	# Сбрасываем состояние игрока (если нужно)
		player.current_health = player.max_health
		player.update_health()
		player.player_ui.update_gold(player.gold)
	
		print("Игрок перемещен в стартовую комнату. Позиция: ", player.position)




func create_hatch(position: Vector2i) -> Area2D:
	door_layer.set_cell(position, 0, TILE_HATCH)
	
	var hatch = Area2D.new()
	hatch.position = door_layer.map_to_local(position)
	hatch.set_meta("is_hatch", true)
	
	var collision = CollisionShape2D.new()
	collision.shape = RectangleShape2D.new()
	collision.shape.extents = Vector2(100, 100)
	hatch.add_child(collision)
	
	# Добавляем обработку сигналов прямо здесь
	hatch.body_entered.connect(
		func(body): 
			if body.is_in_group("player"):
				body.near_hatch = hatch
	)
	
	hatch.body_exited.connect(
		func(body): 
			if body.is_in_group("player") and body.near_hatch == hatch:
				body.near_hatch = null
	)
	
	door_layer.add_child(hatch)
	return hatch

#func _on_hatch_entered(body: Node2D, hatch: Area2D):
	#if body.is_in_group("player"):
		#body.near_hatch = hatch
#
#func _on_hatch_exited(body: Node2D):
	#if body.is_in_group("player") and body.near_hatch:
		#body.near_hatch = null

func create_room(center: Vector2i, radius: int, connections: Dictionary ):
	# Пол комнаты
	for x in range(center.x - radius, center.x + radius + 1):
		for y in range(center.y - radius, center.y + radius + 1):
			var random_floor = TILE_FLOOR[randi() % TILE_FLOOR.size()]
			floor_layer.set_cell(Vector2i(x, y), 0, random_floor)
	
	# Стены с дверями
	create_walls_with_doors(center, radius, connections)

func is_start_or_end_room(x: int, y: int) -> bool:
	return (x == 0 and y == 0) or (x == GRID_SIZE-1 and y == GRID_SIZE-1)

func spawn_skeletons_in_room(center: Vector2i, radius: int):
	if randf() > skeleton_spawn_chance:
		return
	
	var skeleton_count = randi() % max_skeletons_per_room + 1
	
	for i in range(skeleton_count):
		var spawn_pos = get_valid_spawn_position(center, radius)
		if spawn_pos:
			create_skeleton(spawn_pos)

func get_valid_spawn_position(center: Vector2i, radius: int) -> Vector2:
	var attempts = 0
	while attempts < 10:
		var pos = Vector2(
			center.x + randf_range(-radius + 1, radius - 1),
			center.y + randf_range(-radius + 1, radius - 1)
		)
		
		# Проверяем, что позиция на полу и не слишком близко к стенам
		if is_valid_floor_position(pos):
			return floor_layer.map_to_local(pos)
		
		attempts += 1
	return Vector2.ZERO

func is_valid_floor_position(pos: Vector2) -> bool:
	var tile_pos = floor_layer.local_to_map(pos)
	return floor_layer.get_cell_source_id(tile_pos) != -1

func create_skeleton(position: Vector2):
	var skeleton = SKELETON_SCENE.instantiate()
	skeleton.position = position
	
	# Автоматическая установка игрока если не задан вручную
	if skeleton.has_method("set_player") && !skeleton.player:
		var player_node = get_tree().get_first_node_in_group("player")
		if player_node:
			skeleton.set_player(player_node)
	
	ysort_node.add_child(skeleton)
	
	# Настройка патрулирования
	if skeleton.has_method("set_patrol_area"):
		skeleton.set_patrol_area(position, 50.0)

func spawn_enemy(position: Vector2):
	var enemy = preload("res://Scene/SkeletonCrus_2.tscn").instantiate()
	enemy.player = get_tree().get_first_node_in_group("player")
	enemy.position = position
	add_child(enemy)

func create_walls_with_doors(center: Vector2i, radius: int, connections: Dictionary):
	# 1. Сначала создаем все стены
	for x in range(center.x - radius - 1, center.x + radius + 2):
		place_wall_side(Vector2i(x, center.y - radius - 1), WALL_SIDE.UP)
		place_wall_side(Vector2i(x, center.y + radius + 1), WALL_SIDE.BOTTOM)
	
	for y in range(center.y - radius, center.y + radius + 1):
		place_wall_side(Vector2i(center.x - radius - 1, y), WALL_SIDE.LEFT)
		place_wall_side(Vector2i(center.x + radius + 1, y), WALL_SIDE.RIGHT)

	# 2. Обрабатываем двери и соединения
	# Верхняя дверь (только левая замена)
	if connections.get("up", false):
		var door_pos = Vector2i(center.x, center.y - radius - 1)
		place_door(door_pos, DOOR_SIDE.UP)
		# Левый верхний внутренний угол
		wall_layer.set_cell(door_pos - Vector2i(1, 0),
			0,
			TILE_INNER_CORNER["top_left"][0],
			TILE_INNER_CORNER["top_left"][1])

	# Нижняя дверь (обе стороны)
	if connections.get("down", false):
		var door_pos = Vector2i(center.x, center.y + radius + 1)
		place_door(door_pos, DOOR_SIDE.BOTTOM)
		# Левый нижний внутренний угол
		wall_layer.set_cell(door_pos - Vector2i(1, 0),
			0,
			TILE_INNER_CORNER["bottom_left"][0],
			TILE_INNER_CORNER["bottom_left"][1])
		# Правый нижний внутренний угол
		wall_layer.set_cell(door_pos + Vector2i(1, 0),
			0,
			TILE_INNER_CORNER["bottom_right"][0],
			TILE_INNER_CORNER["bottom_right"][1])

	# Правая дверь (верхний и нижний углы)
	if connections.get("right", false):
		var door_pos = Vector2i(center.x + radius + 1, center.y)
		place_door(door_pos, DOOR_SIDE.RIGHT)
		# Верхний правый внутренний угол
		wall_layer.set_cell(door_pos + Vector2i(0, -1),
			0,
			TILE_INNER_CORNER["top_right"][0],
			TILE_INNER_CORNER["top_right"][1])
		# Нижний правый внутренний угол
		wall_layer.set_cell(door_pos + Vector2i(0, 1),
			0,
			TILE_INNER_CORNER["bottom_right"][0],
			TILE_INNER_CORNER["bottom_right"][1])

	# Левая дверь (верхний и нижний углы)
	if connections.get("left", false):
		var door_pos = Vector2i(center.x - radius - 1, center.y)
		place_door(door_pos, DOOR_SIDE.LEFT)
		
		# Верхний левый внутренний угол
		wall_layer.set_cell(door_pos + Vector2i(0, -1),
			0,
			TILE_INNER_CORNER["top_left"][0],
			TILE_INNER_CORNER["top_left"][1])
		# Нижний левый внутренний угол
		wall_layer.set_cell(door_pos + Vector2i(0, 1),
			0,
			TILE_INNER_CORNER["bottom_left"][0],
			TILE_INNER_CORNER["bottom_left"][1])

	# 3. Углы комнаты (в самом конце)
	place_wall_corner(Vector2i(center.x - radius - 1, center.y - radius - 1), WALL_ANGLE.TOP_LEFT)
	place_wall_corner(Vector2i(center.x + radius + 1, center.y - radius - 1), WALL_ANGLE.TOP_RIGHT)
	place_wall_corner(Vector2i(center.x + radius + 1, center.y + radius + 1), WALL_ANGLE.BOTTOM_RIGHT)
	place_wall_corner(Vector2i(center.x - radius - 1, center.y + radius + 1), WALL_ANGLE.BOTTOM_LEFT)

func create_horizontal_corridor(door1_pos: Vector2i, door2_pos: Vector2i):
	var y_pos = door1_pos.y
	var start_x = min(door1_pos.x, door2_pos.x)
	var end_x = max(door1_pos.x, door2_pos.x)
	
	# 1. Создаем пол коридора
	for x in range(start_x, end_x + 1):
		floor_layer.set_cell(Vector2i(x, y_pos), 0, TILE_FLOOR[0], 0)
	
	# 2. Обработка стен и внутренних углов
	for x in range(start_x - 1, end_x):
		# Пропускаем позиции дверей
		if x == door1_pos.x or x == door2_pos.x:
			continue
			
		# Верхняя стена коридора
		if not is_floor_cell(Vector2i(x, y_pos - 1)):
			# Проверяем, нужно ли ставить внутренний угол
			if x == door1_pos.x - 1 and door1_pos.x > start_x:
				wall_layer.set_cell(Vector2i(x, y_pos - 1), 0, TILE_INNER_CORNER_TOP, 1) # Левый верхний внутренний угол
			elif x == door2_pos.x + 1 and door2_pos.x < end_x:
				wall_layer.set_cell(Vector2i(x, y_pos - 1), 0, TILE_INNER_CORNER_TOP, 0) # Правый верхний внутренний угол
			else:
				wall_layer.set_cell(Vector2i(x, y_pos - 1), 0, TILE_WALL_VERTICAL, 0)
		
		# Нижняя стена коридора
		if not is_floor_cell(Vector2i(x, y_pos + 1)):
			# Проверяем, нужно ли ставить внутренний угол
			if x == door1_pos.x - 1 and door1_pos.x > start_x:
				wall_layer.set_cell(Vector2i(x, y_pos + 1), 0, TILE_INNER_CORNER_BOTTOM, 1) # Левый нижний внутренний угол
			elif x == door2_pos.x + 1 and door2_pos.x < end_x:
				wall_layer.set_cell(Vector2i(x, y_pos + 1), 0, TILE_INNER_CORNER_BOTTOM, 0) # Правый нижний внутренний угол
			else:
				wall_layer.set_cell(Vector2i(x, y_pos + 1), 0, TILE_WALL_VERTICAL, 0)

func create_vertical_corridor(door1_pos: Vector2i, door2_pos: Vector2i):
	var x_pos = door1_pos.x
	var start_y = min(door1_pos.y, door2_pos.y)
	var end_y = max(door1_pos.y, door2_pos.y)
	
	# 1. Создаем пол коридора
	for y in range(start_y, end_y + 1):
		floor_layer.set_cell(Vector2i(x_pos, y), 0, TILE_FLOOR[0], 0)
	
	# 2. Обработка стен (для вертикальных коридоров внутренние углы не нужны)
	for y in range(start_y - 1, end_y):
		if y == door1_pos.y or y == door2_pos.y:
			continue
			
		# Левая стена коридора
		if not is_floor_cell(Vector2i(x_pos - 1, y)):
			wall_layer.set_cell(Vector2i(x_pos - 1, y), 0, TILE_WALL_HORIZONTAL, 0)
		
		# Правая стена коридора
		if not is_floor_cell(Vector2i(x_pos + 1, y)):
			wall_layer.set_cell(Vector2i(x_pos + 1, y), 0, TILE_WALL_HORIZONTAL, 1)

# Вспомогательная функция для проверки пола
func is_floor_cell(pos: Vector2i) -> bool:
	return floor_layer.get_cell_source_id(pos) != -1

# Генерация лабиринта (алгоритм Эйлера)
func generate_maze(width, height):
	var maze = []
	for y in range(height):
		var row = []
		for x in range(width):
			row.append(0)
		maze.append(row)
	
	# Начинаем с случайной клетки
	var stack = [Vector2i(randi() % width, randi() % height)]
	var visited = []
	visited.append(stack[0])
	
	var directions = [
		Vector2i(1, 0),  # Right
		Vector2i(0, 1),  # Down
		Vector2i(-1, 0), # Left
		Vector2i(0, -1)   # Up
	]
	
	while stack.size() > 0:
		var current = stack.back()
		var neighbors = []
		
		# Ищем непосещенных соседей
		for dir in directions:
			var nx = current.x + dir.x
			var ny = current.y + dir.y
			
			if nx >= 0 and nx < width and ny >= 0 and ny < height:
				if not Vector2i(nx, ny) in visited:
					neighbors.append(dir)
		
		if neighbors.size() > 0:
			var next_dir = neighbors[randi() % neighbors.size()]
			var next_pos = current + next_dir
			
			# Отмечаем проход между клетками
			if next_dir.x == 1:   # Right
				maze[current.y][current.x] |= 1
				maze[next_pos.y][next_pos.x] |= 4
			elif next_dir.y == 1:  # Down
				maze[current.y][current.x] |= 2
				maze[next_pos.y][next_pos.x] |= 8
			elif next_dir.x == -1: # Left
				maze[current.y][current.x] |= 4
				maze[next_pos.y][next_pos.x] |= 1
			elif next_dir.y == -1: # Up
				maze[current.y][current.x] |= 8
				maze[next_pos.y][next_pos.x] |= 2
			
			visited.append(next_pos)
			stack.append(next_pos)
		else:
			stack.pop_back()
	
	return maze

func place_wall_corner(pos: Vector2i, angle: WALL_ANGLE):
	match angle:
		WALL_ANGLE.TOP_LEFT:
			wall_layer.set_cell(pos, 0, TILE_WALL_TOP_CORNER, 0)  # Верхний левый
		WALL_ANGLE.TOP_RIGHT:
			wall_layer.set_cell(pos, 0, TILE_WALL_TOP_CORNER, 1)  # Верхний правый
		WALL_ANGLE.BOTTOM_LEFT:
			wall_layer.set_cell(pos, 0, TILE_WALL_BOTTOM_CORNER, 0)  # Нижний левый
		WALL_ANGLE.BOTTOM_RIGHT:
			wall_layer.set_cell(pos, 0, TILE_WALL_BOTTOM_CORNER, 1)  # Нижний правый

func place_wall_side(pos: Vector2i, side: WALL_SIDE):
	match side:
		WALL_SIDE.UP, WALL_SIDE.BOTTOM:
			wall_layer.set_cell(pos, 0, TILE_WALL_VERTICAL, 0)
		WALL_SIDE.LEFT:
			wall_layer.set_cell(pos, 0, TILE_WALL_HORIZONTAL, 0)
		WALL_SIDE.RIGHT:
			wall_layer.set_cell(pos, 0, TILE_WALL_HORIZONTAL, 1)

func place_door(pos: Vector2i, side: DOOR_SIDE, is_locked: bool = false) -> Area2D:
		# Получаем данные тайла
	var tile_data = get_door_tile_data(side)
	
	# Устанавливаем тайл
	door_layer.set_cell(pos, 0, tile_data.tile, tile_data.alt)
	
	# Создаем Area2D
	var door = Area2D.new()
	var door_center = door_layer.map_to_local(pos)
	door.position = door_center
	door.set_meta("is_door", true)
	door.set_meta("is_locked", is_locked)
	door.set_meta("door_side", side)  # Сохраняем направление двери
	
	# Зона взаимодействия 
	var collision = CollisionShape2D.new()
	collision.shape = RectangleShape2D.new()
	collision.shape.extents = Vector2(250, 250)
	door.add_child(collision)
	
		# Заранее рассчитываем ОБЕ точки телепортации
	var exit_pos_front = door_center
	var exit_pos_back = door_center
	
	# Предварительный расчет точек телепортации
	var exits = {
		DOOR_SIDE.UP:    { front = Vector2(0, 128),  back = Vector2(0, -128) },
		DOOR_SIDE.BOTTOM: { front = Vector2(0, -128), back = Vector2(0, 128) },
		DOOR_SIDE.LEFT:  { front = Vector2(-128, 0), back = Vector2(128, 0) },
		DOOR_SIDE.RIGHT: { front = Vector2(128, 0),  back = Vector2(-128, 0) }
	}[side]
	
	door.set_meta("exit_front", door_center + exits.front)
	door.set_meta("exit_back", door_center + exits.back)
	
	door_layer.add_child(door)
	
		# Отладочный вывод
	print("Создана дверь: ", side, 
		  " Тайл: ", tile_data.tile, 
		  " Alt: ", tile_data.alt,
		  " Позиция: ", pos)
		
	return door

func get_door_tile_data(side: DOOR_SIDE) -> Dictionary:
	return {
		DOOR_SIDE.UP:    { tile = TILE_DOOR_VERTICAL, alt = 0 },
		DOOR_SIDE.BOTTOM: { tile = TILE_DOOR_VERTICAL, alt = 0 }, # Разные альты для одинакового тайла
		DOOR_SIDE.LEFT:  { tile = TILE_DOOR_HORIZONTAL, alt = 0 },
		DOOR_SIDE.RIGHT: { tile = TILE_DOOR_HORIZONTAL, alt = 1 }
	}[side]
