extends Node2D
## Stage-C: 12 levels, menu/select, score-on-hit (aligned with Phaser original).

enum Screen { MENU, SELECT, PLAY }
enum HookState { SWING, EXTEND, RETRACT }

const ORIGIN := Vector2(180, 55)
const MIN_LEN := 40.0
const LEVEL_COUNT := 12
const TIME_LIMIT := 60

const ITEMS: Array[Dictionary] = [
	{"type": "gold", "value": 100, "color": Color(1.0, 0.84, 0.0), "size": Vector2(30, 30)},
	{"type": "stone", "value": 20, "color": Color(0.5, 0.5, 0.52), "size": Vector2(40, 40)},
	{"type": "diamond", "value": 200, "color": Color(0.2, 0.95, 0.95), "size": Vector2(20, 20)},
]

@onready var _hook_line: Line2D = $HookLine
@onready var _hook_head: Polygon2D = $HookHead
@onready var _items_root: Node2D = $Items
@onready var _miner: ColorRect = $Miner
@onready var _hud: Label = $UI/HUD
@onready var _overlay: ColorRect = $UI/Overlay
@onready var _over_msg: Label = $UI/Overlay/VBox/Msg
@onready var _retry: Button = $UI/Overlay/VBox/Retry
@onready var _next: Button = $UI/Overlay/VBox/Next
@onready var _to_select: Button = $UI/Overlay/VBox/ToSelect
@onready var _menu: ColorRect = $UI/Menu
@onready var _start_btn: Button = $UI/Menu/VBox/Start
@onready var _select_btn: Button = $UI/Menu/VBox/Select
@onready var _select: ColorRect = $UI/Select
@onready var _select_grid: GridContainer = $UI/Select/VBox/Grid
@onready var _select_back: Button = $UI/Select/VBox/Back
@onready var _play_controls: HBoxContainer = $UI/Controls
@onready var _restart_btn: Button = $UI/Controls/Restart
@onready var _menu_btn: Button = $UI/Controls/MenuBtn

var _screen: Screen = Screen.MENU
var _level: int = 1
var _angle_deg: float = 90.0
var _angle_speed: float = 2.0
var _hook_len: float = MIN_LEN
var _max_len: float = 540.0
var _state: HookState = HookState.SWING
var _score: int = 0
var _time_left: int = TIME_LIMIT
var _alive: bool = false
var _rng := RandomNumberGenerator.new()
var _items: Array[Area2D] = []
var _timer: Timer

func _ready() -> void:
	_rng.randomize()
	_max_len = 640.0 - 100.0
	_retry.pressed.connect(_restart_level)
	_next.pressed.connect(_on_next_level)
	_to_select.pressed.connect(_show_select)
	_start_btn.pressed.connect(func() -> void: _start_level(1))
	_select_btn.pressed.connect(_show_select)
	_select_back.pressed.connect(_show_menu)
	_restart_btn.pressed.connect(_restart_level)
	_menu_btn.pressed.connect(_show_menu)
	_timer = Timer.new()
	_timer.wait_time = 1.0
	_timer.timeout.connect(_on_timer_tick)
	add_child(_timer)
	_build_select_grid()
	_show_menu()

func _target_score() -> int:
	return _level * 200

func _item_count() -> int:
	return 5 + _level * 2

func _build_select_grid() -> void:
	for c in _select_grid.get_children():
		c.queue_free()
	for i in range(1, LEVEL_COUNT + 1):
		var b := Button.new()
		b.text = "第%d关\n目标%d" % [i, i * 200]
		b.custom_minimum_size = Vector2(100, 56)
		var lv := i
		b.pressed.connect(func() -> void: _start_level(lv))
		_select_grid.add_child(b)

func _show_menu() -> void:
	_timer.stop()
	_alive = false
	_screen = Screen.MENU
	_menu.visible = true
	_select.visible = false
	_overlay.visible = false
	_hud.visible = false
	_play_controls.visible = false
	_miner.visible = false
	_hook_line.visible = false
	_hook_head.visible = false
	_items_root.visible = false

func _show_select() -> void:
	_timer.stop()
	_alive = false
	_screen = Screen.SELECT
	_menu.visible = false
	_select.visible = true
	_overlay.visible = false
	_hud.visible = false
	_play_controls.visible = false
	_miner.visible = false
	_hook_line.visible = false
	_hook_head.visible = false
	_items_root.visible = false

func _start_level(lv: int) -> void:
	_level = clampi(lv, 1, LEVEL_COUNT)
	_screen = Screen.PLAY
	_menu.visible = false
	_select.visible = false
	_overlay.visible = false
	_hud.visible = true
	_play_controls.visible = true
	_miner.visible = true
	_hook_line.visible = true
	_hook_head.visible = true
	_items_root.visible = true
	_restart_level()

