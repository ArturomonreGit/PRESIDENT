class_name NightScene
extends Control
## Base de las "escenas" del plató (resultados, mapa, hemiciclo...). `bc` es la NightBroadcast que las muestra.

var bc
var title_text := ""
var sub_text := ""

func setup(broadcast) -> void:
	bc = broadcast
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	build()
	refresh()

func build() -> void:
	pass

## Se llama tras cada corte del recuento y al mostrar la escena.
func refresh() -> void:
	queue_redraw()

func _draw() -> void:
	if title_text != "":
		TV.text_tl(self, title_text, Vector2(0, 66), 28, TV.WHITE, true, HORIZONTAL_ALIGNMENT_CENTER, size.x)
		if sub_text != "":
			TV.text_tl(self, sub_text, Vector2(0, 104), 14, TV.MUTED, true, HORIZONTAL_ALIGNMENT_CENTER, size.x)
