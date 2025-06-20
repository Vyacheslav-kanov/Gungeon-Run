extends CharacterBody2D
class_name Enemy

# Общие параметры
@export var health: int = 50
@export var speed: float = 150.0
@export var damage: int = 10
@export var gold: int = 20

@onready var sprite = $AnimatedSprite2D
@onready var hurtbox = $Hurtbox

var current_health: int
var player: Node2D = null
var is_alive: bool = true
var is_attacking: bool = false

func _ready():
	add_to_group("enemies")
	current_health = health
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)

func take_damage(amount: int):
	current_health -= amount
	sprite.play("hurt")
	await sprite.animation_finished
	if current_health <= 0:
		die()

func die():
	pass

func _on_hurtbox_area_entered(area):
	if area.is_in_group("player_weapon"):
		var player = area.get_parent().owner
		if player:
			take_damage(player.attack_damage)
