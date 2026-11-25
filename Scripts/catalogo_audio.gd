extends RefCounted

const PROGRESSAO := preload("res://Scripts/progressao.gd")
const PASTA := "res://Assets/Audio/"

# Trilhas e ambientes são opcionais. Os nomes abaixo são nomes de arquivo, com extensão.
const TRILHAS := {
	PROGRESSAO.MENU: "Music/menu.ogg",
	PROGRESSAO.CAMARIM: "Music/camarim.ogg",
	PROGRESSAO.BILLIE_JEAN: "Music/billie_jean.ogg",
	PROGRESSAO.THRILLER: "Music/thriller.ogg",
	PROGRESSAO.SMOOTH_CRIMINAL: "Music/smooth_criminal.ogg",
	PROGRESSAO.ULTIMO_ECO: "Music/ultimo_eco.ogg",
	PROGRESSAO.INTRODUCAO: "Cinematics/introducao.ogg",
	"res://Scenes/encerramento.tscn": "Cinematics/encerramento.ogg",
}

const AMBIENTES := {
	PROGRESSAO.CAMARIM: "Ambient/camarim.ogg",
	PROGRESSAO.BILLIE_JEAN: "Ambient/billie_jean.ogg",
	PROGRESSAO.THRILLER: "Ambient/thriller.ogg",
	PROGRESSAO.SMOOTH_CRIMINAL: "Ambient/smooth_criminal.ogg",
	PROGRESSAO.ULTIMO_ECO: "Ambient/ultimo_eco.ogg",
}

const MEMORIAS := [PROGRESSAO.BILLIE_JEAN, PROGRESSAO.THRILLER, PROGRESSAO.SMOOTH_CRIMINAL]

# Cada evento pode ter várias gravações. As que ainda não existem são ignoradas.
const EFEITOS := {
	&"passo_madeira": ["passo_madeira_01.wav", "passo_madeira_02.wav"],
	&"passo_tapete": ["passo_tapete_01.wav", "passo_tapete_02.wav"],
	&"passo_asfalto": ["passo_asfalto_01.wav", "passo_asfalto_02.wav"],
	&"passo_pedra": ["passo_pedra_01.wav", "passo_pedra_02.wav"],
	&"passo_terra": ["passo_terra_01.wav", "passo_terra_02.wav"],
	&"passo_grama": ["passo_grama_01.wav", "passo_grama_02.wav"],
	&"passo_metal": ["passo_metal_01.wav", "passo_metal_02.wav"],
	&"dash": ["dash.wav"],
	&"moonwalk": ["moonwalk.wav"],
	&"chute": ["chute_01.wav", "chute_02.wav"],
	&"combo_final": ["combo_final.wav"],
	&"impacto": ["impacto_01.wav", "impacto_02.wav"],
	&"chapeu_lancamento": ["chapeu_lancamento.wav"],
	&"chapeu_retorno": ["chapeu_retorno.wav"],
	&"dano_michael": ["dano_michael.wav"],
	&"esquiva_perfeita": ["esquiva_perfeita.wav"],
	&"nota_coletada": ["nota_coletada.wav"],
	&"cura": ["cura.wav"],
	&"ataque_inimigo": ["ataque_inimigo_01.wav", "ataque_inimigo_02.wav"],
	&"chefe_aviso": ["chefe_aviso.wav"],
	&"chefe_golpe": ["chefe_golpe.wav"],
	&"chefe_investida": ["chefe_investida.wav"],
	&"chefe_onda": ["chefe_onda.wav"],
	&"chefe_fenda": ["chefe_fenda.wav"],
	&"chefe_etapa": ["chefe_etapa.wav"],
	&"portal": ["portal.wav"],
	&"restauracao": ["restauracao.wav"],
	&"vitoria": ["vitoria.wav"],
}

const INTERFACE := {
	&"ui_clique": ["clique.wav"],
	&"derrota": ["derrota.wav"],
	&"game_over": ["game_over.wav"],
}

const CINEMATICAS := {
	&"intro_ameaca": ["intro_ameaca.wav"],
	&"final_dissolucao": ["final_dissolucao.wav"],
	&"final_nota": ["final_nota.wav"],
}

const PISOS := {
	PROGRESSAO.BILLIE_JEAN: ^"Chao",
	PROGRESSAO.THRILLER: ^"Piso",
	PROGRESSAO.SMOOTH_CRIMINAL: ^"Piso",
}


static func canal(evento: StringName) -> StringName:
	if INTERFACE.has(evento):
		return &"UI"
	if CINEMATICAS.has(evento):
		return &"Cinematics"
	return &"SFX"


static func arquivos(evento: StringName) -> Array:
	if INTERFACE.has(evento):
		return INTERFACE[evento]
	if CINEMATICAS.has(evento):
		return CINEMATICAS[evento]
	return EFEITOS.get(evento, [])


static func superficie(cena: Node, posicao: Vector2) -> String:
	if cena == null:
		return "pedra"
	if cena.scene_file_path == PROGRESSAO.CAMARIM:
		var tapete := cena.get_node_or_null("tapete_vermelho") as Sprite2D
		if tapete != null and tapete.get_rect().grow(-5.0).has_point(tapete.to_local(posicao)):
			return "tapete"
		return "madeira"
	if cena.scene_file_path == PROGRESSAO.BILLIE_JEAN:
		var luminosos := cena.get_node_or_null("PisosLuminosos") as TileMapLayer
		if luminosos != null and luminosos.get_cell_source_id(luminosos.local_to_map(luminosos.to_local(posicao))) != -1:
			return "metal"
	var caminho: NodePath = PISOS.get(cena.scene_file_path, NodePath())
	if not caminho.is_empty():
		var piso := cena.get_node_or_null(caminho) as TileMapLayer
		if piso != null and piso.tile_set != null and piso.tile_set.get_custom_data_layer_by_name("superficie_audio") != -1:
			var dados := piso.get_cell_tile_data(piso.local_to_map(piso.to_local(posicao)))
			if dados != null:
				var material := String(dados.get_custom_data("superficie_audio"))
				if not material.is_empty():
					return material
	return "pedra"
