class_name RoomTypes
extends RefCounted

enum Type {
	EMPTY,          # 0
	TREASURE,       # 1
	ARMORY,         # 2
	TRAP_CHAMBER,   # 3
	BOSS_ARENA,     # 4
	LIBRARY,        # 5
	SHRINE          # 6
}

# Базовые веса для случайной генерации
const BASE_WEIGHTS = {
	Type.EMPTY: 40,
	Type.TREASURE: 25,
	Type.ARMORY: 20,
	Type.TRAP_CHAMBER: 15,
	Type.BOSS_ARENA: 5,
	Type.LIBRARY: 10,
	Type.SHRINE: 8
}

# Текстовые названия для UI
const NAMES = {
	Type.EMPTY: "Пустая комната",
	Type.TREASURE: "Сокровищница",
	Type.ARMORY: "Оружейная",
	Type.TRAP_CHAMBER: "Ловушки",
	Type.BOSS_ARENA: "Арена босса",
	Type.LIBRARY: "Библиотека",
	Type.SHRINE: "Алтарь"
}
