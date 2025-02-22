class_name BidDistribution
extends MarginContainer


@onready var bid_label: Label = %BidLabel
@onready var bid_amount: TextEdit = %BidAmount
@onready var submit_button: Button = %SubmitButton

var player_ui: PlayerUI


func initialize(ui: PlayerUI) -> void:
	player_ui = ui
	submit_button.pressed.connect(_on_submit_button_pressed)
	
func _on_submit_button_pressed() -> void:
	if not bid_amount.text.is_valid_int():
		player_ui.current_player_label.text = "Bad inputs, try again!"
		return
		
	var bid_amount_int = int(bid_amount.text)
	var player_id = multiplayer.get_unique_id()
	bid_amount.text = ""
	
	if bid_amount_int > Global.player_info[player_id].gold:
		player_ui.current_player_label.text = "You don't that much gold!"
		return
	
	Global.player_bids[player_id] = bid_amount_int
	
	player_ui.sync_manager.rpc("sync_player_bids", Global.player_bids)
	player_ui.turn_manager.rpc_id(Global.host_id, "advance_to_next_player")
	hide()
	
@rpc("any_peer", "call_local", "reliable")
func allow_bid() -> void:
	bid_label.text = "Bid for item: " + Global.boss_drops[Global.bid_item_indices[Global.current_bid_item]].name
	show()
