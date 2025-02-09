extends Node

func create_rect() -> TextureRect:
	var rect = TextureRect.new()
	rect.texture = preload("res://Assets/icon.svg")  # Replace with actual path
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT

	# Set anchor to the middle-top part of the screen
	rect.anchor_left = 0.5
	rect.anchor_top = 0.1
	rect.anchor_right = 0.5
	rect.anchor_bottom = 0.1

	# Offset position (centering the texture)
	rect.offset_left = -50  # Half of width
	rect.offset_top = 10    # Small padding from the top
	rect.offset_right = 50  # Half of width
	rect.offset_bottom = 60 # Adjust height

	return rect
