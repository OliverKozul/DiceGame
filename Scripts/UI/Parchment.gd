@tool
class_name Parchment
extends PanelContainer
## A panel drawn as aged parchment. Put content inside as usual; text on it should use the
## Ink label variations.

const SHADER := preload("res://Assets/Shaders/parchment.gdshader")

## How strongly the edges are darkened.
@export_range(0.0, 1.0) var edge_burn := 0.45:
	set(value):
		edge_burn = value
		if _paper:
			_material.set_shader_parameter("edge_burn", value)

## One seamless noise texture shared by every parchment panel.
static var _noise: NoiseTexture2D

var _paper: ColorRect
var _material := ShaderMaterial.new()


static func shared_noise() -> NoiseTexture2D:
	if _noise == null:
		var noise := FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = 0.012
		noise.fractal_octaves = 4
		_noise = NoiseTexture2D.new()
		_noise.width = 512
		_noise.height = 512
		_noise.seamless = true
		_noise.noise = noise
	return _noise


func _ready() -> void:
	if theme_type_variation == &"":
		theme_type_variation = &"PaperPanel"
	_material.shader = SHADER
	_material.set_shader_parameter("edge_burn", edge_burn)
	_material.set_shader_parameter("noise_texture", shared_noise())
	_paper = ColorRect.new()
	_paper.material = _material
	_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Internal and in front of the child list, so it draws behind the content and is never saved.
	add_child(_paper, false, Node.INTERNAL_MODE_FRONT)
	_paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
