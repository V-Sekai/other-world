extends Node3D

# Function to calculate entropy of a square
func _calculate_entropy(square) -> int:
	return len(square["possible_tiles"])

func _find_lowest_entropy_square(state) -> Variant:
	var min_entropy = INF
	var min_squares = []
	for key in state:
		var square = state[key]
		if len(square["possible_tiles"]) <= 1: # Skip if the square is solved
			continue
		var entropy = len(square["possible_tiles"])
		if entropy < min_entropy:
			min_entropy = entropy
			min_squares = [key]
		elif entropy == min_entropy:
			min_squares.append(key)
	
	if len(min_squares) == 0:
		return null
	
	var chosen_key = min_squares[0]
	return chosen_key

const possible_types = {
	"A": {
		"next": ["A", "B"]
	},
	"B": {
		"next": ["A"]
	}
}

var direction_names = ["next"]

func array_difference(a1: Array, a2: Array) -> Array:
	var diff = []
	for element in a1:
		if element not in a2:
			diff.append(element)
	return diff

func update_possible_tiles(state, coordinates, chosen_tile):
	var todos = []
	if state.has(coordinates) and "possible_tiles" in state[coordinates]:
		var possible_tiles = state[coordinates]["possible_tiles"]
		var difference = array_difference(possible_tiles, possible_types[chosen_tile]["next"])
		todos.append(["remove_possible_tiles", coordinates, difference])
		todos.append(["set_tile_state", coordinates, possible_tiles])
	return todos


const tile_width = 4

func set_tile_state(state, coordinate, chosen_tile) -> Dictionary:
	if state.has(coordinate):
		state[coordinate]["tile"] = chosen_tile
		state[coordinate]["possible_tiles"] = [chosen_tile]
	return state

func remove_possible_tiles(state, coordinate, chosen_tiles: Array) -> Dictionary:
	if state.has(coordinate):
		if state[coordinate].has("possible_tiles"):
			var possible_tiles = state[coordinate]["possible_tiles"]
			for tile in chosen_tiles:
				possible_tiles.erase(tile)
	return state

## Function to find the square with the lowest entropy
func calculate_square(state):
	return _find_lowest_entropy_square(state)

# Function to check if all tiles have a state
func all_tiles_have_state(state):
	for key in state:
		var square = state[key]
		if square["tile"] == null or len(square["possible_tiles"]) != 1: # If a square's tile is null or doesn't have exactly one possible tile, it doesn't have a state yet
			return false
	return true

func collapse_wave_function(state: Dictionary) -> Variant:
	var result = [["set_tile_state"]]
	var key = _find_lowest_entropy_square(state)
	
	if key == null:
		if all_tiles_have_state(state):
			return []
		else:
			print("Contradiction found, restarting...")
			return false
	
	var possible_tiles: Array = state[key]["possible_tiles"]
	possible_tiles.shuffle()
	var chosen_tile = possible_tiles.front()
	possible_tiles.pop_front()
	result[0].append(key)
	result[0].append(chosen_tile)
	return result

## Meta collapse_wave_function
func meta_collapse_wave_function(state):
	if all_tiles_have_state(state):
		return []
	else:
		var new_state = state.duplicate()  # Create a copy of the state to try collapse_wave_function
		
		# Instead of directly calling collapse_wave_function, add it to the todo_list
		var todo_list = [["collapse_wave_function"]]
		
		todo_list.append(["meta_collapse_wave_function"])
		return todo_list

func print_ascii_art(state, width):
	var ascii_art = ""
	for i in range(width):
		for j in range(width):
			if state[i * width + j]["tile"] != null:
				# Use the first letter of the tile type as its symbol
				var symbol = state[i * width + j]["tile"]
				ascii_art += "(" + str(i) + "," + str(j) + "):" + symbol + " "
			else:
				ascii_art += "(" + str(i) + "," + str(j) + "):null "
		ascii_art += "\n"
	print(ascii_art)

func _ready() -> void:
	var planner: Plan = Plan.new()
	var the_domain: Domain = Domain.new()
	planner.current_domain = the_domain

	the_domain.add_actions([set_tile_state, remove_possible_tiles])
	the_domain.add_task_methods("collapse_wave_function", [collapse_wave_function])
	the_domain.add_task_methods("meta_collapse_wave_function", [meta_collapse_wave_function])
	the_domain.add_task_methods("update_possible_tiles", [update_possible_tiles])

	planner.current_domain = the_domain
	planner.verbose = 1

	var state = {}
	for i in range(tile_width):
		for j in range(tile_width):
			state[i * tile_width + j] = {
				"tile": null,
				"possible_tiles": possible_types.keys()
			}
	var wfc_array: Array
	wfc_array.append(["meta_collapse_wave_function"])
	var result = planner.find_plan(state, wfc_array)
	print(result)
	print(state)
	print_ascii_art(state, tile_width)
