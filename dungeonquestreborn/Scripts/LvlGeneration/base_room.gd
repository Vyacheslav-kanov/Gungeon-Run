class_name BaseRoom
extends RefCounted

# Параметры комнаты
var position: Vector2i       # Левый верхний угол
var size: Vector2i          # Ширина и высота в тайлах
var type: int               # Тип из RoomTypes.Type
var door_sides: Array = []  # Массив направлений дверей (используем TileConfig.Door.Side)

# Основной метод генерации
func generate(t_config: TileConfig, f_layer: TileMapLayer, 
			 w_layer: TileMapLayer, d_layer: TileMapLayer) -> void:
	
	# Генерация в правильном порядке
	_generate_floor(t_config, f_layer)
	_generate_walls(t_config, w_layer)
	_place_doors(t_config, d_layer)

# Генерация пола
func _generate_floor(tile_config: TileConfig, floor_layer: TileMapLayer):
	for x in range(position.x, position.x + size.x):
		for y in range(position.y, position.y + size.y):
			var tile = tile_config.get_random_floor()
			floor_layer.set_cell(Vector2i(x, y), 0, tile, 0)

# Генерация стен
func _generate_walls(tile_config: TileConfig, wall_layer: TileMapLayer):
	# Горизонтальные стены (верх и низ)
	for x in range(position.x - 1, position.x + size.x + 1):
		# Верхняя стена
		wall_layer.set_cell(
			Vector2i(x, position.y - 1),
			0,
			tile_config.Wall.HORIZONTAL,
			0
		)
		# Нижняя стена
		wall_layer.set_cell(
			Vector2i(x, position.y + size.y),
			0,
			tile_config.Wall.HORIZONTAL,
			0
		)
	
	# Вертикальные стены (лево и право)
	for y in range(position.y, position.y + size.y):
		# Левая стена
		wall_layer.set_cell(
			Vector2i(position.x - 1, y),
			0,
			tile_config.Wall.VERTICAL,
			0
		)
		# Правая стена
		wall_layer.set_cell(
			Vector2i(position.x + size.x, y),
			0,
			tile_config.Wall.VERTICAL,
			1  # Альтернативный тайл для зеркального отображения
		)
	
	# Углы
	wall_layer.set_cell(
		Vector2i(position.x - 1, position.y - 1),
		0,
		tile_config.Wall.TOP_CORNER,
		0  # Левый верхний угол
	)
	wall_layer.set_cell(
		Vector2i(position.x + size.x, position.y - 1),
		0,
		tile_config.Wall.TOP_CORNER,
		1  # Правый верхний угол
	)
	wall_layer.set_cell(
		Vector2i(position.x + size.x, position.y + size.y),
		0,
		tile_config.Wall.BOTTOM_CORNER,
		1  # Правый нижний угол
	)
	wall_layer.set_cell(
		Vector2i(position.x - 1, position.y + size.y),
		0,
		tile_config.Wall.BOTTOM_CORNER,
		0  # Левый нижний угол
	)

# Размещение дверей
func _place_doors(tile_config: TileConfig, door_layer: TileMapLayer):
	for side in door_sides:
		var door_pos = _get_door_position(side)
		var tile_data = tile_config.Door.get_tile(side)
		door_layer.set_cell(door_pos, 0, tile_data.tile, tile_data.alt)

# Получение позиции двери
func _get_door_position(side: int) -> Vector2i:
	match side:
		TileConfig.Door.Side.UP:
			return position + Vector2i(size.x / 2, -1)
		TileConfig.Door.Side.BOTTOM:
			return position + Vector2i(size.x / 2, size.y)
		TileConfig.Door.Side.LEFT:
			return position + Vector2i(-1, size.y / 2)
		TileConfig.Door.Side.RIGHT:
			return position + Vector2i(size.x, size.y / 2)
		_:
			return position

# Добавление двери
func add_door(side: int):
	if not door_sides.has(side):
		door_sides.append(side)

# Центр комнаты
func get_center() -> Vector2i:
	return position + (size / 2)

# Инициализация
func _init(room_type: int, room_size: Vector2i, room_position: Vector2i):
	self.type = room_type
	self.size = room_size
	self.position = room_position
