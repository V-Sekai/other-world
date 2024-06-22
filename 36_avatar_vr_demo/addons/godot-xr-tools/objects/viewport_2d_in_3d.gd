@tool
extends Node3D


## XR ToolsViewport 2D in 3D
##
## This script manages a 2D scene rendered as a texture on a 3D quad.
##
## Pointer and keyboard input are mapped into the 2D scene.


signal pointer_entered
signal pointer_exited


## Transparent property
enum TransparancyMode {
	OPAQUE,
	TRANSPARENT,
	SCISSOR
}

## Viewport Update Mode
enum UpdateMode {
	UPDATE_ONCE, ## Note, even if already set to ONCE, if you assign the property again, it will trigger a single redraw
	UPDATE_ALWAYS,
	UPDATE_THROTTLED
}


## Viewport enabled property
@export var enabled : bool = true: set = set_enabled

## Screen size property
@export var screen_size : Vector2 = Vector2(3.0, 2.0): set = set_screen_size

## Viewport size property
@export var viewport_size : Vector2 = Vector2(300.0, 200.0): set = set_viewport_size

## Transparent property
@export var transparent : TransparancyMode = TransparancyMode.TRANSPARENT: set = set_transparent

## Alpha Scissor Threshold property
@export var alpha_scissor_threshold : float = 0.25: set = set_alpha_scissor_threshold

## Unshaded
@export var unshaded : bool = false: set = set_unshaded

## Scene property
@export var scene : PackedScene: set = set_scene

## Display properties
@export var filter : bool = true: set = set_filter

## Update Mode property
@export var update_mode : UpdateMode = UpdateMode.UPDATE_ALWAYS: set = set_update_mode

## Update throttle property
@export var throttle_fps : float = 30.0


## Collision layer
@export_flags_3d_physics var collision_layer : int = 15: set = set_collision_layer


var is_ready : bool = false
var scene_node : Node
var viewport_texture : ViewportTexture
var material : StandardMaterial3D
var time_since_last_update : float = 0.0


# Called when the node enters the scene tree for the first time.
func _ready():
	is_ready = true

	# Setup our viewport texture and material
	material = StandardMaterial3D.new()
	material.flags_unshaded = true
	material.params_cull_mode = StandardMaterial3D.CULL_DISABLED
	$Screen.set_surface_override_material(0, material)

	# apply properties
	_update_enabled()
	_update_screen_size()
	_update_viewport_size()
	_update_collision_layer()
	_update_scene()
	# _update_filter() ## already called from _update_viewport_size
	_update_update_mode()
	_update_collision_layer()
	_update_transparent()
	_update_unshaded()


# Get the 2D scene instance
func get_scene_instance():
	return scene_node


# Connect a 2D scene signal
func connect_scene_signal(which, on, callback):
	if scene_node:
		scene_node.connect(which, on, callback)


# Handler for pointer entered
func _on_pointer_entered():
	emit_signal("pointer_entered")


# Handler for pointer exited
func _on_pointer_exited():
	emit_signal("pointer_exited")


# Handler for input eventsd
func _input(event):
	$Viewport.push_input(event)

# Process event
func _process(delta):
	if Engine.is_editor_hint():
		# Don't run in editor (will auto run on load)
		set_process(false)
		return

	if update_mode == UpdateMode.UPDATE_THROTTLED:
		var frame_time = 1.0 / throttle_fps
		time_since_last_update += delta
		if time_since_last_update > frame_time:
			# Trigger update
			$Viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
			time_since_last_update = 0.0
	else:
		# This is no longer needed
		set_process(false)

# Set enabled property
func set_enabled(is_enabled: bool) -> void:
	enabled = is_enabled
	if is_ready:
		_update_enabled()


# Set screen size property
func set_screen_size(new_size: Vector2) -> void:
	screen_size = new_size
	if is_ready:
		_update_screen_size()


# Set viewport size property
func set_viewport_size(new_size: Vector2) -> void:
	viewport_size = new_size
	if is_ready:
		_update_viewport_size()


