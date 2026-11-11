extends Node

# Player completed game or exited current run. Save game data.

# //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
## When the player starts a new game, track the number of times they have played
#"runs_played": 0,
#
## During the game track the type of enemies and bosses defeated
#"enemy_01_defeated": 0,
#"enemies_defeated": 0,
#"boss_01_defeated": 0,
#"bosses_defeated": 0,
#
## When the player completes a game, track the upgrades and items earned so they can choose them at the next game
## Track the number of games completed and if it is the fastest time or highest score  
#"upgrades_earned" : [],
#"items_earned" : [],
#"runs_completed": 0,
#"fastest_run": 0,
#"highest_score": 0,
# //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

func _ready():
	var save_path = "res://game_data.cfg"
	if !FileAccess.file_exists(save_path):
		print("No save file found. Creating a new one...")
		
		# Create new ConfigFile object.
		var new_config_file = ConfigFile.new()
		
		# Store data in game_history section
		new_config_file.set_value("game_history", "upgrades_earned", [])
		new_config_file.set_value("game_history", "items_earned", [])
		new_config_file.set_value("game_history", "runs_played", 0)
		new_config_file.set_value("game_history", "runs_completed", 0)
		new_config_file.set_value("game_history", "fastest_run", INF)
		new_config_file.set_value("game_history", "enemy_01_defeated", 0)
		new_config_file.set_value("game_history", "enemies_defeated", 0)
		new_config_file.set_value("game_history", "boss_01_defeated", 0)
		new_config_file.set_value("game_history", "bosses_defeated", 0)
		new_config_file.set_value("game_history", "highest_score", 0)
		
		# Save it to a file (overwrite if already exists).
		new_config_file.save("res://game_data.cfg")
		
	# Load data from a file.
	var config_file = ConfigFile.new()
	var load_status = config_file.load("res://game_data.cfg")
	
	# If the file didn't load.
	if load_status != OK:
		print("Game data file didn't load.")
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
	
	var current_game_upgrades_earned = []		# get from World scene
	var current_game_items_earned = []			# get from World scene

	var game_data = {}
	
	# Load and update game data with current game data
	# Iterate over all sections of the config file and store each section	
	for section in config_file.get_sections():
		#Load game data
		game_data = {
		"upgrades_earned" : config_file.get_value(section, "upgrades_earned", []),
		"items_earned" : config_file.get_value(section, "items_earned", []),
		"runs_played" : config_file.get_value(section, "runs_played"),
		"runs_completed" : config_file.get_value(section, "runs_completed"),
		"fastest_run" : config_file.get_value(section, "fastest_run"),
		"enemy_01_defeated" : config_file.get_value(section, "enemy_01_defeated"),
		"enemies_defeated" : config_file.get_value(section, "enemies_defeated"),
		"boss_01_defeated" : config_file.get_value(section, "boss_01_defeated"),
		"bosses_defeated" : config_file.get_value(section, "bosses_defeated"),
		"highest_score" : config_file.get_value(section, "highest_score")
		}
		
		# Update game data with current game data
		current_game_upgrades_earned.map(
			func(upgrade):
				if not game_data["upgrades_earned"].has(upgrade):
					game_data["upgrades_earned"].push(upgrade)
		)
		
		current_game_items_earned.map(
			func(item):
				if not game_data["upgrades_earned"].has(item):
					game_data["upgrades_earned"].push(item)
				else:
					game_data["upgrades_earned"][item].quantity += 1 		# item object should have a property to track quantity  
		)
		
		game_data["runs_played"] += 1
		if (current_game_run_completed):
			game_data["runs_completed"] += 1
		if (current_game_time_completed < game_data["fastest_run"]):
			game_data["fastest_run"] = current_game_time_completed
		game_data["enemy_01_defeated"] += current_game_enemies_01_defeated
		game_data["enemies_defeated"] += current_game_enemies_defeated
		game_data["boss_01_defeated"] += current_game_bosses_01_defeated
		game_data["bosses_defeated"] += current_game_bosses_defeated
		if (current_game_score > game_data["highest_score"]):
			game_data["highest_score"] = current_game_score
	
	
	# /////////////////////////////////////////////////////////////
	
	# Store data
	
	# Create new ConfigFile object.
	var updated_config_file = ConfigFile.new()
	
	# Store data in game_history section
	updated_config_file.set_value("game_history", "upgrades_earned", game_data["upgrades_earned"])
	updated_config_file.set_value("game_history", "items_earned", game_data["items_earned"])
	updated_config_file.set_value("game_history", "runs_played", game_data["runs_played"])
	updated_config_file.set_value("game_history", "runs_completed", game_data["runs_completed"])
	updated_config_file.set_value("game_history", "fastest_run", game_data["fastest_run"])
	updated_config_file.set_value("game_history", "enemy_01_defeated", game_data["enemy_01_defeated"])
	updated_config_file.set_value("game_history", "enemies_defeated", game_data["enemies_defeated"])
	updated_config_file.set_value("game_history", "boss_01_defeated", game_data["boss_01_defeated"])
	updated_config_file.set_value("game_history", "bosses_defeated", game_data["bosses_defeated"])
	updated_config_file.set_value("game_history", "highest_score", game_data["highest_score"])
	
	
	# Save it to a file (overwrite if already exists).
	updated_config_file.save("res://game_data.cfg")
	# config.save_encrypted_pass("res://gane_data.cfg")
	

