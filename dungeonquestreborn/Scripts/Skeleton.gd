extends Enemy

# Настройки
@export var patrol_speed: float = 80.0
@export var chase_speed: float = 200.0
@export var attack_range: float = 120.0
@export var detection_range: float = 250.0
@export var patrol_radius: float = 150.0
@export var attack_cooldown: float = 0.5
@export var min_speed_threshold: float = 10.0  # Если скорость ниже этого значения - считаем что уперлись в стенку


@onready var detection_area = $DetectionArea
@onready var attack_timer = $AttackCooldownTimer

var patrol_target: Vector2
var can_attack: bool = true
var is_stuck: bool = false
var stuck_timer: float = 0.0
var stuck_time_threshold: float = 0.5  # Сколько секунд быть в "залипании" перед разворотом

func _ready():
	super._ready()
	detection_area.body_entered.connect(_on_detection_area_body_entered)
	detection_area.body_exited.connect(_on_detection_area_body_exited)
	attack_timer.timeout.connect(_on_attack_cooldown_timeout)  # Добавляем эту строку
	set_new_patrol_target()
	attack_timer.wait_time = attack_cooldown
	attack_timer.one_shot = true

func set_new_patrol_target():
	patrol_target = global_position + Vector2(
		randf_range(-patrol_radius, patrol_radius),
		randf_range(-patrol_radius/2, patrol_radius/2)
	).normalized() * patrol_radius

func _physics_process(delta):
	if !is_alive: return
	
	# Проверяем, не застрял ли враг
	if velocity.length() < min_speed_threshold and !is_attacking:
		stuck_timer += delta
		if stuck_timer >= stuck_time_threshold:
			is_stuck = true
	else:
		stuck_timer = 0.0
		is_stuck = false
	
	if is_attacking:
		velocity = Vector2.ZERO
	elif player:
		chase_behavior()
	else:
		patrol_behavior()
	
	# Если уперлись в стенку - меняем направление
	if is_stuck:
		set_new_patrol_target()
		is_stuck = false
	
	try_attack()
	update_animation()
	move_and_slide()

func patrol_behavior():
	var direction = (patrol_target - global_position).normalized()
	velocity = direction * patrol_speed
	sprite.flip_h = velocity.x < 0
	
	if global_position.distance_to(patrol_target) < 10 or is_stuck:
		set_new_patrol_target()

func chase_behavior():
	if is_attacking: 
		return
	
	var direction = (player.global_position - global_position).normalized()
	velocity = direction * chase_speed
	sprite.flip_h = direction.x < 0
	
	# Если уперлись в стенку при преследовании, немного отходим назад
	if is_stuck:
		velocity = -direction * patrol_speed * 0.5
		await get_tree().create_timer(0.5).timeout

func try_attack():
	if !can_attack or !player or is_attacking: 
		return
	
	if global_position.distance_to(player.global_position) <= attack_range:
		start_attack()

func start_attack():
	#print("start attack")
	can_attack = false
	is_attacking = true
	velocity = Vector2.ZERO
	sprite.play("attack")
	attack_timer.start()
	
	await sprite.animation_finished
	
	if player and global_position.distance_to(player.global_position) <= attack_range * 1.2:
		player.take_damage(damage)
	
	is_attacking = false
	
func die():
	is_alive = false
	sprite.stop()
	sprite.play("die")
	player.add_gold(gold)
	await sprite.animation_finished
	queue_free()

func update_animation():
	if is_attacking: 
		return
	
	if player:
		sprite.play("run")
	elif velocity.length() > 5:
		sprite.play("walk")
	else:
		sprite.play("idle")

func _on_detection_area_body_entered(body):
	if body.is_in_group("player"):
		player = body

func _on_detection_area_body_exited(body):
	if body == player:
		player = null

func _on_attack_cooldown_timeout():
	can_attack = true
