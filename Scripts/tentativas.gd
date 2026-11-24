extends RefCounted

# Três tentativas por fase. O estado é estático: sobrevive ao reload da cena e é
# zerado ao entrar em outra fase ou ao voltar ao menu principal.

const TELA := preload("res://Scripts/tela_derrota.gd")
const MAXIMO := 3

static var restantes := MAXIMO
static var fase := ""


# Chamado no _ready de cada fase: recarregar a mesma fase mantém as tentativas,
# entrar em outra fase começa com três novas.
static func registrar_fase(caminho: String) -> void:
	if caminho.is_empty() or fase == caminho:
		return
	fase = caminho
	restantes = MAXIMO


static func reiniciar() -> void:
	fase = ""
	restantes = MAXIMO


static func restaurar() -> void:
	restantes = MAXIMO


static func ativa_em(cena: Node) -> bool:
	return not fase.is_empty() and cena != null and cena.scene_file_path == fase


# Perder os quatro corações consome uma tentativa. Devolve quantas sobraram.
static func consumir() -> int:
	restantes = maxi(0, restantes - 1)
	return restantes


static func mostrar_derrota(cena: Node, sobraram: int) -> void:
	var tela := TELA.new()
	tela.name = "TelaDerrota"
	tela.restantes = sobraram
	cena.add_child(tela)
