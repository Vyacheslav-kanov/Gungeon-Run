class_name TileConfig
extends RefCounted

# Группировка по функциональности
enum WallSide { UP = 0, RIGHT = 2, BOTTOM = 0, LEFT = 1 }

# Тайлы сгруппированы по типам
class Floor:
	const DEFAULT = [Vector2i(1,1), Vector2i(2,1), Vector2i(3,1), Vector2i(1,2)]
	const HATCH = Vector2i(2,2)
	
	static func get_random() -> Vector2i:
		return DEFAULT[randi() % DEFAULT.size()]

class Wall:
	const TOP_CORNER := Vector2i(0, 0)    # Альт: 0-левый, 1-правый
	const BOTTOM_CORNER := Vector2i(0, 4) # Альт: 0-левый, 1-правый
	const VERTICAL := Vector2i(3, 0)
	const HORIZONTAL := Vector2i(0, 1)
	
	class InnerCorner: # Углы стен для коридора по бокам двери
		const TOP := Vector2i(1, 3)    # Альт: 0-правый, 1-левый
		const BOTTOM := Vector2i(2, 3) # Альт: 0-правый, 1-левый
		
		static func get_corner(type: StringName) -> Array:
			var corners := {
				&"top_left": [TOP, 1],
				&"top_right": [TOP, 0],
				&"bottom_left": [BOTTOM, 1],
				&"bottom_right": [BOTTOM, 0]
			}
			return corners.get(type, [Vector2i.ZERO, 0])

class Door:
	enum Side { LEFT, RIGHT, UP, BOTTOM }
	
	const TILES = {
		Side.LEFT: { tile = Vector2i(2,7), alt = 0 },
		Side.RIGHT: { tile = Vector2i(2,7), alt = 1 },
		Side.UP: { tile = Vector2i(2,5), alt = 0 },
		Side.BOTTOM: { tile = Vector2i(2,5), alt = 0 }
	}
	
	static func get_tile(side: int) -> Dictionary:
		return {
			TileConfig.Door.Side.LEFT:  { tile = Vector2i(2,7), alt = 0 },
			TileConfig.Door.Side.RIGHT: { tile = Vector2i(2,7), alt = 1 },
			TileConfig.Door.Side.UP:    { tile = Vector2i(2,5), alt = 0 },
			TileConfig.Door.Side.BOTTOM:{ tile = Vector2i(2,5), alt = 0 }
		}.get(side, {})

# Методы для удобного доступа
static func get_inner_corner(type: String) -> Array:
	var corners = {
		"top_left": [Wall.InnerCorner.TOP, 1],
		"top_right": [Wall.InnerCorner.TOP, 0],
		"bottom_left": [Wall.InnerCorner.BOTTOM, 1],
		"bottom_right": [Wall.InnerCorner.BOTTOM, 0]
	}
	return corners.get(type, [Vector2i.ZERO, 0])

static func get_random_floor() -> Vector2i:
	return Floor.DEFAULT[randi() % Floor.DEFAULT.size()]
