extends CanvasLayer


@onready var current_player_label = %CurrentPlayerLabel
@onready var status_labels = %StatusLabels
@onready var player_intention_labels = %PlayerIntentionLabels
@onready var turn_info_labels = %TurnInfoLabels
@onready var buttons = %Buttons
@onready var combat_distribution = %CombatDistribution
@onready var shop = %Shop
@onready var defeat_screen: ColorRect = %DefeatScreen
@onready var victory_screen: ColorRect = %VictoryScreen

@onready var roll_manager = %RollManager
@onready var sync_manager = %SyncManager
@onready var turn_manager = %TurnManager
@onready var intention_manager = %IntentionManager
@onready var action_manager = %ActionManager
@onready var resolve_manager = %ResolveManager
@onready var button_manager = %ButtonManager
@onready var trinket_manager = %TrinketManager
@onready var combat_manager: Node = %CombatManager

var rng = RandomNumberGenerator.new()

signal update_all_status_labels


func _ready() -> void:
	var player_id = multiplayer.get_unique_id()
	#rng.seed = 32  # Set the seed to 0
	initialize(player_id)

	if multiplayer.is_server():
		Global.current_turn = 1
	else:
		turn_manager.rpc_id(1, "request_turn_sync")

func initialize(player_id: int) -> void:
	if not Global.player_info.has(player_id):
		Global.player_info[player_id] = {
			"gold": 0,
			"cunning": 0,
			"combat": 0,
			"hp": 10,
			"trinkets": [],
			#"die_faces": ["⚔", "⚔", "💰", "💰", "🧠", "🧠"],
			"die_faces": ["⚔", "⚔", "⚔", "⚔", "⚔", "⚔"],
			"die_face_values": {"⚔": 1, "💰": 1, "🧠": 1}
		}
		
	status_labels.initialize(self, player_id)
	turn_info_labels.initialize(self, player_id)
	buttons.initialize(self)
	combat_distribution.initialize(self)
	shop.initialize(self, player_id)
	
	roll_manager.initialize(self)
	sync_manager.initialize(self)
	turn_manager.initialize(self)
	intention_manager.initialize(self)
	action_manager.initialize(self)
	resolve_manager.initialize(self)
	button_manager.initialize(self)
	trinket_manager.initialize(self)
	combat_manager.initialize(self)
	
	current_player_label.text = "Roll the dice!"
	
@rpc("any_peer", "call_local")
func show_defeat_ui(player_id: int) -> void:
	if player_id == multiplayer.get_unique_id():
		defeat_screen.show()
		
@rpc("any_peer", "call_local")
func show_victory_ui() -> void:
	victory_screen.show()