# //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

	## Save file variables
	#var upgrades_earned
	#var items_earned
	#var runs_played
	#var runs_completed
	#var fastest_run
	#var enemy_01_defeated
	#var enemies_defeated
	#var boss_01_defeated
	#var bosses_defeated
	#var highest_score	
	
	
		## Fetch the data for each section.
		#upgrades_earned = config_file.get_value(section, "upgrades_earned", [])
		#items_earned = config_file.get_value(section, "items_earned", [])
		#runs_played = config_file.get_value(section, "runs_played")
		#runs_completed = config_file.get_value(section, "runs_completed")
		#fastest_run = config_file.get_value(section, "fastest_run")
		#enemy_01_defeated = config_file.get_value(section, "enemy_01_defeated")
		#enemies_defeated = config_file.get_value(section, "enemies_defeated")
		#boss_01_defeated = config_file.get_value(section, "boss_01_defeated")
		#bosses_defeated = config_file.get_value(section, "bosses_defeated")
		#highest_score = config_file.get_value(section, "highest_score")
		#
		#upgrades_earned.push()
		#items_earned.push()
		#runs_played += 1
		#if (current_run < fastest_run):
			#fastest_run = current_run
		#enemy_01_defeated += current_enemies_01_defeated
		#enemies_defeated += enemies_defeated
		#boss_01_defeated += current_bosses_01_defeated
		#bosses_defeated += bosses_defeated
		#if (current_score > highest_score):
			#highest_score = current_score

	## Store data in game_history section
	#updated_config_file.set_value("game_history", "upgrades_earned", upgrades_earned)
	#updated_config_file.set_value("game_history", "items_earned", items_earned)
	#updated_config_file.set_value("game_history", "runs_played", runs_played)
	#updated_config_file.set_value("game_history", "runs_completed", runs_completed)
	#updated_config_file.set_value("game_history", "fastest_run", fastest_run)
	#updated_config_file.set_value("game_history", "enemy_01_defeated", enemy_01_defeated)
	#updated_config_file.set_value("game_history", "enemies_defeated", enemies_defeated)
	#updated_config_file.set_value("game_history", "boss_01_defeated", boss_01_defeated)
	#updated_config_file.set_value("game_history", "bosses_defeated", bosses_defeated)
	#updated_config_file.set_value("game_history", "highest_score", highest_score)
