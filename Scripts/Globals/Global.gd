extends Node


var players: Array = []
var player_names: Dictionary = {}
var player_info: Dictionary = {}
var player_order: Array = []

var current_turn: int = 0
var current_phase: String = "roll"
var current_player_index: int = 0

var players_rolled: Dictionary = {}
var players_acted: Dictionary = {}
var players_resolved: Dictionary = {}

var boss_attackers: Array = []

@onready var mob = load("res://Resources/Enemies/RatKing.tres")
@onready var boss = load("res://Resources/Enemies/RedDragon.tres")
