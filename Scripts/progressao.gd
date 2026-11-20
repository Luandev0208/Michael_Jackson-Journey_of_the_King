extends RefCounted

const CAMARIM := "res://Scenes/camarim.tscn"
const BILLIE_JEAN := "res://Scenes/billie_jean.tscn"
const THRILLER := "res://Scenes/thriller.tscn"
const SMOOTH_CRIMINAL := "res://Scenes/smooth_criminal.tscn"
const MAPA_DE_TESTE := "res://Scenes/jogo.tscn"
const MENU := "res://Scenes/interface.tscn"

static func fases_disponiveis() -> Dictionary:
	var cenas := {
		"Camarim": CAMARIM,
		"Billie Jean": BILLIE_JEAN,
		"Thriller": THRILLER,
		"Smooth Criminal": SMOOTH_CRIMINAL,
		"Mapa de combate": MAPA_DE_TESTE,
	}
	for nome in cenas.keys():
		if not ResourceLoader.exists(cenas[nome], "PackedScene"):
			cenas.erase(nome)
	return cenas
