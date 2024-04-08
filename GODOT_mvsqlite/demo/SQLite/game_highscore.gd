extends Node

# Variables
var db;
var highscore = 0;
var row_id = 0;
@onready
var open = false;


func _ready():
	# Create MVSQLite instance
	db = MVSQLite.new()

	# Open the database
	if not db.open("user://player_stats.sqlite"):
		return

	open = true

	# Create table
	var query = "CREATE TABLE IF NOT EXISTS highscore (id INTEGER PRIMARY KEY, score INTEGER NOT NULL);"
	if not db.create_query(query).execute().is_empty():
		return

	# Retrieve current highscore
	var rows = db.fetch_array("SELECT id, score FROM highscore LIMIT 1;");
	if (rows and not rows.is_empty()):
		row_id = rows[0]['id'];
		highscore = rows[0]['score'];

	# Test
	set_highscore(1000)
	set_highscore(2000)
	set_highscore(10000)
	set_highscore(50000)
	print("High score: ", get_highscore())


func _exit_tree():
	if db:
		# Close database
		db.close()


func set_highscore(score):
	if not open:
		return

	# Update highscore
	highscore = score

	# Execute sql syntax
	if row_id > 0:
		db.create_query("UPDATE highscore SET score=? WHERE id=?;").execute([highscore, row_id])
	else:
		db.create_query("INSERT INTO highscore (score) VALUES (?);").execute([row_id])
		var query = db.create_query("SELECT last_insert_rowid()")
		row_id = query.execute([])[0][query.get_columns().find("last_insert_rowid()")]


func get_highscore():
	if not open:
		return

	# Retrieve highscore from database
	var rows = db.fetch_array_with_args("SELECT score FROM highscore WHERE id=? LIMIT 1;", [row_id]);
	if (rows and not rows.is_empty()):
		highscore = rows[0]['score'];

	# Return the highscore
	return highscore
