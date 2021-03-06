tool
extends TileMap

export(int)   var map_w           = 32
export(int)   var map_h           = 32
export(int)   var min_room_size   = 5
export(float, 0.2, 0.75) var min_room_factor = 0.5  # percent of leaf room can occupy (up to three-quarters)
export(bool)  var redraw  setget redraw

enum Tiles { GROUND=-1, ROOF }

var tree       = {}
var leaves     = []
var leaf_id    = 0
var rooms      = []

func _ready():
	redraw()


# warning-ignore:unused_argument
# warning-ignore:function_conflicts_variable
func redraw(value = null):
	# only do this if we are working in the editor
	if !Engine.is_editor_hint(): return

	#generate()


func generate(rng):
	clear()
	fill_roof()
	start_tree()     # Start Generation
	create_leaf(0, rng)   # Create Tree
	create_rooms(rng)   # Create rooms in the leaf leaves of the tree
	join_rooms()     # Ensure all rooms connected
	clear_deadends() # Remove deadend corridors
	update_bitmask_region(Vector2(0, 0), Vector2(map_w, map_h)) # autotile


# start by filling the map with roof tiles
func fill_roof():
	for x in range(0, map_w):
		for y in range(0, map_h):
			set_cell(x, y, Tiles.ROOF)


# First generate a BSP tree of the dungeon
func start_tree():
	rooms     = []
	tree      = {}
	leaves    = []
	leaf_id   = 0

	# Root Leaf is the full map size that we start dividing
	tree[leaf_id] = { "x": 2, "y": 2, "w": map_w-5, "h": map_h-5 }
	leaf_id += 1


# Recursively build the tree by spliting the map into
# rectangles (leaves), that we then place our rooms in
func create_leaf(parent_id, rng):
	var x = tree[parent_id].x
	var y = tree[parent_id].y
	var w = tree[parent_id].w
	var h = tree[parent_id].h

	# used to connect the leaves later
	tree[parent_id].center = { x = floor(x + w/2), y = floor(y + h/2) }

	# whether the tree has space for a split
	var can_split = false

	# randomly split horizontal or vertical
	# if not enough width, split horizontal
	# if not enough height, split vertical
	var split_type = ["h", "v"][rng.randi_range(0, 1)]
	if   (min_room_factor * w < min_room_size):  split_type = "h"
	elif (min_room_factor * h < min_room_size):  split_type = "v"

	var leaf1 = {}
	var leaf2 = {}

	# try and split the current leaf,
	# if the room will fit
	if (split_type == "v"):
		var room_size = min_room_factor * w
		if (room_size >= min_room_size):
			var w1 = rng.randi_range(room_size, (w - room_size) - 1)
			var w2 = w - w1
			leaf1 = { x = x, y = y, w = w1, h = h, split = 'v' }
			leaf2 = { x = x+w1, y = y, w = w2, h = h, split = 'v' }
			can_split = true
	else:
		var room_size = min_room_factor * h
		if (room_size >= min_room_size):
			var h1 = rng.randi_range(room_size, (h - room_size) - 1)
			var h2 = h - h1
			leaf1 = { x = x, y = y, w = w, h = h1, split = 'h' }
			leaf2 = { x = x, y = y+h1, w = w, h = h2, split = 'h' }
			can_split = true

	# rooms fit, lets split
	if (can_split):
		leaf1.parent_id    = parent_id
		tree[leaf_id]      = leaf1
		tree[parent_id].l  = leaf_id
		leaf_id += 1

		leaf2.parent_id    = parent_id
		tree[leaf_id]      = leaf2
		tree[parent_id].r  = leaf_id
		leaf_id += 1

		# append these leaves as branches from the parent
		leaves.append([tree[parent_id].l, tree[parent_id].r])

		# try and create more leaves
		create_leaf(tree[parent_id].l, rng)
		create_leaf(tree[parent_id].r, rng)


# warning-ignore:shadowed_variable
func create_rooms(rng):
	for leaf_id in tree:
		var leaf = tree[leaf_id]
		if leaf.has("l"): continue    # if the node has children, don't build rooms

		if rng.randf() < 0.75:
			var room = {}
			room.id = leaf_id;
			room.w  = rng.randi_range(min_room_size, leaf.w - 1) - 1
			room.h  = rng.randi_range(min_room_size, leaf.h - 1) - 1
			room.x  = leaf.x + floor((leaf.w-room.w)/2) + 1
			room.y  = leaf.y + floor((leaf.h-room.h)/2) + 1
			room.split = leaf.split

			room.center = Vector2()
			room.center.x = floor(room.x + room.w/2)
			room.center.y = floor(room.y + room.h/2)
			rooms.append(room);

	# draw the rooms on the tilemap
	for r in rooms:
		for x in range(r.x, r.x + r.w):
			for y in range(r.y, r.y + r.h):
				set_cell(x, y, Tiles.GROUND)


func join_rooms():
	for sister in leaves:
		var a = sister[0]
		var b = sister[1]
		connect_leaves(tree[a], tree[b])


func connect_leaves(leaf1, leaf2):
	var x = min(leaf1.center.x, leaf2.center.x)
	var y = min(leaf1.center.y, leaf2.center.y)
	var w = 1
	var h = 1

	# Vertical corridor
	if (leaf1.split == 'h'):
		x -= floor(w/2)+1
		h = abs(leaf1.center.y - leaf2.center.y)
	else:
		# Horizontal corridor
		y -= floor(h/2)+1
		w = abs(leaf1.center.x - leaf2.center.x)

	# Ensure within map
	x = 0 if (x < 0) else x
	y = 0 if (y < 0) else y

	for i in range(x, x+w):
		for j in range(y, y+h):
			if(get_cell(i, j) == Tiles.ROOF): set_cell(i, j, Tiles.GROUND)


func clear_deadends():
	var done = false

	while !done:
		done = true

		for x in range(0, map_w):
			for y in range(0, map_h):
				if get_cell(x, y) == Tiles.ROOF:
					continue

				var roof_count = check_nearby(x, y)
				if roof_count == 3:
					set_cell(x, y, Tiles.ROOF)
					done = false


# check in 4 dirs to see how many tiles are roofs
func check_nearby(x, y):
	var count = 0
	if get_cell(x, y-1)   == Tiles.ROOF:  count += 1
	if get_cell(x, y+1)   == Tiles.ROOF:  count += 1
	if get_cell(x-1, y)   == Tiles.ROOF:  count += 1
	if get_cell(x+1, y)   == Tiles.ROOF:  count += 1
	return count
