extends Node2D


export(int) var game_seed = 0
export(int) var pan_speed = 8
export(Vector2) var half_view = Vector2(640, 360)

onready var player = $Player
onready var world = $World
onready var world_size = $World.world_size


func _ready():
	if game_seed:
		$Start.find_node("Seed").text = String(game_seed)
	show_dialog($Start)


func show_dialog(dialog):
	world.set_visible(false)
	view_to(half_view, 0)
	dialog.popup_centered()


# TODO: need to instantiate Player here, taking care with render order
func new(depth=0):
	$Start.set_visible(false)
	world.set_visible(true)
	if depth:
		world.world_depth = depth
	seed(game_seed)
	$View.find_node("Seed").set_value(game_seed)
	change_level(world.create(player))
	world.set_value("Turn", 1, true)
	player.turn()
	player.update()


const view_map = {
	ui_up = Vector2(0, -1),
	ui_down = Vector2(0, 1),
	ui_left = Vector2(-1, 0),
	ui_right = Vector2(1, 0)
}
# warning-ignore:unused_argument
func _process(_delta):
	if not world.active_level:
		return
	var position = $View.position
	for e in view_map:
		if Input.is_action_pressed(e):
			position += pan_speed * view_map[e]
	view_to(position, 0)
	if world.target and world.turn > world.target:
		timed_out()
	if world.turn % 2:
		if player.get_state() == Robot.DONE:
			world.turn += 1
			world.set_value("Moves", 0, true)
			var dead = 0
			for r in world.active_level.rogues:
				if r.turn():
					dead += 1
			if dead == len(world.active_level.rogues):
				if not world.active_level.state & Level.CLEAR:
					world.active_level.state |= Level.CLEAR
					world.check_end()
	else:
		for r in world.active_level.rogues:
			var state = r.get_state()
			if state == Robot.IDLE or state == Robot.WAIT:
				return
		if player.turn():
			$Lose.window_title = "You have been deactivated!"
			game_over(false)
		player.update()
		world.turn += 1
		world.set_value("Turn", (world.turn + 1) / 2, true)


const cursor_map = {
	cursor_up = Vector2(0, -1),
	cursor_down = Vector2(0, 1),
	cursor_left = Vector2(-1, 0),
	cursor_right = Vector2(1, 0)
}
func _unhandled_input(event):
	if event is InputEventKey and event.pressed:
		var level = null
		if event.control:
			match event.scancode:
				KEY_S:
					_on_Save_pressed()
				KEY_R:
					_on_Restart_pressed()
				KEY_Q:
					_on_Quit_pressed()
		match event.scancode:
			KEY_U:
				level = world.active_level.parent
			KEY_O:
				level = world.active_level.children[0]
			KEY_P:
				level = world.active_level.children[1]
		if level:
			change_level(level)
	if world.active_level == null:
		return
	var move = Vector2.ZERO
	for e in cursor_map:
		if event.is_action_pressed(e, true):
			move += cursor_map[e]
	if move != Vector2.ZERO:
		world.active_level.move_cursor(move)
	if event.is_action_pressed("map_reset"):
		view_to(player.position)
		return
	if event.is_action_pressed("cursor_reset"):
		world.active_level.set_cursor(player.location)
		return


func change_level(level):
	if not level:
		if world.level_one.is_clear():
			game_over(true)
	if level != world.active_level:
		world.change_level(level)
	player.change_level(level)
	view_to(player.position)


func view_to(position, offset=180):
	$View.position = Vector2(
		clamp(position.x + offset, 0, world_size.x),
		clamp(position.y, 0, world_size.y))


func load_game():
	var depth = 7
	var save_game = File.new()
	if save_game.file_exists("user://robolike.save"):
		depth = save_game.get_32()
		game_seed = save_game.get_32()
		save_game.close()
	new(depth)


func save_game():
	var save_game = File.new()
	save_game.open("user://robolike.save", File.WRITE)
	save_game.store_32(world.world_depth)
	save_game.store_32(game_seed)
	save_game.close()


func game_over(success):
	var popup = $Win if success else $Lose
	var messages = PoolStringArray()
	if success:
		messages.append("You succeeded!\n")
	else:
		messages.append("You failed \u2639")
	var stats = {
		"levels reset": 0,
		"levels cleared": 0,
		"rogues deactivated": 0,
	}
	gather_stats(world.level_one, stats)
	for stat in stats:
		messages.append("%s: %s" % [stat, stats[stat]])
	popup.dialog_text = messages.join("\n")
	show_dialog(popup)


func gather_stats(level, acc):
	if level.state & Level.RESET:
		acc["levels reset"] += 1
	if level.state & Level.CLEAR:
		acc["levels cleared"] += 1
	for r in level.rogues:
		if r.get_state() == Robot.DEAD:
			acc["rogues deactivated"] += 1
	if level.children:
		for child in level.children:
			if child:
				gather_stats(child, acc)


func timed_out():
	world.show_info("""Turn %d

Systems rebooting ...

All robots in the facility will be wiped.
""" % ((world.turn + 1) / 2))
	$Lose.window_title = "Facility systems reboot!"
	game_over(false)


func _on_Resume_pressed():
	load_game()


func _on_New_pressed():
	var seed_text = $Start.find_node("Seed").text
	game_seed = seed_text.to_int() if seed_text.is_valid_integer() else seed_text.hash()
	var depth = $Start.find_node("Depth").value
	new(depth)


func _on_Random_pressed():
	randomize()
	$Start.find_node("Seed").text = String(randi())


func _on_Save_pressed():
	save_game()


func _on_Restart_pressed():
	save_game()
	show_dialog($Start)


func _on_Quit_pressed():
	show_dialog($Quit)


func _on_Quit_confirmed():
	get_tree().quit()


func _on_Quit_popup_hide():
	view_to(player.position)
	world.set_visible(true)


func _on_game_over():
	# TODO: should be restart
	get_tree().quit()
