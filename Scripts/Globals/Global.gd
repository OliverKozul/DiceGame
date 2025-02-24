extends Node


var host_id: int = 1
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

var boss_attackers: Dictionary = {}
var enemy_ids: Dictionary = {
	"Red Dragon": -999,
	"Rat King": 0,
	"Goblin Thief": -1,
	"Vampire Lord": -2,
}
var boss_drops: Array = []
var boss_drop_indices: Array = []
var boss_kills: int = 0
var mob_kills: int = 0

var selected_item_indices: Dictionary = {}
var bid_item_indices: Array = []
var player_bids: Dictionary = {}
var current_bid_item: int = 0

@onready var mobs: Array[Mob] = [
	preload("res://Resources/Enemies/RatKing.tres"), 
	preload("res://Resources/Enemies/GoblinThief.tres"), 
	preload("res://Resources/Enemies/VampireLord.tres")]
@onready var boss: Boss = preload("res://Resources/Enemies/RedDragon.tres")
@onready var default_label_settings = preload("res://Assets/LabelSettings/Default.tres")
