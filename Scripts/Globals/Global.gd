extends Node


var current_turn : int = 0
var current_phase : String = "roll"
var current_action_index : int = 0
var action_order : Array = []
var players_rolled = {}  # Stores whether each player has rolled
var players_acted = {}  # Stores whether each player has acted
var player_info = {}
