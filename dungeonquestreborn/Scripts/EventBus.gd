extends Node

# Уровень
signal level_pre_generation()
signal level_nodes_ready(nodes: Dictionary)
signal level_generation_complete()

func _ready():
	print("EventBus loaded:", get_node("/root/EventBus") != null)

# Игрок
signal player_spawned(player: Node2D)