# Set transparent property
func set_transparent(new_transparent: TransparancyMode) -> void:
	transparent = new_transparent
	if is_ready:
		_update_transparent()


# Set the alpha scisser threshold
func set_alpha_scissor_threshold(new_threshold: float) -> void:
	alpha_scissor_threshold = new_threshold
	if is_ready:
		_update_transparent()


# Set the unshaded property
func set_unshaded(new_unshaded : bool) -> void:
	unshaded = new_unshaded
	if is_ready:
		_update_unshaded()


# Set scene property
func set_scene(new_scene: PackedScene) -> void:
	scene = new_scene
	if is_ready:
		_update_scene()


# Set filter property
func set_filter(new_filter: bool) -> void:
	filter = new_filter
	if is_ready:
		_update_filter()

# Set update mode property
func set_update_mode(new_update_mode: UpdateMode) -> void:
	update_mode = new_update_mode
	if is_ready:
		_update_update_mode()


# Set collision layer property
func set_collision_layer(new_layer: int) -> void:
	collision_layer = new_layer
	if is_ready:
		_update_collision_layer()


# Enabled update handler
func _update_enabled() -> void:
	if Engine.is_editor_hint():
		return

	$StaticBody3D/CollisionShape3D.disabled = !enabled


# Screen size update handler
func _update_screen_size() -> void:
	$Screen.mesh.size = screen_size
	$StaticBody3D.screen_size = screen_size
	$StaticBody3D/CollisionShape3D.shape.extents = Vector3(screen_size.x * 0.5, screen_size.y * 0.5, 0.01)


# Viewport size update handler
func _update_viewport_size() -> void:
	$Viewport.size = viewport_size
	$StaticBody3D.viewport_size = viewport_size

	# Update our viewport texture, it will have changed
	viewport_texture = $Viewport.get_texture()
	if material:
		material.albedo_texture = viewport_texture
	_update_filter()


# Transparent update handler
func _update_transparent() -> void:
	if material:
		material.flags_transparent = transparent != TransparancyMode.OPAQUE
		material.params_use_alpha_scissor = transparent == TransparancyMode.SCISSOR
		if transparent == TransparancyMode.SCISSOR:
			material.params_alpha_scissor_threshold = alpha_scissor_threshold
	$Viewport.transparent_bg = transparent != TransparancyMode.OPAQUE

	# make sure we redraw the screen atleast once
	if Engine.is_editor_hint() or update_mode == UpdateMode.UPDATE_ONCE:
		# this will trigger redrawing our screen
		$Viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


# Unshaded update handler
func _update_unshaded() -> void:
	if material:
		material.flags_unshaded = unshaded

	# make sure we redraw the screen atleast once
	if Engine.is_editor_hint() or update_mode == UpdateMode.UPDATE_ONCE:
		# this will trigger redrawing our screen
		$Viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


# Scene update handler
func _update_scene() -> void:
	# out with the old
	if scene_node:
		$Viewport.remove_child(scene_node)
		scene_node.queue_free()

	# in with the new
	if scene:
		scene_node = scene.instantiate()
		$Viewport.add_child(scene_node)

	# make sure we update atleast once
	$Viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


# Filter update handler
func _update_filter() -> void:
	if material:
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR if filter else 0

	# make sure we redraw the screen atleast once
	if Engine.is_editor_hint() or update_mode == UpdateMode.UPDATE_ONCE:
		# this will trigger redrawing our screen
		$Viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


# Update mode handler
func _update_update_mode() -> void:
	if Engine.is_editor_hint():
		$Viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		return

	if update_mode == UpdateMode.UPDATE_ONCE:
		# this will trigger redrawing our screen
		$Viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		set_process(false)
	elif update_mode == UpdateMode.UPDATE_ALWAYS:
		# redraw screen every frame
		$Viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		set_process(false)
	elif update_mode == UpdateMode.UPDATE_THROTTLED:
		# we will attempt to update the screen at the given framerate
		$Viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		set_process(true)


# Collision layer update handler
func _update_collision_layer() -> void:
	$StaticBody3D.collision_layer = collision_layer
