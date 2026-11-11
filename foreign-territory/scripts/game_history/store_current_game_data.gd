extends Node

# //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
# During the game track:
# 	Type of enemies defeated
#	Bosses defeated
# 	Upgrades earned
#	Items earned
# 	Current run time 
#	Current score
#	if the current run was completed

var current_game_data = {
	"enemy_01_defeated": 0,
	"enemies_defeated": 0,
	"boss_01_defeated": 0,
	"bosses_defeated": 0,
	"upgrades_earned" : [],
	"items_earned" : [],
	"run_completed": false,
	"run_time": 0,
	"score": 0,
	}

signal enemy_defeated(type)
signal boss_defeated(type)

var enemies_defeated = []
var bosses_defeated = []

var upgrades_earned = []
var items_earned = []

var score = 0


var time_elapsed: float = 0.0
var game_paused = false

# //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

func _ready():
	var save_path = "res://current_game_data.cfg"
	if !FileAccess.file_exists(save_path):
		print("No save file found. Creating a new one...")
		
		# Create new ConfigFile object.
		var new_config_file = ConfigFile.new()
		
		# Store data in game_history section
		new_config_file.set_value("curent_game_history", "upgrades_earned", [])
		new_config_file.set_value("curent_game_history", "items_earned", [])
		#new_config_file.set_value("game_history", "runs_played", 0)
		#new_config_file.set_value("game_history", "runs_completed", 0)
		new_config_file.set_value("curent_game_history", "run_time", 0)
		new_config_file.set_value("curent_game_history", "enemy_01_defeated", 0)
		new_config_file.set_value("curent_game_history", "enemies_defeated", 0)
		new_config_file.set_value("curent_game_history", "boss_01_defeated", 0)
		new_config_file.set_value("curent_game_history", "bosses_defeated", 0)
		new_config_file.set_value("curent_game_history", "score", 0)
		
		# Save it to a file (overwrite if already exists).
		new_config_file.save("res://current_game_data.cfg")
		
	# Load data from a file.
	var config_file = ConfigFile.new()
	var load_status = config_file.load("res://current_game_data.cfg")
	
	# If the file didn't load.
	if load_status != OK:
		print("Current game data file didn't load.")
		return
	
		# /////////////////////////////////////////////////////////////
	# Current run data ///////////////// 
	var current_game_run_completed = true		# get from World scene
	
	var current_game_time_completed = 0 		# get from World scene
	var current_game_score = 0					# get from World scene

	var current_game_enemies_01_defeated = 0	# get from World scene
	var current_game_enemies_defeated = 0		# get from World scene
	var current_game_bosses_01_defeated = 0		# get from World scene
	var current_game_bosses_defeated = 0		# get from World scene

	var game_data = {}
	
	
	# Load data
	# Iterate over all sections of the config file and store each section	
	for section in config_file.get_sections():
		game_data = {
		"upgrades_earned" : config_file.get_value(section, "upgrades_earned", []),
		"items_earned" : config_file.get_value(section, "items_earned", []),
		#"runs_played" : config_file.get_value(section, "runs_played"),
		#"runs_completed" : config_file.get_value(section, "runs_completed"),
		"run_time" : config_file.get_value(section, "run_time"),
		"enemy_01_defeated" : config_file.get_value(section, "enemy_01_defeated"),
		"enemies_defeated" : config_file.get_value(section, "enemies_defeated"),
		"boss_01_defeated" : config_file.get_value(section, "boss_01_defeated"),
		"bosses_defeated" : config_file.get_value(section, "bosses_defeated"),
		"score" : config_file.get_value(section, "score")
		}
		
		game_data["upgrades_earned"].push() 	#///////////////////////
		game_data["items_earned"].push()		#///////////////////////
		game_data["runs_played"] += 1
		if (current_game_run_completed):
			game_data["runs_completed"] += 1
		if (current_game_time_completed < game_data["fastest_run"]):
			game_data["run_time"] = current_game_time_completed
		game_data["enemy_01_defeated"] += current_game_enemies_01_defeated
		game_data["enemies_defeated"] += current_game_enemies_defeated
		game_data["boss_01_defeated"] += current_game_bosses_01_defeated
		game_data["bosses_defeated"] += current_game_bosses_defeated
		if (current_game_score > game_data["score"]):
			game_data["score"] = current_game_score
	
	
	# /////////////////////////////////////////////////////////////
	
	# Store data
	
	# Create new ConfigFile object.
	var updated_config_file = ConfigFile.new()
	
	# Store data in game_history section
	updated_config_file.set_value("curent_game_history", "upgrades_earned", game_data["upgrades_earned"])
	updated_config_file.set_value("curent_game_history", "items_earned", game_data["items_earned"])
	updated_config_file.set_value("curent_game_history", "run_time", game_data["run_time"])
	updated_config_file.set_value("curent_game_history", "enemy_01_defeated", game_data["enemy_01_defeated"])
	updated_config_file.set_value("curent_game_history", "enemies_defeated", game_data["enemies_defeated"])
	updated_config_file.set_value("curent_game_history", "boss_01_defeated", game_data["boss_01_defeated"])
	updated_config_file.set_value("curent_game_history", "bosses_defeated", game_data["bosses_defeated"])
	updated_config_file.set_value("curent_game_history", "score", game_data["score"])
	
	
	# Save it to a file (overwrite if already exists).
	updated_config_file.save("res://current_game_data.cfg")
	# config.save_encrypted_pass("res://gane_data.cfg")

func _process(delta: float) -> void:
	
	#////////////////////////////////////////////////////////////////////////////////
	
	# Game time elapsed
	if !game_paused:
		time_elapsed += delta
	
	#////////////////////////////////////////////////////////////////////////////////
	
	# Enemies defeated
	if len(enemies_defeated) > 0:
		# Update score
		score += enemies_defeated.reduce(func(acc, enemy): return acc + enemy.score, 0)
		
		# Update enemies defeated and enemy type defeated
		current_game_data["enemies_defeated"] += len(enemies_defeated)
		enemies_defeated.map(
			func(enemy): 
				match enemy.type:
					"enemy_01" :
						current_game_data["enemy_01"] += 1
					"enemy_02" :
						current_game_data["enemy_02"] += 1
					"enemy_03" :
						current_game_data["enemy_03"] += 1
					"enemy_04" :
						current_game_data["enemy_04"] += 1
					"enemy_05" :
						current_game_data["enemy_05"] += 1
		)
		
		enemies_defeated.clear()
	
	# Bosses defeated
	if len(bosses_defeated) > 0:
		# Update score
		score += bosses_defeated.reduce(func(acc, boss): return acc + boss.score, 0)
		
		# Update enemies defeated and enemy type defeated
		current_game_data["bosses_defeated"] += len(bosses_defeated)
		bosses_defeated.map(
			func(boss): 
				match boss.type:
					"boss_01" :
						current_game_data["boss_01"] += 1
					"boss_02" :
						current_game_data["boss_02"] += 1
					"boss_03" :
						current_game_data["boss_03"] += 1
					"boss_04" :
						current_game_data["enemy_04"] += 1
					"boss_05" :
						current_game_data["boss_05"] += 1
		)
		
		bosses_defeated.clear()
	
	#////////////////////////////////////////////////////////////////////////////////
	
	# Upgrades earned
	
	
	
	# Items earned
	
	
	
