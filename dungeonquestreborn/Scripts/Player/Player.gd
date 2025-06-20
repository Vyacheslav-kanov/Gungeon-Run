extends CharacterBody2D

@export var speed: float = 450.0
@export var acceleration: float = 15.0
@export var friction: float = 50.0
@export var max_health: int = 1000
@export var knockback_force: float = 300.0
@export var attack_damage: int = 200

var level: int = 1
# Компоненты
@onready var Ysort = $Ysort
@onready var animated_sprite = $AnimatedSprite2D
@onready var sorting_node = $SortingNode
@onready var player_ui = $PlayerUI
@onready var attack_area = $AttackArea  # Изменено: теперь берем всю Area2D, а не CollisionShape2D
@onready var attack_shape = $AttackArea/CollisionShape2D  # Добавлено отдельная ссылка на форму
@onready var health_bar = $PlayerUI/HUD/HBoxContainer/HealthBar

var current_health: int
var gold: int = 0
var is_attacking: bool = false
var is_dead: bool = false
var current_input: Vector2 = Vector2.ZERO
var near_door: Area2D = null
var near_hatch: Area2D = null

enum DOOR_SIDE { UP, RIGHT, BOTTOM, LEFT }

func _ready():
	add_to_group("player")
	animated_sprite.play("idle")
	current_health = max_health
	update_health()
	player_ui.update_gold(gold)
	player_ui.update_level(level)
	attack_shape.disabled = true  # Отключаем форму коллизии, а не всю область
	
	# Подключаем сигналы области атаки
	attack_area.body_entered.connect(_on_attack_area_body_entered)

func _physics_process(delta):
	if is_dead: return
	
	if Input.is_action_just_pressed("interact"):
		if near_door:
			use_door(near_door)
		elif near_hatch:
			use_hatch(near_hatch)
	
	if Input.is_action_just_pressed("attack"):
		attack()
		
	current_input = Input.get_vector("Left", "Right", "Up", "Down")
	handle_movement()
	move_and_slide()
	update_animation_and_flip()

func update_health():
	if health_bar:
		health_bar.value = current_health
		health_bar.max_value = max_health
	player_ui.update_health(max_health, current_health)

func use_door(door: Area2D):
	if door.get_meta("is_locked"):
		print("Заперто!")
		return
	
	var door_pos = door.position
	var player_to_door = global_position - door_pos
	print("player pos ", global_position, "  door  ", door_pos)
	# Определяем с какой стороны игрок
	var is_front = false
	match door.get_meta("door_side"):
		DOOR_SIDE.UP:    is_front = player_to_door.y < 0 # если игрок ниже двери 
		DOOR_SIDE.BOTTOM:  is_front = player_to_door.y > 0
		DOOR_SIDE.LEFT:  is_front = player_to_door.x > 0
		DOOR_SIDE.RIGHT: is_front = player_to_door.x < 0
	
	# Выбираем нужную точку
	var target_pos = door.get_meta("exit_front") if is_front else door.get_meta("exit_back")
	print(" ", door.get_meta("door_side"), " ", is_front)
	global_position = target_pos
	print("player tp to ", target_pos)

func _on_door_exited(area: Area2D):
	if area == near_door:
		near_door = null

func _on_door_entered(area: Area2D):
	if area.get_meta("is_door"):
		near_door = area

func use_hatch(hatch: Area2D):
	if is_dead: return
	
	# Восстанавливаем здоровье
	current_health = max_health
	update_health()
	
	# Получаем генератор уровней (он уже есть в дереве сцены)
	var level_generator = get_parent()
	if level_generator and level_generator.has_method("generate_grid_level"):
		# Сохраняем золото в генератор
		level_generator.persistent_player_data["gold"] = gold
		
		# Генерируем новый уровень
		level_generator.generate_grid_level()
		level += 1
		player_ui.update_level(level)


func _on_hatch_exited(area: Area2D):
	if area == near_hatch:
		near_door = null

func _on_hatch_entered(area: Area2D):
	if area.get_meta("is_hatch"):
		near_hatch = area

func handle_movement():
	if is_attacking:
		velocity = Vector2.ZERO
		return
	
	if current_input != Vector2.ZERO:
		velocity = current_input.normalized() * speed
	else:
		velocity = Vector2.ZERO

func update_animation_and_flip():
	if is_dead:
		animated_sprite.play("die")
		return
	
	if is_attacking:
		animated_sprite.play("slashing")
		return
	
	# Обработка поворота и анимации
	if current_input.x < -0.1:  # Движение влево
		animated_sprite.flip_h = true
		animated_sprite.play("run")
	elif current_input.x > 0.1:  # Движение вправо
		animated_sprite.flip_h = false
		animated_sprite.play("run")
	elif current_input.length() > 0.1:  # Движение вверх/вниз
		animated_sprite.play("run")
	else:
		animated_sprite.play("idle")

func attack():
	if is_dead or is_attacking: return
	
	is_attacking = true
	animated_sprite.play("slashing")
	attack_shape.disabled = false  # Включаем коллизию при атаке
	
	# Ждем пока анимация дойдет до кадра с ударом
	await animated_sprite.frame_changed
	_check_attack_hits()
	#if animated_sprite.frame >= 3:  # Пример: наносим удар на 3 кадре анимации
		
	await animated_sprite.animation_finished
	is_attacking = false
	attack_shape.disabled = true

# Новый метод для проверки попаданий
func _check_attack_hits():
	var bodies = attack_area.get_overlapping_bodies()
	for body in bodies:
		if body.has_method("take_damage") and body.is_in_group("enemies"):
			body.take_damage(attack_damage)
			# Можно добавить эффект попадания
			print("Попал по врагу!")

func take_damage(amount: int):
	if is_dead: return
	
	current_health = max(0, current_health - amount)
	update_health()  # Обновляем полосу здоровья
	
	# Анимация получения урона только в idle
	if animated_sprite.animation == "idle":
		animated_sprite.play("hurt")
		await animated_sprite.animation_finished
	
	# Отбрасывание
	#velocity = direction * knockback_force
	
	if current_health <= 0:
		die()

func die():
	is_dead = true
	animated_sprite.play("die")
	set_process(false)
	set_physics_process(false)

func add_gold(amount: int):
	gold += amount
	player_ui.update_gold(gold)

func add_experience(amount: int):
	# Ваша логика прокачки уровня
	pass

func _on_attack_area_body_entered(body):
	if body.has_method("take_damage") and body.is_in_group("enemies"):
		body.take_damage(attack_damage)