func _restart_level() -> void:
	for c in _items_root.get_children():
		c.queue_free()
	_items.clear()
	_score = 0
	_time_left = TIME_LIMIT
	_alive = true
	_state = HookState.SWING
	_hook_len = MIN_LEN
	_angle_deg = 90.0
	_angle_speed = 2.0
	_overlay.visible = false
	_spawn_items()
	_update_hud()
	_timer.start()

func _spawn_items() -> void:
	var count := _item_count()
	for _i in count:
		var cfg: Dictionary = ITEMS[_rng.randi_range(0, ITEMS.size() - 1)]
		var area := Area2D.new()
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		var sz: Vector2 = cfg["size"] as Vector2
		rect.size = sz
		shape.shape = rect
		area.add_child(shape)
		var vis := ColorRect.new()
		vis.size = sz
		vis.position = -sz * 0.5
		vis.color = cfg["color"] as Color
		vis.mouse_filter = Control.MOUSE_FILTER_IGNORE
		area.add_child(vis)
		area.position = Vector2(_rng.randf_range(50, 310), _rng.randf_range(180, 560))
		area.set_meta("value", int(cfg["value"]))
		area.set_meta("alive", true)
		_items_root.add_child(area)
		_items.append(area)

func _update_hud() -> void:
	_hud.text = "关卡 %d/%d\n分数 %d / 目标 %d\n时间 %d\n点击或空格发射" % [
		_level, LEVEL_COUNT, _score, _target_score(), _time_left
	]

func _process(delta: float) -> void:
	if _screen != Screen.PLAY or not _alive:
		return
	match _state:
		HookState.SWING:
			_angle_deg += _angle_speed
			if _angle_deg >= 135.0 or _angle_deg <= 45.0:
				_angle_speed = -_angle_speed
		HookState.EXTEND:
			# Original advances ~5 px/frame at 60fps ≈ 300 px/s
			_hook_len = minf(_hook_len + 300.0 * delta, _max_len)
			if _hook_len >= _max_len:
				_state = HookState.RETRACT
			else:
				_check_hit()
		HookState.RETRACT:
			_hook_len = maxf(_hook_len - 180.0 * delta, MIN_LEN)
			if _hook_len <= MIN_LEN:
				_state = HookState.SWING
	_update_hook_visual()

func _hook_tip() -> Vector2:
	var rad := deg_to_rad(_angle_deg)
	return ORIGIN + Vector2(cos(rad), sin(rad)) * _hook_len

func _update_hook_visual() -> void:
	var tip := _hook_tip()
	_hook_line.points = PackedVector2Array([ORIGIN, tip])
	_hook_head.position = tip

func _check_hit() -> void:
	var tip := _hook_tip()
	var tip_rect := Rect2(tip - Vector2(5, 5), Vector2(10, 10))
	for area in _items:
		if not is_instance_valid(area):
			continue
		if not bool(area.get_meta("alive", true)):
			continue
		var shape_node := area.get_child(0) as CollisionShape2D
		var rect_shape := shape_node.shape as RectangleShape2D
		var sz: Vector2 = rect_shape.size
		var rect := Rect2(area.global_position - sz * 0.5, sz)
		if tip_rect.intersects(rect):
			# Align original: score immediately on hit, then retract
			_score += int(area.get_meta("value", 0))
			area.set_meta("alive", false)
			area.visible = false
			shape_node.disabled = true
			_update_hud()
			_state = HookState.RETRACT
			if _score >= _target_score():
				_end_game(true)
			break

func _unhandled_input(event: InputEvent) -> void:
	if _screen != Screen.PLAY or not _alive or _state != HookState.SWING:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_state = HookState.EXTEND
	elif event is InputEventScreenTouch and event.pressed:
		_state = HookState.EXTEND
	elif event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		_state = HookState.EXTEND

func _on_timer_tick() -> void:
	if _screen != Screen.PLAY or not _alive:
		return
	_time_left -= 1
	_update_hud()
	if _time_left <= 0:
		_end_game(_score >= _target_score())

func _end_game(won: bool) -> void:
	_alive = false
	_timer.stop()
	_overlay.visible = true
	if won:
		_over_msg.text = "过关！\n关卡 %d\n分数 %d" % [_level, _score]
		_next.visible = _level < LEVEL_COUNT
		_next.text = "下一关"
	else:
		_over_msg.text = "失败\n分数 %d（目标 %d）" % [_score, _target_score()]
		_next.visible = false
	_retry.visible = true
	_to_select.visible = true

func _on_next_level() -> void:
	if _level < LEVEL_COUNT:
		_start_level(_level + 1)
	else:
		_show_menu()
