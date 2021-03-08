class_name Robot
extends Node2D


var location = Vector2.ZERO
var level = null
var base = "2"
var state = "Idle"
var facing = Vector2.DOWN
var sprite = null
var weapon = null
var equipment = {
	weapon = null,
	extras = []
}
var stats = {}


const facing_map = {
	Vector2.DOWN: "Down",
	Vector2.UP: "Up",
	Vector2.LEFT: "Left",
	Vector2.RIGHT: "Right",
}
func set_sprite(dead=false):
	if sprite:
		sprite.set_visible(false)
	var path = "%s/%s" % [state, facing_map[facing]]
	var robot = "Dead" if dead else base
	if equipment.extras:
		robot += "-X"
	if not dead:
		path = "Robot/%s/%s" % [robot, path]
	sprite = get_node(path)
	sprite.set_visible(true)
	if dead or equipment["weapon"] == null:
		if weapon:
			weapon.set_visible(false)
			weapon = null
		return
	weapon = get_node("Weapons/%s/%s" % [equipment["weapon"], path])
	weapon.set_visible(true)


func set_location(destination):
	location = destination
	position = level.location_to_position(location)


func move(movement):
	facing = movement
	set_sprite()