extends CanvasLayer
class_name PlayerUI


@onready var current_player_label = %CurrentPlayerLabel
@onready var status_labels: StatusLabels = %StatusLabels
@onready var player_intention_labels: PlayerIntentionLabels = %PlayerIntentionLabels
@onready var turn_info_labels: TurnInfoLabels = %TurnInfoLabels
@onready var buttons: Buttons = %Buttons
@onready var combat_distribution: CombatDistribution = %CombatDistribution
@onready var loot_distribution: LootDistribution = %LootDistribution
@onready var bid_distribution: BidDistribution = %BidDistribution
@onready var shop: Shop = %Shop
@onready var trinkets_ui: TrinketsUI = %TrinketsUI
@onready var dice_ui: DiceUI = %DiceUI
@onready var defeat_screen: ColorRect = %DefeatScreen
@onready var victory_screen: ColorRect = %VictoryScreen

@onready var roll_manager: RollManager = %RollManager
@onready var sync_manager: SyncManager = %SyncManager
@onready var turn_manager: TurnManager = %TurnManager
@onready var intention_manager: IntentionManager = %IntentionManager
@onready var action_manager: ActionManager = %ActionManager
@onready var resolve_manager: ResolveManager = %ResolveManager
@onready var button_manager: ButtonManager = %ButtonManager
@onready var trinket_manager: TrinketManager = %TrinketManager
@onready var combat_manager: CombatManager = %CombatManager

var player_info_uis: Dictionary = {}
var player_info_ui_scene: PackedScene = preload("res://Scenes/PlayerInfoUI.tscn")

signal update_all_status_labels


func _ready() -> void:
	var player_id = multiplayer.get_unique_id()
	initialize(player_id)

	if multiplayer.is_server():
		Global.current_turn = 1
		sync_manager.rpc("sync_turn", Global.current_turn)
		player_intention_labels.rpc("update_players")

func initialize(player_id: int) -> void:
	for id in Global.player_order:
		if not Global.player_info.has(id):
			Global.player_info[id] = {
				"gold": 0,
				"cunning": 0,
				"combat": 0,
				"hp": 25,
				"trinkets": [],
				"die_faces": [["⚔", "⚔", "⚔", "💰", "💰", "🧠"], ["⚔", "⚔", "💰", "💰", "💰", "🧠"]],
				#"die_faces": [["⚔", "⚔", "⚔", "⚔", "⚔", "⚔"]],
				"die_face_values": [{"⚔": 1, "💰": 1, "🧠": 1}],
			}
		
	status_labels.initialize(self, player_id)
	player_intention_labels.initialize(self)
	turn_info_labels.initialize(self)
	buttons.initialize(self)
	combat_distribution.initialize(self)
	loot_distribution.initialize(self)
	bid_distribution.initialize(self)
	shop.initialize(self, player_id)
	trinkets_ui.initialize(self, player_id)
	dice_ui.initialize(self, player_id)
	
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
		
	create_player_info_ui()
	
func create_player_info_ui() -> void:
	for player_id in Global.player_order:
		var player_info_ui: PlayerInfoUI = player_info_ui_scene.instantiate()
		player_info_ui.visible = false
		add_child(player_info_ui)
		player_info_ui.initialize(self, player_id)
		player_info_uis[player_id] = player_info_ui
	
@rpc("any_peer", "call_local", "reliable")
func show_defeat_ui(player_id: int) -> void:
	turn_info_labels.roll_results[player_id].text = Global.player_names[player_id] + " is dead."
	
	if player_id == multiplayer.get_unique_id():
		defeat_screen.show()
		
@rpc("any_peer", "call_local", "reliable")
func show_victory_ui() -> void:
	victory_screen.show()
