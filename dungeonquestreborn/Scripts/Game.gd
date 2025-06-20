#extends Node2D
#
#@onready var level_generator = $Ysort
#
#func _ready():
	#print("Дочерние ноды: ", get_children())
	#level_generator.generate_level()
	#_spawn_player()
#
#func _spawn_player():
	#var player = preload("res://Scene/Player.tscn").instantiate()
	#player.global_position = level_generator.get_spawn_position()
	#level_generator.add_child(player)  # Добавляем в Ysort для правильного порядка отрисовки

extends Node2D

#@onready var dungeon = $Dangeon
@onready var ysort_node = $Ysort  # Получаем узел YSort
var player_scene = preload("res://Scene/Player.tscn")

func _ready():
	generate_dungeon()
	spawn_player()

func generate_dungeon():
	# Ваш код генерации подземелья
	ysort_node.generate_grid_level()  # Предполагая, что метод есть в TileMap

func spawn_player():
	var player = player_scene.instantiate()
	
	# 1. Устанавливаем позицию относительно мира
	var spawn_pos = Vector2(160, 160)  # Глобальные координаты
	
	# 2. Добавляем игрока в Y-sort
	ysort_node.add_child(player)
