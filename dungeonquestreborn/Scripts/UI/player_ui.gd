extends CanvasLayer

@onready var health_bar = $HUD/HBoxContainer/HealthBar
@onready var health_point = $"HUD/HBoxContainer/HealthBar/health_point"
@onready var level = $"HUD/HBoxContainer/level number"
@onready var gold_label = $HUD/HBoxContainer/GoldLabel
@onready var soul_effect = preload("res://Scene/soul_effect.tscn")  # Обновленный путь

func update_health(max_health: int, current_health: int):
	health_bar.max_value = max_health
	health_bar.value = current_health
	health_point.text =  str(current_health)

func update_gold(amount: int):
	gold_label.text = str(amount)
	# Анимация изменения количества
	var tween = create_tween()
	tween.tween_property(gold_label, "scale", Vector2(1.2, 1.2), 0.1)
	tween.tween_property(gold_label, "scale", Vector2(1.0, 1.0), 0.1)

func show_soul_gain(amount: int, is_large: bool = false):
	var effect = soul_effect.instantiate()
	add_child(effect)
	
	# Позиционируем относительно gold_label
	effect.global_position = gold_label.global_position + Vector2(-40, -30)
	effect.show_amount(amount, is_large)

func update_level(new_level: int):
	level.text = str(new_level)
