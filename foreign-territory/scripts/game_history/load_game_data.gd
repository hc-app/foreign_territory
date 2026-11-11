extends Node

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
		
# Load data
	# Iterate over all sections of the config file and store each section
	var game_data = {}
	for section in config_file.get_sections():
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
		
	# Player open menu and select the "View play history" to view game history
	# Load game data onto "View play history" screen
	
	
	# Player open menu and select the "choose upgrade and items" option to select upgradea and items to use in the new game
	# Load game data onto "Choose upgrade and items" UI
	
	
	
	
