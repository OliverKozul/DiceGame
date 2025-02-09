extends Node


var players : Array = []
var current_turn : int = 0
var current_phase : String = "roll"
var current_player_index : int = 0
var player_order : Array = []
var players_rolled : Dictionary = {}  # Stores whether each player has rolled
var players_acted : Dictionary = {}  # Stores whether each player has acted
var players_resolved : Dictionary = {}
var player_info : Dictionary = {}
